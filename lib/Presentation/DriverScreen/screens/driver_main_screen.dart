import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geocoding/geocoding.dart';
import 'package:hopper/Core/Constants/log.dart';
import 'package:hopper/Core/Utility/app_loader.dart';
import 'package:hopper/Presentation/Drawer/screens/drawer_screens.dart';
import 'package:hopper/Presentation/DriverScreen/screens/picking_customer_screen.dart';
import 'package:hopper/utils/sharedprefsHelper/sharedprefs_handler.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:hopper/Core/Utility/Buttons.dart';
import '../../../utils/netWorkHandling/network_handling_screen.dart';
import '../../../utils/sharedprefsHelper/booking_local_data.dart';
import '../../../utils/websocket/socket_io_client.dart';
import '../../Authentication/screens/GetStarted_Screens.dart';
import '../../Authentication/widgets/textFields.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:hopper/Core/Constants/Colors.dart';
import 'package:hopper/Core/Utility/images.dart';
import 'package:get/get.dart';
import 'package:hopper/Presentation/DriverScreen/controller/driver_status_controller.dart';

import '../../Drawer/controller/ride_history_controller.dart';

class DriverMainScreen extends StatefulWidget {
  const DriverMainScreen({super.key});

  @override
  State<DriverMainScreen> createState() => _DriverMainScreenState();
}

