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

enum MapFocusMode { driver, fullTrip }

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
  bool get hasActiveRoute => _routeFull.length >= 2;

  // Route state
  List<LatLng> _routeFull = <LatLng>[];
  List<LatLng> _remaining = <LatLng>[];
  List<LatLng> _completed = <LatLng>[];
  bool _showCompleted = true;
  bool _routeIsFallbackStraight = false;
  Timer? _routeRetryTimer;
  DateTime _lastRouteRetryAt = DateTime.fromMillisecondsSinceEpoch(0);

  // Full-trip preview (pickup->drop) used during pickupNavigation when the user
  // taps the "full trip" (landscape) control. This ensures the entire ride
  // polygon can be shown even before the ride starts.
  List<LatLng> _previewPickupToDrop = <LatLng>[];
  String _previewPickupToDropSig = '';
  bool _previewRouteLoading = false;

  final RouteSnapService _snapService = const RouteSnapService();
  final RerouteService _rerouteService = RerouteService();

  // For stable bearing: use snapped movement history.
  LatLng? _lastSnappedForBearing;
  LatLng? _lastLookAheadPoint;

  // GPS filter + reroute throttle state (centralized; screens should not duplicate).
  LatLng? _lastAcceptedGps;
  DateTime? _lastAcceptedAt;
  int _offRouteConsecutive = 0;

  // Dead-reckoning state (visual-only extrapolation for brief socket gaps).
  Timer? _deadReckonTimer;
  DateTime? _lastLiveUpdateAt;
  LatLng? _lastLivePosition;
  double _lastLiveBearing = 0.0;
  double _lastLiveSpeedMs = 0.0;

  // Debounce polyline updates while animating to avoid flicker.
  Timer? _polylineDebounce;
  LatLng? _lastTrimAt;
  int _lastTrimNearestIndex = -1;

  // Exposed UI knobs
  bool autoFollowEnabled = true;
  double bottomSheetHeight = 0.0;
  double _lastSpeedMs = 0.0;

  // Single source of truth for focus button toggle state.
  final ValueNotifier<MapFocusMode> focusMode =
      ValueNotifier<MapFocusMode>(MapFocusMode.fullTrip);
  bool _initialFullTripFitDone = false;

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

  /// Whether the follow camera should rotate the map (heading-up).
  ///
  /// Keep the map north-up when standing/crawling so "up/down" on the screen
  /// remains intuitive (Google Maps browse-like behavior). Once we detect
  /// movement above a small speed threshold, enable heading-up navigation.
  bool get cameraBearingEnabledNow {
    if (!MapUiConfig.cameraBearingEnabled) return false;
    if (!_isNavigationMode(_mode)) return false;
    return _lastSpeedMs >= MapUiConfig.cameraBearingEnableMinSpeedMs;
  }

  LatLng? _navDestination;
  bool _navDriverFriendlyStop = false;

  void _dbg(String message) {
    if (!kDebugMode) return;
    // ignore: avoid_print
    print('[RIDE_MAP][${_mode.name}] $message');
  }

  void attachMapController(GoogleMapController controller) {
    // When the platform view is recreated (most commonly due to orientation
    // change / landscape), GoogleMap provides a NEW controller. Our controller
    // instance can survive across that rebuild, so we must re-run the one-time
    // camera init/fits for the *new* map controller; otherwise the map can stay
    // at a default camera and the full-trip polyline appears "missing".
    final hadController = _mapController != null;
    _mapController = controller;
    if (hadController) {
      _initRanForDestination = false;
      _initInFlight = false;
      _initialFullTripFitDone = false;
      _lastFitDestination = null;
      _lastFitRouteSig = 0;
    }
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
    // Preload the vehicle icon early so the first live position can render a marker immediately.
    _dbg('[ICON_CACHE] preload $_vehicleType started');
    unawaited(_ensureVehicleIcon());
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
    if (c == null) return;
    // If the animated pose isn't ready yet (e.g. screen just opened but we have
    // a live socket fix), fall back to last live position so the location button
    // still works immediately.
    final fallbackPos = _lastLivePosition;
    if (pose == null && fallbackPos == null) return;
    final target = pose?.position ?? fallbackPos!;
    final bearing = pose?.bearing ?? _lastLiveBearing;
    final z = (zoom ?? (_isNavigationMode(_mode) ? MapUiConfig.navigationZoom : MapUiConfig.defaultZoom))
        .clamp(11.5, 17.8);
    final t = (tilt ?? (_isNavigationMode(_mode) ? MapUiConfig.cameraTilt : 0.0)).clamp(0.0, 60.0);
    try {
      await c.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: target,
            zoom: z,
            tilt: t,
            bearing: bearingEnabled ? bearing : 0.0,
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

  /// Fit the full active trip (driver + pickup + drop + route polyline).
  ///
  /// This is the "second tap" behavior for the existing location/focus button.
  /// If there is no active polyline, it falls back to fitting current markers.
  Future<void> fitFullTrip({
    double padding = 95,
    bool clampMinZoom = false,
    bool includeAllStops = false,
  }) async {
    final c = _mapController;
    if (c == null) return;

    final route = _routeFull;
    final pose = _vehicleAnim.pose.value;
    final preview =
        (includeAllStops && _mode == RideMapMode.pickupNavigation)
            ? _previewPickupToDrop
            : const <LatLng>[];
    final pts = <LatLng>[
      ..._fitPointsForMode(includeAllStops: includeAllStops),
      // Include overlay markers (maneuvers/stop pins) so full-fit never hides them.
      ...overlayMarkers.value.map((m) => m.position),
      // IMPORTANT: include the *entire* polyline to ensure route-overview never
      // crops curved routes that extend beyond the pickup/drop bounding box.
      ...route,
      ...preview,
    ];

    // If we don't have enough points to compute bounds, fallback to focusing the driver.
    // If the polyline isn't loaded yet but we have driver/pickup/drop points, we still
    // fit bounds using those markers (prevents "blank random focus" on open).
    if (pts.length < 2) {
      _dbg(
        'fitFullTrip(): routePoints=${route.length} preview=${preview.length} points=${pts.length} -> focus driver',
      );
      if (pose != null) {
        await focusVehicle(
          zoom: MapUiConfig.navigationZoom,
          tilt: MapUiConfig.cameraTilt,
          bearingEnabled: cameraBearingEnabledNow,
        );
        return;
      }
      await fitToBounds(padding: padding);
      return;
    }

    _dbg(
      'fitFullTrip(): routePoints=${route.length} preview=${preview.length} points=${pts.length} padding=$padding',
    );

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
      // Some devices throw if the map isn't fully laid out yet.
      await Future<void>.delayed(const Duration(milliseconds: 250));
      try {
        await c.animateCamera(CameraUpdate.newLatLngBounds(bounds, padding));
      } catch (_) {}
    }

    if (clampMinZoom) {
      // Smart zoom clamp for short pickup legs: newLatLngBounds can zoom out too far
      // when padding is large or map size is small.
      //
      // NOTE: Only use this for the *initial* camera fit. For user-triggered "fit
      // full trip", we should never zoom-in beyond bounds (it can hide endpoints).
      final distMeters = _boundsDiagonalMeters(bounds);
      final minZoom =
          distMeters < 500.0
              ? MapUiConfig.minPickupFitZoom
              : (distMeters < 2000.0 ? 14.5 : 13.5);

      try {
        await Future<void>.delayed(const Duration(milliseconds: 220));
        final currentZoom = await c.getZoomLevel();
        if (currentZoom < minZoom) {
          final center = LatLng((minLat + maxLat) / 2, (minLng + maxLng) / 2);
          await c.animateCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(target: center, zoom: minZoom),
            ),
          );
        }
      } catch (_) {}
    }
  }

  double _boundsDiagonalMeters(LatLngBounds b) {
    return _distanceMeters(b.southwest, b.northeast);
  }

  void setMode(RideMapMode mode) {
    if (_mode == mode) return;
    _mode = mode;
    // Preview polyline is only relevant during pickup leg.
    if (_mode != RideMapMode.pickupNavigation) {
      _previewPickupToDrop = <LatLng>[];
      _previewPickupToDropSig = '';
      _previewRouteLoading = false;
    }
    _rebuildPreviewOverlayPolyline();
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
      _dbg('[ICON_CACHE] preload $_vehicleType done');
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
    // Guard: pickup marker must match the active pickup destination in pickupNavigation.
    // Some flows previously mixed "recommended stop" vs "actual pickup" which can
    // make the route appear to end before the marker.
    if (_mode == RideMapMode.pickupNavigation &&
        pickup != null &&
        _navDestination != null &&
        _distanceMeters(pickup, _navDestination!) > 2.0) {
      _dbg('[BUG_BLOCKED] pickup marker mismatch corrected');
      _pickup = _navDestination;
    } else {
      _pickup = pickup;
    }
    _drop = drop;
    final p = _pickup;
    if (p != null) {
      _dbg(
        '[PICKUP_MARKER] lat=${p.latitude} lng=${p.longitude}',
      );
    }
    _rebuildStaticMarkers(showPickupPin: showPickupPin, showDropPin: showDropPin);

    // Pickup/drop changed: clear stale preview so the next full-trip tap reflects
    // the current booking.
    _previewPickupToDrop = <LatLng>[];
    _previewPickupToDropSig = '';
    _previewRouteLoading = false;
    _rebuildPreviewOverlayPolyline();
  }

  void setShowCompletedRoute(bool show) {
    _showCompleted = show;
    _rebuildPolylines();
  }

  void clearRoute() {
    _routeFull = <LatLng>[];
    _remaining = <LatLng>[];
    _completed = <LatLng>[];
    _previewPickupToDrop = <LatLng>[];
    _previewPickupToDropSig = '';
    _previewRouteLoading = false;
    _navDestination = null;
    _offRouteConsecutive = 0;
    _initialFullTripFitDone = false;
    _routeIsFallbackStraight = false;
    _routeRetryTimer?.cancel();
    _rebuildPolylines();
    _rebuildPreviewOverlayPolyline();
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

  void setRoutePoints(List<LatLng> points, {bool isFallbackStraightLine = false}) {
    _routeFull = List<LatLng>.from(points);
    _remaining = List<LatLng>.from(points);
    _completed = <LatLng>[];
    _offRouteConsecutive = 0;
    _lastTrimNearestIndex = -1;
    _lastTrimAt = null;
    _routeIsFallbackStraight = isFallbackStraightLine;
    _rebuildPolylines();
    _initialFullTripFitDone = false;

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
      _initialFullTripFitDone = false;
    }
    unawaited(initializeRideMapIfReady(source: 'destination_loaded'));
  }

  void updateVehicleLocation(
    LatLng raw, {
    String source = 'unknown',
    double? speedMetersPerSecond,
    double? headingDeg,
    double? accuracyMeters,
    DateTime? timestamp,
  }) {
    _dbg('[VEHICLE_SOURCE] source=$source lat=${raw.latitude} lng=${raw.longitude}');
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

    // Track latest live socket/GPS fix so we can dead-reckon briefly if updates stall.
    final isRealSource = source == 'gps' || source == 'socket';
    if (isRealSource) {
      _lastLiveUpdateAt = deviceNow;
      _lastLivePosition = raw;
      if (speedMetersPerSecond != null && speedMetersPerSecond.isFinite) {
        _lastLiveSpeedMs = speedMetersPerSecond;
      }
      if (headingDeg != null && headingDeg.isFinite) {
        _lastLiveBearing = headingDeg;
      }
      _armDeadReckoning();
    }

    // ================= Timestamp filtering =================
    // Socket replays / delayed packets cause the marker to "rewind" and the
    // camera to face backwards. Filter aggressively but keep first paint.
    if (pointTime.isBefore(deviceNow.subtract(MapUiConfig.maxLocationAge))) return;
    // Allow slight future skew.
    if (pointTime.isAfter(deviceNow.add(MapUiConfig.maxFutureSkew))) {
      pointTime = deviceNow;
    }

    // ================= GPS filtering (do not place marker on raw GPS) =================
    if (accuracyMeters != null &&
        accuracyMeters.isFinite &&
        accuracyMeters > MapUiConfig.gpsAccuracyRejectMeters) {
      return;
    }

    final lastAccepted = _lastAcceptedGps;
    if (lastAccepted != null) {
      final moved = _distanceMeters(lastAccepted, raw);
      final hasSpeed = speedMetersPerSecond != null && speedMetersPerSecond.isFinite;
      final speed = hasSpeed ? speedMetersPerSecond : 0.0;

      // Ignore tiny movements (noise).
      // When we have an active route, we can safely accept smaller deltas for
      // smoother motion because we will snap to the polyline (map-matching).
      final allowSmallMove =
          (_routeFull.length >= 2 && source == 'socket') || (hasSpeed && speed > 2.0);
      if (moved < MapUiConfig.minMoveAcceptMeters && !allowSmallMove) return;

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

    // isRealSource already computed above (socket/gps).
    LatLng filteredPos = raw;
    double? snappedSegmentBearing;

    if (_routeFull.length >= 2) {
      final snap = _snapService.snapAndTrim(
        route: _routeFull,
        vehicle: filteredPos,
        lookAheadPoints: 80,
        lookAheadMeters: _lookAheadMeters(speedMetersPerSecond),
        previousNearestIndex: _lastTrimNearestIndex >= 0 ? _lastTrimNearestIndex : null,
      );

      // Snap to the route only if we're reasonably close.
      final snapTol = _snapToleranceMeters(
        accuracyMeters: accuracyMeters,
        speedMetersPerSecond: speedMetersPerSecond,
      );
      if (snap.distanceToRouteMeters <= snapTol) {
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

        // IMPORTANT tracking rule:
        // When a route polyline exists and we are snapped to it, bearing should
        // come from the polyline direction (not raw GPS heading). This prevents
        // backside/reverse camera and keeps the vehicle aligned to the route.
        if (snap.remaining.length >= 2) {
          snappedSegmentBearing = BearingUtils.bearingBetween(
            snap.remaining[0],
            snap.remaining[1],
          );
        }
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
    double? motionBearing;
    final motionFrom = _lastSnappedForBearing ?? currentPos;
    if (motionFrom != null && _distanceMeters(motionFrom, targetPos) >= 1.8) {
      motionBearing = BearingUtils.bearingBetween(motionFrom, targetPos);
    }
    final hasHeading = headingDeg != null && headingDeg.isFinite;
    final heading = hasHeading ? BearingUtils.normalize360(headingDeg!) : null;

    if (snappedSegmentBearing != null) {
      // Even at low speed (or slow GPS tick rate), keep the marker oriented
      // to the route when snapped. This prevents rotation shake at junctions.
      final routeBearing = snappedSegmentBearing;

      // Guard against rare cases where snapping/route direction flips ~180° due
      // to GPS jitter or a reversed remaining segment. Prefer real motion/heading
      // when route bearing is clearly contradictory.
      if (motionBearing != null &&
          BearingUtils.angleDeltaDeg(routeBearing, motionBearing) > 120.0) {
        if (heading != null &&
            BearingUtils.angleDeltaDeg(heading, motionBearing) <= 70.0) {
          targetBearing = heading;
        } else {
          targetBearing = motionBearing;
        }
      } else {
        targetBearing = routeBearing;
      }
    } else if (speed > 2.0) {
      // If we have a snapped segment direction, always trust the route.
      // This keeps the marker exactly aligned to the active polyline.
      if (_lastLookAheadPoint != null) {
        // Fallback: look-ahead bearing (still route-based).
        final lookAheadBearing =
            BearingUtils.bearingBetween(targetPos, _lastLookAheadPoint!);
        if (motionBearing != null &&
            BearingUtils.angleDeltaDeg(lookAheadBearing, motionBearing) > 120.0) {
          // Same anti-flip guard for look-ahead bearing.
          if (heading != null &&
              BearingUtils.angleDeltaDeg(heading, motionBearing) <= 70.0) {
            targetBearing = heading;
          } else {
            targetBearing = motionBearing;
          }
        } else {
          targetBearing = lookAheadBearing;
        }
      } else {
        // No route: movement-based, then GPS heading.
        if (motionBearing != null) {
          targetBearing = motionBearing;
        } else if (heading != null) {
          targetBearing = heading;
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
    if (isRealSource) {
      // Store final route-aligned bearing for dead-reckoning.
      _lastLiveBearing = smoothed;
    }

    // Critical safety: never place vehicle marker at pickup/drop due to fallbacks.
    // Allow it only if the real driver is actually there (source gps/socket),
    // or if this is a short dead-reckoning extrapolation from a recent live fix.
    final deadReckonAllowed =
        source == 'dead_reckon' &&
        _lastLiveUpdateAt != null &&
        deviceNow.difference(_lastLiveUpdateAt!) <= MapUiConfig.deadReckonMaxAge;

    if (!isRealSource && !deadReckonAllowed) {
      final p = _pickup;
      final d = _drop;
      if (p != null && _distanceMeters(targetPos, p) <= 2.5) {
        _dbg('[BUG_BLOCKED] attempted to set vehicle marker to pickup location');
        return;
      }
      if (d != null && _distanceMeters(targetPos, d) <= 2.5) {
        _dbg('[BUG_BLOCKED] attempted to set vehicle marker to drop location');
        return;
      }
    }

    // Cache the last real driver position only from real sources (socket/gps).
    // Never cache fallback/pickup/drop-derived points.
    if (isRealSource) {
      _lastAcceptedGps = raw;
      _lastAcceptedAt = pointTime;
    }

    // Large GPS jump handling: if it jumps too far, snap without long animation.
    if (currentPos != null) {
      final jump = _distanceMeters(currentPos, targetPos);
      if (jump > MapUiConfig.gpsJumpResyncMeters) {
        _vehicleAnim.setImmediate(targetPos, smoothed);
        return;
      }
    }

    // First fix: set immediately so map init/camera/route can run right away.
    if (currentPos == null) {
      _vehicleAnim.setImmediate(targetPos, smoothed);
    } else {
      _vehicleAnim.animateTo(
        to: targetPos,
        bearingTo: smoothed,
        speedMetersPerSecond: speedMetersPerSecond,
      );
    }

    // Map should never wait for a "current location" button click to become usable.
    // Kick init when we get the first valid pose.
    unawaited(initializeRideMapIfReady(source: 'driver_location_update'));
  }

  void _armDeadReckoning() {
    if (!MapUiConfig.deadReckonEnabled) return;
    if (_disposed) return;
    _deadReckonTimer?.cancel();
    _deadReckonTimer = Timer.periodic(
      Duration(milliseconds: MapUiConfig.deadReckonTickMs),
      (_) => _deadReckonTick(),
    );
  }

  void _deadReckonTick() {
    if (_disposed) return;
    final lastAt = _lastLiveUpdateAt;
    final lastPos = _lastLivePosition;
    if (lastAt == null || lastPos == null) {
      _deadReckonTimer?.cancel();
      return;
    }

    final age = DateTime.now().difference(lastAt);
    if (age <= const Duration(milliseconds: 400)) return;
    if (age > MapUiConfig.deadReckonMaxAge) {
      _deadReckonTimer?.cancel();
      return;
    }

    final speed = _lastLiveSpeedMs.clamp(0.0, 25.0);
    if (speed < 0.5) return;

    final seconds = MapUiConfig.deadReckonTickMs / 1000.0;
    final meters = speed * seconds;
    final next = _moveMeters(lastPos, _lastLiveBearing, meters);

    // Visual-only update. This will still snap to polyline and smooth bearing.
    updateVehicleLocation(
      next,
      source: 'dead_reckon',
      speedMetersPerSecond: speed,
      headingDeg: _lastLiveBearing,
      accuracyMeters: MapUiConfig.gpsAccuracyRejectMeters,
      timestamp: DateTime.now(),
    );
  }

  LatLng _moveMeters(LatLng from, double bearingDeg, double meters) {
    final rad = bearingDeg * math.pi / 180.0;
    final dLat = (meters * math.cos(rad)) / 111320.0;
    final safeCos = math.cos(from.latitude * math.pi / 180.0).abs().clamp(0.2, 1.0);
    final dLng = (meters * math.sin(rad)) / (111320.0 * safeCos);
    return LatLng(from.latitude + dLat, from.longitude + dLng);
  }

  void _scheduleRouteRetryIfNeeded({required LatLng origin, required LatLng dest}) {
    if (_disposed) return;
    final now = DateTime.now();
    if (now.difference(_lastRouteRetryAt).inSeconds < 8) return;
    _lastRouteRetryAt = now;

    _routeRetryTimer?.cancel();
    _routeRetryTimer = Timer(const Duration(seconds: 2), () async {
      if (_disposed) return;
      try {
        _dbg(
          '[ROUTE_RETRY] origin=${origin.latitude},${origin.longitude} dest=${dest.latitude},${dest.longitude}',
        );
        final res = await _routeService.fetchRoadRoute(
          origin: origin,
          destination: dest,
          driverFriendlyStop: _navDriverFriendlyStop,
          mode: TravelModeResolver.getTravelMode(_vehicleType),
        );
        if (_disposed) return;
        if (res.points.length >= 2 && !res.isFallbackStraightLine) {
          _routeIsFallbackStraight = false;
          setRoutePoints(res.points);
          _dbg('[ROUTE_RETRY] success points=${res.points.length}');
        }
      } catch (e) {
        _dbg('[ROUTE_RETRY] failed err=$e');
      }
    });
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

    // If both driver + destination available, fetch route and do one-time initial
    // "full trip" fit (driver + destination + polyline).
    final driverPos = pose?.position ?? _lastLivePosition ?? _lastAcceptedGps;
    if (driverPos == null) {
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
          'initializeRideMapIfReady($source): fetching route origin=$driverPos dest=$dest',
        );
        final res = await _routeService.fetchRoadRoute(
          origin: driverPos,
          destination: dest,
          driverFriendlyStop: _navDriverFriendlyStop,
          mode: TravelModeResolver.getTravelMode(_vehicleType),
        );
        if (_disposed) return;
        if (res.points.length >= 2) {
          if (res.isFallbackStraightLine) {
            // Keep any existing non-fallback route to avoid "route becomes straight".
            final hasGoodExistingRoute =
                _routeFull.length >= 2 && _routeIsFallbackStraight == false;
            if (hasGoodExistingRoute) {
              _dbg(
                'initializeRideMapIfReady($source): route fallback straight ignored (keeping existing)',
              );
            } else {
              _routeIsFallbackStraight = true;
              setRoutePoints(res.points, isFallbackStraightLine: true);
              _dbg(
                'initializeRideMapIfReady($source): route fallback straight set points=${res.points.length}',
              );
              _scheduleRouteRetryIfNeeded(origin: driverPos, dest: dest);
            }
          } else {
            _routeIsFallbackStraight = false;
            setRoutePoints(res.points);
            _dbg(
              'initializeRideMapIfReady($source): route set points=${res.points.length}',
            );
          }
        } else {
          _dbg(
            'initializeRideMapIfReady($source): route fetch returned <2 points',
          );
          _scheduleRouteRetryIfNeeded(origin: driverPos, dest: dest);
        }
      }

      // One-time initial camera: show full trip (driver + destination + polyline).
      if (!_initialFullTripFitDone) {
        _dbg(
          'initializeRideMapIfReady($source): initial fitFullTrip routePoints=${_routeFull.length}',
        );
        // Delay slightly to avoid "map size is zero" on some devices.
        await Future<void>.delayed(const Duration(milliseconds: 300));
        await fitFullTrip(padding: _fullTripPaddingPx(), clampMinZoom: true);
        _initialFullTripFitDone = true;
        focusMode.value = MapFocusMode.fullTrip;
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

  double _fullTripPaddingPx() {
    // Uniform padding (google_maps_flutter newLatLngBounds only supports one value).
    // Bias upwards when bottom sheet is tall so route isn't hidden.
    final extra = (bottomSheetHeight * 0.25).clamp(0.0, 85.0);
    final raw = 95.0 + extra;
    // Cap padding so short pickup legs don't zoom out too far.
    return raw.clamp(70.0, MapUiConfig.maxPickupFitPadding);
  }

  /// Called by the existing "location/focus" button.
  ///
  /// Toggles indefinitely:
  /// - fullTrip -> driver focus
  /// - driver -> fullTrip fit
  Future<void> toggleFocusMode() async {
    final old = focusMode.value;
    final next = (old == MapFocusMode.driver) ? MapFocusMode.fullTrip : MapFocusMode.driver;
    _dbg('[FOCUS_BUTTON] tapped oldMode=${old.name} newMode=${next.name}');
    await applyFocusMode(next, userInitiated: true);
  }

  Future<void> applyFocusMode(MapFocusMode mode, {required bool userInitiated}) async {
    focusMode.value = mode;
    if (mode == MapFocusMode.driver) {
      // Button tap should override manual camera pause: enable follow again.
      setAutoFollowEnabled(true);
      final pose = _vehicleAnim.pose.value;
      _dbg('[FOCUS_DRIVER] target=${pose?.position}');
      await focusVehicle(
        zoom: 17.4,
        tilt: MapUiConfig.cameraTilt,
        bearingEnabled: cameraBearingEnabledNow,
      );
      return;
    }

    setAutoFollowEnabled(false);
    final pts = _fitPointsForMode(includeAllStops: true);
    _dbg('[FOCUS_FULL_TRIP] points=${pts.length}');
    // Ensure route init is kicked before fitting (safe no-op if already initialized).
    unawaited(initializeRideMapIfReady(source: 'focus_button/full_trip'));
    // If we are still in pickup leg, load a preview pickup->drop polyline so
    // the full ride polygon can be shown on a single view.
    if (_mode == RideMapMode.pickupNavigation) {
      unawaited(_ensurePreviewPickupToDropRoute());
    }
    await fitFullTrip(
      padding: _fullTripPaddingPx(),
      clampMinZoom: false,
      includeAllStops: true,
    );
  }

  List<LatLng> _fitPointsForMode({required bool includeAllStops}) {
    final pts = <LatLng>[];
    final pose = _vehicleAnim.pose.value;
    if (pose != null) pts.add(pose.position);

    // For user-initiated full-fit, always include pickup + drop so the full trip
    // is visible even during pickup leg.
    if (includeAllStops) {
      if (_pickup != null) pts.add(_pickup!);
      if (_drop != null) pts.add(_drop!);
    } else {
      // Smart fit: only include the active leg for the current screen mode.
      if (_mode == RideMapMode.pickupNavigation) {
        if (_pickup != null) pts.add(_pickup!);
      } else if (_mode == RideMapMode.dropNavigation) {
        if (_drop != null) pts.add(_drop!);
      } else {
        if (_pickup != null) pts.add(_pickup!);
        if (_drop != null) pts.add(_drop!);
      }
    }
    // Include active route points (already the current leg).
    pts.addAll(_routeFull);
    // Include preview pickup->drop route if available (pickup leg full-trip view).
    pts.addAll(_previewPickupToDrop);

    // Remove duplicates (very close points).
    final unique = <LatLng>[];
    for (final p in pts) {
      final exists = unique.any((u) => _distanceMeters(u, p) <= 1.0);
      if (!exists) unique.add(p);
    }
    return unique;
  }

  String _previewSigFor(LatLng pickup, LatLng drop) {
    return 'p:${pickup.latitude.toStringAsFixed(5)},${pickup.longitude.toStringAsFixed(5)}|'
        'd:${drop.latitude.toStringAsFixed(5)},${drop.longitude.toStringAsFixed(5)}|'
        'v:${_vehicleType.name}';
  }

  Future<void> _ensurePreviewPickupToDropRoute() async {
    if (_disposed) return;
    if (_previewRouteLoading) return;
    final pickup = _pickup;
    final drop = _drop;
    if (pickup == null || drop == null) return;

    // Only show preview during pickup leg.
    if (_mode != RideMapMode.pickupNavigation) return;

    final sig = _previewSigFor(pickup, drop);
    if (_previewPickupToDropSig == sig && _previewPickupToDrop.length >= 2) {
      _rebuildPreviewOverlayPolyline();
      return;
    }

    _previewRouteLoading = true;
    try {
      final res = await _routeService.fetchRoadRoute(
        origin: pickup,
        destination: drop,
        driverFriendlyStop: _navDriverFriendlyStop,
        mode: TravelModeResolver.getTravelMode(_vehicleType),
      );
      if (_disposed) return;
      if (res.points.length >= 2) {
        _previewPickupToDrop = List<LatLng>.from(res.points);
        _previewPickupToDropSig = sig;
        _rebuildPreviewOverlayPolyline();
      }
    } catch (_) {
      // Preview route is best-effort; bounds fit will still include pickup+drop points.
    } finally {
      _previewRouteLoading = false;
    }
  }

  void _rebuildPreviewOverlayPolyline() {
    // Only show preview overlay in pickupNavigation mode. Clear otherwise.
    final existing = overlayPolylines.value;
    final next = <Polyline>{};
    for (final p in existing) {
      if (p.polylineId.value != 'preview_pickup_to_drop') next.add(p);
    }

    if (_mode == RideMapMode.pickupNavigation && _previewPickupToDrop.length >= 2) {
      next.add(
        Polyline(
          polylineId: const PolylineId('preview_pickup_to_drop'),
          points: _previewPickupToDrop,
          color: MapUiConfig.completedPolylineColor.withOpacity(0.85),
          width: (MapUiConfig.polylineWidth - 1).clamp(3, 7),
          zIndex: -1,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
          jointType: JointType.round,
        ),
      );
    }

    overlayPolylines.value = next;
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
                bearing: cameraBearingEnabledNow ? bearing : 0.0,
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
    // Hard validation: no NaN/Infinity coordinates.
    if (!pose.position.latitude.isFinite || !pose.position.longitude.isFinite) {
      _dbg(
        '[BUG_BLOCKED] invalid vehicle marker lat/lng=${pose.position.latitude},${pose.position.longitude}',
      );
      return;
    }
    // Defensive: a NaN/Infinity rotation can cause the marker to not render on
    // some platforms.
    final safeBearing = pose.bearing.isFinite ? pose.bearing : 0.0;
    final icon = _vehicleIcon ?? BitmapDescriptor.defaultMarker;

    final set = markers.value;
    const vehicleMarkerId = 'vehicle_marker';
    final next = <Marker>{...set.where((m) => m.markerId.value != vehicleMarkerId)};
    next.add(
      Marker(
        markerId: const MarkerId(vehicleMarkerId),
        position: pose.position,
        icon: icon,
        anchor: const Offset(0.5, 0.5),
        flat: true,
        rotation: _bearingWithIconOffset(safeBearing),
        zIndexInt: 50,
      ),
    );
    final iconType = _vehicleIcon == null ? 'defaultIcon' : 'customIcon';
    _dbg(
      '[VEHICLE_MARKER] created/updated lat=${pose.position.latitude} lng=${pose.position.longitude} icon=$iconType id=$vehicleMarkerId',
    );
    _dbg(
      '[VEHICLE_VISIBLE_CHECK] hasDriver=true iconReady=${_vehicleIcon != null} '
      'markerCount=${next.length} vehicleMarkerExists=${next.any((m) => m.markerId.value == vehicleMarkerId)}',
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
    final keepDriver =
        set.where((m) => m.markerId.value == 'vehicle_marker').toList();
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
          patterns: <PatternItem>[PatternItem.dash(14), PatternItem.gap(10)],
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

  static double _snapToleranceMeters({
    required double? accuracyMeters,
    required double? speedMetersPerSecond,
  }) {
    double base = MapUiConfig.snapToRouteToleranceMeters;

    final speed = (speedMetersPerSecond != null &&
            speedMetersPerSecond.isFinite &&
            speedMetersPerSecond >= 0)
        ? speedMetersPerSecond
        : 0.0;

    // When crawling/turning in dense areas, be stricter to avoid parallel-road snaps.
    if (speed <= 2.0) {
      base = math.min(base, 18.0);
    } else if (speed <= 6.0) {
      base = math.min(base, 24.0);
    }

    if (accuracyMeters == null || !accuracyMeters.isFinite || accuracyMeters <= 0.0) {
      return base;
    }

    // If accuracy is good, keep tolerance tight (prevents snapping to the wrong
    // nearby road). If accuracy is noisy (still within our reject cap), allow more.
    // IMPORTANT: do NOT loosen tolerance too much based only on accuracy.
    // Large tolerances are the main reason for "parallel road lock" where the
    // marker keeps snapping to the route even after the driver moved to the
    // next street.
    final accBased = math.max(12.0, accuracyMeters * 0.9);
    return math.min(base, accBased);
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
    _deadReckonTimer?.cancel();
    _polylineDebounce?.cancel();
    _vehicleAnim.pose.removeListener(_poseListener);
    _vehicleAnim.dispose();
    markers.dispose();
    polylines.dispose();
    overlayMarkers.dispose();
    overlayPolylines.dispose();
    overlayCircles.dispose();
    focusMode.dispose();
  }
}
