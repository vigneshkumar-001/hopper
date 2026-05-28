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
  /// - Uses [previousNearestIndex] to search a local window (prevents snapping
  ///   to the wrong leg near U-turns / flyovers where the route comes close to
  ///   itself).
  /// - Produces completed + remaining polylines without flicker.
  static PolylineTrimResult trim({
    required List<LatLng> route,
    required LatLng vehicle,
    int lookAheadPoints = 80,
    int? previousNearestIndex,
    int backtrackPoints = 25,
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

    // Window the snap search to the vicinity of the last known progress to
    // avoid selecting a geographically-close but earlier segment (common when
    // the polyline has a U-turn and the two legs are near each other).
    final int maxSegIndex = route.length - 2; // last valid segment start
    final int hint = previousNearestIndex ?? -1;

    int windowStartSeg = 0;
    // With no hint (e.g. first paint), search the full route so we can handle
    // opening the screen mid-trip (already near the end of the polyline).
    int windowEndSeg = maxSegIndex;
    if (hint >= 0) {
      windowStartSeg = math.max(0, math.min(maxSegIndex, hint - backtrackPoints));
      windowEndSeg = math.min(maxSegIndex, hint + lookAheadPoints);
      if (windowEndSeg <= windowStartSeg) {
        windowStartSeg = math.max(0, windowEndSeg - 1);
      }
    }

    final int windowEndExclusivePoint = math.min(route.length, windowEndSeg + 2);
    final windowPolyline = route.sublist(windowStartSeg, windowEndExclusivePoint);

    final snapLocal = snapToPolyline(vehicle, windowPolyline);
    final snap = PolylineSnapResult(
      point: snapLocal.point,
      distanceMeters: snapLocal.distanceMeters,
      segmentIndex: windowStartSeg + snapLocal.segmentIndex,
      t: snapLocal.t,
    );

    final seg = snap.segmentIndex.clamp(0, route.length - 2);

    // Completed + remaining should split at the snapped segment, not at a
    // nearest vertex, otherwise U-turns can appear as a straight chord.
    final completed = <LatLng>[];
    if (seg > 0) {
      completed.addAll(route.sublist(0, seg));
      completed.add(snap.point);
    }
    final remaining = <LatLng>[snap.point, ...route.sublist(seg + 1)];

    return PolylineTrimResult(
      snapped: snap.point,
      snapDistanceMeters: snap.distanceMeters,
      nearestIndex: seg,
      remaining: remaining,
      completed: completed,
    );
  }

}
