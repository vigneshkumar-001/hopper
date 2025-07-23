// import 'package:flutter_compass/flutter_compass.dart';
//
// import 'dart:async';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:geolocator/geolocator.dart';
// import 'package:google_maps_flutter/google_maps_flutter.dart';
// import 'package:hopper/Core/Utility/images.dart';
//
// class CompassMapScreen extends StatefulWidget {
//   const CompassMapScreen({Key? key}) : super(key: key);
//
//   @override
//   State<CompassMapScreen> createState() => _CompassMapScreenState();
// }
//
// class _CompassMapScreenState extends State<CompassMapScreen> {
//   GoogleMapController? _mapController;
//   LatLng? _currentPosition;
//   Marker? _carMarker;
//   BitmapDescriptor? _carIcon;
//   double _heading = 0;
//
//   StreamSubscription<Position>? _positionStream;
//   StreamSubscription<CompassEvent>? _compassStream;
//
//   @override
//   void initState() {
//     super.initState();
//     _loadCarIcon();
//     _startCompass();
//     _startLocationTracking();
//   }
//
//   /// Load custom car icon from asset
//   Future<void> _loadCarIcon() async {
//     _carIcon = await BitmapDescriptor.fromAssetImage(
//       const ImageConfiguration(size: Size(45, 45)),
//       AppImages.driverCarMove,
//     );
//   }
//
//   /// Start compass stream
//   void _startCompass() {
//     _compassStream = FlutterCompass.events?.listen((event) {
//       if (event.heading != null) {
//         setState(() {
//           _heading = event.heading!;
//         });
//         _updateCarMarker();
//       }
//     });
//   }
//
//   /// Start location tracking
//   void _startLocationTracking() async {
//     bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
//     LocationPermission permission = await Geolocator.checkPermission();
//     if (!serviceEnabled || permission == LocationPermission.denied) {
//       await Geolocator.requestPermission();
//     }
//
//     _positionStream = Geolocator.getPositionStream(
//       locationSettings: const LocationSettings(
//         accuracy: LocationAccuracy.bestForNavigation,
//         distanceFilter: 2,
//       ),
//     ).listen((position) {
//       setState(() {
//         _currentPosition = LatLng(position.latitude, position.longitude);
//       });
//
//       _updateCarMarker();
//
//       if (_mapController != null) {
//         _mapController!.animateCamera(
//           CameraUpdate.newLatLng(_currentPosition!),
//         );
//       }
//     });
//   }
//
//   /// Update the car marker with current heading and position
//   void _updateCarMarker() {
//     if (_currentPosition == null || _carIcon == null) return;
//
//     final marker = Marker(
//       markerId: const MarkerId('car'),
//       position: _currentPosition!,
//       icon: _carIcon!,
//       rotation: _heading,
//       anchor: const Offset(0.5, 0.5),
//       flat: true,
//     );
//
//     setState(() {
//       _carMarker = marker;
//     });
//   }
//
//   @override
//   void dispose() {
//     _positionStream?.cancel();
//     _compassStream?.cancel();
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Driver Compass Map'),
//         centerTitle: true,
//       ),
//       body: Stack(
//         children: [
//           GoogleMap(
//             initialCameraPosition: CameraPosition(
//               target: _currentPosition!, // Coimbatore
//               zoom: 16,
//             ),
//             onMapCreated: (controller) => _mapController = controller,
//             markers: _carMarker != null ? {_carMarker!} : {},
//             myLocationEnabled: false,
//             myLocationButtonEnabled: false,
//             zoomControlsEnabled: false,
//           ),
//           Positioned(
//             bottom: 20,
//             left: 20,
//             child: Text(
//               "Heading: ${_heading.toStringAsFixed(1)}°",
//               style: const TextStyle(fontSize: 18, color: Colors.black),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';

enum AppState {
  choosingLocation,
  confirmingFare,
  waitingForPickup,
  riding,
  postRide,
}

enum RideStatus { picking_up, riding, completed }

class Ride {
  final String id;
  final String driverId;
  final String passengerId;
  final int fare;
  final RideStatus status;