class _DriverMainScreenState extends State<DriverMainScreen>
    with SingleTickerProviderStateMixin {
  AnimationController? _animationController;
  Tween<double>? _latTween;
  Tween<double>? _lngTween;
  Tween<double>? _rotationTween;
  Animation<double>? _animation;

  final RideHistoryController controller = Get.put(RideHistoryController());
  final DriverStatusController statusController = Get.put(
    DriverStatusController(),
  );
  LatLng? _currentPosition;
  GoogleMapController? _mapController;
  bool _isAcceptingRide = false;
  int remainingSeconds = 15;
  Timer? _timer;

  bool isOnline = false;
  bool driverAccepted = false;
  Map<String, dynamic>? bookingRequestData;
  double _heading = 0;
  Marker? _carMarker;
  late SocketService socketService;
  StreamSubscription<Position>? _positionStream;
  StreamSubscription<CompassEvent>? _compassStream;

  BitmapDescriptor? _carIcon;
  // void _startCompass() {
  //   _compassStream = FlutterCompass.events?.listen((event) {
  //     if (event.heading != null && mounted) {
  //       setState(() {
  //         _heading = event.heading!;
  //       });
  //       _updateCarMarker();
  //     }
  //   });
  // }

  double getFixedRotation(double heading) {
    if (heading < 0 || heading > 360) return 0;

    if (heading >= 315 || heading < 45) return 0; // North
    if (heading >= 45 && heading < 135) return 90; // East
    if (heading >= 135 && heading < 225) return 180; // South
    if (heading >= 225 && heading < 315) return 270; // West

    return 0;
  }

  String getDirectionLabel(double heading) {
    if (heading >= 315 || heading < 45) return 'North';
    if (heading >= 45 && heading < 135) return 'East';
    if (heading >= 135 && heading < 225) return 'South';
    if (heading >= 225 && heading < 315) return 'West';
    return 'Unknown';
  }

  LatLng? _lastPosition;
  void _updateCarMarker(LatLng newPosition) {
    if (!mounted) return; // <- Prevent running after dispose
    if (_carIcon == null) return;

    if (_lastPosition == null) {
      // First time placement
      _carMarker = Marker(
        markerId: const MarkerId('car'),
        position: newPosition,
        icon: _carIcon!,
        rotation: 0,
        anchor: const Offset(0.5, 0.5),
        flat: true,
      );
      _lastPosition = newPosition;
      setState(() {});
      return;
    }

    double bearing = _bearingBetween(_lastPosition!, newPosition);

    _latTween = Tween(
      begin: _lastPosition!.latitude,
      end: newPosition.latitude,
    );
    _lngTween = Tween(
      begin: _lastPosition!.longitude,
      end: newPosition.longitude,
    );
    _rotationTween = Tween(begin: _carMarker?.rotation ?? 0, end: bearing);

    // ✅ Only create controller once
    _animationController ??= AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    // Reset duration if needed
    _animationController!.duration = const Duration(milliseconds: 1500);

    // Reset before starting new animation
    _animationController!.reset();

    _animation ??= CurvedAnimation(
      parent: _animationController!,
      curve: Curves.easeInOut,
    );

    _animationController!.addListener(() {
      final lat = _latTween!.evaluate(_animation!);
      final lng = _lngTween!.evaluate(_animation!);
      final rotation = _rotationTween!.evaluate(_animation!);

      setState(() {
        _carMarker = Marker(
          markerId: const MarkerId('car'),
          position: LatLng(lat, lng),
          icon: _carIcon!,
          rotation: rotation,
          anchor: const Offset(0.5, 0.5),
          flat: true,
        );
      });
    });

    _animationController!.forward();
    _lastPosition = newPosition;
  }

  /*  Future<void> _loadCustomCarIcon() async {
    _carIcon = await BitmapDescriptor.asset(
      const ImageConfiguration(size: Size(37, 37)),
      AppImages.parcelBike,
    );
  }*/
  Future<void> _loadCustomCarIcon() async {
    if (statusController.serviceType.value == "Car") {
      _carIcon = await BitmapDescriptor.asset(
        const ImageConfiguration(size: Size(57, 57)),
        AppImages.movingCar, // <-- your car icon asset
      );
    } else if (statusController.serviceType.value == "Bike") {
      _carIcon = await BitmapDescriptor.asset(
        const ImageConfiguration(size: Size(57, 57)),
        AppImages.parcelBike, // <-- your bike icon asset
      );
    } else {
      // Default marker if service type not matched
      _carIcon = BitmapDescriptor.defaultMarker;
    }
  }

  Color getTextColor({Color color = Colors.black}) =>
      statusController.isOnline.value ? color : Colors.black;

  void _goToCurrentLocation() async {
    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    final latLng = LatLng(position.latitude, position.longitude);

    _mapController?.animateCamera(CameraUpdate.newLatLngZoom(latLng, 17));
  }

  /*  Future<void> _initLocation(BuildContext context) async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      Get.snackbar(
        "Location Disabled",
        "Please enable location services to use the app.",
        snackPosition: SnackPosition.TOP,
      );
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showPermissionDialog(context);
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _showPermissionDialog(context, openSettings: true);
      return;
    }

    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    final userLatLng = LatLng(position.latitude, position.longitude);
    if (!mounted) return; // ✅ Prevent setState after dispose
    setState(() {
      _currentPosition = userLatLng;
    });

    print("📍 Driver Location: ${position.latitude}, ${position.longitude}");

    if (_mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: userLatLng, zoom: 16),
        ),
      );
    }
  }*/
  Future<void> _initLocation(BuildContext context) async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      Get.snackbar(
        "Location Disabled",
        "Please enable location services to use the app.",
      );
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showPermissionDialog(context);
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _showPermissionDialog(context, openSettings: true);
      return;
    }

    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    final userLatLng = LatLng(position.latitude, position.longitude);

    if (!mounted) return;

    setState(() {
      _currentPosition = userLatLng;
    });

    // ✅ Recreate marker immediately when location available
    if (_carIcon != null) {
      _updateCarMarker(userLatLng);
    }

    // ✅ Move camera
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: userLatLng, zoom: 16),
      ),
    );
  }

  void _showPermissionDialog(
    BuildContext context, {
    bool openSettings = false,
  }) {
    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: Text("Permission Required"),
            content: Text(
              openSettings
                  ? "Location permission is permanently denied. Please enable it in settings."
                  : "Location permission is required to continue.",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text("Cancel"),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  if (openSettings) {
                    Geolocator.openAppSettings();
                  } else {
                    Geolocator.requestPermission();
                  }
                },
                child: Text("Allow"),
              ),
            ],
          ),
    );
  }

  late StreamSubscription<Position> _locationStream;
  String? driverId;
  String? _currentBookingId;
  String? pickupAddress;
  String? dropAddress;
  double safeToDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0.0;
  }

  int safeToInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.round(); // or floor()
    return int.tryParse(value.toString()) ?? 0;
  }

  String formatDistance(double meters) {
    double kilometers = meters / 1000;
    return '${kilometers.toStringAsFixed(1)} Km';
  }

  String formatDuration(int minutes) {
    int hours = minutes ~/ 60;
    int remainingMinutes = minutes % 60;
    return hours > 0
        ? '$hours hr $remainingMinutes min'
        : '$remainingMinutes min';
  }

  Future<void> _initSocketAndLocation() async {
    driverId = await SharedPrefHelper.getDriverId();

    if (driverId == null) {
      CommonLogger.log.e('Driver ID is null! Cannot initialize socket.');
      return;
    }

    socketService = SocketService();

    socketService.initSocket(
      'https://hoppr-face-two-dbe557472d7f.herokuapp.com',
    );

    socketService.on('connect', (_) {
      CommonLogger.log.i('🟢 Connected to socket');

      socketService.emit('register', {'userId': driverId, 'type': 'driver'});
    });

    socketService.on('registered', (data) {
      CommonLogger.log.i('✅ Driver Registered: $data');
      Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 0,
        ),
      ).listen((position) {
        final locationData = {
          'userId': driverId,
          'latitude': position.latitude,
          'longitude': position.longitude,
          if (_currentBookingId != null) 'bookingId': _currentBookingId,
        };

        SocketService().emit('updateLocation', locationData);
        final newLatLng = LatLng(position.latitude, position.longitude);
        _updateCarMarker(newLatLng);
        CommonLogger.log.i("📍 Emitting Location: $locationData");
      });

      // _locationStream = Geolocator.getPositionStream(
      //   locationSettings: const LocationSettings(
      //     accuracy: LocationAccuracy.high,
      //     distanceFilter: 0, // Emit even without movement
      //   ),
      // ).listen((position) {
      //   final locationData = {
      //     'userId': driverId,
      //     'latitude': position.latitude,
      //     'longitude': position.longitude,
      //     if (_currentBookingId != null) 'bookingId': _currentBookingId,
      //   };
      //
      //   socketService.emit('updateLocation', locationData);
      //
      //   CommonLogger.log.i("📍 Emitting Location: $locationData");
      // });
    });

    socketService.on('booking-request', (data) async {
      BookingDataService().setBookingData(data);
      CommonLogger.log.i('📦 Booking Request: $data');
      _currentBookingId = data['bookingId'];

      // Get lat/lng from incoming data
      final pickup = data['pickupLocation'];
      final drop = data['dropLocation'];

      // Convert to address
      pickupAddress = await getAddressFromLatLng(
        pickup['latitude'],
        pickup['longitude'],
      );
      dropAddress = await getAddressFromLatLng(
        drop['latitude'],
        drop['longitude'],
      );
      if (!mounted) return;
      setState(() {
        bookingRequestData = data;
      });
      _startTimer();

      CommonLogger.log.i('📍 Pickup: $pickupAddress');
      CommonLogger.log.i('📍 Drop: $dropAddress');
    });

    // socketService.on('driver-arrived', (data) {
    //   CommonLogger.log.i('🚗 Driver arrived: $data');
    // });

    // Initialize location tracking if needed
    _initLocation(context);
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

  String formatCountdown(int seconds) {
    final mins = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return "$mins:$secs";
  }

  double _bearingBetween(LatLng start, LatLng end) {
    double lat1 = start.latitude * (pi / 180.0);
    double lon1 = start.longitude * (pi / 180.0);
    double lat2 = end.latitude * (pi / 180.0);
    double lon2 = end.longitude * (pi / 180.0);

    double dLon = lon2 - lon1;

    double y = sin(dLon) * cos(lat2);
    double x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon);

    double brng = atan2(y, x);

    return (brng * 180 / pi + 360) % 360;
  }

  @override
  void initState() {
    super.initState();
    _prepareApp();
  }

  Future<void> _prepareApp() async {
    // 1. Get service type first
    await statusController.getDriverStatus();

    // 2. Now load the correct car/bike icon
    await _loadCustomCarIcon();

    // 3. Update UI
    setState(() {});

    // 4. Other initializations
    _initSocketAndLocation();

    SchedulerBinding.instance.addPostFrameCallback((_) {
      statusController.weeklyChallenges();
      statusController.todayActivity();
      statusController.todayPackageActivity();
    });
  }

  void _startTimer() {
    _timer?.cancel();
    remainingSeconds = 15;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (remainingSeconds > 0) {
        setState(() {
          remainingSeconds--;
        });
      } else {
        timer.cancel();
        setState(() {
          bookingRequestData = null;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _animationController?.dispose();

    super.dispose();
  }

  bool isonline = false;
  bool status = true;

  @override
  Widget build(BuildContext context) {
    return NoInternetOverlay(
      child: WillPopScope(
        onWillPop: () async {
          return await true;
        },
        child: Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 15),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        InkWell(
                          onTap: () {
                            Get.to(DrawerScreen());
                          },
                          child: Image.asset(
                            AppImages.drawer,
                            height: 28,
                            width: 28,
                          ),
                        ),

                        GestureDetector(
                          onTap: () async {
                            statusController.toggleStatus();
                            final isOnline = statusController.isOnline.value;
                            Position position =
                                await Geolocator.getCurrentPosition(
                                  desiredAccuracy: LocationAccuracy.high,
                                );
                            statusController.onlineAcceptStatus(
                              context,
                              status: isOnline,
                              latitude: position.latitude,
                              longitude: position.longitude,
                            );
                          },
                          // onTap: () => statusController.toggleStatus(),
                          child: Obx(() {
                            final isOnline = statusController.isOnline.value;

                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    isOnline ? AppColors.nBlue : Colors.black,
                                borderRadius: BorderRadius.circular(30),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.25),
                                    offset: const Offset(0, 4),
                                    blurRadius: 10,
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children:
                                    isOnline
                                        ? [
                                          Text(
                                            "Online",
                                            style: TextStyle(
                                              color: Colors.white,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Container(
                                            padding: const EdgeInsets.all(5),
                                            decoration: const BoxDecoration(
                                              color: Colors.white,
                                              shape: BoxShape.circle,
                                            ),
                                            child: Image.asset(
                                              AppImages.offlineCar,
                                              width: 20,
                                              height: 20,
                                              color: AppColors.nBlue,
                                            ),
                                          ),
                                        ]
                                        : [
                                          Container(
                                            padding: const EdgeInsets.all(5),
                                            decoration: const BoxDecoration(
                                              color: Colors.white,
                                              shape: BoxShape.circle,
                                            ),
                                            child: Image.asset(
                                              AppImages.offlineCar,
                                              width: 20,
                                              height: 20,
                                              color: Colors.black,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Text(
                                            "Offline",
                                            style: TextStyle(
                                              color: Colors.white,
                                            ),
                                          ),
                                        ],
                              ),
                            );
                          }),
                        ),
                        // Obx(() {
                        //   final isOnline = statusController.isOnline.value;
                        //   return Image.asset(
                        //     AppImages.search,
                        //     height: 28,
                        //     width: 28,
                        //     color: isOnline ? Colors.black : Colors.grey.shade400,
                        //   );
                        // }),
                        Text(''),
                        // Image.asset(AppImages.search, height: 28, width: 28),
                      ],
                    ),
                  ),

                  const SizedBox(height: 15),

                  Expanded(
                    child: Obx(
                      () => IgnorePointer(
                        ignoring: !statusController.isOnline.value,
                        child: Opacity(
                          opacity: statusController.isOnline.value ? 1.0 : 0.4,
                          child: Stack(
                            children: [
                              SizedBox(
                                height: 350,
                                width: double.infinity,
                                child: GoogleMap(
                                  compassEnabled: false,

                                  initialCameraPosition: CameraPosition(
                                    target: LatLng(0, 0),
                                    zoom: 16,
                                  ),

                                  // onMapCreated: (controller) {
                                  //   _mapController = controller;
                                  //   _initLocation(context);
                                  // },
                                  onMapCreated: (controller) async {
                                    _mapController = controller;
                                    _initLocation(context);

                                    String style = await DefaultAssetBundle.of(
                                      context,
                                    ).loadString(
                                      'assets/map_style/map_style.json',
                                    );
                                    _mapController!.setMapStyle(style);
                                  },
                                  myLocationEnabled: false,
                                  myLocationButtonEnabled: false,
                                  zoomControlsEnabled: false,
                                  markers:
                                      _carMarker != null ? {_carMarker!} : {},
                                  gestureRecognizers: {
                                    Factory<OneSequenceGestureRecognizer>(
                                      () => EagerGestureRecognizer(),
                                    ),
                                  },
                                ),
                              ),

                              Positioned(
                                top: 200,
                                right: 10,
                                child: FloatingActionButton(
                                  mini: true,
                                  backgroundColor: Colors.white,
                                  onPressed: _goToCurrentLocation,
                                  child: const Icon(
                                    Icons.my_location,
                                    color: Colors.black,
                                  ),
                                ),
                              ),

                              if (statusController.serviceType == 'Car') ...[
                                DraggableScrollableSheet(
                                  initialChildSize:
                                      0.65, // Start with 80% height
                                  minChildSize: 0.65,
                                  maxChildSize:
                                      0.80, // Can expand up to 95% height
                                  builder: (context, scrollController) {
                                    return Container(
                                      decoration: const BoxDecoration(
                                        color: Colors.white,
                                        // borderRadius: BorderRadius.vertical(
                                        //   top: Radius.circular(20),
                                        // ),
                                      ),
                                      child: RefreshIndicator(
                                        onRefresh: () async {
                                          await statusController
                                              .weeklyChallenges();
                                          await statusController
                                              .todayActivity();
                                        },
                                        child: ListView(
                                          physics:
                                              const AlwaysScrollableScrollPhysics(
                                                parent: BouncingScrollPhysics(),
                                              ), // Important!
                                          controller: scrollController,
                                          children: [
                                            Center(
                                              child: Container(
                                                width: 40,
                                                height: 4,
                                                margin: const EdgeInsets.only(
                                                  top: 10,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.grey[400],
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                ),
                                              ),
                                            ),

                                            const SizedBox(height: 20),

                                            Center(
                                              child:
                                                  CustomTextfield.textWithStyles700(
                                                    'Hoppr Car',
                                                    color: AppColors.commonBlack
                                                        .withOpacity(0.5),
                                                  ),
                                            ),
                                            if (bookingRequestData != null) ...[
                                              Column(
                                                children: [
                                                  Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .center,
                                                    children: [
                                                      Container(
                                                        padding:
                                                            EdgeInsets.symmetric(
                                                              horizontal: 10,
                                                              vertical: 5,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          color: AppColors.red,
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                5,
                                                              ),
                                                        ),
                                                        child: CustomTextfield.textWithStyles600(
                                                          color:
                                                              AppColors
                                                                  .commonWhite,
                                                          '${formatCountdown(remainingSeconds)} ',
                                                        ),
                                                      ),
                                                      SizedBox(width: 15),
                                                      Text(
                                                        "Respond within 15 seconds",
                                                        style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.w700,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  SizedBox(height: 10),
                                                  Card(
                                                    elevation: 3,
                                                    child: Container(
                                                      decoration: BoxDecoration(
                                                        color:
                                                            AppColors
                                                                .commonWhite,
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              10,
                                                            ),
                                                      ),

                                                      child: Column(
                                                        children: [
                                                          Container(
                                                            width:
                                                                double.infinity,
                                                            height: 54,
                                                            decoration: BoxDecoration(
                                                              borderRadius:
                                                                  BorderRadius.only(
                                                                    topLeft:
                                                                        Radius.circular(
                                                                          10,
                                                                        ),
                                                                    topRight:
                                                                        Radius.circular(
                                                                          10,
                                                                        ),
                                                                  ),
                                                              color:
                                                                  AppColors
                                                                      .nBlue,
                                                            ),
                                                            child: Padding(
                                                              padding:
                                                                  const EdgeInsets.symmetric(
                                                                    horizontal:
                                                                        15,
                                                                  ),
                                                              child: Row(
                                                                children: [
                                                                  Image.asset(
                                                                    AppImages
                                                                        .notification,
                                                                    height: 25,
                                                                    width: 25,
                                                                  ),
                                                                  SizedBox(
                                                                    width: 10,
                                                                  ),
                                                                  CustomTextfield.textWithStyles600(
                                                                    bookingRequestData!['rideType'] ==
                                                                            'Bike'
                                                                        ? 'New Package Request'
                                                                        : 'New Ride Request',
                                                                    color:
                                                                        AppColors
                                                                            .commonWhite,
                                                                  ),

                                                                  Spacer(),
                                                                  CustomTextfield.textWithImage(
                                                                    imageColors:
                                                                        AppColors
                                                                            .commonWhite,
                                                                    text:
                                                                        '${bookingRequestData!['estimatedPrice']}',
                                                                    imagePath:
                                                                        AppImages
                                                                            .bCurrency,
                                                                    colors:
                                                                        AppColors
                                                                            .commonWhite,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w700,
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                          ),
                                                          Padding(
                                                            padding:
                                                                const EdgeInsets.all(
                                                                  8.0,
                                                                ),
                                                            child: Column(
                                                              children: [
                                                                Row(
                                                                  children: [
                                                                    Icon(
                                                                      Icons
                                                                          .circle,
                                                                      color:
                                                                          Colors
                                                                              .green,
                                                                      size: 12,
                                                                    ),
                                                                    SizedBox(
                                                                      width: 8,
                                                                    ),
                                                                    Expanded(
                                                                      child: Text(
                                                                        bookingRequestData!['pickupAddress'] ??
                                                                            '',
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ),
                                                                const SizedBox(
                                                                  height: 8,
                                                                ),
                                                                Row(
                                                                  children: [
                                                                    Icon(
                                                                      Icons
                                                                          .circle,
                                                                      color:
                                                                          Colors
                                                                              .red,
                                                                      size: 12,
                                                                    ),
                                                                    SizedBox(
                                                                      width: 8,
                                                                    ),
                                                                    Expanded(
                                                                      child: Text(
                                                                        bookingRequestData!['dropAddress'] ??
                                                                            "",
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ),
                                                              ],
                                                            ),
                                                          ),

                                                          Padding(
                                                            padding:
                                                                const EdgeInsets.symmetric(
                                                                  horizontal:
                                                                      15,
                                                                ),
                                                            child: Divider(
                                                              color: AppColors
                                                                  .commonBlack
                                                                  .withOpacity(
                                                                    0.1,
                                                                  ),
                                                            ),
                                                          ),

                                                          Padding(
                                                            padding:
                                                                const EdgeInsets.symmetric(
                                                                  horizontal:
                                                                      30,
                                                                ),
                                                            child: Row(
                                                              mainAxisAlignment:
                                                                  MainAxisAlignment
                                                                      .spaceAround,
                                                              children: [
                                                                // Row(
                                                                //   children: [
                                                                //     Icon(
                                                                //       Icons
                                                                //           .person_outline,
                                                                //       color:
                                                                //           AppColors.nBlue,
                                                                //     ),
                                                                //     const SizedBox(
                                                                //       width: 10,
                                                                //     ),
                                                                //     Text(
                                                                //       '${bookingRequestData!['sharedCount']}',
                                                                //       style: TextStyle(
                                                                //         fontWeight:
                                                                //             FontWeight
                                                                //                 .w500,
                                                                //       ),
                                                                //     ),
                                                                //   ],
                                                                // ),
                                                                // SizedBox(
                                                                //   height: 40,
                                                                //   child: VerticalDivider(
                                                                //     color: AppColors
                                                                //         .commonBlack
                                                                //         .withOpacity(0.1),
                                                                //   ),
                                                                // ),
                                                                Row(
                                                                  children: [
                                                                    Image.asset(
                                                                      AppImages
                                                                          .time,
                                                                      height:
                                                                          20,
                                                                      width: 20,
                                                                    ),
                                                                    const SizedBox(
                                                                      width: 10,
                                                                    ),
                                                                    Text(
                                                                      formatDuration(
                                                                        safeToInt(
                                                                          bookingRequestData?['estimateDuration'],
                                                                        ),
                                                                      ),
                                                                      style: TextStyle(
                                                                        fontWeight:
                                                                            FontWeight.w500,
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ),
                                                                SizedBox(
                                                                  height: 40,
                                                                  child: VerticalDivider(
                                                                    color: AppColors
                                                                        .commonBlack
                                                                        .withOpacity(
                                                                          0.1,
                                                                        ),
                                                                  ),
                                                                ),
                                                                Row(
                                                                  children: [
                                                                    Image.asset(
                                                                      AppImages
                                                                          .distance,
                                                                      height:
                                                                          20,
                                                                      width: 20,
                                                                    ),
                                                                    const SizedBox(
                                                                      width: 10,
                                                                    ),
                                                                    Text(
                                                                      formatDistance(
                                                                        safeToDouble(
                                                                          bookingRequestData?['estimatedDistance'],
                                                                        ),
                                                                      ),
                                                                      style: TextStyle(
                                                                        fontWeight:
                                                                            FontWeight.w500,
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                          Padding(
                                                            padding:
                                                                const EdgeInsets.symmetric(
                                                                  horizontal:
                                                                      15,
                                                                ),
                                                            child: Divider(
                                                              color: AppColors
                                                                  .commonBlack
                                                                  .withOpacity(
                                                                    0.1,
                                                                  ),
                                                            ),
                                                          ),

                                                          Padding(
                                                            padding:
                                                                const EdgeInsets.symmetric(
                                                                  horizontal:
                                                                      8.0,
                                                                  vertical: 10,
                                                                ),
                                                            child: Row(
                                                              children: [
                                                                Expanded(
                                                                  child: Buttons.button(
                                                                    borderRadius:
                                                                        10,
                                                                    buttonColor:
                                                                        AppColors
                                                                            .red,
                                                                    onTap:
                                                                        statusController.isLoading.value
                                                                            ? null
                                                                            : () {
                                                                              final bookingId =
                                                                                  bookingRequestData!['bookingId'];
                                                                              CommonLogger.log.i(
                                                                                bookingId,
                                                                              );

                                                                              // Get.to(
                                                                              //   PickingCustomerScreen(),
                                                                              // );
                                                                              // statusController
                                                                              //     .bookingAccept(
                                                                              //       context,
                                                                              //       bookingId:
                                                                              //           bookingId,
                                                                              //       status:
                                                                              //           'REJECT',
                                                                              //
                                                                              //
                                                                              //     );
                                                                              setState(
                                                                                () {
                                                                                  bookingRequestData =
                                                                                      null;
                                                                                },
                                                                              );
                                                                            },
                                                                    text: Text(
                                                                      'Decline',
                                                                    ),
                                                                  ),
                                                                ),
                                                                SizedBox(
                                                                  width: 20,
                                                                ),
                                                                Obx(() {
                                                                  return Expanded(
                                                                    child: Buttons.button(
                                                                      borderRadius:
                                                                          10,
                                                                      buttonColor:
                                                                          AppColors
                                                                              .drkGreen,
                                                                      onTap:
                                                                          statusController.isLoading.value
                                                                              ? null
                                                                              : () async {
                                                                                try {
                                                                                  final bookingId =
                                                                                      bookingRequestData!['bookingId'];
                                                                                  final address =
                                                                                      bookingRequestData!['pickupAddress'] ??
                                                                                      '';

                                                                                  final dropAddress =
                                                                                      bookingRequestData!['dropAddress'] ??
                                                                                      '';

                                                                                  final pickup = LatLng(
                                                                                    bookingRequestData!['pickupLocation']['latitude'],
                                                                                    bookingRequestData!['pickupLocation']['longitude'],
                                                                                  );

                                                                                  final position = await Geolocator.getCurrentPosition(
                                                                                    desiredAccuracy:
                                                                                        LocationAccuracy.high,
                                                                                  );

                                                                                  final driverLocation = LatLng(
                                                                                    position.latitude,
                                                                                    position.longitude,
                                                                                  );

                                                                                  await statusController.bookingAccept(
                                                                                    pickupLocationAddress:
                                                                                        address,
                                                                                    dropLocationAddress:
                                                                                        dropAddress,

                                                                                    context,
                                                                                    bookingId:
                                                                                        bookingId,
                                                                                    status:
                                                                                        'ACCEPT',
                                                                                    pickupLocation:
                                                                                        pickup,
                                                                                    driverLocation:
                                                                                        driverLocation,
                                                                                  );
                                                                                  setState(
                                                                                    () {
                                                                                      bookingRequestData =
                                                                                          null;
                                                                                    },
                                                                                  );
                                                                                } catch (
                                                                                  e
                                                                                ) {
                                                                                  CommonLogger.log.e(
                                                                                    "Booking accept failed: $e",
                                                                                  );
                                                                                }
                                                                              },
                                                                      text:
                                                                          statusController.isLoading.value
                                                                              ? SizedBox(
                                                                                height:
                                                                                    20,
                                                                                width:
                                                                                    20,
                                                                                child:
                                                                                    AppLoader.circularLoader(),
                                                                              )
                                                                              : Text(
                                                                                'Accept',
                                                                              ),
                                                                    ),
                                                                  );
                                                                }),
                                                              ],
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ] else
                                              ...[],
                                            statusController.isOnline.value
                                                ? SizedBox.shrink()
                                                : GestureDetector(
                                                  onTap: () {},
                                                  child: Container(
                                                    width: double.infinity,
                                                    height: 54,
                                                    decoration: BoxDecoration(
                                                      color:
                                                          AppColors.commonBlack,
                                                    ),
                                                    child: Row(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .center,
                                                      children: [
                                                        Image.asset(
                                                          AppImages.graph,
                                                          color:
                                                              AppColors
                                                                  .commonWhite,
                                                          height: 20,
                                                          width: 20,
                                                        ),

                                                        SizedBox(width: 10),
                                                        CustomTextfield.textWithStyles600(
                                                          fontSize: 13,
                                                          color:
                                                              AppColors
                                                                  .commonWhite,
                                                          'Requests are Surging - Go Online Now!',
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                            const SizedBox(height: 20),

                                            Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 17,
                                                  ),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  CustomTextfield.textWithStyles700(
                                                    'Weekly Challenges',
                                                    fontSize: 16,
                                                    color: getTextColor(),
                                                  ),
                                                  const SizedBox(height: 10),
                                                  Container(
                                                    decoration: BoxDecoration(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            10,
                                                          ),
                                                      border: Border.all(
                                                        color: AppColors
                                                            .commonBlack
                                                            .withOpacity(0.1),
                                                      ),
                                                    ),
                                                    child: Padding(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 15,
                                                            vertical: 22,
                                                          ),
                                                      child: Obx(() {
                                                        final weeklyData =
                                                            statusController
                                                                .weeklyStatusData
                                                                .value;
                                                        final serviceType =
                                                            statusController
                                                                .serviceType
                                                                .value;
                                                        return Row(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                            Expanded(
                                                              child: Column(
                                                                crossAxisAlignment:
                                                                    CrossAxisAlignment
                                                                        .start,
                                                                children: [
                                                                  CustomTextfield.textWithStylesSmall(
                                                                    'Ends on Monday',
                                                                    colors:
                                                                        AppColors
                                                                            .grey,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w500,
                                                                  ),
                                                                  const SizedBox(
                                                                    height: 5,
                                                                  ),
                                                                  CustomTextfield.textWithStyles600(
                                                                    'Complete ${weeklyData?.goal.toString() ?? ''} trips',
                                                                    fontSize:
                                                                        16,
                                                                  ),
                                                                  const SizedBox(
                                                                    height: 5,
                                                                  ),
                                                                  CustomTextfield.textWithStylesSmall(
                                                                    colors: getTextColor(
                                                                      color:
                                                                          AppColors
                                                                              .drkGreen,
                                                                    ),

                                                                    '${weeklyData?.totalTrips.toString() ?? ''} trips done out of 20',
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w500,
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                            const SizedBox(
                                                              width: 15,
                                                            ),
                                                            CircularPercentIndicator(
                                                              radius: 45.0,
                                                              lineWidth: 10.0,
                                                              animation: true,
                                                              percent:
                                                                  (weeklyData
                                                                          ?.progressPercent ??
                                                                      0) /
                                                                  100,
                                                              center: Text(
                                                                "${weeklyData?.progressPercent.toString() ?? ''}%",
                                                                style: TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600,
                                                                ),
                                                              ),
                                                              circularStrokeCap:
                                                                  CircularStrokeCap
                                                                      .round,
                                                              backgroundColor:
                                                                  AppColors
                                                                      .drkGreen
                                                                      .withOpacity(
                                                                        0.1,
                                                                      ),
                                                              progressColor:
                                                                  getTextColor(
                                                                    color:
                                                                        AppColors
                                                                            .drkGreen,
                                                                  ),
                                                            ),
                                                          ],
                                                        );
                                                      }),
                                                    ),
                                                  ),

                                                  const SizedBox(height: 20),
                                                  CustomTextfield.textWithStyles700(
                                                    "Today's Activity",
                                                    fontSize: 16,
                                                  ),
                                                  const SizedBox(height: 10),
                                                  Container(
                                                    decoration: BoxDecoration(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            10,
                                                          ),
                                                      border: Border.all(
                                                        color: AppColors
                                                            .commonBlack
                                                            .withOpacity(0.1),
                                                      ),
                                                    ),
                                                    child: Padding(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 25,
                                                            vertical: 15,
                                                          ),
                                                      child: Obx(() {
                                                        final data =
                                                            statusController
                                                                .todayStatusData
                                                                .value;
                                                        return Row(
                                                          mainAxisAlignment:
                                                              MainAxisAlignment
                                                                  .spaceBetween,
                                                          children: [
                                                            Column(
                                                              children: [
                                                                CustomTextfield.textWithStyles600(
                                                                  'Earnings',
                                                                  color:
                                                                      AppColors
                                                                          .grey,
                                                                ),
                                                                CustomTextfield.textWithImage(
                                                                  text:
                                                                      data?.earnings
                                                                          .toString() ??
                                                                      '',
                                                                  colors:
                                                                      AppColors
                                                                          .commonBlack,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w700,
                                                                  fontSize: 16,
                                                                  imagePath:
                                                                      AppImages
                                                                          .bCurrency,
                                                                ),
                                                              ],
                                                            ),

                                                            SizedBox(
                                                              height: 50,
                                                              child: VerticalDivider(
                                                                color: AppColors
                                                                    .commonBlack
                                                                    .withOpacity(
                                                                      0.2,
                                                                    ),
                                                              ),
                                                            ),

                                                            Column(
                                                              children: [
                                                                CustomTextfield.textWithStyles600(
                                                                  'Online',
                                                                  color:
                                                                      AppColors
                                                                          .grey,
                                                                ),
                                                                CustomTextfield.textWithImage(
                                                                  colors:
                                                                      AppColors
                                                                          .commonBlack,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w700,
                                                                  fontSize: 16,
                                                                  text:
                                                                      data?.online
                                                                          .toString() ??
                                                                      '',
                                                                ),
                                                              ],
                                                            ),

                                                            SizedBox(
                                                              height: 50,
                                                              child: VerticalDivider(
                                                                color: AppColors
                                                                    .commonBlack
                                                                    .withOpacity(
                                                                      0.2,
                                                                    ),
                                                              ),
                                                            ),

                                                            Column(
                                                              children: [
                                                                CustomTextfield.textWithStyles600(
                                                                  'Rides',
                                                                  color:
                                                                      AppColors
                                                                          .grey,
                                                                ),

                                                                CustomTextfield.textWithImage(
                                                                  text:
                                                                      data?.rides
                                                                          .toString() ??
                                                                      '',
                                                                  colors:
                                                                      AppColors
                                                                          .commonBlack,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w700,
                                                                  fontSize: 16,
                                                                ),
                                                              ],
                                                            ),
                                                          ],
                                                        );
                                                      }),
                                                    ),
                                                  ),

                                                  const SizedBox(height: 20),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ] else ...[
                                DraggableScrollableSheet(
                                  initialChildSize: 0.65,
                                  minChildSize: 0.62,
                                  maxChildSize: 1.0,

                                  builder: (context, scrollController) {
                                    return Container(
                                      decoration: const BoxDecoration(
                                        color: Colors.white,
                                        // borderRadius: BorderRadius.vertical(
                                        //   top: Radius.circular(20),
                                        // ),
                                      ),
                                      child: RefreshIndicator(
                                        onRefresh: () async {
                                          await statusController
                                              .weeklyChallenges();
                                          await statusController
                                              .todayPackageActivity();
                                        },
                                        child: ListView(
                                          physics:
                                              AlwaysScrollableScrollPhysics(
                                                parent: BouncingScrollPhysics(),
                                              ),
                                          controller: scrollController,
                                          children: [
                                            Center(
                                              child: Container(
                                                width: 40,
                                                height: 4,
                                                margin: const EdgeInsets.only(
                                                  top: 10,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.grey[400],
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                ),
                                              ),
                                            ),

                                            const SizedBox(height: 20),
                                            if (bookingRequestData != null) ...[
                                              Column(
                                                children: [
                                                  Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .center,
                                                    children: [
                                                      Container(
                                                        padding:
                                                            EdgeInsets.symmetric(
                                                              horizontal: 10,
                                                              vertical: 5,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          color: AppColors.red,
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                5,
                                                              ),
                                                        ),
                                                        child: CustomTextfield.textWithStyles600(
                                                          color:
                                                              AppColors
                                                                  .commonWhite,
                                                          '${formatCountdown(remainingSeconds)} ',
                                                        ),
                                                      ),
                                                      SizedBox(width: 15),
                                                      Text(
                                                        "Respond within 15 seconds",
                                                        style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.w700,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  SizedBox(height: 10),
                                                  Card(
                                                    elevation: 3,
                                                    child: Container(
                                                      decoration: BoxDecoration(
                                                        color:
                                                            AppColors
                                                                .commonWhite,
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              10,
                                                            ),
                                                      ),

                                                      child: Column(
                                                        children: [
                                                          Container(
                                                            width:
                                                                double.infinity,
                                                            height: 54,
                                                            decoration: BoxDecoration(
                                                              borderRadius:
                                                                  BorderRadius.only(
                                                                    topLeft:
                                                                        Radius.circular(
                                                                          10,
                                                                        ),
                                                                    topRight:
                                                                        Radius.circular(
                                                                          10,
                                                                        ),
                                                                  ),
                                                              color:
                                                                  AppColors
                                                                      .nBlue,
                                                            ),
                                                            child: Padding(
                                                              padding:
                                                                  const EdgeInsets.symmetric(
                                                                    horizontal:
                                                                        15,
                                                                  ),
                                                              child: Row(
                                                                children: [
                                                                  Image.asset(
                                                                    AppImages
                                                                        .notification,
                                                                    height: 25,
                                                                    width: 25,
                                                                  ),
                                                                  SizedBox(
                                                                    width: 10,
                                                                  ),
                                                                  CustomTextfield.textWithStyles600(
                                                                    bookingRequestData!['rideType'] ==
                                                                            'Bike'
                                                                        ? 'New Package Request'
                                                                        : 'New Ride Request',
                                                                    color:
                                                                        AppColors
                                                                            .commonWhite,
                                                                  ),

                                                                  Spacer(),
                                                                  CustomTextfield.textWithImage(
                                                                    imageColors:
                                                                        AppColors
                                                                            .commonWhite,
                                                                    text:
                                                                        '${bookingRequestData!['estimatedPrice']}',
                                                                    imagePath:
                                                                        AppImages
                                                                            .bCurrency,
                                                                    colors:
                                                                        AppColors
                                                                            .commonWhite,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w700,
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                          ),
                                                          Padding(
                                                            padding:
                                                                const EdgeInsets.all(
                                                                  8.0,
                                                                ),
                                                            child: Column(
                                                              children: [
                                                                Row(
                                                                  children: [
                                                                    Icon(
                                                                      Icons
                                                                          .circle,
                                                                      color:
                                                                          Colors
                                                                              .green,
                                                                      size: 12,
                                                                    ),
                                                                    SizedBox(
                                                                      width: 8,
                                                                    ),
                                                                    Expanded(
                                                                      child: Text(
                                                                        bookingRequestData!['pickupAddress'] ??
                                                                            '',
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ),
                                                                const SizedBox(
                                                                  height: 8,
                                                                ),
                                                                Row(
                                                                  children: [
                                                                    Icon(
                                                                      Icons
                                                                          .circle,
                                                                      color:
                                                                          Colors
                                                                              .red,
                                                                      size: 12,
                                                                    ),
                                                                    SizedBox(
                                                                      width: 8,
                                                                    ),
                                                                    Expanded(
                                                                      child: Text(
                                                                        bookingRequestData!['dropAddress'] ??
                                                                            "",
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ),
                                                              ],
                                                            ),
                                                          ),

                                                          Padding(
                                                            padding:
                                                                const EdgeInsets.symmetric(
                                                                  horizontal:
                                                                      15,
                                                                ),
                                                            child: Divider(
                                                              color: AppColors
                                                                  .commonBlack
                                                                  .withOpacity(
                                                                    0.1,
                                                                  ),
                                                            ),
                                                          ),

                                                          Padding(
                                                            padding:
                                                                const EdgeInsets.symmetric(
                                                                  horizontal:
                                                                      30,
                                                                ),
                                                            child: Row(
                                                              mainAxisAlignment:
                                                                  MainAxisAlignment
                                                                      .spaceAround,
                                                              children: [
                                                                // Row(
                                                                //   children: [
                                                                //     Icon(
                                                                //       Icons
                                                                //           .person_outline,
                                                                //       color:
                                                                //           AppColors.nBlue,
                                                                //     ),
                                                                //     const SizedBox(
                                                                //       width: 10,
                                                                //     ),
                                                                //     Text(
                                                                //       '${bookingRequestData!['sharedCount']}',
                                                                //       style: TextStyle(
                                                                //         fontWeight:
                                                                //             FontWeight
                                                                //                 .w500,
                                                                //       ),
                                                                //     ),
                                                                //   ],
                                                                // ),
                                                                // SizedBox(
                                                                //   height: 40,
                                                                //   child: VerticalDivider(
                                                                //     color: AppColors
                                                                //         .commonBlack
                                                                //         .withOpacity(0.1),
                                                                //   ),
                                                                // ),
                                                                Row(
                                                                  children: [
                                                                    Image.asset(
                                                                      AppImages
                                                                          .time,
                                                                      height:
                                                                          20,
                                                                      width: 20,
                                                                    ),
                                                                    const SizedBox(
                                                                      width: 10,
                                                                    ),
                                                                    Text(
                                                                      formatDuration(
                                                                        safeToInt(
                                                                          bookingRequestData?['estimateDuration'],
                                                                        ),
                                                                      ),
                                                                      style: TextStyle(
                                                                        fontWeight:
                                                                            FontWeight.w500,
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ),
                                                                SizedBox(
                                                                  height: 40,
                                                                  child: VerticalDivider(
                                                                    color: AppColors
                                                                        .commonBlack
                                                                        .withOpacity(
                                                                          0.1,
                                                                        ),
                                                                  ),
                                                                ),
                                                                Row(
                                                                  children: [
                                                                    Image.asset(
                                                                      AppImages
                                                                          .distance,
                                                                      height:
                                                                          20,
                                                                      width: 20,
                                                                    ),
                                                                    const SizedBox(
                                                                      width: 10,
                                                                    ),
                                                                    Text(
                                                                      formatDistance(
                                                                        safeToDouble(
                                                                          bookingRequestData?['estimatedDistance'],
                                                                        ),
                                                                      ),
                                                                      style: TextStyle(
                                                                        fontWeight:
                                                                            FontWeight.w500,
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                          Padding(
                                                            padding:
                                                                const EdgeInsets.symmetric(
                                                                  horizontal:
                                                                      15,
                                                                ),
                                                            child: Divider(
                                                              color: AppColors
                                                                  .commonBlack
                                                                  .withOpacity(
                                                                    0.1,
                                                                  ),
                                                            ),
                                                          ),

                                                          Padding(
                                                            padding:
                                                                const EdgeInsets.symmetric(
                                                                  horizontal:
                                                                      8.0,
                                                                  vertical: 10,
                                                                ),
                                                            child: Row(
                                                              children: [
                                                                Expanded(
                                                                  child: Buttons.button(
                                                                    borderRadius:
                                                                        10,
                                                                    buttonColor:
                                                                        AppColors
                                                                            .red,
                                                                    onTap:
                                                                        statusController.isLoading.value
                                                                            ? null
                                                                            : () {
                                                                              final bookingId =
                                                                                  bookingRequestData!['bookingId'];
                                                                              CommonLogger.log.i(
                                                                                bookingId,
                                                                              );

                                                                              // Get.to(
                                                                              //   PickingCustomerScreen(),
                                                                              // );
                                                                              // statusController
                                                                              //     .bookingAccept(
                                                                              //       context,
                                                                              //       bookingId:
                                                                              //           bookingId,
                                                                              //       status:
                                                                              //           'REJECT',
                                                                              //
                                                                              //
                                                                              //     );
                                                                              setState(
                                                                                () {
                                                                                  bookingRequestData =
                                                                                      null;
                                                                                },
                                                                              );
                                                                            },
                                                                    text: Text(
                                                                      'Decline',
                                                                    ),
                                                                  ),
                                                                ),
                                                                SizedBox(
                                                                  width: 20,
                                                                ),
                                                                Obx(() {
                                                                  return Expanded(
                                                                    child: Buttons.button(
                                                                      borderRadius:
                                                                          10,
                                                                      buttonColor:
                                                                          AppColors
                                                                              .drkGreen,
                                                                      onTap:
                                                                          statusController.isLoading.value
                                                                              ? null
                                                                              : () async {
                                                                                try {
                                                                                  final bookingId =
                                                                                      bookingRequestData!['bookingId'];
                                                                                  final address =
                                                                                      bookingRequestData!['pickupAddress'] ??
                                                                                      '';

                                                                                  final dropAddress =
                                                                                      bookingRequestData!['dropAddress'] ??
                                                                                      '';

                                                                                  final pickup = LatLng(
                                                                                    bookingRequestData!['pickupLocation']['latitude'],
                                                                                    bookingRequestData!['pickupLocation']['longitude'],
                                                                                  );

                                                                                  final position = await Geolocator.getCurrentPosition(
                                                                                    desiredAccuracy:
                                                                                        LocationAccuracy.high,
                                                                                  );

                                                                                  final driverLocation = LatLng(
                                                                                    position.latitude,
                                                                                    position.longitude,
                                                                                  );

                                                                                  await statusController.bookingAccept(
                                                                                    pickupLocationAddress:
                                                                                        address,
                                                                                    dropLocationAddress:
                                                                                        dropAddress,

                                                                                    context,
                                                                                    bookingId:
                                                                                        bookingId,
                                                                                    status:
                                                                                        'ACCEPT',
                                                                                    pickupLocation:
                                                                                        pickup,
                                                                                    driverLocation:
                                                                                        driverLocation,
                                                                                  );
                                                                                  setState(
                                                                                    () {
                                                                                      bookingRequestData =
                                                                                          null;
                                                                                    },
                                                                                  );
                                                                                } catch (
                                                                                  e
                                                                                ) {
                                                                                  CommonLogger.log.e(
                                                                                    "Booking accept failed: $e",
                                                                                  );
                                                                                }
                                                                              },
                                                                      text:
                                                                          statusController.isLoading.value
                                                                              ? SizedBox(
                                                                                height:
                                                                                    20,
                                                                                width:
                                                                                    20,
                                                                                child:
                                                                                    AppLoader.circularLoader(),
                                                                              )
                                                                              : Text(
                                                                                'Accept',
                                                                              ),
                                                                    ),
                                                                  );
                                                                }),
                                                              ],
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ] else
                                              ...[],
                                            statusController.isOnline.value
                                                ? SizedBox.shrink()
                                                : GestureDetector(
                                                  onTap: () {},
                                                  child: Container(
                                                    width: double.infinity,
                                                    height: 54,
                                                    decoration: BoxDecoration(
                                                      color:
                                                          AppColors.commonBlack,
                                                    ),
                                                    child: Row(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .center,
                                                      children: [
                                                        Image.asset(
                                                          AppImages.graph,
                                                          color:
                                                              AppColors
                                                                  .commonWhite,
                                                          height: 20,
                                                          width: 20,
                                                        ),

                                                        SizedBox(width: 10),
                                                        CustomTextfield.textWithStyles600(
                                                          fontSize: 13,
                                                          color:
                                                              AppColors
                                                                  .commonWhite,
                                                          'Requests are Surging - Go Online Now!',
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),

                                            Center(
                                              child: Opacity(
                                                opacity: 0.7, // 👈 0.0 = fully transparent, 1.0 = fully opaque
                                                child: Image.asset(
                                                  AppImages.hopprPackage,
                                                  height: 25,
                                                ),
                                              ),
                                            ),

                                            const SizedBox(height: 20),
                                            Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 17,
                                                  ),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [

                                                  CustomTextfield.textWithStyles700(
                                                    "Today's Activity",
                                                    fontSize: 16,
                                                  ),
                                                  const SizedBox(height: 10),
                                                  Container(
                                                    decoration: BoxDecoration(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            10,
                                                          ),
                                                    ),
                                                    child: Padding(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 25,
                                                            vertical: 15,
                                                          ),
                                                      child: Obx(() {
                                                        final data =
                                                            statusController
                                                                .parcelBookingData
                                                                .value;
                                                        return Row(
                                                          children: [
                                                            Expanded(
                                                              flex: 2,
                                                              child: Column(
                                                                children: [
                                                                  Container(
                                                                    padding: EdgeInsets.symmetric(
                                                                      horizontal:
                                                                          10,
                                                                      vertical:
                                                                          10,
                                                                    ),
                                                                    decoration: BoxDecoration(
                                                                      color: const Color(
                                                                        0xFFE2FBE9,
                                                                      ),
                                                                      shape:
                                                                          BoxShape
                                                                              .circle,
                                                                    ),
                                                                    child: Image.asset(
                                                                      height:
                                                                          17,
                                                                      AppImages
                                                                          .bCurrency,
                                                                      color: Color(
                                                                        0xff009721,
                                                                      ),
                                                                    ),
                                                                  ),
                                                                  SizedBox(
                                                                    height: 5,
                                                                  ),
                                                                  CustomTextfield.textWithImage(
                                                                    text: (data?.earning ??
                                                                            0)
                                                                        .toStringAsFixed(
                                                                          2,
                                                                        ),
                                                                    colors:
                                                                        AppColors
                                                                            .commonBlack,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w700,
                                                                    fontSize:
                                                                        15,
                                                                    imagePath:
                                                                        AppImages
                                                                            .bCurrency,
                                                                  ),

                                                                  SizedBox(
                                                                    height: 5,
                                                                  ),
                                                                  CustomTextfield.textWithStylesSmall(
                                                                    'Earnings',
                                                                    colors:
                                                                        AppColors
                                                                            .grey,
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                            Spacer(),
                                                            Expanded(
                                                              flex: 1,
                                                              child: Column(
                                                                children: [
                                                                  Container(
                                                                    padding: EdgeInsets.symmetric(
                                                                      horizontal:
                                                                          10,
                                                                      vertical:
                                                                          10,
                                                                    ),
                                                                    decoration: BoxDecoration(
                                                                      color: const Color(
                                                                        0XFFDEEAFC,
                                                                      ),
                                                                      shape:
                                                                          BoxShape
                                                                              .circle,
                                                                    ),
                                                                    child: Image.asset(
                                                                      height:
                                                                          17,
                                                                      AppImages
                                                                          .boxLine,
                                                                    ),
                                                                  ),
                                                                  SizedBox(
                                                                    height: 5,
                                                                  ),
                                                                  CustomTextfield.textWithImage(
                                                                    colors:
                                                                        AppColors
                                                                            .commonBlack,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w700,
                                                                    fontSize:
                                                                        16,
                                                                    text:
                                                                        data?.completed
                                                                            .toString() ??
                                                                        '0',
                                                                  ),
                                                                  SizedBox(
                                                                    height: 5,
                                                                  ),
                                                                  CustomTextfield.textWithStylesSmall(
                                                                    'Deliveries',
                                                                    colors:
                                                                        AppColors
                                                                            .grey,
                                                                    maxLine: 1,
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                            Spacer(),
                                                            Expanded(
                                                              flex: 1,
                                                              child: Column(
                                                                children: [
                                                                  Container(
                                                                    padding: EdgeInsets.symmetric(
                                                                      horizontal:
                                                                          10,
                                                                      vertical:
                                                                          10,
                                                                    ),
                                                                    decoration: BoxDecoration(
                                                                      color:
                                                                          AppColors
                                                                              .starColors,
                                                                      shape:
                                                                          BoxShape
                                                                              .circle,
                                                                    ),
                                                                    child: Image.asset(
                                                                      height:
                                                                          17,
                                                                      color: Color(
                                                                        0XFFC18C30,
                                                                      ),
                                                                      AppImages
                                                                          .star,
                                                                    ),
                                                                  ),
                                                                  SizedBox(
                                                                    height: 5,
                                                                  ),
                                                                  CustomTextfield.textWithImage(
                                                                    colors:
                                                                        AppColors
                                                                            .commonBlack,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w700,
                                                                    fontSize:
                                                                        16,
                                                                    text:
                                                                        data?.rating
                                                                            .toString() ??
                                                                        '0',
                                                                  ),
                                                                  SizedBox(
                                                                    height: 5,
                                                                  ),
                                                                  CustomTextfield.textWithStylesSmall(
                                                                    'Rating',
                                                                    colors:
                                                                        AppColors
                                                                            .grey,
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                          ],
                                                        );
                                                      }),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 10),
                                                  CustomTextfield.textWithStyles700(
                                                    'Weekly Challenges',
                                                    fontSize: 16,
                                                    color: getTextColor(),
                                                  ),
                                                  const SizedBox(height: 10),
                                                  Container(
                                                    decoration: BoxDecoration(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            10,
                                                          ),
                                                      border: Border.all(
                                                        color: AppColors
                                                            .commonBlack
                                                            .withOpacity(0.1),
                                                      ),
                                                    ),
                                                    child: Padding(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 15,
                                                            vertical: 15,
                                                          ),
                                                      child: Obx(() {
                                                        final weeklyData =
                                                            statusController
                                                                .parcelBookingData
                                                                .value;

                                                        return Row(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                            Expanded(
                                                              child: Column(
                                                                crossAxisAlignment:
                                                                    CrossAxisAlignment
                                                                        .start,
                                                                children: [
                                                                  CustomTextfield.textWithStylesSmall(
                                                                    'Ends on Monday',
                                                                    colors:
                                                                        AppColors
                                                                            .grey,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w500,
                                                                  ),
                                                                  const SizedBox(
                                                                    height: 5,
                                                                  ),
                                                                  CustomTextfield.textWithStyles600(
                                                                    // and\nget ${weeklyData?.reward.toString() ?? ''} extra
                                                                    'Complete ${weeklyData?.weeklyProgress.goal.toString() ?? '0'} orders',
                                                                    fontSize:
                                                                        17,
                                                                  ),
                                                                  const SizedBox(
                                                                    height: 10,
                                                                  ),
                                                                  CustomTextfield.textWithStylesSmall(
                                                                    colors: getTextColor(
                                                                      color:
                                                                          AppColors
                                                                              .drkGreen,
                                                                    ),

                                                                    '${weeklyData?.weeklyProgress.totalTrips.toString() ?? '0'} trips done out of 20',
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w500,
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                            const SizedBox(
                                                              width: 15,
                                                            ),
                                                            CircularPercentIndicator(
                                                              radius: 45.0,
                                                              lineWidth: 10.0,
                                                              animation: true,
                                                              percent:
                                                                  (weeklyData
                                                                          ?.weeklyProgress
                                                                          .progressPercent ??
                                                                      0) /
                                                                  100,
                                                              center: Text(
                                                                "${weeklyData?.weeklyProgress.progressPercent.toString() ?? ''}%",
                                                                style: TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600,
                                                                ),
                                                              ),
                                                              circularStrokeCap:
                                                                  CircularStrokeCap
                                                                      .round,
                                                              backgroundColor:
                                                                  AppColors
                                                                      .drkGreen
                                                                      .withOpacity(
                                                                        0.1,
                                                                      ),
                                                              progressColor:
                                                                  getTextColor(
                                                                    color:
                                                                        AppColors
                                                                            .drkGreen,
                                                                  ),
                                                            ),
                                                          ],
                                                        );
                                                      }),
                                                    ),
                                                  ),

                                                  const SizedBox(height: 20),
                                                  CustomTextfield.textWithStyles700(
                                                    'Recent Deliveries',
                                                    fontSize: 17,
                                                  ),
                                                  const SizedBox(height: 20),
                                                  Obx(() {
                                                    final history =
                                                        statusController
                                                            .parcelBookingData
                                                            .value;

                                                    return Column(
                                                      children: [
                                                        if (history?.recentBookings ==
                                                                null ||
                                                            history!
                                                                .recentBookings
                                                                .isEmpty)
                                                          Center(
                                                            child: Padding(
                                                              padding:
                                                                  const EdgeInsets.symmetric(
                                                                    vertical:
                                                                        20,
                                                                  ),
                                                              child: Text(
                                                                "No recent deliveries",
                                                                style: TextStyle(
                                                                  fontSize: 16,
                                                                  color:
                                                                      AppColors
                                                                          .commonBlack,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w500,
                                                                ),
                                                              ),
                                                            ),
                                                          )
                                                        else
                                                          ListView.builder(
                                                            shrinkWrap: true,
                                                            physics:
                                                                NeverScrollableScrollPhysics(),
                                                            itemCount:
                                                                history
                                                                    .recentBookings
                                                                    .length,
                                                            itemBuilder: (
                                                              context,
                                                              index,
                                                            ) {
                                                              final data =
                                                                  history
                                                                      .recentBookings[index];
                                                              return Padding(
                                                                padding:
                                                                    const EdgeInsets.symmetric(
                                                                      vertical:
                                                                          4,
                                                                    ),
                                                                child: Container(
                                                                  decoration: BoxDecoration(
                                                                    borderRadius:
                                                                        BorderRadius.circular(
                                                                          10,
                                                                        ),
                                                                    color:
                                                                        AppColors
                                                                            .containerColor1,
                                                                  ),
                                                                  child: Padding(
                                                                    padding: const EdgeInsets.symmetric(
                                                                      horizontal:
                                                                          15,
                                                                      vertical:
                                                                          10,
                                                                    ),
                                                                    child: Row(
                                                                      crossAxisAlignment:
                                                                          CrossAxisAlignment
                                                                              .start,
                                                                      children: [
                                                                        Padding(
                                                                          padding: const EdgeInsets.only(
                                                                            top:
                                                                                2.0,
                                                                          ),
                                                                          child: Container(
                                                                            padding: EdgeInsets.symmetric(
                                                                              horizontal:
                                                                                  10,
                                                                              vertical:
                                                                                  10,
                                                                            ),
                                                                            decoration: BoxDecoration(
                                                                              color: getTextColor(
                                                                                color:
                                                                                    AppColors.changeButtonColor,
                                                                              ),
                                                                              shape:
                                                                                  BoxShape.circle,
                                                                            ),
                                                                            child: Image.asset(
                                                                              AppImages.boxLine,
                                                                              color:
                                                                                  AppColors.commonWhite,
                                                                              height:
                                                                                  17,
                                                                            ),
                                                                          ),
                                                                        ),
                                                                        SizedBox(
                                                                          width:
                                                                              10,
                                                                        ),
                                                                        Expanded(
                                                                          child: Column(
                                                                            crossAxisAlignment:
                                                                                CrossAxisAlignment.start,
                                                                            children: [
                                                                              CustomTextfield.textWithStyles600(
                                                                                data.customerName.toString(),
                                                                                fontSize:
                                                                                    15,
                                                                              ),
                                                                              CustomTextfield.textWithStylesSmall(
                                                                                '2:45 PM', // You might want to use data.statusTime here
                                                                              ),
                                                                            ],
                                                                          ),
                                                                        ),
                                                                        Spacer(),
                                                                        Column(
                                                                          crossAxisAlignment:
                                                                              CrossAxisAlignment.end,
                                                                          children: [
                                                                            CustomTextfield.textWithImage(
                                                                              fontWeight:
                                                                                  FontWeight.w600,
                                                                              text:
                                                                                  data.amount.toString(),
                                                                              colors: getTextColor(
                                                                                color:
                                                                                    AppColors.drkGreen,
                                                                              ),
                                                                              imagePath:
                                                                                  AppImages.bCurrency,
                                                                              fontSize:
                                                                                  16,
                                                                              imageColors: getTextColor(
                                                                                color:
                                                                                    AppColors.drkGreen,
                                                                              ),
                                                                            ),
                                                                            Padding(
                                                                              padding: const EdgeInsets.only(
                                                                                right:
                                                                                    8.0,
                                                                              ),
                                                                              child: Container(
                                                                                padding: EdgeInsets.symmetric(
                                                                                  horizontal:
                                                                                      20,
                                                                                  vertical:
                                                                                      5,
                                                                                ),
                                                                                decoration: BoxDecoration(
                                                                                  borderRadius: BorderRadius.circular(
                                                                                    8,
                                                                                  ),
                                                                                  color:
                                                                                      AppColors.chatCallContainerColor,
                                                                                ),
                                                                                child: CustomTextfield.textWithStylesSmall(
                                                                                  data.status.toString(),
                                                                                  fontWeight:
                                                                                      FontWeight.w500,
                                                                                  colors: getTextColor(
                                                                                    color:
                                                                                        AppColors.drkGreen,
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
                                                            },
                                                          ),
                                                      ],
                                                    );
                                                  }),

                                                  SizedBox(height: 20),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
