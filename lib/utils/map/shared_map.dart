import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:hopper/utils/map/app_map_style.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

enum PickupIndicatorStyle { pulse, dots, none }

class SharedMap extends StatefulWidget {
  final LatLng initialPosition;
  final LatLng? pickupPosition;
  final Set<Marker> markers;
  final Set<Polyline> polylines;
  final bool myLocationEnabled;
  final bool fitToBounds;
  final bool trafficEnabled;
  final bool compassEnabled;
  final ValueChanged<GoogleMapController>? onMapCreated;
  final VoidCallback? onCameraMoveStarted;

  /// ✅ Uber/Ola follow driver camera
  final bool followDriver;
  final bool followBearingEnabled;
  final double followZoom;
  final double followTilt;

  /// Pickup indicator style (pulse / dots / none)
  final PickupIndicatorStyle pickupIndicatorStyle;
  final Color pickupIndicatorColor;
  final Color pickupTargetColor;

  const SharedMap({
    super.key,
    required this.initialPosition,
    this.pickupPosition,
    this.markers = const <Marker>{},
    this.polylines = const <Polyline>{},
    this.myLocationEnabled = true,
    this.fitToBounds = true,
    this.trafficEnabled = false,
    this.compassEnabled = true,
    this.onMapCreated,
    this.onCameraMoveStarted,
    this.followDriver = false,
    this.followBearingEnabled = true,
    this.followZoom = 16.2,
    this.followTilt = 0,
    this.pickupIndicatorStyle = PickupIndicatorStyle.pulse,
    this.pickupIndicatorColor = Colors.green,
    this.pickupTargetColor = Colors.black,
  });

  @override
  SharedMapState createState() => SharedMapState();
}

class SharedMapState extends State<SharedMap> {
  GoogleMapController? _mapController;

  bool _cameraInitialized = false;
  bool _didInitialAutoFit = false;
  String? _mapStyle;

  // pulse without 60fps rebuild
  Timer? _pulseTimer;
  double _pulseT = 0.0;

  // smooth follow debounce
  Timer? _followDebounce;
  Timer? _programmaticCameraTimer;
  LatLng? _lastFollowTarget;
  double _lastFollowBearing = 0;
  DateTime _lastFollowMoveAt = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _followPausedUntil = DateTime.fromMillisecondsSinceEpoch(0);
  bool _isProgrammaticCameraMove = false;

  @override
  void initState() {
    super.initState();
    _loadMapStyle();
    _setKeepAwake(true);
    _updatePulseTimer();
  }

  @override
  void didUpdateWidget(covariant SharedMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pickupIndicatorStyle != widget.pickupIndicatorStyle ||
        oldWidget.pickupPosition != widget.pickupPosition) {
      _updatePulseTimer();
    }

