import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:hopper/utils/map/shared_map.dart';

class CommonGoogleMap extends StatelessWidget {
  final LatLng initialPosition;
  final Set<Polyline> polylines;
  final Set<Marker> markers;
  final bool myLocationEnabled;
  final Function(GoogleMapController)? onMapCreated;
  final VoidCallback? onCameraMoveStarted;
  final Function(CameraPosition)? onCameraMove;
  final VoidCallback? onCameraIdle;
  final Set<Circle> circles;
  final bool keepScreenOn;

  const CommonGoogleMap({
    super.key,
    this.circles = const <Circle>{},
    required this.initialPosition,
    this.polylines = const <Polyline>{},
    this.markers = const <Marker>{},
    this.onCameraMove,
    this.onCameraMoveStarted,
    this.onCameraIdle,
    this.myLocationEnabled = true,
    this.onMapCreated,
    this.keepScreenOn = true,
  });

  @override
  Widget build(BuildContext context) {
    return SharedMap(
      initialPosition: initialPosition,
      initialZoom: 15.2,
      polylines: polylines,
      markers: markers,
      circles: circles,
      myLocationEnabled: myLocationEnabled,
      fitToBounds: false,
      compassEnabled: false,
      keepScreenOn: keepScreenOn,
      tiltGesturesEnabled: false,
      onCameraMoveStarted: onCameraMoveStarted,
      onCameraMove: onCameraMove == null ? null : (p) => onCameraMove!(p),
      onCameraIdle: onCameraIdle,
      onMapCreated:
          onMapCreated == null ? null : (c) => onMapCreated!.call(c),
      gestureRecognizers: {
        Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer()),
      },
    );
  }
}

