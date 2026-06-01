import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hopper/Presentation/DriverScreen/screens/background_service.dart'
    as legacy_bg;

/// Thin, production-safe wrapper around the app's existing background tracking
/// implementation (`Presentation/DriverScreen/screens/background_service.dart`).
///
/// This file exists to provide a stable API for "start tracking before opening
/// Google Maps", while reusing the already-shipped, battle-tested service code.
class DriverBackgroundLocationService {
  static final DriverBackgroundLocationService _instance =
      DriverBackgroundLocationService._internal();
  factory DriverBackgroundLocationService() => _instance;
  DriverBackgroundLocationService._internal();

  static const String _socketUrlKey = 'bg_socket_url';
  static const String _rideIdKey = 'bg_ride_id';
  static const String _driverIdKey = 'bg_driver_id';

  /// Call once at app startup (before `runApp`).
  static Future<void> initialize() async {
    await legacy_bg.initializeBackgroundService();
  }

  /// Start background tracking.
  ///
  /// IMPORTANT:
  /// - In this app, foreground + background sockets must not run together.
  ///   Callers should hand-off/disconnect the foreground socket before calling.
  static Future<void> startTracking({
    required String socketUrl,
    required String rideId,
    required String driverId,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_socketUrlKey, socketUrl);
      await prefs.setString(_rideIdKey, rideId);
      await prefs.setString(_driverIdKey, driverId);
    } catch (_) {
      // Don't block tracking start if prefs fail.
    }

    await legacy_bg.ensureDriverTrackingServiceRunning(
      driverId: driverId,
      bookingId: rideId,
    );

    // Also push the latest values to the already-running service if any.
    try {
      FlutterBackgroundService().invoke('data', {
        'driverId': driverId,
        'bookingId': rideId,
        'socketUrl': socketUrl,
      });
    } catch (_) {}

    if (kDebugMode) {
      debugPrint(
        '[BG_TRACKING] startTracking driverId=$driverId bookingId=$rideId socketUrl=$socketUrl',
      );
    }
  }

  /// Stop background tracking.
  static Future<void> stopTracking() async {
    await legacy_bg.stopDriverTrackingService();
  }

  /// Update the booking/ride context used for payloads (pickup → drop, etc).
  static Future<void> updateRidePhase(String newRideId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_rideIdKey, newRideId);
    } catch (_) {}

    try {
      FlutterBackgroundService().invoke('data', {'bookingId': newRideId});
    } catch (_) {}
  }
}

