import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'map_ui_config.dart';
import 'route_polyline_service.dart';
import 'travel_mode_resolver.dart';
import 'marker_icon_cache.dart';

class RerouteResult {
  final List<LatLng> points;
  final bool isFallbackStraightLine;

  const RerouteResult({required this.points, required this.isFallbackStraightLine});
}

/// Central reroute throttling + route replacement rules.
///
/// Keeps route API calls stable (no spam) and ensures we only replace the
/// visible route after a successful new route fetch.
class RerouteService {
  RerouteService({RoutePolylineService routeService = const RoutePolylineService()})
      : _routeService = routeService;

  final RoutePolylineService _routeService;

  DateTime _lastRerouteAt = DateTime.fromMillisecondsSinceEpoch(0);

  bool canReroute(DateTime now) =>
      now.difference(_lastRerouteAt) >= MapUiConfig.minRerouteInterval;

  void markReroute(DateTime now) => _lastRerouteAt = now;

  Future<RerouteResult?> reroute({
    required LatLng origin,
    required LatLng destination,
    required RideVehicleType vehicleType,
    required bool driverFriendlyStop,
    required DateTime now,
  }) async {
    if (!canReroute(now)) return null;
    markReroute(now);

    try {
      final mode = TravelModeResolver.getTravelMode(vehicleType);
      final res = await _routeService.fetchRoadRoute(
        origin: origin,
        destination: destination,
        driverFriendlyStop: driverFriendlyStop,
        mode: mode,
      );
      if (res.points.length < 2) return null;
      return RerouteResult(
        points: res.points,
        isFallbackStraightLine: res.isFallbackStraightLine,
      );
    } catch (_) {
      return null;
    }
  }
}
