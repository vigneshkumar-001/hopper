import 'package:flutter/material.dart';

/// Centralized UI constants for all ride-map experiences.
///
/// Keep these values stable to ensure marker/polyline/camera consistency
/// across: home, request, pickup, drop, shared pickup, shared drop, completed.
class MapUiConfig {
  // Marker logical sizes (device-independent logical pixels).
  // Bitmaps are generated at `size * devicePixelRatio` and cached.
  // Tuned smaller for production (Ola/Uber-like).
  // More compact vehicle markers (closer to Ola/Uber in-app size).
  static const double carMarkerSize = 20.0;
  static const double bikeMarkerSize = 18.0;
  static const double pickupMarkerSize = 32.0;
  static const double dropMarkerSize = 32.0;

  // Route styling
  // Premium layered route (Ola/Uber-like): soft outline + clean main stroke.
  static const int polylineWidth = 6;
  static const int polylineShadowWidth = 11;
  // Active route (premium black) as requested.
  static const Color activePolylineColor = Color(0xFF111111);
  // Outline for contrast on light maps.
  static const Color activePolylineShadowColor = Color(0xFFFFFFFF);
  static const Color completedPolylineColor = Color(0x99A0AEC0);
  static const Color completedPolylineShadowColor = Color(0x33FFFFFF);

  // Camera defaults
  static const double defaultZoom = 15.4;
  static const double navigationZoom = 16.9;
  static const double navigationZoomMax = 17.5;
  static const double cameraTilt = 45.0;
  static const bool cameraBearingEnabled = true;
  static const Duration animationDuration = Duration(milliseconds: 550);

  /// Default padding baseline. `RideMapView` adds safe-area + bottom-sheet.
  static const double mapSidePadding = 24.0;
  static const double mapTopPadding = 24.0;
  static const double mapBottomExtraPadding = 80.0;

  // Navigation behavior thresholds (meters / degrees).
  static const double snapToRouteToleranceMeters = 35.0;
  static const double offRouteRecalcThresholdMeters = 45.0;
  static const double gpsAccuracyRejectMeters = 25.0;
  static const double minMoveAcceptMeters = 3.0;
  static const double stationaryDriftIgnoreMeters = 8.0;
  static const double gpsJumpResyncMeters = 120.0;
  static const Duration minRerouteInterval = Duration(seconds: 12);

  // Socket/GPS sanity filters.
  // If a timestamp is older than this, ignore the point (prevents "rewind").
  static const Duration maxLocationAge = Duration(seconds: 10);
  // Allow a small future skew (some devices/server clocks can be ahead).
  static const Duration maxFutureSkew = Duration(seconds: 2);
  // Reject physically implausible motion for a taxi/bike (m/s).
  // 55 m/s ~= 198 km/h.
  static const double maxImpliedSpeedMetersPerSecond = 55.0;

  // Off-route detection.
  // Require consecutive misses to avoid re-route spam from GPS glitches.
  static const int offRouteConfirmCount = 3;

  // Dead-reckoning fallback (for brief socket gaps).
  // When live socket/GPS updates pause briefly, we extrapolate from the last
  // known real pose (speed + bearing) for a short window so the marker doesn't
  // look "stuck". Stops immediately when a fresh live update arrives.
  static const bool deadReckonEnabled = true;
  static const int deadReckonTickMs = 250;
  static const Duration deadReckonMaxAge = Duration(seconds: 3);

  /// Look-ahead distance (meters) for navigation framing / bearing stability.
  static const double lookAheadMinMeters = 50.0;
  static const double lookAheadMaxMeters = 90.0;

  static const double minCameraMoveMeters = 2.5;
  static const double minCameraBearingDeltaDeg = 3.0;

  // Follow-camera throttling (avoid shake / spam).
  static const Duration cameraThrottleMin = Duration(milliseconds: 300);
  static const Duration cameraDebounce = Duration(milliseconds: 140);

  // Navigation camera update rules (Uber/Ola-like).
  static const double navCameraMinMoveMeters = 8.0;
  static const double navCameraMinBearingDeltaDeg = 10.0;
  static const Duration navCameraMaxSilence = Duration(milliseconds: 700);

  // Bounds-fit tuning: avoid zooming out too much on route fit.
  static const double boundsFitMinZoom = 16.2;
  static const double boundsFitMaxZoom = 18.0;
  static const double boundsFitExtraZoomIn = 0.25; // small "pro" push-in

  // Pickup leg fit tuning (short distances should not zoom out city-wide).
  static const double minPickupFitZoom = 16.0;
  static const double maxPickupFitPadding = 100.0;

  // Vehicle icon orientation.
  // If an icon asset points "south" or "east" by default, adjust here rather than
  // hacking bearing math across the app.
  // 0 means the asset points north (default Google Maps bearing convention).
  static const double carBearingOffsetDeg = 0.0;
  static const double bikeBearingOffsetDeg = 0.0;
  static const double packageBikeBearingOffsetDeg = 0.0;
}
