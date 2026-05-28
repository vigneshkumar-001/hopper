import 'dart:math' as math;

import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Haversine distance in meters between two coordinates.
///
/// Use this for "business logic" (arrival detection, radius checks, etc.).
class Haversine {
  static const double _earthRadiusM = 6371000.0;

  static double distanceMeters(LatLng a, LatLng b) {
    final dLat = _degToRad(b.latitude - a.latitude);
    final dLon = _degToRad(b.longitude - a.longitude);
    final lat1 = _degToRad(a.latitude);
    final lat2 = _degToRad(b.latitude);

    final sinDLat = math.sin(dLat / 2);
    final sinDLon = math.sin(dLon / 2);
    final aa =
        sinDLat * sinDLat +
        math.cos(lat1) * math.cos(lat2) * sinDLon * sinDLon;
    return _earthRadiusM * 2 * math.atan2(math.sqrt(aa), math.sqrt(1 - aa));
  }

  static double _degToRad(double deg) => deg * math.pi / 180.0;
}

