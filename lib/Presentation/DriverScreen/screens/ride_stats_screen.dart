import 'dart:async';
import 'dart:math' as math;

import 'package:action_slider/action_slider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:hopper/Core/Constants/Colors.dart';
import 'package:hopper/Core/Constants/log.dart';
import 'package:hopper/Core/Utility/Buttons.dart';
import 'package:hopper/Core/Utility/images.dart';
import 'package:hopper/Presentation/Authentication/widgets/textFields.dart';
import 'package:hopper/Presentation/DriverScreen/controller/driver_status_controller.dart';
import 'package:hopper/Presentation/DriverScreen/screens/driver_main_screen.dart';
import 'package:hopper/utils/map/google_map.dart';
import 'package:hopper/utils/map/route_info.dart';
import 'package:hopper/utils/netWorkHandling/network_handling_screen.dart';
import 'package:hopper/utils/sharedprefsHelper/local_data_store.dart';
import 'package:hopper/utils/websocket/socket_io_client.dart';

import 'cash_collected_screen.dart';

class RideStatsScreen extends StatefulWidget {
  final String bookingId;
  final String? pickupAddress;
  final String? dropAddress;

  const RideStatsScreen({
    super.key,
    required this.bookingId,
    this.pickupAddress,
    this.dropAddress,
  });

  @override
  State<RideStatsScreen> createState() => _RideStatsScreenState();
}

