import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class CommonGoogleMap extends StatefulWidget {
  final LatLng initialPosition;
  final Set<Polyline> polylines;
  final Set<Marker> markers;
  final bool myLocationEnabled;
  final Function(GoogleMapController)? onMapCreated;

  const CommonGoogleMap({
    Key? key,
    required this.initialPosition,
    this.polylines = const {},
    this.markers = const {},
    this.myLocationEnabled = true,
    this.onMapCreated,
  }) : super(key: key);

  @override
  State<CommonGoogleMap> createState() => _CommonGoogleMapState();
}

class _CommonGoogleMapState extends State<CommonGoogleMap> {
  late GoogleMapController _controller;

  @override
  Widget build(BuildContext context) {
    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: widget.initialPosition,
        zoom: 16,
      ),
      polylines: widget.polylines,
      markers: widget.markers,
      myLocationEnabled: widget.myLocationEnabled,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      gestureRecognizers: {
        Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer()),
      },
      onMapCreated: (controller) {
        _controller = controller;
        if (widget.onMapCreated != null) {
          widget.onMapCreated!(controller);
        }
      },
    );
  }
}
