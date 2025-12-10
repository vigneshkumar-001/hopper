// lib/utils/map/driver_route.dart

import 'dart:async';
import 'dart:math' as math;

import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'route_info.dart';

class DriverRouteUpdate {
  final LatLng driverLocation;
  final double bearing;
  final List<LatLng> polylinePoints;
  final LatLng? nextPoint;
  final String directionText;
  final String distanceText;
  final String maneuver;

  DriverRouteUpdate({
    required this.driverLocation,
    required this.bearing,
    required this.polylinePoints,
    required this.nextPoint,
    required this.directionText,
    required this.distanceText,
    required this.maneuver,
  });
}

class DriverRouteController {
  DriverRouteController({
    required LatLng destination,
    required this.onRouteUpdate,
    this.onCameraUpdate,
  }) : _destination = destination;

  LatLng _destination;
  LatLng get destination => _destination;

  final void Function(DriverRouteUpdate update) onRouteUpdate;
  final void Function(CameraPosition position)? onCameraUpdate;

  LatLng? _current;
  LatLng? _last;
  double _bearing = 0;
  List<LatLng> _polyline = [];
  LatLng? _nextPoint;
  String _directionText = '';
  String _distanceText = '';
  String _maneuver = '';

  StreamSubscription<Position>? _positionSub;
  bool _animating = false;

  static const double _MAX_ACCURACY_M = 20.0;
  static const double _MIN_MOVE_METERS = 3.0;
  static const double _MIN_SPEED_MS = 1.0;
  static const double _HEADING_TRUST_MS = 2.0;
  static const double _MIN_TURN_DEG = 10.0;

  Future<void> start() async {
    final hasPermission = await _ensureLocationPermission();
    if (!hasPermission) return;

    final pos = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    _current = LatLng(pos.latitude, pos.longitude);
    _last = _current;

    await _fetchRoute(_current!, _destination);
    _emitUpdate();

    _startLocationStream();
  }

  Future<void> updateDestination(LatLng dest) async {
    _destination = dest;

    if (_current != null) {
      await _fetchRoute(_current!, _destination);
    }

    _emitUpdate();
  }

