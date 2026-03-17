import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:hopper/utils/map/app_map_style.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

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

  const SharedMap({
    super.key,
    required this.initialPosition,
    this.pickupPosition,
    this.markers = const <Marker>{},
    this.polylines = const <Polyline>{},
    this.myLocationEnabled = true,
    this.fitToBounds = true,
    this.trafficEnabled = true,
    this.compassEnabled = true,
    this.onMapCreated,
    this.onCameraMoveStarted,
    this.followDriver = false,
    this.followBearingEnabled = true,
    this.followZoom = 15.2,
    this.followTilt = 0,
  });

  @override
  SharedMapState createState() => SharedMapState();
}

class SharedMapState extends State<SharedMap> {
  GoogleMapController? _mapController;

  bool _cameraInitialized = false;
  String? _mapStyle;

  // pulse without 60fps rebuild
  Timer? _pulseTimer;
  double _pulseT = 0.0;

  // smooth follow debounce
  Timer? _followDebounce;
  Timer? _programmaticCameraTimer;
  LatLng? _lastFollowTarget;
  double _lastFollowBearing = 0;
  DateTime _followPausedUntil = DateTime.fromMillisecondsSinceEpoch(0);
  bool _isProgrammaticCameraMove = false;

  @override
  void initState() {
    super.initState();
    _loadMapStyle();
    _setKeepAwake(true);

    // update pulse every 200ms only (smooth enough, low cost)
    _pulseTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (!mounted) return;
      setState(() {
        _pulseT += 0.12;
        if (_pulseT > 1) _pulseT = 0;
      });
    });
  }

  Future<void> _loadMapStyle() async {
    try {
      final style = await AppMapStyle.loadUberLight();
      _mapStyle = style;
      if (_mapController != null) {
        await _mapController!.setMapStyle(style);
      }
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

    if (_mapStyle != null) {
      _mapController!.setMapStyle(_mapStyle);
    }

    if (_cameraInitialized) return;
    _cameraInitialized = true;

    if (widget.fitToBounds && widget.markers.length >= 2) {
      fitRouteBounds();
    } else {
      _mapController!.moveCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: widget.initialPosition, zoom: 14.6),
        ),
      );
    }
  }

  Future<void> fitPolylineBounds(
    List<LatLng> pts, {
    double padding = 80,
  }) async {
    if (_mapController == null) return;
    if (pts.length < 2) return;
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

    try {
      _markProgrammaticCameraMove();
      await _mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, padding),
      );
      final z = await _mapController!.getZoomLevel();
      if (z > 16.2) {
        _markProgrammaticCameraMove();
        await _mapController!.animateCamera(CameraUpdate.zoomTo(16.2));
      }
    } catch (_) {}
  }

  // ------------------ circles ------------------
  Set<Circle> _buildPickupCircles() {
    if (widget.pickupPosition == null) return const <Circle>{};

    // 0..1 wave
    final t = _pulseT;
    const double baseRadius = 22;
    final double animRadius = baseRadius + 28 * t;

    return {
      Circle(
        circleId: const CircleId('pickup_inner'),
        center: widget.pickupPosition!,
        radius: baseRadius,
        fillColor: Colors.green.withOpacity(0.22),
        strokeColor: Colors.green.withOpacity(0.65),
        strokeWidth: 2,
      ),
      Circle(
        circleId: const CircleId('pickup_pulse'),
        center: widget.pickupPosition!,
        radius: animRadius,
        fillColor: Colors.green.withOpacity(0.08 * (1 - t)),
        strokeColor: Colors.green.withOpacity(0.55 * (1 - t)),
        strokeWidth: 2,
      ),
    };
  }

  // ------------------ PUBLIC API ------------------
  Future<void> focusPickup() async {
    if (_mapController == null || widget.pickupPosition == null) return;
    pauseAutoFollow(const Duration(seconds: 2));

    _markProgrammaticCameraMove();
    await _mapController!.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: widget.pickupPosition!, zoom: 15.8),
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

    final center = LatLng((minLat + maxLat) / 2, (minLng + maxLng) / 2);

    final dLat = (maxLat - minLat).abs();
    final dLng = (maxLng - minLng).abs();
    final spread = math.max(dLat, dLng);

    double zoom;
    if (spread < 0.001) {
      zoom = 16.3;
    } else if (spread < 0.01) {
      zoom = 15.4;
    } else if (spread < 0.05) {
      zoom = 14.2;
    } else if (spread < 0.1) {
      zoom = 12;
    } else {
      zoom = 10;
    }

    _markProgrammaticCameraMove();
    await _mapController!.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: center, zoom: zoom),
      ),
    );
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
      if (d < 2.0 && (_angleDelta(_lastFollowBearing, bearing) < 3.0)) return;
    }

    _lastFollowTarget = target;
    _lastFollowBearing = bearing;

    _followDebounce?.cancel();
    _followDebounce = Timer(const Duration(milliseconds: 120), () async {
      if (!mounted || _mapController == null) return;

      try {
        _markProgrammaticCameraMove();
        await _mapController!.moveCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: target,
              zoom: widget.followZoom,
              bearing: widget.followBearingEnabled ? bearing : 0,
              tilt: widget.followTilt,
            ),
          ),
        );
      } catch (_) {}
    });
  }

  void pauseAutoFollow(Duration duration) {
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
      minMaxZoomPreference: const MinMaxZoomPreference(12.0, 18.0),
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
