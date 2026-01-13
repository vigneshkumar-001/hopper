// lib/Presentation/DriverScreen/screens/SharedBooking/Screens/picking_customer_shared_screen.dart

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:action_slider/action_slider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:hopper/api/repository/api_constents.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:hopper/Core/Constants/Colors.dart';
import 'package:hopper/Core/Utility/Buttons.dart';
import 'package:hopper/Core/Utility/images.dart';
import 'package:hopper/Core/Utility/app_loader.dart';
import 'package:hopper/Presentation/Authentication/widgets/textFields.dart';
import 'package:hopper/Presentation/DriverScreen/controller/driver_status_controller.dart';
import 'package:hopper/Presentation/DriverScreen/screens/SharedBooking/Controller/shared_controller.dart';
import 'package:hopper/Presentation/DriverScreen/screens/SharedBooking/Controller/shared_ride_controller.dart';
import 'package:hopper/Presentation/DriverScreen/screens/SharedBooking/Screens/share_ride_start_screen.dart';
import 'package:hopper/Presentation/DriverScreen/screens/chat_screen.dart';
import 'package:hopper/Presentation/DriverScreen/screens/driver_main_screen.dart';
import 'package:hopper/utils/map/shared_map.dart';
import 'package:hopper/utils/netWorkHandling/network_handling_screen.dart';
import 'package:hopper/Core/Constants/log.dart';

import '../../../../../utils/map/driver_route.dart';
import '../../../../../utils/websocket/socket_io_client.dart';
import '../../verify_rider_screen.dart';
import '../Controller/booking_request_controller.dart';
import 'booking_overlay_request.dart';

class PickingCustomerSharedScreen extends StatefulWidget {
  final LatLng pickupLocation;
  final String? pickupLocationAddress;
  final String? dropLocationAddress;
  final LatLng driverLocation;
  final String bookingId;

  const PickingCustomerSharedScreen({
    Key? key,
    required this.pickupLocation,
    required this.driverLocation,
    required this.bookingId,
    this.pickupLocationAddress,
    this.dropLocationAddress,
  }) : super(key: key);

  @override
  State<PickingCustomerSharedScreen> createState() =>
      _PickingCustomerSharedScreenState();
}

/// Small immutable container for UI updates (so we don’t rebuild whole screen).
class RouteUiState {
  final LatLng driverLocation;
  final double bearing;
  final List<LatLng> polyline;
  final String directionText;
  final String distanceText;
  final String maneuver;

  const RouteUiState({
    required this.driverLocation,
    required this.bearing,
    required this.polyline,
    required this.directionText,
    required this.distanceText,
    required this.maneuver,
  });
}