  Future<bool> _ensureLocationPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  void _startLocationStream() {
    _positionSub?.cancel();
    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 3,
      ),
    ).listen(_onPosition);
  }

  Future<void> _onPosition(Position position) async {
    final acc = position.accuracy.isFinite ? position.accuracy : 9999.0;
    if (acc > _MAX_ACCURACY_M) return;

    final newLoc = LatLng(position.latitude, position.longitude);
    final speed = position.speed.isFinite ? position.speed : 0.0;
    final heading = position.heading.isFinite ? position.heading : -1.0;

    if (_last == null) {
      _last = newLoc;
      _current = newLoc;
      _emitUpdate();
      return;
    }

    final moved = Geolocator.distanceBetween(
      _last!.latitude,
      _last!.longitude,
      newLoc.latitude,
      newLoc.longitude,
    );

    if (moved < _MIN_MOVE_METERS) return;

    double targetBearing = _bearing;

    if (speed >= _HEADING_TRUST_MS && heading >= 0) {
      targetBearing = heading;
    } else {
      targetBearing = _getBearing(_last!, newLoc);
    }

    final diff = _angleDeltaDeg(_bearing, targetBearing);
    if (speed < _MIN_SPEED_MS && diff < _MIN_TURN_DEG) {
      targetBearing = _bearing;
    }

    await _animateTo(newLoc, targetBearing);

    _last = newLoc;
    _current = newLoc;

    _updateRemainingPolyline(newLoc);

    if (_isOffRoute(newLoc)) {
      await _fetchRoute(newLoc, _destination);
    }

    _emitUpdate();
  }

  Future<void> _fetchRoute(LatLng origin, LatLng dest) async {
    final result = await getRouteInfo(origin: origin, destination: dest);

    _directionText = _parseHtmlString(result['direction']);
    _distanceText = result['distance'];
    _maneuver = result['maneuver'] ?? '';
    _polyline = decodePolyline(result['polyline']);

    if (_polyline.length >= 2) {
      _nextPoint = _polyline[1];
    } else if (_polyline.length == 1) {
      _nextPoint = _polyline[0];
    } else {
      _nextPoint = null;
    }
  }

  Future<void> _animateTo(LatLng to, double targetBearing) async {
    if (_current == null) {
      _current = to;
      _bearing = targetBearing;
      return;
    }

    if (_animating) {
      _current = to;
      _bearing = targetBearing;
      return;
    }

    _animating = true;

    final start = _current!;
    final startBearing = _bearing;
    final endBearing = _shortestAngle(startBearing, targetBearing);

    const steps = 30;
    const duration = Duration(milliseconds: 800);
    final interval = duration.inMilliseconds ~/ steps;

    for (int i = 1; i <= steps; i++) {
      await Future.delayed(Duration(milliseconds: interval));

      final t = i / steps;
      final lat = _lerp(start.latitude, to.latitude, t);
      final lng = _lerp(start.longitude, to.longitude, t);
      final newBearing = _lerpBearing(startBearing, endBearing, t);

      _current = LatLng(lat, lng);
      _bearing = _normalizeAngle(newBearing);

      _emitUpdate();
    }

    _animating = false;
  }

  void _emitUpdate() {
    if (_current == null) return;

    onRouteUpdate(
      DriverRouteUpdate(
        driverLocation: _current!,
        bearing: _bearing,
        polylinePoints: List<LatLng>.from(_polyline),
        nextPoint: _nextPoint,
        directionText: _directionText,
        distanceText: _distanceText,
        maneuver: _maneuver,
      ),
    );

    if (onCameraUpdate != null) {
      onCameraUpdate!(
        CameraPosition(target: _current!, zoom: 15, bearing: _bearing, tilt: 0),
      );
    }
  }

  void _updateRemainingPolyline(LatLng currentLocation) async {
    if (_polyline.isEmpty) return;

    int closestIndex = _getClosestPolylinePointIndex(currentLocation);
    if (closestIndex != -1 && closestIndex < _polyline.length) {
      _polyline = _polyline.sublist(closestIndex);

      if (_polyline.length >= 2) {
        _nextPoint = _polyline[1];

        final result = await getRouteInfo(
          origin: currentLocation,
          destination: _destination,
        );

        _directionText = _parseHtmlString(result['direction']);
        _distanceText = result['distance'];
        _maneuver = result['maneuver'] ?? '';
        _polyline = decodePolyline(result['polyline']);
      }
    }
  }

  int _getClosestPolylinePointIndex(LatLng position) {
    double minDistance = double.infinity;
    int closestIndex = -1;

    for (int i = 0; i < _polyline.length; i++) {
      final distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        _polyline[i].latitude,
        _polyline[i].longitude,
      );
      if (distance < minDistance) {
        minDistance = distance;
        closestIndex = i;
      }
    }
    return closestIndex;
  }

  bool _isOffRoute(LatLng currentLocation) {
    if (_polyline.isEmpty) return true;

    for (final point in _polyline) {
      final d = Geolocator.distanceBetween(
        currentLocation.latitude,
        currentLocation.longitude,
        point.latitude,
        point.longitude,
      );
      if (d < 20) return false;
    }
    return true;
  }

  double _lerp(double start, double end, double t) => start + (end - start) * t;

  double _lerpBearing(double start, double end, double t) {
    double difference = ((end - start + 540) % 360) - 180;
    return (start + difference * t + 360) % 360;
  }

  double _getBearing(LatLng start, LatLng end) {
    final lat1 = start.latitude * math.pi / 180;
    final lon1 = start.longitude * math.pi / 180;
    final lat2 = end.latitude * math.pi / 180;
    final lon2 = end.longitude * math.pi / 180;

    final dLon = lon2 - lon1;

    final y = math.sin(dLon) * math.cos(lat2);
    final x =
        math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);

    final bearing = math.atan2(y, x);
    return (bearing * 180 / math.pi + 360) % 360;
  }

  double _angleDeltaDeg(double a, double b) {
    double d = (b - a) % 360;
    if (d > 180) d -= 360;
    if (d < -180) d += 360;
    return d.abs();
  }

  double _shortestAngle(double from, double to) {
    double diff = (to - from) % 360;
    if (diff > 180) diff -= 360;
    return from + diff;
  }

  double _normalizeAngle(double a) {
    a %= 360;
    if (a < 0) a += 360;
    return a;
  }

  String _parseHtmlString(String htmlText) {
    return htmlText
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&');
  }

  void dispose() {
    _positionSub?.cancel();
  }
}

