import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class NavigationService {
  static final NavigationService _instance = NavigationService._internal();
  factory NavigationService() => _instance;
  NavigationService._internal();

  static const String _navReturnPendingKey = 'nav_return_pending';
  static const String _navReturnSetAtKey = 'nav_return_set_at_ms';
  static const String _navReturnSourceKey = 'nav_return_source';
  // Tracks whether we've already sent the driver to the "Display over other
  // apps" settings once, so we never loop them back there on every Navigate tap.
  static const String _overlayPromptedKey = 'overlay_bubble_prompted';

  static const MethodChannel _channel =
      MethodChannel('hopper/navigation_intents');

  // ---- Floating "return to Hoppr" bubble over Google Maps (Android only) ----

  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Whether the "Display over other apps" permission is granted.
  Future<bool> hasOverlayPermission() async {
    if (!_isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('hasOverlayPermission') ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> _openOverlaySettings() async {
    try {
      await _channel.invokeMethod('requestOverlayPermission');
    } catch (_) {}
  }

  /// Prepare the return-bubble before launching external navigation.
  ///
  /// Returns `true` if the caller should proceed to launch Google Maps now.
  /// Returns `false` ONLY when we just opened the overlay-permission settings
  /// screen (first time) — the caller should abort this tap so the driver can
  /// grant it and tap Navigate again. After that first prompt we never block
  /// navigation again, even if still denied (bubble simply won't show).
  Future<bool> prepareReturnBubble() async {
    if (!_isAndroid) return true;
    if (await hasOverlayPermission()) return true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final prompted = prefs.getBool(_overlayPromptedKey) ?? false;
      if (!prompted) {
        await prefs.setBool(_overlayPromptedKey, true);
        await _openOverlaySettings();
        return false;
      }
    } catch (_) {}
    return true;
  }

  /// Show the floating return bubble over Google Maps. No-op if the permission
  /// isn't granted; safe on iOS/web.
  Future<void> showReturnBubble() async {
    if (!_isAndroid) return;
    try {
      await _channel.invokeMethod('showReturnBubble');
    } catch (_) {}
  }

  /// Remove the floating return bubble. Safe to call anytime / on iOS/web.
  Future<void> hideReturnBubble() async {
    if (!_isAndroid) return;
    try {
      await _channel.invokeMethod('hideReturnBubble');
    } catch (_) {}
  }

  Future<void> markExternalNavigationReturnPending({
    String source = 'trip_navigation',
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_navReturnPendingKey, true);
      await prefs.setInt(
        _navReturnSetAtKey,
        DateTime.now().millisecondsSinceEpoch,
      );
      await prefs.setString(_navReturnSourceKey, source);
    } catch (_) {}
  }

  Future<bool> consumeExternalNavigationReturnPending({
    Duration maxAge = const Duration(hours: 6),
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pending = await hasExternalNavigationReturnPending(maxAge: maxAge);
      await clearExternalNavigationReturnPending();
      return pending;
    } catch (_) {
      return false;
    }
  }

  Future<bool> hasExternalNavigationReturnPending({
    Duration maxAge = const Duration(hours: 6),
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pending = prefs.getBool(_navReturnPendingKey) ?? false;
      final setAtMs = prefs.getInt(_navReturnSetAtKey) ?? 0;
      if (!pending || setAtMs <= 0) return false;
      final setAt = DateTime.fromMillisecondsSinceEpoch(setAtMs);
      if (DateTime.now().difference(setAt) > maxAge) return false;
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> clearExternalNavigationReturnPending() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_navReturnPendingKey);
      await prefs.remove(_navReturnSetAtKey);
      await prefs.remove(_navReturnSourceKey);
    } catch (_) {}
  }

  /// Request the required location permissions for background tracking.
  ///
  /// Returns `true` when permission is granted and GPS is enabled.
  Future<bool> requestPermissions() async {
    // Ensure GPS is enabled.
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      await Geolocator.openLocationSettings();
      return false;
    }

    // Base permission flow (while-in-use first).
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever ||
        permission == LocationPermission.denied) {
      return false;
    }

    // Background permission (Android 10+).
    // Note: On some Android versions, the OS may force this to be granted via
    // Settings even after request(). We treat "limited/denied" as not-ready.
    try {
      final always = await Permission.locationAlways.request();
      if (!always.isGranted) return false;
    } catch (_) {
      // If permission_handler fails for any reason, fall back to Geolocator state.
      final p = await Geolocator.checkPermission();
      if (p != LocationPermission.always) return false;
    }

    return true;
  }

  /// Whether background ("Allow all the time") location is already granted.
  Future<bool> hasAlwaysLocation() async {
    try {
      final p = await Geolocator.checkPermission();
      return p == LocationPermission.always;
    } catch (_) {
      return false;
    }
  }

  /// Open the OS app-settings page so the driver can pick "Allow all the time".
  Future<void> openLocationAppSettings() async {
    try {
      await openAppSettings(); // from permission_handler
    } catch (_) {}
  }

  /// Open Google Maps turn-by-turn navigation to [destLat],[destLng].
  /// Prefers native Google Maps app, falls back to a Maps URL.
  Future<void> openGoogleMapsNavigation({
    required double destLat,
    required double destLng,
    required String destinationLabel,
  }) async {
    // Android: show the floating "return to Hoppr" bubble just before handing
    // off to Google Maps, so it's added while we're still foregrounded and then
    // floats on top of Maps. No-op if the overlay permission isn't granted.
    if (_isAndroid) {
      unawaited(showReturnBubble());
    }

    // Android: launch with an explicit intent to reduce Google Maps back-stack
    // and improve "return to app" behavior on some devices.
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        final didLaunch = await _channel.invokeMethod<bool>(
              'openGoogleMapsNavigation',
              <String, dynamic>{
                'lat': destLat,
                'lng': destLng,
                'label': destinationLabel,
              },
            ) ??
            false;
        if (didLaunch) return;
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[NAV] platform intent launch failed: $e');
        }
      }
    }

    final nativeUrl = Uri.parse('google.navigation:q=$destLat,$destLng&mode=d');

    final webUrl = Uri.parse(
      'https://www.google.com/maps/dir/?api=1'
      '&destination=$destLat,$destLng'
      '&travelmode=driving',
    );

    try {
      if (await canLaunchUrl(nativeUrl)) {
        await launchUrl(nativeUrl, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[NAV] native launch failed: $e');
      }
    }

    // Browser fallback.
    await launchUrl(webUrl, mode: LaunchMode.externalApplication);
  }
}