class _PickingCustomerSharedScreenState
    extends State<PickingCustomerSharedScreen>
    with SingleTickerProviderStateMixin {
  late DriverRouteController _routeController;

  final SharedController sharedController = Get.put(SharedController());
  final DriverStatusController driverStatusController = Get.put(
    DriverStatusController(),
  );
  final SharedRideController sharedRideController =
      Get.find<SharedRideController>();
  final BookingRequestController bookingController =
      Get.find<BookingRequestController>();

  final GlobalKey<SharedMapState> _mapKey = GlobalKey<SharedMapState>();

  BitmapDescriptor? carIcon;

  late SocketService socketService;

  Timer? _globalTimer;

  // ✅ Instead of calling setState for every route tick, update only these parts.
  late final ValueNotifier<RouteUiState> _routeUi;

  // Throttle & filters
  DateTime? _lastRouteTick;
  LatLng? _lastDriverLocForUi;
  double _lastBearingForUi = 0;

  bool _isDriverFocused = false;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );

    _routeUi = ValueNotifier<RouteUiState>(
      RouteUiState(
        driverLocation: widget.driverLocation,
        bearing: 0,
        polyline: const [],
        directionText: '',
        distanceText: '',
        maneuver: '',
      ),
    );

    _initSocket();
    _loadMarkerIcons();

    _routeController = DriverRouteController(
      destination: widget.pickupLocation,
      onRouteUpdate: _onRouteUpdateOptimized,
      onCameraUpdate: (_) {},
    );

    _routeController.start();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _pulseAnimation = Tween<double>(
      begin: 0,
      end: 60,
    ).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _globalTimer?.cancel();
    _routeController.dispose();
    _pulseController.dispose();
    _routeUi.dispose();

    try {
      socketService.socket.off('driver-cancelled');
      socketService.socket.off('customer-cancelled');
      socketService.socket.off('driver-arrived');
      socketService.socket.off('driver-location');
      socketService.socket.off('booking-request');
    } catch (_) {}

    super.dispose();
  }

  // ───────────────── SOCKET SETUP ─────────────────

  Future<void> _initSocket() async {
    socketService = SocketService();
    socketService.initSocket(ApiConstents.sharedRideSocket);

    socketService.on('booking-request', (data) async {
      if (data == null) return;
      CommonLogger.log.i('[SHARED PICK] 📦 Booking Request → $data');

      final incomingId = data['bookingId']?.toString();

      if (incomingId == widget.bookingId) return;

      if (incomingId != null &&
          incomingId == bookingController.lastHandledBookingId.value) {
        return;
      }

      final pickup = data['pickupLocation'];
      final drop = data['dropLocation'];
      if (pickup == null || drop == null) return;

      final pickupAddr = await getAddressFromLatLng(
        (pickup['latitude'] as num).toDouble(),
        (pickup['longitude'] as num).toDouble(),
      );
      final dropAddr = await getAddressFromLatLng(
        (drop['latitude'] as num).toDouble(),
        (drop['longitude'] as num).toDouble(),
      );

      bookingController.showRequest(
        rawData: data,
        pickupAddress: pickupAddr,
        dropAddress: dropAddr,
      );
    });

    void handleDriverLocation(dynamic data) {
      if (data == null) return;

      final active = sharedRideController.activeTarget.value;
      final eventBookingId = data['bookingId']?.toString();
      if (active != null && eventBookingId != null) {
        if (eventBookingId != active.bookingId) return;
      }

      if (data['pickupDistanceInMeters'] != null) {
        driverStatusController.pickupDistanceInMeters.value =
            (data['pickupDistanceInMeters'] as num).toDouble();
      }
      if (data['pickupDurationInMin'] != null) {
        driverStatusController.pickupDurationInMin.value =
            (data['pickupDurationInMin'] as num).toDouble();
      }
    }

    socketService.on('driver-cancelled', (data) {
      if (data != null && data['status'] == true) {
        if (!mounted) return;
        Get.offAll(() => const DriverMainScreen());
      }
    });

    socketService.on('customer-cancelled', (data) {
      if (data != null && data['status'] == true) {
        if (!mounted) return;
        Get.offAll(() => const DriverMainScreen());
      }
    });

    socketService.on('driver-arrived', (data) {
      CommonLogger.log.i('[SHARED PICK] driver-arrived : $data');
    });

    socketService.onConnect(() {
      CommonLogger.log.i("✅ [SHARED PICK] Socket connected");
      socketService.on('driver-location', handleDriverLocation);
    });

    if (socketService.connected) {
      socketService.on('driver-location', handleDriverLocation);
    }

    socketService.connect();
  }

  // ─────────────── ROUTE UI OPTIMIZED ───────────────

  void _onRouteUpdateOptimized(dynamic update) {
    if (!mounted) return;

    // Always keep driver location for logic
    sharedRideController.updateDriverLocation(update.driverLocation);

    final now = DateTime.now();
    if (_lastRouteTick != null &&
        now.difference(_lastRouteTick!).inMilliseconds < 300) {
      return;
    }
    _lastRouteTick = now;

    // Ignore micro-movements to avoid unnecessary rebuilds
    final LatLng newLoc = update.driverLocation;
    final double newBearing = update.bearing;

    final double moved =
        _lastDriverLocForUi == null
            ? 999
            : _haversineMeters(_lastDriverLocForUi!, newLoc);

    final bool bearingChanged = (newBearing - _lastBearingForUi).abs() > 3.0;

    // If nothing meaningful changed, skip
    if (moved < 2.0 && !bearingChanged) return;

    _lastDriverLocForUi = newLoc;
    _lastBearingForUi = newBearing;

    // Polyline simplify
    List<LatLng> pts = (update.polylinePoints as List<LatLng>);
    pts = _simplifyPolyline(pts, minStepMeters: 8, maxPoints: 180);

    _routeUi.value = RouteUiState(
      driverLocation: newLoc,
      bearing: newBearing,
      polyline: pts,
      directionText: (update.directionText ?? '').toString(),
      distanceText: (update.distanceText ?? '').toString(),
      maneuver: (update.maneuver ?? '').toString(),
    );
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

  double _degToRad(double d) => d * (math.pi / 180.0);

  // ──────────────── HELPERS ────────────────

  Future<BitmapDescriptor> _bitmapFromAsset(
    String path, {
    int width = 48,
  }) async {
    final data = await rootBundle.load(path);
    final codec = await ui.instantiateImageCodec(
      data.buffer.asUint8List(),
      targetWidth: width,
    );
    final frame = await codec.getNextFrame();
    final bytes = await frame.image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.fromBytes(bytes!.buffer.asUint8List());
  }

  Future<void> _loadMarkerIcons() async {
    try {
      final icon = await _bitmapFromAsset(AppImages.movingCar, width: 74);
      if (!mounted) return;
      setState(() => carIcon = icon);
    } catch (_) {
      if (!mounted) return;
      setState(() => carIcon = BitmapDescriptor.defaultMarker);
    }
  }

  void _startNoShowTimer(SharedRiderItem rider) {
    rider.secondsLeft = 300;
    sharedRideController.riders.refresh();

    if (_globalTimer != null) return;

    _globalTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        _globalTimer = null;
        return;
      }

      bool anyActive = false;

      for (final r in sharedRideController.riders) {
        if (r.secondsLeft > 0) {
          r.secondsLeft--;
          anyActive = true;
        }
      }

      sharedRideController.riders.refresh();

      if (!anyActive) {
        timer.cancel();
        _globalTimer = null;
      }
    });
  }

  String formatTimer(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<String> getAddressFromLatLng(double lat, double lng) async {
    try {
      final list = await placemarkFromCoordinates(lat, lng);
      final p = list.first;
      return "${p.name}, ${p.locality}, ${p.administrativeArea}";
    } catch (_) {
      return "Location not available";
    }
  }

  String getManeuverIcon(String m) {
    switch (m) {
      case "turn-right":
        return "assets/images/right-turn.png";
      case "turn-left":
        return "assets/images/left-turn.png";
      case "roundabout-left":
        return "assets/images/roundabout-left.png";
      case "roundabout-right":
        return "assets/images/roundabout-right.png";
      default:
        return 'assets/images/straight.png';
    }
  }

  String _formatDistance(double meters) {
    if (meters <= 0) return '0 Km';
    final km = meters / 1000.0;
    return '${km.toStringAsFixed(1)} Km';
  }

  String _formatDuration(double minutes) {
    if (minutes <= 0) return '0 min';
    final total = minutes.round();
    final h = total ~/ 60;
    final m = total % 60;
    return h > 0 ? '$h hr $m min' : '$m min';
  }

  Future<void> _onSelectRider(SharedRiderItem rider) async {
    sharedRideController.activeTarget.value = rider;

    await _routeController.updateDestination(rider.pickupLatLng);

    final origin = _routeUi.value.driverLocation;
    final mapState = _mapKey.currentState;

    if (mapState != null) {
      await mapState.focusOnCustomerRoute(origin, rider.pickupLatLng);
    }
  }

  // ───────── ETA UI ─────────

  Widget _buildPickupEtaRow() {
    return Obx(() {
      final minutes = driverStatusController.pickupDurationInMin.value;
      final meters = driverStatusController.pickupDistanceInMeters.value;

      if (minutes <= 0 && meters <= 0) {
        return const SizedBox.shrink();
      }

      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CustomTextfield.textWithStyles600(
            _formatDuration(minutes),
            fontSize: 18,
          ),
          const SizedBox(width: 8),
          Icon(Icons.circle, color: AppColors.drkGreen, size: 10),
          const SizedBox(width: 8),
          CustomTextfield.textWithStyles600(
            _formatDistance(meters),
            fontSize: 18,
          ),
        ],
      );
    });
  }

  // ──────────────── RIDER CARD ────────────────

  Widget _buildRiderCard(SharedRiderItem rider, {required bool isActive}) {
    final bool showRedTimer = rider.secondsLeft > 0 && rider.secondsLeft <= 10;

    return InkWell(
      onTap: () => _onSelectRider(rider),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isActive ? AppColors.drkGreen : Colors.grey.shade300,
            width: isActive ? 2.5 : 1,
          ),
          boxShadow:
              isActive
                  ? [
                    BoxShadow(
                      color: AppColors.drkGreen.withOpacity(0.18),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ]
                  : const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (rider.secondsLeft > 0)
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color:
                          showRedTimer
                              ? AppColors.timerBorderColor
                              : AppColors.commonBlack.withOpacity(0.15),
                      width: 3.2,
                    ),
                  ),
                  child: Text(
                    formatTimer(rider.secondsLeft),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.4,
                      color:
                          showRedTimer
                              ? AppColors.timerBorderColor
                              : AppColors.commonBlack,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 6),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              trailing: GestureDetector(
                onTap: () => Get.to(ChatScreen(bookingId: rider.bookingId)),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.commonBlack.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  padding: const EdgeInsets.all(10),
                  child: Image.asset(AppImages.msg, height: 25, width: 25),
                ),
              ),
              leading: GestureDetector(
                onTap: () async {
                  final Uri url = Uri.parse('tel:${rider.phone}');
                  if (await canLaunchUrl(url)) await launchUrl(url);
                },
                child: Padding(
                  padding: const EdgeInsets.all(5),
                  child: ClipOval(
                    child: CachedNetworkImage(
                      imageUrl: rider.profilePic,
                      height: 45,
                      width: 45,
                      fit: BoxFit.cover,
                      placeholder:
                          (_, __) => const SizedBox(
                            height: 40,
                            width: 40,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                      errorWidget:
                          (_, __, ___) => const Icon(
                            Icons.person,
                            size: 30,
                            color: Colors.black,
                          ),
                    ),
                  ),
                ),
              ),
              title: CustomTextfield.textWithStyles600(
                rider.name,
                fontSize: 18,
              ),
              subtitle: CustomTextfield.textWithStylesSmall(
                'Shared Rider',
                fontSize: 13,
                colors: AppColors.textColorGrey,
              ),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Column(
                children: [
                  _addrRow(
                    title: 'Pickup',
                    address: rider.pickupAddress,
                    dotColor: Colors.black,
                  ),
                  const SizedBox(height: 10),
                  _addrRow(
                    title: 'Drop off',
                    address: rider.dropoffAddress,
                    dotColor: AppColors.grey,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!rider.arrived &&
                      rider.stage == SharedRiderStage.waitingPickup) ...[
                    Obx(() {
                      final isLoading =
                          driverStatusController
                              .arrivedLoadingBookingId
                              .value ==
                          rider.bookingId;

                      return Buttons.button(
                        buttonColor: AppColors.resendBlue,
                        borderRadius: 10,
                        onTap:
                            isLoading
                                ? null
                                : () async {
                                  final result = await driverStatusController
                                      .driverArrived(
                                        context,
                                        bookingId: rider.bookingId,
                                      );

                                  if (result != null && result.status == 200) {
                                    rider.arrived = true;
                                    sharedRideController.markArrived(
                                      rider.bookingId,
                                    );
                                    _startNoShowTimer(rider);
                                    setState(() {}); // only for this card view
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
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
                            isLoading
                                ? SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: AppLoader.circularLoader(),
                                )
                                : const Text('Arrived at Shared Pickup Point'),
                      );
                    }),
                  ] else if (rider.arrived &&
                      rider.stage == SharedRiderStage.waitingPickup) ...[
                    ActionSlider.standard(
                      controller: rider.sliderController,
                      action: (controller) async {
                        controller.loading();

                        final msg = await driverStatusController.otpRequest(
                          context,
                          bookingId: rider.bookingId,
                          custName: rider.name,
                          pickupAddress: rider.pickupAddress,
                          dropAddress: rider.dropoffAddress,
                        );

                        if (msg == null) {
                          controller.failure();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Failed to send OTP')),
                          );
                          return;
                        }

                        final verified = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                            builder:
                                (_) => VerifyRiderScreen(
                                  bookingId: rider.bookingId,
                                  custName: rider.name,
                                  pickupAddress: rider.pickupAddress,
                                  dropAddress: rider.dropoffAddress,
                                  isSharedRide: true,
                                ),
                          ),
                        );

                        if (verified == true) {
                          controller.success();
                          sharedRideController.markOnboard(rider.bookingId);
                          if (!mounted) return;

                          Get.off(
                            () => ShareRideStartScreen(
                              pickupLocation: rider.pickupLatLng,
                              driverLocation: _routeUi.value.driverLocation,
                              bookingId: widget.bookingId,
                            ),
                          );
                        } else {
                          controller.reset();
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
                        'Swipe to Start Ride for ${rider.name}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ] else if (rider.stage == SharedRiderStage.onboardDrop) ...[
                    CustomTextfield.textWithStylesSmall(
                      'Already onboard (drop from Start screen)',
                      colors: AppColors.textColorGrey,
                      fontSize: 13,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _addrRow({
    required String title,
    required String address,
    required Color dotColor,
  }) {
    return Row(
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(40),
            color: AppColors.commonBlack.withOpacity(0.08),
          ),
          padding: const EdgeInsets.all(4),
          child: Icon(Icons.circle, size: 10, color: dotColor),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CustomTextfield.textWithStyles600(title, fontSize: 14),
              CustomTextfield.textWithStylesSmall(
                address,
                colors: AppColors.textColorGrey,
                maxLine: 2,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ────────────────────── UI ──────────────────────

  @override
  Widget build(BuildContext context) {
    return NoInternetOverlay(
      child: Stack(
        children: [
          WillPopScope(
            onWillPop: () async => false,
            child: Scaffold(
              body: Stack(
                children: [
                  // ✅ Map + header updates only when route UI changes
                  ValueListenableBuilder<RouteUiState>(
                    valueListenable: _routeUi,
                    builder: (context, uiState, _) {
                      final currentTarget =
                          sharedRideController
                              .activeTarget
                              .value
                              ?.pickupLatLng ??
                          widget.pickupLocation;

                      final markers = <Marker>{
                        Marker(
                          markerId: const MarkerId('driver'),
                          position: uiState.driverLocation,
                          icon: carIcon ?? BitmapDescriptor.defaultMarker,
                          rotation: uiState.bearing,
                          anchor: const Offset(0.5, 0.5),
                          flat: true,
                        ),
                        Marker(
                          markerId: const MarkerId('pickup_main'),
                          position: widget.pickupLocation,
                          infoWindow: const InfoWindow(title: 'Pickup Area'),
                        ),
                        ...sharedRideController.riders.map(
                          (r) => Marker(
                            markerId: MarkerId('pickup_${r.bookingId}'),
                            position: r.pickupLatLng,
                            icon: BitmapDescriptor.defaultMarkerWithHue(
                              BitmapDescriptor.hueGreen,
                            ),
                            infoWindow: InfoWindow(title: r.name),
                          ),
                        ),
                      };

                      return Stack(
                        children: [
                          SizedBox(
                            height: 550,
                            width: double.infinity,
                            child: RepaintBoundary(
                              child: SharedMap(
                                key: _mapKey,
                                initialPosition: widget.pickupLocation,
                                pickupPosition: currentTarget,
                                markers: markers,
                                polylines: {
                                  if (uiState.polyline.length >= 2)
                                    Polyline(
                                      polylineId: const PolylineId(
                                        "route_to_rider",
                                      ),
                                      color: AppColors.commonBlack,
                                      width: 5,
                                      points: uiState.polyline,
                                    ),
                                },
                                myLocationEnabled: true,
                                fitToBounds: false,
                              ),
                            ),
                          ),

                          // cleaner header
                          Positioned(
                            top: 45,
                            left: 10,
                            right: 10,
                            child: _DirectionHeader(
                              maneuver: uiState.maneuver,
                              distanceText: uiState.distanceText,
                              directionText: uiState.directionText,
                              getManeuverIcon: getManeuverIcon,
                            ),
                          ),
                        ],
                      );
                    },
                  ),

                  // Focus button
                  Positioned(
                    top: 350,
                    right: 10,
                    child: SafeArea(
                      child: GestureDetector(
                        onTap: () {
                          final mapState = _mapKey.currentState;
                          if (mapState == null) return;

                          if (_isDriverFocused) {
                            mapState.fitRouteBounds();
                          } else {
                            mapState.focusPickup();
                          }

                          setState(() => _isDriverFocused = !_isDriverFocused);
                        },
                        child: Container(
                          height: 42,
                          width: 42,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 10,
                                offset: Offset(0, 4),
                              ),
                            ],
                            border: Border.all(
                              color: Colors.black.withOpacity(0.05),
                            ),
                          ),
                          child: Icon(
                            _isDriverFocused
                                ? Icons.crop_square_rounded
                                : Icons.my_location,
                            size: 22,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Bottom sheet (list)
                  DraggableScrollableSheet(
                    initialChildSize: 0.45,
                    minChildSize: 0.35,
                    maxChildSize: 0.99,
                    builder: (context, scrollController) {
                      return Container(
                        color: Colors.white,
                        child: Obx(() {
                          final active =
                              sharedRideController.activeTarget.value;

                          return ListView(
                            controller: scrollController,
                            physics: const BouncingScrollPhysics(),
                            children: [
                              const SizedBox(height: 6),
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
                              const SizedBox(height: 8),

                              if (active != null) ...[
                                const SizedBox(height: 8),
                                _buildPickupEtaRow(),
                                const SizedBox(height: 12),
                              ],

                              if (sharedRideController.riders.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.all(24.0),
                                  child: Center(
                                    child: CustomTextfield.textWithStylesSmall(
                                      'Waiting for shared ride requests…',
                                      colors: AppColors.textColorGrey,
                                    ),
                                  ),
                                )
                              else
                                ...sharedRideController.riders.map((rider) {
                                  final activeR =
                                      sharedRideController.activeTarget.value;
                                  final isActive =
                                      activeR != null &&
                                      activeR.bookingId == rider.bookingId;

                                  return _buildRiderCard(
                                    rider,
                                    isActive: isActive,
                                  );
                                }).toList(),

                              if (sharedRideController.riders.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 12,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Obx(() {
                                        final stopped =
                                            driverStatusController
                                                .isStopNewRequests
                                                .value;

                                        return Buttons.button(
                                          borderColor: AppColors.buttonBorder,
                                          buttonColor:
                                              stopped
                                                  ? AppColors.containerColor
                                                  : AppColors.commonWhite,
                                          borderRadius: 10,
                                          textColor: AppColors.commonBlack,
                                          onTap:
                                              stopped
                                                  ? null
                                                  : () => Buttons.showDialogBox(
                                                    context: context,
                                                    onConfirmStop: () async {
                                                      await driverStatusController
                                                          .stopNewRideRequest(
                                                            context: context,
                                                            stop: true,
                                                          );
                                                    },
                                                  ),
                                          text: Text(
                                            stopped
                                                ? 'Already Stopped'
                                                : 'Stop New Ride Requests',
                                          ),
                                        );
                                      }),
                                      const SizedBox(height: 10),
                                      Buttons.button(
                                        borderRadius: 10,
                                        buttonColor: AppColors.red,
                                        onTap: () {
                                          Buttons.showCancelRideBottomSheet(
                                            context,
                                            onConfirmCancel: (reason) async {
                                              await driverStatusController
                                                  .cancelBooking(
                                                    bookingId: widget.bookingId,
                                                    context,
                                                    reason: reason,
                                                  );
                                            },
                                          );
                                        },
                                        text: const Text(
                                          'Cancel this Shared Ride',
                                        ),
                                      ),
                                      const SizedBox(height: 20),
                                    ],
                                  ),
                                ),
                            ],
                          );
                        }),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const BookingOverlayRequest(),
        ],
      ),
    );
  }
}

class _DirectionHeader extends StatelessWidget {
  final String maneuver;
  final String distanceText;
  final String directionText;
  final String Function(String) getManeuverIcon;

  const _DirectionHeader({
    required this.maneuver,
    required this.distanceText,
    required this.directionText,
    required this.getManeuverIcon,
  });

  @override
  Widget build(BuildContext context) {
    // Keep header stable (avoid flicker)
    final safeDistance = distanceText.isEmpty ? '--' : distanceText;
    final safeDirection =
        directionText.isEmpty ? 'Searching best route…' : directionText;

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Row(
        children: [
          Expanded(
            flex: 1,
            child: Container(
              height: 92,
              color: AppColors.directionColor,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 14,
                  horizontal: 10,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      getManeuverIcon(maneuver),
                      height: 30,
                      width: 30,
                    ),
                    const SizedBox(height: 6),
                    CustomTextfield.textWithStyles600(
                      safeDistance,
                      color: AppColors.commonWhite,
                      fontSize: 14,
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Container(
              height: 92,
              color: AppColors.directionColor1,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 14,
                  horizontal: 12,
                ),
                child: Center(
                  child: CustomTextfield.textWithStyles600(
                    safeDirection,
                    fontSize: 13,
                    color: AppColors.commonWhite,
                    maxLine: 2,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// // lib/Presentation/DriverScreen/screens/SharedBooking/Screens/picking_customer_shared_screen.dart
//
// import 'dart:async';
// import 'dart:ui' as ui;
//
// import 'package:action_slider/action_slider.dart';
// import 'package:cached_network_image/cached_network_image.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:geocoding/geocoding.dart';
// import 'package:get/get.dart';
// import 'package:google_maps_flutter/google_maps_flutter.dart';
// import 'package:hopper/api/repository/api_constents.dart';
// import 'package:url_launcher/url_launcher.dart';
//
// import 'package:hopper/Core/Constants/Colors.dart';
// import 'package:hopper/Core/Utility/Buttons.dart';
// import 'package:hopper/Core/Utility/images.dart';
// import 'package:hopper/Core/Utility/app_loader.dart';
// import 'package:hopper/Presentation/Authentication/widgets/textFields.dart';
// import 'package:hopper/Presentation/DriverScreen/controller/driver_status_controller.dart';
// import 'package:hopper/Presentation/DriverScreen/screens/SharedBooking/Controller/shared_controller.dart';
// import 'package:hopper/Presentation/DriverScreen/screens/SharedBooking/Controller/shared_ride_controller.dart';
// import 'package:hopper/Presentation/DriverScreen/screens/SharedBooking/Screens/share_ride_start_screen.dart';
// import 'package:hopper/Presentation/DriverScreen/screens/SharedBooking/Screens/shared_screens.dart';
// import 'package:hopper/Presentation/DriverScreen/screens/chat_screen.dart';
// import 'package:hopper/Presentation/DriverScreen/screens/driver_main_screen.dart';
// import 'package:hopper/utils/map/shared_map.dart';
// import 'package:hopper/utils/netWorkHandling/network_handling_screen.dart';
// import 'package:hopper/Core/Constants/log.dart';
//
// import '../../../../../utils/map/driver_route.dart';
// import '../../../../../utils/sharedprefsHelper/local_data_store.dart';
// import '../../../../../utils/websocket/socket_io_client.dart';
// import '../../verify_rider_screen.dart';
// import '../Controller/booking_request_controller.dart';
// import 'booking_overlay_request.dart';
//
// class PickingCustomerSharedScreen extends StatefulWidget {
//   final LatLng pickupLocation;
//   final String? pickupLocationAddress;
//   final String? dropLocationAddress;
//   final LatLng driverLocation;
//   final String bookingId; // pool / main booking
//
//   const PickingCustomerSharedScreen({
//     Key? key,
//     required this.pickupLocation,
//     required this.driverLocation,
//     required this.bookingId,
//     this.pickupLocationAddress,
//     this.dropLocationAddress,
//   }) : super(key: key);
//
//   @override
//   State<PickingCustomerSharedScreen> createState() =>
//       _PickingCustomerSharedScreenState();
// }
//
// class _PickingCustomerSharedScreenState
//     extends State<PickingCustomerSharedScreen>
//     with SingleTickerProviderStateMixin {
//   late DriverRouteController _routeController;
//   final SharedController sharedController = Get.put(SharedController());
//   final DriverStatusController driverStatusController = Get.put(
//     DriverStatusController(),
//   );
//   // ⬇️ Use shared instance from SharedController
//   final SharedRideController sharedRideController =
//       Get.find<SharedRideController>();
//   final BookingRequestController bookingController =
//       Get.find<BookingRequestController>();
//   final GlobalKey<SharedMapState> _mapKey = GlobalKey<SharedMapState>();
//
//   LatLng? driverLocation;
//   double carBearing = 0.0;
//   List<LatLng> polylinePoints = [];
//   String directionText = '';
//   String distance = '';
//   String maneuver = '';
//   DateTime? _lastRouteUiUpdate;
//
//   BitmapDescriptor? carIcon;
//
//   late SocketService socketService;
//
//   Timer? _globalTimer;
//   bool _isDriverFocused = false;
//   late AnimationController _pulseController;
//   late Animation<double> _pulseAnimation;
//
//   @override
//   void initState() {
//     super.initState();
//
//     SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
//     SystemChrome.setSystemUIOverlayStyle(
//       const SystemUiOverlayStyle(
//         statusBarColor: Colors.transparent,
//         statusBarIconBrightness: Brightness.dark,
//       ),
//     );
//
//     _initSocket();
//     _loadMarkerIcons();
//     _routeController = DriverRouteController(
//       destination: widget.pickupLocation,
//       onRouteUpdate: (update) {
//         if (!mounted) return;
//
//         // ✅ Always keep driver location for logic
//         sharedRideController.updateDriverLocation(update.driverLocation);
//
//         // 🔄 Throttle UI updates (e.g. every 300 ms)
//         final now = DateTime.now();
//         if (_lastRouteUiUpdate != null &&
//             now.difference(_lastRouteUiUpdate!).inMilliseconds < 300) {
//           return;
//         }
//         _lastRouteUiUpdate = now;
//
//         // 🔻 Downsample polyline to reduce heavy drawing
//         List<LatLng> simplifiedPolyline = update.polylinePoints;
//         if (simplifiedPolyline.length > 200) {
//           simplifiedPolyline = [
//             for (int i = 0; i < update.polylinePoints.length; i += 3)
//               update.polylinePoints[i],
//           ];
//         }
//
//         setState(() {
//           driverLocation = update.driverLocation;
//           carBearing = update.bearing;
//           polylinePoints = simplifiedPolyline;
//           directionText = update.directionText;
//           distance = update.distanceText;
//           maneuver = update.maneuver;
//         });
//       },
//       onCameraUpdate: (_) {},
//     );
//
//     _routeController.start();
//
//     _pulseController = AnimationController(
//       vsync: this,
//       duration: const Duration(seconds: 2),
//     )..repeat();
//
//     _pulseAnimation = Tween<double>(begin: 0, end: 60).animate(
//       CurvedAnimation(parent: _pulseController, curve: Curves.easeOut),
//     )..addListener(() {
//       if (!mounted) return;
//       if (_isDriverFocused) setState(() {});
//     });
//   }
//
//   @override
//   void dispose() {
//     _globalTimer?.cancel();
//     _routeController.dispose();
//     _pulseController.dispose();
//
//     try {
//       // joined-booking is handled globally in SharedController now
//       // socketService.socket.off('joined-booking');
//       // socketService.socket.off('driver-location');
//       socketService.socket.off('driver-cancelled');
//       socketService.socket.off('customer-cancelled');
//       socketService.socket.off('driver-arrived');
//     } catch (_) {}
//
//     super.dispose();
//   }
//
//   // ───────────────── SOCKET SETUP ─────────────────
//
//   Future<void> _initSocket() async {
//     socketService = SocketService();
//     socketService.initSocket(ApiConstents.sharedRideSocket);
//
//     // 🔹 booking-request → show popup via BookingRequestController
//     socketService.on('booking-request', (data) async {
//       if (data == null) return;
//       CommonLogger.log.i('[SHARED PICK] 📦 Booking Request → $data');
//
//       final incomingId = data['bookingId']?.toString();
//
//       // 🛑 1. Ignore if same as the main/shared booking we are already on
//       if (incomingId == widget.bookingId) {
//         CommonLogger.log.i(
//           '[SHARED PICK] Ignoring booking-request for current bookingId=$incomingId',
//         );
//         return;
//       }
//
//       // 🛑 2. Ignore if this booking was already handled on ANY screen
//       if (incomingId != null &&
//           incomingId == bookingController.lastHandledBookingId.value) {
//         CommonLogger.log.i(
//           '[SHARED PICK] Ignoring already-handled bookingId=$incomingId',
//         );
//         return;
//       }
//
//       // ✅ 3. Normal flow → show popup for *new* shared requests
//       final pickup = data['pickupLocation'];
//       final drop = data['dropLocation'];
//
//       if (pickup == null || drop == null) {
//         CommonLogger.log.w(
//           '[SHARED PICK] pickup/drop missing in booking-request',
//         );
//         return;
//       }
//
//       final pickupAddr = await getAddressFromLatLng(
//         (pickup['latitude'] as num).toDouble(),
//         (pickup['longitude'] as num).toDouble(),
//       );
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
//     void handleDriverLocation(dynamic data) {
//       CommonLogger.log.i('[SHARED PICK] driver-location: $data');
//       if (data == null) return;
//
//       final active = sharedRideController.activeTarget.value;
//       final eventBookingId = data['bookingId']?.toString();
//
//       if (active != null && eventBookingId != null) {
//         if (eventBookingId != active.bookingId) {
//           return;
//         }
//       }
//
//       if (data['pickupDistanceInMeters'] != null) {
//         driverStatusController.pickupDistanceInMeters.value =
//             (data['pickupDistanceInMeters'] as num).toDouble();
//       }
//       if (data['pickupDurationInMin'] != null) {
//         driverStatusController.pickupDurationInMin.value =
//             (data['pickupDurationInMin'] as num).toDouble();
//       }
//     }
//
//     socketService.on('driver-cancelled', (data) {
//       if (data != null && data['status'] == true) {
//         if (!mounted) return;
//         Get.offAll(() => const DriverMainScreen());
//       }
//     });
//
//     socketService.on('customer-cancelled', (data) {
//       if (data != null && data['status'] == true) {
//         if (!mounted) return;
//         Get.offAll(() => const DriverMainScreen());
//       }
//     });
//
//     socketService.on('driver-arrived', (data) {
//       CommonLogger.log.i('[SHARED PICK] driver-arrived : $data');
//     });
//
//     socketService.onConnect(() {
//       CommonLogger.log.i("✅ [SHARED PICK] Socket connected");
//       socketService.on('driver-location', handleDriverLocation);
//     });
//
//     if (socketService.connected) {
//       CommonLogger.log.i(
//         "✅ [SHARED PICK] already connected → attach driver-location",
//       );
//       socketService.on('driver-location', handleDriverLocation);
//     }
//
//     socketService.connect();
//   }
//
//   // ──────────────── HELPERS ────────────────
//
//   Future<BitmapDescriptor> _bitmapFromAsset(
//     String path, {
//     int width = 48,
//   }) async {
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
//   Future<void> _loadMarkerIcons() async {
//     try {
//       final icon = await _bitmapFromAsset(AppImages.movingCar, width: 74);
//       if (!mounted) return;
//       setState(() {
//         carIcon = icon;
//       });
//     } catch (_) {
//       carIcon = BitmapDescriptor.defaultMarker;
//     }
//   }
//
//   void _startNoShowTimer(SharedRiderItem rider) {
//     rider.secondsLeft = 300;
//     sharedRideController.riders.refresh();
//
//     if (_globalTimer != null) return;
//
//     _globalTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
//       if (!mounted) {
//         timer.cancel();
//         _globalTimer = null;
//         return;
//       }
//
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
//   String formatTimer(int seconds) {
//     final m = (seconds ~/ 60).toString().padLeft(2, '0');
//     final s = (seconds % 60).toString().padLeft(2, '0');
//     return '$m:$s';
//   }
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
//   String _formatDistance(double meters) {
//     if (meters <= 0) return '0 Km';
//     final km = meters / 1000.0;
//     return '${km.toStringAsFixed(1)} Km';
//   }
//
//   String _formatDuration(double minutes) {
//     if (minutes <= 0) return '0 min';
//     final total = minutes.round();
//     final h = total ~/ 60;
//     final m = total % 60;
//     return h > 0 ? '$h hr $m min' : '$m min';
//   }
//
//   void _onSelectRider(SharedRiderItem rider) async {
//     sharedRideController.activeTarget.value = rider;
//
//     await _routeController.updateDestination(rider.pickupLatLng);
//
//     final origin = driverLocation ?? widget.driverLocation;
//     final mapState = _mapKey.currentState;
//
//     if (mapState != null) {
//       await mapState.focusOnCustomerRoute(origin, rider.pickupLatLng);
//     }
//
//     if (mounted) {
//       setState(() {});
//     }
//   }
//
//   // ───────── ETA UI FOR PICKUP (THIS SCREEN) ─────────
//
//   Widget _buildPickupEtaRow() {
//     return Obx(() {
//       final minutes = driverStatusController.pickupDurationInMin.value;
//       final meters = driverStatusController.pickupDistanceInMeters.value;
//
//       if (minutes <= 0 && meters <= 0) {
//         return const SizedBox.shrink();
//       }
//
//       return Row(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           CustomTextfield.textWithStyles600(
//             _formatDuration(minutes),
//             fontSize: 18,
//           ),
//           const SizedBox(width: 8),
//           Icon(Icons.circle, color: AppColors.drkGreen, size: 10),
//           const SizedBox(width: 8),
//           CustomTextfield.textWithStyles600(
//             _formatDistance(meters),
//             fontSize: 18,
//           ),
//         ],
//       );
//     });
//   }
//
//   // ──────────────── RIDER CARD ────────────────
//
//   Widget _buildRiderCard(SharedRiderItem rider, {required bool isActive}) {
//     final bool showRedTimer = rider.secondsLeft > 0 && rider.secondsLeft <= 10;
//
//     return InkWell(
//       onTap: () => _onSelectRider(rider),
//       child: Container(
//         margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
//         padding: const EdgeInsets.symmetric(vertical: 8),
//         decoration: BoxDecoration(
//           color: Colors.white,
//           borderRadius: BorderRadius.circular(12),
//           border: Border.all(
//             color: isActive ? AppColors.drkGreen : Colors.grey.shade300,
//             width: isActive ? 3 : 1,
//           ),
//           boxShadow:
//               isActive
//                   ? [
//                     BoxShadow(
//                       color: AppColors.drkGreen.withOpacity(0.25),
//                       blurRadius: 10,
//                       offset: const Offset(0, 4),
//                     ),
//                   ]
//                   : [],
//         ),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             if (rider.secondsLeft > 0)
//               Center(
//                 child: Container(
//                   padding: const EdgeInsets.symmetric(
//                     horizontal: 18,
//                     vertical: 6,
//                   ),
//                   decoration: BoxDecoration(
//                     color: Colors.white,
//                     borderRadius: BorderRadius.circular(30),
//                     border: Border.all(
//                       color:
//                           showRedTimer
//                               ? AppColors.timerBorderColor
//                               : AppColors.commonBlack.withOpacity(0.2),
//                       width: 4,
//                     ),
//                   ),
//                   child: Text(
//                     formatTimer(rider.secondsLeft),
//                     style: TextStyle(
//                       fontSize: 13,
//                       fontWeight: FontWeight.bold,
//                       letterSpacing: 1.5,
//                       color:
//                           showRedTimer
//                               ? AppColors.timerBorderColor
//                               : AppColors.commonBlack,
//                     ),
//                   ),
//                 ),
//               ),
//             const SizedBox(height: 6),
//             ListTile(
//               contentPadding: const EdgeInsets.symmetric(horizontal: 12),
//               trailing: GestureDetector(
//                 onTap: () {
//                   Get.to(ChatScreen(bookingId: rider.bookingId));
//                 },
//                 child: Container(
//                   decoration: BoxDecoration(
//                     color: AppColors.commonBlack.withOpacity(0.1),
//                     borderRadius: BorderRadius.circular(30),
//                   ),
//                   padding: const EdgeInsets.all(10),
//                   child: Image.asset(AppImages.msg, height: 25, width: 25),
//                 ),
//               ),
//               leading: GestureDetector(
//                 onTap: () async {
//                   final Uri url = Uri.parse('tel:${rider.phone}');
//                   if (await canLaunchUrl(url)) {
//                     await launchUrl(url);
//                   }
//                 },
//                 child: Padding(
//                   padding: const EdgeInsets.all(5),
//                   child: ClipOval(
//                     child: CachedNetworkImage(
//                       imageUrl: rider.profilePic,
//                       height: 45,
//                       width: 45,
//                       fit: BoxFit.cover,
//                       placeholder:
//                           (context, url) => const SizedBox(
//                             height: 40,
//                             width: 40,
//                             child: CircularProgressIndicator(strokeWidth: 2),
//                           ),
//                       errorWidget:
//                           (context, url, error) => const Icon(
//                             Icons.person,
//                             size: 30,
//                             color: Colors.black,
//                           ),
//                     ),
//                   ),
//                 ),
//               ),
//               title: CustomTextfield.textWithStyles600(
//                 rider.name,
//                 fontSize: 18,
//               ),
//               subtitle: CustomTextfield.textWithStylesSmall(
//                 'Shared Rider',
//                 fontSize: 13,
//                 colors: AppColors.textColorGrey,
//               ),
//             ),
//             const SizedBox(height: 6),
//             Padding(
//               padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
//               child: Column(
//                 children: [
//                   Row(
//                     children: [
//                       Container(
//                         decoration: BoxDecoration(
//                           borderRadius: BorderRadius.circular(40),
//                           color: AppColors.commonBlack.withOpacity(0.1),
//                         ),
//                         padding: const EdgeInsets.all(4),
//                         child: const Icon(
//                           Icons.circle,
//                           size: 10,
//                           color: Colors.black,
//                         ),
//                       ),
//                       const SizedBox(width: 16),
//                       Expanded(
//                         child: Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             CustomTextfield.textWithStyles600(
//                               'Pickup',
//                               fontSize: 14,
//                             ),
//                             CustomTextfield.textWithStylesSmall(
//                               rider.pickupAddress,
//                               colors: AppColors.textColorGrey,
//                               maxLine: 2,
//                             ),
//                           ],
//                         ),
//                       ),
//                     ],
//                   ),
//                   const SizedBox(height: 10),
//                   Row(
//                     children: [
//                       Container(
//                         decoration: BoxDecoration(
//                           borderRadius: BorderRadius.circular(40),
//                           color: AppColors.commonBlack.withOpacity(0.1),
//                         ),
//                         padding: const EdgeInsets.all(4),
//                         child: Icon(
//                           Icons.circle,
//                           size: 10,
//                           color: AppColors.grey,
//                         ),
//                       ),
//                       const SizedBox(width: 16),
//                       Expanded(
//                         child: Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             CustomTextfield.textWithStyles600(
//                               'Drop off',
//                               fontSize: 14,
//                             ),
//                             CustomTextfield.textWithStylesSmall(
//                               rider.dropoffAddress,
//                               colors: AppColors.textColorGrey,
//                               maxLine: 2,
//                             ),
//                           ],
//                         ),
//                       ),
//                     ],
//                   ),
//                 ],
//               ),
//             ),
//             const SizedBox(height: 10),
//             Padding(
//               padding: const EdgeInsets.symmetric(horizontal: 16),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   if (!rider.arrived &&
//                       rider.stage == SharedRiderStage.waitingPickup) ...[
//                     Obx(() {
//                       final isLoading =
//                           driverStatusController
//                               .arrivedLoadingBookingId
//                               .value ==
//                           rider.bookingId;
//
//                       return Buttons.button(
//                         buttonColor: AppColors.resendBlue,
//                         borderRadius: 8,
//                         onTap:
//                             isLoading
//                                 ? null
//                                 : () async {
//                                   final result = await driverStatusController
//                                       .driverArrived(
//                                         context,
//                                         bookingId: rider.bookingId,
//                                       );
//
//                                   if (result != null && result.status == 200) {
//                                     setState(() {
//                                       rider.arrived = true;
//                                     });
//
//                                     sharedRideController.markArrived(
//                                       rider.bookingId,
//                                     );
//                                     _startNoShowTimer(rider);
//                                   } else {
//                                     ScaffoldMessenger.of(context).showSnackBar(
//                                       SnackBar(
//                                         content: Text(
//                                           result?.message ??
//                                               "Something went wrong",
//                                         ),
//                                       ),
//                                     );
//                                   }
//                                 },
//                         text:
//                             isLoading
//                                 ? SizedBox(
//                                   height: 20,
//                                   width: 20,
//                                   child: AppLoader.circularLoader(),
//                                 )
//                                 : const Text('Arrived at Shared Pickup Point'),
//                       );
//                     }),
//                   ] else if (rider.arrived &&
//                       rider.stage == SharedRiderStage.waitingPickup) ...[
//                     ActionSlider.standard(
//                       controller: rider.sliderController,
//                       action: (controller) async {
//                         controller.loading();
//
//                         final msg = await driverStatusController.otpRequest(
//                           context,
//                           bookingId: rider.bookingId,
//                           custName: rider.name,
//                           pickupAddress: rider.pickupAddress,
//                           dropAddress: rider.dropoffAddress,
//                         );
//
//                         if (msg == null) {
//                           controller.failure();
//                           ScaffoldMessenger.of(context).showSnackBar(
//                             const SnackBar(content: Text('Failed to send OTP')),
//                           );
//                           return;
//                         }
//
//                         final verified = await Navigator.push<bool>(
//                           context,
//                           MaterialPageRoute(
//                             builder:
//                                 (_) => VerifyRiderScreen(
//                                   bookingId: rider.bookingId,
//                                   custName: rider.name,
//                                   pickupAddress: rider.pickupAddress,
//                                   dropAddress: rider.dropoffAddress,
//                                   isSharedRide: true,
//                                 ),
//                           ),
//                         );
//
//                         if (verified == true) {
//                           controller.success();
//
//                           sharedRideController.markOnboard(rider.bookingId);
//
//                           if (!mounted) return;
//
//                           Get.off(
//                             () => ShareRideStartScreen(
//                               pickupLocation: rider.pickupLatLng,
//                               driverLocation:
//                                   driverLocation ?? widget.driverLocation,
//                               bookingId: widget.bookingId,
//                             ),
//                           );
//                         } else {
//                           controller.reset();
//                         }
//                       },
//                       height: 50,
//                       backgroundColor: const Color(0xFF1C1C1C),
//                       toggleColor: Colors.white,
//                       icon: const Icon(
//                         Icons.double_arrow,
//                         color: Colors.black,
//                         size: 28,
//                       ),
//                       child: Text(
//                         'Swipe to Start Ride for ${rider.name}',
//                         style: const TextStyle(
//                           color: Colors.white,
//                           fontSize: 18,
//                           fontWeight: FontWeight.bold,
//                         ),
//                       ),
//                     ),
//                   ] else if (rider.stage == SharedRiderStage.onboardDrop) ...[
//                     CustomTextfield.textWithStylesSmall(
//                       'Already onboard (drop from Start screen)',
//                       colors: AppColors.textColorGrey,
//                       fontSize: 13,
//                     ),
//                   ],
//                 ],
//               ),
//             ),
//             const SizedBox(height: 10),
//           ],
//         ),
//       ),
//     );
//   }
//
//   // ────────────────────── UI ──────────────────────
//
//   @override
//   Widget build(BuildContext context) {
//     final markers = <Marker>{
//       Marker(
//         markerId: const MarkerId('driver'),
//         position: driverLocation ?? widget.driverLocation,
//         icon: carIcon ?? BitmapDescriptor.defaultMarker,
//         rotation: carBearing,
//         anchor: const Offset(0.5, 0.5),
//         flat: true,
//       ),
//       Marker(
//         markerId: const MarkerId('pickup_main'),
//         position: widget.pickupLocation,
//         infoWindow: const InfoWindow(title: 'Pickup Area'),
//       ),
//       ...sharedRideController.riders.map(
//         (r) => Marker(
//           markerId: MarkerId('pickup_${r.bookingId}'),
//           position: r.pickupLatLng,
//           icon: BitmapDescriptor.defaultMarkerWithHue(
//             BitmapDescriptor.hueGreen,
//           ),
//           infoWindow: InfoWindow(title: r.name),
//         ),
//       ),
//     };
//
//     final currentTarget =
//         sharedRideController.activeTarget.value?.pickupLatLng ??
//         widget.pickupLocation;
//
//     return NoInternetOverlay(
//       child: Stack(
//         children: [
//           WillPopScope(
//             onWillPop: () async => false,
//             child: Scaffold(
//               body: Stack(
//                 children: [
//                   SizedBox(
//                     height: 550,
//                     width: double.infinity,
//                     child: SharedMap(
//                       key: _mapKey,
//                       initialPosition: widget.pickupLocation,
//                       pickupPosition: currentTarget,
//                       markers: markers,
//                       polylines: {
//                         if (polylinePoints.length >= 2)
//                           Polyline(
//                             polylineId: const PolylineId("route_to_rider"),
//                             color: AppColors.commonBlack,
//                             width: 5,
//                             points: polylinePoints,
//                           ),
//                       },
//                       myLocationEnabled: true,
//                       fitToBounds: false,
//                     ),
//                   ),
//                   Positioned(
//                     top: 350,
//                     right: 10,
//                     child: SafeArea(
//                       child: GestureDetector(
//                         onTap: () {
//                           final mapState = _mapKey.currentState;
//                           if (mapState == null) return;
//
//                           if (_isDriverFocused) {
//                             mapState.fitRouteBounds();
//                           } else {
//                             mapState.focusPickup();
//                           }
//
//                           setState(() => _isDriverFocused = !_isDriverFocused);
//                         },
//                         child: Container(
//                           height: 42,
//                           width: 42,
//                           decoration: BoxDecoration(
//                             color: Colors.white,
//                             borderRadius: BorderRadius.circular(10),
//                             boxShadow: const [
//                               BoxShadow(
//                                 color: Colors.black12,
//                                 blurRadius: 8,
//                                 offset: Offset(0, 3),
//                               ),
//                             ],
//                             border: Border.all(
//                               color: Colors.black.withOpacity(0.05),
//                             ),
//                           ),
//                           child: Icon(
//                             _isDriverFocused
//                                 ? Icons.crop_square_rounded
//                                 : Icons.my_location,
//                             size: 22,
//                             color: Colors.black87,
//                           ),
//                         ),
//                       ),
//                     ),
//                   ),
//                   Positioned(
//                     top: 45,
//                     left: 10,
//                     right: 10,
//                     child: Row(
//                       children: [
//                         Expanded(
//                           flex: 1,
//                           child: Container(
//                             height: 100,
//                             color: AppColors.directionColor,
//                             child: Padding(
//                               padding: const EdgeInsets.symmetric(
//                                 vertical: 20,
//                                 horizontal: 10,
//                               ),
//                               child: Column(
//                                 crossAxisAlignment: CrossAxisAlignment.center,
//                                 children: [
//                                   Image.asset(
//                                     getManeuverIcon(maneuver),
//                                     height: 32,
//                                     width: 32,
//                                   ),
//                                   const SizedBox(height: 5),
//                                   CustomTextfield.textWithStyles600(
//                                     distance,
//                                     color: AppColors.commonWhite,
//                                   ),
//                                 ],
//                               ),
//                             ),
//                           ),
//                         ),
//                         Expanded(
//                           flex: 3,
//                           child: Container(
//                             height: 100,
//                             color: AppColors.directionColor1,
//                             child: Padding(
//                               padding: const EdgeInsets.symmetric(
//                                 vertical: 20,
//                                 horizontal: 10,
//                               ),
//                               child: Column(
//                                 crossAxisAlignment: CrossAxisAlignment.center,
//                                 mainAxisAlignment: MainAxisAlignment.center,
//                                 children: [
//                                   CustomTextfield.textWithStyles600(
//                                     maxLine: 2,
//                                     directionText,
//                                     fontSize: 13,
//                                     color: AppColors.commonWhite,
//                                   ),
//                                 ],
//                               ),
//                             ),
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                   DraggableScrollableSheet(
//                     initialChildSize: 0.45,
//                     minChildSize: 0.35,
//                     maxChildSize: 0.99,
//                     builder: (context, scrollController) {
//                       return Container(
//                         color: Colors.white,
//                         child: Obx(() {
//                           final active =
//                               sharedRideController.activeTarget.value;
//                           return ListView(
//                             controller: scrollController,
//                             physics: const BouncingScrollPhysics(),
//                             children: [
//                               const SizedBox(height: 6),
//                               Center(
//                                 child: Container(
//                                   width: 60,
//                                   height: 5,
//                                   decoration: BoxDecoration(
//                                     color: Colors.grey[400],
//                                     borderRadius: BorderRadius.circular(10),
//                                   ),
//                                 ),
//                               ),
//                               const SizedBox(height: 8),
//                               if (active != null) ...[
//                                 const SizedBox(height: 8),
//                                 _buildPickupEtaRow(),
//                                 const SizedBox(height: 12),
//                               ],
//                               if (sharedRideController.riders.isEmpty)
//                                 Padding(
//                                   padding: const EdgeInsets.all(24.0),
//                                   child: Center(
//                                     child: CustomTextfield.textWithStylesSmall(
//                                       'Waiting for shared ride requests…',
//                                       colors: AppColors.textColorGrey,
//                                     ),
//                                   ),
//                                 )
//                               else
//                                 ...sharedRideController.riders.map((rider) {
//                                   final active =
//                                       sharedRideController.activeTarget.value;
//                                   final isActive =
//                                       active != null &&
//                                       active.bookingId == rider.bookingId;
//
//                                   return _buildRiderCard(
//                                     rider,
//                                     isActive: isActive,
//                                   );
//                                 }).toList(),
//                               if (sharedRideController.riders.isNotEmpty)
//                                 Padding(
//                                   padding: const EdgeInsets.symmetric(
//                                     horizontal: 20,
//                                     vertical: 12,
//                                   ),
//                                   child: Column(
//                                     crossAxisAlignment:
//                                         CrossAxisAlignment.start,
//                                     children: [
//                                       Obx(() {
//                                         final stopped =
//                                             driverStatusController
//                                                 .isStopNewRequests
//                                                 .value;
//
//                                         return Buttons.button(
//                                           borderColor: AppColors.buttonBorder,
//                                           buttonColor:
//                                               stopped
//                                                   ? AppColors.containerColor
//                                                   : AppColors.commonWhite,
//                                           borderRadius: 8,
//                                           textColor: AppColors.commonBlack,
//                                           onTap:
//                                               stopped
//                                                   ? null
//                                                   : () => Buttons.showDialogBox(
//                                                     context: context,
//                                                     onConfirmStop: () async {
//                                                       await driverStatusController
//                                                           .stopNewRideRequest(
//                                                             context: context,
//                                                             stop: true,
//                                                           );
//                                                     },
//                                                   ),
//                                           text: Text(
//                                             stopped
//                                                 ? 'Already Stopped'
//                                                 : 'Stop New Ride Requests',
//                                           ),
//                                         );
//                                       }),
//                                       const SizedBox(height: 10),
//                                       Buttons.button(
//                                         borderRadius: 8,
//                                         buttonColor: AppColors.red,
//                                         onTap: () {
//                                           Buttons.showCancelRideBottomSheet(
//                                             context,
//                                             onConfirmCancel: (reason) async {
//                                               await driverStatusController
//                                                   .cancelBooking(
//                                                     bookingId: widget.bookingId,
//                                                     context,
//                                                     reason: reason,
//                                                   );
//                                             },
//                                           );
//                                         },
//                                         text: const Text(
//                                           'Cancel this Shared Ride',
//                                         ),
//                                       ),
//                                       const SizedBox(height: 20),
//                                     ],
//                                   ),
//                                 ),
//                             ],
//                           );
//                         }),
//                       );
//                     },
//                   ),
//                 ],
//               ),
//             ),
//           ),
//           const BookingOverlayRequest(),
//         ],
//       ),
//     );
//   }
// }
