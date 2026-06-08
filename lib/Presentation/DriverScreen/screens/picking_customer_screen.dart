// lib/Presentation/DriverScreen/screens/picking_customer_screen.dart
// âœ… Update: Top row = Call (left) + Duration (center) + Chat (right)
// âœ… Under that = Customer profile + name (tap name -> enable Arrived button for testing)

import 'dart:async';

import 'package:action_slider/action_slider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:hopper/utils/phone/call_launcher.dart';

import 'package:hopper/Core/Constants/Colors.dart';
import 'package:hopper/Core/Services/driver_background_location_service.dart';
import 'package:hopper/Core/Services/navigation_service.dart';
import 'package:hopper/Core/Utility/Buttons.dart';
import 'package:hopper/Core/Utility/images.dart';
import 'package:hopper/Presentation/Authentication/widgets/textFields.dart';
import 'package:hopper/Presentation/DriverScreen/screens/chat_screen.dart';
import 'package:hopper/Presentation/DriverScreen/controller/driver_main_controller.dart';
import 'package:hopper/api/repository/api_config_controller.dart';
import 'package:hopper/utils/map/map_control_button.dart';
import 'package:hopper/utils/netWorkHandling/network_handling_screen.dart';
import 'package:hopper/utils/map/driver_message_suggestions.dart';
import 'package:hopper/utils/sharedprefsHelper/sharedprefs_handler.dart';
import 'package:hopper/utils/widgets/hoppr_swipe_slider.dart';
import 'package:hopper/utils/widgets/hoppr_circular_loader.dart';
import 'package:hopper/utils/ride_map/ride_map_view.dart';
import 'package:hopper/utils/ride_map/ride_map_controller.dart';

import '../controller/driver_status_controller.dart';
import '../controller/pickup_customer_controller.dart';

class PickingCustomerScreen extends StatefulWidget {
  final LatLng pickupLocation;
  final String? pickupLocationAddress;
  final String? dropLocationAddress;
  final LatLng driverLocation;
  final String bookingId;

  const PickingCustomerScreen({
    super.key,
    required this.pickupLocation,
    required this.driverLocation,
    required this.bookingId,
    this.pickupLocationAddress,
    this.dropLocationAddress,
  });

  @override
  State<PickingCustomerScreen> createState() => _PickingCustomerScreenState();
}

