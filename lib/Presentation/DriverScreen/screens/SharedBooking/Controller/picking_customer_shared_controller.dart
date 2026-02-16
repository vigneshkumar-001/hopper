import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:hopper/Core/Constants/log.dart';
import 'package:hopper/Core/Utility/images.dart';
import 'package:hopper/Presentation/DriverScreen/controller/driver_status_controller.dart';
import 'package:hopper/api/repository/api_constents.dart';
import 'package:hopper/utils/map/route_info.dart';
import 'package:hopper/utils/websocket/socket_io_client.dart';

import 'shared_ride_controller.dart';

class SharedRouteUiState {
  final LatLng driverLocation;
  final double bearing;
  final List<LatLng> polyline;
  final String directionText;
  final String distanceText;
  final String maneuver;

  const SharedRouteUiState({
    required this.driverLocation,
    required this.bearing,
    required this.polyline,
    required this.directionText,
    required this.distanceText,
    required this.maneuver,
  });

  SharedRouteUiState copyWith({
    LatLng? driverLocation,
    double? bearing,
    List<LatLng>? polyline,
    String? directionText,
    String? distanceText,
    String? maneuver,
  }) {
    return SharedRouteUiState(
      driverLocation: driverLocation ?? this.driverLocation,
      bearing: bearing ?? this.bearing,
      polyline: polyline ?? this.polyline,
      directionText: directionText ?? this.directionText,
      distanceText: distanceText ?? this.distanceText,
      maneuver: maneuver ?? this.maneuver,
    );
  }
}

class _Eta {
  final double meters;
  final double minutes;
  final DateTime at;
  const _Eta(this.meters, this.minutes, this.at);
}

class PickingCustomerSharedController extends GetxController {
  final LatLng pickupLocation;
  final LatLng driverLocation;
  final String bookingId;

  PickingCustomerSharedController({
    required this.pickupLocation,
    required this.driverLocation,
    required this.bookingId,
  });

  // deps
  final DriverStatusController driverStatusController =
  Get.find<DriverStatusController>();

  final SharedRideController sharedRideController =
  Get.find<SharedRideController>();

  // socket
  late final SocketService socketService;

  // map icon
  final Rxn<BitmapDescriptor> carIcon = Rxn<BitmapDescriptor>();

  // UI state
  late final Rx<SharedRouteUiState> routeUi;

  // ✅ ETA shown in UI (for active rider ONLY)
  final RxDouble etaMeters = 0.0.obs;
  final RxDouble etaMinutes = 0.0.obs;

  // ✅ Show "Updating..." while switching riders until fresh ETA arrives
  final RxBool isEtaUpdating = false.obs;

  // ✅ Cache ETA per rider bookingId (prevents old values flash)
  final Map<String, _Eta> _etaCache = {};

  // focus toggle (used by your UI button)
  final isDriverFocused = false.obs;

  // tracking
  StreamSubscription<Position>? _posSub;
  LatLng? _lastPos;
  bool _animating = false;

  // routing
  List<LatLng> _poly = [];
  DateTime _lastRouteFetch = DateTime.fromMillisecondsSinceEpoch(0);

  // thresholds
  static const double _MAX_ACCURACY_M = 25.0;
  static const double _MIN_MOVE_METERS = 3.0;
  static const double _MIN_SPEED_MS = 1.0;
  static const double _HEADING_TRUST_MS = 2.0;
  static const double _MIN_TURN_DEG = 10.0;
  static const double _OFF_ROUTE_TOLERANCE_M = 25.0;

  @override
  void onInit() {
    super.onInit();

    DirectionsConfig.apiKey = ApiConstents.googleMapApiKey;

    routeUi = SharedRouteUiState(
      driverLocation: driverLocation,
      bearing: 0,
      polyline: const [],
      directionText: '',
      distanceText: '',
      maneuver: '',
    ).obs;

    _applySystemUi();
    _loadCarIcon();
    _initSocket();
    _startTracking();
    _fetchRoute(force: true);
  }

  @override
  void onClose() {
    _posSub?.cancel();
    try {
      socketService.socket.off('joined-booking');
      socketService.socket.off('driver-location');
      socketService.socket.off('driver-arrived');
      socketService.socket.off('driver-cancelled');
      socketService.socket.off('customer-cancelled');
    } catch (_) {}
    super.onClose();
  }

  // ---------------- UI ----------------
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
      final ctx = Get.context;
      final dpr = (ctx != null) ? MediaQuery.of(ctx).devicePixelRatio : 2.5;

      // ✅ bigger + cleaner icon (use good PNG asset 96/128px)
      final cfg = ImageConfiguration(
        size: const Size(72, 72),
        devicePixelRatio: dpr,
      );

      final asset = driverStatusController.serviceType.value == "Bike"
          ? AppImages.parcelBike
          : AppImages.movingCar;

