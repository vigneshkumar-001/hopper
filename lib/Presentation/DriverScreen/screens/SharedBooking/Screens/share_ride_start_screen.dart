import 'dart:async';
import 'dart:ui' as ui;

import 'package:action_slider/action_slider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:hopper/Core/Constants/Colors.dart';
import 'package:hopper/Core/Utility/Buttons.dart';
import 'package:hopper/Core/Utility/images.dart';
import 'package:hopper/Presentation/Authentication/widgets/textFields.dart';
import 'package:hopper/Presentation/DriverScreen/controller/driver_status_controller.dart';
import 'package:hopper/Presentation/DriverScreen/screens/SharedBooking/Controller/shared_controller.dart';
import 'package:hopper/Presentation/DriverScreen/screens/SharedBooking/Controller/shared_ride_controller.dart';
import 'package:hopper/Presentation/DriverScreen/screens/SharedBooking/Screens/booking_overlay_request.dart';
import 'package:hopper/Presentation/DriverScreen/screens/cash_collected_screen.dart';
import 'package:hopper/Presentation/DriverScreen/screens/driver_main_screen.dart';
import 'package:hopper/Presentation/DriverScreen/screens/verify_rider_screen.dart';
import 'package:hopper/utils/map/driver_route.dart';
import 'package:hopper/utils/map/shared_map.dart';
import 'package:hopper/utils/netWorkHandling/network_handling_screen.dart';
import 'package:hopper/Core/Constants/log.dart';
import '../../../../../utils/websocket/socket_io_client.dart';

class ShareRideStartScreen extends StatefulWidget {
  final String bookingId; // pool / main booking
  final LatLng pickupLocation;
  final LatLng driverLocation;

  const ShareRideStartScreen({
    Key? key,
    required this.pickupLocation,
    required this.driverLocation,
    required this.bookingId,
  }) : super(key: key);

  @override
  State<ShareRideStartScreen> createState() => _ShareRideStartScreenState();
}

