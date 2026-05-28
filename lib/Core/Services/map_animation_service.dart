import 'dart:math' as math;

import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Pure math helpers for smooth marker movement (lerp + shortest-angle bearing).
///
/// UI code should drive an AnimationController and update ValueNotifiers;
/// this class stays framework-agnostic and testable.
class MapAnimationService {
  /// Shortest-path bearing interpolation: prevents 359° -> 1° spinning.
  double interpolateBearing(double startBearing, double endBearing, double t) {
    var diff = (endBearing - startBearing) % 360.0;
    if (diff > 180.0) diff -= 360.0;
    if (diff < -180.0) diff += 360.0;
    return (startBearing + diff * t) % 360.0;
  }

  LatLng interpolateLatLng(LatLng start, LatLng end, double t) {
    final tt = t.clamp(0.0, 1.0);
    return LatLng(
      start.latitude + (end.latitude - start.latitude) * tt,
      start.longitude + (end.longitude - start.longitude) * tt,
    );
  }

  double computeBearing(LatLng from, LatLng to) {
    final lat1 = from.latitude * math.pi / 180.0;
    final lon1 = from.longitude * math.pi / 180.0;
    final lat2 = to.latitude * math.pi / 180.0;
    final lon2 = to.longitude * math.pi / 180.0;

    final dLon = lon2 - lon1;
    final y = math.sin(dLon) * math.cos(lat2);
    final x =
        math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
    final brng = math.atan2(y, x) * 180.0 / math.pi;
    return (brng + 360.0) % 360.0;
  }
}

