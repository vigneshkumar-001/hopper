import 'package:flutter_compass/flutter_compass.dart';

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:hopper/Core/Utility/images.dart';

class CompassMapScreen extends StatefulWidget {
  const CompassMapScreen({Key? key}) : super(key: key);

  @override
  State<CompassMapScreen> createState() => _CompassMapScreenState();
}

class _CompassMapScreenState extends State<CompassMapScreen> {
  GoogleMapController? _mapController;
  LatLng? _currentPosition;
  Marker? _carMarker;
  BitmapDescriptor? _carIcon;
  double _heading = 0;

  StreamSubscription<Position>? _positionStream;
  StreamSubscription<CompassEvent>? _compassStream;

  @override
  void initState() {
    super.initState();
    _loadCarIcon();
    _startCompass();
    _startLocationTracking();
  }

  /// Load custom car icon from asset
  Future<void> _loadCarIcon() async {
    _carIcon = await BitmapDescriptor.fromAssetImage(
      const ImageConfiguration(size: Size(45, 45)),
      AppImages.driverCarMove,
    );
  }

  /// Start compass stream
  void _startCompass() {
    _compassStream = FlutterCompass.events?.listen((event) {
      if (event.heading != null) {
        setState(() {
          _heading = event.heading!;
        });
        _updateCarMarker();
      }
    });
  }

  /// Start location tracking
  void _startLocationTracking() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    LocationPermission permission = await Geolocator.checkPermission();
    if (!serviceEnabled || permission == LocationPermission.denied) {
      await Geolocator.requestPermission();
    }

    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 2,
      ),
    ).listen((position) {
      setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);
      });

      _updateCarMarker();

      if (_mapController != null) {
        _mapController!.animateCamera(
          CameraUpdate.newLatLng(_currentPosition!),
        );
      }
    });
  }

  /// Update the car marker with current heading and position
  void _updateCarMarker() {
    if (_currentPosition == null || _carIcon == null) return;

    final marker = Marker(
      markerId: const MarkerId('car'),
      position: _currentPosition!,
      icon: _carIcon!,
      rotation: _heading,
      anchor: const Offset(0.5, 0.5),
      flat: true,
    );

    setState(() {
      _carMarker = marker;
    });
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _compassStream?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver Compass Map'),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _currentPosition!, // Coimbatore
              zoom: 16,
            ),
            onMapCreated: (controller) => _mapController = controller,
            markers: _carMarker != null ? {_carMarker!} : {},
            myLocationEnabled: false,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
          ),
          Positioned(
            bottom: 20,
            left: 20,
            child: Text(
              "Heading: ${_heading.toStringAsFixed(1)}°",
              style: const TextStyle(fontSize: 18, color: Colors.black),
            ),
          ),
        ],
      ),
    );
  }
}
