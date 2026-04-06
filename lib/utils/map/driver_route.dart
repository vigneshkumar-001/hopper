// lib/utils/map/driver_route.dart

import 'dart:async';
import 'dart:math' as math;

import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'route_info.dart';
import 'polyline_snap.dart';

class DriverRouteUpdate {
  final LatLng driverLocation;
  final LatLng destination;
  final double bearing;
  final List<LatLng> polylinePoints;
  final LatLng? nextPoint;
  final String directionText;
  final String distanceText;
  final String maneuver;
  final String laneGuidance;
  final List<Map<String, dynamic>> maneuverPoints;

  DriverRouteUpdate({
    required this.driverLocation,
    required this.destination,
    required this.bearing,
    required this.polylinePoints,
    required this.nextPoint,
    required this.directionText,
    required this.distanceText,
    required this.maneuver,
    required this.laneGuidance,
    required this.maneuverPoints,
  });
}

class DriverRouteController {
  DriverRouteController({
    required LatLng destination,
    required this.onRouteUpdate,
    this.onCameraUpdate,
    this.initialLocation,
  }) : _destination = destination;

  LatLng _destination;
  LatLng get destination => _destination;
  LatLng? _adjustedDestination;

  final void Function(DriverRouteUpdate update) onRouteUpdate;
  final void Function(CameraPosition position)? onCameraUpdate;
  final LatLng? initialLocation;

  // Raw GPS
  LatLng? _currentRaw;
  LatLng? _lastRaw;

  // Display (animated) state
  LatLng? _displayLoc;
  double _displayBearing = 0.0;

  // Target for animation
  LatLng? _animFrom;
  LatLng? _animTo;
  double _bearingFrom = 0.0;
  double _bearingTo = 0.0;
  int _animDurationMs = 700;
  DateTime? _animStartAt;

  // Route info
  List<LatLng> _polyline = <LatLng>[];
  LatLng? _nextPoint;

  String _directionText = '';
  String _distanceText = '';
  String _maneuver = '';
  String _laneGuidance = '';
  List<Map<String, dynamic>> _maneuverPoints = const <Map<String, dynamic>>[];

  StreamSubscription<Position>? _positionSub;

  // Animation timer (smooth movement)
  Timer? _animTimer;

  // ---------------- tuning ----------------
  static const double _MAX_ACCURACY_M = 25.0;
  static const double _MIN_MOVE_METERS = 2.0;
  static const double _STATIONARY_DRIFT_M = 8.0;

  static const double _MIN_SPEED_MS = 1.0;
  static const double _HEADING_TRUST_SPEED_MS = 2.0;
  static const double _MIN_TURN_DEG = 8.0;
  static const double _SNAP_TOLERANCE_M = 35.0;

  // Route refresh throttles
  static const int _ROUTE_REFRESH_MIN_SEC = 10;
  static const double _OFFROUTE_THRESHOLD_M = 25.0;
  static const double _POLYLINE_TRIM_TOLERANCE_M = 30.0;
  static const int _POLYLINE_TRIM_LOOKAHEAD_POINTS = 40;
  static const int _OFF_ROUTE_LOOKAHEAD_POINTS = 80;
  DateTime? _lastRouteFetchAt;

  // Bearing smoothing (raw)
  static const double _BEARING_SMOOTH_ALPHA = 0.35;

  // Animation FPS
  static const int _ANIM_FPS = 30; // Uber-like smoothness
  static const int _ANIM_TICK_MS = 1000 ~/ _ANIM_FPS;

  Future<void> start() async {
    final hasPermission = await _ensureLocationPermission();
    if (!hasPermission) {
      final fallbackStart = initialLocation;
      if (fallbackStart == null) return;

      _currentRaw = fallbackStart;
      _lastRaw = fallbackStart;
      _displayLoc = fallbackStart;
      _displayBearing = 0.0;

      await _fetchRoute(fallbackStart, _destination, force: true);
      _emitUpdate();
      return;
    }

    final pos = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    _currentRaw = LatLng(pos.latitude, pos.longitude);
    _lastRaw = _currentRaw;

    // init display
    _displayLoc = _currentRaw;
    _displayBearing = 0.0;

    await _fetchRoute(_currentRaw!, _destination, force: true);

    // emit initial
    _emitUpdate();

    _startLocationStream();
    _startAnimLoop(); // ✅ start smooth animation loop
  }

