import 'dart:math' as math;

import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:hopper/utils/map/polyline_snap.dart';

class PolylineTrimResult {
  final LatLng snapped;
  final double snapDistanceMeters;
  final int nearestIndex;
  final List<LatLng> remaining;
  final List<LatLng> completed;

  const PolylineTrimResult({
    required this.snapped,
    required this.snapDistanceMeters,
    required this.nearestIndex,
    required this.remaining,
    required this.completed,
  });
}

class PolylineTrimUtils {
  /// Trim a route polyline based on current vehicle position.
  ///
  /// - Snaps to nearest point on polyline (segment-based).
  /// - Finds a stable nearest index (point-based) within [lookAheadPoints].
  /// - Produces completed + remaining polylines without flicker.
  static PolylineTrimResult trim({
    required List<LatLng> route,
    required LatLng vehicle,
    int lookAheadPoints = 80,
  }) {
    if (route.length < 2) {
      return PolylineTrimResult(
        snapped: vehicle,
        snapDistanceMeters: double.infinity,
        nearestIndex: 0,
        remaining: route,
        completed: const <LatLng>[],
      );
    }

    final snap = snapToPolyline(vehicle, route, maxSegments: lookAheadPoints);

    // Find nearest vertex index near the snapped segment. This keeps trimming stable.
    final seg = snap.segmentIndex.clamp(0, route.length - 2);
    final i0 = seg;
    final i1 = seg + 1;

    final d0 = _distanceMeters(snap.point, route[i0]);
    final d1 = _distanceMeters(snap.point, route[i1]);
    final nearest = d0 <= d1 ? i0 : i1;

    final start = math.max(0, nearest - 1);
    final completed = start > 0 ? route.sublist(0, start) : const <LatLng>[];

    // Remaining: replace first point with snapped vehicle point to avoid gaps.
    final remainingBase = route.sublist(start);
    final remaining = <LatLng>[snap.point, ...remainingBase.skip(1)];

    return PolylineTrimResult(
      snapped: snap.point,
      snapDistanceMeters: snap.distanceMeters,
      nearestIndex: nearest,
      remaining: remaining,
      completed: completed,
    );
  }

  static double _distanceMeters(LatLng a, LatLng b) {
    // Fast equirectangular approx (sufficient for short distances in UI).
    final dx = (a.latitude - b.latitude) * 111320.0;
    final dy =
        (a.longitude - b.longitude) *
        111320.0 *
        math.cos(a.latitude * math.pi / 180.0);
    return math.sqrt(dx * dx + dy * dy);
  }
}

