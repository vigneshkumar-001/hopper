// lib/services/background_service.dart
import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

import 'package:hopper/Core/Constants/log.dart';
import '../../../api/repository/api_config_controller.dart';
import '../../../utils/sharedprefsHelper/sharedprefs_handler.dart';

Future<void>? _configureOnce;

Future<void> initializeBackgroundService() async {
  // Idempotent: multiple callers can await this safely (prevents race where
  // `startService()` is called before `configure()` finishes on app launch).
  _configureOnce ??= () async {
    // Ensure the notification channel exists before Android starts the FGS.
    // Missing/invalid notification can crash on newer Android.
    try {
      const channel = AndroidNotificationChannel(
        'driver_tracking',
        'Driver Tracking',
        description: 'Background location tracking',
        importance: Importance.low,
      );
      final plugin = FlutterLocalNotificationsPlugin();
      await plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    } catch (_) {}

    final service = FlutterBackgroundService();

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        isForegroundMode: true,
        autoStart: false,
        autoStartOnBoot: false,
        foregroundServiceTypes: const [AndroidForegroundType.location],
        notificationChannelId: 'driver_tracking',
        initialNotificationTitle: 'Driver Tracking Active',
        initialNotificationContent: 'Sending location updates...',
      ),
      iosConfiguration: IosConfiguration(
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );
  }();

  await _configureOnce;
}

Future<void> ensureDriverTrackingServiceRunning({
  String? driverId,
  String? bookingId,
}) async {
  await initializeBackgroundService();

  // Avoid crashing Android 13+ if notifications are disabled for the app.
  try {
    final plugin = FlutterLocalNotificationsPlugin();
    final android =
        plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    final enabled = await android?.areNotificationsEnabled();
    if (enabled == false) {
      CommonLogger.log.w(
        '🚫 [BG_SERVICE] Notifications disabled; not starting tracking service',
      );
      return;
    }
  } catch (_) {}

  final service = FlutterBackgroundService();
  final running = await service.isRunning();
  if (!running) {
    try {
      await service.startService();
    } catch (e) {
      CommonLogger.log.e('❌ [BG_SERVICE] startService failed: $e');
      return;
    }
  }

  service.invoke('data', {
    if (driverId != null) 'driverId': driverId,
    if (bookingId != null) 'bookingId': bookingId,
  });
}

Future<void> stopDriverTrackingService() async {
  await initializeBackgroundService();
  final service = FlutterBackgroundService();
  final running = await service.isRunning();
  if (!running) return;
  service.invoke('data', {'action': 'stopService'});
}

@pragma('vm:entry-point')
bool onIosBackground(ServiceInstance service) {
  WidgetsFlutterBinding.ensureInitialized();
  return true;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  final AndroidServiceInstance? androidService =
      service is AndroidServiceInstance ? service : null;

  String? driverId;
  String? currentBookingId;

  // Keep service as foreground (Android) so it continues on screen-lock.
  try {
    await androidService?.setAsForegroundService();
    await androidService?.setForegroundNotificationInfo(
      title: 'Driver Tracking Active',
      content: 'Sending location updates...',
    );
  } catch (_) {}

  // --- jitter filtering / throttling ---
  const double maxAccuracyM = 25.0;
  const double stationaryJumpM = 30.0;
  const double jumpAcceptAccuracyM = 12.0;
  const Duration minEmitInterval = Duration(seconds: 5);

  double? lastLat;
  double? lastLng;
  DateTime lastEmitAt = DateTime.fromMillisecondsSinceEpoch(0);

  try {
    driverId = await SharedPrefHelper.getDriverId();
  } catch (_) {}

  String socketUrl = ApiConfigController.singleSocket;
  try {
    final shared = await SharedPrefHelper.instance.getSharedBookingEnabled();
    socketUrl = shared
        ? ApiConfigController.sharedSocket
        : ApiConfigController.singleSocket;
  } catch (_) {}

  final socket = IO.io(
    socketUrl,
    IO.OptionBuilder()
        .setTransports(['websocket'])
        .enableForceNew()
        .enableReconnection()
        .build(),
  );

  socket.connect();

  socket.onConnect((_) {
    if (driverId != null) {
      socket.emit('register', {'userId': driverId, 'type': 'driver'});
    }
    if (kDebugMode) {
      CommonLogger.log.i("✅ [BG_SOCKET] Connected ($socketUrl)");
    }
  });

  service.on('data').listen((event) {
    if (event == null) return;

    if (event['action'] == 'stopService') {
      socket.disconnect();
      service.stopSelf();
    }

    if (event.containsKey('bookingId')) {
      currentBookingId = event['bookingId']?.toString();
    }

    if (event.containsKey('driverId')) {
      driverId = event['driverId']?.toString();
      socket.emit('register', {'userId': driverId, 'type': 'driver'});
    }
  });

  Geolocator.getPositionStream(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 8,
    ),
  ).listen((position) {
    if (driverId == null || driverId!.trim().isEmpty) return;

    final now = DateTime.now();
    if (now.difference(lastEmitAt) < minEmitInterval) return;

    final acc = position.accuracy.isFinite ? position.accuracy : 9999.0;
    if (acc > maxAccuracyM) return;

    if (lastLat != null && lastLng != null) {
      final movedMeters = Geolocator.distanceBetween(
        lastLat!,
        lastLng!,
        position.latitude,
        position.longitude,
      );

      final speedMs = (position.speed.isFinite && position.speed >= 0)
          ? position.speed
          : 0.0;

      if (speedMs < 1.0 &&
          movedMeters >= stationaryJumpM &&
          acc > jumpAcceptAccuracyM) {
        return;
      }

      double driftGate = 8.0;
      final adaptive = (acc * 0.8).clamp(0.0, 20.0);
      if (adaptive > driftGate) driftGate = adaptive;
      if (speedMs < 1.0 && movedMeters < driftGate) return;
    }

    lastLat = position.latitude;
    lastLng = position.longitude;
    lastEmitAt = now;

    final locationData = {
      'userId': driverId,
      'latitude': position.latitude,
      'longitude': position.longitude,
      if (currentBookingId != null) 'bookingId': currentBookingId,
      'timestamp': now.toIso8601String(),
    };
    socket.emit('updateLocation', locationData);
    if (kDebugMode) {
      CommonLogger.log.i('📍 [BG_SOCKET_EMIT] updateLocation $locationData');
    }
  });

  Timer.periodic(const Duration(minutes: 15), (timer) async {
    bool running = await FlutterBackgroundService().isRunning();
    if (!running) {
      timer.cancel();
    }
    service.invoke('heartbeat', {'time': DateTime.now().toIso8601String()});
  });
}
