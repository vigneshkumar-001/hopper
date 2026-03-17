// lib/Presentation/DriverScreen/controller/pickup_customer_controller.dart

import 'dart:async';
import 'dart:math' as math;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:hopper/Core/Constants/log.dart';
import 'package:hopper/Core/Utility/images.dart';
import 'package:hopper/Presentation/DriverScreen/controller/driver_status_controller.dart';
import 'package:hopper/Presentation/DriverScreen/screens/verify_rider_screen.dart';
import 'package:hopper/api/repository/api_config_controller.dart';
import 'package:hopper/api/repository/api_constents.dart';
import 'package:hopper/utils/map/route_info.dart';
import 'package:hopper/utils/sharedprefsHelper/local_data_store.dart';
import 'package:hopper/utils/sharedprefsHelper/sharedprefs_handler.dart';
import 'package:hopper/utils/websocket/socket_io_client.dart';
import 'package:hopper/utils/map/navigation_assist.dart';
import 'package:hopper/utils/map/navigation_voice_service.dart';
import 'package:hopper/utils/map/map_motion_profile.dart';
import 'package:hopper/utils/map/app_map_style.dart';

/// UI snapshot (keeps widget build super clean)
class PickingUiState {
  final LatLng driverLocation;
  final double bearing;
  final List<LatLng> polyline;
  final String directionText;
  final String distanceText;
  final String maneuver;

  const PickingUiState({
    required this.driverLocation,
    required this.bearing,
    required this.polyline,
    required this.directionText,
    required this.distanceText,
    required this.maneuver,
  });

  PickingUiState copyWith({
    LatLng? driverLocation,
    double? bearing,
    List<LatLng>? polyline,
    String? directionText,
    String? distanceText,
    String? maneuver,
  }) {
    return PickingUiState(
      driverLocation: driverLocation ?? this.driverLocation,
      bearing: bearing ?? this.bearing,
      polyline: polyline ?? this.polyline,
      directionText: directionText ?? this.directionText,
      distanceText: distanceText ?? this.distanceText,
      maneuver: maneuver ?? this.maneuver,
    );
  }
}

class _QueuedSocketEmit {
  final String event;
  final Map<String, dynamic> payload;
  const _QueuedSocketEmit({required this.event, required this.payload});
}

class PickingCustomerController extends GetxController {
  // Toggle for local testing:
  // true  -> show Arrived controls immediately.
  // false -> normal behavior (auto-show when within 500m of pickup).
  static const bool enableArrivedTesting = true;

  // ----- inputs -----
  final LatLng pickupLocation;
  final LatLng driverLocation;
  final String bookingId;
  final String? pickupLocationAddress;
  final String? dropLocationAddress;

  PickingCustomerController({
    required this.pickupLocation,
    required this.driverLocation,
    required this.bookingId,
    this.pickupLocationAddress,
    this.dropLocationAddress,
  });

  // ----- deps -----
  final DriverStatusController driverStatusController =
      Get.find<DriverStatusController>();

  // ----- map -----
  GoogleMapController? mapController;
  final Rxn<BitmapDescriptor> carIcon = Rxn<BitmapDescriptor>();

  // ----- socket -----
  late final SocketService socketService;

  // ----- rider meta -----
  final customerName = ''.obs;
  final customerPhone = ''.obs;
  final customerProfilePic = ''.obs;
  final pickupAddressText = ''.obs;
  final dropAddressText = ''.obs;

  // ----- flow flags -----
  final arrivedAtPickup = true.obs; // before pressing "Arrived at Pickup Point"
  final driverReached = false.obs; // driver near pickup (from socket event)
  final showRedTimer = false.obs;
  final isArrivedSubmitting = false.obs;
  final isOffRouteAlert = false.obs;
  final isNetworkOffline = false.obs;
  final pendingQueueCount = 0.obs;
  final followZoom = 15.0.obs;
  final isDriverFocused = false.obs;

  // ----- timer -----
  final secondsLeft = 0.obs;
  Timer? _timer;

  // ----- UI state -----
  late final Rx<PickingUiState> ui;

  // ----- tracking -----
  StreamSubscription<Position>? _posSub;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  LatLng? _lastPos;
  bool _animating = false;
  LatLng? _queuedTarget;
  double? _queuedBearing;
  DateTime _lastCameraMoveAt = DateTime.fromMillisecondsSinceEpoch(0);

  // ----- routing/polylines -----
  List<LatLng> _poly = [];
  DateTime _lastRouteFetch = DateTime.fromMillisecondsSinceEpoch(0);
  PickingUiState? _cachedUiState;
  bool _pendingRouteRetry = false;
  Timer? _routeRetryTimer;
  final List<_QueuedSocketEmit> _socketRetryQueue = <_QueuedSocketEmit>[];
  String? _driverId;
  bool _routeRefreshQueued = false;

  // ----- thresholds (jitter control) -----
  static const double _MAX_ACCURACY_M = 25.0;
  static const double _MIN_MOVE_METERS = 3.0;
  static const double _MIN_SPEED_MS = 1.0;
  static const double _STATIONARY_DRIFT_M = 8.0;
  static const double _HEADING_TRUST_MS = 2.0;
  static const double _MIN_TURN_DEG = 10.0;
  static const double _OFF_ROUTE_TOLERANCE_M = 25.0;
  static const double _ARRIVED_PICKUP_RADIUS_M = 500.0;
  static const double _POLYLINE_TRIM_TOLERANCE_M = 30.0;
  static const int _POLYLINE_TRIM_LOOKAHEAD_POINTS = 40;
  static const int _OFF_ROUTE_LOOKAHEAD_POINTS = 80;

  @override
  void onInit() {
    super.onInit();

    // Ã¢Å“â€¦ MUST SET BEFORE _fetchRoute()
    DirectionsConfig.apiKey = ApiConstents.googleMapApiKey;

    ui =
        PickingUiState(
          driverLocation: driverLocation,
          bearing: 0,
          polyline: <LatLng>[driverLocation, pickupLocation],
          directionText: '',
          distanceText: '',
          maneuver: '',
        ).obs;

    _applySystemUi();
    _initConnectivityWatchdog();
    _loadDriverId();
    _loadCarIcon();
    _initSocket();
    _bootFromJoinedOrReverseGeocode();
    _startTracking();
    _fetchRoute(force: true);

    if (enableArrivedTesting) {
      driverReached.value = true;
      CommonLogger.log.i("Test mode enabled: driverReached forced to true");
    }
  }

  @override
  void onClose() {
    _posSub?.cancel();
    _connectivitySub?.cancel();
    _stopNoShowTimer();
    _routeRetryTimer?.cancel();
    try {
      socketService.socket.off('joined-booking');
      socketService.socket.off('driver-location');
      socketService.socket.off('driver-arrived');
      socketService.socket.off('driver-cancelled');
      socketService.socket.off('customer-cancelled');
    } catch (_) {}
    _queuedTarget = null;
    _queuedBearing = null;
    mapController = null;
    super.onClose();
  }

