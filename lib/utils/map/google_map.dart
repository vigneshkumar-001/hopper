import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:hopper/utils/map/app_map_style.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class CommonGoogleMap extends StatefulWidget {
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
  State<CommonGoogleMap> createState() => _CommonGoogleMapState();
}

class _CommonGoogleMapState extends State<CommonGoogleMap> {
  GoogleMapController? _mapController;
  String? _mapStyle;

  @override
  void initState() {
    super.initState();
    _setKeepAwake(true);
    _loadMapStyle();
  }

  @override
  void dispose() {
    try {
      _mapController?.dispose();
    } catch (_) {}
    _setKeepAwake(false);
    super.dispose();
  }

  Future<void> _loadMapStyle() async {
    try {
      final style = await AppMapStyle.loadUberLight();
      _mapStyle = style;
      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> _setKeepAwake(bool enabled) async {
    if (!widget.keepScreenOn) return;
    try {
      await WakelockPlus.toggle(enable: enabled);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return GoogleMap(
      style: _mapStyle,
      onCameraMove: widget.onCameraMove,
      initialCameraPosition: CameraPosition(
        target: widget.initialPosition,
        zoom: 15.2,
      ),
      onCameraMoveStarted: widget.onCameraMoveStarted,
      onCameraIdle: widget.onCameraIdle,
      polylines: widget.polylines,
      markers: widget.markers,
      myLocationEnabled: widget.myLocationEnabled,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      circles: widget.circles,
      compassEnabled: false,
      mapToolbarEnabled: false,
      rotateGesturesEnabled: true,
      tiltGesturesEnabled: false,
      trafficEnabled: false,
      buildingsEnabled: false,
      indoorViewEnabled: false,
      gestureRecognizers: {
        Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer()),
      },
      onMapCreated: (controller) async {
        _mapController = controller;
        if (widget.onMapCreated != null) {
          widget.onMapCreated!(controller);
        }
      },
    );
  }
}
