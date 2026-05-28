import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:hopper/utils/map/route_info.dart';
import 'package:flutter/foundation.dart';

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
    Future<RoutePolylineResult?> attempt(String attemptMode) async {
      Map<String, dynamic> result;
      try {
        result = driverFriendlyStop
            ? await getDriverFriendlyRouteInfo(
                origin: origin,
                destination: destination,
                mode: attemptMode,
              )
            : await getRouteInfo(
                origin: origin,
                destination: destination,
                mode: attemptMode,
              );
      } catch (e) {
        if (kDebugMode) {
          debugPrint(
            '[ROUTE_API_FAIL] mode=$attemptMode driverFriendlyStop=$driverFriendlyStop '
            'origin=${origin.latitude},${origin.longitude} '
            'dest=${destination.latitude},${destination.longitude} err=$e',
          );
        }
        rethrow;
      }

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
      return null;
    }

    try {
      final first = await attempt(mode);
      if (first != null) return first;
    } catch (_) {
      // ignore (fallback below)
    }

    // If two-wheeler isn't supported for this API key/region, fall back to driving
    // before drawing a straight line. This keeps behavior production-friendly.
    if (mode == 'two_wheeler') {
      try {
        final driving = await attempt('driving');
        if (driving != null) return driving;
      } catch (_) {}
    }

    if (kDebugMode) {
      debugPrint(
        '[ROUTE_FALLBACK_STRAIGHT] origin=${origin.latitude},${origin.longitude} '
        'dest=${destination.latitude},${destination.longitude} mode=$mode',
      );
    }
    return RoutePolylineResult(
      points: <LatLng>[origin, destination],
      isFallbackStraightLine: true,
      adjustedDestination: null,
    );
  }
}
