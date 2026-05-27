import 'marker_icon_cache.dart';

/// Central place to resolve travel-mode + thresholds per vehicle.
///
/// NOTE: Google Directions API support for 2-wheeler varies by region/account.
/// We keep this structured so we can switch to `two_wheeler` when supported
/// without touching screen code.
class TravelModeResolver {
  static String getTravelMode(RideVehicleType type) {
    switch (type) {
      case RideVehicleType.car:
        return 'driving';
      case RideVehicleType.bike:
      case RideVehicleType.packageBike:
        // Try 2-wheeler mode; `RoutePolylineService` already falls back to a
        // straight line on error, so higher-level callers remain stable.
        return 'two_wheeler';
    }
  }
}