  Future<void> _loadDriverId() async {
    _driverId = await SharedPrefHelper.getDriverId();
  }

  void _initConnectivityWatchdog() {
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      final offline = results.every((r) => r == ConnectivityResult.none);
      isNetworkOffline.value = offline;
      if (offline) return;

      if (!socketService.connected) {
        socketService.connect();
      }
      _flushSocketRetryQueue();
      if (_pendingRouteRetry) {
        _fetchRoute(force: true);
      }
    });
  }

  // ===================== UI / SYSTEM =====================

  void _applySystemUi() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );
  }

  Future<void> _loadCarIcon() async {
    try {
      final cfg = const ImageConfiguration(size: Size(42, 42));
      final asset =
          driverStatusController.serviceType.value == "Bike"
              ? AppImages.parcelBike
              : AppImages.movingCar;

      // safest API:
      final icon = await BitmapDescriptor.fromAssetImage(cfg, asset);
      carIcon.value = icon;
    } catch (_) {
      carIcon.value = BitmapDescriptor.defaultMarker;
    }
  }

  // ===================== SOCKET =====================

  void _initSocket() {
    socketService = SocketService();
    final cfg = Get.find<ApiConfigController>();
    socketService.initSocket(cfg.socketUrl);

    socketService.on('joined-booking', (data) async {
      if (data == null) return;
      JoinedBookingData().setData(data);

      // Ã¢Å“â€¦ IMPORTANT: fill these so UI shows customer name
      customerName.value = (data['customerName'] ?? '').toString();
      customerPhone.value = (data['customerPhone'] ?? '').toString();
      customerProfilePic.value = (data['customerProfilePic'] ?? '').toString();

      final loc = data['customerLocation'];
      if (loc != null) {
        final fromLat = (loc['fromLatitude'] as num?)?.toDouble();
        final fromLng = (loc['fromLongitude'] as num?)?.toDouble();
        final toLat = (loc['toLatitude'] as num?)?.toDouble();
        final toLng = (loc['toLongitude'] as num?)?.toDouble();

        if (fromLat != null && fromLng != null) {
          pickupAddressText.value = await getAddressFromLatLng(
            fromLat,
            fromLng,
          );
        }
        if (toLat != null && toLng != null) {
          dropAddressText.value = await getAddressFromLatLng(toLat, toLng);
        }
      }

      CommonLogger.log.i(
        "Joined booking loaded for customer: ${customerName.value}",
      );
    });

    socketService.on('driver-location', (data) {
      if (data == null) return;

      if (data['pickupDistanceInMeters'] != null) {
        driverStatusController.pickupDistanceInMeters.value =
            (data['pickupDistanceInMeters'] as num).toDouble();
      }
      if (data['pickupDurationInMin'] != null) {
        driverStatusController.pickupDurationInMin.value =
            (data['pickupDurationInMin'] as num).toDouble();
      }
    });

    socketService.on('driver-arrived', (data) {
      final status = data?['status'];
      if (status == true || status?.toString() == 'true') {
        driverReached.value = true;
      }
    });

    socketService.on('driver-cancelled', (data) {
      if (data?['status'] == true) {
        // handled in UI navigation (you already do)
      }
    });

    socketService.on('customer-cancelled', (data) {
      if (data?['status'] == true) {
        Get.find<DriverAnalyticsController>().trackCancel(
          bookingId: data?['bookingId']?.toString() ?? bookingId,
        );
        // handled in UI navigation (you already do)
      }
    });

    socketService.socket.onAny((event, data) {
      CommonLogger.log.i('Pickup socket event: $event | data: $data');
    });

    if (!socketService.connected) {
      socketService.connect();
      socketService.onConnect(() {
        CommonLogger.log.i("Socket connected");
        _flushSocketRetryQueue();
      });
    }
  }

  // ===================== BOOT DATA =====================

  Future<void> _bootFromJoinedOrReverseGeocode() async {
    // if joined-booking already saved, hydrate now
    final joined = JoinedBookingData().getData();
    if (joined != null) {
      customerName.value = (joined['customerName'] ?? '').toString();
      customerPhone.value = (joined['customerPhone'] ?? '').toString();
      customerProfilePic.value =
          (joined['customerProfilePic'] ?? '').toString();

      final loc = joined['customerLocation'];
      if (loc != null) {
        final fromLat = (loc['fromLatitude'] as num?)?.toDouble();
        final fromLng = (loc['fromLongitude'] as num?)?.toDouble();
        final toLat = (loc['toLatitude'] as num?)?.toDouble();
        final toLng = (loc['toLongitude'] as num?)?.toDouble();

        if (fromLat != null && fromLng != null) {
          pickupAddressText.value = await getAddressFromLatLng(
            fromLat,
            fromLng,
          );
        }
        if (toLat != null && toLng != null) {
          dropAddressText.value = await getAddressFromLatLng(toLat, toLng);
        }
      }
      return;
    }

    // fallback: use passed addresses OR reverse geocode pickup
    if ((pickupLocationAddress ?? '').isNotEmpty) {
      pickupAddressText.value = pickupLocationAddress!;
    } else {
      pickupAddressText.value = await getAddressFromLatLng(
        pickupLocation.latitude,
        pickupLocation.longitude,
      );
    }
    if ((dropLocationAddress ?? '').isNotEmpty) {
      dropAddressText.value = dropLocationAddress!;
    }
  }

  Future<String> getAddressFromLatLng(double lat, double lng) async {
    try {
      final placemarks = await placemarkFromCoordinates(lat, lng);
      final p = placemarks.first;
      return "${p.name}, ${p.locality}, ${p.administrativeArea}";
    } catch (_) {
      return "Location not available";
    }
  }

  // ===================== MAP EVENTS =====================

  Future<void> onMapCreated(
    GoogleMapController gm,
    BuildContext context,
  ) async {
    mapController = gm;

    try {
      final style = await AppMapStyle.loadUberLight();
      await mapController?.setMapStyle(style);
    } catch (_) {}

    // Fit driver + pickup
    await Future.delayed(const Duration(milliseconds: 250));
    fitBoundsToDriverAndPickup();
  }

  Future<void> goToCurrentLocation() async {
    final ok = await _ensureLocationPermission();
    if (!ok) return;
    final pos = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    final latLng = LatLng(pos.latitude, pos.longitude);
    mapController?.animateCamera(CameraUpdate.newLatLngZoom(latLng, 17));
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

  Future<void> fitBoundsToDriverAndPickup() async {
    if (mapController == null) return;

    final d = ui.value.driverLocation;
    final p = pickupLocation;

    final bounds = _safeBounds(
      math.min(d.latitude, p.latitude),
      math.min(d.longitude, p.longitude),
      math.max(d.latitude, p.latitude),
      math.max(d.longitude, p.longitude),
    );

    try {
      await mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 90),
      );
      final z = await mapController!.getZoomLevel();
      if (z > 14.9) {
        mapController!.animateCamera(CameraUpdate.zoomTo(14.9));
      }
    } catch (_) {}
  }

  // ===================== ROUTE =====================

  String _stripHtml(String s) {
    return s
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&');
  }

  Future<void> _fetchRoute({bool force = false}) async {
    try {
      if (isNetworkOffline.value) {
        _pendingRouteRetry = true;
        _scheduleRouteRetry();
        return;
      }

      final now = DateTime.now();
      if (!force) {
        if (now.difference(_lastRouteFetch).inSeconds < 8) return;
      }
      _lastRouteFetch = now;

      final origin = ui.value.driverLocation;

      final result = await getRouteInfo(
        origin: origin,
        destination: pickupLocation,
        // Ã¢Å“â€¦ keep consistent
        alternatives: false,
        traffic: true,
        mode: "driving",
        routeIndex: 0,
      );

      final poly = (result['polyline'] ?? '').toString();
      final pts = _simplifyPolyline(
        decodePolyline(poly),
        minStepMeters: 6,
        maxPoints: 220,
      );

      if (pts.length < 2) {
        _setDirectPolyline(ui.value.driverLocation);
        if ((_cachedUiState?.polyline.length ?? 0) >= 2) {
          ui.value = _cachedUiState!;
        }
        _scheduleRouteRetry();
        return;
      }

      CommonLogger.log.i("route pts=${pts.length}");

      _poly = pts;

      ui.value = ui.value.copyWith(
        polyline: pts,
        directionText: _stripHtml((result['direction'] ?? '').toString()),
        distanceText: (result['distance'] ?? '').toString(),
        maneuver: (result['maneuver'] ?? '').toString(),
      );
      final analytics = Get.find<DriverAnalyticsController>();
      analytics.setSlaFromEtaMinutes(
        driverStatusController.pickupDurationInMin.value,
      );
      final voiceLine = NavigationAssist.buildVoiceLine(
        maneuver: ui.value.maneuver,
        distanceText: ui.value.distanceText,
        directionText: ui.value.directionText,
      );
      NavigationVoiceService.instance.speakTurn(voiceLine);
      _cachedUiState = ui.value;
      _pendingRouteRetry = false;
    } catch (e) {
      CommonLogger.log.e("Route fetch failed: $e");
      _pendingRouteRetry = true;
      if (_cachedUiState != null) {
        ui.value = _cachedUiState!;
      }
      _setDirectPolyline(ui.value.driverLocation);
      _scheduleRouteRetry();
    }
  }

  void _setDirectPolyline(LatLng origin) {
    final direct = <LatLng>[origin, pickupLocation];
    _poly = direct;
    ui.value = ui.value.copyWith(polyline: direct);
  }

  void _scheduleRouteRetry() {
    _routeRetryTimer?.cancel();
    _routeRetryTimer = Timer(const Duration(seconds: 3), () {
      if (isNetworkOffline.value) return;
      _fetchRoute(force: true);
    });
  }

  void _trimPolyline(LatLng current) {
    if (_poly.length < 2) return;

    final closest = _closestPoint(
      current,
      _poly,
      limit: _POLYLINE_TRIM_LOOKAHEAD_POINTS,
    );
    final idx = closest.$1;
    final bestDistance = closest.$2;
    if (idx <= 0) return;
    if (bestDistance > _POLYLINE_TRIM_TOLERANCE_M) return;

    final keepFrom = (idx - 1).clamp(0, _poly.length - 2);
    final trimmed = _poly.sublist(keepFrom);
    if (trimmed.length < 2) return;

    _poly = trimmed;
    ui.value = ui.value.copyWith(polyline: _poly);
  }

  (int, double) _closestPoint(LatLng pos, List<LatLng> pts, {int? limit}) {
    double best = double.infinity;
    int idx = 0;
    final searchLimit =
        limit == null ? pts.length : math.min(pts.length, limit);
    for (int i = 0; i < searchLimit; i++) {
      final d = Geolocator.distanceBetween(
        pos.latitude,
        pos.longitude,
        pts[i].latitude,
        pts[i].longitude,
      );
      if (d < best) {
        best = d;
        idx = i;
      }
    }
    return (idx, best);
  }

  bool _isOffRoute(LatLng current) {
    if (_poly.isEmpty) return true;

    final searchLimit = math.min(_poly.length, _OFF_ROUTE_LOOKAHEAD_POINTS);
    for (int i = 0; i < searchLimit; i++) {
      final p = _poly[i];
      final d = Geolocator.distanceBetween(
        current.latitude,
        current.longitude,
        p.latitude,
        p.longitude,
      );
      if (d < _OFF_ROUTE_TOLERANCE_M) return false;
    }
    return true;
  }

  // ===================== TRACKING + ANIMATION =====================

  void _startTracking() async {
    final ok = await _ensureLocationPermission();
    if (!ok) return;

    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation,
      );
      final current = LatLng(pos.latitude, pos.longitude);
      _lastPos = current;
      _setDirectPolyline(current);
      ui.value = ui.value.copyWith(driverLocation: current);
      _updateDriverReachedByDistance(current);
      await _fetchRoute(force: true);
    } catch (_) {}

    _posSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 3,
      ),
    ).listen((pos) async {
      final acc = (pos.accuracy.isFinite) ? pos.accuracy : 9999.0;
      if (acc > _MAX_ACCURACY_M) return;

      final current = LatLng(pos.latitude, pos.longitude);
      final speed = (pos.speed.isFinite) ? pos.speed : 0.0;
      final heading = (pos.heading.isFinite) ? pos.heading : -1.0;
      _updateSmartAutoZoom(speed);

      if (_lastPos == null) {
        _lastPos = current;
        ui.value = ui.value.copyWith(driverLocation: current);
        _updateDriverReachedByDistance(current);
        await _fetchRoute(force: true);
        return;
      }

      final moved = Geolocator.distanceBetween(
        _lastPos!.latitude,
        _lastPos!.longitude,
        current.latitude,
        current.longitude,
      );

      if (moved < _MIN_MOVE_METERS) {
        // tiny drift -> update location silently without rotation
        ui.value = ui.value.copyWith(driverLocation: current);
        _lastPos = current;
        _updateDriverReachedByDistance(current);
        if (ui.value.polyline.length < 2) {
          await _fetchRoute(force: true);
        }
        return;
      }

      if (MapMotionProfile.shouldFreezeTurn(
        speedMs: speed,
        movedMeters: moved,
        accuracyM: acc,
      )) {
        ui.value = ui.value.copyWith(
          driverLocation: current,
          bearing: ui.value.bearing,
        );
        _lastPos = current;
        _updateDriverReachedByDistance(current);
        return;
      }

      double targetBearing = ui.value.bearing;

      final shouldHoldBearing =
          speed < _MIN_SPEED_MS || moved < _STATIONARY_DRIFT_M;

      if (shouldHoldBearing) {
        targetBearing = ui.value.bearing;
      } else if (speed >= _HEADING_TRUST_MS && heading >= 0) {
        targetBearing = heading;
      } else {
        targetBearing = _bearingBetween(ui.value.driverLocation, current);
      }

      final diff = MapMotionProfile.angleDelta(ui.value.bearing, targetBearing);
      if (speed < _MIN_SPEED_MS && diff < _MIN_TURN_DEG) {
        targetBearing = ui.value.bearing;
      }

      targetBearing = MapMotionProfile.smoothBearing(
        current: ui.value.bearing,
        target: targetBearing,
        speedMs: speed,
      );

      await _animateTo(current, targetBearing);

      _lastPos = current;
      _updateDriverReachedByDistance(current);

      // polyline maintenance
      _trimPolyline(current);

      final offRoute = _isOffRoute(current);
      isOffRouteAlert.value = offRoute;
      if (offRoute) {
        await _fetchRoute(force: true);
      } else {
        await _fetchRoute(force: false);
      }
    });
  }

  void _updateDriverReachedByDistance(LatLng current) {
    if (driverReached.value) return;
    if (enableArrivedTesting) {
      driverReached.value = true;
      return;
    }

    final distanceToPickup = Geolocator.distanceBetween(
      current.latitude,
      current.longitude,
      pickupLocation.latitude,
      pickupLocation.longitude,
    );

    if (distanceToPickup <= _ARRIVED_PICKUP_RADIUS_M) {
      driverReached.value = true;
      CommonLogger.log.i(
        "Auto driverReached TRUE at ${distanceToPickup.toStringAsFixed(1)}m from pickup",
      );
    }
  }

  void _updateSmartAutoZoom(double speedMs) {
    final kmh = speedMs * 3.6;
    double targetZoom;
    if (kmh >= 55) {
      targetZoom = 13.4;
    } else if (kmh >= 30) {
      targetZoom = 13.9;
    } else if (kmh >= 15) {
      targetZoom = 14.4;
    } else {
      targetZoom = 14.9;
    }
    followZoom.value = (followZoom.value * 0.75) + (targetZoom * 0.25);
  }

  Future<void> _animateTo(LatLng to, double bearing) async {
    if (_animating) {
      _queuedTarget = to;
      _queuedBearing = bearing;
      return;
    }
    _animating = true;

    final from = ui.value.driverLocation;
    final startBearing = ui.value.bearing;
    final endBearing = MapMotionProfile.shortestAngle(startBearing, bearing);

    const steps = 24;
    const total = Duration(milliseconds: 620);
    final stepMs = total.inMilliseconds ~/ steps;

    for (int i = 1; i <= steps; i++) {
      await Future.delayed(Duration(milliseconds: stepMs));
      final linearT = i / steps;
      final t = Curves.easeInOut.transform(linearT);

      final lat = _lerp(from.latitude, to.latitude, t);
      final lng = _lerp(from.longitude, to.longitude, t);
      final b = _lerpBearing(startBearing, endBearing, t);

      ui.value = ui.value.copyWith(
        driverLocation: LatLng(lat, lng),
        bearing: MapMotionProfile.normalizeAngle(b),
      );

      if (i == steps || i % 4 == 0) {
        _followCameraIfNeeded(ui.value.driverLocation, ui.value.bearing);
      }
    }

    _animating = false;
    if (_queuedTarget != null && _queuedBearing != null) {
      final nextTarget = _queuedTarget!;
      final nextBearing = _queuedBearing!;
      _queuedTarget = null;
      _queuedBearing = null;
      await _animateTo(nextTarget, nextBearing);
    }
  }

  void _followCameraIfNeeded(LatLng target, double bearing) {
    final map = mapController;
    if (map == null) return;

    final now = DateTime.now();
    if (now.difference(_lastCameraMoveAt).inMilliseconds < 140) return;
    _lastCameraMoveAt = now;

    try {
      map.moveCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: target,
            zoom: followZoom.value,
            bearing: bearing,
            tilt: 45,
          ),
        ),
      );
    } catch (_) {}
  }

  LatLngBounds _safeBounds(
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

  Future<void> refreshRouteNow() async {
    await _fetchRoute(force: true);
  }

  void ensureRouteReady() {
    if (ui.value.polyline.length >= 2 || isNetworkOffline.value) return;
    if (_routeRefreshQueued) return;
    _routeRefreshQueued = true;
    Future.microtask(() async {
      try {
        await refreshRouteNow();
      } finally {
        _routeRefreshQueued = false;
      }
    });
  }

  Future<void> focusRouteOverview() async {
    if (mapController == null) return;
    isDriverFocused.value = false;
    final pts = ui.value.polyline;
    if (pts.length < 2) {
      await fitBoundsToDriverAndPickup();
      return;
    }

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
      await mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 80),
      );
    } catch (_) {
      await fitBoundsToDriverAndPickup();
    }
  }

  Future<void> focusDriverNow() async {
    isDriverFocused.value = true;
    await goToCurrentLocation();
  }

  Future<void> sendQuickMessage(String text, {int? delayMinutes}) async {
    final driverId = _driverId ?? await SharedPrefHelper.getDriverId();
    final payload = <String, dynamic>{
      'bookingId': bookingId,
      'driverId': driverId,
      'delayMinutes': (delayMinutes ?? 0) < 0 ? 0 : (delayMinutes ?? 0),
      'message': text,
    };

    if (isNetworkOffline.value || !socketService.connected) {
      _enqueueSocketEmit('driver-message', payload);
      return;
    }

    socketService.emitWithAck('driver-message', payload, (ack) {
      final ok = (ack is Map && ack['success'] == true);
      if (!ok) {
        _enqueueSocketEmit('driver-message', payload);
      }
    });
  }

  void _enqueueSocketEmit(String event, Map<String, dynamic> payload) {
    _socketRetryQueue.add(_QueuedSocketEmit(event: event, payload: payload));
    pendingQueueCount.value = _socketRetryQueue.length;
  }

  void _flushSocketRetryQueue() {
    if (_socketRetryQueue.isEmpty || !socketService.connected) return;
    final queued = List<_QueuedSocketEmit>.from(_socketRetryQueue);
    _socketRetryQueue.clear();
    pendingQueueCount.value = 0;
    for (final q in queued) {
      socketService.emitWithAck(q.event, q.payload, (ack) {
        final ok = (ack is Map && ack['success'] == true);
        if (!ok) {
          _enqueueSocketEmit(q.event, q.payload);
        }
      });
    }
  }

  double _lerp(double a, double b, double t) => a + (b - a) * t;

  double _lerpBearing(double start, double end, double t) {
    double difference = ((end - start + 540) % 360) - 180;
    return (start + difference * t + 360) % 360;
  }

  double _bearingBetween(LatLng a, LatLng b) {
    final lat1 = a.latitude * math.pi / 180;
    final lon1 = a.longitude * math.pi / 180;
    final lat2 = b.latitude * math.pi / 180;
    final lon2 = b.longitude * math.pi / 180;

    final dLon = lon2 - lon1;
    final y = math.sin(dLon) * math.cos(lat2);
    final x =
        math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);

    final bearing = math.atan2(y, x) * 180 / math.pi;
    return _normalizeAngle(bearing);
  }

  double _angleDeltaDeg(double a, double b) {
    double d = (b - a) % 360;
    if (d > 180) d -= 360;
    if (d < -180) d += 360;
    return d.abs();
  }

  double _smoothBearing({
    required double current,
    required double target,
    required double speedMs,
  }) {
    final delta = ((target - current + 540) % 360) - 180;

    final gain =
        speedMs >= 8
            ? 0.65
            : speedMs >= 4
            ? 0.55
            : 0.42;

    return _normalizeAngle(current + (delta * gain));
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

  double _degToRad(double d) => d * (math.pi / 180.0);

  double _haversineMeters(LatLng a, LatLng b) {
    const r = 6371000.0;
    final dLat = _degToRad(b.latitude - a.latitude);
    final dLon = _degToRad(b.longitude - a.longitude);
    final lat1 = _degToRad(a.latitude);
    final lat2 = _degToRad(b.latitude);

    final h =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    return 2 * r * math.asin(math.sqrt(h));
  }

  List<LatLng> _simplifyPolyline(
    List<LatLng> points, {
    required double minStepMeters,
    required int maxPoints,
  }) {
    if (points.length <= 2) return points;
    final simplified = <LatLng>[points.first];

    LatLng last = points.first;
    for (int i = 1; i < points.length - 1; i++) {
      final p = points[i];
      if (_haversineMeters(last, p) >= minStepMeters) {
        simplified.add(p);
        last = p;
        if (simplified.length >= maxPoints) break;
      }
    }
    simplified.add(points.last);
    return simplified;
  }

  // ===================== TIMER =====================

  void startNoShowTimer() {
    _stopNoShowTimer();
    secondsLeft.value = 300;
    showRedTimer.value = false;

    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (secondsLeft.value <= 0) {
        t.cancel();
        Get.find<DriverAnalyticsController>().trackNoShow();
        return;
      }
      secondsLeft.value--;
      showRedTimer.value = secondsLeft.value <= 10;
    });
  }

  void _stopNoShowTimer() {
    _timer?.cancel();
    _timer = null;
    secondsLeft.value = 0;
    showRedTimer.value = false;
  }

  String formatTimer(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // ===================== ACTIONS =====================

  Future<void> onArrivedAtPickupPressed(BuildContext context) async {
    if (isArrivedSubmitting.value) return;
    isArrivedSubmitting.value = true;
    try {
      final res = await driverStatusController.driverArrived(
        context,
        bookingId: bookingId,
      );

      if (res != null && res.status == 200) {
        arrivedAtPickup.value = false;
        startNoShowTimer();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res?.message ?? "Something went wrong")),
        );
      }
    } finally {
      isArrivedSubmitting.value = false;
    }
  }

  Future<void> onSwipeStartRide(BuildContext context) async {
    // request OTP
    final msg = await driverStatusController.otpRequest(
      context,
      bookingId: bookingId,
      custName: customerName.value,
      pickupAddress: pickupLocationAddress ?? pickupAddressText.value,
      dropAddress: dropLocationAddress ?? dropAddressText.value,
    );

    if (msg == null) return;

    _stopNoShowTimer();

    // Ã¢Å“â€¦ navigate to Verify screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => VerifyRiderScreen(
              bookingId: bookingId,
              custName: customerName.value,
              pickupAddress: pickupLocationAddress ?? pickupAddressText.value,
              dropAddress: dropLocationAddress ?? dropAddressText.value,
              isSharedRide: false,
            ),
      ),
    );
  }

  void debugSetDriverReachedTrue() {
    driverReached.value = true;
    CommonLogger.log.i("Test action: driverReached set to true manually");
  }
  // ===================== ICON HELPERS =====================

  String getManeuverIcon(String maneuver) {
    switch (maneuver) {
      case "turn-right":
        return "assets/images/right-turn.png";
      case "turn-left":
        return "assets/images/left-turn.png";
      case "straight":
      case "merge":
        return 'assets/images/straight.png';
      case "roundabout-left":
        return 'assets/images/roundabout-left.png';
      case "roundabout-right":
        return 'assets/images/roundabout-right.png';
      default:
        return 'assets/images/straight.png';
    }
  }
}

