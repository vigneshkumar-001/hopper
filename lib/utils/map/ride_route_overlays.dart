import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Shared polyline styling so single-ride and shared-ride maps look identical.
class RideRouteOverlays {
  static const Color _main = Color(0xFF111111);

  static Set<Polyline> buildRoutePolylines({
    required List<LatLng> routePoints,
    required LatLng origin,
    required LatLng destination,
    String idPrefix = 'route',
    Color mainColor = _main,
    Color outlineColor = Colors.white,
    double outlineOpacity = 0.95,
    int outlineWidth = 10,
    int mainWidth = 6,
    bool drawFallbackDottedLine = true,
  }) {
    if (routePoints.length >= 2) {
      return <Polyline>{
        Polyline(
          polylineId: PolylineId('${idPrefix}_outline'),
          color: outlineColor.withOpacity(outlineOpacity),
          width: outlineWidth,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
          jointType: JointType.round,
          points: routePoints,
        ),
        Polyline(
          polylineId: PolylineId('${idPrefix}_main'),
          color: mainColor,
          width: mainWidth,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
          jointType: JointType.round,
          points: routePoints,
        ),
      };
    }

    if (!drawFallbackDottedLine) return const <Polyline>{};

    // When directions are still loading (or fail), draw a subtle dotted line so
    // the map never looks "blank"/stuck.
    return <Polyline>{
      Polyline(
        polylineId: PolylineId('${idPrefix}_fallback'),
        color: mainColor.withOpacity(0.55),
        width: 4,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
        jointType: JointType.round,
        patterns: <PatternItem>[PatternItem.dot, PatternItem.gap(12)],
        points: <LatLng>[origin, destination],
      ),
    };
  }
}