  Future<void> updateDestination(LatLng dest) async {
    _destination = dest;

    final origin = _currentRaw ?? _displayLoc;
    if (origin != null) {
      await _fetchRoute(origin, _destination, force: true);
      _emitUpdate();
    }
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
        distanceFilter: 2,
      ),
    ).listen(_onPosition);
  }

  void _startAnimLoop() {
    _animTimer?.cancel();
    _animTimer = Timer.periodic(const Duration(milliseconds: _ANIM_TICK_MS), (
      _,
    ) {
      _tickAnimation();
    });
  }

  Future<void> _onPosition(Position position) async {
    final acc = position.accuracy.isFinite ? position.accuracy : 9999.0;
    if (acc > _MAX_ACCURACY_M) return;

    final rawLoc = LatLng(position.latitude, position.longitude);
    final newLoc = _maybeSnapToRoute(rawLoc);

    if (_lastRaw == null) {
      _lastRaw = rawLoc;
      _currentRaw = rawLoc;
      _displayLoc ??= newLoc;
      return;
    }

    final moved = Geolocator.distanceBetween(
      _lastRaw!.latitude,
      _lastRaw!.longitude,
      rawLoc.latitude,
      rawLoc.longitude,
    );

    if (moved < _MIN_MOVE_METERS) return;

    final speed = position.speed.isFinite ? position.speed : 0.0;
    final heading = position.heading.isFinite ? position.heading : -1.0;

    // Keep orientation stable when almost stationary (GPS drift only).
    if (speed < _MIN_SPEED_MS && moved < _STATIONARY_DRIFT_M) {
      _currentRaw = rawLoc;
      _lastRaw = rawLoc;
      _displayLoc = newLoc;
      _emitUpdate();
      return;
    }

    // ---------- target bearing (raw) ----------
    double targetBearing;
    if (speed < _MIN_SPEED_MS) {
      targetBearing = _displayBearing;
    } else if (speed >= _HEADING_TRUST_SPEED_MS && heading >= 0) {
      targetBearing = heading;
    } else {
      targetBearing = _getBearing(_lastRaw!, newLoc);
    }

    // Prevent micro-rotation at low speed
    final diff = _angleDeltaDeg(_displayBearing, targetBearing);
    if (speed < _MIN_SPEED_MS && diff < _MIN_TURN_DEG) {
      targetBearing = _displayBearing;
    }

    // Smooth bearing (raw → target)
    final smoothedBearing = _smoothBearing(
      _displayBearing,
      targetBearing,
      _BEARING_SMOOTH_ALPHA,
    );

    _currentRaw = rawLoc;

    // ✅ Update animation target (from current display → new gps)
    _setAnimationTarget(
      from: _displayLoc ?? _lastRaw!,
      to: newLoc,
      bearingFrom: _displayBearing,
      bearingTo: smoothedBearing,
      speedMs: speed,
      movedMeters: moved,
    );

    _lastRaw = rawLoc;

    // Update remaining polyline cheaply (no API)
    _trimPolylineToCurrent(newLoc);

    // If off-route, fetch new route (throttled)
    if (_shouldRefetchRoute(rawLoc)) {
      await _fetchRoute(rawLoc, _destination);
    }
  }

  LatLng _maybeSnapToRoute(LatLng raw) {
    if (_polyline.length < 6) return raw;
    final snap = snapToPolyline(
      raw,
      _polyline,
      maxSegments: _OFF_ROUTE_LOOKAHEAD_POINTS,
    );
    return snap.distanceMeters <= _SNAP_TOLERANCE_M ? snap.point : raw;
  }

  void _setAnimationTarget({
    required LatLng from,
    required LatLng to,
    required double bearingFrom,
    required double bearingTo,
    required double speedMs,
    required double movedMeters,
  }) {
    _animFrom = from;
    _animTo = to;
    _bearingFrom = _normalizeAngle(bearingFrom);
    _bearingTo = _normalizeAngle(bearingTo);

    // ✅ Duration: based on speed/distance (clamped)
    // if speed is invalid, use movedMeters to estimate.
    int ms;
    if (speedMs.isFinite && speedMs > 0.5) {
      ms = ((movedMeters / speedMs) * 1000).round();
    } else {
      // fallback: 5 m/s guess
      ms = ((movedMeters / 5.0) * 1000).round();
    }

    // clamp to feel natural
    _animDurationMs = ms.clamp(280, 1100);
    _animStartAt = DateTime.now();
  }

  void _tickAnimation() {
    if (_animFrom == null || _animTo == null || _animStartAt == null) {
      return;
    }

    final elapsed = DateTime.now().difference(_animStartAt!).inMilliseconds;
    final t = (elapsed / _animDurationMs).clamp(0.0, 1.0);

    // Smooth curve
    final eased = _easeOutCubic(t);

    // Interpolate LatLng
    final LatLng from = _animFrom!;
    final LatLng to = _animTo!;
    _displayLoc = LatLng(
      _lerp(from.latitude, to.latitude, eased),
      _lerp(from.longitude, to.longitude, eased),
    );

    // Interpolate bearing (shortest angle)
    _displayBearing = _lerpAngle(_bearingFrom, _bearingTo, eased);

    // Emit frequently (smooth marker)
    _emitUpdate();

    // finish
    if (t >= 1.0) {
      _animFrom = _animTo;
      _animStartAt = null;
    }
  }

  double _easeOutCubic(double t) => 1 - math.pow(1 - t, 3).toDouble();

  double _lerp(double a, double b, double t) => a + (b - a) * t;

  double _lerpAngle(double a, double b, double t) {
    a = _normalizeAngle(a);
    b = _normalizeAngle(b);

    double diff = (b - a) % 360;
    if (diff > 180) diff -= 360;
    if (diff < -180) diff += 360;

    return _normalizeAngle(a + diff * t);
  }

  bool _shouldRefetchRoute(LatLng loc) {
    if (_polyline.isEmpty) return true;

    final off = _isOffRoute(loc);
    if (!off) return false;

    final now = DateTime.now();
    if (_lastRouteFetchAt == null) return true;
    final diff = now.difference(_lastRouteFetchAt!).inSeconds;
    return diff >= _ROUTE_REFRESH_MIN_SEC;
  }

  Future<void> _fetchRoute(
    LatLng origin,
    LatLng dest, {
    bool force = false,
  }) async {
    final now = DateTime.now();
    if (!force && _lastRouteFetchAt != null) {
      final diff = now.difference(_lastRouteFetchAt!).inSeconds;
      if (diff < _ROUTE_REFRESH_MIN_SEC) return;
    }

    _lastRouteFetchAt = now;

    try {
      final result = await getDriverFriendlyRouteInfo(
        origin: origin,
        destination: dest,
        maxAdjustMeters: 140,
      );

      _directionText = _parseHtmlString(result['direction']);
      _distanceText = (result['distance'] ?? '').toString();
      _maneuver = (result['maneuver'] ?? '').toString();
      _laneGuidance = (result['laneGuidance'] ?? '').toString();
      _polyline = decodePolyline((result['polyline'] ?? '').toString());

      final adj = result['adjustedDestination'];
      if (adj is Map) {
        final lat = adj['lat'];
        final lng = adj['lng'];
        if (lat is num && lng is num) {
          _adjustedDestination = LatLng(lat.toDouble(), lng.toDouble());
        }
      } else {
        _adjustedDestination = null;
      }

      final mp = result['maneuverPoints'];
      if (mp is List) {
        _maneuverPoints =
            mp.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      } else {
        _maneuverPoints = const <Map<String, dynamic>>[];
      }
    } catch (_) {
      // Never crash the route loop; fall back to a straight line.
      _directionText = '';
      _distanceText = '';
      _maneuver = '';
      _laneGuidance = '';
      _maneuverPoints = const <Map<String, dynamic>>[];
      _adjustedDestination = null;
      if (origin.latitude == dest.latitude && origin.longitude == dest.longitude) {
        _polyline = <LatLng>[origin];
      } else {
        _polyline = <LatLng>[origin, dest];
      }
    }

    if (_polyline.length >= 2) {
      _nextPoint = _polyline[1];
    } else if (_polyline.length == 1) {
      _nextPoint = _polyline[0];
    } else {
      _nextPoint = null;
    }
  }

  void _emitUpdate() {
    final loc = _displayLoc ?? _currentRaw;
    if (loc == null) return;

    onRouteUpdate(
      DriverRouteUpdate(
        driverLocation: loc,
        destination: _adjustedDestination ?? _destination,
        bearing: _normalizeAngle(_displayBearing),
        polylinePoints: List<LatLng>.from(_polyline),
        nextPoint: _nextPoint,
        directionText: _directionText,
        distanceText: _distanceText,
        maneuver: _maneuver,
        laneGuidance: _laneGuidance,
        maneuverPoints: _maneuverPoints,
      ),
    );

    if (onCameraUpdate != null) {
      onCameraUpdate!(
        CameraPosition(
          target: loc,
          zoom: 16,
          bearing: _normalizeAngle(_displayBearing),
          tilt: 45,
        ),
      );
    }
  }

  // ---------------- polyline trimming (cheap) ----------------
  void _trimPolylineToCurrent(LatLng currentLocation) {
    if (_polyline.isEmpty) return;

    final closestIndex = _getClosestPolylinePointIndex(
      currentLocation,
      limit: _POLYLINE_TRIM_LOOKAHEAD_POINTS,
    );
    if (closestIndex <= 0) return;
    if (_distanceToPoint(currentLocation, _polyline[closestIndex]) >
        _POLYLINE_TRIM_TOLERANCE_M) {
      return;
    }

    final startIndex = math.max(0, closestIndex - 1);
    if (startIndex >= _polyline.length) return;

    _polyline = _polyline.sublist(startIndex);

    if (_polyline.length >= 2) {
      _nextPoint = _polyline[1];
    } else if (_polyline.length == 1) {
      _nextPoint = _polyline[0];
    } else {
      _nextPoint = null;
    }
  }

  int _getClosestPolylinePointIndex(LatLng position, {int? limit}) {
    double minDistance = double.infinity;
    int closestIndex = -1;

    final searchLimit =
        limit == null ? _polyline.length : math.min(_polyline.length, limit);

    for (int i = 0; i < searchLimit; i++) {
      final distance = _distanceToPoint(position, _polyline[i]);
      if (distance < minDistance) {
        minDistance = distance;
        closestIndex = i;
      }
    }
    return closestIndex;
  }

  bool _isOffRoute(LatLng currentLocation) {
    if (_polyline.length < 6) return _polyline.isEmpty;

    final snap = snapToPolyline(
      currentLocation,
      _polyline,
      maxSegments: _OFF_ROUTE_LOOKAHEAD_POINTS,
    );
    return snap.distanceMeters > _OFFROUTE_THRESHOLD_M;
  }

  double _distanceToPoint(LatLng from, LatLng to) {
    return Geolocator.distanceBetween(
      from.latitude,
      from.longitude,
      to.latitude,
      to.longitude,
    );
  }

  // ---------------- bearing helpers ----------------
  double _smoothBearing(double current, double target, double alpha) {
    final t = _shortestAngle(current, target);
    final out = current + (t - current) * alpha;
    return _normalizeAngle(out);
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
    from = _normalizeAngle(from);
    to = _normalizeAngle(to);

    double diff = (to - from) % 360;
    if (diff > 180) diff -= 360;
    if (diff < -180) diff += 360;
    return from + diff;
  }

  double _normalizeAngle(double a) {
    a %= 360;
    if (a < 0) a += 360;
    return a;
  }

  String _parseHtmlString(String htmlText) {
    var text = htmlText
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&');

    text = text.replaceAll(
      RegExp(r'\(\s*on the (left|right)\s*\)', caseSensitive: false),
      '',
    );

    return text.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  void dispose() {
    _positionSub?.cancel();
    _animTimer?.cancel();
  }
}

