import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:action_slider/action_slider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/services.dart';
import 'package:flutter_compass/flutter_compass.dart'; // (kept if you use it later)
import 'package:geocoding/geocoding.dart';
import 'package:hopper/Presentation/DriverScreen/screens/chat_screen.dart';
import 'package:hopper/Presentation/DriverScreen/screens/driver_main_screen.dart';
import 'package:hopper/Presentation/DriverScreen/screens/verify_rider_screen.dart';
import 'package:hopper/utils/sharedprefsHelper/local_data_store.dart';
import 'package:hopper/utils/websocket/socket_io_client.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:hopper/Core/Utility/images.dart';
import 'package:hopper/Presentation/Authentication/widgets/textFields.dart';
import '../../../Core/Constants/Colors.dart';
import '../../../Core/Constants/log.dart';
import '../../../Core/Utility/Buttons.dart';
import '../../../Core/Utility/app_loader.dart';
import '../../../utils/map/google_map.dart';
import '../../../utils/map/route_info.dart';
import '../../../utils/netWorkHandling/network_handling_screen.dart';
import '../controller/driver_status_controller.dart';
import 'package:get/get.dart';

class PickingCustomerScreen extends StatefulWidget {
  final LatLng pickupLocation;
  final String? pickupLocationAddress;
  final String? dropLocationAddress;
  final LatLng driverLocation;
  final String bookingId;

  const PickingCustomerScreen({
    Key? key,
    required this.pickupLocation,
    required this.driverLocation,
    required this.bookingId,
    this.pickupLocationAddress,
    this.dropLocationAddress,
  }) : super(key: key);

  @override
  State<PickingCustomerScreen> createState() => _PickingCustomerScreenState();
}

class _PickingCustomerScreenState extends State<PickingCustomerScreen> {
  late ActionSliderController _sliderController;
  LatLng? driverLocation;
  late SocketService socketService;
  LatLng? nextPoint;
  bool showArrivedButton = false;

  // Rider / meta (leave your naming as-is)
  String customerFrom = '';
  String CUSTOMERNAME = '';
  String CUSTOMERPHN = '';
  String DISTANCE = '';
  String DRIVERTIME = '';
  String RIDEDISTANCEINMETERS = '';
  String ESTIMATEDRIDETIMEINMIN = '';
  double carBearing = 0;
  double _currentMapBearing = 0.0;
  String PICKUPDISTANCEINMETERS = '';
  String PICKUPDURATIONINMIN = '';

  String customerTo = '';
  late LatLng driverCurrentLatLng;
  String profilePic = '';
  String custName = '';
  String plateNumber = '';
  String driverName = '';
  String cutomerProfile = '';
  dynamic Amount;
  String carDetails = '';
  bool isDriverConfirmed = false;
  String pickupAddress = '';
  String dropoffAddress = '';

  String driverProfilePic = '';
  List<String> carExteriorImages = [];
  LatLng? lastPosition;
  bool isAnimating = false;
  Marker? _carMarker;
  GoogleMapController? _mapController;
  bool driverReached = false;
  bool arrivedAtPickup = true;
  final DriverStatusController driverStatusController = Get.put(
    DriverStatusController(),
  );

  String directionText = '';
  BitmapDescriptor? carIcon;
  String distance = '';
  List<LatLng> polylinePoints = [];
  StreamSubscription<Position>? positionStream;
  int _seconds = 300;
  Timer? _timer;

  bool showRedTimer = false;
  Future<BitmapDescriptor> _bitmapFromAsset(
    String path, {
    int width = 48,
  }) async {
    final data = await rootBundle.load(path);
    final codec = await ui.instantiateImageCodec(
      data.buffer.asUint8List(),
      targetWidth: width, // <- control size here
    );
    final frame = await codec.getNextFrame();
    final bytes = await frame.image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.fromBytes(bytes!.buffer.asUint8List());
  }

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

