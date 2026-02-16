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
import 'package:hopper/api/repository/api_constents.dart';
import 'package:hopper/utils/map/route_info.dart';
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

  /// marker state (moving car)
  final Rxn<Marker> movingMarker = Rxn<Marker>();
  LatLng? _lastDriverPosition;

  final RxDouble currentBearing = 0.0.obs;
  final RxBool autoFollowEnabled = true.obs;

  Timer? _autoFollowTimer;

  /// polyline + nav banner
  final RxList<LatLng> polylinePoints = <LatLng>[].obs;
  final RxString directionText = ''.obs;
  final RxString distanceText = ''.obs;
  final RxString maneuver = ''.obs;

  /// UI state
  final RxBool driverCompletedRide = false.obs;

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
  static const double _HEADING_TRUST_MS = 2.0;
  static const double _MIN_TURN_DEG = 10.0;

  /// route refresh throttle (prevents too many API calls)
  DateTime _lastRouteRefresh = DateTime.fromMillisecondsSinceEpoch(0);

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
    _startLocationStream();
  }

  @override
  void onClose() {
    _positionStream?.cancel();
    _autoFollowTimer?.cancel();
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
      final cfg = const ImageConfiguration(size: Size(52, 52));
      final String asset =
          driverStatusController.serviceType.value == "Bike"
              ? AppImages.parcelBike
              : AppImages.movingCar;

      // You used BitmapDescriptor.asset(...) – keep same
      final icon = await BitmapDescriptor.asset(height: 60, cfg, asset);
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

    socketService.on('driver-reached-destination', (data) {
      final status = data?['status'];
      if (status == true || status?.toString() == 'true') {
        driverCompletedRide.value = true;
        CommonLogger.log.i('✅ Driver reached destination');
      }
    });

    socketService.on('driver-location', (data) {
      CommonLogger.log.i('driver-location : $data');
      if (data == null) return;
      final dropM = (data['dropDistanceInMeters'] ?? 0).toDouble();
      final dropMin = (data['dropDurationInMin'] ?? 0).toDouble();

      driverStatusController.dropDistanceInMeters.value = dropM;
      driverStatusController.dropDurationInMin.value = dropMin;
    });

    socketService.on('driver-cancelled', (data) {
      if (data?['status'] == true) Get.offAllNamed('/DriverMainScreen');
    });
    socketService.on('customer-cancelled', (data) {
      if (data?['status'] == true) Get.offAllNamed('/DriverMainScreen');
    });

    socketService.socket.onAny((event, data) {
      CommonLogger.log.i('📦 [socket] $event: $data');
    });

    if (!socketService.connected) {
      socketService.connect();
      socketService.onConnect(() => CommonLogger.log.i('🔌 Socket connected'));
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

      if (_lastDriverPosition == null) {
        _lastDriverPosition = current;
        _setMarkerImmediate(current, currentBearing.value);
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

      double targetBearing = currentBearing.value;

      if (speed >= _HEADING_TRUST_MS && heading >= 0) {
        targetBearing = heading;
      } else {
        targetBearing = _bearingBetween(_lastDriverPosition!, current);
      }

      final diff = _angleDeltaDeg(currentBearing.value, targetBearing);
      if (speed < _MIN_SPEED_MS && diff < _MIN_TURN_DEG) {
        targetBearing = currentBearing.value;
      }

      await animateMarkerTo(current, overrideBearing: targetBearing);

      _lastDriverPosition = current;

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
    final from = bookingFromLocation.value;
    final to = bookingToLocation.value;
    if (from == null || to == null) return;

    try {
      final result = await getRouteInfo(origin: from, destination: to);
      final pts = decodePolyline((result['polyline'] ?? '').toString());

      CommonLogger.log.i("✅ full route pts=${pts.length}");

      directionText.value = (result['direction'] ?? '').toString();
      distanceText.value = (result['distance'] ?? '').toString();
      maneuver.value = (result['maneuver'] ?? '').toString();
      polylinePoints.assignAll(pts);
    } catch (e) {
      CommonLogger.log.e("❌ loadFullRoute failed: $e");
    }
  }

  Future<void> refreshRouteFrom(LatLng from) async {
    final to = bookingToLocation.value;
    if (to == null) return;

    final result = await getRouteInfo(origin: from, destination: to);

    directionText.value = (result['direction'] ?? '').toString();
    distanceText.value = (result['distance'] ?? '').toString();
    maneuver.value = (result['maneuver'] ?? '').toString();
    polylinePoints.assignAll(decodePolyline(result['polyline']));
  }

  void _trimPolylineAlongProgress(LatLng current) {
    if (polylinePoints.isEmpty) return;

    final pts = polylinePoints.toList();
    final idx = _closestPointIndex(current, pts);
    if (idx <= 0) return;

    final keepFrom = (idx - 1).clamp(0, pts.length - 1);
    polylinePoints.assignAll(pts.sublist(keepFrom));
  }

  bool _isOffRoute(LatLng current) {
    const toleranceM = 25.0;
    for (final p in polylinePoints) {
      final d = Geolocator.distanceBetween(
        current.latitude,
        current.longitude,
        p.latitude,
        p.longitude,
      );
      if (d < toleranceM) return false;
    }
    return true;
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

  // ---------------- MARKER ANIMATION ----------------

  void _onMarkerAnimTick() {
    if (_latTween == null || _lngTween == null || _rotTween == null) return;

    final lat = _latTween!.transform(_curve.value);
    final lng = _lngTween!.transform(_curve.value);
    final bearing = _normalizeAngle(_rotTween!.transform(_curve.value));

    final pos = LatLng(lat, lng);

    movingMarker.value = Marker(
      markerId: const MarkerId("moving_car"),
      position: pos,
      icon: carIcon.value ?? BitmapDescriptor.defaultMarker,
      anchor: const Offset(0.5, 0.5),
      rotation: bearing,
      flat: true,
    );

    if (autoFollowEnabled.value && mapController != null) {
      mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: pos, zoom: 17, tilt: 50, bearing: bearing),
        ),
      );
    }
  }

  void _setMarkerImmediate(LatLng pos, double bearing) {
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

    final shortestEnd = _shortestAngle(startRot, endRot);
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
      currentBearing.value = _normalizeAngle(
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
    return _normalizeAngle(bearing);
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

  // ---------------- MAP UX ----------------

  void onUserMapMoveStarted() {
    autoFollowEnabled.value = false;
    _autoFollowTimer?.cancel();
    _autoFollowTimer = Timer(const Duration(seconds: 10), () {
      autoFollowEnabled.value = true;
    });
  }

  Future<void> goToCurrentLocation() async {
    final pos = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    final latLng = LatLng(pos.latitude, pos.longitude);
    mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: latLng,
          zoom: 17,
          tilt: 50,
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
    switch (m) {
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
}