// // lib/Presentation/DriverScreen/controller/picking_customer_controller.dart
//
// import 'dart:async';
// import 'dart:math' as math;
//
// import 'package:flutter/foundation.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:geocoding/geocoding.dart';
// import 'package:geolocator/geolocator.dart';
// import 'package:get/get.dart';
// import 'package:google_maps_flutter/google_maps_flutter.dart';
//
// import 'package:hopper/Core/Constants/log.dart';
// import 'package:hopper/Core/Utility/images.dart';
// import 'package:hopper/Presentation/DriverScreen/controller/driver_status_controller.dart';
// import 'package:hopper/utils/websocket/socket_io_client.dart';
//
// import '../../../utils/map/route_info.dart';
// import '../screens/verify_rider_screen.dart';
//
// // keep your existing map helpers
//
// class PickingCustomerUiState {
//   final LatLng driverLocation;
//   final double bearing;
//   final List<LatLng> polyline;
//   final String directionText;
//   final String distanceText;
//   final String maneuver;
//
//   const PickingCustomerUiState({
//     required this.driverLocation,
//     required this.bearing,
//     required this.polyline,
//     required this.directionText,
//     required this.distanceText,
//     required this.maneuver,
//   });
//
//   PickingCustomerUiState copyWith({
//     LatLng? driverLocation,
//     double? bearing,
//     List<LatLng>? polyline,
//     String? directionText,
//     String? distanceText,
//     String? maneuver,
//   }) {
//     return PickingCustomerUiState(
//       driverLocation: driverLocation ?? this.driverLocation,
//       bearing: bearing ?? this.bearing,
//       polyline: polyline ?? this.polyline,
//       directionText: directionText ?? this.directionText,
//       distanceText: distanceText ?? this.distanceText,
//       maneuver: maneuver ?? this.maneuver,
//     );
//   }
// }
//
// class PickingCustomerController extends GetxController
//     with GetSingleTickerProviderStateMixin {
//   PickingCustomerController({
//     required this.pickupLocation,
//     required this.bookingId,
//     required LatLng driverLocation, // Ã¢Å“â€¦ add this
//     this.pickupLocationAddress,
//     this.dropLocationAddress,
//   }) : _initialDriverLocation = driverLocation;
//
//   // Inputs
//   final LatLng pickupLocation;
//   final String bookingId;
//   final String? pickupLocationAddress;
//   final String? dropLocationAddress;
//
//   final LatLng _initialDriverLocation;
//
//   // External
//   final DriverStatusController driverStatusController = Get.put(
//     DriverStatusController(),
//   );
//
//   // Socket
//   late final SocketService socketService;
//
//   // Map controller
//   GoogleMapController? mapController;
//
//   // UI State
//   final Rx<PickingCustomerUiState> ui =
//       PickingCustomerUiState(
//         driverLocation: const LatLng(0, 0),
//         bearing: 0,
//         polyline: const [],
//         directionText: '',
//         distanceText: '',
//         maneuver: '',
//       ).obs;
//
//   // Marker icon
//   final Rxn<BitmapDescriptor> carIcon = Rxn<BitmapDescriptor>();
//
//   // Rider meta (keep your fields)
//   final RxString customerName = ''.obs;
//   final RxString customerPhone = ''.obs;
//   final RxString customerProfilePic = ''.obs;
//
//   final RxString pickupAddressText = ''.obs;
//   final RxString dropAddressText = ''.obs;
//
//   final RxBool driverReached = false.obs; // from server driver-arrived
//   final RxBool arrivedAtPickup =
//       true.obs; // your UI flow (before arrived button)
//
//   // Timer (No-show)
//   Timer? _timer;
//   final RxInt secondsLeft = 0.obs;
//   final RxBool showRedTimer = false.obs;
//
//   // Location stream
//   StreamSubscription<Position>? _posSub;
//
//   // Route throttle
//   DateTime? _lastRouteTick;
//   LatLng? _lastDriverLocForUi;
//   double _lastBearingForUi = 0;
//
//   // Smooth animation
//   late final AnimationController animCtrl;
//   late final Animation<double> anim;
//   Tween<double>? latTween;
//   Tween<double>? lngTween;
//   Tween<double>? rotTween;
//
//   LatLng? _lastPosition;
//
//   // Performance tuning
//   static const double _maxAccuracyM = 25.0;
//   static const double _minMoveMeters = 2.5;
//   static const int _routeThrottleMs = 350;
//   static const double _bearingChangeMin = 3.0;
//
//   // -------------------- lifecycle --------------------
//
//   @override
//   void onInit() {
//     super.onInit();
//
//     ui.value = ui.value.copyWith(driverLocation: _initialDriverLocation);
//
//     animCtrl = AnimationController(
//       vsync: this,
//       duration: const Duration(milliseconds: 650),
//     );
//
//     anim = CurvedAnimation(parent: animCtrl, curve: Curves.easeOutCubic)
//       ..addListener(_onAnimTick);
//
//     _loadCarIcon();
//     _initSocket();
//     _initFirstRouteAndStartTracking();
//   }
//
//   @override
//   void onClose() {
//     _timer?.cancel();
//     _posSub?.cancel();
//     animCtrl.dispose();
//
//     try {
//       socketService.socket.off('joined-booking');
//       socketService.socket.off('driver-location');
//       socketService.socket.off('driver-cancelled');
//       socketService.socket.off('customer-cancelled');
//       socketService.socket.off('driver-arrived');
//     } catch (_) {}
//
//     super.onClose();
//   }
//
//   // -------------------- map --------------------
//
//   Future<void> onMapCreated(GoogleMapController c, BuildContext context) async {
//     mapController = c;
//
//     try {
//       final style = await DefaultAssetBundle.of(
//         context,
//       ).loadString('assets/map_style/map_style1.json');
//       await mapController?.setMapStyle(style);
//     } catch (e) {
//       if (kDebugMode) CommonLogger.log.w("Map style load failed: $e");
//     }
//
//     await fitBoundsToDriverAndPickup();
//   }
//
//   Future<void> fitBoundsToDriverAndPickup() async {
//     if (mapController == null) return;
//
//     final d = ui.value.driverLocation;
//     final bounds = LatLngBounds(
//       southwest: LatLng(
//         math.min(d.latitude, pickupLocation.latitude),
//         math.min(d.longitude, pickupLocation.longitude),
//       ),
//       northeast: LatLng(
//         math.max(d.latitude, pickupLocation.latitude),
//         math.max(d.longitude, pickupLocation.longitude),
//       ),
//     );
//
//     await mapController!.animateCamera(
//       CameraUpdate.newLatLngBounds(bounds, 90),
//     );
//
//     final zoom = await mapController!.getZoomLevel();
//     if (zoom > 16) {
//       await mapController!.animateCamera(CameraUpdate.zoomTo(16));
//     }
//   }
//
//   Future<void> goToCurrentLocation() async {
//     final pos = await _getCurrentPos();
//     if (pos == null) return;
//
//     final latLng = LatLng(pos.latitude, pos.longitude);
//     await mapController?.animateCamera(CameraUpdate.newLatLngZoom(latLng, 17));
//   }
//
//   // -------------------- icon --------------------
//
//   Future<void> _loadCarIcon() async {
//     try {
//       final cfg = const ImageConfiguration(size: Size(42, 42));
//       final String asset =
//           driverStatusController.serviceType.value == "Bike"
//               ? AppImages.parcelBike
//               : AppImages.movingCar;
//
//       final icon = await BitmapDescriptor.asset(cfg, asset);
//       carIcon.value = icon;
//     } catch (_) {
//       carIcon.value = BitmapDescriptor.defaultMarker;
//     }
//   }
//
//   // -------------------- socket --------------------
//
//   Future<void> _initSocket() async {
//     socketService = SocketService();
//     // your SocketService already knows where to connect (based on your app)
//     // if you need initSocket(url), do it here.
//     // socketService.initSocket(ApiConstents.socketUrl);
//
//     socketService.on('joined-booking', (data) async {
//       if (data == null) return;
//
//       try {
//         // if you store joined data somewhere, keep it
//         // JoinedBookingData().setData(data);
//
//         final vehicle = data['vehicle'] ?? {};
//         final String customerN = (data['customerName'] ?? '').toString();
//         final String customerP = (data['customerPhone'] ?? '').toString();
//         final String customerPic =
//             (data['customerProfilePic'] ?? '').toString();
//
//         customerName.value = customerN;
//         customerPhone.value = customerP;
//         customerProfilePic.value = customerPic;
//
//         // addresses from customerLocation
//         final customerLoc = data['customerLocation'];
//         if (customerLoc != null) {
//           final double fromLat =
//               (customerLoc['fromLatitude'] as num).toDouble();
//           final double fromLng =
//               (customerLoc['fromLongitude'] as num).toDouble();
//           final double toLat = (customerLoc['toLatitude'] as num).toDouble();
//           final double toLng = (customerLoc['toLongitude'] as num).toDouble();
//
//           pickupAddressText.value = await getAddressFromLatLng(
//             fromLat,
//             fromLng,
//           );
//           dropAddressText.value = await getAddressFromLatLng(toLat, toLng);
//         } else {
//           pickupAddressText.value = pickupLocationAddress ?? '';
//           dropAddressText.value = dropLocationAddress ?? '';
//         }
//
//         CommonLogger.log.i("Ã¢Å“â€¦ joined-booking handled for $bookingId");
//         CommonLogger.log.i("vehicle: $vehicle");
//       } catch (e) {
//         CommonLogger.log.e("joined-booking parse error: $e");
//       }
//     });
//
//     socketService.on('driver-location', (data) {
//       if (data == null) return;
//
//       // ETA meters/min update (your existing logic)
//       if (data['pickupDistanceInMeters'] != null) {
//         driverStatusController.pickupDistanceInMeters.value =
//             (data['pickupDistanceInMeters'] as num).toDouble();
//       }
//       if (data['pickupDurationInMin'] != null) {
//         driverStatusController.pickupDurationInMin.value =
//             (data['pickupDurationInMin'] as num).toDouble();
//       }
//     });
//
//     socketService.on('driver-arrived', (data) {
//       final status = data?['status'];
//       final ok = status == true || status.toString() == 'true';
//       if (ok) {
//         driverReached.value = true;
//       }
//     });
//
//     socketService.on('driver-cancelled', (data) {
//       final ok = data != null && data['status'] == true;
//       if (ok) {
//         Get.offAllNamed('/driverMain'); // or push DriverMainScreen()
//       }
//     });
//
//     socketService.on('customer-cancelled', (data) {
//       final ok = data != null && data['status'] == true;
//       if (ok) {
//         Get.offAllNamed('/driverMain');
//       }
//     });
//
//     if (!socketService.connected) {
//       socketService.connect();
//       socketService.onConnect(() => CommonLogger.log.i("Ã¢Å“â€¦ socket connected"));
//     }
//   }
//
//   // -------------------- permissions + pos --------------------
//
//   Future<bool> _ensureLocationPermission() async {
//     final serviceEnabled = await Geolocator.isLocationServiceEnabled();
//     if (!serviceEnabled) return false;
//
//     var permission = await Geolocator.checkPermission();
//     if (permission == LocationPermission.denied) {
//       permission = await Geolocator.requestPermission();
//     }
//
//     return permission == LocationPermission.always ||
//         permission == LocationPermission.whileInUse;
//   }
//
//   Future<Position?> _getCurrentPos() async {
//     final ok = await _ensureLocationPermission();
//     if (!ok) return null;
//
//     return Geolocator.getCurrentPosition(
//       desiredAccuracy: LocationAccuracy.bestForNavigation,
//     );
//   }
//
//   // -------------------- route + tracking --------------------
//
//   Future<void> _initFirstRouteAndStartTracking() async {
//     final pos = await _getCurrentPos();
//     if (pos != null) {
//       final latLng = LatLng(pos.latitude, pos.longitude);
//       ui.value = ui.value.copyWith(driverLocation: latLng);
//       _lastPosition = latLng;
//       _lastDriverLocForUi = latLng;
//     } else {
//       _lastPosition = ui.value.driverLocation;
//       _lastDriverLocForUi = ui.value.driverLocation;
//     }
//
//     await _fetchRoute(origin: ui.value.driverLocation);
//     _startTrackingStream();
//   }
//
//   void _startTrackingStream() {
//     _posSub?.cancel();
//
//     _posSub = Geolocator.getPositionStream(
//       locationSettings: const LocationSettings(
//         accuracy: LocationAccuracy.bestForNavigation,
//         distanceFilter: 3,
//       ),
//     ).listen((p) async {
//       final acc = p.accuracy.isFinite ? p.accuracy : 9999.0;
//       if (acc > _maxAccuracyM) return;
//
//       final newLoc = LatLng(p.latitude, p.longitude);
//       final last = _lastPosition ?? newLoc;
//
//       final moved = Geolocator.distanceBetween(
//         last.latitude,
//         last.longitude,
//         newLoc.latitude,
//         newLoc.longitude,
//       );
//       if (moved < _minMoveMeters) return;
//
//       // bearing from path (more stable)
//       final newBearing = _bearingBetween(last, newLoc);
//
//       // smooth animate marker
//       _animateMarkerTo(newLoc, newBearing);
//
//       _lastPosition = newLoc;
//
//       // route tick throttle
//       final now = DateTime.now();
//       if (_lastRouteTick != null &&
//           now.difference(_lastRouteTick!).inMilliseconds < _routeThrottleMs) {
//         return;
//       }
//       _lastRouteTick = now;
//
//       final double movedUi =
//           _lastDriverLocForUi == null
//               ? 999
//               : _haversineMeters(_lastDriverLocForUi!, newLoc);
//       final bool bearingChanged =
//           (newBearing - _lastBearingForUi).abs() > _bearingChangeMin;
//
//       if (movedUi < 2.0 && !bearingChanged) return;
//
//       _lastDriverLocForUi = newLoc;
//       _lastBearingForUi = newBearing;
//
//       // trim polyline + reroute if off-route
//       _trimPolylineFromCurrent(newLoc);
//
//       if (_isOffRoute(newLoc)) {
//         await _fetchRoute(origin: newLoc);
//       }
//     });
//   }
//
//   Future<void> _fetchRoute({required LatLng origin}) async {
//     try {
//       final result = await getRouteInfo(
//         origin: origin,
//         destination: pickupLocation,
//       );
//
//       final String dir = (result['direction'] ?? '').toString();
//       final String dist = (result['distance'] ?? '').toString();
//       final String man = (result['maneuver'] ?? '').toString();
//
//       List<LatLng> pts = decodePolyline((result['polyline'] ?? '').toString());
//
//       // simplify polyline for performance
//       pts = _simplifyPolyline(pts, minStepMeters: 8, maxPoints: 180);
//
//       ui.value = ui.value.copyWith(
//         directionText: _stripHtml(dir),
//         distanceText: dist,
//         maneuver: man,
//         polyline: pts,
//       );
//     } catch (e) {
//       CommonLogger.log.e("route fetch error: $e");
//     }
//   }
//
//   void _trimPolylineFromCurrent(LatLng current) {
//     final pts = ui.value.polyline;
//     if (pts.isEmpty) return;
//
//     int closestIndex = _closestPointIndex(current, pts);
//     if (closestIndex <= 0) return;
//     if (closestIndex >= pts.length) return;
//
//     // Trim once (fixed your old double sublist bug)
//     final trimmed = pts.sublist(closestIndex);
//
//     ui.value = ui.value.copyWith(polyline: trimmed);
//   }
//
//   int _closestPointIndex(LatLng pos, List<LatLng> pts) {
//     double min = double.infinity;
//     int best = 0;
//
//     for (int i = 0; i < pts.length; i++) {
//       final d = Geolocator.distanceBetween(
//         pos.latitude,
//         pos.longitude,
//         pts[i].latitude,
//         pts[i].longitude,
//       );
//       if (d < min) {
//         min = d;
//         best = i;
//       }
//     }
//     return best;
//   }
//
//   bool _isOffRoute(LatLng pos) {
//     final pts = ui.value.polyline;
//     if (pts.isEmpty) return true;
//
//     for (final p in pts) {
//       final d = Geolocator.distanceBetween(
//         pos.latitude,
//         pos.longitude,
//         p.latitude,
//         p.longitude,
//       );
//       if (d < 20) return false; // within 20m = on route
//     }
//     return true;
//   }
//
//   // -------------------- smooth marker --------------------
//
//   void _animateMarkerTo(LatLng newPos, double bearing) {
//     final current = ui.value.driverLocation;
//
//     latTween = Tween(begin: current.latitude, end: newPos.latitude);
//     lngTween = Tween(begin: current.longitude, end: newPos.longitude);
//
//     // rotate via shortest path
//     final curRot = ui.value.bearing;
//     final endRot = _shortestAngle(curRot, bearing);
//     rotTween = Tween(begin: curRot, end: endRot);
//
//     animCtrl
//       ..stop()
//       ..reset()
//       ..forward();
//   }
//
//   void _onAnimTick() {
//     final lt = latTween;
//     final lg = lngTween;
//     final rt = rotTween;
//     if (lt == null || lg == null || rt == null) return;
//
//     final lat = lt.evaluate(anim);
//     final lng = lg.evaluate(anim);
//     final rot = rt.evaluate(anim);
//
//     ui.value = ui.value.copyWith(
//       driverLocation: LatLng(lat, lng),
//       bearing: _normalizeAngle(rot),
//     );
//
//     // optional: camera follow if you want Uber feel (can be heavy if always)
//     // mapController?.animateCamera(
//     //   CameraUpdate.newCameraPosition(
//     //     CameraPosition(target: ui.value.driverLocation, zoom: 17, tilt: 60, bearing: ui.value.bearing),
//     //   ),
//     // );
//   }
//
//   // -------------------- timer controls --------------------
//
//   void startNoShowTimer() {
//     _timer?.cancel();
//     secondsLeft.value = 300;
//     showRedTimer.value = false;
//
//     _timer = Timer.periodic(const Duration(seconds: 1), (t) {
//       if (secondsLeft.value > 0) {
//         secondsLeft.value -= 1;
//         showRedTimer.value = secondsLeft.value <= 10;
//       } else {
//         t.cancel();
//       }
//     });
//   }
//
//   void stopNoShowTimer() {
//     _timer?.cancel();
//     _timer = null;
//     secondsLeft.value = 0;
//     showRedTimer.value = false;
//   }
//
//   String formatTimer(int seconds) {
//     final m = (seconds ~/ 60).toString().padLeft(2, '0');
//     final s = (seconds % 60).toString().padLeft(2, '0');
//     return '$m:$s';
//   }
//
//   // -------------------- actions used by UI --------------------
//
//   Future<void> onArrivedAtPickupPressed(BuildContext context) async {
//     final result = await driverStatusController.driverArrived(
//       context,
//       bookingId: bookingId,
//     );
//
//     if (result != null && result.status == 200) {
//       arrivedAtPickup.value = false; // move to waiting rider flow
//       startNoShowTimer();
//     } else {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text(result?.message ?? "Something went wrong")),
//       );
//     }
//   }
//
//   Future<void> onSwipeStartRide(BuildContext context) async {
//     // 1) Request OTP
//     final msg = await driverStatusController.otpRequest(
//       context,
//       bookingId: bookingId,
//       custName: customerName.value,
//       pickupAddress: pickupLocationAddress ?? pickupAddressText.value,
//       dropAddress: dropLocationAddress ?? dropAddressText.value,
//     );
//
//     // 2) If OTP request failed -> stop here
//     if (msg == null) return;
//
//     // 3) Stop timer (no-show timer etc.)
//     stopNoShowTimer();
//
//     // 4) Navigate to Verify screen
//     //    Ã¢Å“â€¦ single ride -> it will go RideStatsScreen after verify
//     Get.to(
//       () => VerifyRiderScreen(
//         bookingId: bookingId,
//         custName: customerName.value,
//         pickupAddress: pickupLocationAddress ?? pickupAddressText.value,
//         dropAddress: dropLocationAddress ?? dropAddressText.value,
//         isSharedRide: false, // Ã¢Å“â€¦ single pickup screen
//       ),
//     );
//   }
//
//   // Future<void> onSwipeStartRide(BuildContext context) async {
//   //   final msg = await driverStatusController.otpRequest(
//   //     context,
//   //     bookingId: bookingId,
//   //     custName: customerName.value,
//   //     pickupAddress: pickupLocationAddress ?? pickupAddressText.value,
//   //     dropAddress: dropLocationAddress ?? dropAddressText.value,
//   //   );
//   //
//   //   if (msg != null) {
//   //     stopNoShowTimer();
//   //   }
//   // }
//
//   // -------------------- helpers --------------------
//
//   Future<String> getAddressFromLatLng(double lat, double lng) async {
//     try {
//       final list = await placemarkFromCoordinates(lat, lng);
//       final p = list.first;
//       return "${p.name}, ${p.locality}, ${p.administrativeArea}";
//     } catch (_) {
//       return "Location not available";
//     }
//   }
//
//   String getManeuverIcon(String m) {
//     switch (m) {
//       case "turn-right":
//         return "assets/images/right-turn.png";
//       case "turn-left":
//         return "assets/images/left-turn.png";
//       case "roundabout-left":
//         return "assets/images/roundabout-left.png";
//       case "roundabout-right":
//         return "assets/images/roundabout-right.png";
//       default:
//         return 'assets/images/straight.png';
//     }
//   }
//
//   double _bearingBetween(LatLng start, LatLng end) {
//     final lat1 = start.latitude * (math.pi / 180.0);
//     final lon1 = start.longitude * (math.pi / 180.0);
//     final lat2 = end.latitude * (math.pi / 180.0);
//     final lon2 = end.longitude * (math.pi / 180.0);
//
//     final dLon = lon2 - lon1;
//     final y = math.sin(dLon) * math.cos(lat2);
//     final x =
//         math.cos(lat1) * math.sin(lat2) -
//         math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
//
//     final brng = math.atan2(y, x);
//     return (brng * 180 / math.pi + 360) % 360;
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
//   String _stripHtml(String htmlText) {
//     return htmlText
//         .replaceAll(RegExp(r'<[^>]*>'), '')
//         .replaceAll('&nbsp;', ' ')
//         .replaceAll('&amp;', '&');
//   }
//
//   double _degToRad(double d) => d * (math.pi / 180.0);
//
//   double _haversineMeters(LatLng a, LatLng b) {
//     const r = 6371000.0;
//     final dLat = _degToRad(b.latitude - a.latitude);
//     final dLon = _degToRad(b.longitude - a.longitude);
//     final lat1 = _degToRad(a.latitude);
//     final lat2 = _degToRad(b.latitude);
//
//     final h =
//         math.sin(dLat / 2) * math.sin(dLat / 2) +
//         math.cos(lat1) *
//             math.cos(lat2) *
//             math.sin(dLon / 2) *
//             math.sin(dLon / 2);
//
//     return 2 * r * math.asin(math.sqrt(h));
//   }
//
//   List<LatLng> _simplifyPolyline(
//     List<LatLng> points, {
//     required double minStepMeters,
//     required int maxPoints,
//   }) {
//     if (points.length <= 2) return points;
//     final simplified = <LatLng>[points.first];
//
//     LatLng last = points.first;
//     for (int i = 1; i < points.length - 1; i++) {
//       final p = points[i];
//       if (_haversineMeters(last, p) >= minStepMeters) {
//         simplified.add(p);
//         last = p;
//         if (simplified.length >= maxPoints) break;
//       }
//     }
//     simplified.add(points.last);
//     return simplified;
//   }
// }
