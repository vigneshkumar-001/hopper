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
      if (kDebugMode) {
        CommonLogger.log.i('🟢 [BG_SERVICE] Starting driver tracking service');
      }
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
  if (kDebugMode) {
    CommonLogger.log.i('🛑 [BG_SERVICE] Stopping driver tracking service');
  }
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
  StreamSubscription<Position>? positionSub;
  Timer? pollTimer;

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

  Map<String, dynamic>? _pendingPayload;
  String? _pendingEvent;
  DateTime _lastManualReconnectAt = DateTime.fromMillisecondsSinceEpoch(0);

  final socket = IO.io(
    socketUrl,
    IO.OptionBuilder()
        .setTransports(['websocket'])
        .enableReconnection()
        .enableAutoConnect()
        .setReconnectionAttempts(999999)
        .setReconnectionDelay(1000)
        .setReconnectionDelayMax(8000)
        .setTimeout(15000)
        .build(),
  );

  void safeRegisterAndFlush() {
    final did = driverId?.trim() ?? '';
    if (did.isNotEmpty) {
      socket.emit('register', {
        'userId': did,
        'type': 'driver',
        if (currentBookingId != null) 'bookingId': currentBookingId,
      });
    }

    final event = _pendingEvent;
    final payload = _pendingPayload;
    if (event != null && payload != null) {
      socket.emit(event, payload);
      _pendingEvent = null;
      _pendingPayload = null;
    }
  }

  socket.connect();

  socket.onConnect((_) {
    safeRegisterAndFlush();
    if (kDebugMode) {
      CommonLogger.log.i("✅ [BG_SOCKET] Connected ($socketUrl)");
    }
  });

  socket.onReconnect((_) {
    safeRegisterAndFlush();
    if (kDebugMode) {
      CommonLogger.log.i("🔁 [BG_SOCKET] Reconnected ($socketUrl)");
    }
  });

  socket.onDisconnect((_) {
    if (kDebugMode) {
      CommonLogger.log.e("⛔ [BG_SOCKET] Disconnected ($socketUrl)");
    }

    // If the server explicitly disconnects, socket.io may not auto-reconnect.
    // Try a debounced manual reconnect; re-register happens on connect.
    final now = DateTime.now();
    if (now.difference(_lastManualReconnectAt) >= const Duration(seconds: 2)) {
      _lastManualReconnectAt = now;
      socket.connect();
    }
  });

  socket.onConnectError((err) {
    if (kDebugMode) {
      CommonLogger.log.e("⚠️ [BG_SOCKET] Connect error: $err ($socketUrl)");
    }
  });

  Timer? heartbeatTimer;
  service.on('data').listen((event) {
    if (event == null) return;

    if (event['action'] == 'stopService') {
      heartbeatTimer?.cancel();
      pollTimer?.cancel();
      unawaited(positionSub?.cancel());
      socket.disconnect();
      service.stopSelf();
    }

    if (event.containsKey('bookingId')) {
      currentBookingId = event['bookingId']?.toString();
    }

    if (event.containsKey('driverId')) {
      driverId = event['driverId']?.toString();
      if (socket.connected) {
        safeRegisterAndFlush();
      } else {
        socket.connect();
      }
    }
  });

  positionSub = Geolocator.getPositionStream(
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
    if (!socket.connected) {
      _pendingEvent = 'updateLocation';
      _pendingPayload = locationData;
      socket.connect();
    } else {
      socket.emit('updateLocation', locationData);
    }
    if (kDebugMode) {
      CommonLogger.log.i('📍 [BG_SOCKET_EMIT] updateLocation $locationData');
    }
  });

  // If the stream doesn't emit (driver stationary / OEM throttling), poll and emit
  // periodically so the server still receives location while driver is online.
  pollTimer = Timer.periodic(const Duration(seconds: 20), (_) async {
    if (driverId == null || driverId!.trim().isEmpty) return;

    final now = DateTime.now();
    if (now.difference(lastEmitAt) < const Duration(seconds: 18)) return;

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
        ),
      );

      final acc = position.accuracy.isFinite ? position.accuracy : 9999.0;
      if (acc > maxAccuracyM) return;

      final prevLat = lastLat;
      final prevLng = lastLng;

      lastLat = position.latitude;
      lastLng = position.longitude;
      lastEmitAt = now;

      final movedMeters =
          (prevLat == null || prevLng == null)
              ? null
              : Geolocator.distanceBetween(
                prevLat,
                prevLng,
                position.latitude,
                position.longitude,
              );
      final speedMs =
          (position.speed.isFinite && position.speed >= 0) ? position.speed : 0.0;
      final isMoving = (movedMeters != null && movedMeters >= 5.0) || speedMs >= 0.6;

      final locationData = {
        'userId': driverId,
        'latitude': position.latitude,
        'longitude': position.longitude,
        if (currentBookingId != null) 'bookingId': currentBookingId,
        'timestamp': now.toIso8601String(),
      };

      if (!socket.connected) {
        _pendingEvent = isMoving ? 'updateLocation' : 'driver-heartbeat';
        _pendingPayload = locationData;
        socket.connect();
      } else {
        socket.emit(isMoving ? 'updateLocation' : 'driver-heartbeat', locationData);
      }
      if (kDebugMode) {
        CommonLogger.log.i(
          '[BG_SOCKET_EMIT] ${isMoving ? 'updateLocation' : 'driver-heartbeat'} (poll) $locationData',
        );
      }
    } catch (_) {}
  });

  // NOTE: Don't call `FlutterBackgroundService().isRunning()` from the
  // background isolate. It can throw `MissingPluginException` on some devices /
  // builds because the method-channel implementation may not be registered in
  // this isolate. If the service stops, the isolate/timer is torn down anyway.
  heartbeatTimer = Timer.periodic(const Duration(minutes: 15), (_) {
    service.invoke('heartbeat', {'time': DateTime.now().toIso8601String()});
  });
}