class _ShareRideStartScreenState extends State<ShareRideStartScreen>
    with SingleTickerProviderStateMixin {
  late final ActionSliderController _sliderController;
  late final DriverRouteController _routeController;

  // GetX controllers (singletons)
  final SharedController sharedController = Get.put(SharedController());
  final DriverStatusController driverStatusController = Get.put(
    DriverStatusController(),
  );
  final SharedRideController sharedRideController =
      Get.find<SharedRideController>();

  final GlobalKey<SharedMapState> _mapKey = GlobalKey<SharedMapState>();

  LatLng? driverLocation;
  double carBearing = 0.0;
  List<LatLng> polylinePoints = [];
  String directionText = '';
  String distance = '';
  String maneuver = '';

  BitmapDescriptor? carIcon;
  late SocketService socketService;

  bool driverCompletedRide = false;
  bool _isDriverFocused = false;

  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  // simple throttle for route updates
  DateTime? _lastRouteUpdate;

  // 🔽 expanded card bookingIds
  final Set<String> _expandedCards = <String>{};

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

    _initSocket();
    _loadMarkerIcons();

    // Decide initial destination based on active target
    final initialTarget = sharedRideController.activeTarget.value;
    final initialDestination =
        initialTarget == null
            ? widget.pickupLocation
            : (initialTarget.stage == SharedRiderStage.waitingPickup
                ? initialTarget.pickupLatLng
                : initialTarget.dropLatLng);

    _routeController = DriverRouteController(
      destination: initialDestination,
      onRouteUpdate: (update) {
        // Throttle UI updates to avoid jank
        final now = DateTime.now();
        if (_lastRouteUpdate != null) {
          final diff = now.difference(_lastRouteUpdate!).inMilliseconds;
          if (diff < 300) return; // skip if too frequent
        }
        _lastRouteUpdate = now;

        if (!mounted) return;
        setState(() {
          driverLocation = update.driverLocation;
          carBearing = update.bearing;
          polylinePoints = update.polylinePoints;
          directionText = update.directionText;
          distance = update.distanceText;
          maneuver = update.maneuver;
        });

        sharedRideController.updateDriverLocation(update.driverLocation);
      },
      onCameraUpdate: (_) {},
    );

    _routeController.start();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _pulseAnimation = Tween<double>(begin: 0, end: 60).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOut),
    )..addListener(() {
      if (!mounted) return;
      if (_isDriverFocused) setState(() {});
    });
  }

  @override
  void dispose() {
    _routeController.dispose();
    _pulseController.dispose();
    _sliderController.dispose();

    try {
      socketService.socket.off('driver-reached-destination');
      socketService.socket.off('driver-location');
      socketService.socket.off('driver-cancelled');
      socketService.socket.off('customer-cancelled');
    } catch (_) {}

    super.dispose();
  }

  Future<void> _initSocket() async {
    socketService = SocketService();

    // 1) Driver reached destination
    socketService.on('driver-reached-destination', (data) {
      final status = data?['status'];
      if (status == true || status?.toString() == 'true') {
        if (!mounted) return;
        setState(() => driverCompletedRide = true);
        CommonLogger.log.i('✅ Driver reached destination');
      }
    });

    // ❌ NO driver-location here anymore – controller handles it

    // 3) Cancel events
    socketService.on('driver-cancelled', (data) {
      if (data?['status'] == true) {
        Get.offAll(() => const DriverMainScreen());
      }
    });

    socketService.on('customer-cancelled', (data) {
      if (data?['status'] == true) {
        Get.offAll(() => const DriverMainScreen());
      }
    });

    // 4) Connect if needed
    if (!socketService.connected) {
      socketService.connect();
      socketService.onConnect(
        () => CommonLogger.log.i('🔌 [SHARED START] socket connected'),
      );
    } else {
      CommonLogger.log.i(
        '💡 [SHARED START] already connected → listeners attached',
      );
    }
  }

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
      setState(() {
        carIcon = icon;
      });
    } catch (_) {
      carIcon = BitmapDescriptor.defaultMarker;
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
    final km = meters / 1000.0;
    if (meters <= 0) return '0 Km';
    return '${km.toStringAsFixed(1)} Km';
  }

  String _formatDuration(double minutes) {
    if (minutes <= 0) return '0 min';
    final total = minutes.round();
    final h = total ~/ 60;
    final m = total % 60;
    return h > 0 ? '$h hr $m min' : '$m min';
  }

  // ──────────────── NEXT STOP LOGIC ────────────────

  Future<void> _setAsNextStop(SharedRiderItem r) async {
    final stage = r.stage;

    sharedRideController.setActiveTarget(r.bookingId, stage);

    final dest =
        stage == SharedRiderStage.waitingPickup ? r.pickupLatLng : r.dropLatLng;

    // ✅ reset ETA used in UI
    sharedController.pickupDistanceInMeters.value = 0;
    sharedController.pickupDurationInMin.value = 0;
    sharedController.dropDistanceInMeters.value = 0;
    sharedController.dropDurationInMin.value = 0;

    await _routeController.updateDestination(dest);
    _mapKey.currentState?.focusPickup();
    setState(() {});
  }

  // Pass the completed rider so we know who to collect cash for
  Future<void> _onCurrentLegCompleted(SharedRiderItem completedRider) async {
    // 1) Go to cash collection screen for this rider
    final cashCollected = await Get.to<bool>(
      () => CashCollectedScreen(
        bookingId: completedRider.bookingId,
        Amount: completedRider.amount,
        isSharedRide: true, // 👈 IMPORTANT
      ),
    );

    // If driver backed without collecting cash, stay on this screen
    if (cashCollected != true) {
      return;
    }

    // 2) Mark dropped internally
    sharedRideController.markDropped(completedRider.bookingId);

    // 3) Check if there is a next rider
    final next = sharedRideController.recomputeNextTarget();
    if (next == null) {
      // ✅ No more riders = shared trip finished → go to main screen
      Get.offAll(() => const DriverMainScreen());
      return;
    }

    // 4) There is another rider → update destination and continue
    final dest =
        next.stage == SharedRiderStage.waitingPickup
            ? next.pickupLatLng
            : next.dropLatLng;

    await _routeController.updateDestination(dest);

    if (mounted) {
      setState(() {
        // activeTarget already updated inside recomputeNextTarget()
        // if you need to do any extra local state, do here
      });
    }
  }

  Widget _buildEtaRow(SharedRiderItem active) {
    final isPickupLeg = active.stage == SharedRiderStage.waitingPickup;

    return Obx(() {
      final minutes =
          isPickupLeg
              ? sharedController.pickupDurationInMin.value
              : sharedController.dropDurationInMin.value;

      final meters =
          isPickupLeg
              ? sharedController.pickupDistanceInMeters.value
              : sharedController.dropDistanceInMeters.value;

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

  /*
  Widget _buildEtaRow(SharedRiderItem active) {
    final isPickupLeg = active.stage == SharedRiderStage.waitingPickup;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Obx(() {
          final minutes = isPickupLeg
              ? driverStatusController.pickupDurationInMin.value
              : driverStatusController.dropDurationInMin.value;

          return CustomTextfield.textWithStyles600(
            _formatDuration(minutes),
            fontSize: 18,
          );
        }),
        const SizedBox(width: 8),
        Icon(Icons.circle, color: AppColors.drkGreen, size: 10),
        const SizedBox(width: 8),
        Obx(() {
          final meters = isPickupLeg
              ? driverStatusController.pickupDistanceInMeters.value
              : driverStatusController.dropDistanceInMeters.value;

          return CustomTextfield.textWithStyles600(
            _formatDistance(meters),
            fontSize: 18,
          );
        }),
      ],
    );
  }
*/

  // ───────── ACTIVE SECTION – ARRIVED / OTP / COMPLETE ─────────

  Widget _buildActiveActionArea(SharedRiderItem active) {
    // WAITING PICKUP, NOT ARRIVED YET → show ARRIVED
    if (active.stage == SharedRiderStage.waitingPickup && !active.arrived) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Buttons.button(
          buttonColor: AppColors.resendBlue,
          borderRadius: 8,
          onTap: () async {
            final result = await driverStatusController.driverArrived(
              context,
              bookingId: active.bookingId,
            );

            if (result != null && result.status == 200) {
              sharedRideController.markArrived(active.bookingId);
              if (mounted) setState(() {});
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(result?.message ?? "Something went wrong"),
                ),
              );
            }
          },
          text: Text('Arrived at pickup for ${active.name}'),
        ),
      );
    }

    // WAITING PICKUP, ARRIVED → show SWIPE TO START (OTP)
    // WAITING PICKUP, ARRIVED → show SWIPE TO START (OTP)
    if (active.stage == SharedRiderStage.waitingPickup && active.arrived) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: ActionSlider.standard(
          controller: ActionSliderController(),
          height: 50,
          backgroundColor: AppColors.drkGreen,
          toggleColor: Colors.white,
          icon: Icon(Icons.double_arrow, color: AppColors.drkGreen, size: 28),
          child: Text(
            'Swipe to Start Ride for ${active.name}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          action: (controller) async {
            controller.loading();

            // 1️⃣ Send OTP
            final msg = await driverStatusController.otpRequest(
              context,
              bookingId: active.bookingId,
              custName: active.name,
              pickupAddress: active.pickupAddress,
              dropAddress: active.dropoffAddress,
            );

            if (msg == null) {
              controller.failure();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Failed to send OTP')),
              );
              return;
            }

            // 2️⃣ Verify OTP – shared flow
            final verified = await Navigator.push<bool>(
              context,
              MaterialPageRoute(
                builder:
                    (_) => VerifyRiderScreen(
                      bookingId: active.bookingId,
                      custName: active.name,
                      pickupAddress: active.pickupAddress,
                      dropAddress: active.dropoffAddress,
                      isSharedRide: true, // stays in this screen
                    ),
              ),
            );

            if (verified == true) {
              controller.success();

              // 3️⃣ Rider onboard → stage = onboardDrop
              sharedRideController.markOnboard(active.bookingId);

              // 4️⃣ Properly set this rider as current leg (drop),
              // reset ETAs, update route, refresh UI
              await _setAsNextStop(active);
            } else {
              controller.reset();
            }
          },
        ),
      );
    }

    // ONBOARD → COMPLETE CURRENT STOP (DROP)
    if (active.stage == SharedRiderStage.onboardDrop) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: ActionSlider.standard(
          controller: _sliderController,
          height: 50,
          backgroundColor: AppColors.drkGreen,
          toggleColor: Colors.white,
          icon: Icon(Icons.double_arrow, color: AppColors.drkGreen, size: 28),
          child: const Text(
            'Complete Current Stop',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          action: (controller) async {
            controller.loading();
            await Future.delayed(const Duration(milliseconds: 300));

            final msg = await driverStatusController.completeRideRequest(
              context,
              Amount: active.amount,
              bookingId: active.bookingId,
            );

            if (msg != null) {
              controller.success();

              // ✅ After backend marks ride complete,
              // go to cash collected screen & then decide next step
              await _onCurrentLegCompleted(active);
            } else {
              controller.failure();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Failed to complete stop')),
              );
            }
          },
        ),
      );
    }

    // DROPPED: no actions
    return const SizedBox.shrink();
  }

  // ──────────────── RIDER LIST ROWS (EXPANDABLE) ────────────────

  Widget _buildRiderRow(SharedRiderItem r) {
    final active = sharedRideController.activeTarget.value;
    final isActive = active?.bookingId == r.bookingId;
    final isDropped = r.stage == SharedRiderStage.dropped;

    final isExpanded = _expandedCards.contains(r.bookingId);

    String stageLabel;
    switch (r.stage) {
      case SharedRiderStage.waitingPickup:
        stageLabel = 'Pending pickup';
        break;
      case SharedRiderStage.onboardDrop:
        stageLabel = 'In car – drop pending';
        break;
      case SharedRiderStage.dropped:
        stageLabel = 'Dropped';
        break;
    }

    void toggleExpanded() {
      setState(() {
        if (isExpanded) {
          _expandedCards.remove(r.bookingId);
        } else {
          _expandedCards.add(r.bookingId);
        }
      });
    }

    return Opacity(
      opacity: isDropped ? 0.4 : 1,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color:
              isActive
                  ? AppColors.containerColor1.withOpacity(0.1)
                  : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color:
                isActive ? AppColors.resendBlue : Colors.grey.withOpacity(0.3),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar
            ClipOval(
              child: CachedNetworkImage(
                imageUrl: r.profilePic,
                height: 40,
                width: 40,
                fit: BoxFit.cover,
                placeholder:
                    (c, u) => const SizedBox(
                      height: 30,
                      width: 30,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                errorWidget: (c, u, e) => const Icon(Icons.person, size: 30),
              ),
            ),
            const SizedBox(width: 10),

            // Text + expand area
            Expanded(
              child: InkWell(
                onTap: toggleExpanded,
                borderRadius: BorderRadius.circular(6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name + bookingId + arrow
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: CustomTextfield.textWithStyles600(
                            r.name,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '#${r.bookingId}',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.textColorGrey,
                          ),
                        ),
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: toggleExpanded,
                          child: AnimatedRotation(
                            turns: isExpanded ? 0.5 : 0.0, // 180°
                            duration: const Duration(milliseconds: 200),
                            child: Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: 20,
                              color: AppColors.textColorGrey,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    CustomTextfield.textWithStylesSmall(
                      stageLabel,
                      colors: AppColors.textColorGrey,
                      fontSize: 12,
                    ),
                    const SizedBox(height: 4),

                    // 🔽 Animated expand/collapse of Pickup & Drop
                    AnimatedCrossFade(
                      duration: const Duration(milliseconds: 220),
                      crossFadeState:
                          isExpanded
                              ? CrossFadeState.showSecond
                              : CrossFadeState.showFirst,
                      // 👇 collapsed: nothing shown
                      firstChild: const SizedBox.shrink(),
                      // 👇 expanded: show pickup & drop (multi-line)
                      secondChild: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CustomTextfield.textWithStylesSmall(
                            'Pickup: ${r.pickupAddress}',
                            colors: AppColors.textColorGrey,
                            maxLine: 3,
                            fontSize: 11,
                          ),
                          const SizedBox(height: 2),
                          CustomTextfield.textWithStylesSmall(
                            'Drop: ${r.dropoffAddress}',
                            colors: AppColors.textColorGrey,
                            maxLine: 3,
                            fontSize: 11,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(width: 8),

            // Action button
            if (!isDropped)
              TextButton(
                onPressed: () => _setAsNextStop(r),
                child: Text(
                  isActive ? 'Current' : 'Set as Next',
                  style: TextStyle(
                    fontSize: 12,
                    color: isActive ? AppColors.drkGreen : AppColors.resendBlue,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ────────────────────── UI ──────────────────────

  @override
  Widget build(BuildContext context) {
    final active = sharedRideController.activeTarget.value;
    final markers = <Marker>{
      Marker(
        markerId: const MarkerId('driver'),
        position: driverLocation ?? widget.driverLocation,
        icon: carIcon ?? BitmapDescriptor.defaultMarker,
        rotation: carBearing,
        anchor: const Offset(0.5, 0.5),
        flat: true,
      ),
      if (active != null)
        Marker(
          markerId: const MarkerId('target'),
          position:
              active.stage == SharedRiderStage.waitingPickup
                  ? active.pickupLatLng
                  : active.dropLatLng,
          infoWindow: InfoWindow(
            title:
                active.stage == SharedRiderStage.waitingPickup
                    ? 'Pickup ${active.name}'
                    : 'Drop ${active.name}',
          ),
        ),
    };

    return NoInternetOverlay(
      child: WillPopScope(
        onWillPop: () async => false,
        child: Scaffold(
          body: Stack(
            children: [
              // MAP
              SizedBox(
                height: 550,
                width: double.infinity,
                child: SharedMap(
                  key: _mapKey,
                  initialPosition: widget.pickupLocation,
                  pickupPosition: driverLocation ?? widget.driverLocation,
                  markers: markers,
                  polylines: {
                    if (polylinePoints.length >= 2)
                      Polyline(
                        polylineId: const PolylineId("route"),
                        color: AppColors.commonBlack,
                        width: 5,
                        points: polylinePoints,
                      ),
                  },
                  myLocationEnabled: true,
                  fitToBounds: true,
                ),
              ),

              // Map focus button
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
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 8,
                            offset: Offset(0, 3),
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

              // Top direction card
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
                                directionText,
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
                initialChildSize: 0.70,
                minChildSize: 0.40,
                maxChildSize: 0.85,
                builder: (context, scrollController) {
                  return Container(
                    color: Colors.white,
                    child: Obx(() {
                      final active = sharedRideController.activeTarget.value;

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
                          const SizedBox(height: 20),

                          if (!driverCompletedRide && active != null) ...[
                            // Active rider summary
                            Container(
                              color: AppColors.rideInProgress.withOpacity(0.1),
                              padding: const EdgeInsets.all(15),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CustomTextfield.textWithStyles600(
                                    active.stage ==
                                            SharedRiderStage.waitingPickup
                                        ? 'Heading to pick up ${active.name}'
                                        : 'Ride in Progress – Dropping ${active.name}',
                                    color: AppColors.rideInProgress,
                                    fontSize: 14,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Booking ID: #${active.bookingId}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textColorGrey,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Pickup: ${active.pickupAddress}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.commonBlack,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Drop: ${active.dropoffAddress}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.commonBlack,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

                            // ETA row
                            _buildEtaRow(active),
                            const SizedBox(height: 10),

                            // Actions
                            _buildActiveActionArea(active),
                            const SizedBox(height: 10),
                          ],

                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              'Next Stops',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),

                          if (sharedRideController.riders.isEmpty)
                            const Padding(
                              padding: EdgeInsets.all(20),
                              child: Text('No riders in this shared trip'),
                            )
                          else
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: Column(
                                children:
                                    sharedRideController.riders
                                        .map(_buildRiderRow)
                                        .toList(),
                              ),
                            ),

                          const SizedBox(height: 20),

                          // Stop new + Cancel shared
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
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
                                    borderRadius: 8,
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
                                  borderRadius: 8,
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
                                  text: const Text('Cancel this Shared Ride'),
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
              const BookingOverlayRequest(),
            ],
          ),
        ),
      ),
    );
  }
}