  void _startTimer() {
    _timer?.cancel();
    _seconds = 300;
    showRedTimer = false;

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_seconds > 0) {
        setState(() {
          _seconds--;
          showRedTimer = _seconds <= 10;
        });
      } else {
        timer.cancel();
      }
    });
  }

  String get timerText {
    final m = (_seconds ~/ 60).toString().padLeft(2, '0');
    final s = (_seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String formatDistance(double meters) {
    double kilometers = meters / 1000;
    return '${kilometers.toStringAsFixed(1)} km';
  }

  String formatDuration(double minutes) {
    int totalMinutes = minutes.round();
    int hours = totalMinutes ~/ 60;
    int remainingMinutes = totalMinutes % 60;

    if (hours > 0) {
      return '$hours hr $remainingMinutes min';
    } else {
      return '$remainingMinutes min';
    }
  }

  Future<String> getAddressFromLatLng(double lat, double lng) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(lat, lng);
      Placemark place = placemarks[0];
      return "${place.name}, ${place.locality}, ${place.administrativeArea}";
    } catch (e) {
      return "Location not available";
    }
  }

  Future<void> _initSocketAndLocation() async {
    socketService = SocketService();

    socketService.on('joined-booking', (data) async {
      if (!mounted) return;
      JoinedBookingData().setData(data);
      CommonLogger.log.i("🚕 Joined booking data: $data");

      // Extract driver & vehicle details
      final vehicle = data['vehicle'] ?? {};
      final String driverFullName = data['driverName'] ?? '';
      final String color = vehicle['color'] ?? '';
      final String model = vehicle['model'] ?? '';
      final String customerName = data['customerName'] ?? '';
      final amount = data['amount'] ?? '';
      final String customerProfilePic = data['customerProfilePic'] ?? '';
      final String customerPhone = data['customerPhone'] ?? '';
      final bool driverAccepted = data['driver_accept_status'] == true;
      final customerLoc = data['customerLocation'];

      double fromLat = customerLoc['fromLatitude'];
      double fromLng = customerLoc['fromLongitude'];
      double toLat = customerLoc['toLatitude'];
      double toLng = customerLoc['toLongitude'];

      final LatLng customerFromLatLng = LatLng(fromLat, fromLng);
      final LatLng customerToLatLng = LatLng(toLat, toLng);

      final driverLocationObj = data['driverLocation'];
      final LatLng driverLatLng = LatLng(
        driverLocationObj['latitude'],
        driverLocationObj['longitude'],
      );

      // profile & car photos
      final String picUrl = data['profilePic'] ?? '';
      // final List<dynamic> carPhotos = List.from(
      //   data['carExteriorPhotos'] ?? [],
      // );

      String pickupAddrs = await getAddressFromLatLng(fromLat, fromLng);
      String dropoffAddrs = await getAddressFromLatLng(toLat, toLng);

      if (!mounted) return;
      setState(() {
        plateNumber = vehicle['plateNumber'] ?? '';
        driverName = driverFullName;
        carDetails = '$color - ${vehicle['type'] ?? ''} $model';
        isDriverConfirmed = driverAccepted;

        pickupAddress = pickupAddrs;
        customerFrom = pickupAddrs;
        customerTo = dropoffAddrs;

        CUSTOMERNAME = customerName;
        CUSTOMERPHN = customerPhone;
        cutomerProfile = customerProfilePic;
        Amount = amount;

        driverCurrentLatLng = driverLatLng;
        driverProfilePic = picUrl;
        // carExteriorImages = carPhotos.map((e) => e.toString()).toList();
      });

      CommonLogger.log.i("🚕 Driver confirmed: $driverAccepted");
      CommonLogger.log.i("🚕 Driver name: $driverFullName");
      CommonLogger.log.i("🚕 Plate number: ${vehicle['plateNumber']}");
    });

    socketService.socket.onAny((event, data) {
      CommonLogger.log.i('📦 [onAny] $event: $data');
    });

    socketService.on('driver-location', (data) async {
      CommonLogger.log.i('driver-location : $data');

      if (data != null) {
        if (data['pickupDistanceInMeters'] != null) {
          driverStatusController.pickupDistanceInMeters.value =
              (data['pickupDistanceInMeters'] as num).toDouble();
        }
        if (data['pickupDurationInMin'] != null) {
          driverStatusController.pickupDurationInMin.value =
              (data['pickupDurationInMin'] as num).toDouble();
        }
      }
    });

    socketService.on('driver-cancelled', (data) async {
      CommonLogger.log.i('driver-cancelled : $data');
      if (data != null && data['status'] == true) {
        if (!mounted) return;
        Get.offAll(() => DriverMainScreen());
      }
    });

    socketService.on('customer-cancelled', (data) async {
      CommonLogger.log.i('customer-cancelled : $data');
      if (data != null && data['status'] == true) {
        if (!mounted) return;
        Get.offAll(() => DriverMainScreen());
      }
    });

    socketService.on('driver-arrived', (data) {
      final status = data['status'];
      if (status == true || status.toString() == 'true') {
        if (!mounted) return;
        setState(() {
          driverReached = true;
        });
        CommonLogger.log.i('🚦 arrivedAtPickup updated to false');
      }
      CommonLogger.log.i('🚗 Driver arrived: $data');
    });

    if (!socketService.connected) {
      socketService.connect();
      socketService.onConnect(() {
        CommonLogger.log.i("✅ Socket connected");
      });
    } else {
      CommonLogger.log.i("✅ Socket already connected");
    }
  }

  @override
  void initState() {
    super.initState();
    _sliderController = ActionSliderController();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );
    _initSocketAndLocation();
    _loadMarkerIcons();
    _getInitialDriverLocation();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sliderController.reset();
  }

  @override
  void dispose() {
    positionStream?.cancel();
    _timer?.cancel();

    try {
      // use the underlying IO.Socket
      socketService.socket.off('joined-booking');
      socketService.socket.off('driver-location');
      socketService.socket.off('driver-cancelled');
      socketService.socket.off('customer-cancelled');
      socketService.socket.off('driver-arrived');

      // Only disconnect if this screen owns the socket
      // If the socket is a global singleton used by the whole app, comment this out.
      // socketService.socket.disconnect();
    } catch (_) {}

    _mapController = null;
    _sliderController.dispose();
    super.dispose();
  }

  Future<void> _getInitialDriverLocation() async {
    final hasPermission = await _ensureLocationPermission();
    if (!hasPermission) return;

    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    driverLocation = LatLng(position.latitude, position.longitude);

    final result = await getRouteInfo(
      origin: driverLocation!,
      destination: widget.pickupLocation,
    );

    if (!mounted) return;
    setState(() {
      directionText = result['direction'];
      distance = result['distance'];
      polylinePoints = decodePolyline(result['polyline']);
      maneuver = result['maneuver'] ?? '';
      if (polylinePoints.length >= 2) {
        nextPoint = polylinePoints[1];
      } else if (polylinePoints.length == 1) {
        nextPoint = polylinePoints[0];
      }
    });

    _startDriverTracking();
  }

  Future<bool> _ensureLocationPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  Future<void> loadRoute() async {
    if (driverLocation == null) return;
    final result = await getRouteInfo(
      origin: driverLocation!,
      destination: widget.pickupLocation,
    );

    if (!mounted) return;
    setState(() {
      directionText = result['direction'];
      distance = result['distance'];
      maneuver = result['maneuver'] ?? '';
      polylinePoints = decodePolyline(result['polyline']);
      if (polylinePoints.length >= 2) {
        nextPoint = polylinePoints[1];
      } else if (polylinePoints.length == 1) {
        nextPoint = polylinePoints[0];
      }
    });
  }

  Future<void> _fetchRoute() async {
    if (driverLocation == null) return;

    final result = await getRouteInfo(
      origin: driverLocation!, // driver
      destination: widget.pickupLocation, // customer
    );

    if (!mounted) return;
    setState(() {
      polylinePoints = decodePolyline(result['polyline']);
      directionText = result['direction'];
      distance = result['distance'];
      maneuver = result['maneuver'] ?? '';
      if (polylinePoints.length >= 2) {
        nextPoint = polylinePoints[1];
      } else if (polylinePoints.length == 1) {
        nextPoint = polylinePoints[0];
      }
    });
  }

  // --- motion thresholds to tame jitter ---
  static const double _MAX_ACCURACY_M = 20.0; // ignore noisy GPS fixes
  static const double _MIN_MOVE_METERS = 3.0; // need ≥3 m movement to rotate
  static const double _MIN_SPEED_MS = 1.0; // ~3.6 km/h
  static const double _HEADING_TRUST_MS =
      2.0; // only trust device heading if ≥2 m/s
  static const double _MIN_TURN_DEG = 10.0; // ignore tiny turns when slow

  void _startDriverTracking() {
    positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 3, // a tad higher filtering
      ),
    ).listen((position) async {
      if (!mounted) return;

      final current = LatLng(position.latitude, position.longitude);
      final acc = (position.accuracy.isFinite) ? position.accuracy : 9999.0;
      final speed = (position.speed.isFinite) ? position.speed : 0.0; // m/s
      final heading =
          (position.heading.isFinite)
              ? position.heading
              : -1.0; // deg 0..360 or -1

      // 1) ignore very inaccurate fixes
      if (acc > _MAX_ACCURACY_M) return;

      if (lastPosition == null) {
        lastPosition = current;
        driverLocation = current;
        setState(() {});
        return;
      }

      // 2) did we move enough to consider rotation?
      final moved = Geolocator.distanceBetween(
        lastPosition!.latitude,
        lastPosition!.longitude,
        current.latitude,
        current.longitude,
      );
      final significantMove = moved >= _MIN_MOVE_METERS;

      // 3) decide target bearing (only if significant move)
      double targetBearing = carBearing;

      if (significantMove) {
        if (speed >= _HEADING_TRUST_MS && heading >= 0) {
          // moving at a real speed -> trust fused heading
          targetBearing = heading;
        } else {
          // fallback based on path
          targetBearing = _getBearing(lastPosition!, current);
        }

        // when slow, ignore tiny bearing changes
        final diff = _angleDeltaDeg(carBearing, targetBearing);
        if (speed < _MIN_SPEED_MS && diff < _MIN_TURN_DEG) {
          targetBearing = carBearing;
        }

        // 4) animate car to new position with chosen bearing
        await _animateCarTo(current, overrideBearing: targetBearing);

        // 5) update references
        lastPosition = current;
        driverLocation = current;

        // 6) maintain polyline + reroute if off-route
        _updateRemainingPolyline(current);
        if (isOffRoute(current)) {
          await _fetchUpdatedRoute(current);
        }
      } else {
        // not a significant move: update lastPosition, but don't rotate
        lastPosition = current;
        driverLocation = current;
      }
    });
  }

  Future<void> _fetchUpdatedRoute(LatLng currentLocation) async {
    final result = await getRouteInfo(
      origin: currentLocation,
      destination: widget.pickupLocation,
    );

    if (!mounted) return;
    setState(() {
      polylinePoints = decodePolyline(result['polyline']);
      directionText = result['direction'];
      distance = result['distance'];
      maneuver = result['maneuver'] ?? '';
      if (polylinePoints.length >= 2) {
        nextPoint = polylinePoints[1];
      } else if (polylinePoints.length == 1) {
        nextPoint = polylinePoints[0];
      }
    });
  }

  bool _isSameLocation(LatLng a, LatLng b) {
    return (a.latitude - b.latitude).abs() < 0.00001 &&
        (a.longitude - b.longitude).abs() < 0.00001;
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
    return from + diff; // returns a target near 'from' taking the shortest path
  }

  double _normalizeAngle(double a) {
    a %= 360;
    if (a < 0) a += 360;
    return a;
  }

  Future<void> _animateCarTo(LatLng to, {double? overrideBearing}) async {
    if (driverLocation == null || _isSameLocation(driverLocation!, to)) return;

    isAnimating = true;

    final start = driverLocation!;
    final end = to;

    final startBearing = carBearing;
    final endBearingRaw =
        (overrideBearing != null) ? overrideBearing : _getBearing(start, end);
    final endBearing = _shortestAngle(startBearing, endBearingRaw);

    const steps = 30;
    const duration = Duration(milliseconds: 800);
    final interval = duration.inMilliseconds ~/ steps;

    for (int i = 1; i <= steps; i++) {
      await Future.delayed(Duration(milliseconds: interval));
      if (!mounted) return;

      final t = i / steps;
      final lat = _lerp(start.latitude, end.latitude, t);
      final lng = _lerp(start.longitude, end.longitude, t);
      final newBearing = _lerpBearing(startBearing, endBearing, t);

      setState(() {
        driverLocation = LatLng(lat, lng);
        carBearing = _normalizeAngle(newBearing);
      });

      _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: driverLocation!,
            zoom: 17,
            bearing: carBearing,
            tilt: 60,
          ),
        ),
      );
    }

    isAnimating = false;
  }

  double _lerp(double start, double end, double t) => start + (end - start) * t;

  double _lerpBearing(double start, double end, double t) {
    double difference = ((end - start + 540) % 360) - 180;
    return (start + difference * t + 360) % 360;
  }

  void _updateRemainingPolyline(LatLng currentLocation) async {
    if (polylinePoints.isEmpty) return;

    int closestIndex = _getClosestPolylinePointIndex(currentLocation);
    if (closestIndex != -1 && closestIndex < polylinePoints.length) {
      // ✅ Trim ONCE (bug fix: you had this twice)
      polylinePoints = polylinePoints.sublist(closestIndex);

      if (polylinePoints.length >= 2) {
        nextPoint = polylinePoints[1];

        final result = await getRouteInfo(
          origin: currentLocation,
          destination: widget.pickupLocation,
        );

        if (!mounted) return;
        updateDirectionInfo(
          newDirectionText: parseHtmlString(result['direction']),
          newDistance: result['distance'],
          newManeuver: result['maneuver'] ?? '',
        );
      }
    }
  }

  int _getClosestPolylinePointIndex(LatLng position) {
    double minDistance = double.infinity;
    int closestIndex = -1;

    for (int i = 0; i < polylinePoints.length; i++) {
      final distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        polylinePoints[i].latitude,
        polylinePoints[i].longitude,
      );
      if (distance < minDistance) {
        minDistance = distance;
        closestIndex = i;
      }
    }
    return closestIndex;
  }

  double _getBearing(LatLng start, LatLng end) {
    final lat1 = start.latitude * math.pi / 180;
    final lon1 = start.longitude * math.pi / 180;
    final lat2 = end.latitude * math.pi / 180;
    final lon2 = end.longitude * math.pi / 180;

    final dLon = lon2 - lon1;

    final y = math.sin(dLon) * math.cos(lat2);
    final x =
        math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);

    final bearing = math.atan2(y, x);
    return (bearing * 180 / math.pi + 360) % 360;
  }

  void _goToCurrentLocation() async {
    final hasPermission = await _ensureLocationPermission();
    if (!hasPermission) return;

    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    final latLng = LatLng(position.latitude, position.longitude);
    CommonLogger.log.i('Current Loc : $latLng');

    _mapController?.animateCamera(CameraUpdate.newLatLngZoom(latLng, 17));
  }

  String parseHtmlString(String htmlText) {
    return htmlText
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&');
  }

  String maneuver = '';
  void updateDirectionInfo({
    required String newDirectionText,
    required String newDistance,
    required String newManeuver,
  }) {
    if (!mounted) return;
    setState(() {
      directionText = newDirectionText;
      distance = newDistance;
      maneuver = newManeuver;
    });
  }

  String getManeuverIcon(String maneuver) {
    switch (maneuver) {
      case "turn-right":
        return "assets/images/right-turn.png";
      case "turn-left":
        return "assets/images/left-turn.png"; // ✅ fixed
      case "straight":
        return 'assets/images/straight.png';
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

  void fitBoundsToDriverAndPickup() async {
    if (_mapController == null || driverLocation == null) return;

    final bounds = LatLngBounds(
      southwest: LatLng(
        math.min(driverLocation!.latitude, widget.pickupLocation.latitude),
        math.min(driverLocation!.longitude, widget.pickupLocation.longitude),
      ),
      northeast: LatLng(
        math.max(driverLocation!.latitude, widget.pickupLocation.latitude),
        math.max(driverLocation!.longitude, widget.pickupLocation.longitude),
      ),
    );

    await _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 90),
    );

    final zoomLevel = await _mapController!.getZoomLevel();
    if (zoomLevel > 16) {
      _mapController!.animateCamera(CameraUpdate.zoomTo(16));
    }
  }

  bool isOffRoute(LatLng currentLocation) {
    if (polylinePoints.isEmpty) return true;

    for (final point in polylinePoints) {
      final d = Geolocator.distanceBetween(
        currentLocation.latitude,
        currentLocation.longitude,
        point.latitude,
        point.longitude,
      );
      if (d < 20) return false; // within 20m = on route
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final markers = <Marker>{
      Marker(
        markerId: const MarkerId('driver'),
        position: driverLocation ?? widget.driverLocation,
        icon: carIcon ?? BitmapDescriptor.defaultMarker,
        rotation: carBearing,
        anchor: const Offset(0.5, 0.5),
        flat: true,
      ),
      Marker(
        markerId: const MarkerId('pickup'),
        position: widget.pickupLocation,
        infoWindow: const InfoWindow(title: 'Pickup Location'),
      ),
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
                  onCameraMove:
                      (position) => _currentMapBearing = position.bearing,
                  myLocationEnabled: false,
                  onMapCreated: (controller) async {
                    _mapController = controller;
                    fitBoundsToDriverAndPickup();
                    final style = await DefaultAssetBundle.of(
                      context,
                    ).loadString('assets/map_style/map_style1.json');
                    _mapController?.setMapStyle(style);
                  },
                  initialPosition: widget.pickupLocation,
                  markers: markers,
                  polylines: {
                    Polyline(
                      polylineId: const PolylineId("route"),
                      color: AppColors.commonBlack,
                      width: 5,
                      points: polylinePoints,
                    ),
                  },
                ),
              ),

              Positioned(
                top: arrivedAtPickup ? 350 : 500,
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
                                getManeuverIcon(maneuver),
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

              // Bottom sheet + timer overlay
              Stack(
                children: [
                  DraggableScrollableSheet(
                    key: ValueKey(arrivedAtPickup),
                    initialChildSize:
                        arrivedAtPickup
                            ? (showRedTimer ? 0.45 : 0.50)
                            : (showRedTimer ? 0.35 : 0.30),
                    minChildSize:
                        arrivedAtPickup
                            ? (showRedTimer ? 0.43 : 0.40)
                            : (showRedTimer ? 0.35 : 0.30),
                    maxChildSize:
                        arrivedAtPickup
                            ? (showRedTimer ? 0.46 : 0.65)
                            : (showRedTimer ? 0.35 : 0.30),
                    builder: (context, scrollController) {
                      return Container(
                        decoration: const BoxDecoration(color: Colors.white),
                        child: ListView(
                          physics: const BouncingScrollPhysics(),
                          controller: scrollController,
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
                            const SizedBox(height: 10),
                            if (!arrivedAtPickup) ...[
                              Column(
                                children: [
                                  Visibility(
                                    visible: showRedTimer,
                                    maintainSize: false,
                                    maintainAnimation: false,
                                    maintainState: false,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 20,
                                      ),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: AppColors.red.withOpacity(0.1),
                                        ),
                                        child: ListTile(
                                          onTap: () {
                                            Buttons.showCancelRideBottomSheet(
                                              context,
                                              onConfirmCancel: (reason) {
                                                driverStatusController
                                                    .cancelBooking(
                                                      bookingId:
                                                          widget.bookingId,
                                                      context,
                                                      reason: reason,
                                                    );
                                              },
                                            );
                                          },
                                          trailing: Image.asset(
                                            AppImages.redArrow,
                                            height: 20,
                                            width: 20,
                                          ),
                                          leading: Image.asset(
                                            AppImages.close,
                                            height: 20,
                                            width: 20,
                                          ),
                                          title: CustomTextfield.textWithStyles600(
                                            fontSize: 14,
                                            color: AppColors.red,
                                            'Tap to cancel the ride, If rider don’t show up',
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),

                                  ListTile(
                                    trailing: GestureDetector(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder:
                                                (context) => ChatScreen(
                                                  bookingId: widget.bookingId,
                                                ),
                                          ),
                                        );
                                      },
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: AppColors.commonBlack
                                              .withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(
                                            30,
                                          ),
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.all(10),
                                          child: Image.asset(
                                            AppImages.msg,
                                            height: 25,
                                            width: 25,
                                          ),
                                        ),
                                      ),
                                    ),
                                    leading: GestureDetector(
                                      onTap: () async {
                                        const phoneNumber = 'tel:+918248191110';
                                        final Uri url = Uri.parse(phoneNumber);
                                        if (await canLaunchUrl(url)) {
                                          await launchUrl(url);
                                        }
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.all(5),
                                        child: ClipOval(
                                          child: CachedNetworkImage(
                                            imageUrl: cutomerProfile,
                                            height: 45,
                                            width: 45,
                                            fit: BoxFit.cover,
                                            placeholder:
                                                (
                                                  context,
                                                  url,
                                                ) => const SizedBox(
                                                  height: 40,
                                                  width: 40,
                                                  child:
                                                      CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                      ),
                                                ),
                                            errorWidget:
                                                (context, url, error) =>
                                                    const Icon(
                                                      Icons.person,
                                                      size: 30,
                                                      color: Colors.black,
                                                    ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    title: Center(
                                      child: CustomTextfield.textWithStyles600(
                                        fontSize: 20,
                                        'Waiting for the Rider',
                                      ),
                                    ),
                                    subtitle: Center(
                                      child:
                                          CustomTextfield.textWithStylesSmall(
                                            fontSize: 14,
                                            colors: AppColors.textColorGrey,
                                            CUSTOMERNAME,
                                          ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 10,
                                    ),
                                    child: ActionSlider.standard(
                                      controller: _sliderController,
                                      action: (controller) async {
                                        controller.loading();
                                        await Future.delayed(
                                          const Duration(seconds: 1),
                                        );
                                        final message = await driverStatusController
                                            .otpRequest(
                                              pickupAddress:
                                                  widget
                                                      .pickupLocationAddress ??
                                                  '',
                                              dropAddress:
                                                  widget.dropLocationAddress ??
                                                  '',
                                              custName: CUSTOMERNAME,
                                              context,
                                              bookingId: widget.bookingId,
                                            );

                                        if (message != null) {
                                          controller.success();
                                          _timer?.cancel();
                                          _timer = null;
                                        } else {
                                          controller.failure();
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Failed to start ride',
                                              ),
                                            ),
                                          );
                                        }
                                      },
                                      height: 50,
                                      backgroundColor: const Color(0xFF1C1C1C),
                                      toggleColor: Colors.white,
                                      icon: const Icon(
                                        Icons.double_arrow,
                                        color: Colors.black,
                                        size: 28,
                                      ),
                                      child: Text(
                                        'Swipe to Start Ride',
                                        style: TextStyle(
                                          color: AppColors.commonWhite,
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ] else ...[
                              if (!driverReached) ...[
                                Column(
                                  children: [
                                    ListTile(
                                      trailing: GestureDetector(
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder:
                                                  (context) => ChatScreen(
                                                    bookingId: widget.bookingId,
                                                  ),
                                            ),
                                          );
                                        },
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: AppColors.commonBlack
                                                .withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(
                                              30,
                                            ),
                                          ),
                                          child: Padding(
                                            padding: const EdgeInsets.all(10),
                                            child: Image.asset(
                                              AppImages.msg,
                                              height: 25,
                                              width: 25,
                                            ),
                                          ),
                                        ),
                                      ),
                                      leading: GestureDetector(
                                        onTap: () async {
                                          const phoneNumber =
                                              'tel:+918248191110';
                                          final Uri url = Uri.parse(
                                            phoneNumber,
                                          );
                                          if (await canLaunchUrl(url)) {
                                            await launchUrl(url);
                                          }
                                        },
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: AppColors.commonBlack
                                                .withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(
                                              30,
                                            ),
                                          ),
                                          child: Padding(
                                            padding: const EdgeInsets.all(10),
                                            child: Image.asset(
                                              AppImages.call,
                                              height: 25,
                                              width: 25,
                                            ),
                                          ),
                                        ),
                                      ),
                                      title: Center(
                                        child: Obx(
                                          () =>
                                              CustomTextfield.textWithStyles600(
                                                formatDuration(
                                                  driverStatusController
                                                      .pickupDurationInMin
                                                      .value,
                                                ),
                                                fontSize: 20,
                                              ),
                                        ),
                                      ),
                                      subtitle: Center(
                                        child:
                                            CustomTextfield.textWithStylesSmall(
                                              fontSize: 14,
                                              colors: AppColors.textColorGrey,
                                              'Picking up $CUSTOMERNAME',
                                            ),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 5,
                                        horizontal: 15,
                                      ),
                                      child: Divider(
                                        color: AppColors.dividerColor1,
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 5,
                                        horizontal: 15,
                                      ),
                                      child: GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            driverReached = !driverReached;
                                          });
                                        },
                                        child: Row(
                                          children: [
                                            CachedNetworkImage(
                                              imageUrl: cutomerProfile,
                                              height: 25,
                                              width: 25,
                                              fit: BoxFit.contain,
                                              placeholder:
                                                  (
                                                    context,
                                                    url,
                                                  ) => const SizedBox(
                                                    height: 25,
                                                    width: 25,
                                                    child:
                                                        CircularProgressIndicator(
                                                          strokeWidth: 2,
                                                        ),
                                                  ),
                                              errorWidget:
                                                  (context, url, error) =>
                                                      const Icon(
                                                        Icons.person,
                                                        size: 25,
                                                        color: Colors.black,
                                                      ),
                                            ),
                                            const SizedBox(width: 15),
                                            CustomTextfield.textWithStyles600(
                                              CUSTOMERNAME,
                                              fontSize: 20,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 5,
                                        horizontal: 15,
                                      ),
                                      child: Divider(
                                        color: AppColors.dividerColor1,
                                      ),
                                    ),
                                    const SizedBox(height: 15),
                                  ],
                                ),
                              ] else ...[
                                const SizedBox(height: 10),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                  ),
                                  child: Column(
                                    children: [
                                      Buttons.button(
                                        buttonColor: AppColors.resendBlue,
                                        borderRadius: 8,
                                        onTap: () async {
                                          final result =
                                              await driverStatusController
                                                  .driverArrived(
                                                    context,
                                                    bookingId: widget.bookingId,
                                                  );

                                          if (result != null &&
                                              result.status == 200) {
                                            if (!mounted) return;
                                            setState(() {
                                              arrivedAtPickup = false;
                                              _seconds = 300;
                                            });
                                            _startTimer();
                                          } else {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  result?.message ??
                                                      "Something went wrong",
                                                ),
                                              ),
                                            );
                                          }
                                        },
                                        text:
                                            driverStatusController
                                                    .arrivedIsLoading
                                                    .value
                                                ? SizedBox(
                                                  height: 20,
                                                  width: 20,
                                                  child:
                                                      AppLoader.circularLoader(),
                                                )
                                                : const Text(
                                                  'Arrived at Pickup Point',
                                                ),
                                      ),
                                      const SizedBox(height: 20),
                                      GestureDetector(
                                        onTap: () {},
                                        child: Row(
                                          children: [
                                            Padding(
                                              padding: const EdgeInsets.all(5),
                                              child: ClipOval(
                                                child: CachedNetworkImage(
                                                  imageUrl: cutomerProfile,
                                                  height: 45,
                                                  width: 45,
                                                  fit: BoxFit.cover,
                                                  placeholder:
                                                      (
                                                        context,
                                                        url,
                                                      ) => const SizedBox(
                                                        height: 40,
                                                        width: 40,
                                                        child:
                                                            CircularProgressIndicator(
                                                              strokeWidth: 2,
                                                            ),
                                                      ),
                                                  errorWidget:
                                                      (context, url, error) =>
                                                          const Icon(
                                                            Icons.person,
                                                            size: 30,
                                                            color: Colors.black,
                                                          ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            CustomTextfield.textWithStyles600(
                                              CUSTOMERNAME,
                                              fontSize: 20,
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 15),
                                      Container(
                                        decoration: BoxDecoration(
                                          color: AppColors.containerColor1,
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 30,
                                            vertical: 10,
                                          ),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              CustomTextfield.textWithImage(
                                                colors: AppColors.commonBlack,
                                                fontWeight: FontWeight.w500,
                                                fontSize: 12,
                                                text: 'Get Help',
                                                imagePath: AppImages.getHelp,
                                              ),
                                              const SizedBox(
                                                height: 20,
                                                child: VerticalDivider(),
                                              ),
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
                                      ),
                                      const SizedBox(height: 20),
                                    ],
                                  ),
                                ),
                              ],

                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 15,
                                      ),
                                      child: CustomTextfield.textWithStyles600(
                                        'Ride Details',
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    Row(
                                      children: [
                                        Container(
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(
                                              40,
                                            ),
                                            color: AppColors.commonBlack
                                                .withOpacity(0.1),
                                          ),
                                          child: const Padding(
                                            padding: EdgeInsets.all(4),
                                            child: Icon(
                                              Icons.circle,
                                              color: Colors.black,
                                              size: 10,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 20),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              CustomTextfield.textWithStyles600(
                                                'Pickup',
                                                fontSize: 16,
                                              ),
                                              CustomTextfield.textWithStylesSmall(
                                                colors: AppColors.textColorGrey,
                                                maxLine: 2,
                                                widget.pickupLocationAddress ??
                                                    '',
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
                                            borderRadius: BorderRadius.circular(
                                              40,
                                            ),
                                            color: AppColors.commonBlack
                                                .withOpacity(0.1),
                                          ),
                                          child: Padding(
                                            padding: const EdgeInsets.all(4),
                                            child: Icon(
                                              Icons.circle,
                                              color: AppColors.grey,
                                              size: 10,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 20),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              CustomTextfield.textWithStyles600(
                                                'Drop off - Constitution Ave',
                                                fontSize: 16,
                                              ),
                                              CustomTextfield.textWithStylesSmall(
                                                widget.dropLocationAddress ??
                                                    '',
                                                colors: AppColors.textColorGrey,
                                                maxLine: 2,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 20),
                                    Buttons.button(
                                      borderColor: AppColors.buttonBorder,
                                      buttonColor: AppColors.commonWhite,
                                      borderRadius: 8,
                                      textColor: AppColors.commonBlack,
                                      onTap:
                                          () => Buttons.showDialogBox(
                                            context: context,
                                          ),
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
                                            driverStatusController
                                                .cancelBooking(
                                                  bookingId: widget.bookingId,
                                                  context,
                                                  reason: reason,
                                                );
                                          },
                                        );
                                      },
                                      text: const Text('Cancel this Ride'),
                                    ),
                                    const SizedBox(height: 15),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),

                  if (!arrivedAtPickup)
                    Positioned(
                      bottom: showRedTimer ? 285 : 240,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 22,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(
                              color:
                                  showRedTimer
                                      ? AppColors.timerBorderColor
                                      : AppColors.commonBlack.withOpacity(0.2),
                              width: 6,
                            ),
                          ),
                          child: Text(
                            timerText,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                              color:
                                  showRedTimer
                                      ? AppColors.timerBorderColor
                                      : AppColors.commonBlack,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// import 'dart:async';
// import 'dart:math';
// import 'dart:math' as math;
// import 'package:action_slider/action_slider.dart';
// import 'package:cached_network_image/cached_network_image.dart';
// import 'package:flutter/services.dart';
// import 'package:flutter_compass/flutter_compass.dart';
// import 'package:geocoding/geocoding.dart';
// import 'package:hopper/Presentation/DriverScreen/screens/chat_screen.dart';
// import 'package:hopper/Presentation/DriverScreen/screens/driver_main_screen.dart';
// import 'package:hopper/Presentation/DriverScreen/screens/verify_rider_screen.dart';
// import 'package:hopper/utils/sharedprefsHelper/local_data_store.dart';
// import 'package:hopper/utils/websocket/socket_io_client.dart';
// import 'package:url_launcher/url_launcher.dart';
//
// import 'package:flutter/material.dart';
// import 'package:geolocator/geolocator.dart';
// import 'package:google_maps_flutter/google_maps_flutter.dart';
// import 'package:hopper/Core/Utility/images.dart';
// import 'package:hopper/Presentation/Authentication/widgets/textFields.dart';
// import '../../../Core/Constants/Colors.dart';
// import '../../../Core/Constants/log.dart';
// import '../../../Core/Utility/Buttons.dart';
// import '../../../Core/Utility/app_loader.dart';
// import '../../../utils/map/google_map.dart';
// import '../../../utils/map/route_info.dart';
// import '../../../utils/netWorkHandling/network_handling_screen.dart';
// import '../controller/driver_status_controller.dart';
// import 'package:get/get.dart';
//
// class PickingCustomerScreen extends StatefulWidget {
//   final LatLng pickupLocation;
//   final String? pickupLocationAddress;
//   final String? dropLocationAddress;
//   final LatLng driverLocation;
//   final String bookingId;
//
//   const PickingCustomerScreen({
//     Key? key,
//     required this.pickupLocation,
//     required this.driverLocation,
//     required this.bookingId,
//     this.pickupLocationAddress,
//     this.dropLocationAddress,
//   }) : super(key: key);
//
//   @override
//   State<PickingCustomerScreen> createState() => _PickingCustomerScreenState();
// }
//
// class _PickingCustomerScreenState extends State<PickingCustomerScreen> {
//   late ActionSliderController _sliderController;
//   LatLng? driverLocation;
//   late SocketService socketService;
//   LatLng? nextPoint;
//   bool showArrivedButton = false;
//   late LatLng customerFroms;
//   String customerFrom = '';
//   String CUSTOMERNAME = '';
//   String CUSTOMERPHN = '';
//   String DISTANCE = '';
//   String DRIVERTIME = '';
//   String RIDEDISTANCEINMETERS = '';
//   String ESTIMATEDRIDETIMEINMIN = '';
//   double carBearing = 0;
//   double _currentMapBearing = 0.0;
//   String PICKUPDISTANCEINMETERS = '';
//   String PICKUPDURATIONINMIN = '';
//
//   // late LatLng customerTo;
//   String customerTo = '';
//   late LatLng driverCurrentLatLng;
//   String profilePic = '';
//   String custName = '';
//   String plateNumber = '';
//   String driverName = '';
//   String cutomerProfile = '';
//   String carDetails = '';
//   bool isDriverConfirmed = false;
//   String pickupAddress = '';
//   String dropoffAddress = '';
//
//   String driverProfilePic = '';
//   List<String> carExteriorImages = [];
//   LatLng? lastPosition;
//   bool isAnimating = false;
//   Marker? _carMarker;
//   GoogleMapController? _mapController;
//   bool driverReached = false;
//   bool arrivedAtPickup = true;
//   final DriverStatusController driverStatusController = Get.put(
//     DriverStatusController(),
//   );
//
//   String directionText = '';
//   BitmapDescriptor? carIcon;
//   String distance = '';
//   List<LatLng> polylinePoints = [];
//   StreamSubscription<Position>? positionStream;
//   int _seconds = 300;
//   Timer? _timer;
//
//   bool showRedTimer = false;
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
//   // Future<void> _loadMarkerIcons() async {
//   //   carIcon = await BitmapDescriptor.asset(
//   //     height: 70,
//   //     const ImageConfiguration(size: Size(50, 50)),
//   //     AppImages.parcelBike,
//   //   );
//   //
//   //   setState(() {});
//   // }
//
//   void _startTimer() {
//     _timer?.cancel();
//     _seconds = 300;
//     showRedTimer = false;
//
//     _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
//       if (_seconds > 0) {
//         setState(() {
//           _seconds--;
//
//           // ✅ Show red only when less than or equal to 10 seconds
//           showRedTimer = _seconds <= 10;
//         });
//       } else {
//         timer.cancel();
//       }
//     });
//   }
//
//   String get timerText {
//     final m = (_seconds ~/ 60).toString().padLeft(2, '0');
//     final s = (_seconds % 60).toString().padLeft(2, '0');
//     return '$m:$s';
//   }
//
//   String formatDistance(double meters) {
//     double kilometers = meters / 1000;
//     return '${kilometers.toStringAsFixed(1)} km';
//   }
//
//   String formatDuration(double minutes) {
//     int totalMinutes = minutes.round();
//     int hours = totalMinutes ~/ 60;
//     int remainingMinutes = totalMinutes % 60;
//
//     if (hours > 0) {
//       return '$hours hr $remainingMinutes min';
//     } else {
//       return '$remainingMinutes min';
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
//     socketService = SocketService();
//     socketService.on('joined-booking', (data) async {
//       if (!mounted) return;
//       JoinedBookingData().setData(data);
//       CommonLogger.log.i("🚕 Joined booking data: $data");
//
//       // Extract driver & vehicle details
//       final vehicle = data['vehicle'] ?? {};
//       final String driverId = data['driverId'] ?? '';
//       final String driverFullName = data['driverName'] ?? '';
//       final double rating =
//           double.tryParse(data['driverRating'].toString()) ?? 0.0;
//       final String color = vehicle['color'] ?? '';
//       final String model = vehicle['model'] ?? '';
//       final String customerName = data['customerName'] ?? '';
//       final String customerProfilePic = data['customerProfilePic'] ?? '';
//       final String customerPhone = data['customerPhone'] ?? '';
//       final String driverDistanceInMeters =
//           data['driverDistanceInMeters']?.toString() ?? '';
//       final String estimatedArrivalTimeInMin =
//           data['estimatedArrivalTimeInMin']?.toString() ?? '';
//       final String rideDistanceInMeters =
//           data['rideDistanceInMeters']?.toString() ?? '';
//       final String estimatedRideTimeInMin =
//           data['estimatedRideTimeInMin']?.toString() ?? '';
//       final String type = vehicle['type'] ?? '';
//       final String plate = vehicle['plateNumber'] ?? '';
//       final bool driverAccepted = data['driver_accept_status'] == true;
//       final customerLoc = data['customerLocation'];
//       double fromLat = customerLoc['fromLatitude'];
//       double fromLng = customerLoc['fromLongitude'];
//       double toLat = customerLoc['toLatitude'];
//       double toLng = customerLoc['toLongitude'];
//
//       final LatLng customerFromLatLng = LatLng(
//         customerLoc['fromLatitude'],
//         customerLoc['fromLongitude'],
//       );
//       final LatLng customerToLatLng = LatLng(
//         customerLoc['toLatitude'],
//         customerLoc['toLongitude'],
//       );
//
//       final driverLocation = data['driverLocation'];
//       final LatLng driverLatLng = LatLng(
//         driverLocation['latitude'],
//         driverLocation['longitude'],
//       );
//
//       // Extract profile and car photo
//       final String picUrl = data['profilePic'] ?? '';
//
//       final List<dynamic> carPhotos = List.from(
//         data['carExteriorPhotos'] ?? [],
//       );
//       String pickupAddrs = await getAddressFromLatLng(fromLat, fromLng);
//       String dropoffAddrs = await getAddressFromLatLng(toLat, toLng);
//       setState(() {
//         plateNumber = plate;
//         driverName = '$driverFullName';
//         carDetails = '$color - $type $model';
//         isDriverConfirmed = driverAccepted;
//         pickupAddress = pickupAddrs;
//
//         customerFrom = pickupAddrs;
//         CUSTOMERNAME = customerName;
//         CUSTOMERPHN = customerPhone;
//         cutomerProfile = customerProfilePic;
//
//         customerTo = dropoffAddrs;
//         driverCurrentLatLng = driverLatLng;
//         driverProfilePic = profilePic;
//         carExteriorImages = carPhotos.map((e) => e.toString()).toList();
//       });
//
//       CommonLogger.log.i("🚕 Driver confirmed: $driverAccepted");
//       CommonLogger.log.i("🚕 Driver name: $driverFullName");
//       CommonLogger.log.i("🚕 Plate number: $plate");
//     });
//
//     // Debug: See all events
//     socketService.socket.onAny((event, data) {
//       CommonLogger.log.i('📦 [onAny] $event: $data');
//     });
//     socketService.on('driver-location', (data) async {
//       CommonLogger.log.i('driver-location : $data');
//
//       if (data != null) {
//         if (data['pickupDistanceInMeters'] != null) {
//           driverStatusController.pickupDistanceInMeters.value =
//               (data['pickupDistanceInMeters'] as num).toDouble();
//         }
//
//         if (data['pickupDurationInMin'] != null) {
//           driverStatusController.pickupDurationInMin.value =
//               (data['pickupDurationInMin'] as num).toDouble();
//         }
//       }
//     });
//
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
//
//     socketService.on('driver-arrived', (data) {
//       final status = data['status'];
//       if (status == true || status.toString() == 'true') {
//         if (!mounted) return;
//         setState(() {
//           driverReached = true;
//         });
//
//         CommonLogger.log.i('🚦 arrivedAtPickup updated to false');
//       }
//
//       CommonLogger.log.i('🚗 Driver arrived: $data');
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
//   @override
//   void initState() {
//     super.initState();
//     _sliderController = ActionSliderController(); // init controller
//     SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
//     SystemChrome.setSystemUIOverlayStyle(
//       SystemUiOverlayStyle(
//         statusBarColor: Colors.transparent,
//         statusBarIconBrightness: Brightness.dark,
//       ),
//     );
//     _initSocketAndLocation();
//     _loadMarkerIcons();
//
//     _getInitialDriverLocation();
//     // _startTimer();
//   }
//
//   @override
//   void didChangeDependencies() {
//     super.didChangeDependencies();
//     _sliderController.reset();
//   }
//
//   @override
//   void dispose() {
//     positionStream?.cancel();
//     _sliderController.dispose();
//     _timer?.cancel();
//     super.dispose();
//   }
//
//   Future<void> _getInitialDriverLocation() async {
//     Position position = await Geolocator.getCurrentPosition(
//       desiredAccuracy: LocationAccuracy.high,
//     );
//     driverLocation = LatLng(position.latitude, position.longitude);
//
//     final result = await getRouteInfo(
//       origin: driverLocation!,
//       destination: widget.pickupLocation,
//     );
//
//     setState(() {
//       directionText = result['direction'];
//       distance = result['distance'];
//       polylinePoints = decodePolyline(result['polyline']);
//       if (polylinePoints.length >= 2) {
//         nextPoint = polylinePoints[1];
//       } else if (polylinePoints.length == 1) {
//         nextPoint = polylinePoints[0];
//       }
//     });
//
//     _startDriverTracking();
//   }
//
//   Future<void> loadRoute() async {
//     final result = await getRouteInfo(
//       origin: driverLocation!,
//       destination: widget.pickupLocation,
//     );
//
//     setState(() {
//       directionText = result['direction'];
//       distance = result['distance'];
//       maneuver = result['maneuver']; // ADD THIS!
//       polylinePoints = decodePolyline(result['polyline']);
//       if (polylinePoints.length >= 2) {
//         nextPoint = polylinePoints[1]; // the point the car is moving towards
//       } else if (polylinePoints.length == 1) {
//         nextPoint = polylinePoints[0]; // fallback
//       }
//     });
//   }
//
//   Future<void> _fetchRoute() async {
//     if (driverLocation == null) return;
//
//     final result = await getRouteInfo(
//       origin: driverLocation!, // 🚗 Driver
//       destination: widget.pickupLocation, // 🧍 Customer
//     );
//
//     setState(() {
//       polylinePoints = decodePolyline(result['polyline']);
//       if (polylinePoints.length >= 2) {
//         nextPoint = polylinePoints[1];
//       }
//     });
//   }
//
//   void _startDriverTracking() {
//     positionStream = Geolocator.getPositionStream(
//       locationSettings: const LocationSettings(
//         accuracy: LocationAccuracy.bestForNavigation,
//         distanceFilter: 2,
//       ),
//     ).listen((position) async {
//       final current = LatLng(position.latitude, position.longitude);
//
//       if (lastPosition != null) {
//         final distanceMoved = Geolocator.distanceBetween(
//           lastPosition!.latitude,
//           lastPosition!.longitude,
//           current.latitude,
//           current.longitude,
//         );
//
//         if (distanceMoved < 1) return; // ignore minor moves
//       }
//
//       final bearing =
//           lastPosition != null
//               ? _getBearing(lastPosition!, current)
//               : carBearing;
//
//       setState(() {
//         driverLocation = current;
//         carBearing = bearing;
//         _currentMapBearing = bearing;
//       });
//
//       _animateCarTo(current);
//
//       lastPosition = current;
//       _updateRemainingPolyline(current);
//     });
//   }
//
//   Future<void> _fetchUpdatedRoute(LatLng currentLocation) async {
//     final result = await getRouteInfo(
//       origin: currentLocation,
//       destination: widget.pickupLocation,
//     );
//
//     setState(() {
//       polylinePoints = decodePolyline(result['polyline']);
//       directionText = result['direction'];
//       distance = result['distance'];
//       maneuver = result['maneuver'];
//
//       if (polylinePoints.length >= 2) {
//         nextPoint = polylinePoints[1];
//       } else if (polylinePoints.length == 1) {
//         nextPoint = polylinePoints[0];
//       }
//     });
//   }
//
//   bool _isSameLocation(LatLng a, LatLng b) {
//     return (a.latitude - b.latitude).abs() < 0.00001 &&
//         (a.longitude - b.longitude).abs() < 0.00001;
//   }
//
//   Future<void> _animateCarTo(LatLng to) async {
//     if (driverLocation == null || _isSameLocation(driverLocation!, to)) return;
//
//     isAnimating = true;
//
//     final start = driverLocation!;
//     final end = to;
//
//     final startBearing = carBearing;
//     final endBearing = _getBearing(start, end);
//
//     const steps = 30; // more steps = smoother movement
//     const duration = Duration(milliseconds: 800);
//     final interval = duration.inMilliseconds ~/ steps;
//
//     for (int i = 1; i <= steps; i++) {
//       await Future.delayed(Duration(milliseconds: interval));
//
//       final t = i / steps;
//
//       final lat = _lerp(start.latitude, end.latitude, t);
//       final lng = _lerp(start.longitude, end.longitude, t);
//       final newBearing = _lerpBearing(startBearing, endBearing, t);
//
//       setState(() {
//         driverLocation = LatLng(lat, lng);
//         carBearing = newBearing;
//       });
//
//       _mapController?.animateCamera(
//         CameraUpdate.newCameraPosition(
//           CameraPosition(
//             target: driverLocation!,
//             zoom: 17,
//             bearing: carBearing,
//             tilt: 60,
//           ),
//         ),
//       );
//     }
//
//     isAnimating = false;
//   }
//
//   double _lerp(double start, double end, double t) {
//     return start + (end - start) * t;
//   }
//
//   double _lerpBearing(double start, double end, double t) {
//     double difference = ((end - start + 540) % 360) - 180;
//     return (start + difference * t + 360) % 360;
//   }
//
//   void _updateRemainingPolyline(LatLng currentLocation) async {
//     int closestIndex = _getClosestPolylinePointIndex(currentLocation);
//     if (closestIndex != -1 && closestIndex < polylinePoints.length) {
//       polylinePoints = polylinePoints.sublist(closestIndex);
//       polylinePoints = polylinePoints.sublist(closestIndex);
//       if (polylinePoints.length >= 2) {
//         nextPoint = polylinePoints[1];
//         final result = await getRouteInfo(
//           origin: currentLocation,
//           destination: widget.pickupLocation,
//         );
//
//         updateDirectionInfo(
//           newDirectionText: parseHtmlString(result['direction']),
//           newDistance: result['distance'],
//           newManeuver: result['maneuver'],
//         );
//       }
//     }
//   }
//
//   int _getClosestPolylinePointIndex(LatLng position) {
//     double minDistance = double.infinity;
//     int closestIndex = -1;
//
//     for (int i = 0; i < polylinePoints.length; i++) {
//       final distance = Geolocator.distanceBetween(
//         position.latitude,
//         position.longitude,
//         polylinePoints[i].latitude,
//         polylinePoints[i].longitude,
//       );
//       if (distance < minDistance) {
//         minDistance = distance;
//         closestIndex = i;
//       }
//     }
//
//     return closestIndex;
//   }
//
//   double _getBearing(LatLng start, LatLng end) {
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
//   void _goToCurrentLocation() async {
//     Position position = await Geolocator.getCurrentPosition(
//       desiredAccuracy: LocationAccuracy.high,
//     );
//
//     final latLng = LatLng(position.latitude, position.longitude);
//     CommonLogger.log.i('Current Loc :${latLng}');
//
//     _mapController?.animateCamera(CameraUpdate.newLatLngZoom(latLng, 17));
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
//   void updateDirectionInfo({
//     required String newDirectionText,
//     required String newDistance,
//     required String newManeuver,
//   }) {
//     setState(() {
//       directionText = newDirectionText;
//       distance = newDistance;
//       maneuver = newManeuver;
//     });
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
//   /*  void fitBoundsToDriverAndPickup() {
//     if (_mapController == null ||
//         driverLocation == null ||
//         widget.pickupLocation == null)
//       return;
//
//     final bounds = LatLngBounds(
//       southwest: LatLng(
//         min(driverLocation!.latitude, widget.pickupLocation.latitude),
//         min(driverLocation!.longitude, widget.pickupLocation.longitude),
//       ),
//       northeast: LatLng(
//         max(driverLocation!.latitude, widget.pickupLocation.latitude),
//         max(driverLocation!.longitude, widget.pickupLocation.longitude),
//       ),
//     );
//
//     _mapController!.animateCamera(
//       CameraUpdate.newLatLngBounds(bounds, 60),
//     );
//   }*/
//   void fitBoundsToDriverAndPickup() async {
//     if (_mapController == null ||
//         driverLocation == null ||
//         widget.pickupLocation == null)
//       return;
//
//     final bounds = LatLngBounds(
//       southwest: LatLng(
//         min(driverLocation!.latitude, widget.pickupLocation.latitude),
//         min(driverLocation!.longitude, widget.pickupLocation.longitude),
//       ),
//       northeast: LatLng(
//         max(driverLocation!.latitude, widget.pickupLocation.latitude),
//         max(driverLocation!.longitude, widget.pickupLocation.longitude),
//       ),
//     );
//
//     // Animate camera with padding
//     await _mapController!.animateCamera(
//       CameraUpdate.newLatLngBounds(bounds, 90),
//     );
//
//     // Apply a minimum zoom (to avoid over zoom)
//     final zoomLevel = await _mapController!.getZoomLevel();
//     if (zoomLevel > 16) {
//       _mapController!.animateCamera(CameraUpdate.zoomTo(16));
//     }
//   }
//
//   bool isOffRoute(LatLng currentLocation) {
//     if (polylinePoints.isEmpty) return true;
//
//     for (final point in polylinePoints) {
//       final distance = Geolocator.distanceBetween(
//         currentLocation.latitude,
//         currentLocation.longitude,
//         point.latitude,
//         point.longitude,
//       );
//
//       if (distance < 20) return false; // within 20 meters = on route
//     }
//
//     return true;
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final markers = <Marker>{
//       Marker(
//         markerId: const MarkerId('driver'),
//         position: driverLocation ?? const LatLng(0, 0),
//         icon: carIcon ?? BitmapDescriptor.defaultMarker,
//         rotation: carBearing, // ✅ use stored rotation
//         anchor: const Offset(0.5, 0.5),
//         flat: true,
//       ),
//       Marker(
//         markerId: const MarkerId('pickup'),
//         position: widget.pickupLocation,
//         infoWindow: const InfoWindow(title: 'Pickup Location'),
//       ),
//     };
//
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
//                 onMapCreated: (controller) async {
//                   _mapController = controller;
//                   fitBoundsToDriverAndPickup();
//                   String style = await DefaultAssetBundle.of(
//                     context,
//                   ).loadString('assets/map_style/map_style1.json');
//                   _mapController!.setMapStyle(style);
//                 },
//                 initialPosition: widget.pickupLocation,
//                 markers: markers,
//                 polylines: {
//                   Polyline(
//                     polylineId: PolylineId("route"),
//                     color: AppColors.commonBlack,
//                     width: 5,
//                     points: polylinePoints,
//                   ),
//                 },
//               ),
//             ),
//
//             Positioned(
//               top: arrivedAtPickup ? 350 : 500,
//               right: 10,
//               child: FloatingActionButton(
//                 mini: true,
//                 backgroundColor: Colors.white,
//                 shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(30),
//                 ),
//                 onPressed: _goToCurrentLocation,
//                 child: const Icon(Icons.my_location, color: Colors.black),
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
//                           mainAxisAlignment: MainAxisAlignment.center,
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
//
//             Stack(
//               children: [
//                 DraggableScrollableSheet(
//                   key: ValueKey(arrivedAtPickup),
//                   initialChildSize:
//                       arrivedAtPickup
//                           ? (showRedTimer ? 0.45 : 0.50)
//                           : (showRedTimer ? 0.35 : 0.30),
//
//                   minChildSize:
//                       arrivedAtPickup
//                           ? (showRedTimer ? 0.43 : 0.40)
//                           : (showRedTimer ? 0.35 : 0.30),
//
//                   maxChildSize:
//                       arrivedAtPickup
//                           ? (showRedTimer ? 0.46 : 0.65)
//                           : (showRedTimer ? 0.35 : 0.30),
//
//                   /* initialChildSize: arrivedAtPickup ? 0.55 : 0.35,
//                   minChildSize: arrivedAtPickup ? 0.40 : 0.35,
//                   maxChildSize: arrivedAtPickup ? 0.63 : 0.36,*/
//                   // initialChildSize: 0.50, // Start with 80% height
//                   // minChildSize: 0.5, // Can collapse to 40%
//                   // maxChildSize: 0.65, // Can expand up to 95% height
//                   builder: (context, scrollController) {
//                     return Container(
//                       decoration: BoxDecoration(color: Colors.white),
//                       child: ListView(
//                         physics: BouncingScrollPhysics(),
//                         controller: scrollController,
//                         children: [
//                           Center(
//                             child: Container(
//                               width: 60,
//                               height: 5,
//
//                               decoration: BoxDecoration(
//                                 color: Colors.grey[400],
//                                 borderRadius: BorderRadius.circular(10),
//                               ),
//                             ),
//                           ),
//                           SizedBox(height: 10),
//                           if (!arrivedAtPickup) ...[
//                             Column(
//                               children: [
//                                 Visibility(
//                                   visible: showRedTimer,
//                                   maintainSize: false,
//                                   maintainAnimation: false,
//                                   maintainState: false,
//                                   child: Padding(
//                                     padding: const EdgeInsets.symmetric(
//                                       horizontal: 20,
//                                     ),
//                                     child: Container(
//                                       decoration: BoxDecoration(
//                                         color: AppColors.red.withOpacity(0.1),
//                                       ),
//                                       child: ListTile(
//                                         onTap: () {
//                                           Buttons.showCancelRideBottomSheet(
//                                             context,
//                                             onConfirmCancel: (reason) {
//                                               print(
//                                                 "User selected reason: $reason",
//                                               );
//                                               driverStatusController
//                                                   .cancelBooking(
//                                                     bookingId: widget.bookingId,
//                                                     context,
//                                                     reason: reason,
//                                                   );
//                                             },
//                                           );
//                                         },
//                                         trailing: Image.asset(
//                                           AppImages.redArrow,
//                                           height: 20,
//                                           width: 20,
//                                         ),
//                                         leading: Image.asset(
//                                           AppImages.close,
//                                           height: 20,
//                                           width: 20,
//                                         ),
//                                         title: CustomTextfield.textWithStyles600(
//                                           fontSize: 14,
//                                           color: AppColors.red,
//                                           'Tap to cancel the ride, If rider don’t show up',
//                                         ),
//                                       ),
//                                     ),
//                                   ),
//                                 ),
//
//                                 ListTile(
//                                   trailing: GestureDetector(
//                                     onTap: () {
//                                       Navigator.push(
//                                         context,
//                                         MaterialPageRoute(
//                                           builder:
//                                               (context) => ChatScreen(
//                                                 bookingId: widget.bookingId,
//                                               ),
//                                         ),
//                                       );
//                                     },
//                                     child: Container(
//                                       decoration: BoxDecoration(
//                                         color: AppColors.commonBlack
//                                             .withOpacity(0.1),
//                                         borderRadius: BorderRadius.circular(30),
//                                       ),
//                                       child: Padding(
//                                         padding: const EdgeInsets.all(10),
//                                         child: Image.asset(
//                                           AppImages.msg,
//                                           height: 25,
//                                           width: 25,
//                                         ),
//                                       ),
//                                     ),
//                                   ),
//                                   leading: GestureDetector(
//                                     onTap: () async {
//                                       const phoneNumber = 'tel:+918248191110';
//                                       CommonLogger.log.i(phoneNumber);
//                                       final Uri url = Uri.parse(phoneNumber);
//                                       if (await canLaunchUrl(url)) {
//                                         await launchUrl(url);
//                                       } else {
//                                         print('Could not launch dialer');
//                                       }
//                                     },
//                                     child: Padding(
//                                       padding: const EdgeInsets.all(5),
//                                       child: ClipOval(
//                                         child: CachedNetworkImage(
//                                           imageUrl: cutomerProfile,
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
//                                   ),
//
//                                   title: Center(
//                                     child: CustomTextfield.textWithStyles600(
//                                       fontSize: 20,
//                                       'Waiting for the Rider',
//                                     ),
//                                   ),
//                                   subtitle: Center(
//                                     child: CustomTextfield.textWithStylesSmall(
//                                       fontSize: 14,
//                                       colors: AppColors.textColorGrey,
//                                       CUSTOMERNAME,
//                                     ),
//                                   ),
//                                 ),
//                                 Padding(
//                                   padding: const EdgeInsets.symmetric(
//                                     horizontal: 20,
//                                     vertical: 10,
//                                   ),
//                                   child: ActionSlider.standard(
//                                     controller:
//                                         _sliderController, // attach controller
//                                     action: (controller) async {
//                                       controller.loading();
//                                       await Future.delayed(
//                                         const Duration(seconds: 1),
//                                       );
//                                       final message =
//                                           await driverStatusController
//                                               .otpRequest(
//                                                 pickupAddress:
//                                                     widget
//                                                         .pickupLocationAddress ??
//                                                     '',
//                                                 dropAddress:
//                                                     widget
//                                                         .dropLocationAddress ??
//                                                     '',
//                                                 custName: CUSTOMERNAME,
//                                                 context,
//                                                 bookingId: widget.bookingId,
//                                               );
//
//                                       if (message != null) {
//                                         controller.success();
//                                         if (_timer != null &&
//                                             _timer!.isActive) {
//                                           _timer!.cancel();
//                                           _timer = null;
//                                         }
//
//                                         // ScaffoldMessenger.of(context).showSnackBar(
//                                         //   SnackBar(content: Text(message)),
//                                         // );
//                                       } else {
//                                         controller.failure();
//                                         ScaffoldMessenger.of(
//                                           context,
//                                         ).showSnackBar(
//                                           const SnackBar(
//                                             content: Text(
//                                               'Failed to start ride',
//                                             ),
//                                           ),
//                                         );
//                                       }
//                                     },
//                                     height: 50,
//                                     backgroundColor: const Color(0xFF1C1C1C),
//                                     toggleColor: Colors.white,
//                                     icon: const Icon(
//                                       Icons.double_arrow,
//                                       color: Colors.black,
//                                       size: 28,
//                                     ),
//                                     child: Text(
//                                       'Swipe to Start Ride',
//                                       style: TextStyle(
//                                         color: AppColors.commonWhite,
//                                         fontSize: 20,
//                                         fontWeight: FontWeight.bold,
//                                       ),
//                                     ),
//                                   ),
//                                 ),
//                               ],
//                             ),
//                           ] else ...[
//                             if (!driverReached) ...[
//                               Column(
//                                 children: [
//                                   ListTile(
//                                     trailing: GestureDetector(
//                                       onTap: () {
//                                         Navigator.push(
//                                           context,
//                                           MaterialPageRoute(
//                                             builder:
//                                                 (context) => ChatScreen(
//                                                   bookingId: widget.bookingId,
//                                                 ),
//                                           ),
//                                         );
//                                       },
//                                       child: Container(
//                                         decoration: BoxDecoration(
//                                           color: AppColors.commonBlack
//                                               .withOpacity(0.1),
//                                           borderRadius: BorderRadius.circular(
//                                             30,
//                                           ),
//                                         ),
//                                         child: Padding(
//                                           padding: const EdgeInsets.all(10),
//                                           child: Image.asset(
//                                             AppImages.msg,
//                                             height: 25,
//                                             width: 25,
//                                           ),
//                                         ),
//                                       ),
//                                     ),
//                                     leading: GestureDetector(
//                                       onTap: () async {
//                                         const phoneNumber = 'tel:+918248191110';
//                                         CommonLogger.log.i(phoneNumber);
//                                         final Uri url = Uri.parse(phoneNumber);
//                                         if (await canLaunchUrl(url)) {
//                                           await launchUrl(url);
//                                         } else {
//                                           // Optionally show a toast/snackbar
//                                           print('Could not launch dialer');
//                                         }
//                                       },
//                                       child: Container(
//                                         decoration: BoxDecoration(
//                                           color: AppColors.commonBlack
//                                               .withOpacity(0.1),
//                                           borderRadius: BorderRadius.circular(
//                                             30,
//                                           ),
//                                         ),
//                                         child: Padding(
//                                           padding: const EdgeInsets.all(10),
//                                           child: Image.asset(
//                                             AppImages.call,
//                                             height: 25,
//                                             width: 25,
//                                           ),
//                                         ),
//                                       ),
//                                     ),
//
//                                     // title: Center(
//                                     //   child: CustomTextfield.textWithStyles600(
//                                     //     fontSize: 20,
//                                     //     '$DRIVERTIME Away',
//                                     //   ),
//                                     // ),
//                                     title: Center(
//                                       child: Obx(
//                                         () => CustomTextfield.textWithStyles600(
//                                           formatDuration(
//                                             driverStatusController
//                                                 .pickupDurationInMin
//                                                 .value,
//                                           ),
//                                           fontSize: 20,
//                                         ),
//                                       ),
//                                     ),
//
//                                     subtitle: Center(
//                                       child:
//                                           CustomTextfield.textWithStylesSmall(
//                                             fontSize: 14,
//                                             colors: AppColors.textColorGrey,
//                                             'Picking up $CUSTOMERNAME',
//                                           ),
//                                     ),
//                                   ),
//                                   Padding(
//                                     padding: const EdgeInsets.symmetric(
//                                       vertical: 5,
//                                       horizontal: 15,
//                                     ),
//                                     child: Divider(
//                                       color: AppColors.dividerColor1,
//                                     ),
//                                   ),
//                                   Padding(
//                                     padding: const EdgeInsets.symmetric(
//                                       vertical: 5,
//                                       horizontal: 15,
//                                     ),
//                                     child: GestureDetector(
//                                       onTap: () {
//                                         setState(() {
//                                           driverReached = !driverReached;
//                                         });
//                                       },
//                                       child: Row(
//                                         children: [
//                                           CachedNetworkImage(
//                                             imageUrl: cutomerProfile,
//                                             height: 25,
//                                             width: 25,
//                                             fit: BoxFit.contain,
//                                             placeholder:
//                                                 (
//                                                   context,
//                                                   url,
//                                                 ) => const SizedBox(
//                                                   height: 25,
//                                                   width: 25,
//                                                   child:
//                                                       CircularProgressIndicator(
//                                                         strokeWidth: 2,
//                                                       ),
//                                                 ),
//                                             errorWidget:
//                                                 (context, url, error) =>
//                                                     const Icon(
//                                                       Icons.person,
//                                                       size: 25,
//                                                       color: Colors.black,
//                                                     ),
//                                           ),
//                                           SizedBox(width: 15),
//                                           CustomTextfield.textWithStyles600(
//                                             CUSTOMERNAME,
//                                             fontSize: 20,
//                                           ),
//                                         ],
//                                       ),
//                                     ),
//                                   ),
//                                   Padding(
//                                     padding: const EdgeInsets.symmetric(
//                                       vertical: 5,
//                                       horizontal: 15,
//                                     ),
//                                     child: Divider(
//                                       color: AppColors.dividerColor1,
//                                     ),
//                                   ),
//                                   const SizedBox(height: 15),
//                                 ],
//                               ),
//                             ] else ...[
//                               const SizedBox(height: 10),
//                               Padding(
//                                 padding: const EdgeInsets.symmetric(
//                                   horizontal: 20,
//                                 ),
//                                 child: Column(
//                                   children: [
//                                     Buttons.button(
//                                       buttonColor: AppColors.resendBlue,
//                                       borderRadius: 8,
//                                       onTap: () async {
//                                         final result =
//                                             await driverStatusController
//                                                 .driverArrived(
//                                                   context,
//                                                   bookingId: widget.bookingId,
//                                                 );
//
//                                         if (result != null &&
//                                             result.status == 200) {
//                                           // ✅ API success, start timer
//                                           setState(() {
//                                             arrivedAtPickup = false;
//                                             _seconds = 300;
//                                           });
//                                           _startTimer();
//                                         } else {
//                                           // ❌ API failed, show error
//                                           ScaffoldMessenger.of(
//                                             context,
//                                           ).showSnackBar(
//                                             SnackBar(
//                                               content: Text(
//                                                 result?.message ??
//                                                     "Something went wrong",
//                                               ),
//                                             ),
//                                           );
//                                         }
//                                       },
//
//                                       // onTap: () {
//                                       //   setState(() {
//                                       //     arrivedAtPickup = false;
//                                       //     _seconds = 300;
//                                       //   });
//                                       //   _startTimer();
//                                       //   driverStatusController.driverArrived(
//                                       //     context,
//                                       //     bookingId: widget.bookingId,
//                                       //   );
//                                       // },
//                                       text:
//                                           driverStatusController
//                                                   .arrivedIsLoading
//                                                   .value
//                                               ? SizedBox(
//                                                 height: 20,
//                                                 width: 20,
//                                                 child:
//                                                     AppLoader.circularLoader(),
//                                               )
//                                               : Text('Arrived at Pickup Point'),
//                                     ),
//                                     const SizedBox(height: 20),
//                                     GestureDetector(
//                                       onTap: () {
//                                         // setState(() {
//                                         //   driverReached = !driverReached;
//                                         // });
//                                       },
//                                       child: Row(
//                                         children: [
//                                           Padding(
//                                             padding: const EdgeInsets.all(5),
//                                             child: ClipOval(
//                                               child: CachedNetworkImage(
//                                                 imageUrl: cutomerProfile,
//                                                 height:
//                                                     45, // make it a bit bigger for clarity
//                                                 width: 45,
//                                                 fit: BoxFit.cover,
//                                                 placeholder:
//                                                     (
//                                                       context,
//                                                       url,
//                                                     ) => const SizedBox(
//                                                       height: 40,
//                                                       width: 40,
//                                                       child:
//                                                           CircularProgressIndicator(
//                                                             strokeWidth: 2,
//                                                           ),
//                                                     ),
//                                                 errorWidget:
//                                                     (context, url, error) =>
//                                                         const Icon(
//                                                           Icons.person,
//                                                           size: 30,
//                                                           color: Colors.black,
//                                                         ),
//                                               ),
//                                             ),
//                                           ),
//
//                                           SizedBox(width: 10),
//                                           CustomTextfield.textWithStyles600(
//                                             CUSTOMERNAME,
//                                             fontSize: 20,
//                                           ),
//                                         ],
//                                       ),
//                                     ),
//                                     const SizedBox(height: 15),
//                                     Container(
//                                       decoration: BoxDecoration(
//                                         color: AppColors.containerColor1,
//                                       ),
//                                       child: Padding(
//                                         padding: const EdgeInsets.symmetric(
//                                           horizontal: 30,
//                                           vertical: 10,
//                                         ),
//                                         child: Row(
//                                           mainAxisAlignment:
//                                               MainAxisAlignment.spaceBetween,
//                                           children: [
//                                             CustomTextfield.textWithImage(
//                                               colors: AppColors.commonBlack,
//                                               fontWeight: FontWeight.w500,
//                                               fontSize: 12,
//                                               text: 'Get Help',
//                                               imagePath: AppImages.getHelp,
//                                             ),
//                                             SizedBox(
//                                               height: 20,
//                                               child: VerticalDivider(),
//                                             ),
//                                             CustomTextfield.textWithImage(
//                                               colors: AppColors.commonBlack,
//                                               fontWeight: FontWeight.w500,
//                                               fontSize: 12,
//                                               text: 'Share Trip Status',
//                                               imagePath: AppImages.share,
//                                             ),
//                                           ],
//                                         ),
//                                       ),
//                                     ),
//                                     const SizedBox(height: 20),
//                                   ],
//                                 ),
//                               ),
//                             ],
//
//                             Padding(
//                               padding: const EdgeInsets.symmetric(
//                                 horizontal: 20,
//                               ),
//                               child: Column(
//                                 crossAxisAlignment: CrossAxisAlignment.start,
//                                 children: [
//                                   Padding(
//                                     padding: const EdgeInsets.symmetric(
//                                       horizontal: 15,
//                                     ),
//                                     child: CustomTextfield.textWithStyles600(
//                                       'Ride Details',
//                                       fontSize: 16,
//                                     ),
//                                   ),
//                                   const SizedBox(height: 20),
//                                   Row(
//                                     children: [
//                                       Container(
//                                         decoration: BoxDecoration(
//                                           borderRadius: BorderRadius.circular(
//                                             40,
//                                           ),
//                                           color: AppColors.commonBlack
//                                               .withOpacity(0.1),
//                                         ),
//                                         child: Padding(
//                                           padding: const EdgeInsets.all(4),
//                                           child: Icon(
//                                             Icons.circle,
//                                             color: AppColors.commonBlack,
//                                             size: 10,
//                                           ),
//                                         ),
//                                       ),
//                                       SizedBox(width: 20),
//                                       Expanded(
//                                         child: Column(
//                                           crossAxisAlignment:
//                                               CrossAxisAlignment.start,
//                                           children: [
//                                             CustomTextfield.textWithStyles600(
//                                               fontSize: 16,
//                                               'Pickup',
//                                             ),
//                                             CustomTextfield.textWithStylesSmall(
//                                               colors: AppColors.textColorGrey,
//                                               maxLine: 2,
//                                               widget.pickupLocationAddress ??
//                                                   '',
//                                             ),
//                                           ],
//                                         ),
//                                       ),
//                                     ],
//                                   ),
//                                   const SizedBox(height: 20),
//                                   Row(
//                                     children: [
//                                       Container(
//                                         decoration: BoxDecoration(
//                                           borderRadius: BorderRadius.circular(
//                                             40,
//                                           ),
//                                           color: AppColors.commonBlack
//                                               .withOpacity(0.1),
//                                         ),
//                                         child: Padding(
//                                           padding: const EdgeInsets.all(4),
//                                           child: Icon(
//                                             Icons.circle,
//                                             color: AppColors.grey,
//                                             size: 10,
//                                           ),
//                                         ),
//                                       ),
//                                       SizedBox(width: 20),
//                                       Expanded(
//                                         child: Column(
//                                           crossAxisAlignment:
//                                               CrossAxisAlignment.start,
//                                           children: [
//                                             CustomTextfield.textWithStyles600(
//                                               fontSize: 16,
//                                               'Drop off - Constitution Ave',
//                                             ),
//                                             CustomTextfield.textWithStylesSmall(
//                                               widget.dropLocationAddress ?? '',
//                                               colors: AppColors.textColorGrey,
//                                               maxLine: 2,
//                                             ),
//                                           ],
//                                         ),
//                                       ),
//                                     ],
//                                   ),
//                                   SizedBox(height: 20),
//                                   Buttons.button(
//                                     borderColor: AppColors.buttonBorder,
//                                     buttonColor: AppColors.commonWhite,
//                                     borderRadius: 8,
//
//                                     textColor: AppColors.commonBlack,
//
//                                     onTap: () {
//                                       Buttons.showDialogBox(context: context);
//                                     },
//                                     text: Text('Stop New Ride Request'),
//                                   ),
//                                   SizedBox(height: 10),
//                                   Buttons.button(
//                                     borderRadius: 8,
//
//                                     buttonColor: AppColors.red,
//
//                                     onTap: () {
//                                       Buttons.showCancelRideBottomSheet(
//                                         context,
//                                         onConfirmCancel: (reason) {
//                                           print(
//                                             "User selected reason: $reason",
//                                           );
//                                           driverStatusController.cancelBooking(
//                                             bookingId: widget.bookingId,
//                                             context,
//                                             reason: reason,
//                                           );
//                                         },
//                                       );
//                                     },
//                                     text: Text('Cancel this Ride'),
//                                   ),
//                                   SizedBox(height: 15),
//                                 ],
//                               ),
//                             ),
//                           ],
//                         ],
//                       ),
//                     );
//                   },
//                 ),
//                 if (!arrivedAtPickup)
//                   Positioned(
//                     bottom: showRedTimer ? 285 : 240,
//                     left: 0,
//                     right: 0,
//                     child: Center(
//                       child: Container(
//                         padding: const EdgeInsets.symmetric(
//                           horizontal: 22,
//                           vertical: 7,
//                         ),
//                         decoration: BoxDecoration(
//                           color: Colors.white,
//                           borderRadius: BorderRadius.circular(30),
//                           border: Border.all(
//                             color:
//                                 showRedTimer
//                                     ? AppColors.timerBorderColor
//                                     : AppColors.commonBlack.withOpacity(0.2),
//
//                             width: 6,
//                           ),
//                         ),
//                         child: Text(
//                           timerText,
//                           style: TextStyle(
//                             fontSize: 15,
//                             fontWeight: FontWeight.bold,
//                             letterSpacing: 1.5,
//                             color:
//                                 showRedTimer
//                                     ? AppColors.timerBorderColor
//                                     : AppColors.commonBlack,
//                           ),
//                         ),
//                       ),
//                     ),
//                   ),
//               ],
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
