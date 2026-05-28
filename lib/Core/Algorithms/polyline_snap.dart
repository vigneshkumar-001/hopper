import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'haversine.dart';
import '../../utils/map/polyline_snap.dart' as existing;

/// GPS road snapping helper.
///
/// This wraps the already-existing fast segment snap implementation in
/// `lib/utils/map/polyline_snap.dart` and applies a distance gate.
class PolylineSnapper {
  /// Snap [rawGps] to [polyline] only when within [maxSnapMeters] to avoid
  /// snapping to a wrong road during long off-route segments.
  LatLng snapToPolyline(
    LatLng rawGps,
    List<LatLng> polyline, {
    double maxSnapMeters = 30,
    int? maxSegments,
  }) {
    if (polyline.length < 2) return rawGps;
    final snap = existing.snapToPolyline(rawGps, polyline, maxSegments: maxSegments);
    if (!snap.distanceMeters.isFinite) return rawGps;
    return snap.distanceMeters <= maxSnapMeters ? snap.point : rawGps;
  }

  /// Computes minimum Haversine distance from a point to a polyline by sampling
  /// snapped point distance (fast enough for UI reroute checks).
  double distanceToPolylineMeters(
    LatLng point,
    List<LatLng> polyline, {
    int? maxSegments,
  }) {
    if (polyline.length < 2) return double.infinity;
    final snap = existing.snapToPolyline(point, polyline, maxSegments: maxSegments);
    // existing snap uses equirectangular meters; verify with haversine
    return Haversine.distanceMeters(point, snap.point);
  }
}