    // Map can be created before pickup/drop/polyline data arrives (async).
    // In that case, do a one-time initial camera move once we have enough data,
    // so the user doesn't need to press the location button to "wake" the map.
    if (widget.fitToBounds &&
        _mapController != null &&
        !_didInitialAutoFit &&
        (_bestPolylinePoints().length >= 2 || widget.markers.isNotEmpty)) {
      _didInitialAutoFit = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _mapController == null) return;
        _attemptInitialCameraMove();
      });
    }
  }

  void _updatePulseTimer() {
    final shouldPulse =
        widget.pickupIndicatorStyle == PickupIndicatorStyle.pulse &&
        widget.pickupPosition != null;

    if (!shouldPulse) {
      _pulseTimer?.cancel();
      _pulseTimer = null;
      _pulseT = 0.0;
      return;
    }

    if (_pulseTimer != null) return;

    // update pulse at a modest rate (smooth, low cost)
    _pulseTimer = Timer.periodic(const Duration(milliseconds: 120), (_) {
      if (!mounted) return;
      setState(() {
        _pulseT += 0.06;
        if (_pulseT >= 1) _pulseT -= 1;
      });
    });
  }

  Future<void> _loadMapStyle() async {
    try {
      final style = await AppMapStyle.loadUberLight();
      _mapStyle = style;
      if (mounted) setState(() {});
    } catch (_) {}
  }

  @override
  void dispose() {
    _followDebounce?.cancel();
    _programmaticCameraTimer?.cancel();
    _pulseTimer?.cancel();
    _mapController?.dispose();
    _setKeepAwake(false);
    super.dispose();
  }

  Future<void> _setKeepAwake(bool enabled) async {
    try {
      await WakelockPlus.toggle(enable: enabled);
    } catch (_) {}
  }

  void _markProgrammaticCameraMove() {
    _isProgrammaticCameraMove = true;
    _programmaticCameraTimer?.cancel();
    _programmaticCameraTimer = Timer(const Duration(milliseconds: 350), () {
      _isProgrammaticCameraMove = false;
    });
  }

  void _onMapCreated(GoogleMapController controller) {
    widget.onMapCreated?.call(controller);
    _mapController = controller;

    if (_cameraInitialized) return;
    _cameraInitialized = true;

    if (widget.fitToBounds) {
      // If we already have enough info, auto-fit once after first frame.
      if (_bestPolylinePoints().length >= 2 || widget.markers.isNotEmpty) {
        _didInitialAutoFit = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || _mapController == null) return;
          _attemptInitialCameraMove();
        });
        return;
      }

      // Not enough info yet (async data). Still set an initial camera position,
      // but keep `_didInitialAutoFit = false` so `didUpdateWidget` can auto-fit
      // as soon as markers/polyline arrive.
      _mapController!.moveCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: widget.initialPosition, zoom: 14.6),
        ),
      );
      return;
    }

    _didInitialAutoFit = true;
    _mapController!.moveCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: widget.initialPosition, zoom: 14.6),
      ),
    );
  }

  void _attemptInitialCameraMove() {
    if (_mapController == null) return;

    final pts = _bestPolylinePoints();
    if (pts.length >= 2) {
      fitPolylineBounds(pts, padding: 95);
      return;
    }

    if (widget.markers.length >= 2) {
      fitRouteBounds();
      return;
    }

    if (widget.markers.isNotEmpty) {
      focusDriver(zoom: 16.6);
    }
  }

  Future<void> fitPolylineBounds(
    List<LatLng> pts, {
    double padding = 80,
  }) async {
    if (_mapController == null) return;
    if (pts.length < 2) {
      await fitRouteBounds();
      return;
    }
    pauseAutoFollow(const Duration(seconds: 2));

    double minLat = pts.first.latitude;
    double maxLat = pts.first.latitude;
    double minLng = pts.first.longitude;
    double maxLng = pts.first.longitude;

    for (final p in pts) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    final bounds = _safeBounds(minLat, minLng, maxLat, maxLng);

    Future<void> doFit() async {
      _markProgrammaticCameraMove();
      await _mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, padding),
      );
      final z = await _mapController!.getZoomLevel();
      if (z > 17.2) {
        _markProgrammaticCameraMove();
        await _mapController!.animateCamera(CameraUpdate.zoomTo(17.2));
      }
    }

    try {
      await doFit();
    } catch (_) {
      // Sometimes `newLatLngBounds` fails (map hasn't got a size yet) or the
      // auto-follow timer overrides the move. Retry once after a frame.
      try {
        await WidgetsBinding.instance.endOfFrame;
      } catch (_) {}
      await Future.delayed(const Duration(milliseconds: 250));
      try {
        await doFit();
      } catch (_) {}
    }
  }

  // ------------------ circles ------------------
  double _bearingBetween(LatLng a, LatLng b) {
    final lat1 = a.latitude * math.pi / 180.0;
    final lat2 = b.latitude * math.pi / 180.0;
    final dLng = (b.longitude - a.longitude) * math.pi / 180.0;
    final y = math.sin(dLng) * math.cos(lat2);
    final x =
        math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLng);
    final brng = math.atan2(y, x) * 180.0 / math.pi;
    final norm = (brng + 360.0) % 360.0;
    return norm;
  }

  List<LatLng> _bestPolylinePoints() {
    if (widget.polylines.isEmpty) return const <LatLng>[];
    Polyline? best;
    for (final p in widget.polylines) {
      if (best == null) {
        best = p;
      } else if (p.points.length > best.points.length) {
        best = p;
      }
    }
    return best?.points ?? const <LatLng>[];
  }

  Set<Circle> _buildPickupPulseCircles(LatLng pos) {
    final c = widget.pickupIndicatorColor;
    final targetColor = widget.pickupTargetColor;

    // Smooth "breathing" pulse (no sudden jump): 0 -> 1 -> 0
    final wave = 0.5 - 0.5 * math.cos(_pulseT * 2 * math.pi);
    const double minRadius = 26;
    const double maxRadius = 56;
    final animRadius = minRadius + (maxRadius - minRadius) * wave;

    return {
      // target marker (black ring + white center)
      Circle(
        circleId: const CircleId('pickup_target_outer'),
        center: pos,
        radius: 10,
        fillColor: targetColor,
        strokeColor: Colors.white,
        strokeWidth: 2,
        zIndex: 105,
      ),
      Circle(
        circleId: const CircleId('pickup_target_inner'),
        center: pos,
        radius: 3.4,
        fillColor: Colors.white,
        strokeWidth: 0,
        zIndex: 106,
      ),

      // one smooth animated circle (light green)
      Circle(
        circleId: const CircleId('pickup_pulse'),
        center: pos,
        radius: animRadius,
        fillColor: c.withValues(alpha: 0.10 + 0.06 * (1 - wave)),
        strokeColor: c.withValues(alpha: 0.22 + 0.28 * (1 - wave)),
        strokeWidth: 2,
        zIndex: 99,
      ),
    };
  }

  Set<Circle> _buildPickupDotsCircles(LatLng pos) {
    // Prefer placing dots towards the driver position (works even if route/polyline is odd).
    LatLng? driverPos;
    for (final m in widget.markers) {
      if (m.markerId.value == 'driver') {
        driverPos = m.position;
        break;
      }
    }

    double bearing;
    if (driverPos != null) {
      bearing = _bearingBetween(pos, driverPos);
    } else {
      final pts = _bestPolylinePoints();
      bearing =
          pts.length >= 2 ? _bearingBetween(pts[pts.length - 2], pts.last) : 0.0;
      // if we only have polyline direction, dots should trail behind pickup.
      bearing = (bearing + 180.0) % 360.0;
    }

    // Keep dots close to the pickup bubble (avoid showing "dots on road" far away)
    final dot1 = _offsetLatLng(pos, bearing, 10);
    final dot2 = _offsetLatLng(pos, bearing, 18);
    final dot3 = _offsetLatLng(pos, bearing, 26);

    final c = widget.pickupIndicatorColor;
    final targetColor = widget.pickupTargetColor;

    return {
      // light bubble like Uber/Ola
      Circle(
        circleId: const CircleId('pickup_bubble'),
        center: pos,
        radius: 40,
        fillColor: c.withValues(alpha: 0.18),
        strokeColor: Colors.transparent,
        strokeWidth: 0,
        zIndex: 101,
      ),
      // pickup target (black ring + white center)
      Circle(
        circleId: const CircleId('pickup_target_outer'),
        center: pos,
        radius: 10,
        fillColor: targetColor,
        strokeColor: Colors.white,
        strokeWidth: 2,
        zIndex: 105,
      ),
      Circle(
        circleId: const CircleId('pickup_target_inner'),
        center: pos,
        radius: 3.4,
        fillColor: Colors.white,
        strokeWidth: 0,
        zIndex: 106,
      ),

      // trailing dots
      Circle(
        circleId: const CircleId('pickup_dot_1'),
        center: dot1,
        radius: 3.2,
        fillColor: c.withValues(alpha: 0.92),
        strokeWidth: 0,
        zIndex: 104,
      ),
      Circle(
        circleId: const CircleId('pickup_dot_2'),
        center: dot2,
        radius: 2.7,
        fillColor: c.withValues(alpha: 0.62),
        strokeWidth: 0,
        zIndex: 103,
      ),
      Circle(
        circleId: const CircleId('pickup_dot_3'),
        center: dot3,
        radius: 2.2,
        fillColor: c.withValues(alpha: 0.34),
        strokeWidth: 0,
        zIndex: 102,
      ),
    };
  }

  Set<Circle> _buildPickupCircles() {
    final pos = widget.pickupPosition;
    if (pos == null) return const <Circle>{};

    switch (widget.pickupIndicatorStyle) {
      case PickupIndicatorStyle.none:
        return const <Circle>{};
      case PickupIndicatorStyle.pulse:
        return _buildPickupPulseCircles(pos);
      case PickupIndicatorStyle.dots:
        return _buildPickupDotsCircles(pos);
    }
  }

  // ------------------ PUBLIC API ------------------
  Future<void> focusDriver({
    double zoom = 17.2,
    double tilt = 0,
    bool bearingEnabled = false,
  }) async {
    if (_mapController == null) return;
    if (widget.markers.isEmpty) return;

    final driver = widget.markers.firstWhere(
      (m) => m.markerId.value == 'driver',
      orElse: () => widget.markers.first,
    );

    pauseAutoFollow(const Duration(seconds: 2));
    try {
      _markProgrammaticCameraMove();
      await _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: driver.position,
            zoom: zoom.clamp(11.5, 17.8),
            tilt: tilt.clamp(0, 60),
            bearing: bearingEnabled ? driver.rotation : 0,
          ),
        ),
      );
    } catch (_) {}
  }

  Future<void> focusPickup() async {
    if (_mapController == null || widget.pickupPosition == null) return;
    pauseAutoFollow(const Duration(seconds: 2));

    _markProgrammaticCameraMove();
    await _mapController!.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: widget.pickupPosition!, zoom: 16.2),
      ),
    );
  }

  Future<void> fitRouteBounds() async {
    if (_mapController == null || widget.markers.isEmpty) return;
    pauseAutoFollow(const Duration(seconds: 2));

    final list = widget.markers.toList();

    double minLat = list.first.position.latitude;
    double maxLat = list.first.position.latitude;
    double minLng = list.first.position.longitude;
    double maxLng = list.first.position.longitude;

    for (final m in list) {
      final lat = m.position.latitude;
      final lng = m.position.longitude;
      if (lat < minLat) minLat = lat;
      if (lat > maxLat) maxLat = lat;
      if (lng < minLng) minLng = lng;
      if (lng > maxLng) maxLng = lng;
    }

    final bounds = _safeBounds(minLat, minLng, maxLat, maxLng);

    Future<void> doFit() async {
      _markProgrammaticCameraMove();
      await _mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 95),
      );
      final z = await _mapController!.getZoomLevel();
      if (z > 17.2) {
        _markProgrammaticCameraMove();
        await _mapController!.animateCamera(CameraUpdate.zoomTo(17.2));
      }
    }

    try {
      await doFit();
    } catch (_) {
      // Sometimes `newLatLngBounds` fails if called before the map has a size.
      await Future.delayed(const Duration(milliseconds: 250));
      try {
        await doFit();
      } catch (_) {}
    }
  }

  Future<void> focusOnCustomerRoute(LatLng pickup, LatLng drop) async {
    if (_mapController == null) return;
    pauseAutoFollow(const Duration(seconds: 2));

    final minLat = math.min(pickup.latitude, drop.latitude);
    final maxLat = math.max(pickup.latitude, drop.latitude);
    final minLng = math.min(pickup.longitude, drop.longitude);
    final maxLng = math.max(pickup.longitude, drop.longitude);

    final bounds = _safeBounds(minLat, minLng, maxLat, maxLng);

    try {
      _markProgrammaticCameraMove();
      await _mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 95),
      );
    } catch (_) {
      await Future.delayed(const Duration(milliseconds: 250));
      _markProgrammaticCameraMove();
      await _mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 95),
      );
    }
  }

  /// ✅ Uber follow camera (call this from screen if you want)
  void followDriverCamera({required LatLng target, required double bearing}) {
    if (_mapController == null) return;
    if (DateTime.now().isBefore(_followPausedUntil)) return;

    // avoid micro-updates
    if (_lastFollowTarget != null) {
      final d = _distanceMeters(_lastFollowTarget!, target);
      if (d < 0.75 && (_angleDelta(_lastFollowBearing, bearing) < 2.0)) return;
    }

    _lastFollowTarget = target;
    _lastFollowBearing = bearing;

    _followDebounce?.cancel();
    _followDebounce = Timer(const Duration(milliseconds: 120), () async {
      if (!mounted || _mapController == null) return;

      try {
        final now = DateTime.now();
        if (now.difference(_lastFollowMoveAt).inMilliseconds < 220) return;
        _lastFollowMoveAt = now;

        final zoom = widget.followZoom.clamp(11.5, 17.8);
        final leadMeters =
            zoom >= 15.0
                ? 70.0
                : zoom >= 14.3
                ? 110.0
                : 150.0;
        final followTarget = _offsetLatLng(target, bearing, leadMeters);

        _markProgrammaticCameraMove();
        await _mapController!.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: followTarget,
              zoom: zoom,
              bearing: widget.followBearingEnabled ? bearing : 0,
              tilt: widget.followTilt,
            ),
          ),
        );
      } catch (_) {}
    });
  }

  void pauseAutoFollow(Duration duration) {
    // Cancel any pending follow move so a manual camera action (fit/focus)
    // doesn't get overridden a few milliseconds later.
    _followDebounce?.cancel();
    final until = DateTime.now().add(duration);
    if (until.isAfter(_followPausedUntil)) {
      _followPausedUntil = until;
    }
  }

  // ------------------ helpers ------------------
  static double _distanceMeters(LatLng a, LatLng b) {
    // approx ok for small distances
    final dx = (a.latitude - b.latitude) * 111320.0;
    final dy =
        (a.longitude - b.longitude) *
        111320.0 *
        math.cos(a.latitude * math.pi / 180);
    return math.sqrt(dx * dx + dy * dy);
  }

  static double _angleDelta(double a, double b) {
    double d = (b - a) % 360;
    if (d > 180) d -= 360;
    if (d < -180) d += 360;
    return d.abs();
  }

  static LatLngBounds _safeBounds(
    double minLat,
    double minLng,
    double maxLat,
    double maxLng,
  ) {
    const eps = 0.00012;
    if ((maxLat - minLat).abs() < eps) {
      maxLat += eps;
      minLat -= eps;
    }
    if ((maxLng - minLng).abs() < eps) {
      maxLng += eps;
      minLng -= eps;
    }
    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  static LatLng _offsetLatLng(LatLng origin, double bearingDeg, double meters) {
    const earthRadiusM = 6378137.0;
    final bearing = bearingDeg * math.pi / 180.0;
    final d = meters / earthRadiusM;

    final lat1 = origin.latitude * math.pi / 180.0;
    final lng1 = origin.longitude * math.pi / 180.0;

    final lat2 = math.asin(
      math.sin(lat1) * math.cos(d) +
          math.cos(lat1) * math.sin(d) * math.cos(bearing),
    );
    final lng2 =
        lng1 +
        math.atan2(
          math.sin(bearing) * math.sin(d) * math.cos(lat1),
          math.cos(d) - math.sin(lat1) * math.sin(lat2),
        );

    return LatLng(lat2 * 180.0 / math.pi, lng2 * 180.0 / math.pi);
  }

  @override
  Widget build(BuildContext context) {
    // If followDriver enabled, we follow the driver marker (markerId 'driver')
    if (widget.followDriver && widget.markers.isNotEmpty) {
      final driver = widget.markers.firstWhere(
        (m) => m.markerId.value == 'driver',
        orElse: () => widget.markers.first,
      );
      // Note: bearing comes from marker rotation
      followDriverCamera(target: driver.position, bearing: driver.rotation);
    }

    return GoogleMap(
      style: _mapStyle,
      initialCameraPosition: CameraPosition(
        target: widget.initialPosition,
        zoom: 14.6,
      ),
      onMapCreated: _onMapCreated,
      onCameraMoveStarted: () {
        if (_isProgrammaticCameraMove) return;
        widget.onCameraMoveStarted?.call();
        pauseAutoFollow(const Duration(seconds: 6));
      },
      markers: widget.markers,
      polylines: widget.polylines,
      circles: _buildPickupCircles(),
      myLocationEnabled: widget.myLocationEnabled,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      minMaxZoomPreference: const MinMaxZoomPreference(11.0, 18.0),
      compassEnabled: widget.compassEnabled,
      buildingsEnabled: false,
      indoorViewEnabled: false,
      // ✅ Uber feel: allow tilt gestures (optional)
      tiltGesturesEnabled: true,
      mapToolbarEnabled: false,
      trafficEnabled: widget.trafficEnabled,
    );
  }
}

