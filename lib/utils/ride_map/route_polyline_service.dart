import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:hopper/utils/map/route_info.dart';

class RoutePolylineResult {
  final List<LatLng> points;
  final bool isFallbackStraightLine;
  final LatLng? adjustedDestination;

  const RoutePolylineResult({
    required this.points,
    required this.isFallbackStraightLine,
    required this.adjustedDestination,
  });
}

/// Centralized route fetcher (Directions API).
///
/// NOTE: This uses existing `getRouteInfo` / `getDriverFriendlyRouteInfo` so we
/// keep behavior stable while centralizing access and fallback behavior.
class RoutePolylineService {
  const RoutePolylineService();

  Future<RoutePolylineResult> fetchRoadRoute({
    required LatLng origin,
    required LatLng destination,
    bool driverFriendlyStop = false,
    String mode = 'driving',
  }) async {
    try {
      final result = driverFriendlyStop
          ? await getDriverFriendlyRouteInfo(
              origin: origin,
              destination: destination,
              mode: mode,
            )
          : await getRouteInfo(
              origin: origin,
              destination: destination,
              mode: mode,
            );

      final poly = (result['polyline'] ?? '').toString();
      final pts = decodePolyline(poly);
      final adjusted = result['adjustedDestination'];
      LatLng? adjustedDest;
      if (adjusted is Map) {
        final lat = (adjusted['lat'] as num?)?.toDouble();
        final lng = (adjusted['lng'] as num?)?.toDouble();
        if (lat != null && lng != null) adjustedDest = LatLng(lat, lng);
      }

      if (pts.length >= 2) {
        return RoutePolylineResult(
          points: pts,
          isFallbackStraightLine: false,
          adjustedDestination: adjustedDest,
        );
      }
    } catch (_) {}

    return RoutePolylineResult(
      points: <LatLng>[origin, destination],
      isFallbackStraightLine: true,
      adjustedDestination: null,
    );
  }
}