class _PickingCustomerScreenState extends State<PickingCustomerScreen>
    with WidgetsBindingObserver {
  late final PickingCustomerController c;
  late final ActionSliderController sliderController;
  final NavigationService _navigationService = NavigationService();
  StreamSubscription<dynamic>? _bgLocationSub;
  bool _backgroundServiceActive = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    sliderController = ActionSliderController();

    // IMPORTANT: Don't create GetX controllers during `build()`.
    // Creating it in `initState()` prevents "markNeedsBuild during build"
    // errors when the controller updates Rx values in `onInit()`.
    c = Get.put(
      PickingCustomerController(
        pickupLocation: widget.pickupLocation,
        driverLocation: widget.driverLocation,
        bookingId: widget.bookingId,
        pickupLocationAddress: widget.pickupLocationAddress,
        dropLocationAddress: widget.dropLocationAddress,
      ),
      tag: widget.bookingId,
    );

    _setupBackgroundServiceListener();

    // Kick route fetch after the first frame so we never mutate Rx during build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      c.ensureRouteReady();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _bgLocationSub?.cancel();
    sliderController.dispose();
    // Allow GetX to clean up controller when this screen is removed.
    if (Get.isRegistered<PickingCustomerController>(tag: widget.bookingId)) {
      Get.delete<PickingCustomerController>(tag: widget.bookingId, force: true);
    }
    super.dispose();
  }

  void _setupBackgroundServiceListener() {
    _bgLocationSub?.cancel();
    try {
      final service = FlutterBackgroundService();
      _bgLocationSub = service.on('locationUpdate').listen((data) {
        if (!mounted || data == null) return;
        if (data is! Map) return;

        final lat = (data['lat'] as num?)?.toDouble();
        final lng = (data['lng'] as num?)?.toDouble();
        if (lat == null || lng == null) return;

        final bearing = (data['bearing'] as num?)?.toDouble();
        final speed = (data['speed'] as num?)?.toDouble();
        final acc = (data['accuracy'] as num?)?.toDouble();
        final tsRaw = data['timestamp']?.toString();
        final ts = tsRaw == null ? null : DateTime.tryParse(tsRaw);

        c.rideMap.updateVehicleLocation(
          LatLng(lat, lng),
          source: 'gps',
          speedMetersPerSecond: speed,
          headingDeg: bearing,
          accuracyMeters: acc,
          timestamp: ts,
        );
      });
    } catch (_) {
      // Ignore: listener is best-effort.
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _backgroundServiceActive = false;
      // Reclaim ownership from background service to prevent duplicate socket emits.
      if (Get.isRegistered<DriverMainController>()) {
        unawaited(Get.find<DriverMainController>().onAppResumed());
      }
      // Refresh map immediately after coming back from external navigation.
      c.goToCurrentLocation();
    }
  }

  Future<void> _onNavigatePressed() async {
    final ok = await _navigationService.requestPermissions(); 
    if (!ok) {
      Get.snackbar(
        'Permission Required',
        'Please allow background location for tracking',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    final driverId = (await SharedPrefHelper.getDriverId())?.trim() ?? '';
    if (driverId.isEmpty) {
      Get.snackbar(
        'Error',
        'Driver ID missing. Please re-login.',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    final socketUrl =
        Get.isRegistered<ApiConfigController>()
            ? Get.find<ApiConfigController>().socketUrl
            : ApiConfigController.singleSocket;

    await _navigationService.markExternalNavigationReturnPending(
      source: 'single_pickup_google_maps',
    );

    // Hand-off before launching external Google Maps (single socket session).
    if (Get.isRegistered<DriverMainController>()) {
      await Get.find<DriverMainController>().onAppPaused();
    }

    await DriverBackgroundLocationService.startTracking(
      socketUrl: socketUrl,
      rideId: widget.bookingId,
      driverId: driverId,
    );
    _backgroundServiceActive = true;

    _showNavigationTrackingMessage('pickup');

    await _navigationService.openGoogleMapsNavigation(
      destLat: widget.pickupLocation.latitude,
      destLng: widget.pickupLocation.longitude,
      destinationLabel: 'Pickup Location',
    );
  }

  void _showNavigationTrackingMessage(String destinationName) {
    Get.closeCurrentSnackbar();
    Get.snackbar(
      'Navigation Started',
      'Navigating to $destinationName. Please keep location access on so your live position keeps updating in background for the customer.',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: const Color(0xFF111827),
      colorText: Colors.white,
      duration: const Duration(seconds: 5),
      margin: const EdgeInsets.all(16),
      borderRadius: 12,
      icon: const Icon(Icons.my_location_rounded, color: Colors.white),
    );
  }

  @override
  Widget build(BuildContext context) {
    final DriverStatusController driverStatusController =
        Get.find<DriverStatusController>();

    return NoInternetOverlay(
      child: WillPopScope(
        onWillPop: () async => false,
        child: Scaffold(
          body: Obx(() {
            final pickupTarget =
                c.adjustedPickupLocation.value ?? widget.pickupLocation;

            // NOTE: No side-effects in build. All map updates are driven by the
            // controller (workers) to avoid build-phase exceptions.
            return Stack(
              children: [
                DecoratedBox(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x18000000),
                        blurRadius: 18,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: SizedBox(
                    height: 650,
                    child: Stack(
                      children: [
                        RideMapView(
                          controller: c.rideMap,
                          initialPosition: pickupTarget,
                          myLocationEnabled: false,
                           fitToBounds: false,
                           trafficEnabled: false,
                           compassEnabled: false,
                           onUserCameraMoveStarted: () {
                             c.isDriverFocused.value = false;
                             c.rideMap.setAutoFollowEnabled(false);
                             c.rideMap.focusMode.value = MapFocusMode.fullTrip;
                           },
                           onMapCreated: (gm) => c.onMapCreated(gm, context),
                         ),
                        Positioned(
                          top: 56,
                          left: 12,
                          child: Obx(() {
                            final meters = c.pickupAdjustMeters.value;
                            if (meters <= 20) return const SizedBox.shrink();
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.82),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                'Recommended pickup point - ${meters}m',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            );
                          }),
                        ),
                        IgnorePointer(
                          child: Container(
                            height: 190,
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Color(0x26000000), Color(0x00000000)],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Map controls
                Positioned(
                  top: c.arrivedAtPickup.value ? 322 : 472,
                    right: 12,
                    child: Column(
                      children: [
                      NavigateToDestinationButton(
                        onTap: _onNavigatePressed,
                        label: 'To Pickup',
                      ),
                      const SizedBox(height: 10),
                      ValueListenableBuilder<MapFocusMode>(
                        valueListenable: c.rideMap.focusMode,
                        builder: (context, mode, _) {
                          final focused = mode == MapFocusMode.driver;
                          return MapFocusToggleButton(
                            isDriverFocused: focused,
                            onFocusDriver: () async {
                              // Always focus driver on first tap.
                              c.rideMap.applyFocusMode(
                                MapFocusMode.driver,
                                userInitiated: true,
                              );
                              c.isDriverFocused.value = true;
                            },
                            onFitBounds: () async {
                              // Always fit full leg/route on second tap.
                              c.rideMap.applyFocusMode(
                                MapFocusMode.fullTrip,
                                userInitiated: true,
                              );
                              c.isDriverFocused.value = false;
                            },
                            onDriverFocusedChanged: (v) => c.isDriverFocused.value = v,
                          );
                        },
                      ),
                    ],
                  ),
                ),

                // (Removed) Direction header as requested.
                if (c.isNetworkOffline.value || c.pendingQueueCount.value > 0)
                  Positioned(
                    top: 145,
                    left: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1F2937),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        c.isNetworkOffline.value
                            ? 'No internet. Route cache active, syncing when online.'
                            : 'Sync pending: ${c.pendingQueueCount.value} message(s)',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                if (c.isOffRouteAlert.value)
                  Positioned(
                    top: 198,
                    left: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.amber.shade700),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, size: 18),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Route deviation detected',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: c.fitBoundsToDriverAndPickup,
                            child: const Text('Recenter'),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Bottom sheet + timer badge
                Stack(
                  children: [
                    DraggableScrollableSheet(
                      key: ValueKey(c.arrivedAtPickup.value),
                      initialChildSize: c.arrivedAtPickup.value ? 0.50 : 0.30,
                      minChildSize: c.arrivedAtPickup.value ? 0.40 : 0.30,
                      maxChildSize: c.arrivedAtPickup.value ? 0.65 : 0.30,
                      builder: (context, scrollController) {
                        return Container(
                          decoration: const BoxDecoration(color: Colors.white),
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
                              const SizedBox(height: 10),

                              // âœ… TOP ROW: Call (left) + Duration (center) + Chat (right)
                              // âœ… SUBTITLE: Customer name (below duration)
                              if (c.arrivedAtPickup.value) ...[
                                _topActionRow(
                                  c: c,
                                  context: context,
                                  bookingId: widget.bookingId,
                                  driverStatusController:
                                      driverStatusController,
                                ),
                                const SizedBox(height: 10),

                                // Second row: customer photo + name (manual tap only in test mode)
                                _customerRow(
                                  c,
                                  onTapName:
                                      PickingCustomerController
                                              .enableArrivedTesting
                                          ? c.debugSetDriverReachedTrue
                                          : null,
                                ),
                                const SizedBox(height: 10),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  child: Obx(() {
                                    final eta =
                                        driverStatusController
                                            .pickupDurationInMin
                                            .value
                                            .round();
                                    final chips =
                                        DriverMessageSuggestions.pickup(
                                          reachedPickup: c.driverReached.value,
                                          etaMinutes: eta,
                                        );
                                    return SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: Row(
                                        children:
                                            chips
                                                .map(
                                                  (msg) => Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                          right: 8,
                                                        ),
                                                     child: InkWell(
                                                      onTap: () async {
                                                        final sent = await c
                                                            .sendQuickMessage(
                                                              msg,
                                                              delayMinutes: eta,
                                                            );
                                                        if (!mounted) return;
                                                        final messenger =
                                                            ScaffoldMessenger.of(
                                                              context,
                                                            );
                                                        messenger.clearSnackBars();
                                                        messenger.showSnackBar(
                                                          SnackBar(
                                                            content: Text(
                                                              sent
                                                                  ? 'Message sent'
                                                                  : 'Message queued',
                                                            ),
                                                            duration:
                                                                const Duration(
                                                              milliseconds:
                                                                  1200,
                                                            ),
                                                          ),
                                                        );
                                                      },
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            18,
                                                          ),
                                                      child: Container(
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 12,
                                                              vertical: 8,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          color: AppColors
                                                              .commonBlack
                                                              .withOpacity(
                                                                0.04,
                                                              ),
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                18,
                                                              ),
                                                          border: Border.all(
                                                            color: AppColors
                                                                .commonBlack
                                                                .withOpacity(
                                                                  0.08,
                                                                ),
                                                          ),
                                                        ),
                                                        child: Text(
                                                          msg,
                                                          style:
                                                              const TextStyle(
                                                                fontSize: 12,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                              ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                )
                                                .toList(),
                                      ),
                                    );
                                  }),
                                ),
                                const SizedBox(height: 10),
                              ],

                              // ===== BEFORE ARRIVED (picking up) =====
                              if (c.arrivedAtPickup.value) ...[
                                if (c.driverReached.value) ...[
                                  if (c.driverReached.value) ...[
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 20,
                                      ),
                                      child: Obx(
                                        () => Buttons.button(
                                          buttonColor: AppColors.resendBlue,
                                          borderRadius: 8,
                                          onTap:
                                              c.isArrivedSubmitting.value
                                                  ? null
                                                  : () => c
                                                      .onArrivedAtPickupPressed(
                                                        context,
                                                      ),
                                          text: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              if (c
                                                  .isArrivedSubmitting
                                                  .value) ...[
                                                const HopprCircularLoader(
                                                  radius: 8,
                                                  size: 16,
                                                  color: Colors.white,
                                                ),
                                                const SizedBox(width: 10),
                                              ],
                                              const Text(
                                                'Arrived at Pickup Point',
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                  ],
                                ],

                                const SizedBox(height: 12),

                                _rideDetailsBlock(
                                  pickupAddress:
                                      widget.pickupLocationAddress ??
                                      c.pickupAddressText.value,
                                  dropAddress:
                                      widget.dropLocationAddress ??
                                      c.dropAddressText.value,
                                ),

                                const SizedBox(height: 10),

                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                  ),
                                  child: Column(
                                    children: [
                                      Buttons.button(
                                        borderColor: AppColors.buttonBorder,
                                        buttonColor: AppColors.commonWhite,
                                        borderRadius: 8,
                                        textColor: AppColors.commonBlack,
                                        onTap:
                                            () => Buttons.showDialogBox(
                                              context: context,
                                              onConfirmStop: () async {},
                                            ),
                                        text: const Text(
                                          'Stop New Ride Request',
                                        ),
                                      ),
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
                                        text: const Text('Cancel this Ride'),
                                      ),
                                    ],
                                  ),
                                ),
                              ]
                              // ===== AFTER ARRIVED (wait rider + swipe) =====
                              else ...[
                                if (c.showRedTimer.value)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                    ),
                                    child: Container(
                                      color: AppColors.red.withOpacity(0.1),
                                      child: ListTile(
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
                                          'Tap to cancel the ride, If rider donâ€™t show up',
                                          fontSize: 14,
                                          color: AppColors.red,
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
                                              (_) => ChatScreen(
                                                bookingId: widget.bookingId,
                                                initialPhone:
                                                    c.customerPhone.value,
                                              ),
                                        ),
                                      );
                                    },
                                    child: _roundIconBox(AppImages.msg),
                                  ),
                                  leading: GestureDetector(
                                     onTap: () async {
                                       await CallLauncher.openDialer(
                                         phone: c.customerPhone.value,
                                         context: context,
                                       );
                                     },
                                     child: _roundIconBox(AppImages.call),
                                    ),
                                  title: Center(
                                    child: CustomTextfield.textWithStyles600(
                                      'Waiting for the Rider',
                                      fontSize: 20,
                                    ),
                                  ),
                                  subtitle: Center(
                                    child: Obx(
                                      () => CustomTextfield.textWithStylesSmall(
                                        c.customerName.value.trim().isEmpty
                                            ? 'Rider'
                                            : c.customerName.value,
                                        fontSize: 14,
                                        colors: AppColors.textColorGrey,
                                      ),
                                    ),
                                  ),
                                ),

                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 10,
                                  ),
                                  child: HopprSwipeSlider(
                                    controller: sliderController,
                                    height: 50,
                                    backgroundColor: const Color(0xFF1C1C1C),
                                    handleColor: Colors.white,
                                    handleIconColor: Colors.black,
                                    text: 'Swipe to Start Ride',
                                    onAction: (slider) async {
                                      slider.loading();
                                      await c.onSwipeStartRide(context);
                                      slider.success();
                                      await Future<void>.delayed(
                                        const Duration(milliseconds: 250),
                                      );
                                      slider.reset();
                                    },
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),

                    // Timer badge
                    if (!c.arrivedAtPickup.value && c.secondsLeft.value > 0)
                      Positioned(
                        bottom: c.showRedTimer.value ? 285 : 240,
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
                                    c.showRedTimer.value
                                        ? AppColors.timerBorderColor
                                        : AppColors.commonBlack.withOpacity(
                                          0.2,
                                        ),
                                width: 6,
                              ),
                            ),
                            child: Text(
                              c.formatTimer(c.secondsLeft.value),
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                                color:
                                    c.showRedTimer.value
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
            );
          }),
        ),
      ),
    );
  }

  // ---------------- UI BLOCKS ----------------

  static String _routeDistanceText(
    DriverStatusController driverStatusController,
    String distanceText,
  ) {
    if (distanceText.trim().isNotEmpty) return distanceText;
    final meters = driverStatusController.pickupDistanceInMeters.value;
    if (meters <= 0) return '--';
    if (meters < 1) return '<1 m';
    if (meters >= 1000) return '${(meters / 1000).toStringAsFixed(1)} km';
    return '${meters.round()} m';
  }

  static Widget _topActionRow({
    required PickingCustomerController c,
    required BuildContext context,
    required String bookingId,
    required DriverStatusController driverStatusController,
  }) {
    return ListTile(
      // Left: Call
      leading: GestureDetector(
        onTap: () async {
          await CallLauncher.openDialer(
            phone: c.customerPhone.value,
            context: context,
          );
        },
        child: _roundIconBox(AppImages.call),
      ),

      // Right: Chat
      trailing: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (_) => ChatScreen(
                    bookingId: bookingId,
                    initialPhone: c.customerPhone.value,
                  ),
            ),
          );
        },
        child: _roundIconBox(AppImages.msg),
      ),

      // Center: Duration + Customer name below
      title: Center(
        child: Obx(
          () => CustomTextfield.textWithStyles600(
            _formatDuration(driverStatusController.pickupDurationInMin.value),
            fontSize: 20,
          ),
        ),
      ),
      subtitle: Center(
        child: Obx(() {
          final nameLine =
              c.customerName.value.trim().isEmpty
                  ? 'Picking up Rider'
                  : 'Picking up ${c.customerName.value.trim()}';
          final distLine = _routeDistanceText(driverStatusController, '');

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CustomTextfield.textWithStylesSmall(
                nameLine,
                fontSize: 14,
                colors: AppColors.textColorGrey,
              ),
              const SizedBox(height: 2),
              CustomTextfield.textWithStylesSmall(
                distLine,
                fontSize: 12,
                colors: AppColors.textColorGrey,
              ),
              Obx(() {
                final label = driverStatusController.lastDriverLocationLabel;
                if (label.isEmpty) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: CustomTextfield.textWithStylesSmall(
                    label,
                    fontSize: 11,
                    colors: AppColors.textColorGrey,
                  ),
                );
              }),
            ],
          );
        }),
      ),
    );
  }

  // Second row: left photo + name
  static Widget _customerRow(
    PickingCustomerController c, {
    VoidCallback? onTapName,
  }) {
    return Obx(() {
      final name =
          c.customerName.value.trim().isEmpty
              ? "Rider"
              : c.customerName.value.trim();
      final img = c.customerProfilePic.value.trim();

      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15),
        child: Row(
          children: [
            ClipOval(
              child: CachedNetworkImage(
                imageUrl: img,
                height: 42,
                width: 42,
                fit: BoxFit.cover,
                placeholder:
                    (_, __) => const HopprCircularLoader(size: 42, radius: 12),
                errorWidget:
                    (_, __, ___) =>
                        const Icon(Icons.person, size: 36, color: Colors.black),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: InkWell(
                onTap: onTapName,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: CustomTextfield.textWithStyles600(name, fontSize: 18),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  static Widget _roundIconBox(String asset) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.commonBlack.withOpacity(0.1),
        borderRadius: BorderRadius.circular(30),
      ),
      padding: const EdgeInsets.all(10),
      child: Image.asset(asset, height: 25, width: 25),
    );
  }

  static String _formatDuration(double minutes) {
    if (!minutes.isFinite || minutes < 0) return '--';
    if (minutes > 0 && minutes < 1) return '<1 min';
    if (minutes == 0) return '0 min';
    final total = minutes.round();
    final h = total ~/ 60;
    final m = total % 60;
    return h > 0 ? '$h hr $m min' : '$m min';
  }

  static Widget _rideDetailsBlock({
    required String pickupAddress,
    required String dropAddress,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CustomTextfield.textWithStyles600('Ride Details', fontSize: 16),
          const SizedBox(height: 16),
          Row(
            children: [
              _dot(Colors.black),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CustomTextfield.textWithStyles600('Pickup', fontSize: 16),
                    CustomTextfield.textWithStylesSmall(
                      pickupAddress,
                      colors: AppColors.textColorGrey,
                      maxLine: 2,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _dot(AppColors.grey),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CustomTextfield.textWithStyles600('Drop off', fontSize: 16),
                    CustomTextfield.textWithStylesSmall(
                      dropAddress,
                      colors: AppColors.textColorGrey,
                      maxLine: 2,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static Widget _dot(Color c) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(40),
        color: AppColors.commonBlack.withOpacity(0.1),
      ),
      padding: const EdgeInsets.all(4),
      child: Icon(Icons.circle, size: 10, color: c),
    );
  }
}