// import 'dart:async';
// import 'dart:math' as math; // 👈 for focusOnCustomerRoute bounds
// import 'package:flutter/material.dart';
// // import 'package:google_maps_flutter/google_maps_flutter.dart';
//
// class SharedMap extends StatefulWidget {
//   final LatLng initialPosition;
//   final LatLng? pickupPosition; // 👈 point to focus (driver or pickup)
//   final Set<Marker> markers;
//   final Set<Polyline> polylines;
//   final bool myLocationEnabled;
//   final bool fitToBounds;
//
//   const SharedMap({
//     super.key,
//     required this.initialPosition,
//     this.pickupPosition,
//     this.markers = const <Marker>{},
//     this.polylines = const <Polyline>{},
//     this.myLocationEnabled = true,
//     this.fitToBounds = true,
//   });
//
//   @override
//   SharedMapState createState() => SharedMapState(); // 👈 public
// }
//
// class SharedMapState extends State<SharedMap>
//     with SingleTickerProviderStateMixin {
//   GoogleMapController? _mapController;
//   late AnimationController _pulseController;
//   bool _cameraInitialized = false;
//   String? _mapStyle;
//
//   @override
//   void initState() {
//     super.initState();
//
//     _loadMapStyle();
//
//     _pulseController =
//     AnimationController(vsync: this, duration: const Duration(seconds: 2))
//       ..addListener(() {
//         if (mounted) setState(() {});
//       })
//       ..repeat();
//   }
//
//   Future<void> _loadMapStyle() async {
//     try {
//       final style = await rootBundle.loadString(
//         'assets/map_style/map_style1.json',
//       );
//       _mapStyle = style;
//       if (_mapController != null) {
//         _mapController!.setMapStyle(_mapStyle);
//       }
//     } catch (_) {
//       // ignore
//     }
//   }
//
//   @override
//   void dispose() {
//     _pulseController.dispose();
//     _mapController?.dispose();
//     super.dispose();
//   }
//
//   void _onMapCreated(GoogleMapController controller) {`r`n    widget.onMapCreated?.call(controller);
//     _mapController = controller;

