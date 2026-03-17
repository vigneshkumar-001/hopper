import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:hopper/Core/Constants/log.dart';
import 'package:hopper/Core/Utility/images.dart';
import 'package:hopper/Presentation/DriverScreen/controller/driver_status_controller.dart';
import 'package:hopper/api/repository/api_config_controller.dart';
import 'package:hopper/api/repository/api_constents.dart';
import 'package:hopper/utils/map/route_info.dart';
import 'package:hopper/utils/map/navigation_assist.dart';
import 'package:hopper/utils/map/navigation_voice_service.dart';
import 'package:hopper/utils/map/map_motion_profile.dart';
import 'package:hopper/utils/sharedprefsHelper/local_data_store.dart';
import 'package:hopper/utils/websocket/socket_io_client.dart';

class RideStatsController extends GetxController
    with GetSingleTickerProviderStateMixin {
  RideStatsController({
    required this.bookingId,
    this.pickupAddress,
    this.dropAddress,
  });

  final String bookingId;
  final String? pickupAddress;
  final String? dropAddress;

  /// ---- external controllers ----
  final DriverStatusController driverStatusController =
      Get.find<DriverStatusController>();

  late final SocketService socketService;

  /// ---- map state ----
  GoogleMapController? mapController;

  final Rxn<LatLng> bookingFromLocation = Rxn<LatLng>();
  final Rxn<LatLng> bookingToLocation = Rxn<LatLng>();
  final Rxn<LatLng> driverLocation = Rxn<LatLng>();

  /// marker state (moving car)
  final Rxn<Marker> movingMarker = Rxn<Marker>();
  LatLng? _lastDriverPosition;

  final RxDouble currentBearing = 0.0.obs;
  final RxBool autoFollowEnabled = true.obs;

  Timer? _autoFollowTimer;
  Timer? _routeRetryTimer;
  DateTime _lastCameraFollowAt = DateTime.fromMillisecondsSinceEpoch(0);
  bool _didInitialRouteFit = false;
  bool _isMapActive = false;

  /// polyline + nav banner
  final RxList<LatLng> polylinePoints = <LatLng>[].obs;
  final RxString directionText = ''.obs;
  final RxString distanceText = ''.obs;
  final RxString maneuver = ''.obs;
  List<LatLng> _cachedRoutePoints = <LatLng>[];
  String _cachedDirectionText = '';
  String _cachedDistanceText = '';
  String _cachedManeuver = '';

  /// UI state
  final RxBool driverCompletedRide = false.obs;
  final RxBool cancelLoading = false.obs;
  final RxBool isDriverFocused = false.obs;

  /// rider info
  final RxString customerFrom = ''.obs;
  final RxString customerTo = ''.obs;
  final RxString custName = ''.obs;
  final RxString profilePic = ''.obs;
  final RxString amount = ''.obs;

  /// icon
  final Rxn<BitmapDescriptor> carIcon = Rxn<BitmapDescriptor>();

  /// streams + animation
  StreamSubscription<Position>? _positionStream;

  late final AnimationController _markerController;
  late final Animation<double> _curve;

  Tween<double>? _latTween, _lngTween, _rotTween;

  /// thresholds (same as your code but stable)
  static const double _MAX_ACCURACY_M = 20.0;
  static const double _MIN_MOVE_METERS = 3.0;
  static const double _MIN_SPEED_MS = 1.0;
  static const double _STATIONARY_DRIFT_M = 8.0;
  static const double _HEADING_TRUST_MS = 2.0;
  static const double _MIN_TURN_DEG = 10.0;
  static const double _POLYLINE_TRIM_TOLERANCE_M = 30.0;
  static const int _POLYLINE_TRIM_LOOKAHEAD_POINTS = 40;
  static const int _OFF_ROUTE_LOOKAHEAD_POINTS = 80;

  /// route refresh throttle (prevents too many API calls)
  DateTime _lastRouteRefresh = DateTime.fromMillisecondsSinceEpoch(0);
  static const double _minFollowZoom = 12.8;
  static const double _maxFollowZoom = 14.4;
  double _followZoom = 14.0;

  double get followZoom => _followZoom;

  @override
  void onInit() {
    super.onInit();
    DirectionsConfig.apiKey = ApiConstents.googleMapApiKey;
    _markerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _curve = CurvedAnimation(
      parent: _markerController,
      curve: Curves.easeInOut,
    );

    _markerController.addListener(_onMarkerAnimTick);

    _loadMarkerIcons();
    _hydrateFromJoinedData();
    _wireSocketEvents();
    unawaited(_primeDriverLocationAndRoute());
    _startLocationStream();
  }

  @override
  void onClose() {
    _positionStream?.cancel();
    _autoFollowTimer?.cancel();
    _routeRetryTimer?.cancel();
    _isMapActive = false;
    try {
      mapController?.dispose();
    } catch (_) {}
    mapController = null;
    _markerController.dispose();

    try {
      socketService.socket.off('driver-reached-destination');
      socketService.socket.off('driver-location');
      socketService.socket.off('driver-cancelled');
      socketService.socket.off('customer-cancelled');
    } catch (_) {}

    super.onClose();
  }

  // ---------------- ICON ----------------

  Future<void> _loadMarkerIcons() async {
    try {
      final cfg = const ImageConfiguration(size: Size(42, 42));
      final String asset =
          driverStatusController.serviceType.value == "Bike"
              ? AppImages.parcelBike
              : AppImages.movingCar;
      final icon = await BitmapDescriptor.asset(height: 42, cfg, asset);
      carIcon.value = icon;
    } catch (_) {
      carIcon.value = BitmapDescriptor.defaultMarker;
    }
  }

  // ---------------- HYDRATE ----------------

  Future<void> _hydrateFromJoinedData() async {
    final joined = JoinedBookingData().getData();
    if (joined == null) return;

    try {
      final customerLoc = joined['customerLocation'];
      final fromLat = (customerLoc['fromLatitude'] as num).toDouble();
      final fromLng = (customerLoc['fromLongitude'] as num).toDouble();
      final toLat = (customerLoc['toLatitude'] as num).toDouble();
      final toLng = (customerLoc['toLongitude'] as num).toDouble();

      bookingFromLocation.value = LatLng(fromLat, fromLng);
      bookingToLocation.value = LatLng(toLat, toLng);

      custName.value = (joined['customerName'] ?? '').toString();
      profilePic.value = (joined['customerProfilePic'] ?? '').toString();
      amount.value = (joined['amount'] ?? '').toString();

      // reverse geocode (optional)
      customerFrom.value = await _reverseGeocode(fromLat, fromLng);
      customerTo.value = await _reverseGeocode(toLat, toLng);

      // initial route (from pickup->drop)
      await loadFullRoute();
    } catch (e) {
      CommonLogger.log.e("hydrate error: $e");
    }
  }

  Future<void> _primeDriverLocationAndRoute() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final current = LatLng(pos.latitude, pos.longitude);
      driverLocation.value = current;
      _lastDriverPosition ??= current;
      _setMarkerImmediate(current, currentBearing.value);
      _setDirectFallbackRoute(current);
      await refreshRouteFrom(current);
    } catch (_) {}
  }

  void _setDirectFallbackRoute(LatLng from) {
    final to = bookingToLocation.value;
    if (to == null) return;
    if (from.latitude == to.latitude && from.longitude == to.longitude) {
      polylinePoints.assignAll(<LatLng>[from]);
      return;
    }
    polylinePoints.assignAll(<LatLng>[from, to]);
  }

  void _restoreCachedRoute() {
    if (_cachedRoutePoints.length < 2) return;
    polylinePoints.assignAll(_cachedRoutePoints);
    directionText.value = _cachedDirectionText;
    distanceText.value = _cachedDistanceText;
    maneuver.value = _cachedManeuver;
  }

  void _ensureVisibleRoute(LatLng from) {
    if (_cachedRoutePoints.length >= 2) {
      _restoreCachedRoute();
      return;
    }
    _setDirectFallbackRoute(from);
  }

  void _scheduleRouteRetry(LatLng from) {
    _routeRetryTimer?.cancel();
    _routeRetryTimer = Timer(const Duration(seconds: 2), () {
      unawaited(refreshRouteFrom(from));
    });
  }

  bool _applyRouteResult(Map<String, dynamic> result) {
    final pts = decodePolyline((result['polyline'] ?? '').toString());
    final nextDirection = (result['direction'] ?? '').toString();
    final nextDistance = (result['distance'] ?? '').toString();
    final nextManeuver = (result['maneuver'] ?? '').toString();
    if (pts.length < 2) {
      return false;
    }
    directionText.value = nextDirection;
    distanceText.value = nextDistance;
    maneuver.value = nextManeuver;
    polylinePoints.assignAll(pts);
    _cachedRoutePoints = List<LatLng>.from(pts);
    _cachedDirectionText = nextDirection;
    _cachedDistanceText = nextDistance;
    _cachedManeuver = nextManeuver;
    final voice = NavigationAssist.buildVoiceLine(
      maneuver: maneuver.value,
      distanceText: distanceText.value,
      directionText: directionText.value,
    );
    NavigationVoiceService.instance.speakTurn(voice);
    return true;
  }

  Future<String> _reverseGeocode(double lat, double lng) async {
    try {
      final pm = await placemarkFromCoordinates(lat, lng);
      final p = pm.first;
      return "${p.name}, ${p.locality}, ${p.administrativeArea}";
    } catch (_) {
      return "Location not available";
    }
  }

  // ---------------- SOCKET ----------------

  void _wireSocketEvents() {
    socketService = SocketService();
    final cfg = Get.find<ApiConfigController>();
    socketService.initSocket(cfg.socketUrl);

    socketService.on('driver-reached-destination', (data) {
      final status = data?['status'];
      if (status == true || status?.toString() == 'true') {
        driverCompletedRide.value = true;
      }
    });

    socketService.on('driver-location', (data) {
      CommonLogger.log.i('driver-location : $data');
      if (data == null) return;
      final dropM = (data['dropDistanceInMeters'] ?? 0).toDouble();
      final dropMin = (data['dropDurationInMin'] ?? 0).toDouble();

      driverStatusController.dropDistanceInMeters.value = dropM;
      driverStatusController.dropDurationInMin.value = dropMin;
      Get.find<DriverAnalyticsController>().setSlaFromEtaMinutes(dropMin);
    });

    socketService.on('driver-cancelled', (data) {
      if (data?['status'] == true) Get.offAllNamed('/DriverMainScreen');
    });
    socketService.on('customer-cancelled', (data) {
      if (data?['status'] == true) {
        Get.find<DriverAnalyticsController>().trackCancel(
          bookingId: data?['bookingId']?.toString() ?? bookingId,
        );
        Get.offAllNamed('/DriverMainScreen');
      }
    });

    socketService.socket.onAny((event, data) {
      CommonLogger.log.i('Socket event: $event | data: $data');
    });

    if (!socketService.connected) {
      socketService.connect();
      socketService.onConnect(() => CommonLogger.log.i('Socket connected'));
    }
  }

  // ---------------- LOCATION STREAM ----------------

  void _startLocationStream() {
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 5,
      ),
    ).listen((Position position) async {
      final current = LatLng(position.latitude, position.longitude);

      final acc = (position.accuracy.isFinite) ? position.accuracy : 9999.0;
      final speed = (position.speed.isFinite) ? position.speed : 0.0;
      final heading = (position.heading.isFinite) ? position.heading : -1.0;

      if (acc > _MAX_ACCURACY_M) return;
      _updateSmartAutoZoom(speed);

      if (_lastDriverPosition == null) {
        _lastDriverPosition = current;
        driverLocation.value = current;
        _setMarkerImmediate(current, currentBearing.value);
        _setDirectFallbackRoute(current);
        await refreshRouteFrom(current);
        return;
      }

      final moved = Geolocator.distanceBetween(
        _lastDriverPosition!.latitude,
        _lastDriverPosition!.longitude,
        current.latitude,
        current.longitude,
      );

      final significantMove = moved >= _MIN_MOVE_METERS;
      if (!significantMove) {
        _lastDriverPosition = current; // update reference without rotating
        return;
      }

      if (MapMotionProfile.shouldFreezeTurn(
        speedMs: speed,
        movedMeters: moved,
      )) {
        _lastDriverPosition = current;
        return;
      }

      double targetBearing = currentBearing.value;

      if (speed < _MIN_SPEED_MS) {
        targetBearing = currentBearing.value;
      } else if (speed >= _HEADING_TRUST_MS && heading >= 0) {
        targetBearing = heading;
      } else {
        targetBearing = _bearingBetween(_lastDriverPosition!, current);
      }

      final diff = MapMotionProfile.angleDelta(
        currentBearing.value,
        targetBearing,
      );
      if (speed < _MIN_SPEED_MS && diff < _MIN_TURN_DEG) {
        targetBearing = currentBearing.value;
      }

      targetBearing = MapMotionProfile.smoothBearing(
        current: currentBearing.value,
        target: targetBearing,
        speedMs: speed,
      );

      await animateMarkerTo(current, overrideBearing: targetBearing);

      _lastDriverPosition = current;
      driverLocation.value = current;

      _trimPolylineAlongProgress(current);

      if (_isOffRoute(current)) {
        await _throttledRefreshRoute(current);
      }
    });
  }

  Future<void> _throttledRefreshRoute(LatLng from) async {
    final now = DateTime.now();
    if (now.difference(_lastRouteRefresh).inSeconds < 8) return;
    _lastRouteRefresh = now;
    await refreshRouteFrom(from);
  }

  // ---------------- ROUTES ----------------

  Future<void> loadFullRoute() async {
    final from =
        driverLocation.value ??
        _lastDriverPosition ??
        bookingFromLocation.value;
    final to = bookingToLocation.value;
    if (from == null || to == null) return;

    _ensureVisibleRoute(from);

    try {
      final result = await getRouteInfo(origin: from, destination: to);
      if (!_applyRouteResult(result)) {
        _ensureVisibleRoute(from);
        _scheduleRouteRetry(from);
      }
    } catch (e) {
      CommonLogger.log.e('loadFullRoute failed: $e');
      _ensureVisibleRoute(from);
      _scheduleRouteRetry(from);
    }
  }

  Future<void> refreshRouteFrom(LatLng from) async {
    final to = bookingToLocation.value;
    if (to == null) return;

    _ensureVisibleRoute(from);

    try {
      final result = await getRouteInfo(origin: from, destination: to);
      if (!_applyRouteResult(result)) {
        _ensureVisibleRoute(from);
        _scheduleRouteRetry(from);
      }
    } catch (e) {
      CommonLogger.log.e('refreshRouteFrom failed: $e');
      _ensureVisibleRoute(from);
      _scheduleRouteRetry(from);
    }
  }

  void _trimPolylineAlongProgress(LatLng current) {
    if (polylinePoints.isEmpty) return;

    final pts = polylinePoints.toList();
    final idx = _closestPointIndex(
      current,
      pts,
      limit: _POLYLINE_TRIM_LOOKAHEAD_POINTS,
    );
    if (idx <= 0) return;
    final bestDistance = _distanceToPoint(current, pts[idx]);
    if (bestDistance > _POLYLINE_TRIM_TOLERANCE_M) return;

    final keepFrom = (idx - 1).clamp(0, pts.length - 1);
    polylinePoints.assignAll(pts.sublist(keepFrom));
  }

  bool _isOffRoute(LatLng current) {
    const toleranceM = 25.0;
    final pts = polylinePoints;
    final searchLimit = math.min(pts.length, _OFF_ROUTE_LOOKAHEAD_POINTS);
    for (int i = 0; i < searchLimit; i++) {
      final d = _distanceToPoint(current, pts[i]);
      if (d < toleranceM) return false;
    }
    return true;
  }

  int _closestPointIndex(LatLng pos, List<LatLng> pts, {int? limit}) {
    double best = double.infinity;
    int idx = 0;
    final searchLimit =
        limit == null ? pts.length : math.min(pts.length, limit);
    for (int i = 0; i < searchLimit; i++) {
      final d = _distanceToPoint(pos, pts[i]);
      if (d < best) {
        best = d;
        idx = i;
      }
    }
    return idx;
  }

  double _distanceToPoint(LatLng from, LatLng to) {
    return Geolocator.distanceBetween(
      from.latitude,
      from.longitude,
      to.latitude,
      to.longitude,
    );
  }

  // ---------------- MARKER ANIMATION ----------------

  void _onMarkerAnimTick() {
    if (_latTween == null || _lngTween == null || _rotTween == null) return;

    final lat = _latTween!.transform(_curve.value);
    final lng = _lngTween!.transform(_curve.value);
    final bearing = MapMotionProfile.normalizeAngle(
      _rotTween!.transform(_curve.value),
    );

    final pos = LatLng(lat, lng);

    movingMarker.value = Marker(
      markerId: const MarkerId("moving_car"),
      position: pos,
      icon: carIcon.value ?? BitmapDescriptor.defaultMarker,
      anchor: const Offset(0.5, 0.5),
      rotation: bearing,
      flat: true,
    );

    if (autoFollowEnabled.value && mapController != null && _isMapActive) {
      final now = DateTime.now();
      if (now.difference(_lastCameraFollowAt).inMilliseconds >= 140) {
        _lastCameraFollowAt = now;
        unawaited(
          _safeMoveCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(
                target: pos,
                zoom: _followZoom.clamp(_minFollowZoom, _maxFollowZoom),
                tilt: 45,
                bearing: bearing,
              ),
            ),
          ),
        );
      }
    }
  }

  void _setMarkerImmediate(LatLng pos, double bearing) {
    driverLocation.value = pos;
    movingMarker.value = Marker(
      markerId: const MarkerId("moving_car"),
      position: pos,
      icon: carIcon.value ?? BitmapDescriptor.defaultMarker,
      anchor: const Offset(0.5, 0.5),
      rotation: bearing,
      flat: true,
    );
  }

  Future<void> animateMarkerTo(LatLng newPos, {double? overrideBearing}) async {
    if (_lastDriverPosition == null) return;

    final start = _lastDriverPosition!;
    final end = newPos;

    final startRot = currentBearing.value;
    final endRot = overrideBearing ?? _bearingBetween(start, end);

    _latTween = Tween<double>(begin: start.latitude, end: end.latitude);
    _lngTween = Tween<double>(begin: start.longitude, end: end.longitude);

    final shortestEnd = MapMotionProfile.shortestAngle(startRot, endRot);
    _rotTween = Tween<double>(begin: startRot, end: shortestEnd);

    _markerController
      ..stop()
      ..reset()
      ..forward();

    // update final bearing when completed
    _markerController.removeStatusListener(_onAnimStatus);
    _markerController.addStatusListener(_onAnimStatus);
  }

  void _onAnimStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      currentBearing.value = MapMotionProfile.normalizeAngle(
        _rotTween?.end ?? currentBearing.value,
      );
    }
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
    return MapMotionProfile.normalizeAngle(bearing);
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

  double _angleDeltaDeg(double a, double b) {
    double d = (b - a) % 360;
    if (d > 180) d -= 360;
    if (d < -180) d += 360;
    return d.abs();
  }

  void _updateSmartAutoZoom(double speedMs) {
    final targetZoom = MapMotionProfile.targetZoomFromSpeed(
      speedMs,
    ).clamp(_minFollowZoom, _maxFollowZoom);
    _followZoom = MapMotionProfile.smoothZoom(
      _followZoom,
      targetZoom,
    ).clamp(_minFollowZoom, _maxFollowZoom);
  }

  // ---------------- MAP UX ----------------
  Future<void> attachMap(GoogleMapController controller) async {
    mapController = controller;
    _isMapActive = true;
    _didInitialRouteFit = false;
    await Future<void>.delayed(const Duration(milliseconds: 250));
    await fitBoundsToRoute(force: true);
  }

  Future<void> fitBoundsToRoute({bool force = false}) async {
    final map = mapController;
    if (map == null || !_isMapActive) return;
    if (_didInitialRouteFit && !force) return;

    final route = polylinePoints.toList();
    final points = route.length >= 2 ? route : _fallbackBoundsPoints();
    if (points.length < 2) return;

    autoFollowEnabled.value = false;
    _autoFollowTimer?.cancel();

    final bounds = _safeBoundsFromPoints(points);

    try {
      await _safeAnimateCamera(CameraUpdate.newLatLngBounds(bounds, 95));
      if (!_isMapActive || mapController == null) return;
      final zoom = await map.getZoomLevel();
      if (zoom > 16.2) {
        await _safeAnimateCamera(CameraUpdate.zoomTo(16.2));
      }
    } catch (_) {
      final center = _centerOfPoints(points);
      final spread = _maxSpread(points);
      await _safeAnimateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: center, zoom: _boundsZoomForSpread(spread)),
        ),
      );
    } finally {
      _didInitialRouteFit = true;
      _autoFollowTimer = Timer(const Duration(seconds: 2), () {
        autoFollowEnabled.value = true;
      });
    }
  }

  void onUserMapMoveStarted() {
    autoFollowEnabled.value = false;
    _autoFollowTimer?.cancel();
    _autoFollowTimer = Timer(const Duration(seconds: 10), () {
      autoFollowEnabled.value = true;
    });
  }

  Future<void> _safeAnimateCamera(CameraUpdate update) async {
    final map = mapController;
    if (map == null || !_isMapActive) return;
    try {
      await map.animateCamera(update);
    } catch (_) {
      _isMapActive = false;
      mapController = null;
    }
  }

  Future<void> _safeMoveCamera(CameraUpdate update) async {
    final map = mapController;
    if (map == null || !_isMapActive) return;
    try {
      await map.moveCamera(update);
    } catch (_) {
      _isMapActive = false;
      mapController = null;
    }
  }

  Future<void> goToCurrentLocation() async {
    final pos = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    final latLng = LatLng(pos.latitude, pos.longitude);
    await _safeAnimateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: latLng,
          zoom: _followZoom.clamp(_minFollowZoom, _maxFollowZoom),
          tilt: 45,
          bearing: currentBearing.value,
        ),
      ),
    );
  }

  // ---------------- UI HELPERS ----------------

  String parseHtmlString(String htmlText) {
    return htmlText
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&');
  }

  String maneuverAsset(String m) {
    switch (NavigationAssist.iconForManeuver(m)) {
      case Icons.turn_right:
        return "assets/images/right-turn.png";
      case Icons.turn_left:
      case Icons.u_turn_left:
        return "assets/images/left-turn.png";
      case Icons.roundabout_right:
        return "assets/images/roundabout-right.png";
      default:
        return "assets/images/straight.png";
    }
  }

  String formatDistance(double meters) {
    final km = meters / 1000.0;
    return '${km.toStringAsFixed(1)} Km';
  }

  String formatDuration(double minutes) {
    final total = minutes.round();
    final h = total ~/ 60;
    final m = total % 60;
    return h > 0 ? '$h hr $m min' : '$m min';
  }

  List<LatLng> _fallbackBoundsPoints() {
    final from =
        driverLocation.value ??
        _lastDriverPosition ??
        bookingFromLocation.value;
    final to = bookingToLocation.value;
    if (from == null || to == null) return const <LatLng>[];
    return <LatLng>[from, to];
  }

  LatLngBounds _safeBoundsFromPoints(List<LatLng> points) {
    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final point in points) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
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

    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  LatLng _centerOfPoints(List<LatLng> points) {
    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final point in points) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    return LatLng((minLat + maxLat) / 2, (minLng + maxLng) / 2);
  }

  double _maxSpread(List<LatLng> points) {
    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final point in points) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    return math.max((maxLat - minLat).abs(), (maxLng - minLng).abs());
  }

  double _boundsZoomForSpread(double spread) {
    if (spread < 0.001) return 16.2;
    if (spread < 0.01) return 15.4;
    if (spread < 0.05) return 14.2;
    if (spread < 0.1) return 12.0;
    return 10.0;
  }
}
