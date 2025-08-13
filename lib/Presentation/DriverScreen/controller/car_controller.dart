import 'dart:ui';


import 'package:location/location.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class CarMarkerController {
  Marker? carMarker;
  double _lastRotation = 0.0;

  void updateCarMarker(LocationData newLocation) {
    double speed = newLocation.speed ?? 0.0;
    double heading = newLocation.heading ?? 0.0;

    LatLng newPosition = LatLng(newLocation.latitude!, newLocation.longitude!);

    // If moving and heading changed significantly, rotate
    if (speed > 1.0 && (heading - _lastRotation).abs() > 10.0) {
      _lastRotation = heading;
      carMarker = Marker(
        markerId: MarkerId("car"),
        position: newPosition,
        icon: BitmapDescriptor.defaultMarker, // Replace with custom car icon if needed
        rotation: heading,
        anchor: Offset(0.5, 0.5),
        flat: true,
      );
    } else {
      // Just update the position (no rotation)
      carMarker = Marker(
        markerId: MarkerId("car"),
        position: newPosition,
        icon: BitmapDescriptor.defaultMarker,
        rotation: _lastRotation, // Use last known good heading
        anchor: Offset(0.5, 0.5),
        flat: true,
      );
    }
  }
}
