import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'bearing_utils.dart';
import 'map_ui_config.dart';
import 'marker_icon_cache.dart';
import 'polyline_trim_utils.dart';
import 'reroute_service.dart';
import 'route_polyline_service.dart';
import 'route_snap_service.dart';
import 'travel_mode_resolver.dart';
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
  bool _disposed = false;

  // One-time init guard (per destination) to avoid blank map until user taps
  // current-location. We initialize camera/route automatically when ready.
  LatLng? _lastInitDestination;
  bool _initRanForDestination = false;
  bool _initInFlight = false;

  // One-time fit guard (per destination + route signature).
  LatLng? _lastFitDestination;
  int _lastFitRouteSig = 0;

  static const String _kRideLightMapStyleAsset =
      'assets/map_styles/ride_light_map_style.json';
  static Future<String?>? _rideLightStyleFuture;
  static Future<String?> _loadRideLightStyle() {
    return _rideLightStyleFuture ??= () async {
      try {
        return await rootBundle.loadString(_kRideLightMapStyleAsset);
      } catch (_) {
        return null;
      }
    }();
  }

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
  RideVehicleType get vehicleType => _vehicleType;
  BitmapDescriptor? _vehicleIcon;
  bool _vehicleIconLoading = false;

  LatLng? _pickup;
  LatLng? _drop;
  LatLng? get pickupPosition => _pickup;
  LatLng? get dropPosition => _drop;
  LatLng? get lastVehiclePosition => _vehicleAnim.pose.value?.position;
  LatLng? get navigationDestination => _navDestination;

  // Route state
  List<LatLng> _routeFull = <LatLng>[];
  List<LatLng> _remaining = <LatLng>[];
  List<LatLng> _completed = <LatLng>[];
  bool _showCompleted = true;

  final RouteSnapService _snapService = const RouteSnapService();
  final RerouteService _rerouteService = RerouteService();

  // For stable bearing: use snapped movement history.
  LatLng? _lastSnappedForBearing;
  LatLng? _lastLookAheadPoint;

  // GPS filter + reroute throttle state (centralized; screens should not duplicate).
  LatLng? _lastAcceptedGps;
  DateTime? _lastAcceptedAt;
  int _offRouteConsecutive = 0;

  // Debounce polyline updates while animating to avoid flicker.
  Timer? _polylineDebounce;
  LatLng? _lastTrimAt;
  int _lastTrimNearestIndex = -1;

  // Exposed UI knobs
  bool autoFollowEnabled = true;
  double bottomSheetHeight = 0.0;
  double _lastSpeedMs = 0.0;

  /// Preferred navigation zoom based on latest speed (m/s).
  double get navigationFollowZoom {
    final s = _lastSpeedMs;
    // slow / near stop -> closer zoom
    if (s <= 1.2) return 17.5;
    // city normal
    if (s <= 6.0) return 17.2;
    // faster road -> slightly zoom out
    return 16.8;
  }

  LatLng? _navDestination;
  bool _navDriverFriendlyStop = false;

  void _dbg(String message) {
    if (!kDebugMode) return;
    // ignore: avoid_print
    print('[RIDE_MAP][${_mode.name}] $message');
  }

  void attachMapController(GoogleMapController controller) {
    _mapController = controller;
    // Apply premium light navigation map style (loaded once and reused).
    unawaited(() async {
      final style = await _loadRideLightStyle();
      if (_disposed) return;
      if (style == null || style.trim().isEmpty) return;
      try {
        await controller.setMapStyle(style);
      } catch (_) {}
    }());

    _dbg('attachMapController(): mapControllerReady=true');
    // Auto-init map camera/route as soon as controller is ready.
    unawaited(initializeRideMapIfReady(source: 'onMapCreated'));
  }

  void setAutoFollowEnabled(bool enabled) {
    autoFollowEnabled = enabled;
    _dbg('setAutoFollowEnabled($enabled)');
    if (enabled) {
      unawaited(initializeRideMapIfReady(source: 'location_button/autoFollow'));
    }
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
    _dbg('setBottomSheetHeight($bottomSheetHeight)');
    unawaited(initializeRideMapIfReady(source: 'bottomSheetHeight'));
  }

  void setVehicleType(RideVehicleType type) {
    if (_vehicleType == type) return;
    _vehicleType = type;
    _vehicleIcon = null;
    _vehicleIconLoading = false;
    _dbg('setVehicleType($_vehicleType) -> ensure icon');
    _ensureVehicleIcon();
  }

  Future<void> _ensureVehicleIcon() async {
    if (_disposed) return;
    if (_vehicleIcon != null || _vehicleIconLoading) return;
    _vehicleIconLoading = true;
    try {
      _dbg('_ensureVehicleIcon(): loading icon for $_vehicleType');
      _vehicleIcon = await MarkerIconCache.loadVehicle(_vehicleType);
      if (_disposed) return;
      _dbg('_ensureVehicleIcon(): icon loaded ok for $_vehicleType');
      _rebuildVehicleMarker();
    } catch (e) {
      _dbg('_ensureVehicleIcon(): icon load FAILED for $_vehicleType err=$e');
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
    _offRouteConsecutive = 0;
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
    _offRouteConsecutive = 0;
    _rebuildPolylines();

    // Fit only on first route load / destination change / reroute success.
    final pose = _vehicleAnim.pose.value;
    final dest = _navDestination;
    if (pose != null && dest != null && _routeFull.length >= 2) {
      unawaited(
        fitCameraToRouteOnce(
          routePoints: _routeFull,
          driverLocation: pose.position,
          destination: dest,
          bottomSheetHeight: bottomSheetHeight,
        ),
      );
    }
  }

  Future<void> fetchAndSetRoute({
    required LatLng origin,
    required LatLng destination,
    bool driverFriendlyStop = false,
    String? mode,
  }) async {
    _navDestination = destination;
    _navDriverFriendlyStop = driverFriendlyStop;

    final resolvedMode =
        mode ?? TravelModeResolver.getTravelMode(_vehicleType);
    final res = await _routeService.fetchRoadRoute(
      origin: origin,
      destination: destination,
      driverFriendlyStop: driverFriendlyStop,
      mode: resolvedMode,
    );
    setRoutePoints(res.points);
  }

  void setNavigationDestination(
    LatLng? destination, {
    bool driverFriendlyStop = false,
  }) {
    _navDestination = destination;
    _navDriverFriendlyStop = driverFriendlyStop;
    _dbg(
      'setNavigationDestination(dest=$destination, driverFriendlyStop=$driverFriendlyStop)',
    );
    // Destination changed -> allow one-time init for new dest.
    if (_lastInitDestination == null ||
        destination == null ||
        _distanceMeters(_lastInitDestination!, destination) > 5.0) {
      _lastInitDestination = destination;
      _initRanForDestination = false;
    }
    unawaited(initializeRideMapIfReady(source: 'destination_loaded'));
  }

  void updateVehicleLocation(
    LatLng raw, {
    double? speedMetersPerSecond,
    double? headingDeg,
    double? accuracyMeters,
    DateTime? timestamp,
  }) {
    _dbg(
      'updateVehicleLocation(raw=$raw, acc=${accuracyMeters?.toStringAsFixed(1)}, '
      'speed=${speedMetersPerSecond?.toStringAsFixed(2)}, heading=${headingDeg?.toStringAsFixed(1)})',
    );
    _ensureVehicleIcon();
    if (speedMetersPerSecond != null && speedMetersPerSecond.isFinite) {
      _lastSpeedMs = speedMetersPerSecond;
    }

    final current = _vehicleAnim.pose.value;
    final currentPos = current?.position;
    final currentBearing = current?.bearing ?? 0.0;

    final deviceNow = DateTime.now();
    DateTime pointTime = timestamp ?? deviceNow;

    // ================= Timestamp filtering =================
    // Socket replays / delayed packets cause the marker to "rewind" and the
    // camera to face backwards. Filter aggressively but keep first paint.
    if (pointTime.isBefore(deviceNow.subtract(MapUiConfig.maxLocationAge))) {
      if (currentPos == null) {
        _vehicleAnim.setImmediate(raw, currentBearing);
      }
      return;
    }
    // Allow slight future skew.
    if (pointTime.isAfter(deviceNow.add(MapUiConfig.maxFutureSkew))) {
      pointTime = deviceNow;
    }

    // ================= GPS filtering (do not place marker on raw GPS) =================
    if (accuracyMeters != null &&
        accuracyMeters.isFinite &&
        accuracyMeters > MapUiConfig.gpsAccuracyRejectMeters) {
      // UX: if we don't have any marker yet, still place an initial marker so
      // the map doesn't look "empty". Subsequent updates remain strict.
      if (currentPos == null) {
        _vehicleAnim.setImmediate(raw, currentBearing);
      }
      return;
    }

    final lastAccepted = _lastAcceptedGps;
    if (lastAccepted != null) {
      final moved = _distanceMeters(lastAccepted, raw);
      final hasSpeed = speedMetersPerSecond != null && speedMetersPerSecond.isFinite;
      final speed = hasSpeed ? speedMetersPerSecond : 0.0;

      // Ignore tiny movements (noise).
      if (moved < MapUiConfig.minMoveAcceptMeters) return;

      // Ignore stationary drift (GPS wandering while stopped/slow).
      if (speed < 1.0 && moved < MapUiConfig.stationaryDriftIgnoreMeters) return;

      // Reject physically implausible movement based on timestamps (prevents jumps).
      final lastAt = _lastAcceptedAt;
      if (lastAt != null) {
        final dtMs = pointTime.difference(lastAt).inMilliseconds;
        if (dtMs > 120) {
          final implied = moved / (dtMs / 1000.0);
          if (implied > MapUiConfig.maxImpliedSpeedMetersPerSecond) {
            return;
          }
        }
      }
    }

    _lastAcceptedGps = raw;
    _lastAcceptedAt = pointTime;
    LatLng filteredPos = raw;

    if (_routeFull.length >= 2) {
      final snap = _snapService.snapAndTrim(
        route: _routeFull,
        vehicle: filteredPos,
        lookAheadPoints: 80,
        lookAheadMeters: _lookAheadMeters(speedMetersPerSecond),
      );

      // Snap to the route only if we're reasonably close.
      if (snap.distanceToRouteMeters <= MapUiConfig.snapToRouteToleranceMeters) {
        _offRouteConsecutive = 0;
        filteredPos = snap.snapped;
        _lastLookAheadPoint = snap.lookAheadPoint;
        _schedulePolylineUpdate(
          PolylineTrimResult(
            snapped: snap.snapped,
            snapDistanceMeters: snap.distanceToRouteMeters,
            nearestIndex: snap.nearestIndex,
            remaining: snap.remaining,
            completed: snap.completed,
          ),
        );
      } else {
        // Off-route: keep marker on filtered raw point, but only reroute after
        // consecutive misses to avoid re-route spam from one noisy GPS sample.
        _offRouteConsecutive++;
        if (_offRouteConsecutive >= MapUiConfig.offRouteConfirmCount) {
          _offRouteConsecutive = 0;
          unawaited(
            _maybeAutoReroute(
              origin: filteredPos,
              offRouteMeters: snap.distanceToRouteMeters,
              now: pointTime,
            ),
          );
        }
      }
    }

    final targetPos = filteredPos;

    final speed = speedMetersPerSecond ?? 0.0;

    double targetBearing = currentBearing;
    if (speed > 2.0) {
      // Prefer route look-ahead bearing if available; it prevents the camera
      // from flipping "backwards" when GPS jitter briefly moves opposite.
      if (_lastLookAheadPoint != null) {
        targetBearing = BearingUtils.bearingBetween(targetPos, _lastLookAheadPoint!);
      } else {
        // Movement-based bearing feels most natural (no compass wobble).
        final from = _lastSnappedForBearing ?? currentPos;
        if (from != null && _distanceMeters(from, targetPos) >= 1.2) {
          targetBearing = BearingUtils.bearingBetween(from, targetPos);
        } else if (headingDeg != null && headingDeg.isFinite) {
          targetBearing = headingDeg;
        }
      }
    } else {
      // Low speed: keep stable bearing.
      targetBearing = currentBearing;
    }

    if (_lastSnappedForBearing == null ||
        _distanceMeters(_lastSnappedForBearing!, targetPos) >= 2.0) {
      _lastSnappedForBearing = targetPos;
    }

    final smoothed = BearingUtils.smoothBearing(currentBearing, targetBearing, 0.35);

    // Large GPS jump handling: if it jumps too far, snap without long animation.
    if (currentPos != null) {
      final jump = _distanceMeters(currentPos, targetPos);
      if (jump > MapUiConfig.gpsJumpResyncMeters) {
        _vehicleAnim.setImmediate(targetPos, smoothed);
        return;
      }
    }

    _vehicleAnim.animateTo(
      to: targetPos,
      bearingTo: smoothed,
      speedMetersPerSecond: speedMetersPerSecond,
    );

    // Map should never wait for a "current location" button click to become usable.
    // Kick init when we get the first valid pose.
    unawaited(initializeRideMapIfReady(source: 'driver_location_update'));
  }

  Future<void> initializeRideMapIfReady({String source = 'unknown'}) async {
    if (_disposed) {
      _dbg('initializeRideMapIfReady($source) -> earlyReturn: disposed=true');
      return;
    }
    final c = _mapController;
    final mapControllerReady = c != null;
    if (!mapControllerReady) {
      _dbg(
        'initializeRideMapIfReady($source) -> earlyReturn: mapControllerReady=false',
      );
      return;
    }
    if (_initInFlight) {
      _dbg('initializeRideMapIfReady($source) -> earlyReturn: initInFlight=true');
      return;
    }

    final pose = _vehicleAnim.pose.value;
    final dest = _navDestination;
    _dbg(
      'initializeRideMapIfReady($source) state: '
      'mapControllerReady=$mapControllerReady, '
      'latestDriverLocation=${pose?.position}, '
      'destinationLatLng=$dest, '
      'routePoints=${_routeFull.length}, '
      'hasInitializedForDestination=$_initRanForDestination, '
      'initDestination=$_lastInitDestination, '
      'isRouteLoading=$_initInFlight, '
      'bottomSheetHeight=$bottomSheetHeight, '
      'mode=${_mode.name}',
    );

    // If we already ran init for this destination, do nothing.
    if (_initRanForDestination &&
        _lastInitDestination != null &&
        dest != null &&
        _distanceMeters(_lastInitDestination!, dest) <= 5.0) {
      _dbg(
        'initializeRideMapIfReady($source) -> earlyReturn: alreadyInitializedForDestination=true',
      );
      return;
    }

    // 1) If driver location is available, move camera to driver immediately.
    if (pose != null) {
      try {
        await focusVehicle(
          zoom: MapUiConfig.navigationZoom,
          tilt: MapUiConfig.cameraTilt,
          bearingEnabled: MapUiConfig.cameraBearingEnabled,
        );
        _dbg('initializeRideMapIfReady($source): focused vehicle');
      } catch (_) {}
    }

    // 2) If both driver + destination available, fetch route and fit once.
    if (pose == null) {
      _dbg(
        'initializeRideMapIfReady($source) -> earlyReturn: latestDriverLocation=null',
      );
      return;
    }
    if (dest == null) {
      _dbg(
        'initializeRideMapIfReady($source) -> earlyReturn: destinationLatLng=null',
      );
      return;
    }

    _initInFlight = true;
    try {
      // Fetch road-matched route only once per destination (or after reroute).
      if (_routeFull.length < 2) {
        _dbg(
          'initializeRideMapIfReady($source): fetching route origin=${pose.position} dest=$dest',
        );
        final res = await _routeService.fetchRoadRoute(
          origin: pose.position,
          destination: dest,
          driverFriendlyStop: _navDriverFriendlyStop,
          mode: TravelModeResolver.getTravelMode(_vehicleType),
        );
        if (_disposed) return;
        if (res.points.length >= 2) {
          setRoutePoints(res.points);
          _dbg(
            'initializeRideMapIfReady($source): route set points=${res.points.length}',
          );
        } else {
          _dbg(
            'initializeRideMapIfReady($source): route fetch returned <2 points',
          );
        }
      }

      // Fit bounds once so route isn't hidden behind bottom sheet.
      if (_routeFull.length >= 2) {
        _dbg('initializeRideMapIfReady($source): fitCameraToRouteOnce()');
        unawaited(
          fitCameraToRouteOnce(
            routePoints: _routeFull,
            driverLocation: pose.position,
            destination: dest,
            bottomSheetHeight: bottomSheetHeight,
          ),
        );
      } else {
        _dbg('initializeRideMapIfReady($source): skip fit (routePoints<2)');
      }

      _lastInitDestination = dest;
      _initRanForDestination = true;
      _dbg('initializeRideMapIfReady($source): init completed ok');
    } catch (e) {
      _dbg('initializeRideMapIfReady($source) -> exception: $e');
      // keep screen stable; fallback route logic already exists elsewhere
    } finally {
      _initInFlight = false;
    }
  }

  Future<void> fitCameraToRouteOnce({
    required List<LatLng> routePoints,
    required LatLng driverLocation,
    required LatLng destination,
    required double bottomSheetHeight,
  }) async {
    if (_disposed) return;
    final c = _mapController;
    if (c == null) return;
    if (routePoints.length < 2) return;

    // Guard: do not repeatedly fit on GPS ticks.
    final sig = _routeSignature(routePoints);
    if (_lastFitDestination != null &&
        _distanceMeters(_lastFitDestination!, destination) <= 5.0 &&
        _lastFitRouteSig == sig) {
      return;
    }
    _lastFitDestination = destination;
    _lastFitRouteSig = sig;

    // Bounds must include driver + destination + all points.
    final all = <LatLng>[driverLocation, destination, ...routePoints];
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

    // Very short route: avoid zooming out too much.
    final spanLat = (maxLat - minLat).abs();
    final spanLng = (maxLng - minLng).abs();
    final isShort =
        spanLat < 0.00055 && spanLng < 0.00055; // ~60m-ish in latitude

    final padding = 48.0;
    final bottomPad = bottomSheetHeight + 80.0;

    // newLatLngBounds can fail if called too early; schedule after first frame.
    SchedulerBinding.instance.addPostFrameCallback((_) async {
      if (_disposed) return;
      await Future<void>.delayed(const Duration(milliseconds: 300));
      if (_disposed) return;
      try {
        if (isShort) {
          final mid = LatLng(
            (driverLocation.latitude + destination.latitude) / 2.0,
            (driverLocation.longitude + destination.longitude) / 2.0,
          );
          final bearing = _vehicleAnim.pose.value?.bearing ?? 0.0;
          await c.animateCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(
                target: mid,
                zoom: 17.4,
                tilt: MapUiConfig.cameraTilt,
                bearing: MapUiConfig.cameraBearingEnabled ? bearing : 0.0,
              ),
            ),
          );
          return;
        }

        const eps = 0.00012;
        if (spanLat < eps) {
          maxLat += eps;
          minLat -= eps;
        }
        if (spanLng < eps) {
          maxLng += eps;
          minLng -= eps;
        }

        final bounds = LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        );

        await c.animateCamera(
          CameraUpdate.newLatLngBounds(
            bounds,
            padding, // google maps uses a uniform padding double
          ),
        );

        // Extra: apply bottom bias by zooming slightly in after bounds fit.
        // Then clamp zoom to prevent world/city zoom-out.
        final z = await c.getZoomLevel();
        final clamped =
            (z + MapUiConfig.boundsFitExtraZoomIn).clamp(
              MapUiConfig.boundsFitMinZoom,
              MapUiConfig.boundsFitMaxZoom,
            );
        if ((clamped - z).abs() > 0.05) {
          await c.animateCamera(CameraUpdate.zoomTo(clamped));
        }

        // Apply bottom padding shift by nudging target upwards a bit (optional).
        // GoogleMapController doesn't accept asymmetric padding here, so we bias
        // navigation follow camera via SharedMap padding handling.
        // Keep this no-op aside from uniform padding + zoom clamp.
        // bottomPad is intentionally unused here.
        // ignore: unused_local_variable
        final _ = bottomPad;
      } catch (_) {
        // Ignore (some devices throw if map not laid out yet).
      }
    });
  }

  static int _routeSignature(List<LatLng> pts) {
    // Cheap signature: first/last and length.
    if (pts.isEmpty) return 0;
    final a = pts.first;
    final b = pts.last;
    int h = pts.length;
    h = 31 * h + (a.latitude * 1e5).round();
    h = 31 * h + (a.longitude * 1e5).round();
    h = 31 * h + (b.latitude * 1e5).round();
    h = 31 * h + (b.longitude * 1e5).round();
    return h;
  }

  Future<void> _maybeAutoReroute({
    required LatLng origin,
    required double offRouteMeters,
    required DateTime now,
  }) async {
    if (offRouteMeters < MapUiConfig.offRouteRecalcThresholdMeters) return;

    final dest = _navDestination;
    if (dest == null) return;

    final res = await _rerouteService.reroute(
      origin: origin,
      destination: dest,
      vehicleType: _vehicleType,
      driverFriendlyStop: _navDriverFriendlyStop,
      now: now,
    );
    if (res == null || res.points.length < 2) return;

    // Replace route only after success (no flicker).
    setRoutePoints(res.points);
  }

  void _schedulePolylineUpdate(PolylineTrimResult trim) {
    // Throttle trim updates during animation.
    final now = trim.snapped;
    if (trim.nearestIndex == _lastTrimNearestIndex &&
        _lastTrimAt != null &&
        _distanceMeters(_lastTrimAt!, now) < 2.0) {
      return;
    }
    _lastTrimAt = now;
    _lastTrimNearestIndex = trim.nearestIndex;

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
  }

  void _updateVehicleMarker(VehiclePose pose) {
    if (_disposed) return;
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
        rotation: _bearingWithIconOffset(pose.bearing),
        zIndexInt: 50,
      ),
    );
    try {
      markers.value = next;
    } catch (_) {
      // If disposed between async frames, ignore.
    }
  }

  void _rebuildVehicleMarker() {
    if (_disposed) return;
    final pose = _vehicleAnim.pose.value;
    if (pose != null) _updateVehicleMarker(pose);
  }

  void _rebuildStaticMarkers({bool showPickupPin = false, bool showDropPin = false}) {
    if (_disposed) return;
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
    try {
      markers.value = next;
    } catch (_) {}
  }

  void _rebuildPolylines() {
    if (_disposed) return;
    final next = <Polyline>{};

    if (_showCompleted && _completed.length >= 2) {
      // Shadow / outline for completed route.
      next.add(
        Polyline(
          polylineId: const PolylineId('route_completed_shadow'),
          color: MapUiConfig.completedPolylineShadowColor,
          width: MapUiConfig.polylineShadowWidth,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
          jointType: JointType.round,
          geodesic: false,
          points: _completed,
          zIndex: 0,
        ),
      );
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
      // Shadow / outline for active route (Uber/Ola style).
      next.add(
        Polyline(
          polylineId: const PolylineId('route_active_shadow'),
          color: MapUiConfig.activePolylineShadowColor,
          width: MapUiConfig.polylineShadowWidth,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
          jointType: JointType.round,
          geodesic: false,
          points: _remaining,
          zIndex: 2,
        ),
      );
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
          zIndex: 3,
        ),
      );
    }

    try {
      polylines.value = next;
    } catch (_) {}
  }

  static bool _isNavigationMode(RideMapMode m) =>
      m == RideMapMode.pickupNavigation ||
      m == RideMapMode.dropNavigation ||
      m == RideMapMode.sharedPickup ||
      m == RideMapMode.sharedDrop;

  double _bearingWithIconOffset(double bearing) {
    final base = BearingUtils.normalize360(bearing);
    final offset = switch (_vehicleType) {
      RideVehicleType.car => MapUiConfig.carBearingOffsetDeg,
      RideVehicleType.bike => MapUiConfig.bikeBearingOffsetDeg,
      RideVehicleType.packageBike => MapUiConfig.packageBikeBearingOffsetDeg,
    };
    return BearingUtils.normalize360(base + offset);
  }

  static double _distanceMeters(LatLng a, LatLng b) {
    final dx = (a.latitude - b.latitude) * 111320.0;
    final dy =
        (a.longitude - b.longitude) *
        111320.0 *
        math.cos(a.latitude * math.pi / 180.0);
    return math.sqrt(dx * dx + dy * dy);
  }

  static double _lookAheadMeters(double? speedMetersPerSecond) {
    final speed = (speedMetersPerSecond != null && speedMetersPerSecond.isFinite)
        ? speedMetersPerSecond
        : 0.0;
    final base =
        MapUiConfig.lookAheadMinMeters + (speed * 8.0); // ~8m per m/s
    return base.clamp(MapUiConfig.lookAheadMinMeters, MapUiConfig.lookAheadMaxMeters);
  }

  void dispose() {
    _disposed = true;
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