  Ride({
    required this.id,
    required this.driverId,
    required this.passengerId,
    required this.fare,
    required this.status,
  });

  factory Ride.fromJson(Map<String, dynamic> json) {
    return Ride(
      id: json['id'],
      driverId: json['driver_id'],
      passengerId: json['passenger_id'],
      fare: json['fare'],
      status: RideStatus.values.firstWhere(
        (e) => e.toString().split('.').last == json['status'],
      ),
    );
  }
}

class Driver {
  final String id;
  final String model;
  final String number;
  final bool isAvailable;
  final LatLng location;

  Driver({
    required this.id,
    required this.model,
    required this.number,
    required this.isAvailable,
    required this.location,
  });

  factory Driver.fromJson(Map<String, dynamic> json) {
    return Driver(
      id: json['id'],
      model: json['model'],
      number: json['number'],
      isAvailable: json['is_available'],
      location: LatLng(json['latitude'], json['longitude']),
    );
  }
}

class UberCloneMainScreen extends StatefulWidget {
  const UberCloneMainScreen({super.key});

  @override
  UberCloneMainScreenState createState() => UberCloneMainScreenState();
}

class UberCloneMainScreenState extends State<UberCloneMainScreen> {
  AppState _appState = AppState.choosingLocation;
  GoogleMapController? _mapController;
  CameraPosition _initialCameraPosition = const CameraPosition(
    target: LatLng(37.7749, -122.4194),
    zoom: 14.0,
  );

  LatLng? _selectedDestination;
  LatLng? _currentLocation;
  final Set<Polyline> _polylines = {};
  final Set<Marker> _markers = {};

  /// Fare in cents
  int? _fare;
  StreamSubscription<dynamic>? _driverSubscription;
  StreamSubscription<dynamic>? _rideSubscription;
  Driver? _driver;

  LatLng? _previousDriverLocation;
  BitmapDescriptor? _pinIcon;
  BitmapDescriptor? _carIcon;

  @override
  void initState() {
    super.initState();

    _checkLocationPermission();
    _loadIcons();
  }

  @override
  void dispose() {
    _cancelSubscriptions();
    super.dispose();
  }

