// lib/services/background_service.dart
import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:geolocator/geolocator.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

import '../../../utils/sharedprefsHelper/sharedprefs_handler.dart';

Future<void> initializeBackgroundService() async {
  final service = FlutterBackgroundService();

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      isForegroundMode: true,
      autoStart: false,
      notificationChannelId: 'driver_tracking',
      initialNotificationTitle: 'Driver Tracking Active',
      initialNotificationContent: 'Sending location updates...',
    ),
    iosConfiguration: IosConfiguration(
      onForeground: onStart,
      onBackground: onIosBackground,
    ),
  );
}

bool onIosBackground(ServiceInstance service) {
  WidgetsFlutterBinding.ensureInitialized();
  return true;
}

void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  final AndroidServiceInstance? androidService =
      service is AndroidServiceInstance ? service : null;

  String? driverId;
  String? currentBookingId;

  try {
    driverId = await SharedPrefHelper.getDriverId();
  } catch (_) {}

  final socket = IO.io(
    'https://hoppr-face-two-dbe557472d7f.herokuapp.com',
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
    if (kDebugMode) print("✅ Socket Connected");
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
      accuracy: LocationAccuracy.high,
      distanceFilter: 0,
    ),
  ).listen((position) {
    final locationData = {
      'userId': driverId,
      'latitude': position.latitude,
      'longitude': position.longitude,
      if (currentBookingId != null) 'bookingId': currentBookingId,
      'timestamp': DateTime.now().toIso8601String(),
    };
    socket.emit('updateLocation', locationData);
    if (kDebugMode) print('📡 BG emit: $locationData');
  });

  Timer.periodic(const Duration(minutes: 15), (timer) async {
    bool running = await FlutterBackgroundService().isRunning();
    if (!running) {
      timer.cancel();
    }
    service.invoke('heartbeat', {'time': DateTime.now().toIso8601String()});
  });
}
