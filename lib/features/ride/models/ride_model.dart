import '../../../Core/Services/route_service.dart';

class FareCalculator {
  static double calculateFare({
    required double distanceKm,
    required double durationMinutes,
    required VehicleType vehicleType,
    required double surgeFactor,
  }) {
    double baseFare, perKmRate, perMinRate, minimumFare;

    switch (vehicleType) {
      case VehicleType.bike:
        baseFare = 20.0;
        perKmRate = 8.0;
        perMinRate = 0.5;
        minimumFare = 30.0;
        break;
      case VehicleType.auto:
        baseFare = 25.0;
        perKmRate = 12.0;
        perMinRate = 0.75;
        minimumFare = 40.0;
        break;
      case VehicleType.car:
        baseFare = 50.0;
        perKmRate = 16.0;
        perMinRate = 1.0;
        minimumFare = 80.0;
        break;
    }

    final rawFare = baseFare + (perKmRate * distanceKm) + (perMinRate * durationMinutes);
    final surgedFare = rawFare * surgeFactor;
    return surgedFare < minimumFare ? minimumFare : surgedFare;
  }

  static double calculateSurgeFactor({
    required int activeRideRequests,
    required int availableDrivers,
  }) {
    if (availableDrivers <= 0) return 2.5;
    final ratio = activeRideRequests / availableDrivers;
    if (ratio < 1.2) return 1.0;
    if (ratio < 1.5) return 1.2;
    if (ratio < 2.0) return 1.5;
    if (ratio < 3.0) return 2.0;
    return 2.5;
  }
}
