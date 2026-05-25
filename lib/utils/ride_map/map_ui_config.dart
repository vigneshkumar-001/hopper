import 'package:flutter/material.dart';

/// Centralized UI constants for all ride-map experiences.
///
/// Keep these values stable to ensure marker/polyline/camera consistency
/// across: home, request, pickup, drop, shared pickup, shared drop, completed.
class MapUiConfig {
  // Marker logical sizes (device-independent logical pixels).
  // Bitmaps are generated at `size * devicePixelRatio` and cached.
  // Tuned smaller for production (Ola/Uber-like).
  static const double carMarkerSize = 32.0;
  static const double bikeMarkerSize = 22.0;
  static const double pickupMarkerSize = 32.0;
  static const double dropMarkerSize = 32.0;

  // Route styling
  static const int polylineWidth = 6;
  static const Color activePolylineColor = Color(0xFF111111);
  static const Color completedPolylineColor = Color(0x66111111);

  // Camera defaults
  static const double defaultZoom = 15.4;
  static const double navigationZoom = 16.8;
  static const double cameraTilt = 45.0;
  static const bool cameraBearingEnabled = true;
  static const Duration animationDuration = Duration(milliseconds: 550);

  /// Default map padding (screen-space). Add dynamic bottom-sheet padding on top.
  static const EdgeInsets cameraPadding = EdgeInsets.only(bottom: 260);

  // Navigation behavior thresholds (meters / degrees).
  static const double snapToRouteToleranceMeters = 35.0;
  static const double offRouteRecalcThresholdMeters = 45.0;
  static const double minCameraMoveMeters = 2.5;
  static const double minCameraBearingDeltaDeg = 3.0;
}