class _RideStatsScreenState extends State<RideStatsScreen>
    with SingleTickerProviderStateMixin {
  /// Map + positioning
  GoogleMapController? _mapController;
  LatLng origin = const LatLng(9.9303, 78.0945);
  LatLng destination = const LatLng(9.9342, 78.1824);
  LatLng? bookingFromLocation;
  LatLng? bookingToLocation;

  /// Marker + animation
  Marker? _movingMarker;
  LatLng? _lastDriverPosition;
  double _currentMapBearing = 0.0;
  double _carRotation = 0.0;

  late final AnimationController _markerController;
  late final Animation<double> _curve;
  // Tweens we reset each move
  Tween<double>? _latTween, _lngTween, _rotTween;

  /// Route/polyline
  List<LatLng> polylinePoints = [];
  String directionText = '';
  String distance = '';
  String maneuver = '';

  /// Icon
  BitmapDescriptor? carIcon;

  /// Streams & timers
  StreamSubscription<Position>? positionStream;
  Timer? _autoFollowTimer;
  bool _autoFollowEnabled = true;
  bool _userInteractingWithMap = false;

  /// App state
  final DriverStatusController driverStatusController = Get.put(
    DriverStatusController(),
  );
  late SocketService socketService;
  bool driverCompletedRide = false;

  /// Rider info
  String customerFrom = '';
  String customerTo = '';
  String driverName = '';
  String custName = '';
  String profilePic = '';
  dynamic Amount;
  @override
  void initState() {
    super.initState();

    // Smooth camera/marker animation controller
    _markerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _curve = CurvedAnimation(
      parent: _markerController,
      curve: Curves.easeInOut,
    );

    // Apply animated changes once per frame during an animation
    _markerController.addListener(() {
      if (!mounted ||
          _latTween == null ||
          _lngTween == null ||
          _rotTween == null)
        return;

      final lat = _latTween!.transform(_curve.value);
      final lng = _lngTween!.transform(_curve.value);
      final bearing = _normalizeAngle(_rotTween!.transform(_curve.value));

      final pos = LatLng(lat, lng);

      _movingMarker = Marker(
        markerId: const MarkerId("moving_car"),
        position: pos,
        icon: carIcon ?? BitmapDescriptor.defaultMarker,
        anchor: const Offset(0.5, 0.5),
        rotation: bearing,
        flat: true,
      );

      // Auto-follow camera like Uber/Ola
      if (_autoFollowEnabled && _mapController != null) {
        _mapController!.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(target: pos, zoom: 17, tilt: 50, bearing: bearing),
          ),
        );
      }

      setState(() {}); // update marker layer
    });

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );

    _loadMarkerIcons();
    _hydrateFromJoinedData();
    _wireSocketEvents();
    _startLocationStream();
  }

  @override
  void dispose() {
    positionStream?.cancel();
    _autoFollowTimer?.cancel();
    _markerController.dispose();
    try {
      // remove ONLY listeners; keep socket alive if singleton in app
      socketService.socket.off('driver-reached-destination');
      socketService.socket.off('driver-location');
      socketService.socket.off('driver-cancelled');
      socketService.socket.off('customer-cancelled');
      // socketService.socket.disconnect(); // uncomment only if this screen owns the socket
    } catch (_) {}
    super.dispose();
  }

  // ========== SETUP ==========

  // Future<void> _loadMarkerIcons() async {
  //   // Use fromAssetImage (correct API) for crisp icons
  //   final cfg = const ImageConfiguration(size: Size(37, 37));
  //   final asset =
  //       driverStatusController.serviceType.value == "Bike"
  //           ? AppImages.parcelBike
  //           : AppImages.movingCar;
  //
  //   try {
  //     carIcon = await BitmapDescriptor.fromAssetImage(cfg, asset);
  //     if (mounted) setState(() {});
  //   } catch (_) {
  //     carIcon = BitmapDescriptor.defaultMarker;
  //   }
  // }
  Future<void> _loadMarkerIcons() async {
    try {
      final cfg = const ImageConfiguration(size: Size(52, 52));
      final String asset =
          driverStatusController.serviceType.value == "Bike"
              ? AppImages.parcelBike
              : AppImages.movingCar;

      final icon = await BitmapDescriptor.asset(height: 60, cfg, asset);
      if (!mounted) return;
      setState(() {
        carIcon = icon;
      });
    } catch (e) {
      carIcon = BitmapDescriptor.defaultMarker;
    }
  }

  Future<void> _hydrateFromJoinedData() async {
    final joined = JoinedBookingData().getData();
    if (joined == null) return;

    final customerLoc = joined['customerLocation'];
    final amount = joined['amount'];
    final fromLat = (customerLoc['fromLatitude'] as num).toDouble();
    final fromLng = (customerLoc['fromLongitude'] as num).toDouble();
    final toLat = (customerLoc['toLatitude'] as num).toDouble();
    final toLng = (customerLoc['toLongitude'] as num).toDouble();

    bookingFromLocation = LatLng(fromLat, fromLng);
    bookingToLocation = LatLng(toLat, toLng);

    final fromAddr = await _reverseGeocode(fromLat, fromLng);
    final toAddr = await _reverseGeocode(toLat, toLng);

    driverName = (joined['driverName'] ?? '').toString();
    custName = (joined['customerName'] ?? '').toString();
    profilePic = (joined['customerProfilePic'] ?? '').toString();
    Amount = (joined['amount'] ?? '').toString();

    customerFrom = fromAddr;
    customerTo = toAddr;

    setState(() {});
    await _loadFullRoute(); // initial route
  }

  void _wireSocketEvents() {
    socketService = SocketService();

    socketService.on('driver-reached-destination', (data) {
      final status = data?['status'];
      if (status == true || status?.toString() == 'true') {
        if (!mounted) return;
        setState(() => driverCompletedRide = true);
        CommonLogger.log.i('✅ Driver reached destination');
      }
    });

    socketService.on('driver-location', (data) {
      if (data == null) return;
      final dropM = (data['dropDistanceInMeters'] ?? 0).toDouble();
      final dropMin = (data['dropDurationInMin'] ?? 0).toDouble();
      driverStatusController.dropDistanceInMeters.value = dropM;
      driverStatusController.dropDurationInMin.value = dropMin;
    });

    socketService.on('driver-cancelled', (data) {
      if (data?['status'] == true) Get.offAll(() => const DriverMainScreen());
    });
    socketService.on('customer-cancelled', (data) {
      if (data?['status'] == true) Get.offAll(() => const DriverMainScreen());
    });

    socketService.socket.onAny((event, data) {
      CommonLogger.log.i('📦 [socket] $event: $data');
    });

    if (!socketService.connected) {
      socketService.connect();
      socketService.onConnect(() => CommonLogger.log.i('🔌 Socket connected'));
    }
  }

  // --- motion thresholds to kill jitter ---
  static const double _MAX_ACCURACY_M = 20.0; // ignore noisy fixes
  static const double _MIN_MOVE_METERS =
      3.0; // must move ≥ 3 m to change bearing
  static const double _MIN_SPEED_MS = 1.0; // ~3.6 km/h
  static const double _HEADING_TRUST_MS =
      2.0; // use sensor heading only if ≥ 2 m/s
  static const double _MIN_TURN_DEG = 10.0; // ignore tiny turns when slow
  double _angleDeltaDeg(double a, double b) {
    double d = (b - a) % 360;
    if (d > 180) d -= 360;
    if (d < -180) d += 360;
    return d.abs();
  }

  void _startLocationStream() {
    positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 5, // little more filtering
      ),
    ).listen((Position position) async {
      final current = LatLng(position.latitude, position.longitude);
      final acc = (position.accuracy.isFinite) ? position.accuracy : 9999.0;
      final speed = (position.speed.isFinite) ? position.speed : 0.0; // m/s
      final heading =
          (position.heading.isFinite)
              ? position.heading
              : -1.0; // deg 0..360 or -1

      // 1) Ignore very inaccurate fixes
      if (acc > _MAX_ACCURACY_M) return;

      if (_lastDriverPosition == null) {
        _lastDriverPosition = current;
        origin = current;
        setState(() {});
        return;
      }

      // 2) How far did we move?
      final moved = Geolocator.distanceBetween(
        _lastDriverPosition!.latitude,
        _lastDriverPosition!.longitude,
        current.latitude,
        current.longitude,
      );

      final bool significantMove = moved >= _MIN_MOVE_METERS;

      // 3) Decide bearing update policy
      double targetBearing = _currentMapBearing;

      if (significantMove) {
        // Prefer device heading when actually moving fast enough
        if (speed >= _HEADING_TRUST_MS && heading >= 0) {
          targetBearing = heading;
        } else {
          // fallback: compute from path
          targetBearing = _bearingBetween(_lastDriverPosition!, current);
        }

        // If we're slow, ignore tiny turns to avoid twitch
        final diff = _angleDeltaDeg(_currentMapBearing, targetBearing);
        if (speed < _MIN_SPEED_MS && diff < _MIN_TURN_DEG) {
          targetBearing = _currentMapBearing; // keep old bearing
        }

        // 4) Animate marker (with decided bearing)
        await _animateMarkerTo(current, overrideBearing: targetBearing);

        origin = current;
        _lastDriverPosition = current;

        // 5) Route maintenance
        _trimPolylineAlongProgress(current);
        if (_isOffRoute(current)) {
          await _refreshRouteFrom(current);
        }
      } else {
        // Not a significant move: update position reference but DON'T rotate
        _lastDriverPosition = current;
        // Optionally, you could still animate a tiny nudge without rotation:
        // await _animateMarkerTo(current, overrideBearing: _currentMapBearing, allowTinyHop: true);
      }
    });

    // positionStream = Geolocator.getPositionStream(
    //   locationSettings: const LocationSettings(
    //     accuracy: LocationAccuracy.bestForNavigation,
    //     distanceFilter: 2, // smooth but not too chatty
    //   ),
    // ).listen((pos) async {
    //   final current = LatLng(pos.latitude, pos.longitude);
    //
    //   if (_lastDriverPosition == null) {
    //     _lastDriverPosition = current;
    //     origin = current;
    //     setState(() {});
    //     return;
    //   }
    //
    //   // Animate marker smoothly from last -> current
    //   await _animateMarkerTo(current);
    //
    //   origin = current;
    //   _lastDriverPosition = current;
    //
    //   // Trim polyline as we approach
    //   _trimPolylineAlongProgress(current);
    //
    //   // If off-route, refresh route from current to destination
    //   if (_isOffRoute(current)) {
    //     await _refreshRouteFrom(current);
    //   }
    // });
  }

  // ========== ROUTING HELPERS ==========

  Future<void> _loadFullRoute() async {
    if (bookingFromLocation == null || bookingToLocation == null) return;

    final result = await getRouteInfo(
      origin: bookingFromLocation!,
      destination: bookingToLocation!,
    );

    if (!mounted) return;
    setState(() {
      directionText = result['direction'];
      distance = result['distance'];
      maneuver = (result['maneuver'] ?? '').toString();
      polylinePoints = decodePolyline(result['polyline']);
    });
  }

  Future<void> _refreshRouteFrom(LatLng from) async {
    if (bookingToLocation == null) return;
    final result = await getRouteInfo(
      origin: from,
      destination: bookingToLocation!,
    );

    if (!mounted) return;
    setState(() {
      directionText = result['direction'];
      distance = result['distance'];
      maneuver = (result['maneuver'] ?? '').toString();
      polylinePoints = decodePolyline(result['polyline']);
    });
  }

  void _trimPolylineAlongProgress(LatLng current) {
    if (polylinePoints.isEmpty) return;

    int idx = _closestPointIndex(current, polylinePoints);
    if (idx <= 0) return;

    // Keep a little look-behind so we don't over-trim (optional)
    final keepFrom = (idx - 1).clamp(0, polylinePoints.length - 1);
    polylinePoints = polylinePoints.sublist(keepFrom);

    // Optional: refresh banner info (distance/next maneuver) on trim
    // (If your getRouteInfo is billed, you can throttle this)
  }

  bool _isOffRoute(LatLng current) {
    // If we are farther than 25m from any point on current polyline -> off route
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

  // ========== ANIMATION HELPERS ==========
  Future<void> _animateMarkerTo(
    LatLng newPos, {
    double? overrideBearing,
    bool allowTinyHop = false,
  }) async {
    if (_lastDriverPosition == null) return;

    final start = _lastDriverPosition!;
    final end = newPos;

    // If hop is very tiny and not allowed, skip
    final moved = Geolocator.distanceBetween(
      start.latitude,
      start.longitude,
      end.latitude,
      end.longitude,
    );
    if (!allowTinyHop && moved < _MIN_MOVE_METERS) return;

    final startRot = _currentMapBearing;
    final endRot = overrideBearing ?? _bearingBetween(start, end);

    // Build tweens
    _latTween = Tween<double>(begin: start.latitude, end: end.latitude);
    _lngTween = Tween<double>(begin: start.longitude, end: end.longitude);

    // rotate shortest path
    final shortestEnd = _shortestAngle(startRot, endRot);
    _rotTween = Tween<double>(begin: startRot, end: shortestEnd);

    _markerController
      ..removeStatusListener(_animStatusListener)
      ..reset()
      ..forward();

    _markerController.addStatusListener(_animStatusListener);
  }

  void _animStatusListener(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _currentMapBearing = _normalizeAngle(
        _rotTween?.end ?? _currentMapBearing,
      );
    }
  }

  /*  Future<void> _animateMarkerTo(LatLng newPos) async {
    if (_lastDriverPosition == null) return;

    final start = _lastDriverPosition!;
    final end = newPos;

    final startRot = _currentMapBearing;
    final endRot = _bearingBetween(start, end);

    // Build fresh tweens for this hop
    _latTween = Tween<double>(begin: start.latitude, end: end.latitude);
    _lngTween = Tween<double>(begin: start.longitude, end: end.longitude);
    _rotTween = Tween<double>(
      begin: startRot,
      end: _shortestAngle(startRot, endRot),
    );

    // run the animation (once)
    _markerController
      ..reset()
      ..forward();

    // update current bearing target after anim completes
    _markerController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _currentMapBearing = endRot;
      }
    });
  }*/

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

  // pick shortest rotation direction (e.g., 350° -> 10° goes +20°, not -340°)
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

  // ========== UI HELPERS ==========

  Future<String> _reverseGeocode(double lat, double lng) async {
    try {
      final pm = await placemarkFromCoordinates(lat, lng);
      final p = pm.first;
      return "${p.name}, ${p.locality}, ${p.administrativeArea}";
    } catch (_) {
      return "Location not available";
    }
  }

  String parseHtmlString(String htmlText) {
    return htmlText
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&');
  }

  String _maneuverAsset(String m) {
    switch (m) {
      case "turn-right":
        return "assets/images/right-turn.png";
      case "turn-left":
        return "assets/images/left-turn.png"; // fixed
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

  Future<void> _goToCurrentLocation() async {
    final pos = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    final latLng = LatLng(pos.latitude, pos.longitude);
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: latLng,
          zoom: 17,
          tilt: 50,
          bearing: _currentMapBearing,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final markers = <Marker>{
      if (_movingMarker != null)
        _movingMarker!
      else if (bookingFromLocation != null)
        Marker(
          markerId: const MarkerId('start'),
          position: bookingFromLocation!,
          icon: carIcon ?? BitmapDescriptor.defaultMarker,
          anchor: const Offset(0.5, 0.5),
          flat: true,
          rotation: _currentMapBearing,
        ),
      if (bookingToLocation != null)
        Marker(markerId: const MarkerId('end'), position: bookingToLocation!),
    };

    return NoInternetOverlay(
      child: WillPopScope(
        onWillPop: () async {
          return await false;
        },
        child: Scaffold(
          body: Stack(
            children: [
              SizedBox(
                height: 650,
                child: CommonGoogleMap(
                  onCameraMove: (pos) => _currentMapBearing = pos.bearing,
                  myLocationEnabled: false,
                  onCameraMoveStarted: () {
                    _userInteractingWithMap = true;
                    _autoFollowEnabled = false;
                    _autoFollowTimer?.cancel();
                    _autoFollowTimer = Timer(const Duration(seconds: 10), () {
                      _userInteractingWithMap = false;
                      _autoFollowEnabled = true;
                    });
                  },
                  onMapCreated: (controller) async {
                    _mapController = controller;
                    final style = await DefaultAssetBundle.of(
                      context,
                    ).loadString('assets/map_style/map_style1.json');
                    _mapController?.setMapStyle(style);

                    // Fit both ends initially
                    await Future.delayed(const Duration(milliseconds: 400));
                    if (bookingFromLocation != null &&
                        bookingToLocation != null) {
                      final sw = LatLng(
                        math.min(
                          bookingFromLocation!.latitude,
                          bookingToLocation!.latitude,
                        ),
                        math.min(
                          bookingFromLocation!.longitude,
                          bookingToLocation!.longitude,
                        ),
                      );
                      final ne = LatLng(
                        math.max(
                          bookingFromLocation!.latitude,
                          bookingToLocation!.latitude,
                        ),
                        math.max(
                          bookingFromLocation!.longitude,
                          bookingToLocation!.longitude,
                        ),
                      );
                      await _mapController!.animateCamera(
                        CameraUpdate.newLatLngBounds(
                          LatLngBounds(southwest: sw, northeast: ne),
                          100,
                        ),
                      );
                      final z = await _mapController!.getZoomLevel();
                      _mapController!.animateCamera(
                        CameraUpdate.zoomTo(z.clamp(12.0, 17.0)),
                      );
                    }
                  },
                  initialPosition: bookingFromLocation ?? const LatLng(0, 0),
                  markers: markers,
                  polylines: {
                    Polyline(
                      polylineId: const PolylineId("route"),
                      color: AppColors.commonBlack,
                      width: 4,
                      points: polylinePoints,
                    ),
                  },
                ),
              ),

              // My location button
              Positioned(
                top: driverCompletedRide ? 550 : 450,
                right: 10,
                child: FloatingActionButton(
                  mini: true,
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  onPressed: _goToCurrentLocation,
                  child: const Icon(Icons.my_location, color: Colors.black),
                ),
              ),

              // Direction header
              Positioned(
                top: 45,
                left: 10,
                right: 10,
                child: Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: Container(
                        height: 100,
                        color: AppColors.directionColor,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 20,
                            horizontal: 10,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Image.asset(
                                _maneuverAsset(maneuver),
                                height: 32,
                                width: 32,
                              ),
                              const SizedBox(height: 5),
                              CustomTextfield.textWithStyles600(
                                distance,
                                color: AppColors.commonWhite,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Container(
                        height: 100,
                        color: AppColors.directionColor1,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 20,
                            horizontal: 10,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CustomTextfield.textWithStyles600(
                                maxLine: 2,
                                parseHtmlString(directionText),
                                fontSize: 13,
                                color: AppColors.commonWhite,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Bottom sheet
              DraggableScrollableSheet(
                initialChildSize: driverCompletedRide ? 0.28 : 0.75,
                minChildSize: driverCompletedRide ? 0.25 : 0.40,
                maxChildSize: driverCompletedRide ? 0.30 : 0.75,
                builder: (context, scrollController) {
                  return Container(
                    color: Colors.white,
                    child: ListView(
                      controller: scrollController,
                      physics: const BouncingScrollPhysics(),
                      children: [
                        Center(
                          child: Container(
                            width: 60,
                            height: 5,
                            decoration: BoxDecoration(
                              color: Colors.grey[400],
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        if (!driverCompletedRide) ...[
                          GestureDetector(
                            onTap: () => Get.to(const CashCollectedScreen()),
                            child: Container(
                              color: AppColors.rideInProgress.withOpacity(0.1),
                              padding: const EdgeInsets.all(15),
                              child: Center(
                                child: CustomTextfield.textWithStyles600(
                                  fontSize: 14,
                                  color: AppColors.rideInProgress,
                                  'Ride in Progress',
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Obx(
                                () => CustomTextfield.textWithStyles600(
                                  _formatDuration(
                                    driverStatusController
                                        .dropDurationInMin
                                        .value,
                                  ),
                                  fontSize: 20,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Icon(
                                Icons.circle,
                                color: AppColors.drkGreen,
                                size: 10,
                              ),
                              const SizedBox(width: 10),
                              Obx(
                                () => CustomTextfield.textWithStyles600(
                                  _formatDistance(
                                    driverStatusController
                                        .dropDistanceInMeters
                                        .value,
                                  ),
                                  fontSize: 20,
                                ),
                              ),
                            ],
                          ),
                          Center(
                            child: CustomTextfield.textWithStylesSmall(
                              'Dropping off $custName',
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: _rideDetails(context),
                          ),
                        ] else ...[
                          Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.circle,
                                    color: AppColors.drkGreen,
                                    size: 13,
                                  ),
                                  SizedBox(width: 10),
                                  // You can bind real time-left here if needed
                                  Text(
                                    '1 min away',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              CustomTextfield.textWithStylesSmall(
                                fontWeight: FontWeight.w500,
                                'Dropping off $custName',
                              ),
                              const SizedBox(height: 5),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 10,
                                ),
                                child: ActionSlider.standard(
                                  height: 50,
                                  backgroundColor: AppColors.drkGreen,
                                  toggleColor: Colors.white,
                                  icon: Icon(
                                    Icons.double_arrow,
                                    color: AppColors.drkGreen,
                                    size: 28,
                                  ),
                                  child: const Text(
                                    'Complete Ride',
                                    style: TextStyle(
                                      color: AppColors.commonWhite,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  action: (controller) async {
                                    controller.loading();
                                    await Future.delayed(
                                      const Duration(milliseconds: 800),
                                    );
                                    final msg = await driverStatusController
                                        .completeRideRequest(
                                          context,
                                          Amount: Amount,
                                          bookingId: widget.bookingId,
                                        );
                                    if (msg != null) {
                                      controller.success();
                                    } else {
                                      controller.failure();
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Failed to complete ride',
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(height: 10),
                            ],
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ========== Small UI bits ==========

  Widget _rideDetails(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 15),
          child: Text(
            'Ride Details',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(40),
                color: AppColors.commonBlack.withOpacity(0.1),
              ),
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.circle, color: AppColors.grey, size: 10),
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CustomTextfield.textWithStyles600(
                    color: AppColors.commonBlack.withOpacity(0.5),
                    fontSize: 16,
                    'Pickup',
                  ),
                  CustomTextfield.textWithStylesSmall(
                    colors: AppColors.textColorGrey,
                    widget.pickupAddress ?? '',
                    maxLine: 2,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(40),
                color: AppColors.commonBlack.withOpacity(0.1),
              ),
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(
                  Icons.circle,
                  color: AppColors.commonBlack,
                  size: 10,
                ),
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CustomTextfield.textWithStyles600(
                    'Drop off - Constitution Ave',
                    fontSize: 16,
                  ),
                  CustomTextfield.textWithStylesSmall(
                    colors: AppColors.textColorGrey,
                    widget.dropAddress ?? '',
                    maxLine: 2,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        GestureDetector(
          onTap:
              () => setState(() => driverCompletedRide = !driverCompletedRide),
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.all(5),
                child: ClipOval(
                  child: CachedNetworkImage(
                    imageUrl: profilePic,
                    height: 45,
                    width: 45,
                    fit: BoxFit.cover,
                    placeholder:
                        (context, url) => const SizedBox(
                          height: 40,
                          width: 40,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    errorWidget:
                        (context, url, error) => const Icon(
                          Icons.person,
                          size: 30,
                          color: Colors.black,
                        ),
                  ),
                ),
              ),
              const SizedBox(width: 15),
              CustomTextfield.textWithStyles600(custName, fontSize: 20),
            ],
          ),
        ),
        const SizedBox(height: 15),
        Container(
          color: AppColors.containerColor1,
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              CustomTextfield.textWithImage(
                colors: AppColors.commonBlack,
                fontWeight: FontWeight.w500,
                fontSize: 12,
                text: 'Get Help',
                imagePath: AppImages.getHelp,
              ),
              const SizedBox(height: 20, child: VerticalDivider()),
              CustomTextfield.textWithImage(
                colors: AppColors.commonBlack,
                fontWeight: FontWeight.w500,
                fontSize: 12,
                text: 'Share Trip Status',
                imagePath: AppImages.share,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Buttons.button(
          borderColor: AppColors.buttonBorder,
          buttonColor: AppColors.commonWhite,
          borderRadius: 8,
          textColor: AppColors.commonBlack,
          onTap: () => Buttons.showDialogBox(context: context),
          text: const Text('Stop New Ride Request'),
        ),
        const SizedBox(height: 10),
        Buttons.button(
          borderRadius: 8,
          buttonColor: AppColors.red,
          onTap: () {
            Buttons.showCancelRideBottomSheet(
              context,
              onConfirmCancel: (reason) {
                driverStatusController.cancelBooking(
                  bookingId: widget.bookingId,
                  context,
                  reason: reason,
                );
              },
            );
          },
          text: const Text('Cancel this Ride'),
        ),
      ],
    );
  }

  String _formatDistance(double meters) {
    final km = meters / 1000.0;
    return '${km.toStringAsFixed(1)} Km';
    // If you prefer m under 1km:
    // return (meters < 950) ? '${meters.toStringAsFixed(0)} m' : '${km.toStringAsFixed(1)} Km';
  }

  String _formatDuration(double minutes) {
    final total = minutes.round();
    final h = total ~/ 60;
    final m = total % 60;
    return h > 0 ? '$h hr $m min' : '$m min';
  }
}

// import 'dart:async';
// import 'package:cached_network_image/cached_network_image.dart';
// import 'package:hopper/Presentation/DriverScreen/screens/driver_main_screen.dart';
// import 'package:http/http.dart' as http;
// import 'dart:ui' as ui;
//
// import 'dart:math' as math;
// import 'package:action_slider/action_slider.dart';
// import 'package:flutter/services.dart';
// import 'package:geocoding/geocoding.dart';
// import 'package:hopper/Presentation/DriverScreen/controller/driver_status_controller.dart';
// import 'package:hopper/utils/sharedprefsHelper/local_data_store.dart';
// import 'package:hopper/utils/websocket/socket_io_client.dart';
// import 'package:flutter/material.dart';
// import 'package:geolocator/geolocator.dart';
// import 'package:google_maps_flutter/google_maps_flutter.dart';
// import 'package:hopper/Core/Utility/images.dart';
// import 'package:hopper/Presentation/Authentication/widgets/textFields.dart';
// import '../../../Core/Constants/Colors.dart';
// import '../../../Core/Constants/log.dart';
// import '../../../Core/Utility/Buttons.dart';
// import '../../../utils/map/google_map.dart';
// import '../../../utils/map/route_info.dart';
// import '../../../utils/netWorkHandling/network_handling_screen.dart';
//
// import 'package:get/get.dart';
//
// import 'cash_collected_screen.dart';
//
// class RideStatsScreen extends StatefulWidget {
//   final String bookingId;
//   final String? pickupAddress;
//   final String? dropAddress;
//   const RideStatsScreen({
//     super.key,
//     required this.bookingId,
//     this.pickupAddress,
//     this.dropAddress,
//   });
//
//   @override
//   State<RideStatsScreen> createState() => _RideStatsScreenState();
// }
//
// class _RideStatsScreenState extends State<RideStatsScreen>
//     with SingleTickerProviderStateMixin {
//   LatLng origin = LatLng(9.9303, 78.0945);
//   LatLng destination = LatLng(9.9342, 78.1824);
//   GoogleMapController? _mapController;
//   final DriverStatusController driverStatusController = Get.put(
//     DriverStatusController(),
//   );
//   String customerFrom = '';
//   String customerTo = '';
//   Marker? _movingMarker;
//   LatLng? _lastDriverPosition;
//   double _currentMapBearing = 0.0;
//
//   late SocketService socketService;
//
//   bool driverCompletedRide = false;
//   String directionText = '';
//   String distance = '';
//   bool _cameraInitialized = false;
//
//   String driverName = '';
//   String custName = '';
//   String ProfilePic = '';
//   List<LatLng> polylinePoints = [];
//   StreamSubscription<Position>? positionStream;
//   LatLng? bookingFromLocation;
//   LatLng? bookingToLocation;
//   late BitmapDescriptor carIcon;
//   Timer? _autoFollowTimer;
//   bool _userInteractingWithMap = false;
//   bool _autoFollowEnabled = true;
//
//   /*  @override
//   void initState() {
//     super.initState();
//     Future.delayed(Duration(milliseconds: 100), () {
//       FocusManager.instance.primaryFocus?.unfocus();
//     });
//     SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
//     SystemChrome.setSystemUIOverlayStyle(
//       SystemUiOverlayStyle(
//         statusBarColor: Colors.transparent,
//         statusBarIconBrightness: Brightness.dark,
//       ),
//     );
//     driverReachedDestination();
//     positionStream = Geolocator.getPositionStream(
//       locationSettings: LocationSettings(
//         accuracy: LocationAccuracy.high,
//         distanceFilter: 5,
//       ),
//     ).listen((Position position) async {
//       final currentLatLng = LatLng(position.latitude, position.longitude);
//
//       animateMarker(currentLatLng);
//
//       setState(() {
//         origin = currentLatLng;
//       });
//
//       if (_autoFollowEnabled && _mapController != null) {
//         _mapController!.animateCamera(
//           CameraUpdate.newCameraPosition(
//             CameraPosition(
//               target: currentLatLng,
//               zoom: 16,
//               tilt: 0,
//               bearing: 0,
//             ),
//           ),
//         );
//       }
//
//       await updateRoute();
//     });
//
//     _initSocketAndLocation();
//     _loadMarkerIcons();
//     loadRoute();
//   }*/
//   CurvedAnimation? _curved;
//   late AnimationController _markerController;
//   @override
//   void initState() {
//     super.initState();
//     // init animation controller
//     _markerController = AnimationController(
//       vsync: this,
//       duration: const Duration(milliseconds: 800),
//     );
//     _curved = CurvedAnimation(
//       parent: _markerController,
//       curve: Curves.easeInOut,
//     );
//
//     SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
//     SystemChrome.setSystemUIOverlayStyle(
//       SystemUiOverlayStyle(
//         statusBarColor: Colors.transparent,
//         statusBarIconBrightness: Brightness.dark,
//       ),
//     );
//     driverReachedDestination();
//     _loadMarkerIcons();
//     _initSocketAndLocation();
//     loadRoute();
//
//     positionStream = Geolocator.getPositionStream(
//       locationSettings: LocationSettings(
//         accuracy: LocationAccuracy.high,
//         distanceFilter: 5,
//       ),
//     ).listen((Position position) async {
//       final currentLatLng = LatLng(position.latitude, position.longitude);
//
//       if (_lastDriverPosition == null) {
//         _lastDriverPosition = currentLatLng;
//         return;
//       }
//
//       final rotation = getRotation(_lastDriverPosition!, currentLatLng);
//
//       await animateMarker(currentLatLng);
//
//       setState(() {
//         origin = currentLatLng;
//         _currentMapBearing = rotation;
//       });
//
//       // 🎯 Animate map with rotation like Google Maps/Uber/Ola
//       if (_autoFollowEnabled && _mapController != null) {
//         final currentZoom = await _mapController!.getZoomLevel();
//         final safeZoom = currentZoom > 15 ? 15.0 : currentZoom;
//         _mapController!.animateCamera(
//           CameraUpdate.newCameraPosition(
//             CameraPosition(
//               target: currentLatLng,
//               zoom: safeZoom,
//               tilt: 50, // More tilt for 3D effect
//               bearing: rotation, // Rotate map with vehicle
//             ),
//           ),
//         );
//       }
//
//       _lastDriverPosition = currentLatLng;
//       await updateRoute();
//     });
//   }
//
//   String formatDistance(double meters) {
//     double kilometers = meters / 1000;
//     return '${kilometers.toStringAsFixed(1)} Km';
//   }
//
//   String formatDuration(int minutes) {
//     int hours = minutes ~/ 60;
//     int remainingMinutes = minutes % 60;
//     return hours > 0
//         ? '$hours hr $remainingMinutes min'
//         : '$remainingMinutes min';
//   }
//
//   Future<void> driverReachedDestination() async {
//     socketService = SocketService();
//     socketService.on('driver-reached-destination', (data) async {
//       final status = data['status'];
//       if (status == true || status.toString() == 'true') {
//         if (!mounted) return;
//         setState(() {
//           driverCompletedRide = true;
//         });
//
//         // arrivedAtPickup = false;
//         CommonLogger.log.i(
//           '🚦 driver-reached-destination updated to false $data',
//         );
//       }
//     });
//     socketService.on('driver-location', (data) async {
//       CommonLogger.log.i('driver-location : $data');
//
//       if (data != null) {
//         if (data['dropDistanceInMeters'] != null) {
//           driverStatusController.dropDistanceInMeters.value =
//               (data['dropDistanceInMeters'] ?? 0).toDouble();
//         }
//
//         if (data['dropDurationInMin'] != null) {
//           driverStatusController.dropDurationInMin.value =
//               (data['dropDurationInMin'] ?? 0).toDouble();
//         }
//       }
//     });
//     socketService.on('driver-cancelled', (data) async {
//       CommonLogger.log.i('driver-cancelled : $data');
//
//       if (data != null) {
//         if (data['status'] == true) {
//           Get.offAll(() => DriverMainScreen());
//         }
//       }
//     });
//     socketService.on('customer-cancelled', (data) async {
//       CommonLogger.log.i('customer-cancelled : $data');
//
//       if (data != null) {
//         if (data['status'] == true) {
//           Get.offAll(() => DriverMainScreen());
//         }
//       }
//     });
//     // Debug: See all events
//     socketService.socket.onAny((event, data) {
//       CommonLogger.log.i('📦 [onAny] $event: $data');
//     });
//
//     if (!socketService.connected) {
//       socketService.connect();
//       socketService.onConnect(() {
//         CommonLogger.log.i("✅ Socket connected");
//       });
//     } else {
//       CommonLogger.log.i("✅ Socket already connected");
//     }
//   }
//
//   double getRotation(LatLng start, LatLng end) {
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
//   double _carRotation = 0.0;
//
//   Future<void> animateMarker(LatLng newPosition) async {
//     if (_mapController == null || carIcon == null) return;
//     if (_lastDriverPosition == null) {
//       _lastDriverPosition = newPosition;
//       return;
//     }
//
//     final distanceMoved = Geolocator.distanceBetween(
//       _lastDriverPosition!.latitude,
//       _lastDriverPosition!.longitude,
//       newPosition.latitude,
//       newPosition.longitude,
//     );
//
//     if (distanceMoved < 0.5) return;
//
//     final newRotation = getRotation(_lastDriverPosition!, newPosition);
//
//     final oldPosition = _lastDriverPosition!;
//     final oldRotation = _currentMapBearing;
//
//     final positionTweenLat = Tween<double>(
//       begin: oldPosition.latitude,
//       end: newPosition.latitude,
//     );
//
//     final positionTweenLng = Tween<double>(
//       begin: oldPosition.longitude,
//       end: newPosition.longitude,
//     );
//
//     final rotationTween = Tween<double>(begin: oldRotation, end: newRotation);
//
//     _markerController.reset();
//     _markerController.forward();
//
//     _markerController.addListener(() {
//       if (!mounted) return;
//
//       final lat = positionTweenLat.evaluate(_markerController);
//       final lng = positionTweenLng.evaluate(_markerController);
//       final bearing = _lerpDouble(
//         oldRotation,
//         newRotation,
//         _markerController.value,
//       );
//
//       setState(() {
//         _movingMarker = Marker(
//           markerId: const MarkerId("moving_car"),
//           position: LatLng(lat, lng),
//           icon: carIcon,
//           anchor: const Offset(0.5, 0.5),
//           rotation: bearing,
//         );
//       });
//
//       if (_autoFollowEnabled && _mapController != null) {
//         _mapController!.animateCamera(
//           CameraUpdate.newCameraPosition(
//             CameraPosition(
//               target: LatLng(lat, lng),
//               zoom: 17,
//               tilt: 50,
//               bearing: bearing,
//             ),
//           ),
//         );
//       }
//     });
//
//     await _markerController.forward();
//
//     _lastDriverPosition = newPosition;
//     _currentMapBearing = newRotation;
//   }
//
//   double _lerp(double start, double end, double t) {
//     return start + (end - start) * t;
//   }
//
//   double _lerpDouble(double start, double end, double t) {
//     double difference = end - start;
//     if (difference.abs() > 180) {
//       if (end > start) {
//         start += 360;
//       } else {
//         end += 360;
//       }
//     }
//     return (start + (end - start) * t) % 360;
//   }
//
//   Future<void> _loadMarkerIcons() async {
//     if (driverStatusController.serviceType.value == "Car") {
//       carIcon = await BitmapDescriptor.asset(
//         const ImageConfiguration(size: Size(37, 37)),
//         AppImages.movingCar, // <-- your car icon asset
//       );
//     } else if (driverStatusController.serviceType.value == "Bike") {
//       carIcon = await BitmapDescriptor.asset(
//         const ImageConfiguration(size: Size(37, 37)),
//         AppImages.parcelBike, // <-- your bike icon asset
//       );
//     } else {
//       // Default marker if service type not matched
//       carIcon = BitmapDescriptor.defaultMarker;
//     }
//   }
//
//   Future<String> getAddressFromLatLng(double lat, double lng) async {
//     try {
//       List<Placemark> placemarks = await placemarkFromCoordinates(lat, lng);
//       Placemark place = placemarks[0];
//       return "${place.name}, ${place.locality}, ${place.administrativeArea}";
//     } catch (e) {
//       return "Location not available";
//     }
//   }
//
//   Future<void> _initSocketAndLocation() async {
//     final joinedData = JoinedBookingData().getData();
//
//     if (joinedData != null) {
//       final customerLoc = joinedData['customerLocation'];
//       final fromLat = customerLoc['fromLatitude'];
//       final fromLng = customerLoc['fromLongitude'];
//       final toLat = customerLoc['toLatitude'];
//       final toLng = customerLoc['toLongitude'];
//       final String driverFullName = joinedData['driverName'] ?? '';
//       final String customerProfilePic = joinedData['customerProfilePic'] ?? '';
//       final String customerName = joinedData['customerName'] ?? '';
//       final String customerPhone = joinedData['customerPhone'] ?? '';
//
//       bookingFromLocation = LatLng(fromLat, fromLng);
//       bookingToLocation = LatLng(toLat, toLng);
//
//       final fromAddress = await getAddressFromLatLng(fromLat, fromLng);
//       final toAddress = await getAddressFromLatLng(toLat, toLng);
//
//       setState(() {
//         customerFrom = fromAddress;
//         customerTo = toAddress;
//         driverName = '$driverFullName';
//         custName = customerName;
//         ProfilePic = customerProfilePic;
//       });
//     }
//   }
//
//   @override
//   void dispose() {
//     positionStream?.cancel();
//     _markerController.dispose();
//     _autoFollowTimer?.cancel();
//     super.dispose();
//   }
//
//   Future<void> updateRoute() async {
//     final result = await getRouteInfo(
//       origin: origin,
//       destination: bookingToLocation!,
//     );
//
//     setState(() {
//       directionText = result['direction'];
//       distance = result['distance'];
//       polylinePoints = decodePolyline(result['polyline']);
//     });
//   }
//
//   Future<void> loadRoute() async {
//     if (bookingFromLocation == null || bookingToLocation == null) return;
//
//     final result = await getRouteInfo(
//       origin: bookingFromLocation!,
//       destination: bookingToLocation!,
//     );
//
//     setState(() {
//       directionText = result['direction'];
//       distance = result['distance'];
//       polylinePoints = decodePolyline(result['polyline']);
//     });
//   }
//
//   String parseHtmlString(String htmlText) {
//     return htmlText
//         .replaceAll(RegExp(r'<[^>]*>'), '')
//         .replaceAll('&nbsp;', ' ')
//         .replaceAll('&amp;', '&');
//   }
//
//   String maneuver = '';
//   void _goToCurrentLocation() async {
//     Position position = await Geolocator.getCurrentPosition(
//       desiredAccuracy: LocationAccuracy.high,
//     );
//
//     final latLng = LatLng(position.latitude, position.longitude);
//
//     _mapController?.animateCamera(CameraUpdate.newLatLngZoom(latLng, 16));
//   }
//
//   String getManeuverIcon(maneuver) {
//     switch (maneuver) {
//       case "turn-right":
//         return "assets/images/right-turn.png";
//       case "turn-left":
//         return "assets/images/right-left.png";
//       case "straight":
//         return 'assets/images/straight.png';
//       case "merge":
//         return 'assets/images/straight.png';
//       case "roundabout-left":
//         return 'assets/images/straight.png';
//       case "roundabout-right":
//         return 'assets/images/straight.png';
//       default:
//         return 'assets/images/straight.png';
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return NoInternetOverlay(
//       child: Scaffold(
//         body: Stack(
//           children: [
//             SizedBox(
//               height: 650,
//               child: CommonGoogleMap(
//                 onCameraMove:
//                     (position) => _currentMapBearing = position.bearing,
//                 myLocationEnabled: false,
//                 onCameraMoveStarted: () {
//                   _userInteractingWithMap = true;
//                   _autoFollowEnabled = false;
//
//                   _autoFollowTimer?.cancel(); // cancel any existing timers
//
//                   // Start 10-second timer to re-enable auto-follow
//                   _autoFollowTimer = Timer(Duration(seconds: 10), () {
//                     _autoFollowEnabled = true;
//                     _userInteractingWithMap = false;
//                   });
//                 },
//
//                 // onMapCreated: () {
//                 //   String style = await DefaultAssetBundle.of(
//                 //     context,
//                 //   ).loadString('assets/map_style/map_style.json');
//                 //   _mapController!.setMapStyle(style);
//                 // },
//                 /*    onMapCreated: (controller) async {
//                   _mapController = controller;
//
//                   String style = await DefaultAssetBundle.of(
//                     context,
//                   ).loadString('assets/map_style/map_style1.json');
//                   _mapController!.setMapStyle(style);
//
//                   // Wait briefly to ensure map is ready
//                   await Future.delayed(const Duration(milliseconds: 600));
//
//                   // Fit bounds (auto zoom)
//                   LatLngBounds bounds = LatLngBounds(
//                     southwest: LatLng(
//                       origin.latitude < destination.latitude
//                           ? origin.latitude
//                           : destination.latitude,
//                       origin.longitude < destination.longitude
//                           ? origin.longitude
//                           : destination.longitude,
//                     ),
//                     northeast: LatLng(
//                       origin.latitude > destination.latitude
//                           ? origin.latitude
//                           : destination.latitude,
//                       origin.longitude > destination.longitude
//                           ? origin.longitude
//                           : destination.longitude,
//                     ),
//                   );
//                   _mapController!.animateCamera(
//                     CameraUpdate.newLatLngBounds(bounds, 60),
//                   );
//                 },*/
//                 onMapCreated: (controller) async {
//                   _mapController = controller;
//
//                   String style = await DefaultAssetBundle.of(
//                     context,
//                   ).loadString('assets/map_style/map_style1.json');
//                   _mapController!.setMapStyle(style);
//
//                   await Future.delayed(const Duration(milliseconds: 600));
//
//                   if (origin != null && destination != null) {
//                     LatLngBounds bounds = LatLngBounds(
//                       southwest: LatLng(
//                         origin.latitude < destination.latitude
//                             ? origin.latitude
//                             : destination.latitude,
//                         origin.longitude < destination.longitude
//                             ? origin.longitude
//                             : destination.longitude,
//                       ),
//                       northeast: LatLng(
//                         origin.latitude > destination.latitude
//                             ? origin.latitude
//                             : destination.latitude,
//                         origin.longitude > destination.longitude
//                             ? origin.longitude
//                             : destination.longitude,
//                       ),
//                     );
//
//                     await _mapController!.animateCamera(
//                       CameraUpdate.newLatLngBounds(bounds, 100),
//                     );
//
//                     // ✅ Clamp zoom between 12 (normal city view) and 17 (max detail)
//                     final zoomLevel = await _mapController!.getZoomLevel();
//                     double safeZoom = zoomLevel.clamp(12.0, 17.0);
//                     _mapController!.animateCamera(
//                       CameraUpdate.zoomTo(safeZoom),
//                     );
//                   }
//                 },
//
//                 // initialPosition: origin,
//                 // markers: {
//                 //   Marker(markerId: MarkerId('start'), position: origin),
//                 //   Marker(markerId: MarkerId('end'), position: destination),
//                 // },
//                 initialPosition: bookingFromLocation ?? LatLng(0, 0),
//                 markers: {
//                   if (_movingMarker != null)
//                     _movingMarker!
//                   else if (bookingFromLocation != null)
//                     Marker(
//                       markerId: MarkerId('start'),
//                       position: bookingFromLocation!,
//                       icon: carIcon,
//                     ),
//                   if (bookingToLocation != null)
//                     Marker(
//                       markerId: MarkerId('end'),
//                       position: bookingToLocation!,
//                     ),
//                 },
//
//                 polylines: {
//                   Polyline(
//                     polylineId: PolylineId("route"),
//                     color: AppColors.commonBlack,
//                     width: 4,
//                     points: polylinePoints,
//                   ),
//                 },
//               ),
//             ),
//
//             Positioned(
//               top: driverCompletedRide ? 550 : 450,
//               right: 10,
//               child: Column(
//                 children: [
//                   FloatingActionButton(
//                     mini: true,
//                     backgroundColor: Colors.white,
//                     shape: RoundedRectangleBorder(
//                       borderRadius: BorderRadius.circular(30),
//                     ),
//                     onPressed: _goToCurrentLocation,
//                     child: const Icon(Icons.my_location, color: Colors.black),
//                   ),
//                 ],
//               ),
//             ),
//
//             Positioned(
//               top: 45,
//               left: 10,
//               right: 10,
//               child: Row(
//                 children: [
//                   Expanded(
//                     flex: 1,
//                     child: Container(
//                       height: 100,
//
//                       color: AppColors.directionColor,
//                       child: Padding(
//                         padding: const EdgeInsets.symmetric(
//                           vertical: 20,
//                           horizontal: 10,
//                         ),
//                         child: Column(
//                           crossAxisAlignment: CrossAxisAlignment.center,
//                           children: [
//                             Image.asset(
//                               getManeuverIcon(maneuver),
//                               height: 32,
//                               width: 32,
//                             ),
//
//                             SizedBox(height: 5),
//                             CustomTextfield.textWithStyles600(
//                               distance,
//                               color: AppColors.commonWhite,
//                             ),
//                           ],
//                         ),
//                       ),
//                     ),
//                   ),
//                   Expanded(
//                     flex: 3,
//                     child: Container(
//                       height: 100,
//                       color: AppColors.directionColor1,
//                       child: Padding(
//                         padding: const EdgeInsets.symmetric(
//                           vertical: 20,
//                           horizontal: 10,
//                         ),
//                         child: Column(
//                           crossAxisAlignment: CrossAxisAlignment.center,
//                           children: [
//                             CustomTextfield.textWithStyles600(
//                               maxLine: 2,
//                               '${parseHtmlString(directionText)}',
//                               fontSize: 13,
//                               color: AppColors.commonWhite,
//                             ),
//                           ],
//                         ),
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//             DraggableScrollableSheet(
//               initialChildSize: driverCompletedRide ? 0.28 : 0.75,
//               minChildSize: driverCompletedRide ? 0.25 : 0.40,
//               maxChildSize:
//                   driverCompletedRide
//                       ? 0.30
//                       : 0.75, // Can expand up to 95% height
//               // initialChildSize:  0.80, // Start with 80% height
//               // minChildSize: 0.5, // Can collapse to 40%
//               // maxChildSize: 0.80, // Can expand up to 95% height
//               builder: (context, scrollController) {
//                 return Container(
//                   decoration: BoxDecoration(
//                     color: Colors.white,
//                     // borderRadius: BorderRadius.only(
//                     //   topLeft: Radius.circular(30),
//                     //   topRight: Radius.circular(30),
//                     // ),
//                   ),
//                   child: ListView(
//                     controller: scrollController,
//                     physics: BouncingScrollPhysics(),
//                     children: [
//                       Center(
//                         child: Container(
//                           width: 60,
//                           height: 5,
//
//                           decoration: BoxDecoration(
//                             color: Colors.grey[400],
//                             borderRadius: BorderRadius.circular(10),
//                           ),
//                         ),
//                       ),
//
//                       const SizedBox(height: 20),
//                       if (!driverCompletedRide) ...[
//                         GestureDetector(
//                           onTap: () {
//                             Get.to(CashCollectedScreen());
//                           },
//                           child: Container(
//                             decoration: BoxDecoration(
//                               color: AppColors.rideInProgress.withOpacity(0.1),
//                             ),
//                             child: Padding(
//                               padding: const EdgeInsets.all(15),
//                               child: Center(
//                                 child: CustomTextfield.textWithStyles600(
//                                   fontSize: 14,
//                                   color: AppColors.rideInProgress,
//                                   'Ride in Progress',
//                                 ),
//                               ),
//                             ),
//                           ),
//                         ),
//                         const SizedBox(height: 20),
//                         Row(
//                           mainAxisAlignment: MainAxisAlignment.center,
//                           children: [
//                             Obx(
//                               () => CustomTextfield.textWithStyles600(
//                                 formatDuration(
//                                   driverStatusController.dropDurationInMin.value
//                                       .toInt(), // ✅ FIXED
//                                 ),
//                                 fontSize: 20,
//                               ),
//                             ),
//                             const SizedBox(width: 10),
//                             Icon(
//                               Icons.circle,
//                               color: AppColors.drkGreen,
//                               size: 10,
//                             ),
//                             const SizedBox(width: 10),
//                             Obx(
//                               () => CustomTextfield.textWithStyles600(
//                                 formatDistance(
//                                   driverStatusController
//                                       .dropDistanceInMeters
//                                       .value,
//                                 ),
//                                 fontSize: 20,
//                               ),
//                             ),
//                           ],
//                         ),
//
//                         /*               Row(
//                           mainAxisAlignment: MainAxisAlignment.center,
//                           children: [
//                             CustomTextfield.textWithStyles600(
//                               '16 min',
//                               fontSize: 20,
//                             ),
//                             SizedBox(width: 10),
//                             Icon(
//                               Icons.circle,
//                               color: AppColors.drkGreen,
//                               size: 10,
//                             ),
//                             SizedBox(width: 10),
//                             CustomTextfield.textWithStyles600(
//                               '2.3 Km',
//                               fontSize: 20,
//                             ),
//                           ],
//                         ),*/
//                         Center(
//                           child: CustomTextfield.textWithStylesSmall(
//                             'Dropping off $custName',
//                           ),
//                         ),
//
//                         Padding(
//                           padding: const EdgeInsets.symmetric(horizontal: 20),
//                           child: Column(
//                             crossAxisAlignment: CrossAxisAlignment.start,
//                             children: [
//                               Padding(
//                                 padding: const EdgeInsets.symmetric(
//                                   horizontal: 15,
//                                 ),
//                                 child: CustomTextfield.textWithStyles600(
//                                   'Ride Details',
//                                   fontSize: 16,
//                                 ),
//                               ),
//                               const SizedBox(height: 20),
//                               Row(
//                                 children: [
//                                   Container(
//                                     decoration: BoxDecoration(
//                                       borderRadius: BorderRadius.circular(40),
//                                       color: AppColors.commonBlack.withOpacity(
//                                         0.1,
//                                       ),
//                                     ),
//                                     child: Padding(
//                                       padding: const EdgeInsets.all(4),
//                                       child: Icon(
//                                         Icons.circle,
//                                         color: AppColors.grey,
//                                         size: 10,
//                                       ),
//                                     ),
//                                   ),
//                                   SizedBox(width: 20),
//                                   Expanded(
//                                     child: Column(
//                                       crossAxisAlignment:
//                                           CrossAxisAlignment.start,
//                                       children: [
//                                         CustomTextfield.textWithStyles600(
//                                           color: AppColors.commonBlack
//                                               .withOpacity(0.5),
//                                           fontSize: 16,
//                                           'Pickup',
//                                         ),
//                                         CustomTextfield.textWithStylesSmall(
//                                           colors: AppColors.textColorGrey,
//                                           widget.pickupAddress ?? '',
//                                           maxLine: 2,
//                                         ),
//                                       ],
//                                     ),
//                                   ),
//                                 ],
//                               ),
//                               const SizedBox(height: 20),
//                               Row(
//                                 children: [
//                                   Container(
//                                     decoration: BoxDecoration(
//                                       borderRadius: BorderRadius.circular(40),
//                                       color: AppColors.commonBlack.withOpacity(
//                                         0.1,
//                                       ),
//                                     ),
//                                     child: Padding(
//                                       padding: const EdgeInsets.all(4),
//                                       child: Icon(
//                                         Icons.circle,
//                                         color: AppColors.commonBlack,
//                                         size: 10,
//                                       ),
//                                     ),
//                                   ),
//                                   SizedBox(width: 20),
//                                   Expanded(
//                                     child: Column(
//                                       crossAxisAlignment:
//                                           CrossAxisAlignment.start,
//                                       children: [
//                                         CustomTextfield.textWithStyles600(
//                                           fontSize: 16,
//                                           'Drop off - Constitution Ave',
//                                         ),
//                                         CustomTextfield.textWithStylesSmall(
//                                           colors: AppColors.textColorGrey,
//                                           widget.dropAddress ?? '',
//                                           maxLine: 2,
//                                         ),
//                                       ],
//                                     ),
//                                   ),
//                                 ],
//                               ),
//                               SizedBox(height: 20),
//                               GestureDetector(
//                                 onTap: () {
//                                   setState(() {
//                                     driverCompletedRide = !driverCompletedRide;
//                                   });
//                                 },
//                                 child: Row(
//                                   children: [
//                                     Padding(
//                                       padding: const EdgeInsets.all(5),
//                                       child: ClipOval(
//                                         child: CachedNetworkImage(
//                                           imageUrl: ProfilePic,
//                                           height:
//                                               45, // make it a bit bigger for clarity
//                                           width: 45,
//                                           fit: BoxFit.cover,
//                                           placeholder:
//                                               (context, url) => const SizedBox(
//                                                 height: 40,
//                                                 width: 40,
//                                                 child:
//                                                     CircularProgressIndicator(
//                                                       strokeWidth: 2,
//                                                     ),
//                                               ),
//                                           errorWidget:
//                                               (context, url, error) =>
//                                                   const Icon(
//                                                     Icons.person,
//                                                     size: 30,
//                                                     color: Colors.black,
//                                                   ),
//                                         ),
//                                       ),
//                                     ),
//                                     SizedBox(width: 15),
//                                     CustomTextfield.textWithStyles600(
//                                       custName,
//                                       fontSize: 20,
//                                     ),
//                                   ],
//                                 ),
//                               ),
//                               const SizedBox(height: 15),
//                               Container(
//                                 decoration: BoxDecoration(
//                                   color: AppColors.containerColor1,
//                                 ),
//                                 child: Padding(
//                                   padding: const EdgeInsets.symmetric(
//                                     horizontal: 30,
//                                     vertical: 10,
//                                   ),
//                                   child: Row(
//                                     mainAxisAlignment:
//                                         MainAxisAlignment.spaceBetween,
//                                     children: [
//                                       CustomTextfield.textWithImage(
//                                         colors: AppColors.commonBlack,
//                                         fontWeight: FontWeight.w500,
//                                         fontSize: 12,
//                                         text: 'Get Help',
//                                         imagePath: AppImages.getHelp,
//                                       ),
//                                       SizedBox(
//                                         height: 20,
//                                         child: VerticalDivider(),
//                                       ),
//                                       CustomTextfield.textWithImage(
//                                         colors: AppColors.commonBlack,
//                                         fontWeight: FontWeight.w500,
//                                         fontSize: 12,
//                                         text: 'Share Trip Status',
//                                         imagePath: AppImages.share,
//                                       ),
//                                     ],
//                                   ),
//                                 ),
//                               ),
//                               SizedBox(height: 20),
//                               Buttons.button(
//                                 borderColor: AppColors.buttonBorder,
//                                 buttonColor: AppColors.commonWhite,
//                                 borderRadius: 8,
//
//                                 textColor: AppColors.commonBlack,
//
//                                 onTap: () {
//                                   Buttons.showDialogBox(context: context);
//                                 },
//                                 text: Text('Stop New Ride Request'),
//                               ),
//                               SizedBox(height: 10),
//                               Buttons.button(
//                                 borderRadius: 8,
//
//                                 buttonColor: AppColors.red,
//
//                                 onTap: () {
//                                   Buttons.showCancelRideBottomSheet(
//                                     context,
//                                     onConfirmCancel: (reason) {
//                                       print("User selected reason: $reason");
//                                       driverStatusController.cancelBooking(
//                                         bookingId: widget.bookingId,
//                                         context,
//                                         reason: reason,
//                                       );
//                                     },
//                                   );
//                                   // Buttons.showCancelRideBottomSheet(
//                                   //   context,
//                                   //   onConfirmCancel: (reason) {},
//                                   // );
//                                 },
//                                 text: Text('Cancel this Ride'),
//                               ),
//                             ],
//                           ),
//                         ),
//                       ] else ...[
//                         Column(
//                           children: [
//                             Row(
//                               mainAxisAlignment: MainAxisAlignment.center,
//                               children: [
//                                 Icon(
//                                   Icons.circle,
//                                   color: AppColors.drkGreen,
//                                   size: 13,
//                                 ),
//                                 SizedBox(width: 10),
//                                 CustomTextfield.textWithStyles600(
//                                   '1 min away',
//                                   fontSize: 20,
//                                 ),
//                               ],
//                             ),
//                             const SizedBox(height: 10),
//                             CustomTextfield.textWithStylesSmall(
//                               fontWeight: FontWeight.w500,
//                               'Dropping off Rebecca',
//                             ),
//                             const SizedBox(height: 5),
//                             Padding(
//                               padding: const EdgeInsets.symmetric(
//                                 horizontal: 20,
//                                 vertical: 10,
//                               ),
//                               child: ActionSlider.standard(
//                                 action: (controller) async {
//                                   controller.loading();
//
//                                   await Future.delayed(
//                                     const Duration(seconds: 1),
//                                   );
//                                   final message = await driverStatusController
//                                       .completeRideRequest(
//                                         context,
//                                         bookingId: widget.bookingId,
//                                       );
//
//                                   if (message != null) {
//                                     controller.success();
//
//                                     // ScaffoldMessenger.of(context).showSnackBar(
//                                     //   SnackBar(content: Text(message)),
//                                     // );
//                                   } else {
//                                     controller.failure();
//                                     ScaffoldMessenger.of(context).showSnackBar(
//                                       const SnackBar(
//                                         content: Text('Failed to start ride'),
//                                       ),
//                                     );
//                                   }
//
//                                   await Future.delayed(
//                                     const Duration(milliseconds: 300),
//                                   );
//
//                                   // Navigate to the next screen
//                                   // Navigator.push(
//                                   //   context,
//                                   //   MaterialPageRoute(
//                                   //     builder:
//                                   //         (context) => CashCollectedScreen(),
//                                   //   ), // replace with your widget
//                                   // );
//                                 },
//
//                                 height: 50,
//                                 backgroundColor: AppColors.drkGreen,
//                                 toggleColor: Colors.white,
//                                 icon: Icon(
//                                   Icons.double_arrow,
//                                   color: AppColors.drkGreen,
//                                   size: 28,
//                                 ),
//                                 child: const Text(
//                                   'Complete Ride',
//                                   style: TextStyle(
//                                     color: AppColors.commonWhite,
//                                     fontSize: 20,
//                                     fontWeight: FontWeight.bold,
//                                   ),
//                                 ),
//                                 // action: (controller) async {
//                                 //   controller.loading();
//                                 //   await Future.delayed(
//                                 //     const Duration(seconds: 3),
//                                 //   );
//                                 //   controller.success();
//                                 // },
//                               ),
//                             ),
//                             const SizedBox(height: 10),
//                           ],
//                         ),
//                       ],
//                     ],
//                   ),
//                 );
//               },
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