// // lib/utils/map/driver_route.dart
//
// import 'dart:async';
// import 'dart:math' as math;
//
// import 'package:geolocator/geolocator.dart';
// import 'package:google_maps_flutter/google_maps_flutter.dart';
//
// import 'route_info.dart';
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
// class DriverRouteController {
//   DriverRouteController({
//     required LatLng destination,
//     required this.onRouteUpdate,
//     this.onCameraUpdate,
//   }) : _destination = destination;
//
//   LatLng _destination;
//   LatLng get destination => _destination;
//
//   final void Function(DriverRouteUpdate update) onRouteUpdate;
//   final void Function(CameraPosition position)? onCameraUpdate;
//
//   LatLng? _current;
//   LatLng? _last;
//   double _bearing = 0;
//   List<LatLng> _polyline = [];
//   LatLng? _nextPoint;
//   String _directionText = '';
//   String _distanceText = '';
//   String _maneuver = '';
//
//   StreamSubscription<Position>? _positionSub;
//   bool _animating = false;
//
//   static const double _MAX_ACCURACY_M = 20.0;
//   static const double _MIN_MOVE_METERS = 3.0;
//   static const double _MIN_SPEED_MS = 1.0;
//   static const double _HEADING_TRUST_MS = 2.0;
//   static const double _MIN_TURN_DEG = 10.0;
//
//   Future<void> start() async {
//     final hasPermission = await _ensureLocationPermission();
//     if (!hasPermission) return;
//
//     final pos = await Geolocator.getCurrentPosition(
//       desiredAccuracy: LocationAccuracy.high,
//     );
//
//     _current = LatLng(pos.latitude, pos.longitude);
//     _last = _current;
//
//     await _fetchRoute(_current!, _destination);
//     _emitUpdate();
//
//     _startLocationStream();
//   }
//
//   Future<void> updateDestination(LatLng dest) async {
//     _destination = dest;
//
//     if (_current != null) {
//       await _fetchRoute(_current!, _destination);
//     }
//
//     _emitUpdate();
//   }
//
//   Future<bool> _ensureLocationPermission() async {
//     final serviceEnabled = await Geolocator.isLocationServiceEnabled();
//     if (!serviceEnabled) return false;
//
//     var permission = await Geolocator.checkPermission();
//     if (permission == LocationPermission.denied) {
//       permission = await Geolocator.requestPermission();
//     }
//     return permission == LocationPermission.always ||
//         permission == LocationPermission.whileInUse;
//   }
//
//   void _startLocationStream() {
//     _positionSub?.cancel();
//     _positionSub = Geolocator.getPositionStream(
//       locationSettings: const LocationSettings(
//         accuracy: LocationAccuracy.bestForNavigation,
//         distanceFilter: 3,
//       ),
//     ).listen(_onPosition);
//   }
//
//   Future<void> _onPosition(Position position) async {
//     final acc = position.accuracy.isFinite ? position.accuracy : 9999.0;
//     if (acc > _MAX_ACCURACY_M) return;
//
//     final newLoc = LatLng(position.latitude, position.longitude);
//     final speed = position.speed.isFinite ? position.speed : 0.0;
//     final heading = position.heading.isFinite ? position.heading : -1.0;
//
//     if (_last == null) {
//       _last = newLoc;
//       _current = newLoc;
//       _emitUpdate();
//       return;
//     }
//
//     final moved = Geolocator.distanceBetween(
//       _last!.latitude,
//       _last!.longitude,
//       newLoc.latitude,
//       newLoc.longitude,
//     );
//
//     if (moved < _MIN_MOVE_METERS) return;
//
//     double targetBearing = _bearing;
//
//     if (speed >= _HEADING_TRUST_MS && heading >= 0) {
//       targetBearing = heading;
//     } else {
//       targetBearing = _getBearing(_last!, newLoc);
//     }
//
//     final diff = _angleDeltaDeg(_bearing, targetBearing);
//     if (speed < _MIN_SPEED_MS && diff < _MIN_TURN_DEG) {
//       targetBearing = _bearing;
//     }
//
//     await _animateTo(newLoc, targetBearing);
//
//     _last = newLoc;
//     _current = newLoc;
//
//     _updateRemainingPolyline(newLoc);
//
//     if (_isOffRoute(newLoc)) {
//       await _fetchRoute(newLoc, _destination);
//     }
//
//     _emitUpdate();
//   }
//
//   Future<void> _fetchRoute(LatLng origin, LatLng dest) async {
//     final result = await getRouteInfo(origin: origin, destination: dest);
//
//     _directionText = _parseHtmlString(result['direction']);
//     _distanceText = result['distance'];
//     _maneuver = result['maneuver'] ?? '';
//     _polyline = decodePolyline(result['polyline']);
//
//     if (_polyline.length >= 2) {
//       _nextPoint = _polyline[1];
//     } else if (_polyline.length == 1) {
//       _nextPoint = _polyline[0];
//     } else {
//       _nextPoint = null;
//     }
//   }
//
//   Future<void> _animateTo(LatLng to, double targetBearing) async {
//     if (_current == null) {
//       _current = to;
//       _bearing = targetBearing;
//       return;
//     }
//
//     if (_animating) {
//       _current = to;
//       _bearing = targetBearing;
//       return;
//     }
//
//     _animating = true;
//
//     final start = _current!;
//     final startBearing = _bearing;
//     final endBearing = _shortestAngle(startBearing, targetBearing);
//
//     const steps = 30;
//     const duration = Duration(milliseconds: 800);
//     final interval = duration.inMilliseconds ~/ steps;
//
//     for (int i = 1; i <= steps; i++) {
//       await Future.delayed(Duration(milliseconds: interval));
//
//       final t = i / steps;
//       final lat = _lerp(start.latitude, to.latitude, t);
//       final lng = _lerp(start.longitude, to.longitude, t);
//       final newBearing = _lerpBearing(startBearing, endBearing, t);
//
//       _current = LatLng(lat, lng);
//       _bearing = _normalizeAngle(newBearing);
//
//       _emitUpdate();
//     }
//
//     _animating = false;
//   }
//
//   void _emitUpdate() {
//     if (_current == null) return;
//
//     onRouteUpdate(
//       DriverRouteUpdate(
//         driverLocation: _current!,
//         bearing: _bearing,
//         polylinePoints: List<LatLng>.from(_polyline),
//         nextPoint: _nextPoint,
//         directionText: _directionText,
//         distanceText: _distanceText,
//         maneuver: _maneuver,
//       ),
//     );
//
//     if (onCameraUpdate != null) {
//       onCameraUpdate!(
//         CameraPosition(target: _current!, zoom: 15, bearing: _bearing, tilt: 0),
//       );
//     }
//   }
//
//   void _updateRemainingPolyline(LatLng currentLocation) async {
//     if (_polyline.isEmpty) return;
//
//     int closestIndex = _getClosestPolylinePointIndex(currentLocation);
//     if (closestIndex != -1 && closestIndex < _polyline.length) {
//       _polyline = _polyline.sublist(closestIndex);
//
//       if (_polyline.length >= 2) {
//         _nextPoint = _polyline[1];
//
//         final result = await getRouteInfo(
//           origin: currentLocation,
//           destination: _destination,
//         );
//
//         _directionText = _parseHtmlString(result['direction']);
//         _distanceText = result['distance'];
//         _maneuver = result['maneuver'] ?? '';
//         _polyline = decodePolyline(result['polyline']);
//       }
//     }
//   }
//
//   int _getClosestPolylinePointIndex(LatLng position) {
//     double minDistance = double.infinity;
//     int closestIndex = -1;
//
//     for (int i = 0; i < _polyline.length; i++) {
//       final distance = Geolocator.distanceBetween(
//         position.latitude,
//         position.longitude,
//         _polyline[i].latitude,
//         _polyline[i].longitude,
//       );
//       if (distance < minDistance) {
//         minDistance = distance;
//         closestIndex = i;
//       }
//     }
//     return closestIndex;
//   }
//
//   bool _isOffRoute(LatLng currentLocation) {
//     if (_polyline.isEmpty) return true;
//
//     for (final point in _polyline) {
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
//   double _lerp(double start, double end, double t) => start + (end - start) * t;
//
//   double _lerpBearing(double start, double end, double t) {
//     double difference = ((end - start + 540) % 360) - 180;
//     return (start + difference * t + 360) % 360;
//   }
//
//   double _getBearing(LatLng start, LatLng end) {
//     final lat1 = start.latitude * math.pi / 180;
//     final lon1 = start.longitude * math.pi / 180;
//     final lat2 = end.latitude * math.pi / 180;
//     final lon2 = end.longitude * math.pi / 180;
//
//     final dLon = lon2 - lon1;
//
//     final y = math.sin(dLon) * math.cos(lat2);
//     final x =
//         math.cos(lat1) * math.sin(lat2) -
//         math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
//
//     final bearing = math.atan2(y, x);
//     return (bearing * 180 / math.pi + 360) % 360;
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
//   String _parseHtmlString(String htmlText) {
//     return htmlText
//         .replaceAll(RegExp(r'<[^>]*>'), '')
//         .replaceAll('&nbsp;', ' ')
//         .replaceAll('&amp;', '&');
//   }
//
//   void dispose() {
//     _positionSub?.cancel();
//   }