//
//     if (_mapStyle != null) {
//       _mapController!.setMapStyle(_mapStyle);
//     }
//
//     if (_cameraInitialized) return;
//     _cameraInitialized = true;
//
//     if (widget.fitToBounds && widget.markers.length >= 2) {
//       fitRouteBounds();
//     } else {
//       _mapController!.moveCamera(
//         CameraUpdate.newCameraPosition(
//           CameraPosition(target: widget.initialPosition, zoom: 15),
//         ),
//       );
//     }
//   }
//
//   LatLngBounds _boundsFromMarkers(Set<Marker> markers) {
//     final list = markers.toList();
//
//     double minLat = list.first.position.latitude;
//     double maxLat = list.first.position.latitude;
//     double minLng = list.first.position.longitude;
//     double maxLng = list.first.position.longitude;
//
//     for (final m in list) {
//       if (m.position.latitude < minLat) minLat = m.position.latitude;
//       if (m.position.latitude > maxLat) maxLat = m.position.latitude;
//       if (m.position.longitude < minLng) minLng = m.position.longitude;
//       if (m.position.longitude > maxLng) maxLng = m.position.longitude;
//     }
//
//     return LatLngBounds(
//       southwest: LatLng(minLat, minLng),
//       northeast: LatLng(maxLat, maxLng),
//     );
//   }
//
//   Set<Circle> _buildPickupCircles() {
//     if (widget.pickupPosition == null) return const <Circle>{};
//
//     final t = _pulseController.value; // 0 → 1
//     const double baseRadius = 25;
//     final double animRadius = baseRadius + 25 * t;
//
//     return {
//       Circle(
//         circleId: const CircleId('pickup_inner'),
//         center: widget.pickupPosition!,
//         radius: baseRadius,
//         fillColor: Colors.green.withOpacity(0.25),
//         strokeColor: Colors.green.withOpacity(0.7),
//         strokeWidth: 2,
//       ),
//       Circle(
//         circleId: const CircleId('pickup_pulse'),
//         center: widget.pickupPosition!,
//         radius: animRadius,
//         fillColor: Colors.green.withOpacity(0.08 * (1 - t)),
//         strokeColor: Colors.green.withOpacity(0.6 * (1 - t)),
//         strokeWidth: 2,
//       ),
//     };
//   }
//
//   /// 👉 PUBLIC: focus on pickup/driver with nice zoom
//   Future<void> focusPickup() async {
//     if (_mapController == null || widget.pickupPosition == null) return;
//
//     await _mapController!.animateCamera(
//       CameraUpdate.newCameraPosition(
//         CameraPosition(
//           target: widget.pickupPosition!,
//           zoom: 18,
//         ),
//       ),
//     );
//   }
//
//
//   Future<void> fitRouteBounds() async {
//     if (_mapController == null || widget.markers.isEmpty) return;
//
//     // 1. Compute simple center of all markers
//     final list = widget.markers.toList();
//
//     double minLat = list.first.position.latitude;
//     double maxLat = list.first.position.latitude;
//     double minLng = list.first.position.longitude;
//     double maxLng = list.first.position.longitude;
//
//     for (final m in list) {
//       final lat = m.position.latitude;
//       final lng = m.position.longitude;
//       if (lat < minLat) minLat = lat;
//       if (lat > maxLat) maxLat = lat;
//       if (lng < minLng) minLng = lng;
//       if (lng > maxLng) maxLng = lng;
//     }
//
//     final center = LatLng(
//       (minLat + maxLat) / 2,
//       (minLng + maxLng) / 2,
//     );
//
//     // 2. Decide zoom roughly based on spread, but keep it simple
//     final dLat = (maxLat - minLat).abs();
//     final dLng = (maxLng - minLng).abs();
//     double zoom;
//
//     final spread = math.max(dLat, dLng);
//     if (spread < 0.001) {
//       zoom = 18; // almost same point
//     } else if (spread < 0.01) {
//       zoom = 16;
//     } else if (spread < 0.05) {
//       zoom = 14;
//     } else if (spread < 0.1) {
//       zoom = 12;
//     } else {
//       zoom = 10; // very large area
//     }
//
//     await _mapController!.animateCamera(
//       CameraUpdate.newCameraPosition(
//         CameraPosition(target: center, zoom: zoom),
//       ),
//     );
//   }
//
//
//   /// 👉 PUBLIC: fit all markers (driver + pickup etc.)
//   // Future<void> fitRouteBounds() async {
//   //   if (_mapController == null || widget.markers.length < 2) return;
//   //
//   //   final bounds = _boundsFromMarkers(widget.markers);
//   //   final ne = bounds.northeast;
//   //   final sw = bounds.southwest;
//   //
//   //   final dLat = (ne.latitude - sw.latitude).abs();
//   //   final dLng = (ne.longitude - sw.longitude).abs();
//   //
//   //   final center = LatLng(
//   //     (ne.latitude + sw.latitude) / 2,
//   //     (ne.longitude + sw.longitude) / 2,
//   //   );
//   //
//   //   if (dLat < 0.001 && dLng < 0.001) {
//   //     await _mapController!.animateCamera(
//   //       CameraUpdate.newCameraPosition(
//   //         CameraPosition(
//   //           target: center,
//   //           zoom: 17,
//   //         ),
//   //       ),
//   //     );
//   //     return;
//   //   }
//   //
//   //   try {
//   //     await _mapController!.animateCamera(
//   //       CameraUpdate.newLatLngBounds(bounds, 60),
//   //     );
//   //   } catch (_) {
//   //     await Future.delayed(const Duration(milliseconds: 300));
//   //     await _mapController!.animateCamera(
//   //       CameraUpdate.newLatLngBounds(bounds, 60),
//   //     );
//   //   }
//   // }
//
//   /// 👉 PUBLIC: focus between a specific customer's pickup & drop
//   Future<void> focusOnCustomerRoute(LatLng pickup, LatLng drop) async {
//     if (_mapController == null) return;
//
//     final minLat = math.min(pickup.latitude, drop.latitude);
//     final maxLat = math.max(pickup.latitude, drop.latitude);
//     final minLng = math.min(pickup.longitude, drop.longitude);
//     final maxLng = math.max(pickup.longitude, drop.longitude);
//
//     final bounds = LatLngBounds(
//       southwest: LatLng(minLat, minLng),
//       northeast: LatLng(maxLat, maxLng),
//     );
//
//     try {
//       await _mapController!.animateCamera(
//         CameraUpdate.newLatLngBounds(bounds, 60),
//       );
//     } catch (_) {
//       await Future.delayed(const Duration(milliseconds: 300));
//       await _mapController!.animateCamera(
//         CameraUpdate.newLatLngBounds(bounds, 60),
//       );
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return GoogleMap(
//       initialCameraPosition: CameraPosition(
//         target: widget.initialPosition,
//         zoom: 15,
//       ),
//       onMapCreated: _onMapCreated,
//       markers: widget.markers,
//       polylines: widget.polylines,
//       circles: _buildPickupCircles(),
//       myLocationEnabled: widget.myLocationEnabled,
//       myLocationButtonEnabled: false,
//       zoomControlsEnabled: false,
//       compassEnabled: widget.compassEnabled,
//       tiltGesturesEnabled: false,
//       mapToolbarEnabled: false,
//       trafficEnabled: widget.trafficEnabled,
//     );
//   }
// }
//
//