      final icon = await BitmapDescriptor.fromAssetImage(cfg, asset);
      carIcon.value = icon;
    } catch (e) {
      CommonLogger.log.e("car icon load failed: $e");
      carIcon.value = BitmapDescriptor.defaultMarker;
    }
  }

  // ---------------- SOCKET ----------------
  void _initSocket() {
    socketService = SocketService();

    socketService.on('joined-booking', (data) async {
      if (data == null) return;

      CommonLogger.log.i("✅ [SHARED] joined-booking received: $data");

      await sharedRideController.upsertFromSocket(
        Map<String, dynamic>.from(data as Map),
      );

      // ✅ if first rider, set ETA state to updating until we get driver-location
      if (sharedRideController.activeTarget.value != null) {
        isEtaUpdating.value = true;
      }

      await _fetchRoute(force: true);
    });

    socketService.on('driver-location', (data) {
      if (data == null) return;

      final map = Map<String, dynamic>.from(data as Map);
      final eventBookingId = (map['bookingId'] ?? '').toString();
      final activeId = sharedRideController.activeTarget.value?.bookingId;

      // ✅ update cache always (so when user taps later, we instantly show latest)
      final meters = (map['pickupDistanceInMeters'] as num?)?.toDouble() ?? 0.0;
      final mins = (map['pickupDurationInMin'] as num?)?.toDouble() ?? 0.0;
      _etaCache[eventBookingId] = _Eta(meters, mins, DateTime.now());

      // ✅ update UI ONLY if this event belongs to selected rider
      if (activeId != null && eventBookingId == activeId) {
        etaMeters.value = meters;
        etaMinutes.value = mins;
        isEtaUpdating.value = false;

        // (optional) keep old global values if used in other widgets
        driverStatusController.pickupDistanceInMeters.value = meters;
        driverStatusController.pickupDurationInMin.value = mins;
      }
    });

    socketService.socket.onAny((event, data) {
      CommonLogger.log.i('📦 [shared picking socket] $event: $data');
    });

    if (!socketService.connected) {
      socketService.connect();
      socketService.onConnect(() => CommonLogger.log.i("✅ Socket connected"));
    }
  }

  // ---------------- target selection from UI ----------------
  Future<void> selectRider(SharedRiderItem rider) async {
    sharedRideController.activeTarget.value = rider;

    // ✅ show cached ETA immediately if available (no old customer flash)
    final cached = _etaCache[rider.bookingId];
    if (cached != null) {
      etaMeters.value = cached.meters;
      etaMinutes.value = cached.minutes;
      // still mark updating because new socket tick may come in seconds
      isEtaUpdating.value = true;
    } else {
      etaMeters.value = 0;
      etaMinutes.value = 0;
      isEtaUpdating.value = true;
    }

    await _fetchRoute(force: true);
  }

  // ---------------- ROUTE ----------------
  String _stripHtml(String s) {
    return s
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&');
  }

  LatLng _getCurrentDestination() {
    final active = sharedRideController.activeTarget.value;

    if (active != null) {
      if (active.stage == SharedRiderStage.onboardDrop) {
        return active.dropLatLng;
      }
      return active.pickupLatLng;
    }

    return pickupLocation;
  }

  double _safeToDouble(dynamic v) {
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }

  Future<void> _fetchRoute({bool force = false}) async {
    try {
      final now = DateTime.now();
      if (!force && now.difference(_lastRouteFetch).inSeconds < 6) return;
      _lastRouteFetch = now;

      final origin = routeUi.value.driverLocation;
      final destination = _getCurrentDestination();

      final result = await getRouteInfo(
        origin: origin,
        destination: destination,
        alternatives: false,
        traffic: true,
        mode: "driving",
        routeIndex: 0,
      );

      final poly = (result['polyline'] ?? '').toString();
      final pts = decodePolyline(poly);
      _poly = pts;

      // ✅ Optional: route numeric ETA (only if your getRouteInfo returns them)
      final distMeters = _safeToDouble(
        result['distanceInMeters'] ?? result['distance_meters'],
      );
      final durMin = _safeToDouble(
        result['durationInMin'] ?? result['duration_min'],
      );

      // if socket not yet updated, route ETA can help (don’t override if socket already fresh)
      if (isEtaUpdating.value && distMeters > 0) {
        etaMeters.value = distMeters;
      }
      if (isEtaUpdating.value && durMin >= 0) {
        etaMinutes.value = durMin;
      }

      routeUi.value = routeUi.value.copyWith(
        polyline: pts,
        directionText: _stripHtml((result['direction'] ?? '').toString()),
        distanceText: (result['distance'] ?? '').toString(),
        maneuver: (result['maneuver'] ?? '').toString(),
      );
    } catch (e) {
      CommonLogger.log.e("❌ [SHARED] _fetchRoute failed: $e");
    }
  }

  void _trimPolyline(LatLng current) {
    if (_poly.isEmpty) return;

    final idx = _closestPointIndex(current, _poly);
    if (idx <= 0) return;

    final keepFrom = (idx - 1).clamp(0, _poly.length - 1);
    _poly = _poly.sublist(keepFrom);

    routeUi.value = routeUi.value.copyWith(polyline: _poly);
  }

  int _closestPointIndex(LatLng pos, List<LatLng> pts) {
    double best = double.infinity;
    int idx = 0;
    for (int i = 0; i < pts.length; i++) {
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
    return idx;
  }

  bool _isOffRoute(LatLng current) {
    if (_poly.isEmpty) return true;

    for (final p in _poly) {
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

  // ---------------- TRACKING ----------------
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

  void _startTracking() async {
    final ok = await _ensureLocationPermission();
    if (!ok) return;

    _posSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 3,
      ),
    ).listen((pos) async {
      final acc = (pos.accuracy.isFinite) ? pos.accuracy : 9999.0;
      if (acc > _MAX_ACCURACY_M) return;

      final current = LatLng(pos.latitude, pos.longitude);
      sharedRideController.updateDriverLocation(current);

      final speed = (pos.speed.isFinite) ? pos.speed : 0.0;
      final heading = (pos.heading.isFinite) ? pos.heading : -1.0;

      if (_lastPos == null) {
        _lastPos = current;
        routeUi.value = routeUi.value.copyWith(driverLocation: current);
        return;
      }

      final moved = Geolocator.distanceBetween(
        _lastPos!.latitude,
        _lastPos!.longitude,
        current.latitude,
        current.longitude,
      );

      if (moved < _MIN_MOVE_METERS) {
        routeUi.value = routeUi.value.copyWith(driverLocation: current);
        _lastPos = current;
        return;
      }

      double targetBearing = routeUi.value.bearing;

      if (speed >= _HEADING_TRUST_MS && heading >= 0) {
        targetBearing = heading;
      } else {
        targetBearing = _bearingBetween(_lastPos!, current);
      }

      final diff = _angleDeltaDeg(routeUi.value.bearing, targetBearing);
      if (speed < _MIN_SPEED_MS && diff < _MIN_TURN_DEG) {
        targetBearing = routeUi.value.bearing;
      }

      await _animateTo(current, targetBearing);
      _lastPos = current;

      _trimPolyline(current);

      if (_isOffRoute(current)) {
        await _fetchRoute(force: true);
      } else {
        await _fetchRoute(force: false);
      }
    });
  }

  Future<void> _animateTo(LatLng to, double bearing) async {
    if (_animating) return;
    _animating = true;

    final from = routeUi.value.driverLocation;
    final startBearing = routeUi.value.bearing;
    final endBearing = _shortestAngle(startBearing, bearing);

    const steps = 18; // ✅ faster + smoother
    const total = Duration(milliseconds: 520);
    final stepMs = total.inMilliseconds ~/ steps;

    for (int i = 1; i <= steps; i++) {
      await Future.delayed(Duration(milliseconds: stepMs));
      final t = i / steps;

      final lat = _lerp(from.latitude, to.latitude, t);
      final lng = _lerp(from.longitude, to.longitude, t);
      final b = _lerpBearing(startBearing, endBearing, t);

      routeUi.value = routeUi.value.copyWith(
        driverLocation: LatLng(lat, lng),
        bearing: _normalizeAngle(b),
      );
    }

    _animating = false;
  }

  double _lerp(double a, double b, double t) => a + (b - a) * t;

  double _lerpBearing(double start, double end, double t) {
    final difference = ((end - start + 540) % 360) - 180;
    return (start + difference * t + 360) % 360;
  }

  double _bearingBetween(LatLng a, LatLng b) {
    final lat1 = a.latitude * math.pi / 180;
    final lon1 = a.longitude * math.pi / 180;
    final lat2 = b.latitude * math.pi / 180;
    final lon2 = b.longitude * math.pi / 180;

    final dLon = lon2 - lon1;
    final y = math.sin(dLon) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
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
}
/*import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:hopper/Core/Constants/log.dart';
import 'package:hopper/Core/Utility/images.dart';
import 'package:hopper/Presentation/DriverScreen/controller/driver_status_controller.dart';
import 'package:hopper/api/repository/api_constents.dart';
import 'package:hopper/utils/map/route_info.dart';
import 'package:hopper/utils/websocket/socket_io_client.dart';

import 'shared_ride_controller.dart';

class SharedRouteUiState {
  final LatLng driverLocation;
  final double bearing;
  final List<LatLng> polyline;
  final String directionText;
  final String distanceText;
  final String maneuver;

  const SharedRouteUiState({
    required this.driverLocation,
    required this.bearing,
    required this.polyline,
    required this.directionText,
    required this.distanceText,
    required this.maneuver,
  });

  SharedRouteUiState copyWith({
    LatLng? driverLocation,
    double? bearing,
    List<LatLng>? polyline,
    String? directionText,
    String? distanceText,
    String? maneuver,
  }) {
    return SharedRouteUiState(
      driverLocation: driverLocation ?? this.driverLocation,
      bearing: bearing ?? this.bearing,
      polyline: polyline ?? this.polyline,
      directionText: directionText ?? this.directionText,
      distanceText: distanceText ?? this.distanceText,
      maneuver: maneuver ?? this.maneuver,
    );
  }
}

class PickingCustomerSharedController extends GetxController {
  final LatLng pickupLocation;
  final LatLng driverLocation;
  final String bookingId;

  PickingCustomerSharedController({
    required this.pickupLocation,
    required this.driverLocation,
    required this.bookingId,
  });

  // deps
  final DriverStatusController driverStatusController =
  Get.find<DriverStatusController>();

  final SharedRideController sharedRideController =
  Get.find<SharedRideController>();

  // socket
  late final SocketService socketService;

  // map icon
  final Rxn<BitmapDescriptor> carIcon = Rxn<BitmapDescriptor>();

  // UI state
  late final Rx<SharedRouteUiState> routeUi;

  // ✅ NEW: ETA from our own route (more reliable than socket rounding)
  final RxDouble etaMeters = 0.0.obs;
  final RxDouble etaMinutes = 0.0.obs;

  // focus toggle (used by your UI button)
  final isDriverFocused = false.obs;

  // tracking
  StreamSubscription<Position>? _posSub;
  LatLng? _lastPos;
  bool _animating = false;

  // routing
  List<LatLng> _poly = [];
  DateTime _lastRouteFetch = DateTime.fromMillisecondsSinceEpoch(0);

  // thresholds
  static const double _MAX_ACCURACY_M = 25.0;
  static const double _MIN_MOVE_METERS = 3.0;
  static const double _MIN_SPEED_MS = 1.0;
  static const double _HEADING_TRUST_MS = 2.0;
  static const double _MIN_TURN_DEG = 10.0;
  static const double _OFF_ROUTE_TOLERANCE_M = 25.0;

  @override
  void onInit() {
    super.onInit();

    DirectionsConfig.apiKey = ApiConstents.googleMapApiKey;

    routeUi = SharedRouteUiState(
      driverLocation: driverLocation,
      bearing: 0,
      polyline: const [],
      directionText: '',
      distanceText: '',
      maneuver: '',
    ).obs;

    _applySystemUi();
    _loadCarIcon();
    _initSocket();
    _startTracking();
    _fetchRoute(force: true);
  }

  @override
  void onClose() {
    _posSub?.cancel();
    try {
      socketService.socket.off('joined-booking');
      socketService.socket.off('driver-location');
      socketService.socket.off('driver-arrived');
      socketService.socket.off('driver-cancelled');
      socketService.socket.off('customer-cancelled');
    } catch (_) {}
    super.onClose();
  }

  // ---------------- UI ----------------
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
      final asset = driverStatusController.serviceType.value == "Bike"
          ? AppImages.parcelBike
          : AppImages.movingCar;

      final icon = await BitmapDescriptor.fromAssetImage(cfg, asset);
      carIcon.value = icon;
    } catch (_) {
      carIcon.value = BitmapDescriptor.defaultMarker;
    }
  }

  // ---------------- SOCKET ----------------
  void _initSocket() {
    socketService = SocketService();

    socketService.on('joined-booking', (data) async {
      if (data == null) return;

      CommonLogger.log.i("✅ [SHARED] joined-booking received: $data");

      await sharedRideController.upsertFromSocket(
        Map<String, dynamic>.from(data as Map),
      );

      CommonLogger.log.i(
        "✅ [SHARED] riders count = ${sharedRideController.riders.length}",
      );

      await _fetchRoute(force: true);
    });

    // ❗ Keep this only if you still need it elsewhere.
    // But ETA UI will now use our route ETA (etaMeters/etaMinutes)
    socketService.on('driver-location', (data) {
      if (data == null) return;

      final map = Map<String, dynamic>.from(data as Map);
      final String eventBookingId = (map['bookingId'] ?? '').toString();

      final activeId = sharedRideController.activeTarget.value?.bookingId;

      // ✅ Update ONLY if this event belongs to selected rider
      if (activeId != null && eventBookingId != activeId) return;

      // ✅ Update shared screen ETA variables (recommended)
      if (map['pickupDistanceInMeters'] != null) {
        etaMeters.value = (map['pickupDistanceInMeters'] as num).toDouble();
      }
      if (map['pickupDurationInMin'] != null) {
        etaMinutes.value = (map['pickupDurationInMin'] as num).toDouble();
      }

      // (optional) keep old global values if needed elsewhere
      driverStatusController.pickupDistanceInMeters.value = etaMeters.value;
      driverStatusController.pickupDurationInMin.value = etaMinutes.value;
    });

    socketService.socket.onAny((event, data) {
      CommonLogger.log.i('📦 [shared picking socket] $event: $data');
    });

    if (!socketService.connected) {
      socketService.connect();
      socketService.onConnect(() => CommonLogger.log.i("✅ Socket connected"));
    }
  }

  // ---------------- target selection from UI ----------------
  Future<void> selectRider(SharedRiderItem rider) async {
    sharedRideController.activeTarget.value = rider;

    // ✅ reset so old customer values won’t show
    etaMeters.value = 0;
    etaMinutes.value = 0;

    await _fetchRoute(force: true);
  }

  // ---------------- ROUTE ----------------
  String _stripHtml(String s) {
    return s
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&');
  }

  LatLng _getCurrentDestination() {
    final active = sharedRideController.activeTarget.value;

    if (active != null) {
      if (active.stage == SharedRiderStage.onboardDrop) {
        return active.dropLatLng;
      }
      return active.pickupLatLng;
    }

    return pickupLocation;
  }

  double _safeToDouble(dynamic v) {
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }

  Future<void> _fetchRoute({bool force = false}) async {
    try {
      final now = DateTime.now();
      if (!force && now.difference(_lastRouteFetch).inSeconds < 8) return;
      _lastRouteFetch = now;

      final origin = routeUi.value.driverLocation;
      final destination = _getCurrentDestination();

      final result = await getRouteInfo(
        origin: origin,
        destination: destination,
        alternatives: false,
        traffic: true,
        mode: "driving",
        routeIndex: 0,
      );

      final poly = (result['polyline'] ?? '').toString();
      final pts = decodePolyline(poly);
      _poly = pts;

      // ✅ NEW: pick numeric distance + duration from route response
      // If your getRouteInfo already returns numeric keys, use them:
      // - distanceInMeters
      // - durationInMin
      final distMeters = _safeToDouble(
        result['distanceInMeters'] ?? result['distance_meters'],
      );
      final durMin = _safeToDouble(
        result['durationInMin'] ?? result['duration_min'],
      );

      // fallback: if numeric not present, keep 0 (UI will still show)
      etaMeters.value = distMeters;
      etaMinutes.value = durMin;

      routeUi.value = routeUi.value.copyWith(
        polyline: pts,
        directionText: _stripHtml((result['direction'] ?? '').toString()),
        distanceText: (result['distance'] ?? '').toString(),
        maneuver: (result['maneuver'] ?? '').toString(),
      );
    } catch (e) {
      CommonLogger.log.e("❌ [SHARED] _fetchRoute failed: $e");
    }
  }

  void _trimPolyline(LatLng current) {
    if (_poly.isEmpty) return;

    int idx = _closestPointIndex(current, _poly);
    if (idx <= 0) return;

    final keepFrom = (idx - 1).clamp(0, _poly.length - 1);
    _poly = _poly.sublist(keepFrom);

    routeUi.value = routeUi.value.copyWith(polyline: _poly);
  }

  int _closestPointIndex(LatLng pos, List<LatLng> pts) {
    double best = double.infinity;
    int idx = 0;
    for (int i = 0; i < pts.length; i++) {
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
    return idx;
  }

  bool _isOffRoute(LatLng current) {
    if (_poly.isEmpty) return true;

    for (final p in _poly) {
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

  // ---------------- TRACKING ----------------
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

  void _startTracking() async {
    final ok = await _ensureLocationPermission();
    if (!ok) return;

    _posSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 3,
      ),
    ).listen((pos) async {
      final acc = (pos.accuracy.isFinite) ? pos.accuracy : 9999.0;
      if (acc > _MAX_ACCURACY_M) return;

      final current = LatLng(pos.latitude, pos.longitude);
      sharedRideController.updateDriverLocation(current);

      final speed = (pos.speed.isFinite) ? pos.speed : 0.0;
      final heading = (pos.heading.isFinite) ? pos.heading : -1.0;

      if (_lastPos == null) {
        _lastPos = current;
        routeUi.value = routeUi.value.copyWith(driverLocation: current);
        return;
      }

      final moved = Geolocator.distanceBetween(
        _lastPos!.latitude,
        _lastPos!.longitude,
        current.latitude,
        current.longitude,
      );

      if (moved < _MIN_MOVE_METERS) {
        routeUi.value = routeUi.value.copyWith(driverLocation: current);
        _lastPos = current;
        return;
      }

      double targetBearing = routeUi.value.bearing;

      if (speed >= _HEADING_TRUST_MS && heading >= 0) {
        targetBearing = heading;
      } else {
        targetBearing = _bearingBetween(_lastPos!, current);
      }

      final diff = _angleDeltaDeg(routeUi.value.bearing, targetBearing);
      if (speed < _MIN_SPEED_MS && diff < _MIN_TURN_DEG) {
        targetBearing = routeUi.value.bearing;
      }

      await _animateTo(current, targetBearing);
      _lastPos = current;

      _trimPolyline(current);

      if (_isOffRoute(current)) {
        await _fetchRoute(force: true);
      } else {
        await _fetchRoute(force: false);
      }
    });
  }

  Future<void> _animateTo(LatLng to, double bearing) async {
    if (_animating) return;
    _animating = true;

    final from = routeUi.value.driverLocation;
    final startBearing = routeUi.value.bearing;
    final endBearing = _shortestAngle(startBearing, bearing);

    const steps = 28;
    const total = Duration(milliseconds: 750);
    final stepMs = total.inMilliseconds ~/ steps;

    for (int i = 1; i <= steps; i++) {
      await Future.delayed(Duration(milliseconds: stepMs));
      final t = i / steps;

      final lat = _lerp(from.latitude, to.latitude, t);
      final lng = _lerp(from.longitude, to.longitude, t);
      final b = _lerpBearing(startBearing, endBearing, t);

      routeUi.value = routeUi.value.copyWith(
        driverLocation: LatLng(lat, lng),
        bearing: _normalizeAngle(b),
      );
    }

    _animating = false;
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
    final x = math.cos(lat1) * math.sin(lat2) -
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
}*/




// import 'dart:async';
// import 'dart:math' as math;
// import 'dart:ui' as ui;
//
// import 'package:flutter/foundation.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:geocoding/geocoding.dart';
// import 'package:get/get.dart';
// import 'package:google_maps_flutter/google_maps_flutter.dart';
//
// import 'package:hopper/Core/Constants/log.dart';
// import 'package:hopper/Core/Utility/images.dart';
// import 'package:hopper/Presentation/DriverScreen/controller/driver_status_controller.dart';
// import 'package:hopper/Presentation/DriverScreen/screens/SharedBooking/Controller/booking_request_controller.dart';
// import 'package:hopper/Presentation/DriverScreen/screens/SharedBooking/Controller/shared_ride_controller.dart';
// import 'package:hopper/api/repository/api_constents.dart';
//
// import '../../../../../utils/map/driver_route.dart';
// import '../../../../../utils/websocket/socket_io_client.dart';
//
// /// Immutable UI state used by the screen
// class RouteUiState {
//   final LatLng driverLocation;
//   final double bearing;
//   final List<LatLng> polyline;
//   final String directionText;
//   final String distanceText;
//   final String maneuver;
//
//   const RouteUiState({
//     required this.driverLocation,
//     required this.bearing,
//     required this.polyline,
//     required this.directionText,
//     required this.distanceText,
//     required this.maneuver,
//   });
//
//   RouteUiState copyWith({
//     LatLng? driverLocation,
//     double? bearing,
//     List<LatLng>? polyline,
//     String? directionText,
//     String? distanceText,
//     String? maneuver,
//   }) {
//     return RouteUiState(
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
// class PickingCustomerSharedController extends GetxController {
//   final LatLng pickupLocation;
//   final LatLng driverLocation;
//   final String bookingId;
//
//   PickingCustomerSharedController({
//     required this.pickupLocation,
//     required this.driverLocation,
//     required this.bookingId,
//   });
//
//   // External controllers
//   final SharedRideController sharedRideController = Get.find<SharedRideController>();
//   final DriverStatusController driverStatusController = Get.find<DriverStatusController>();
//   final BookingRequestController bookingController = Get.find<BookingRequestController>();
//
//   // Socket
//   final SocketService socketService = SocketService();
//
//   // Route engine
//   late final DriverRouteController _routeController;
//
//   // UI state (observables)
//   final Rx<RouteUiState> routeUi = RouteUiState(
//     driverLocation: const LatLng(0, 0),
//     bearing: 0,
//     polyline: const [],
//     directionText: '',
//     distanceText: '',
//     maneuver: '',
//   ).obs;
//
//   final Rxn<BitmapDescriptor> carIcon = Rxn<BitmapDescriptor>();
//   final RxBool isDriverFocused = false.obs;
//
//   /// Navigation trigger (screen will watch this)
//   final RxBool goHome = false.obs;
//
//   // Filters / throttle
//   DateTime? _lastRouteTick;
//   LatLng? _lastDriverLocForUi;
//   double _lastBearingForUi = 0;
//
//   // Global timer for riders (no-show)
//   Timer? _globalTimer;
//
//   @override
//   void onInit() {
//     super.onInit();
//
//     // initial ui values
//     routeUi.value = routeUi.value.copyWith(driverLocation: driverLocation);
//
//     _loadCarIcon();
//     _initSocket();
//     _initRoute();
//   }
//
//   @override
//   void onClose() {
//     _globalTimer?.cancel();
//
//     try {
//       _routeController.dispose();
//     } catch (_) {}
//
//     // remove listeners safely
//     try {
//       // socketService.off('booking-request');
//       socketService.off('driver-location');
//       socketService.off('driver-cancelled');
//       socketService.off('customer-cancelled');
//       socketService.off('driver-arrived');
//     } catch (_) {}
//
//     // DO NOT dispose global socket if you reuse same instance app-wide
//     // If this shared socket is exclusive, you can dispose here.
//     // socketService.dispose();
//
//     super.onClose();
//   }
//
//   // ---------------------------------------------------------
//   // SOCKET
//   // ---------------------------------------------------------
//   void _initSocket() {
//     socketService.initSocket(ApiConstents.sharedRideSocket);
//
//     // booking-request -> show overlay request
//     socketService.on('booking-request', (data) async {
//       if (data == null) return;
//       CommonLogger.log.i('[SHARED PICK] 📦 Booking Request → $data');
//
//       final incomingId = data['bookingId']?.toString();
//       if (incomingId == null) return;
//
//       // ignore current screen booking
//       if (incomingId == bookingId) return;
//
//       // prevent duplicates
//       if (incomingId == bookingController.lastHandledBookingId.value) return;
//
//       final pickup = data['pickupLocation'];
//       final drop = data['dropLocation'];
//       if (pickup == null || drop == null) return;
//
//       final pickupAddr = await getAddressFromLatLng(
//         (pickup['latitude'] as num).toDouble(),
//         (pickup['longitude'] as num).toDouble(),
//       );
//
//       final dropAddr = await getAddressFromLatLng(
//         (drop['latitude'] as num).toDouble(),
//         (drop['longitude'] as num).toDouble(),
//       );
//
//       bookingController.showRequest(
//         rawData: data,
//         pickupAddress: pickupAddr,
//         dropAddress: dropAddr,
//       );
//     });
//
//     // ETA updates
//     void handleDriverLocation(dynamic data) {
//       if (data == null) return;
//
//       final active = sharedRideController.activeTarget.value;
//       final eventBookingId = data['bookingId']?.toString();
//
//       // If active rider selected, only accept matching bookingId
//       if (active != null && eventBookingId != null) {
//         if (eventBookingId != active.bookingId) return;
//       }
//
//       if (data['pickupDistanceInMeters'] != null) {
//         driverStatusController.pickupDistanceInMeters.value =
//             (data['pickupDistanceInMeters'] as num).toDouble();
//       }
//
//       if (data['pickupDurationInMin'] != null) {
//         driverStatusController.pickupDurationInMin.value =
//             (data['pickupDurationInMin'] as num).toDouble();
//       }
//     }
//
//     socketService.on('driver-cancelled', (data) {
//       if (data != null && data['status'] == true) {
//         goHome.value = true;
//       }
//     });
//
//     socketService.on('customer-cancelled', (data) {
//       if (data != null && data['status'] == true) {
//         goHome.value = true;
//       }
//     });
//
//     socketService.on('driver-arrived', (data) {
//       CommonLogger.log.i('[SHARED PICK] driver-arrived : $data');
//     });
//
//     // Ensure driver-location listener gets attached after connect
//     socketService.onConnect(() {
//       CommonLogger.log.i("✅ [SHARED PICK] Socket connected");
//       socketService.on('driver-location', handleDriverLocation);
//     });
//
//     if (socketService.connected) {
//       socketService.on('driver-location', handleDriverLocation);
//     }
//
//     socketService.connect();
//   }
//
//   // ---------------------------------------------------------
//   // ROUTE CONTROLLER
//   // ---------------------------------------------------------
//   void _initRoute() {
//     _routeController = DriverRouteController(
//       destination: pickupLocation,
//       onRouteUpdate: _onRouteUpdateOptimized,
//       onCameraUpdate: (_) {},
//     );
//
//     _routeController.start();
//   }
//
//   void _onRouteUpdateOptimized(dynamic update) {
//     // Always keep driver location in sharedRideController for other screens
//     sharedRideController.updateDriverLocation(update.driverLocation);
//
//     final now = DateTime.now();
//     if (_lastRouteTick != null &&
//         now.difference(_lastRouteTick!).inMilliseconds < 300) {
//       return;
//     }
//     _lastRouteTick = now;
//
//     final LatLng newLoc = update.driverLocation;
//     final double newBearing = update.bearing;
//
//     final double moved = _lastDriverLocForUi == null
//         ? 999
//         : _haversineMeters(_lastDriverLocForUi!, newLoc);
//
//     final bool bearingChanged = (newBearing - _lastBearingForUi).abs() > 3.0;
//
//     if (moved < 2.0 && !bearingChanged) return;
//
//     _lastDriverLocForUi = newLoc;
//     _lastBearingForUi = newBearing;
//
//     List<LatLng> pts = (update.polylinePoints as List<LatLng>);
//     pts = _simplifyPolyline(pts, minStepMeters: 8, maxPoints: 180);
//
//     routeUi.value = RouteUiState(
//       driverLocation: newLoc,
//       bearing: newBearing,
//       polyline: pts,
//       directionText: (update.directionText ?? '').toString(),
//       distanceText: (update.distanceText ?? '').toString(),
//       maneuver: (update.maneuver ?? '').toString(),
//     );
//   }
//
//   // ---------------------------------------------------------
//   // RIDER ACTIONS (ALL LOGIC HERE)
//   // ---------------------------------------------------------
//
//   Future<void> selectRider(SharedRiderItem rider) async {
//     sharedRideController.activeTarget.value = rider;
//     await _routeController.updateDestination(rider.pickupLatLng);
//   }
//
//   void startNoShowTimerForAll() {
//     // ensures global timer runs and decrements all riders with secondsLeft>0
//     if (_globalTimer != null) return;
//
//     _globalTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
//       bool anyActive = false;
//
//       for (final r in sharedRideController.riders) {
//         if (r.secondsLeft > 0) {
//           r.secondsLeft--;
//           anyActive = true;
//         }
//       }
//
//       sharedRideController.riders.refresh();
//
//       if (!anyActive) {
//         timer.cancel();
//         _globalTimer = null;
//       }
//     });
//   }
//
//   void startNoShowTimer(SharedRiderItem rider) {
//     rider.secondsLeft = 300;
//     sharedRideController.riders.refresh();
//     startNoShowTimerForAll();
//   }
//
//   Future<bool> driverArrivedForRider(BuildContext context, SharedRiderItem rider) async {
//     final result = await driverStatusController.driverArrived(
//       context,
//       bookingId: rider.bookingId,
//     );
//
//     if (result != null && result.status == 200) {
//       rider.arrived = true;
//       sharedRideController.markArrived(rider.bookingId);
//       startNoShowTimer(rider);
//       return true;
//     }
//     return false;
//   }
//
//   Future<bool> requestOtpAndVerify({
//     required BuildContext context,
//     required SharedRiderItem rider,
//     required Future<bool?> Function() openVerifyScreen,
//   }) async {
//     final msg = await driverStatusController.otpRequest(
//       context,
//       bookingId: rider.bookingId,
//       custName: rider.name,
//       pickupAddress: rider.pickupAddress,
//       dropAddress: rider.dropoffAddress,
//     );
//
//     if (msg == null) return false;
//
//     final verified = await openVerifyScreen();
//     if (verified == true) {
//       sharedRideController.markOnboard(rider.bookingId);
//       return true;
//     }
//     return false;
//   }
//
//   // ---------------------------------------------------------
//   // HELPERS
//   // ---------------------------------------------------------
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
//   Future<void> _loadCarIcon() async {
//     try {
//       final icon = await _bitmapFromAsset(AppImages.movingCar, width: 74);
//       carIcon.value = icon;
//     } catch (_) {
//       carIcon.value = BitmapDescriptor.defaultMarker;
//     }
//   }
//
//   Future<BitmapDescriptor> _bitmapFromAsset(String path, {int width = 48}) async {
//     final data = await rootBundle.load(path);
//     final codec = await ui.instantiateImageCodec(
//       data.buffer.asUint8List(),
//       targetWidth: width,
//     );
//     final frame = await codec.getNextFrame();
//     final bytes = await frame.image.toByteData(format: ui.ImageByteFormat.png);
//     return BitmapDescriptor.fromBytes(bytes!.buffer.asUint8List());
//   }
//
//   List<LatLng> _simplifyPolyline(
//       List<LatLng> points, {
//         required double minStepMeters,
//         required int maxPoints,
//       }) {
//     if (points.length <= 2) return points;
//
//     final simplified = <LatLng>[points.first];
//     LatLng last = points.first;
//
//     for (int i = 1; i < points.length - 1; i++) {
//       final p = points[i];
//       if (_haversineMeters(last, p) >= minStepMeters) {
//         simplified.add(p);
//         last = p;
//         if (simplified.length >= maxPoints) break;
//       }
//     }
//
//     simplified.add(points.last);
//     return simplified;
//   }
//
//   double _haversineMeters(LatLng a, LatLng b) {
//     const r = 6371000.0;
//     final dLat = _degToRad(b.latitude - a.latitude);
//     final dLon = _degToRad(b.longitude - a.longitude);
//     final lat1 = _degToRad(a.latitude);
//     final lat2 = _degToRad(b.latitude);
//
//     final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
//         math.cos(lat1) * math.cos(lat2) *
//             math.sin(dLon / 2) * math.sin(dLon / 2);
//     return 2 * r * math.asin(math.sqrt(h));
//   }
//
//   double _degToRad(double d) => d * (math.pi / 180.0);
// }