// // driver_route_controller.dart
// import 'dart:async';
// import 'dart:math' as math;
//
// import 'package:geolocator/geolocator.dart';
// import 'package:google_maps_flutter/google_maps_flutter.dart';
//
// import 'package:hopper/utils/map/route_info.dart'; // for getRouteInfo & decodePolyline
// import 'package:hopper/Core/Constants/log.dart';
//
// class DriverRouteUpdate {
//   final LatLng driverLocation;
//   final double bearing;
//   final List<LatLng> polylinePoints;
//   final LatLng? nextPoint;
//   final String directionText;
//   final String distanceText;
//   final String maneuver;
//
//   DriverRouteUpdate({
//     required this.driverLocation,
//     required this.bearing,
//     required this.polylinePoints,
//     required this.nextPoint,
//     required this.directionText,
//     required this.distanceText,
//     required this.maneuver,
//   });
// }
//
// typedef DriverRouteUpdateCallback = void Function(DriverRouteUpdate update);
// typedef CameraPositionCallback = void Function(CameraPosition position);
//
// class DriverRouteController {
//   final LatLng destination; // pickup point (customer)
//   final DriverRouteUpdateCallback onRouteUpdate;
//   final CameraPositionCallback? onCameraUpdate;
//
//   DriverRouteController({
//     required this.destination,
//     required this.onRouteUpdate,
//     this.onCameraUpdate,
//   });
//
//   // state
//   LatLng? _driverLocation;
//   LatLng? _lastPosition;
//   double _carBearing = 0.0;
//   List<LatLng> _polylinePoints = [];
//   LatLng? _nextPoint;
//   String _directionText = '';
//   String _distanceText = '';
//   String _maneuver = '';
//
//   StreamSubscription<Position>? _positionStream;
//   bool _disposed = false;
//
//   // thresholds
//   static const double _MAX_ACCURACY_M = 20.0;
//   static const double _MIN_MOVE_METERS = 3.0;
//   static const double _MIN_SPEED_MS = 1.0;
//   static const double _HEADING_TRUST_MS = 2.0;
//   static const double _MIN_TURN_DEG = 10.0;
//
//   Future<void> start() async {
//     if (_disposed) return;
//
//     final hasPermission = await _ensureLocationPermission();
//     if (!hasPermission) {
//       CommonLogger.log.w('⚠️ DriverRouteController: no location permission');
//       return;
//     }
//
//     // initial position
//     final position = await Geolocator.getCurrentPosition(
//       desiredAccuracy: LocationAccuracy.high,
//     );
//
//     _driverLocation = LatLng(position.latitude, position.longitude);
//     _lastPosition = _driverLocation;
//
//     // initial route
//     await _fetchRoute(origin: _driverLocation!);
//
//     // start tracking
//     _startTracking();
//   }
//
//   void dispose() {
//     _disposed = true;
//     _positionStream?.cancel();
//   }
//
//   // Public for screen (if you want)
//   LatLng? get currentDriverLocation => _driverLocation;
//   List<LatLng> get polylinePoints => _polylinePoints;
//
//   // ------------------ INTERNAL -----------------------
//
//   Future<bool> _ensureLocationPermission() async {
//     final serviceEnabled = await Geolocator.isLocationServiceEnabled();
//     if (!serviceEnabled) return false;
//
//     LocationPermission permission = await Geolocator.checkPermission();
//     if (permission == LocationPermission.denied) {
//       permission = await Geolocator.requestPermission();
//     }
//     return permission == LocationPermission.always ||
//         permission == LocationPermission.whileInUse;
//   }
//
//   Future<void> _fetchRoute({required LatLng origin}) async {
//     final result = await getRouteInfo(
//       origin: origin,
//       destination: destination,
//     );
//
//     _directionText = result['direction'];
//     _distanceText = result['distance'];
//     _maneuver = result['maneuver'] ?? '';
//     _polylinePoints = decodePolyline(result['polyline']);
//
//     if (_polylinePoints.length >= 2) {
//       _nextPoint = _polylinePoints[1];
//     } else if (_polylinePoints.length == 1) {
//       _nextPoint = _polylinePoints[0];
//     } else {
//       _nextPoint = null;
//     }
//
//     if (_driverLocation != null) {
//       _emitUpdate();
//     }
//   }
//
//   void _startTracking() {
//     _positionStream = Geolocator.getPositionStream(
//       locationSettings: const LocationSettings(
//         accuracy: LocationAccuracy.bestForNavigation,
//         distanceFilter: 3,
//       ),
//     ).listen((position) async {
//       if (_disposed) return;
//
//       final current = LatLng(position.latitude, position.longitude);
//       final acc =
//       (position.accuracy.isFinite) ? position.accuracy : 9999.0;
//       final speed = (position.speed.isFinite) ? position.speed : 0.0;
//       final heading =
//       (position.heading.isFinite) ? position.heading : -1.0;
//
//       if (acc > _MAX_ACCURACY_M) return;
//
//       if (_lastPosition == null) {
//         _lastPosition = current;
//         _driverLocation = current;
//         _emitUpdate();
//         return;
//       }
//
//       final moved = Geolocator.distanceBetween(
//         _lastPosition!.latitude,
//         _lastPosition!.longitude,
//         current.latitude,
//         current.longitude,
//       );
//
//       final significantMove = moved >= _MIN_MOVE_METERS;
//       double targetBearing = _carBearing;
//
//       if (significantMove) {
//         if (speed >= _HEADING_TRUST_MS && heading >= 0) {
//           targetBearing = heading;
//         } else {
//           targetBearing = _getBearing(_lastPosition!, current);
//         }
//
//         final diff = _angleDeltaDeg(_carBearing, targetBearing);
//         if (speed < _MIN_SPEED_MS && diff < _MIN_TURN_DEG) {
//           targetBearing = _carBearing;
//         }
//
//         await _animateCarTo(
//           to: current,
//           overrideBearing: targetBearing,
//         );
//
//         _lastPosition = current;
//         _driverLocation = current;
//
//         _updateRemainingPolyline(current);
//         if (_isOffRoute(current)) {
//           await _fetchRoute(origin: current);
//         }
//       } else {
//         _lastPosition = current;
//         _driverLocation = current;
//         _emitUpdate(); // position changed a bit, still update
//       }
//     });
//   }
//
//   Future<void> _animateCarTo({
//     required LatLng to,
//     double? overrideBearing,
//   }) async {
//     if (_driverLocation == null || _isSameLocation(_driverLocation!, to)) {
//       return;
//     }
//
//     final start = _driverLocation!;
//     final end = to;
//
//     final startBearing = _carBearing;
//     final endBearingRaw =
//     (overrideBearing != null) ? overrideBearing : _getBearing(start, end);
//     final endBearing = _shortestAngle(startBearing, endBearingRaw);
//
//     const steps = 30;
//     const duration = Duration(milliseconds: 800);
//     final interval = duration.inMilliseconds ~/ steps;
//
//     for (int i = 1; i <= steps; i++) {
//       if (_disposed) return;
//
//       await Future.delayed(Duration(milliseconds: interval));
//       final t = i / steps;
//
//       final lat = _lerp(start.latitude, end.latitude, t);
//       final lng = _lerp(start.longitude, end.longitude, t);
//       final newBearing = _lerpBearing(startBearing, endBearing, t);
//
//       _driverLocation = LatLng(lat, lng);
//       _carBearing = _normalizeAngle(newBearing);
//
//       _emitUpdate();
//
//       if (onCameraUpdate != null) {
//         onCameraUpdate!(
//           CameraPosition(
//             target: _driverLocation!,
//             zoom: 17,
//             bearing: _carBearing,
//             tilt: 60,
//           ),
//         );
//       }
//     }
//   }
//
//   void _updateRemainingPolyline(LatLng currentLocation) async {
//     if (_polylinePoints.isEmpty) return;
//
//     int closestIndex = _getClosestPolylinePointIndex(currentLocation);
//     if (closestIndex != -1 && closestIndex < _polylinePoints.length) {
//       _polylinePoints = _polylinePoints.sublist(closestIndex);
//
//       if (_polylinePoints.length >= 2) {
//         _nextPoint = _polylinePoints[1];
//
//         final result = await getRouteInfo(
//           origin: currentLocation,
//           destination: destination,
//         );
//
//         _directionText = result['direction'];
//         _distanceText = result['distance'];
//         _maneuver = result['maneuver'] ?? '';
//       }
//     }
//   }
//
//   bool _isOffRoute(LatLng currentLocation) {
//     if (_polylinePoints.isEmpty) return true;
//
//     for (final point in _polylinePoints) {
//       final d = Geolocator.distanceBetween(
//         currentLocation.latitude,
//         currentLocation.longitude,
//         point.latitude,
//         point.longitude,
//       );
//       if (d < 20) return false;
//     }
//     return true;
//   }
//
//   // ----------------- small helpers -------------------
//
//   void _emitUpdate() {
//     if (_driverLocation == null) return;
//
//     onRouteUpdate(
//       DriverRouteUpdate(
//         driverLocation: _driverLocation!,
//         bearing: _carBearing,
//         polylinePoints: List<LatLng>.from(_polylinePoints),
//         nextPoint: _nextPoint,
//         directionText: _directionText,
//         distanceText: _distanceText,
//         maneuver: _maneuver,
//       ),
//     );
//   }
//
//   bool _isSameLocation(LatLng a, LatLng b) {
//     return (a.latitude - b.latitude).abs() < 0.00001 &&
//         (a.longitude - b.longitude).abs() < 0.00001;
//   }
//
//   double _angleDeltaDeg(double a, double b) {
//     double d = (b - a) % 360;
//     if (d > 180) d -= 360;
//     if (d < -180) d += 360;
//     return d.abs();
//   }
//
//   double _shortestAngle(double from, double to) {
//     double diff = (to - from) % 360;
//     if (diff > 180) diff -= 360;
//     return from + diff;
//   }
//
//   double _normalizeAngle(double a) {
//     a %= 360;
//     if (a < 0) a += 360;
//     return a;
//   }
//
//   double _lerp(double start, double end, double t) =>
//       start + (end - start) * t;
//
//   double _lerpBearing(double start, double end, double t) {
//     double difference = ((end - start + 540) % 360) - 180;
//     return (start + difference * t + 360) % 360;
//   }
//
//   int _getClosestPolylinePointIndex(LatLng position) {
//     double minDistance = double.infinity;
//     int closestIndex = -1;
//
//     for (int i = 0; i < _polylinePoints.length; i++) {
//       final distance = Geolocator.distanceBetween(
//         position.latitude,
//         position.longitude,
//         _polylinePoints[i].latitude,
//         _polylinePoints[i].longitude,
//       );
//       if (distance < minDistance) {
//         minDistance = distance;
//         closestIndex = i;
//       }
//     }
//     return closestIndex;
//   }
//
//   double _getBearing(LatLng start, LatLng end) {
//     final lat1 = start.latitude * math.pi / 180;
//     final lon1 = start.longitude * math.pi / 180;
//     final lat2 = end.latitude * math.pi / 180;
//     final lon2 = end.longitude * math.pi / 180;
//
//     final dLon = lon2 - lon1;
//     final y = math.sin(dLon) * math.cos(lat2);
//     final x =
//         math.cos(lat1) * math.sin(lat2) -
//             math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
//
//     final bearing = math.atan2(y, x);
//     return (bearing * 180 / math.pi + 360) % 360;
//   }
// }
