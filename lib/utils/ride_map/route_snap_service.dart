import 'dart:math' as math;

import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'polyline_trim_utils.dart';

class RouteSnapResult {
  final LatLng snapped;
  final double distanceToRouteMeters;
  final int nearestIndex;
  final List<LatLng> remaining;
  final List<LatLng> completed;
  final LatLng lookAheadPoint;

  const RouteSnapResult({
    required this.snapped,
    required this.distanceToRouteMeters,
    required this.nearestIndex,
    required this.remaining,
    required this.completed,
    required this.lookAheadPoint,
  });
}

/// Route snapping + look-ahead helper.
///
/// Wraps existing `PolylineTrimUtils` and adds a look-ahead point on the
/// remaining polyline for camera/bearing stability.
class RouteSnapService {
  const RouteSnapService();

  RouteSnapResult snapAndTrim({
    required List<LatLng> route,
    required LatLng vehicle,
    int lookAheadPoints = 80,
    double lookAheadMeters = 60,
  }) {
    final trim = PolylineTrimUtils.trim(
      route: route,
      vehicle: vehicle,
      lookAheadPoints: lookAheadPoints,
    );

    final remaining = trim.remaining;
    final lookAhead = _pointAlongPolyline(
      remaining,
      metersFromStart: lookAheadMeters,
    );

    return RouteSnapResult(
      snapped: trim.snapped,
      distanceToRouteMeters: trim.snapDistanceMeters,
      nearestIndex: trim.nearestIndex,
      remaining: trim.remaining,
      completed: trim.completed,
      lookAheadPoint: lookAhead,
    );
  }

  static LatLng _pointAlongPolyline(List<LatLng> pts, {required double metersFromStart}) {
    if (pts.isEmpty) return const LatLng(0, 0);
    if (pts.length == 1) return pts.first;

    var remaining = metersFromStart;
    for (var i = 0; i < pts.length - 1; i++) {
      final a = pts[i];
      final b = pts[i + 1];
      final seg = _distanceMeters(a, b);
      if (seg <= 0) continue;
      if (remaining <= seg) {
        final t = (remaining / seg).clamp(0.0, 1.0);
        return LatLng(
          a.latitude + (b.latitude - a.latitude) * t,
          a.longitude + (b.longitude - a.longitude) * t,
        );
      }
      remaining -= seg;
    }
    return pts.last;
  }

  static double _distanceMeters(LatLng a, LatLng b) {
    final dx = (a.latitude - b.latitude) * 111320.0;
    final dy =
        (a.longitude - b.longitude) *
        111320.0 *
        math.cos(a.latitude * math.pi / 180.0);
    return math.sqrt(dx * dx + dy * dy);
  }
}

