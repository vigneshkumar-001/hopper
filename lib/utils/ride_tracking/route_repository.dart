import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Abstract route provider so we can switch between:
/// - backend-provided polylines
/// - Google Directions
/// - Mapbox/OSRM
/// without touching tracking / UI code.
abstract class RouteRepository {
  Future<RouteResult> fetchRoute({
    required LatLng origin,
    required LatLng destination,
    required String mode,
    bool driverFriendlyStop = false,
  });
}

class RouteResult {
  final List<LatLng> points;
  final bool isFallbackStraightLine;
  final LatLng? adjustedDestination;

  const RouteResult({
    required this.points,
    required this.isFallbackStraightLine,
    required this.adjustedDestination,
  });
}

