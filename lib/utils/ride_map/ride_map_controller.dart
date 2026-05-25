import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show Offset;

import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'bearing_utils.dart';
import 'map_ui_config.dart';
import 'marker_icon_cache.dart';
import 'polyline_trim_utils.dart';
import 'route_polyline_service.dart';
import 'vehicle_animation_service.dart';

enum RideMapMode {
  home,
  rideRequest,
  pickupNavigation,
  dropNavigation,
  sharedPickup,
  sharedDrop,
  rideCompleted,
}

class RideMapController {
  RideMapController({
    required RideMapMode mode,
    RoutePolylineService routeService = const RoutePolylineService(),
  }) : _mode = mode,
       _routeService = routeService {
    _poseListener = _onPoseTick;
    _vehicleAnim.pose.addListener(_poseListener);
  }

  final RoutePolylineService _routeService;

  RideMapMode _mode;
  RideMapMode get mode => _mode;

  GoogleMapController? _mapController;

  final ValueNotifier<Set<Marker>> markers = ValueNotifier<Set<Marker>>(<Marker>{});
  final ValueNotifier<Set<Polyline>> polylines =
      ValueNotifier<Set<Polyline>>(<Polyline>{});
  final ValueNotifier<Set<Marker>> overlayMarkers =
      ValueNotifier<Set<Marker>>(<Marker>{});
  final ValueNotifier<Set<Polyline>> overlayPolylines =
      ValueNotifier<Set<Polyline>>(<Polyline>{});
  final ValueNotifier<Set<Circle>> overlayCircles =
      ValueNotifier<Set<Circle>>(<Circle>{});

  // Vehicle animation state
  final VehicleAnimationService _vehicleAnim = VehicleAnimationService();
  late final VoidCallback _poseListener;

  RideVehicleType _vehicleType = RideVehicleType.car;
  BitmapDescriptor? _vehicleIcon;
  bool _vehicleIconLoading = false;

  LatLng? _pickup;
  LatLng? _drop;
  LatLng? get pickupPosition => _pickup;
  LatLng? get dropPosition => _drop;

  // Route state
  List<LatLng> _routeFull = <LatLng>[];
  List<LatLng> _remaining = <LatLng>[];
  List<LatLng> _completed = <LatLng>[];
  bool _showCompleted = true;

  // Camera follow throttling
  LatLng? _lastCameraTarget;
  double _lastCameraBearing = 0;
  DateTime _lastCameraMoveAt = DateTime.fromMillisecondsSinceEpoch(0);

  // Debounce polyline updates while animating to avoid flicker.
  Timer? _polylineDebounce;
  LatLng? _lastTrimAt;

  // Exposed UI knobs
  bool autoFollowEnabled = true;
  double bottomSheetHeight = 0.0;

  LatLng? _navDestination;
  bool _navDriverFriendlyStop = false;

  void attachMapController(GoogleMapController controller) {
    _mapController = controller;
  }

  void setAutoFollowEnabled(bool enabled) {
    autoFollowEnabled = enabled;
  }

