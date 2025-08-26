import 'dart:async';
import 'dart:math';
import 'dart:math' as math;
import 'package:action_slider/action_slider.dart';
import 'package:flutter/services.dart';
import 'package:flutter_compass/flutter_compass.dart';
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
  LatLng? driverLocation;
  late SocketService socketService;
  LatLng? nextPoint;
  bool showArrivedButton = false;
  late LatLng customerFroms;
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

  // late LatLng customerTo;
  String customerTo = '';
  late LatLng driverCurrentLatLng;
  String profilePic = '';
  String custName = '';
  String plateNumber = '';
  String driverName = '';
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

  Future<void> _loadMarkerIcons() async {
    carIcon = await BitmapDescriptor.asset(
      height: 70,
      const ImageConfiguration(size: Size(50, 50)),
      AppImages.movingCar,
    );

    setState(() {});
  }

  void _startTimer() {
    _timer?.cancel();
    _seconds = 300;
    showRedTimer = false;

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_seconds > 0) {
        setState(() {
          _seconds--;

          // ✅ Show red only when less than or equal to 10 seconds
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
      final String driverId = data['driverId'] ?? '';
      final String driverFullName = data['driverName'] ?? '';
      final double rating =
          double.tryParse(data['driverRating'].toString()) ?? 0.0;
      final String color = vehicle['color'] ?? '';
      final String model = vehicle['model'] ?? '';
      final String customerName = data['customerName'] ?? '';
      final String customerPhone = data['customerPhone'] ?? '';
      final String driverDistanceInMeters =
          data['driverDistanceInMeters']?.toString() ?? '';
      final String estimatedArrivalTimeInMin =
          data['estimatedArrivalTimeInMin']?.toString() ?? '';
      final String rideDistanceInMeters =
          data['rideDistanceInMeters']?.toString() ?? '';
      final String estimatedRideTimeInMin =
          data['estimatedRideTimeInMin']?.toString() ?? '';
      final String type = vehicle['type'] ?? '';
      final String plate = vehicle['plateNumber'] ?? '';
      final bool driverAccepted = data['driver_accept_status'] == true;
      final customerLoc = data['customerLocation'];
      double fromLat = customerLoc['fromLatitude'];
      double fromLng = customerLoc['fromLongitude'];
      double toLat = customerLoc['toLatitude'];
      double toLng = customerLoc['toLongitude'];

      final LatLng customerFromLatLng = LatLng(
        customerLoc['fromLatitude'],
        customerLoc['fromLongitude'],
      );
      final LatLng customerToLatLng = LatLng(
        customerLoc['toLatitude'],
        customerLoc['toLongitude'],
      );

      final driverLocation = data['driverLocation'];
      final LatLng driverLatLng = LatLng(
        driverLocation['latitude'],
        driverLocation['longitude'],
      );

      // Extract profile and car photo
      final String picUrl = data['profilePic'] ?? '';

      final List<dynamic> carPhotos = List.from(
        data['carExteriorPhotos'] ?? [],
      );
      String pickupAddrs = await getAddressFromLatLng(fromLat, fromLng);
      String dropoffAddrs = await getAddressFromLatLng(toLat, toLng);
      setState(() {
        plateNumber = plate;
        driverName = '$driverFullName';
        carDetails = '$color - $type $model';
        isDriverConfirmed = driverAccepted;
        pickupAddress = pickupAddrs;

        customerFrom = pickupAddrs;
        CUSTOMERNAME = customerName;
        CUSTOMERPHN = customerPhone;

        customerTo = dropoffAddrs;
        driverCurrentLatLng = driverLatLng;
        driverProfilePic = profilePic;
        carExteriorImages = carPhotos.map((e) => e.toString()).toList();
      });

      CommonLogger.log.i("🚕 Driver confirmed: $driverAccepted");
      CommonLogger.log.i("🚕 Driver name: $driverFullName");
      CommonLogger.log.i("🚕 Plate number: $plate");
    });

    // Debug: See all events
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

      if (data != null) {
        if (data['status'] == true) {
          Get.offAll(() => DriverMainScreen());
        }
      }
    });
    socketService.on('customer-cancelled', (data) async {
      CommonLogger.log.i('customer-cancelled : $data');

      if (data != null) {
        if (data['status'] == true) {
          Get.offAll(() => DriverMainScreen());
        }
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

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark, // Or light
      ),
    );
    _initSocketAndLocation();
    _loadMarkerIcons();

    _getInitialDriverLocation();
    // _startTimer();
  }

  @override
  void dispose() {
    positionStream?.cancel();
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _getInitialDriverLocation() async {
    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    driverLocation = LatLng(position.latitude, position.longitude);

    final result = await getRouteInfo(
      origin: driverLocation!,
      destination: widget.pickupLocation,
    );

    setState(() {
      directionText = result['direction'];
      distance = result['distance'];
      polylinePoints = decodePolyline(result['polyline']);
      if (polylinePoints.length >= 2) {
        nextPoint = polylinePoints[1];
      } else if (polylinePoints.length == 1) {
        nextPoint = polylinePoints[0];
      }
    });

    _startDriverTracking();
  }

  Future<void> loadRoute() async {
    final result = await getRouteInfo(
      origin: driverLocation!,
      destination: widget.pickupLocation,
    );

    setState(() {
      directionText = result['direction'];
      distance = result['distance'];
      maneuver = result['maneuver']; // ADD THIS!
      polylinePoints = decodePolyline(result['polyline']);
      if (polylinePoints.length >= 2) {
        nextPoint = polylinePoints[1]; // the point the car is moving towards
      } else if (polylinePoints.length == 1) {
        nextPoint = polylinePoints[0]; // fallback
      }
    });
  }

  Future<void> _fetchRoute() async {
    if (driverLocation == null) return;

    final result = await getRouteInfo(
      origin: driverLocation!, // 🚗 Driver
      destination: widget.pickupLocation, // 🧍 Customer
    );

    setState(() {
      polylinePoints = decodePolyline(result['polyline']);
      if (polylinePoints.length >= 2) {
        nextPoint = polylinePoints[1];
      }
    });
  }

  void _startDriverTracking() {
    positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 5,
      ),
    ).listen((position) {
      final current = LatLng(position.latitude, position.longitude);

      if (lastPosition != null) {
        final distanceMoved = Geolocator.distanceBetween(
          lastPosition!.latitude,
          lastPosition!.longitude,
          current.latitude,
          current.longitude,
        );

        if (distanceMoved < 8) {
          print("🔴 Ignored minor movement: $distanceMoved m");
          return;
        }

        // ✅ only call bearing if lastPosition is not null
        final rotation = _getBearing(lastPosition!, current);
        setState(() {
          _currentMapBearing = rotation;
        });
      }

      if (!isAnimating) {
        if (isOffRoute(current)) {
          print("🧭 Off route! Recalculating...");
          _fetchUpdatedRoute(current);
        }

        _animateCarTo(current);
      }

      fitBoundsToDriverAndPickup();

      // ✅ update last position after handling
      lastPosition = current;
    });

    // positionStream = Geolocator.getPositionStream(
    //   locationSettings: LocationSettings(
    //     accuracy: LocationAccuracy.bestForNavigation,
    //     distanceFilter: 5,
    //   ),
    // ).listen((position)
    // {
    //   final current = LatLng(position.latitude, position.longitude);
    //
    //   if (lastPosition != null) {
    //     final distanceMoved = Geolocator.distanceBetween(
    //       lastPosition!.latitude,
    //       lastPosition!.longitude,
    //       current.latitude,
    //       current.longitude,
    //     );
    //
    //     if (distanceMoved < 8) {
    //       print("🔴 Ignored minor movement: $distanceMoved m");
    //       return;
    //     }
    //   }
    //   final rotation = _getBearing(lastPosition!, current);
    //   setState(() {
    //     _currentMapBearing = rotation;
    //   });
    //
    //   if (!isAnimating) {
    //     if (isOffRoute(current)) {
    //       print("🧭 Off route! Recalculating...");
    //       _fetchUpdatedRoute(current); // 👇 This fetches a new route
    //     }
    //
    //     _animateCarTo(current);
    //   }
    //   fitBoundsToDriverAndPickup();
    //   // Always update last known position
    //   lastPosition = current;
    // });
  }

  Future<void> _fetchUpdatedRoute(LatLng currentLocation) async {
    final result = await getRouteInfo(
      origin: currentLocation,
      destination: widget.pickupLocation,
    );

    setState(() {
      polylinePoints = decodePolyline(result['polyline']);
      directionText = result['direction'];
      distance = result['distance'];
      maneuver = result['maneuver'];

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

  /*  Future<void> _animateCarTo(LatLng to) async {
    if (driverLocation == null || _isSameLocation(driverLocation!, to)) {
      print("⚠️ Skipping animation: same location");
      return;
    }

    isAnimating = true;
    const steps = 20;
    const duration = Duration(milliseconds: 800);
    final interval = duration.inMilliseconds ~/ steps;

    for (int i = 1; i <= steps; i++) {
      await Future.delayed(Duration(milliseconds: interval));

      final lat = _lerp(driverLocation!.latitude, to.latitude, i / steps);
      final lng = _lerp(driverLocation!.longitude, to.longitude, i / steps);

      setState(() {
        driverLocation = LatLng(lat, lng);
      });
    }

    isAnimating = false;

    _updateRemainingPolyline(to);
  }*/

  Future<void> _animateCarTo(LatLng to) async {
    if (driverLocation == null || _isSameLocation(driverLocation!, to)) {
      return;
    }

    isAnimating = true;
    const steps = 10;
    const duration = Duration(milliseconds: 800);
    final interval = duration.inMilliseconds ~/ steps;

    final startBearing = carBearing;
    final endBearing = _getBearing(driverLocation!, to);

    for (int i = 1; i <= steps; i++) {
      await Future.delayed(Duration(milliseconds: interval));

      final lat = _lerp(driverLocation!.latitude, to.latitude, i / steps);
      final lng = _lerp(driverLocation!.longitude, to.longitude, i / steps);
      final newBearing = _lerp(startBearing, endBearing, i / steps);

      setState(() {
        driverLocation = LatLng(lat, lng);
        carBearing = newBearing;
      });

      // Keep map centered & rotated with car
      _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(lat, lng),
            zoom: 18,
            bearing: carBearing, // 🔄 rotate map with car
            tilt: 60,
          ),
        ),
      );
    }

    isAnimating = false;
    _updateRemainingPolyline(to);
  }

  double _lerp(double start, double end, double t) {
    return start + (end - start) * t;
  }

  void _updateRemainingPolyline(LatLng currentLocation) async {
    int closestIndex = _getClosestPolylinePointIndex(currentLocation);
    if (closestIndex != -1 && closestIndex < polylinePoints.length) {
      polylinePoints = polylinePoints.sublist(closestIndex);
      if (polylinePoints.length >= 2) {
        nextPoint = polylinePoints[1];
        final result = await getRouteInfo(
          origin: currentLocation,
          destination: widget.pickupLocation,
        );

        updateDirectionInfo(
          newDirectionText: parseHtmlString(result['direction']),
          newDistance: result['distance'],
          newManeuver: result['maneuver'],
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
    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    final latLng = LatLng(position.latitude, position.longitude);
    CommonLogger.log.i('Current Loc :${latLng}');

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
    setState(() {
      directionText = newDirectionText;
      distance = newDistance;
      maneuver = newManeuver;
    });
  }

  String getManeuverIcon(maneuver) {
    switch (maneuver) {
      case "turn-right":
        return 'assets/images/straight.png';
      case "turn-left":
        return 'assets/images/straight.png';
      case "straight":
        return 'assets/images/straight.png';
      case "merge":
        return 'assets/images/straight.png';
      case "roundabout-left":
        return 'assets/images/straight.png';
      case "roundabout-right":
        return 'assets/images/straight.png';
      default:
        return 'assets/images/straight.png';
    }
  }

  void fitBoundsToDriverAndPickup() {
    if (_mapController == null ||
        driverLocation == null ||
        widget.pickupLocation == null)
      return;

    final bounds = LatLngBounds(
      southwest: LatLng(
        min(driverLocation!.latitude, widget.pickupLocation.latitude),
        min(driverLocation!.longitude, widget.pickupLocation.longitude),
      ),
      northeast: LatLng(
        max(driverLocation!.latitude, widget.pickupLocation.latitude),
        max(driverLocation!.longitude, widget.pickupLocation.longitude),
      ),
    );

    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 60), // adjust padding
    );
  }

  bool isOffRoute(LatLng currentLocation) {
    if (polylinePoints.isEmpty) return true;

    for (final point in polylinePoints) {
      final distance = Geolocator.distanceBetween(
        currentLocation.latitude,
        currentLocation.longitude,
        point.latitude,
        point.longitude,
      );

      if (distance < 20) return false; // within 20 meters = on route
    }

    return true; // 🚨 Off the route
  }

  @override
  Widget build(BuildContext context) {
    final markers = <Marker>{
      Marker(
        markerId: const MarkerId('driver'),
        position: driverLocation ?? const LatLng(0, 0),
        icon: carIcon ?? BitmapDescriptor.defaultMarker,
        rotation: carBearing, // ✅ use stored rotation
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
                  String style = await DefaultAssetBundle.of(
                    context,
                  ).loadString('assets/map_style/map_style1.json');
                  _mapController!.setMapStyle(style);
                },
                initialPosition: widget.pickupLocation,
                markers: markers,
                polylines: {
                  Polyline(
                    polylineId: PolylineId("route"),
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

                            SizedBox(height: 5),
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
                              '${parseHtmlString(directionText)}',
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

                  /* initialChildSize: arrivedAtPickup ? 0.55 : 0.35,
                  minChildSize: arrivedAtPickup ? 0.40 : 0.35,
                  maxChildSize: arrivedAtPickup ? 0.63 : 0.36,*/
                  // initialChildSize: 0.50, // Start with 80% height
                  // minChildSize: 0.5, // Can collapse to 40%
                  // maxChildSize: 0.65, // Can expand up to 95% height
                  builder: (context, scrollController) {
                    return Container(
                      decoration: BoxDecoration(color: Colors.white),
                      child: ListView(
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
                          SizedBox(height: 10),
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
                                              print(
                                                "User selected reason: $reason",
                                              );
                                              driverStatusController
                                                  .cancelBooking(
                                                    bookingId: widget.bookingId,
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
                                        borderRadius: BorderRadius.circular(30),
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
                                      CommonLogger.log.i(phoneNumber);
                                      final Uri url = Uri.parse(phoneNumber);
                                      if (await canLaunchUrl(url)) {
                                        await launchUrl(url);
                                      } else {
                                        print('Could not launch dialer');
                                      }
                                    },
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: AppColors.commonBlack
                                            .withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(30),
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
                                    child: CustomTextfield.textWithStyles600(
                                      fontSize: 20,
                                      'Waiting for the Rider',
                                    ),
                                  ),
                                  subtitle: Center(
                                    child: CustomTextfield.textWithStylesSmall(
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
                                    action: (controller) async {
                                      controller.loading();
                                      await Future.delayed(
                                        const Duration(seconds: 1),
                                      );
                                      final message =
                                          await driverStatusController
                                              .otpRequest(
                                                pickupAddress:
                                                    widget
                                                        .pickupLocationAddress ??
                                                    '',
                                                dropAddress:
                                                    widget
                                                        .dropLocationAddress ??
                                                    '',
                                                custName: CUSTOMERNAME,
                                                context,
                                                bookingId: widget.bookingId,
                                              );

                                      if (message != null) {
                                        controller.success();
                                        if (_timer != null &&
                                            _timer!.isActive) {
                                          _timer!.cancel();
                                          _timer = null;
                                        }

                                        // ScaffoldMessenger.of(context).showSnackBar(
                                        //   SnackBar(content: Text(message)),
                                        // );
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
                                        const phoneNumber = 'tel:+918248191110';
                                        CommonLogger.log.i(phoneNumber);
                                        final Uri url = Uri.parse(phoneNumber);
                                        if (await canLaunchUrl(url)) {
                                          await launchUrl(url);
                                        } else {
                                          // Optionally show a toast/snackbar
                                          print('Could not launch dialer');
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

                                    // title: Center(
                                    //   child: CustomTextfield.textWithStyles600(
                                    //     fontSize: 20,
                                    //     '$DRIVERTIME Away',
                                    //   ),
                                    // ),
                                    title: Center(
                                      child: Obx(
                                        () => CustomTextfield.textWithStyles600(
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
                                          Image.asset(
                                            AppImages.dummyImg,
                                            height: 45,
                                            width: 45,
                                          ),
                                          SizedBox(width: 15),
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
                                          // ✅ API success, start timer
                                          setState(() {
                                            arrivedAtPickup = false;
                                            _seconds = 300;
                                          });
                                          _startTimer();
                                        } else {
                                          // ❌ API failed, show error
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

                                      // onTap: () {
                                      //   setState(() {
                                      //     arrivedAtPickup = false;
                                      //     _seconds = 300;
                                      //   });
                                      //   _startTimer();
                                      //   driverStatusController.driverArrived(
                                      //     context,
                                      //     bookingId: widget.bookingId,
                                      //   );
                                      // },
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
                                              : Text('Arrived at Pickup Point'),
                                    ),
                                    const SizedBox(height: 20),
                                    GestureDetector(
                                      onTap: () {
                                        // setState(() {
                                        //   driverReached = !driverReached;
                                        // });
                                      },
                                      child: Row(
                                        children: [
                                          Image.asset(
                                            AppImages.dummyImg,
                                            height: 45,
                                            width: 45,
                                          ),
                                          SizedBox(width: 15),
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
                                            SizedBox(
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
                                        child: Padding(
                                          padding: const EdgeInsets.all(4),
                                          child: Icon(
                                            Icons.circle,
                                            color: AppColors.commonBlack,
                                            size: 10,
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: 20),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            CustomTextfield.textWithStyles600(
                                              fontSize: 16,
                                              'Pickup',
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
                                      SizedBox(width: 20),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            CustomTextfield.textWithStyles600(
                                              fontSize: 16,
                                              'Drop off - Constitution Ave',
                                            ),
                                            CustomTextfield.textWithStylesSmall(
                                              widget.dropLocationAddress ?? '',
                                              colors: AppColors.textColorGrey,
                                              maxLine: 2,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 20),
                                  Buttons.button(
                                    borderColor: AppColors.buttonBorder,
                                    buttonColor: AppColors.commonWhite,
                                    borderRadius: 8,

                                    textColor: AppColors.commonBlack,

                                    onTap: () {
                                      Buttons.showDialogBox(context: context);
                                    },
                                    text: Text('Stop New Ride Request'),
                                  ),
                                  SizedBox(height: 10),
                                  Buttons.button(
                                    borderRadius: 8,

                                    buttonColor: AppColors.red,

                                    onTap: () {
                                      Buttons.showCancelRideBottomSheet(
                                        context,
                                        onConfirmCancel: (reason) {
                                          print(
                                            "User selected reason: $reason",
                                          );
                                          driverStatusController.cancelBooking(
                                            bookingId: widget.bookingId,
                                            context,
                                            reason: reason,
                                          );
                                        },
                                      );
                                    },
                                    text: Text('Cancel this Ride'),
                                  ),
                                  SizedBox(height: 15),
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
    );
  }
}
