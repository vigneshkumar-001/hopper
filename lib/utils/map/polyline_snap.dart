import 'dart:math' as math;

import 'package:google_maps_flutter/google_maps_flutter.dart';

class PolylineSnapResult {
  final LatLng point;
  final double distanceMeters;
  final int segmentIndex;
  final double t;

  const PolylineSnapResult({
    required this.point,
    required this.distanceMeters,
    required this.segmentIndex,
    required this.t,
  });
}

/// Snap a coordinate onto a polyline (closest point on any segment).
///
/// Uses an equirectangular approximation in meters (fast + accurate enough for
/// small distances used in navigation UI).
PolylineSnapResult snapToPolyline(
  LatLng location,
  List<LatLng> polyline, {
  int? maxSegments,
}) {
  if (polyline.length < 2) {
    return PolylineSnapResult(
      point: location,
      distanceMeters: double.infinity,
      segmentIndex: 0,
      t: 0.0,
    );
  }

  final int segmentCount = polyline.length - 1;
  final int limit = maxSegments == null
      ? segmentCount
      : math.min(segmentCount, math.max(1, maxSegments));

  final double lat0 = location.latitude;
  final double metersPerDegLat = 111320.0;
  final double metersPerDegLng = 111320.0 * math.cos(lat0 * math.pi / 180.0);

  double toX(double lng) => (lng - location.longitude) * metersPerDegLng;
  double toY(double lat) => (lat - location.latitude) * metersPerDegLat;

  double bestD2 = double.infinity;
  int bestSeg = 0;
  double bestT = 0.0;
  double bestX = 0.0;
  double bestY = 0.0;

  for (int i = 0; i < limit; i++) {
    final a = polyline[i];
    final b = polyline[i + 1];

    final ax = toX(a.longitude);
    final ay = toY(a.latitude);
    final bx = toX(b.longitude);
    final by = toY(b.latitude);

    final abx = bx - ax;
    final aby = by - ay;
    final denom = (abx * abx) + (aby * aby);

    double t = 0.0;
    if (denom > 0) {
      // P is (0,0) since we centered on location
      t = ((-ax * abx) + (-ay * aby)) / denom;
      if (t < 0) t = 0;
      if (t > 1) t = 1;
    }

    final px = ax + (abx * t);
    final py = ay + (aby * t);
    final d2 = (px * px) + (py * py);

    if (d2 < bestD2) {
      bestD2 = d2;
      bestSeg = i;
      bestT = t;
      bestX = px;
      bestY = py;
    }
  }

  final snappedLat = location.latitude + (bestY / metersPerDegLat);
  final snappedLng = location.longitude + (bestX / metersPerDegLng);

  return PolylineSnapResult(
    point: LatLng(snappedLat, snappedLng),
    distanceMeters: math.sqrt(bestD2),
    segmentIndex: bestSeg,
    t: bestT,
  );
}

