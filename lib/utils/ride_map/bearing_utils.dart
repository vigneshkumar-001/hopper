import 'dart:math' as math;

import 'package:google_maps_flutter/google_maps_flutter.dart';

class BearingUtils {
  static double normalize360(double bearingDeg) {
    var b = bearingDeg % 360.0;
    if (b < 0) b += 360.0;
    return b;
  }

  /// Returns bearing in degrees [0, 360).
  static double bearingBetween(LatLng start, LatLng end) {
    final lat1 = start.latitude * math.pi / 180.0;
    final lon1 = start.longitude * math.pi / 180.0;
    final lat2 = end.latitude * math.pi / 180.0;
    final lon2 = end.longitude * math.pi / 180.0;

    final dLon = lon2 - lon1;
    final y = math.sin(dLon) * math.cos(lat2);
    final x =
        math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);

    final bearing = math.atan2(y, x) * 180.0 / math.pi;
    return normalize360(bearing);
  }

  static double angleDeltaDeg(double a, double b) {
    a = normalize360(a);
    b = normalize360(b);
    var d = (b - a) % 360.0;
    if (d > 180.0) d -= 360.0;
    if (d < -180.0) d += 360.0;
    return d.abs();
  }

  /// Shortest-angle interpolation between bearings.
  static double lerpAngle(double fromDeg, double toDeg, double t) {
    final a = normalize360(fromDeg);
    final b = normalize360(toDeg);
    var diff = (b - a) % 360.0;
    if (diff > 180.0) diff -= 360.0;
    if (diff < -180.0) diff += 360.0;
    return normalize360(a + diff * t);
  }

  /// Exponential smoothing that respects shortest-angle direction.
  static double smoothBearing(double currentDeg, double targetDeg, double alpha) {
    final a = normalize360(currentDeg);
    final b = normalize360(targetDeg);
    var diff = (b - a) % 360.0;
    if (diff > 180.0) diff -= 360.0;
    if (diff < -180.0) diff += 360.0;
    return normalize360(a + diff * alpha);
  }
}