  Future<void> focusVehicle({
    double? zoom,
    double? tilt,
    bool bearingEnabled = false,
  }) async {
    final c = _mapController;
    final pose = _vehicleAnim.pose.value;
    if (c == null || pose == null) return;
    final z = (zoom ?? (_isNavigationMode(_mode) ? MapUiConfig.navigationZoom : MapUiConfig.defaultZoom))
        .clamp(11.5, 17.8);
    final t = (tilt ?? (_isNavigationMode(_mode) ? MapUiConfig.cameraTilt : 0.0)).clamp(0.0, 60.0);
    try {
      await c.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: pose.position,
            zoom: z,
            tilt: t,
            bearing: bearingEnabled ? pose.bearing : 0.0,
          ),
        ),
      );
    } catch (_) {}
  }

  Future<void> fitToBounds({double padding = 95}) async {
    final c = _mapController;
    if (c == null) return;
    final all = <LatLng>[
      ...markers.value.map((m) => m.position),
      ...overlayMarkers.value.map((m) => m.position),
    ];
    if (all.isEmpty) return;

    double minLat = all.first.latitude;
    double maxLat = all.first.latitude;
    double minLng = all.first.longitude;
    double maxLng = all.first.longitude;
    for (final p in all) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    const eps = 0.00012;
    if ((maxLat - minLat).abs() < eps) {
      maxLat += eps;
      minLat -= eps;
    }
    if ((maxLng - minLng).abs() < eps) {
      maxLng += eps;
      minLng -= eps;
    }
    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );

    try {
      await c.animateCamera(CameraUpdate.newLatLngBounds(bounds, padding));
    } catch (_) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      try {
        await c.animateCamera(CameraUpdate.newLatLngBounds(bounds, padding));
      } catch (_) {}
    }
  }

  void setMode(RideMapMode mode) {
    if (_mode == mode) return;
    _mode = mode;
  }

  void setBottomSheetHeight(double height) {
    bottomSheetHeight = height < 0 ? 0 : height;
  }

  void setVehicleType(RideVehicleType type) {
    if (_vehicleType == type) return;
    _vehicleType = type;
    _vehicleIcon = null;
    _vehicleIconLoading = false;
    _ensureVehicleIcon();
  }

  Future<void> _ensureVehicleIcon() async {
    if (_vehicleIcon != null || _vehicleIconLoading) return;
    _vehicleIconLoading = true;
    try {
      _vehicleIcon = await MarkerIconCache.loadVehicle(_vehicleType);
      _rebuildVehicleMarker();
    } finally {
      _vehicleIconLoading = false;
    }
  }

  void setPickupDrop({
    LatLng? pickup,
    LatLng? drop,
    bool showPickupPin = false,
    bool showDropPin = false,
  }) {
    _pickup = pickup;
    _drop = drop;
    _rebuildStaticMarkers(showPickupPin: showPickupPin, showDropPin: showDropPin);
  }

  void setShowCompletedRoute(bool show) {
    _showCompleted = show;
    _rebuildPolylines();
  }

  void clearRoute() {
    _routeFull = <LatLng>[];
    _remaining = <LatLng>[];
    _completed = <LatLng>[];
    _navDestination = null;
    _rebuildPolylines();
  }

  void setOverlays({
    Set<Marker>? markers,
    Set<Polyline>? polylines,
    Set<Circle>? circles,
  }) {
    if (markers != null) overlayMarkers.value = markers;
    if (polylines != null) overlayPolylines.value = polylines;
    if (circles != null) overlayCircles.value = circles;
  }

  void setRoutePoints(List<LatLng> points) {
    _routeFull = List<LatLng>.from(points);
    _remaining = List<LatLng>.from(points);
    _completed = <LatLng>[];
    _rebuildPolylines();
  }

  Future<void> fetchAndSetRoute({
    required LatLng origin,
    required LatLng destination,
    bool driverFriendlyStop = false,
    String mode = 'driving',
  }) async {
    _navDestination = destination;
    _navDriverFriendlyStop = driverFriendlyStop;

    final res = await _routeService.fetchRoadRoute(
      origin: origin,
      destination: destination,
      driverFriendlyStop: driverFriendlyStop,
      mode: mode,
    );
    setRoutePoints(res.points);
  }

  void setNavigationDestination(
    LatLng? destination, {
    bool driverFriendlyStop = false,
  }) {
    _navDestination = destination;
    _navDriverFriendlyStop = driverFriendlyStop;
  }

  void updateVehicleLocation(
    LatLng raw, {
    double? speedMetersPerSecond,
    double? headingDeg,
  }) {
    _ensureVehicleIcon();

    final current = _vehicleAnim.pose.value;
    final currentPos = current?.position;
    final currentBearing = current?.bearing ?? 0.0;

    LatLng targetPos = raw;

    if (_routeFull.length >= 2) {
      final trim = PolylineTrimUtils.trim(
        route: _routeFull,
        vehicle: raw,
        lookAheadPoints: 80,
      );

      // Snap to the route only if we're reasonably close.
      if (trim.snapDistanceMeters <= MapUiConfig.snapToRouteToleranceMeters) {
        targetPos = trim.snapped;
        _schedulePolylineUpdate(trim);
      } else {
        // Off-route: schedule a re-route when we have a destination.
        if (trim.snapDistanceMeters >= MapUiConfig.offRouteRecalcThresholdMeters) {
          final dest = _navDestination;
          if (dest != null) {
            // Fire-and-forget; controller callers already throttle route requests.
            unawaited(fetchAndSetRoute(
              origin: raw,
              destination: dest,
              driverFriendlyStop: _navDriverFriendlyStop,
            ));
          }
        }
      }
    }

    double targetBearing;
    if (headingDeg != null && headingDeg.isFinite && (speedMetersPerSecond ?? 0) >= 2.0) {
      targetBearing = headingDeg;
    } else if (currentPos != null) {
      targetBearing = BearingUtils.bearingBetween(currentPos, targetPos);
    } else {
      targetBearing = headingDeg ?? 0.0;
    }

    final smoothed = BearingUtils.smoothBearing(currentBearing, targetBearing, 0.35);

    // Large GPS jump handling: if it jumps too far, snap without long animation.
    if (currentPos != null) {
      final jump = _distanceMeters(currentPos, targetPos);
      if (jump > 120) {
        _vehicleAnim.setImmediate(targetPos, smoothed);
        _maybeMoveCamera(targetPos, smoothed, force: true);
        return;
      }
    }

    _vehicleAnim.animateTo(
      to: targetPos,
      bearingTo: smoothed,
      speedMetersPerSecond: speedMetersPerSecond,
    );
  }

  void _schedulePolylineUpdate(PolylineTrimResult trim) {
    // Throttle trim updates during animation.
    final now = trim.snapped;
    if (_lastTrimAt != null && _distanceMeters(_lastTrimAt!, now) < 0.8) return;
    _lastTrimAt = now;

    _polylineDebounce?.cancel();
    _polylineDebounce = Timer(const Duration(milliseconds: 90), () {
      _remaining = trim.remaining;
      _completed = trim.completed;
      _rebuildPolylines();
    });
  }

  void _onPoseTick() {
    final pose = _vehicleAnim.pose.value;
    if (pose == null) return;
    _updateVehicleMarker(pose);
    _maybeMoveCamera(pose.position, pose.bearing);
  }

  void _updateVehicleMarker(VehiclePose pose) {
    final icon = _vehicleIcon;
    if (icon == null) return;

    final set = markers.value;
    final next = <Marker>{...set.where((m) => m.markerId.value != 'driver')};
    next.add(
      Marker(
        markerId: const MarkerId('driver'),
        position: pose.position,
        icon: icon,
        anchor: const Offset(0.5, 0.5),
        flat: true,
        rotation: pose.bearing,
        zIndexInt: 50,
      ),
    );
    markers.value = next;
  }

  void _rebuildVehicleMarker() {
    final pose = _vehicleAnim.pose.value;
    if (pose != null) _updateVehicleMarker(pose);
  }

  void _rebuildStaticMarkers({bool showPickupPin = false, bool showDropPin = false}) {
    final set = markers.value;
    final keepDriver = set.where((m) => m.markerId.value == 'driver').toList();
    final next = <Marker>{...keepDriver};

    if (_pickup != null) {
      next.add(
        Marker(
          markerId: const MarkerId('pickup_bounds'),
          position: _pickup!,
          visible: showPickupPin,
          infoWindow: InfoWindow.noText,
          anchor: const Offset(0.5, 1.0),
          zIndexInt: 10,
        ),
      );
    }
    if (_drop != null) {
      next.add(
        Marker(
          markerId: const MarkerId('drop_bounds'),
          position: _drop!,
          visible: showDropPin,
          infoWindow: InfoWindow.noText,
          anchor: const Offset(0.5, 1.0),
          zIndexInt: 10,
        ),
      );
    }
    markers.value = next;
  }

  void _rebuildPolylines() {
    final next = <Polyline>{};

    if (_showCompleted && _completed.length >= 2) {
      next.add(
        Polyline(
          polylineId: const PolylineId('route_completed'),
          color: MapUiConfig.completedPolylineColor,
          width: MapUiConfig.polylineWidth,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
          jointType: JointType.round,
          geodesic: false,
          points: _completed,
          zIndex: 1,
        ),
      );
    }

    if (_remaining.length >= 2) {
      next.add(
        Polyline(
          polylineId: const PolylineId('route_active'),
          color: MapUiConfig.activePolylineColor,
          width: MapUiConfig.polylineWidth,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
          jointType: JointType.round,
          geodesic: false,
          points: _remaining,
          zIndex: 2,
        ),
      );
    }

    polylines.value = next;
  }

  void _maybeMoveCamera(LatLng target, double bearing, {bool force = false}) {
    if (!autoFollowEnabled) return;

    final c = _mapController;
    if (c == null) return;

    final now = DateTime.now();
    if (!force && now.difference(_lastCameraMoveAt).inMilliseconds < 240) return;

    if (!force && _lastCameraTarget != null) {
      final moved = _distanceMeters(_lastCameraTarget!, target);
      final turned = BearingUtils.angleDeltaDeg(_lastCameraBearing, bearing);
      if (moved < MapUiConfig.minCameraMoveMeters &&
          turned < MapUiConfig.minCameraBearingDeltaDeg) {
        return;
      }
    }

    _lastCameraMoveAt = now;
    _lastCameraTarget = target;
    _lastCameraBearing = bearing;

    final zoom = _isNavigationMode(_mode) ? MapUiConfig.navigationZoom : MapUiConfig.defaultZoom;
    final tilt = _isNavigationMode(_mode) ? MapUiConfig.cameraTilt : 0.0;

    // Lead target so vehicle stays visually "lower" (more road ahead).
    final leadMeters = _leadMetersFor(zoom, bottomSheetHeight);
    final followTarget = _offsetLatLng(target, bearing, leadMeters);

    unawaited(
      c.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: followTarget,
            zoom: zoom,
            tilt: tilt,
            bearing: MapUiConfig.cameraBearingEnabled ? bearing : 0.0,
          ),
        ),
      ),
    );
  }

  static bool _isNavigationMode(RideMapMode m) =>
      m == RideMapMode.pickupNavigation ||
      m == RideMapMode.dropNavigation ||
      m == RideMapMode.sharedPickup ||
      m == RideMapMode.sharedDrop;

  static double _leadMetersFor(double zoom, double bottomSheetHeight) {
    // Base lead (tuned for Ola/Uber-like framing).
    final base = zoom >= 16.2 ? 75.0 : zoom >= 15.0 ? 95.0 : 130.0;
    // Add more lead when a bottom sheet occupies space.
    final extra = (bottomSheetHeight / 6.0).clamp(0.0, 90.0);
    return base + extra;
  }

  static double _distanceMeters(LatLng a, LatLng b) {
    final dx = (a.latitude - b.latitude) * 111320.0;
    final dy =
        (a.longitude - b.longitude) *
        111320.0 *
        math.cos(a.latitude * math.pi / 180.0);
    return math.sqrt(dx * dx + dy * dy);
  }

  static LatLng _offsetLatLng(LatLng origin, double bearingDeg, double meters) {
    // Use a lightweight spherical offset (same as in SharedMap, but centralized).
    const earthRadiusM = 6378137.0;
    final br = bearingDeg * math.pi / 180.0;
    final d = meters / earthRadiusM;

    final lat1 = origin.latitude * math.pi / 180.0;
    final lng1 = origin.longitude * math.pi / 180.0;

    final sinLat1 = math.sin(lat1);
    final cosLat1 = math.cos(lat1);
    final sinD = math.sin(d);
    final cosD = math.cos(d);
    final cosBr = math.cos(br);
    final sinBr = math.sin(br);

    final lat2 = math.asin(sinLat1 * cosD + cosLat1 * sinD * cosBr);
    final lng2 = lng1 +
        math.atan2(
          sinBr * sinD * cosLat1,
          cosD - sinLat1 * math.sin(lat2),
        );

    return LatLng(lat2 * 180.0 / math.pi, lng2 * 180.0 / math.pi);
  }

  void dispose() {
    _polylineDebounce?.cancel();
    _vehicleAnim.pose.removeListener(_poseListener);
    _vehicleAnim.dispose();
    markers.dispose();
    polylines.dispose();
    overlayMarkers.dispose();
    overlayPolylines.dispose();
    overlayCircles.dispose();
  }
}