  Future<void> _checkLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return _askForLocationPermission();
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return _askForLocationPermission();
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // Permissions are denied forever, handle appropriately.
      return _askForLocationPermission();
    }

    // When we reach here, permissions are granted and we can
    // continue accessing the position of the device.
    _getCurrentLocation();
  }

  /// Shows a modal to ask for location permission.
  Future<void> _askForLocationPermission() async {
    return showDialog(
      barrierDismissible: false,
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Location Permission'),
          content: const Text(
            'This app needs location permission to work properly.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                SystemChannels.platform.invokeMethod('SystemNavigator.pop');
              },
              child: const Text('Close App'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await Geolocator.openLocationSettings();
              },
              child: const Text('Open Settings'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition();
      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
        _initialCameraPosition = CameraPosition(
          target: _currentLocation!,
          zoom: 14.0,
        );
      });
      _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(_initialCameraPosition),
      );
    } catch (e) {
      debugPrint(e.toString());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error occured while getting the current location'),
          ),
        );
      }
    }
  }

  /// Loads the icon images used for markers
  Future<void> _loadIcons() async {
    const imageConfiguration = ImageConfiguration(size: Size(48, 48));
    _pinIcon = await BitmapDescriptor.asset(
      imageConfiguration,
      'assets/images/pin.png',
    );
    _carIcon = await BitmapDescriptor.asset(
      imageConfiguration,
      'assets/images/car.png',
    );
  }

  void _goToNextState() {
    setState(() {
      if (_appState == AppState.postRide) {
        _appState = AppState.values[_appState.index + 1];
      } else {
        _appState = AppState.choosingLocation;
      }
    });
  }

  void _onCameraMove(CameraPosition position) {
    if (_appState == AppState.choosingLocation) {
      _selectedDestination = position.target;
    }
  }

  /// Finds a nearby driver
  ///
  /// When a driver is found, it subscribes to the driver's location and ride status.

  void _updateDriverMarker(Driver driver) {
    setState(() {
      _markers.removeWhere((marker) => marker.markerId.value == 'driver');

      double rotation = 0;
      if (_previousDriverLocation != null) {
        rotation = _calculateRotation(
          _previousDriverLocation!,
          driver.location,
        );
      }

      _markers.add(
        Marker(
          markerId: const MarkerId('driver'),
          position: driver.location,
          icon: _carIcon!,
          anchor: const Offset(0.5, 0.5),
          rotation: rotation,
        ),
      );

      _previousDriverLocation = driver.location;
    });
  }

  void _adjustMapView({required LatLng target}) {
    if (_driver != null && _selectedDestination != null) {
      LatLngBounds bounds = LatLngBounds(
        southwest: LatLng(
          min(_driver!.location.latitude, target.latitude),
          min(_driver!.location.longitude, target.longitude),
        ),
        northeast: LatLng(
          max(_driver!.location.latitude, target.latitude),
          max(_driver!.location.longitude, target.longitude),
        ),
      );
      _mapController?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 100));
    }
  }

  double _calculateRotation(LatLng start, LatLng end) {
    double latDiff = end.latitude - start.latitude;
    double lngDiff = end.longitude - start.longitude;
    double angle = atan2(lngDiff, latDiff);
    return angle * 180 / pi;
  }

  void _cancelSubscriptions() {
    _driverSubscription?.cancel();
    _rideSubscription?.cancel();
  }

  /// Shows a modal to indicate that the ride has been completed.
  void _showCompletionModal() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Ride Completed'),
          content: const Text(
            'Thank you for using our service! We hope you had a great ride.',
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Close'),
              onPressed: () {
                Navigator.of(context).pop();
                _resetAppState();
              },
            ),
          ],
        );
      },
    );
  }

  void _resetAppState() {
    setState(() {
      _appState = AppState.choosingLocation;
      _selectedDestination = null;
      _driver = null;
      _fare = null;
      _polylines.clear();
      _markers.clear();
      _previousDriverLocation = null;
    });
    _getCurrentLocation();
  }

  String _getAppBarTitle() {
    switch (_appState) {
      case AppState.choosingLocation:
        return 'Choose Location';
      case AppState.confirmingFare:
        return 'Confirm Fare';
      case AppState.waitingForPickup:
        return 'Waiting for Pickup';
      case AppState.riding:
        return 'On the Way';
      case AppState.postRide:
        return 'Ride Completed';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_getAppBarTitle())),
      body: Stack(
        children: [
          _currentLocation == null
              ? const Center(child: CircularProgressIndicator())
              : GoogleMap(
                initialCameraPosition: _initialCameraPosition,
                onMapCreated: (GoogleMapController controller) {
                  _mapController = controller;
                },
                myLocationEnabled: true,
                onCameraMove: _onCameraMove,
                polylines: _polylines,
                markers: _markers,
              ),
        ],
      ),

      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      bottomSheet:
          _appState == AppState.confirmingFare ||
                  _appState == AppState.waitingForPickup
              ? Container(
                width: MediaQuery.of(context).size.width,
                padding: const EdgeInsets.all(
                  16,
                ).copyWith(bottom: 16 + MediaQuery.of(context).padding.bottom),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.5),
                      spreadRadius: 5,
                      blurRadius: 7,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_appState == AppState.confirmingFare) ...[
                      Text(
                        'Confirm Fare',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Estimated fare: ${NumberFormat.currency(
                          symbol: '\$', // You can change this to your preferred currency symbol
                          decimalDigits: 2,
                        ).format(_fare! / 100)}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (_appState == AppState.waitingForPickup &&
                        _driver != null) ...[
                      Text(
                        'Your Driver',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Car: ${_driver!.model}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Plate Number: ${_driver!.number}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Your driver is on the way. Please wait at the pickup location.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ],
                ),
              )
              : const SizedBox.shrink(),
    );
  }
}
