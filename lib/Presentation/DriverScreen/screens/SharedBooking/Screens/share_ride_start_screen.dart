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
import 'package:hopper/Core/Constants/Colors.dart';
import 'package:hopper/Core/Constants/log.dart';
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

import '../../../../../utils/websocket/socket_io_client.dart';
import '../Controller/booking_request_controller.dart';

/// ------------------------------------------------------------
/// Smooth marker animator (Uber-like feel)
/// - smoothly interpolates position + bearing
/// - uses shortest-angle rotation
/// ------------------------------------------------------------
class _MarkerAnimator {
  _MarkerAnimator({
    required this.onTick,
    this.duration = const Duration(milliseconds: 700),
    this.fps = 60,
    this.shouldTick,
  });

  final void Function(LatLng pos, double bearing) onTick;
  final Duration duration;
  final int fps;

  /// ✅ External guard (ex: widget disposing)
  final bool Function()? shouldTick;

  Timer? _timer;

  LatLng? _fromPos;
  LatLng? _toPos;

  double _fromBearing = 0;
  double _toBearing = 0;

  int _step = 0;
  int get _totalSteps =>
      math.max(1, (duration.inMilliseconds / (1000 / fps)).round());

  void dispose() => _timer?.cancel();

  void jumpTo(LatLng pos, double bearing) {
    _timer?.cancel();
    if (shouldTick != null && shouldTick!() == false) return;
    onTick(pos, _normalizeBearing(bearing));
  }

  void animateTo(LatLng newPos, double newBearing) {
    final nb = _normalizeBearing(newBearing);

    // if first time
    if (_toPos == null) {
      _fromPos = newPos;
      _toPos = newPos;
      _fromBearing = nb;
      _toBearing = nb;
      if (shouldTick != null && shouldTick!() == false) return;
      onTick(newPos, nb);
      return;
    }

    _timer?.cancel();
    _step = 0;

    _fromPos = _toPos;
    _toPos = newPos;

    _fromBearing = _toBearing;
    _toBearing = _shortestAngleTarget(_fromBearing, nb);

    final total = _totalSteps;
    _timer = Timer.periodic(Duration(milliseconds: (1000 / fps).round()), (t) {
      if (shouldTick != null && shouldTick!() == false) {
        t.cancel();
        return;
      }

      _step++;
      final p = (_step / total).clamp(0.0, 1.0);
      final eased = Curves.easeOutCubic.transform(p);

      final pos = _lerpLatLng(_fromPos!, _toPos!, eased);
      final bearing = _lerpDouble(_fromBearing, _toBearing, eased);

      onTick(pos, _normalizeBearing(bearing));

      if (p >= 1.0) t.cancel();
    });
  }

  // ---------- helpers ----------
  static LatLng _lerpLatLng(LatLng a, LatLng b, double t) {
    final lat = a.latitude + (b.latitude - a.latitude) * t;
    final lng = a.longitude + (b.longitude - a.longitude) * t;
    return LatLng(lat, lng);
  }

  static double _lerpDouble(double a, double b, double t) => a + (b - a) * t;

  static double _normalizeBearing(double b) {
    var x = b % 360;
    if (x < 0) x += 360;
    return x;
  }

  /// Adjust target bearing so rotation uses shortest path
  static double _shortestAngleTarget(double from, double to) {
    from = _normalizeBearing(from);
    to = _normalizeBearing(to);
    var diff = to - from;
    if (diff > 180) diff -= 360;
    if (diff < -180) diff += 360;
    return from + diff;
  }
}

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
  late final DriverRouteController _routeController;

  final SharedController sharedController = Get.put(SharedController());
  final DriverStatusController driverStatusController = Get.put(
    DriverStatusController(),
  );
  final BookingRequestController bookingController =
  Get.find<BookingRequestController>();
  final SharedRideController sharedRideController =
  Get.find<SharedRideController>();

  final GlobalKey<SharedMapState> _mapKey = GlobalKey<SharedMapState>();

  // Animated driver marker state
  LatLng? _animatedDriverPos;
  double _animatedBearing = 0.0;

  // Route data
  List<LatLng> polylinePoints = const [];
  String directionText = '';
  String distance = '';
  String maneuver = '';

  BitmapDescriptor? carIcon;
  late SocketService socketService;

  bool driverCompletedRide = false;
  bool _isDriverFocused = false;
  bool _leavingScreen = false;

  /// ✅ critical: prevents setState while element is defunct
  bool _isDisposing = false;

  late final _MarkerAnimator _markerAnimator;

  // UI update throttle
  DateTime? _lastUiUpdate;
  List<LatLng>? _lastPolyline;
  String _lastDirectionText = '';
  String _lastDistanceText = '';
  String _lastManeuver = '';

  late final AnimationController _pulseController;

  final Set<String> _expandedCards = <String>{};

  // -------------------- SAFE EXIT --------------------
  Future<void> _exitToHomeSafely() async {
    if (_leavingScreen) return;
    _leavingScreen = true;

    try {
      Get.closeAllSnackbars();
    } catch (_) {}
    try {
      if (Get.isBottomSheetOpen == true) Get.back();
    } catch (_) {}
    try {
      if (Get.isDialogOpen == true) Get.back();
    } catch (_) {}

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _isDisposing) return;
      if (Get.currentRoute == '/DriverMainScreen') return;
      Get.offAll(() => const DriverMainScreen());
    });
  }

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

    _animatedDriverPos = widget.driverLocation;

    _markerAnimator = _MarkerAnimator(
      shouldTick: () => mounted && !_isDisposing,
      onTick: (pos, bearing) {
        if (!mounted || _isDisposing) return;
        setState(() {
          _animatedDriverPos = pos;
          _animatedBearing = bearing;
        });
      },
    );

    _initSocket();
    _loadMarkerIcons();

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
        // if screen is closing, ignore ALL ticks
        if (!mounted || _isDisposing) return;

        // 1) Smooth marker always
        _markerAnimator.animateTo(update.driverLocation, update.bearing);

        // 2) Update controller store for other logic
        sharedRideController.updateDriverLocation(update.driverLocation);

        // 3) Throttle heavy UI updates (polyline, text)
        final now = DateTime.now();
        if (_lastUiUpdate != null &&
            now.difference(_lastUiUpdate!).inMilliseconds < 300) {
          return;
        }
        _lastUiUpdate = now;

        final poly = update.polylinePoints;
        final dText = update.directionText;
        final distText = update.distanceText;
        final man = update.maneuver;

        final polyChanged =
            _lastPolyline == null ||
                poly.length != _lastPolyline!.length ||
                (poly.isNotEmpty &&
                    _lastPolyline!.isNotEmpty &&
                    (poly.first != _lastPolyline!.first ||
                        poly.last != _lastPolyline!.last));

        final textChanged =
            dText != _lastDirectionText ||
                distText != _lastDistanceText ||
                man != _lastManeuver;

        if (!mounted || _isDisposing) return;
        if (!polyChanged && !textChanged) return;

        setState(() {
          if (polyChanged) {
            polylinePoints = poly;
            _lastPolyline = poly;
          }
          if (textChanged) {
            directionText = dText;
            distance = distText;
            maneuver = man;
            _lastDirectionText = dText;
            _lastDistanceText = distText;
            _lastManeuver = man;
          }
        });
      },
      onCameraUpdate: (_) {},
    );

    _routeController.start();

    // ✅ if you need pulse later, keep it but do NOT call setState in listener
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    // ✅ IMPORTANT: set first to stop setState during disposal window
    _isDisposing = true;

    // stop animations/timers FIRST
    try {
      _markerAnimator.dispose();
    } catch (_) {}
    try {
      _routeController.dispose();
    } catch (_) {}
    try {
      _pulseController.stop();
      _pulseController.dispose();
    } catch (_) {}

    // socket cleanup
    try {
      socketService.socket.off('driver-reached-destination');
      socketService.socket.off('driver-location');
      socketService.socket.off('driver-cancelled');
      socketService.socket.off('customer-cancelled');
      socketService.socket.off('joined-booking');
      socketService.socket.off('booking-request');

      // if supported by your socket client:
      try {
        socketService.socket.offAny();
      } catch (_) {}

      try {
        // socketService.disconnect();
      } catch (_) {}
    } catch (_) {}

    super.dispose();
  }

  // -------------------- HELPERS --------------------
  Future<String> getAddressFromLatLng(double lat, double lng) async {
    try {
      final list = await placemarkFromCoordinates(lat, lng);
      final p = list.first;
      return "${p.name}, ${p.locality}, ${p.administrativeArea}";
    } catch (_) {
      return "Location not available";
    }
  }

  double? _safeNum(dynamic v) {
    if (v == null) return null;
    try {
      return (v as num).toDouble();
    } catch (_) {
      return null;
    }
  }

  // -------------------- SOCKET --------------------
  Future<void> _initSocket() async {
    socketService = SocketService();

    socketService.on('driver-reached-destination', (data) {
      if (!mounted || _isDisposing) return;
      final status = data?['status'];
      if (status == true || status?.toString() == 'true') {
        setState(() => driverCompletedRide = true);
        CommonLogger.log.i('✅ Driver reached destination');
      }
    });

    socketService.on('joined-booking', (data) async {
      try {
        CommonLogger.log.i("[SHARED START] joined-booking → $data");
        if (!mounted || _isDisposing || data == null) return;

        final customerLoc = data['customerLocation'];
        if (customerLoc == null) return;

        final fromLat = _safeNum(
          customerLoc['fromLatitude'] ?? customerLoc['latitude'],
        );
        final fromLng = _safeNum(
          customerLoc['fromLongitude'] ?? customerLoc['longitude'],
        );
        final toLat = _safeNum(
          customerLoc['toLatitude'] ?? customerLoc['toLat'],
        );
        final toLng = _safeNum(
          customerLoc['toLongitude'] ?? customerLoc['toLng'],
        );

        if (fromLat == null ||
            fromLng == null ||
            toLat == null ||
            toLng == null) {
          return;
        }

        final pickupAddrs = await getAddressFromLatLng(fromLat, fromLng);
        final dropoffAddrs = await getAddressFromLatLng(toLat, toLng);

        final String bookingIdStr = data['bookingId']?.toString() ?? '';
        if (bookingIdStr.isEmpty) return;

        final riders = sharedRideController.riders;
        final existingIndex = riders.indexWhere(
              (r) => r.bookingId.toString() == bookingIdStr,
        );

        if (existingIndex == -1) {
          riders.add(
            SharedRiderItem(
              bookingId: bookingIdStr,
              name: data['customerName']?.toString() ?? 'Rider',
              phone: data['customerPhone']?.toString() ?? '',
              profilePic:
              data['customerProfilePic']?.toString() ??
                  data['profilePic']?.toString() ??
                  '',
              pickupAddress: pickupAddrs,
              dropoffAddress: dropoffAddrs,
              amount: (data['amount'] as num?) ?? 0,
              pickupLatLng: LatLng(fromLat, fromLng),
              dropLatLng: LatLng(toLat, toLng),
              arrived: false,
              secondsLeft: 0,
              sliderController: ActionSliderController(),
              stage: SharedRiderStage.waitingPickup,
            ),
          );
        } else {
          final old = riders[existingIndex];
          riders[existingIndex] = SharedRiderItem(
            bookingId: bookingIdStr,
            name: data['customerName']?.toString() ?? old.name,
            phone: data['customerPhone']?.toString() ?? old.phone,
            profilePic:
            data['customerProfilePic']?.toString() ??
                data['profilePic']?.toString() ??
                old.profilePic,
            pickupAddress: pickupAddrs,
            dropoffAddress: dropoffAddrs,
            amount: (data['amount'] as num?) ?? old.amount,
            pickupLatLng: LatLng(fromLat, fromLng),
            dropLatLng: LatLng(toLat, toLng),
            arrived: old.arrived,
            secondsLeft: old.secondsLeft,
            stage: old.stage,
            sliderController: old.sliderController,
          );
        }

        var active = sharedRideController.activeTarget.value;
        if (active == null || riders.length == 1) {
          sharedRideController.setActiveTarget(
            bookingIdStr,
            SharedRiderStage.waitingPickup,
          );
          active = sharedRideController.activeTarget.value;
        }

        if (active != null) {
          final dest =
          active.stage == SharedRiderStage.waitingPickup
              ? active.pickupLatLng
              : active.dropLatLng;

          sharedController.pickupDistanceInMeters.value = 0;
          sharedController.pickupDurationInMin.value = 0;
          sharedController.dropDistanceInMeters.value = 0;
          sharedController.dropDurationInMin.value = 0;

          await _routeController.updateDestination(dest);
          _mapKey.currentState?.focusPickup();
        }

        if (!mounted || _isDisposing) return;
        setState(() {});
      } catch (e, st) {
        CommonLogger.log.e('[SHARED START] Error joined-booking');
        debugPrint('$e');
        debugPrint('$st');
      }
    });

    socketService.on('booking-request', (data) async {
      if (!mounted || _isDisposing) return;
      if (data == null) return;

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
        _safeNum(pickup['latitude']) ?? 0,
        _safeNum(pickup['longitude']) ?? 0,
      );
      final dropAddr = await getAddressFromLatLng(
        _safeNum(drop['latitude']) ?? 0,
        _safeNum(drop['longitude']) ?? 0,
      );

      if (!mounted || _isDisposing) return;
      bookingController.showRequest(
        rawData: data,
        pickupAddress: pickupAddr,
        dropAddress: dropAddr,
      );
    });

    socketService.on('driver-cancelled', (data) async {
      if (data?['status'] == true) await _exitToHomeSafely();
    });

    socketService.on('customer-cancelled', (data) async {
      if (data?['status'] == true) await _exitToHomeSafely();
    });

    if (!socketService.connected) {
      socketService.connect();
      socketService.onConnect(
            () => CommonLogger.log.i('🔌 [SHARED START] socket connected'),
      );
    }
  }

  // -------------------- ICONS --------------------
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
      if (!mounted || _isDisposing) return;
      setState(() => carIcon = icon);
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
        return "assets/images/straight.png";
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

  // -------------------- NAV / TARGET --------------------
  Future<void> _setAsNextStop(SharedRiderItem r) async {
    if (!mounted || _isDisposing) return;
    if (r.stage == SharedRiderStage.dropped) return;

    sharedRideController.setActiveTarget(r.bookingId, r.stage);

    final ctrl = r.sliderController as ActionSliderController?;
    ctrl?.reset();

    final dest =
    r.stage == SharedRiderStage.waitingPickup
        ? r.pickupLatLng
        : r.dropLatLng;

    sharedController.pickupDistanceInMeters.value = 0;
    sharedController.pickupDurationInMin.value = 0;
    sharedController.dropDistanceInMeters.value = 0;
    sharedController.dropDurationInMin.value = 0;

    await _routeController.updateDestination(dest);
    _mapKey.currentState?.focusPickup();

    if (!mounted || _isDisposing) return;
    setState(() {});
  }

  Future<void> _onCurrentLegCompleted(SharedRiderItem completedRider) async {
    if (!mounted || _isDisposing) return;

    final bool? cashCollected = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CashCollectedScreen(
          name: completedRider.name,
          imageUrl: completedRider.profilePic,
          bookingId: completedRider.bookingId,
          Amount: completedRider.amount,
          isSharedRide: true,
        ),
      ),
    );

    if (!mounted || _isDisposing) return;
    if (cashCollected != true) return;

    sharedRideController.markDropped(completedRider.bookingId);

    try {
      final doneCtrl =
      completedRider.sliderController as ActionSliderController?;
      doneCtrl?.reset();
    } catch (_) {}

    final next = sharedRideController.recomputeNextTarget();

    if (next == null) {
      if (!mounted || _isDisposing) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const DriverMainScreen()),
            (route) => false,
      );
      return;
    }

    sharedRideController.setActiveTarget(next.bookingId, next.stage);

    final nextCtrl = next.sliderController as ActionSliderController?;
    nextCtrl?.reset();

    final dest =
    next.stage == SharedRiderStage.waitingPickup
        ? next.pickupLatLng
        : next.dropLatLng;
    await _routeController.updateDestination(dest);

    if (!mounted || _isDisposing) return;
    setState(() {});
  }

  // -------------------- UI PIECES --------------------
  Widget _buildEtaRow(SharedRiderItem active) {
    final isPickupLeg = active.stage == SharedRiderStage.waitingPickup;

    return Obx(() {
      final minutes = isPickupLeg
          ? sharedController.pickupDurationInMin.value
          : sharedController.dropDurationInMin.value;

      final meters = isPickupLeg
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

  Widget _buildActiveActionArea(SharedRiderItem active) {
    if (active.stage == SharedRiderStage.waitingPickup && !active.arrived) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Buttons.button(
          buttonColor: AppColors.resendBlue,
          borderRadius: 8,
          onTap: () async {
            try {
              final result = await driverStatusController.driverArrived(
                context,
                bookingId: active.bookingId,
              );

              if (!mounted || _isDisposing) return;

              if (result != null && result.status == 200) {
                sharedRideController.markArrived(active.bookingId);
                if (!mounted || _isDisposing) return;
                setState(() {});
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(result?.message ?? "Something went wrong"),
                  ),
                );
              }
            } catch (_) {
              if (!mounted || _isDisposing) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Unable to mark as arrived, please retry'),
                ),
              );
            }
          },
          text: Text('Arrived at pickup for ${active.name}'),
        ),
      );
    }

    if (active.stage == SharedRiderStage.waitingPickup && active.arrived) {
      final riderCtrl = active.sliderController as ActionSliderController;

      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: ActionSlider.standard(
          key: ValueKey(
            'start-${active.bookingId}-${active.stage}-${active.arrived}',
          ),
          controller: riderCtrl,
          height: 52,
          backgroundColor: AppColors.drkGreen,
          toggleColor: Colors.white,
          icon: Icon(Icons.double_arrow, color: AppColors.drkGreen, size: 28),
          child: Text(
            'Swipe to Start Ride for ${active.name}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          action: (controller) async {
            try {
              controller.loading();

              final msg = await driverStatusController.otpRequest(
                context,
                bookingId: active.bookingId,
                custName: active.name,
                pickupAddress: active.pickupAddress,
                dropAddress: active.dropoffAddress,
              );

              if (!mounted || _isDisposing) return;

              if (msg == null) {
                controller.failure();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Failed to send OTP')),
                );
                await Future.delayed(const Duration(milliseconds: 700));
                controller.reset();
                return;
              }

              final verified = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (_) => VerifyRiderScreen(
                    bookingId: active.bookingId,
                    custName: active.name,
                    pickupAddress: active.pickupAddress,
                    dropAddress: active.dropoffAddress,
                    isSharedRide: true,
                  ),
                ),
              );

              if (!mounted || _isDisposing) return;

              if (verified == true) {
                controller.success();
                sharedRideController.markOnboard(active.bookingId);
                await _setAsNextStop(active);
              } else {
                controller.reset();
              }
            } catch (_) {
              if (!mounted || _isDisposing) return;
              controller.failure();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Something went wrong, please try again'),
                ),
              );
              await Future.delayed(const Duration(milliseconds: 700));
              controller.reset();
            }
          },
        ),
      );
    }

    if (active.stage == SharedRiderStage.onboardDrop) {
      final riderSlider = active.sliderController as ActionSliderController;

      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: ActionSlider.standard(
          key: ValueKey('complete-${active.bookingId}-${active.stage}'),
          controller: riderSlider,
          height: 52,
          backgroundColor: AppColors.drkGreen,
          toggleColor: Colors.white,
          icon: Icon(Icons.double_arrow, color: AppColors.drkGreen, size: 28),
          child: const Text(
            'Complete Current Stop',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          action: (controller) async {
            try {
              controller.loading();
              await Future.delayed(const Duration(milliseconds: 200));

              final msg = await driverStatusController.completeRideRequest(
                context,
                Amount: active.amount,
                bookingId: active.bookingId,
                navigateToCashScreen: false,
                isSharedRide: true,
              );

              if (!mounted || _isDisposing) return;

              if (msg != null) {
                controller.success();
                await _onCurrentLegCompleted(active);
              } else {
                controller.failure();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Failed to complete stop')),
                );
                await Future.delayed(const Duration(milliseconds: 700));
                controller.reset();
              }
            } catch (_) {
              if (!mounted || _isDisposing) return;
              controller.failure();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Something went wrong, please try again'),
                ),
              );
              await Future.delayed(const Duration(milliseconds: 700));
              controller.reset();
            }
          },
        ),
      );
    }

    return const SizedBox.shrink();
  }

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
      if (!mounted || _isDisposing) return;
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
          color: isActive
              ? AppColors.containerColor1.withOpacity(0.1)
              : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isActive ? AppColors.resendBlue : Colors.grey.withOpacity(0.25),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipOval(
              child: CachedNetworkImage(
                imageUrl: r.profilePic,
                height: 40,
                width: 40,
                fit: BoxFit.cover,
                placeholder: (c, u) => const SizedBox(
                  height: 30,
                  width: 30,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                errorWidget: (c, u, e) => const Icon(Icons.person, size: 30),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: InkWell(
                onTap: toggleExpanded,
                borderRadius: BorderRadius.circular(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
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
                        AnimatedRotation(
                          turns: isExpanded ? 0.5 : 0.0,
                          duration: const Duration(milliseconds: 200),
                          child: Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 20,
                            color: AppColors.textColorGrey,
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
                    AnimatedCrossFade(
                      duration: const Duration(milliseconds: 220),
                      crossFadeState: isExpanded
                          ? CrossFadeState.showSecond
                          : CrossFadeState.showFirst,
                      firstChild: const SizedBox(height: 0),
                      secondChild: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Column(
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
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
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

  @override
  Widget build(BuildContext context) {
    final active = sharedRideController.activeTarget.value;
    final driverPos = _animatedDriverPos ?? widget.driverLocation;

    final markers = <Marker>{
      Marker(
        markerId: const MarkerId('driver'),
        position: driverPos,
        icon: carIcon ?? BitmapDescriptor.defaultMarker,
        rotation: _animatedBearing,
        anchor: const Offset(0.5, 0.5),
        flat: true,
        zIndex: 999,
      ),
      if (active != null)
        Marker(
          markerId: const MarkerId('target'),
          position: active.stage == SharedRiderStage.waitingPickup
              ? active.pickupLatLng
              : active.dropLatLng,
          infoWindow: InfoWindow(
            title: active.stage == SharedRiderStage.waitingPickup
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
              SizedBox(
                height: 550,
                width: double.infinity,
                child: SharedMap(
                  key: _mapKey,
                  followDriver: true,
                  followZoom: 17,
                  followTilt: 45,
                  initialPosition: widget.pickupLocation,
                  pickupPosition: driverPos,
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

                      if (!mounted || _isDisposing) return;
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
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CustomTextfield.textWithStyles600(
                                directionText,
                                maxLine: 2,
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
                            _buildEtaRow(active),
                            const SizedBox(height: 10),
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
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Column(
                                children: sharedRideController.riders
                                    .map(_buildRiderRow)
                                    .toList(),
                              ),
                            ),

                          const SizedBox(height: 20),

                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Obx(() {
                                  final stopped = driverStatusController
                                      .isStopNewRequests
                                      .value;

                                  return Buttons.button(
                                    borderColor: AppColors.buttonBorder,
                                    buttonColor: stopped
                                        ? AppColors.containerColor
                                        : AppColors.commonWhite,
                                    borderRadius: 8,
                                    textColor: AppColors.commonBlack,
                                    onTap: stopped
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
                                        if (Get.isBottomSheetOpen == true) {
                                          Get.back();
                                        }

                                        await driverStatusController.cancelBooking(
                                          context,
                                          bookingId: widget.bookingId,
                                          reason: reason,
                                          silent: true,
                                          navigate: true,
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

              const BookingOverlayRequest(isSharedFlow: true),
            ],
          ),
        ),
      ),
    );
  }
}

// import 'dart:async';
// import 'dart:math' as math;
// import 'dart:ui' as ui;
//
// import 'package:action_slider/action_slider.dart';
// import 'package:cached_network_image/cached_network_image.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:geocoding/geocoding.dart';
// import 'package:get/get.dart';
// import 'package:google_maps_flutter/google_maps_flutter.dart';
// import 'package:hopper/Core/Constants/Colors.dart';
// import 'package:hopper/Core/Constants/log.dart';
// import 'package:hopper/Core/Utility/Buttons.dart';
// import 'package:hopper/Core/Utility/images.dart';
// import 'package:hopper/Presentation/Authentication/widgets/textFields.dart';
// import 'package:hopper/Presentation/DriverScreen/controller/driver_status_controller.dart';
// import 'package:hopper/Presentation/DriverScreen/screens/SharedBooking/Controller/shared_controller.dart';
// import 'package:hopper/Presentation/DriverScreen/screens/SharedBooking/Controller/shared_ride_controller.dart';
// import 'package:hopper/Presentation/DriverScreen/screens/SharedBooking/Screens/booking_overlay_request.dart';
// import 'package:hopper/Presentation/DriverScreen/screens/cash_collected_screen.dart';
// import 'package:hopper/Presentation/DriverScreen/screens/driver_main_screen.dart';
// import 'package:hopper/Presentation/DriverScreen/screens/verify_rider_screen.dart';
// import 'package:hopper/utils/map/driver_route.dart';
// import 'package:hopper/utils/map/shared_map.dart';
// import 'package:hopper/utils/netWorkHandling/network_handling_screen.dart';
//
// import '../../../../../utils/websocket/socket_io_client.dart';
// import '../Controller/booking_request_controller.dart';
//
// /// ------------------------------------------------------------
// /// Smooth marker animator (Uber-like feel)
// /// - smoothly interpolates position + bearing
// /// - uses shortest-angle rotation
// /// ------------------------------------------------------------
// class _MarkerAnimator {
//   _MarkerAnimator({
//     required this.onTick,
//     this.duration = const Duration(milliseconds: 700),
//     this.fps = 60,
//   });
//
//   final void Function(LatLng pos, double bearing) onTick;
//   final Duration duration;
//   final int fps;
//
//   Timer? _timer;
//
//   LatLng? _fromPos;
//   LatLng? _toPos;
//
//   double _fromBearing = 0;
//   double _toBearing = 0;
//
//   int _step = 0;
//   int get _totalSteps =>
//       math.max(1, (duration.inMilliseconds / (1000 / fps)).round());
//
//   void dispose() => _timer?.cancel();
//
//   void jumpTo(LatLng pos, double bearing) {
//     _timer?.cancel();
//     onTick(pos, _normalizeBearing(bearing));
//   }
//
//   void animateTo(LatLng newPos, double newBearing) {
//     final nb = _normalizeBearing(newBearing);
//
//     // if first time
//     if (_toPos == null) {
//       _fromPos = newPos;
//       _toPos = newPos;
//       _fromBearing = nb;
//       _toBearing = nb;
//       onTick(newPos, nb);
//       return;
//     }
//
//     _timer?.cancel();
//     _step = 0;
//
//     _fromPos = _toPos;
//     _toPos = newPos;
//
//     _fromBearing = _toBearing;
//     _toBearing = _shortestAngleTarget(_fromBearing, nb);
//
//     final total = _totalSteps;
//     _timer = Timer.periodic(Duration(milliseconds: (1000 / fps).round()), (t) {
//       _step++;
//       final p = (_step / total).clamp(0.0, 1.0);
//
//       final eased = Curves.easeOutCubic.transform(p);
//
//       final pos = _lerpLatLng(_fromPos!, _toPos!, eased);
//       final bearing = _lerpDouble(_fromBearing, _toBearing, eased);
//
//       onTick(pos, _normalizeBearing(bearing));
//
//       if (p >= 1.0) t.cancel();
//     });
//   }
//
//   // ---------- helpers ----------
//   static LatLng _lerpLatLng(LatLng a, LatLng b, double t) {
//     final lat = a.latitude + (b.latitude - a.latitude) * t;
//     final lng = a.longitude + (b.longitude - a.longitude) * t;
//     return LatLng(lat, lng);
//   }
//
//   static double _lerpDouble(double a, double b, double t) => a + (b - a) * t;
//
//   static double _normalizeBearing(double b) {
//     var x = b % 360;
//     if (x < 0) x += 360;
//     return x;
//   }
//
//   /// Adjust target bearing so rotation uses shortest path
//   static double _shortestAngleTarget(double from, double to) {
//     from = _normalizeBearing(from);
//     to = _normalizeBearing(to);
//     var diff = to - from;
//     if (diff > 180) diff -= 360;
//     if (diff < -180) diff += 360;
//     return from + diff;
//   }
// }
//
// class ShareRideStartScreen extends StatefulWidget {
//   final String bookingId; // pool / main booking
//   final LatLng pickupLocation;
//   final LatLng driverLocation;
//
//   const ShareRideStartScreen({
//     Key? key,
//     required this.pickupLocation,
//     required this.driverLocation,
//     required this.bookingId,
//   }) : super(key: key);
//
//   @override
//   State<ShareRideStartScreen> createState() => _ShareRideStartScreenState();
// }
//
// class _ShareRideStartScreenState extends State<ShareRideStartScreen>
//     with SingleTickerProviderStateMixin {
//   late final DriverRouteController _routeController;
//
//   final SharedController sharedController = Get.put(SharedController());
//   final DriverStatusController driverStatusController = Get.put(
//     DriverStatusController(),
//   );
//   final BookingRequestController bookingController =
//       Get.find<BookingRequestController>();
//   final SharedRideController sharedRideController =
//       Get.find<SharedRideController>();
//
//   final GlobalKey<SharedMapState> _mapKey = GlobalKey<SharedMapState>();
//
//   // Animated driver marker state
//   LatLng? _animatedDriverPos;
//   double _animatedBearing = 0.0;
//
//   // Route data
//   List<LatLng> polylinePoints = const [];
//   String directionText = '';
//   String distance = '';
//   String maneuver = '';
//
//   BitmapDescriptor? carIcon;
//   late SocketService socketService;
//
//   bool driverCompletedRide = false;
//   bool _isDriverFocused = false;
//   bool _leavingScreen = false;
//
//   late final _MarkerAnimator _markerAnimator;
//
//   // UI update throttle
//   DateTime? _lastUiUpdate;
//   List<LatLng>? _lastPolyline;
//   String _lastDirectionText = '';
//   String _lastDistanceText = '';
//   String _lastManeuver = '';
//
//   late final AnimationController _pulseController;
//   late final Animation<double> _pulseAnimation;
//
//   final Set<String> _expandedCards = <String>{};
//
//   // -------------------- SAFE EXIT --------------------
//   Future<void> _exitToHomeSafely() async {
//     if (_leavingScreen) return;
//     _leavingScreen = true;
//
//     try {
//       Get.closeAllSnackbars();
//     } catch (_) {}
//     try {
//       if (Get.isBottomSheetOpen == true) Get.back();
//     } catch (_) {}
//     try {
//       if (Get.isDialogOpen == true) Get.back();
//     } catch (_) {}
//
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       if (!mounted) return;
//       if (Get.currentRoute == '/DriverMainScreen') return;
//       Get.offAll(() => const DriverMainScreen());
//     });
//   }
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
//     _animatedDriverPos = widget.driverLocation;
//
//     _markerAnimator = _MarkerAnimator(
//       onTick: (pos, bearing) {
//         if (!mounted) return;
//         // Only setState for marker movement (fast)
//         setState(() {
//           _animatedDriverPos = pos;
//           _animatedBearing = bearing;
//         });
//       },
//     );
//
//     _initSocket();
//     _loadMarkerIcons();
//
//     final initialTarget = sharedRideController.activeTarget.value;
//     final initialDestination =
//         initialTarget == null
//             ? widget.pickupLocation
//             : (initialTarget.stage == SharedRiderStage.waitingPickup
//                 ? initialTarget.pickupLatLng
//                 : initialTarget.dropLatLng);
//
//     _routeController = DriverRouteController(
//       destination: initialDestination,
//       onRouteUpdate: (update) {
//         // 1) Smooth marker always
//         _markerAnimator.animateTo(update.driverLocation, update.bearing);
//
//         // 2) Update controller store for other logic
//         sharedRideController.updateDriverLocation(update.driverLocation);
//
//         // 3) Throttle heavy UI updates (polyline, text)
//         final now = DateTime.now();
//         if (_lastUiUpdate != null &&
//             now.difference(_lastUiUpdate!).inMilliseconds < 300) {
//           return;
//         }
//         _lastUiUpdate = now;
//
//         // Avoid rebuild if same
//         final poly = update.polylinePoints;
//         final dText = update.directionText;
//         final distText = update.distanceText;
//         final man = update.maneuver;
//
//         final polyChanged =
//             _lastPolyline == null ||
//             poly.length != _lastPolyline!.length ||
//             (poly.isNotEmpty &&
//                 _lastPolyline!.isNotEmpty &&
//                 (poly.first != _lastPolyline!.first ||
//                     poly.last != _lastPolyline!.last));
//
//         final textChanged =
//             dText != _lastDirectionText ||
//             distText != _lastDistanceText ||
//             man != _lastManeuver;
//
//         if (!mounted) return;
//         if (!polyChanged && !textChanged) return;
//
//         setState(() {
//           if (polyChanged) {
//             polylinePoints = poly;
//             _lastPolyline = poly;
//           }
//           if (textChanged) {
//             directionText = dText;
//             distance = distText;
//             maneuver = man;
//             _lastDirectionText = dText;
//             _lastDistanceText = distText;
//             _lastManeuver = man;
//           }
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
//     //
//     // _pulseAnimation = Tween<double>(begin: 0, end: 60).animate(
//     //   CurvedAnimation(parent: _pulseController, curve: Curves.easeOut),
//     // )..addListener(() {
//     //   if (!mounted) return;
//     //   if (_isDriverFocused) setState(() {});
//     // });
//   }
//
//   @override
//   void dispose() {
//     _markerAnimator.dispose();
//     _routeController.dispose();
//     _pulseController.dispose();
//
//     try {
//       socketService.socket.off('driver-reached-destination');
//       socketService.socket.off('driver-location');
//       socketService.socket.off('driver-cancelled');
//       socketService.socket.off('customer-cancelled');
//       socketService.socket.off('joined-booking');
//       socketService.socket.off('booking-request');
//       socketService.socket.onAny((event, data) {});
//     } catch (_) {}
//
//     super.dispose();
//   }
//
//   // -------------------- HELPERS --------------------
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
//   double? _safeNum(dynamic v) {
//     if (v == null) return null;
//     try {
//       return (v as num).toDouble();
//     } catch (_) {
//       return null;
//     }
//   }
//
//   // -------------------- SOCKET --------------------
//   Future<void> _initSocket() async {
//     socketService = SocketService();
//
//     socketService.on('driver-reached-destination', (data) {
//       final status = data?['status'];
//       if (status == true || status?.toString() == 'true') {
//         if (!mounted) return;
//         setState(() => driverCompletedRide = true);
//         CommonLogger.log.i('✅ Driver reached destination');
//       }
//     });
//
//     socketService.on('joined-booking', (data) async {
//       try {
//         CommonLogger.log.i("[SHARED START] joined-booking → $data");
//
//         if (!mounted || data == null) return;
//
//         final customerLoc = data['customerLocation'];
//         if (customerLoc == null) return;
//
//         final fromLat = _safeNum(
//           customerLoc['fromLatitude'] ?? customerLoc['latitude'],
//         );
//         final fromLng = _safeNum(
//           customerLoc['fromLongitude'] ?? customerLoc['longitude'],
//         );
//         final toLat = _safeNum(
//           customerLoc['toLatitude'] ?? customerLoc['toLat'],
//         );
//         final toLng = _safeNum(
//           customerLoc['toLongitude'] ?? customerLoc['toLng'],
//         );
//
//         if (fromLat == null ||
//             fromLng == null ||
//             toLat == null ||
//             toLng == null) {
//           return;
//         }
//
//         final pickupAddrs = await getAddressFromLatLng(fromLat, fromLng);
//         final dropoffAddrs = await getAddressFromLatLng(toLat, toLng);
//
//         final String bookingIdStr = data['bookingId']?.toString() ?? '';
//         if (bookingIdStr.isEmpty) return;
//
//         final riders = sharedRideController.riders;
//         final existingIndex = riders.indexWhere(
//           (r) => r.bookingId.toString() == bookingIdStr,
//         );
//
//         if (existingIndex == -1) {
//           riders.add(
//             SharedRiderItem(
//               bookingId: bookingIdStr,
//               name: data['customerName']?.toString() ?? 'Rider',
//               phone: data['customerPhone']?.toString() ?? '',
//               profilePic:
//                   data['customerProfilePic']?.toString() ??
//                   data['profilePic']?.toString() ??
//                   '',
//               pickupAddress: pickupAddrs,
//               dropoffAddress: dropoffAddrs,
//               amount: (data['amount'] as num?) ?? 0,
//               pickupLatLng: LatLng(fromLat, fromLng),
//               dropLatLng: LatLng(toLat, toLng),
//               arrived: false,
//               secondsLeft: 0,
//               sliderController: ActionSliderController(),
//               stage: SharedRiderStage.waitingPickup,
//             ),
//           );
//         } else {
//           final old = riders[existingIndex];
//           riders[existingIndex] = SharedRiderItem(
//             bookingId: bookingIdStr,
//             name: data['customerName']?.toString() ?? old.name,
//             phone: data['customerPhone']?.toString() ?? old.phone,
//             profilePic:
//                 data['customerProfilePic']?.toString() ??
//                 data['profilePic']?.toString() ??
//                 old.profilePic,
//             pickupAddress: pickupAddrs,
//             dropoffAddress: dropoffAddrs,
//             amount: (data['amount'] as num?) ?? old.amount,
//             pickupLatLng: LatLng(fromLat, fromLng),
//             dropLatLng: LatLng(toLat, toLng),
//             arrived: old.arrived,
//             secondsLeft: old.secondsLeft,
//             stage: old.stage,
//             sliderController: old.sliderController,
//           );
//         }
//
//         // auto pick active if none
//         var active = sharedRideController.activeTarget.value;
//         if (active == null || riders.length == 1) {
//           sharedRideController.setActiveTarget(
//             bookingIdStr,
//             SharedRiderStage.waitingPickup,
//           );
//           active = sharedRideController.activeTarget.value;
//         }
//
//         if (active != null) {
//           final dest =
//               active.stage == SharedRiderStage.waitingPickup
//                   ? active.pickupLatLng
//                   : active.dropLatLng;
//
//           sharedController.pickupDistanceInMeters.value = 0;
//           sharedController.pickupDurationInMin.value = 0;
//           sharedController.dropDistanceInMeters.value = 0;
//           sharedController.dropDurationInMin.value = 0;
//
//           await _routeController.updateDestination(dest);
//           _mapKey.currentState?.focusPickup();
//         }
//
//         if (mounted) setState(() {});
//       } catch (e, st) {
//         CommonLogger.log.e('[SHARED START] Error joined-booking');
//         debugPrint('$e');
//         debugPrint('$st');
//       }
//     });
//
//     socketService.on('booking-request', (data) async {
//       if (data == null) return;
//
//       final incomingId = data['bookingId']?.toString();
//       if (incomingId == widget.bookingId) return;
//
//       if (incomingId != null &&
//           incomingId == bookingController.lastHandledBookingId.value) {
//         return;
//       }
//
//       final pickup = data['pickupLocation'];
//       final drop = data['dropLocation'];
//       if (pickup == null || drop == null) return;
//
//       final pickupAddr = await getAddressFromLatLng(
//         _safeNum(pickup['latitude']) ?? 0,
//         _safeNum(pickup['longitude']) ?? 0,
//       );
//       final dropAddr = await getAddressFromLatLng(
//         _safeNum(drop['latitude']) ?? 0,
//         _safeNum(drop['longitude']) ?? 0,
//       );
//
//       bookingController.showRequest(
//         rawData: data,
//         pickupAddress: pickupAddr,
//         dropAddress: dropAddr,
//       );
//     });
//
//     socketService.on('driver-cancelled', (data) async {
//       if (data?['status'] == true) await _exitToHomeSafely();
//     });
//
//     socketService.on('customer-cancelled', (data) async {
//       if (data?['status'] == true) await _exitToHomeSafely();
//     });
//
//     if (!socketService.connected) {
//       socketService.connect();
//       socketService.onConnect(
//         () => CommonLogger.log.i('🔌 [SHARED START] socket connected'),
//       );
//     }
//   }
//
//   // -------------------- ICONS --------------------
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
//       setState(() => carIcon = icon);
//     } catch (_) {
//       carIcon = BitmapDescriptor.defaultMarker;
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
//         return "assets/images/straight.png";
//     }
//   }
//
//   String _formatDistance(double meters) {
//     final km = meters / 1000.0;
//     if (meters <= 0) return '0 Km';
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
//   // -------------------- NAV / TARGET --------------------
//   Future<void> _setAsNextStop(SharedRiderItem r) async {
//     if (r.stage == SharedRiderStage.dropped) return;
//
//     sharedRideController.setActiveTarget(r.bookingId, r.stage);
//
//     final ctrl = r.sliderController as ActionSliderController?;
//     ctrl?.reset();
//
//     final dest =
//         r.stage == SharedRiderStage.waitingPickup
//             ? r.pickupLatLng
//             : r.dropLatLng;
//
//     sharedController.pickupDistanceInMeters.value = 0;
//     sharedController.pickupDurationInMin.value = 0;
//     sharedController.dropDistanceInMeters.value = 0;
//     sharedController.dropDurationInMin.value = 0;
//
//     await _routeController.updateDestination(dest);
//     _mapKey.currentState?.focusPickup();
//
//     if (mounted) setState(() {});
//   }
//
//   // ✅ FIX STUCK COMPLETE: set activeTarget to NEXT rider immediately + reset slider
//   Future<void> _onCurrentLegCompleted(SharedRiderItem completedRider) async {
//     final bool? cashCollected = await Navigator.push<bool>(
//       context,
//       MaterialPageRoute(
//         builder:
//             (_) => CashCollectedScreen(
//               name: completedRider.name,
//               imageUrl: completedRider.profilePic,
//               bookingId: completedRider.bookingId,
//               Amount: completedRider.amount,
//               isSharedRide: true,
//             ),
//       ),
//     );
//
//     if (cashCollected != true) return;
//
//     sharedRideController.markDropped(completedRider.bookingId);
//
//     try {
//       final doneCtrl =
//           completedRider.sliderController as ActionSliderController?;
//       doneCtrl?.reset();
//     } catch (_) {}
//
//     final next = sharedRideController.recomputeNextTarget();
//
//     if (next == null) {
//       if (!mounted) return;
//       Navigator.pushAndRemoveUntil(
//         context,
//         MaterialPageRoute(builder: (_) => const DriverMainScreen()),
//         (route) => false,
//       );
//       return;
//     }
//
//     // ✅ MUST update active target or UI will still bind old rider
//     sharedRideController.setActiveTarget(next.bookingId, next.stage);
//
//     final nextCtrl = next.sliderController as ActionSliderController?;
//     nextCtrl?.reset();
//
//     final dest =
//         next.stage == SharedRiderStage.waitingPickup
//             ? next.pickupLatLng
//             : next.dropLatLng;
//     await _routeController.updateDestination(dest);
//
//     if (mounted) setState(() {});
//   }
//
//   // -------------------- UI PIECES --------------------
//   Widget _buildEtaRow(SharedRiderItem active) {
//     final isPickupLeg = active.stage == SharedRiderStage.waitingPickup;
//
//     return Obx(() {
//       final minutes =
//           isPickupLeg
//               ? sharedController.pickupDurationInMin.value
//               : sharedController.dropDurationInMin.value;
//
//       final meters =
//           isPickupLeg
//               ? sharedController.pickupDistanceInMeters.value
//               : sharedController.dropDistanceInMeters.value;
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
//   Widget _buildActiveActionArea(SharedRiderItem active) {
//     // 1) Not arrived yet
//     if (active.stage == SharedRiderStage.waitingPickup && !active.arrived) {
//       return Padding(
//         padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
//         child: Buttons.button(
//           buttonColor: AppColors.resendBlue,
//           borderRadius: 8,
//           onTap: () async {
//             try {
//               final result = await driverStatusController.driverArrived(
//                 context,
//                 bookingId: active.bookingId,
//               );
//
//               if (result != null && result.status == 200) {
//                 sharedRideController.markArrived(active.bookingId);
//                 if (mounted) setState(() {});
//               } else {
//                 ScaffoldMessenger.of(context).showSnackBar(
//                   SnackBar(
//                     content: Text(result?.message ?? "Something went wrong"),
//                   ),
//                 );
//               }
//             } catch (_) {
//               ScaffoldMessenger.of(context).showSnackBar(
//                 const SnackBar(
//                   content: Text('Unable to mark as arrived, please retry'),
//                 ),
//               );
//             }
//           },
//           text: Text('Arrived at pickup for ${active.name}'),
//         ),
//       );
//     }
//
//     // 2) Arrived -> Swipe to Start Ride
//     if (active.stage == SharedRiderStage.waitingPickup && active.arrived) {
//       final riderCtrl = active.sliderController as ActionSliderController;
//
//       return Padding(
//         padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
//         child: ActionSlider.standard(
//           key: ValueKey(
//             'start-${active.bookingId}-${active.stage}-${active.arrived}',
//           ),
//           controller: riderCtrl,
//           height: 52,
//           backgroundColor: AppColors.drkGreen,
//           toggleColor: Colors.white,
//           icon: Icon(Icons.double_arrow, color: AppColors.drkGreen, size: 28),
//           child: Text(
//             'Swipe to Start Ride for ${active.name}',
//             style: const TextStyle(
//               color: Colors.white,
//               fontSize: 16,
//               fontWeight: FontWeight.w700,
//             ),
//           ),
//           action: (controller) async {
//             try {
//               controller.loading();
//
//               final msg = await driverStatusController.otpRequest(
//                 context,
//                 bookingId: active.bookingId,
//                 custName: active.name,
//                 pickupAddress: active.pickupAddress,
//                 dropAddress: active.dropoffAddress,
//               );
//
//               if (msg == null) {
//                 controller.failure();
//                 ScaffoldMessenger.of(context).showSnackBar(
//                   const SnackBar(content: Text('Failed to send OTP')),
//                 );
//                 await Future.delayed(const Duration(milliseconds: 700));
//                 controller.reset();
//                 return;
//               }
//
//               final verified = await Navigator.push<bool>(
//                 context,
//                 MaterialPageRoute(
//                   builder:
//                       (_) => VerifyRiderScreen(
//                         bookingId: active.bookingId,
//                         custName: active.name,
//                         pickupAddress: active.pickupAddress,
//                         dropAddress: active.dropoffAddress,
//                         isSharedRide: true,
//                       ),
//                 ),
//               );
//
//               if (verified == true) {
//                 controller.success();
//                 sharedRideController.markOnboard(active.bookingId);
//
//                 // after onboarding -> route to drop leg
//                 await _setAsNextStop(active);
//               } else {
//                 controller.reset();
//               }
//             } catch (_) {
//               controller.failure();
//               ScaffoldMessenger.of(context).showSnackBar(
//                 const SnackBar(
//                   content: Text('Something went wrong, please try again'),
//                 ),
//               );
//               await Future.delayed(const Duration(milliseconds: 700));
//               controller.reset();
//             }
//           },
//         ),
//       );
//     }
//
//     // 3) Onboard -> Complete stop
//     if (active.stage == SharedRiderStage.onboardDrop) {
//       final riderSlider = active.sliderController as ActionSliderController;
//
//       return Padding(
//         padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
//         child: ActionSlider.standard(
//           key: ValueKey('complete-${active.bookingId}-${active.stage}'),
//           controller: riderSlider,
//           height: 52,
//           backgroundColor: AppColors.drkGreen,
//           toggleColor: Colors.white,
//           icon: Icon(Icons.double_arrow, color: AppColors.drkGreen, size: 28),
//           child: const Text(
//             'Complete Current Stop',
//             style: TextStyle(
//               color: Colors.white,
//               fontSize: 16,
//               fontWeight: FontWeight.w700,
//             ),
//           ),
//           action: (controller) async {
//             try {
//               controller.loading();
//               await Future.delayed(const Duration(milliseconds: 200));
//
//               final msg = await driverStatusController.completeRideRequest(
//                 context,
//                 Amount: active.amount,
//                 bookingId: active.bookingId,
//                 navigateToCashScreen: false,
//                 isSharedRide: true,
//               );
//
//               if (msg != null) {
//                 controller.success();
//                 await _onCurrentLegCompleted(active);
//               } else {
//                 controller.failure();
//                 ScaffoldMessenger.of(context).showSnackBar(
//                   const SnackBar(content: Text('Failed to complete stop')),
//                 );
//                 await Future.delayed(const Duration(milliseconds: 700));
//                 controller.reset();
//               }
//             } catch (_) {
//               controller.failure();
//               ScaffoldMessenger.of(context).showSnackBar(
//                 const SnackBar(
//                   content: Text('Something went wrong, please try again'),
//                 ),
//               );
//               await Future.delayed(const Duration(milliseconds: 700));
//               controller.reset();
//             }
//           },
//         ),
//       );
//     }
//
//     return const SizedBox.shrink();
//   }
//
//   Widget _buildRiderRow(SharedRiderItem r) {
//     final active = sharedRideController.activeTarget.value;
//     final isActive = active?.bookingId == r.bookingId;
//     final isDropped = r.stage == SharedRiderStage.dropped;
//     final isExpanded = _expandedCards.contains(r.bookingId);
//
//     String stageLabel;
//     switch (r.stage) {
//       case SharedRiderStage.waitingPickup:
//         stageLabel = 'Pending pickup';
//         break;
//       case SharedRiderStage.onboardDrop:
//         stageLabel = 'In car – drop pending';
//         break;
//       case SharedRiderStage.dropped:
//         stageLabel = 'Dropped';
//         break;
//     }
//
//     void toggleExpanded() {
//       setState(() {
//         if (isExpanded) {
//           _expandedCards.remove(r.bookingId);
//         } else {
//           _expandedCards.add(r.bookingId);
//         }
//       });
//     }
//
//     return Opacity(
//       opacity: isDropped ? 0.4 : 1,
//       child: Container(
//         margin: const EdgeInsets.symmetric(vertical: 6),
//         padding: const EdgeInsets.all(10),
//         decoration: BoxDecoration(
//           color:
//               isActive
//                   ? AppColors.containerColor1.withOpacity(0.1)
//                   : Colors.white,
//           borderRadius: BorderRadius.circular(10),
//           border: Border.all(
//             color:
//                 isActive ? AppColors.resendBlue : Colors.grey.withOpacity(0.25),
//           ),
//         ),
//         child: Row(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             ClipOval(
//               child: CachedNetworkImage(
//                 imageUrl: r.profilePic,
//                 height: 40,
//                 width: 40,
//                 fit: BoxFit.cover,
//                 placeholder:
//                     (c, u) => const SizedBox(
//                       height: 30,
//                       width: 30,
//                       child: CircularProgressIndicator(strokeWidth: 2),
//                     ),
//                 errorWidget: (c, u, e) => const Icon(Icons.person, size: 30),
//               ),
//             ),
//             const SizedBox(width: 10),
//             Expanded(
//               child: InkWell(
//                 onTap: toggleExpanded,
//                 borderRadius: BorderRadius.circular(8),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Row(
//                       children: [
//                         Expanded(
//                           child: CustomTextfield.textWithStyles600(
//                             r.name,
//                             fontSize: 15,
//                           ),
//                         ),
//                         const SizedBox(width: 6),
//                         Text(
//                           '#${r.bookingId}',
//                           style: TextStyle(
//                             fontSize: 10,
//                             color: AppColors.textColorGrey,
//                           ),
//                         ),
//                         const SizedBox(width: 4),
//                         AnimatedRotation(
//                           turns: isExpanded ? 0.5 : 0.0,
//                           duration: const Duration(milliseconds: 200),
//                           child: Icon(
//                             Icons.keyboard_arrow_down_rounded,
//                             size: 20,
//                             color: AppColors.textColorGrey,
//                           ),
//                         ),
//                       ],
//                     ),
//                     const SizedBox(height: 2),
//                     CustomTextfield.textWithStylesSmall(
//                       stageLabel,
//                       colors: AppColors.textColorGrey,
//                       fontSize: 12,
//                     ),
//                     AnimatedCrossFade(
//                       duration: const Duration(milliseconds: 220),
//                       crossFadeState:
//                           isExpanded
//                               ? CrossFadeState.showSecond
//                               : CrossFadeState.showFirst,
//                       firstChild: const SizedBox(height: 0),
//                       secondChild: Padding(
//                         padding: const EdgeInsets.only(top: 6),
//                         child: Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             CustomTextfield.textWithStylesSmall(
//                               'Pickup: ${r.pickupAddress}',
//                               colors: AppColors.textColorGrey,
//                               maxLine: 3,
//                               fontSize: 11,
//                             ),
//                             const SizedBox(height: 2),
//                             CustomTextfield.textWithStylesSmall(
//                               'Drop: ${r.dropoffAddress}',
//                               colors: AppColors.textColorGrey,
//                               maxLine: 3,
//                               fontSize: 11,
//                             ),
//                           ],
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//             const SizedBox(width: 8),
//             if (!isDropped)
//               TextButton(
//                 onPressed: () => _setAsNextStop(r),
//                 child: Text(
//                   isActive ? 'Current' : 'Set as Next',
//                   style: TextStyle(
//                     fontSize: 12,
//                     color: isActive ? AppColors.drkGreen : AppColors.resendBlue,
//                   ),
//                 ),
//               ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final active = sharedRideController.activeTarget.value;
//
//     final driverPos = _animatedDriverPos ?? widget.driverLocation;
//
//     final markers = <Marker>{
//       Marker(
//         markerId: const MarkerId('driver'),
//         position: driverPos,
//         icon: carIcon ?? BitmapDescriptor.defaultMarker,
//         // ✅ correct rotation + smooth interpolation
//         rotation: _animatedBearing,
//         anchor: const Offset(0.5, 0.5),
//         flat: true,
//         zIndex: 999,
//       ),
//       if (active != null)
//         Marker(
//           markerId: const MarkerId('target'),
//           position:
//               active.stage == SharedRiderStage.waitingPickup
//                   ? active.pickupLatLng
//                   : active.dropLatLng,
//           infoWindow: InfoWindow(
//             title:
//                 active.stage == SharedRiderStage.waitingPickup
//                     ? 'Pickup ${active.name}'
//                     : 'Drop ${active.name}',
//           ),
//         ),
//     };
//
//     return NoInternetOverlay(
//       child: WillPopScope(
//         onWillPop: () async => false,
//         child: Scaffold(
//           body: Stack(
//             children: [
//               SizedBox(
//                 height: 550,
//                 width: double.infinity,
//                 child: SharedMap(
//                   key: _mapKey,
//                   followDriver: true,
//                   followZoom: 17,
//                   followTilt: 45,
//                   initialPosition: widget.pickupLocation,
//                   pickupPosition: driverPos,
//                   markers: markers,
//                   polylines: {
//                     if (polylinePoints.length >= 2)
//                       Polyline(
//                         polylineId: const PolylineId("route"),
//                         color: AppColors.commonBlack,
//                         width: 5,
//                         points: polylinePoints,
//                       ),
//                   },
//                   myLocationEnabled: true,
//                   fitToBounds: true,
//                 ),
//               ),
//
//               // focus driver / fit bounds
//               Positioned(
//                 top: 350,
//                 right: 10,
//                 child: SafeArea(
//                   child: GestureDetector(
//                     onTap: () {
//                       final mapState = _mapKey.currentState;
//                       if (mapState == null) return;
//
//                       if (_isDriverFocused) {
//                         mapState.fitRouteBounds();
//                       } else {
//                         mapState.focusPickup();
//                       }
//
//                       setState(() => _isDriverFocused = !_isDriverFocused);
//                     },
//                     child: Container(
//                       height: 42,
//                       width: 42,
//                       decoration: BoxDecoration(
//                         color: Colors.white,
//                         borderRadius: BorderRadius.circular(10),
//                         boxShadow: const [
//                           BoxShadow(
//                             color: Colors.black12,
//                             blurRadius: 8,
//                             offset: Offset(0, 3),
//                           ),
//                         ],
//                         border: Border.all(
//                           color: Colors.black.withOpacity(0.05),
//                         ),
//                       ),
//                       child: Icon(
//                         _isDriverFocused
//                             ? Icons.crop_square_rounded
//                             : Icons.my_location,
//                         size: 22,
//                         color: Colors.black87,
//                       ),
//                     ),
//                   ),
//                 ),
//               ),
//
//               // Direction card
//               Positioned(
//                 top: 45,
//                 left: 10,
//                 right: 10,
//                 child: Row(
//                   children: [
//                     Expanded(
//                       flex: 1,
//                       child: Container(
//                         height: 100,
//                         color: AppColors.directionColor,
//                         child: Padding(
//                           padding: const EdgeInsets.symmetric(
//                             vertical: 20,
//                             horizontal: 10,
//                           ),
//                           child: Column(
//                             crossAxisAlignment: CrossAxisAlignment.center,
//                             children: [
//                               Image.asset(
//                                 getManeuverIcon(maneuver),
//                                 height: 32,
//                                 width: 32,
//                               ),
//                               const SizedBox(height: 5),
//                               CustomTextfield.textWithStyles600(
//                                 distance,
//                                 color: AppColors.commonWhite,
//                               ),
//                             ],
//                           ),
//                         ),
//                       ),
//                     ),
//                     Expanded(
//                       flex: 3,
//                       child: Container(
//                         height: 100,
//                         color: AppColors.directionColor1,
//                         child: Padding(
//                           padding: const EdgeInsets.symmetric(
//                             vertical: 20,
//                             horizontal: 10,
//                           ),
//                           child: Column(
//                             mainAxisAlignment: MainAxisAlignment.center,
//                             children: [
//                               CustomTextfield.textWithStyles600(
//                                 directionText,
//                                 maxLine: 2,
//                                 fontSize: 13,
//                                 color: AppColors.commonWhite,
//                               ),
//                             ],
//                           ),
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//
//               // Bottom sheet
//               DraggableScrollableSheet(
//                 initialChildSize: 0.70,
//                 minChildSize: 0.40,
//                 maxChildSize: 0.85,
//                 builder: (context, scrollController) {
//                   return Container(
//                     color: Colors.white,
//                     child: Obx(() {
//                       final active = sharedRideController.activeTarget.value;
//
//                       return ListView(
//                         controller: scrollController,
//                         physics: const BouncingScrollPhysics(),
//                         children: [
//                           const SizedBox(height: 6),
//                           Center(
//                             child: Container(
//                               width: 60,
//                               height: 5,
//                               decoration: BoxDecoration(
//                                 color: Colors.grey[400],
//                                 borderRadius: BorderRadius.circular(10),
//                               ),
//                             ),
//                           ),
//                           const SizedBox(height: 20),
//
//                           if (!driverCompletedRide && active != null) ...[
//                             Container(
//                               color: AppColors.rideInProgress.withOpacity(0.1),
//                               padding: const EdgeInsets.all(15),
//                               child: Column(
//                                 crossAxisAlignment: CrossAxisAlignment.start,
//                                 children: [
//                                   CustomTextfield.textWithStyles600(
//                                     active.stage ==
//                                             SharedRiderStage.waitingPickup
//                                         ? 'Heading to pick up ${active.name}'
//                                         : 'Ride in Progress – Dropping ${active.name}',
//                                     color: AppColors.rideInProgress,
//                                     fontSize: 14,
//                                   ),
//                                   const SizedBox(height: 6),
//                                   Text(
//                                     'Booking ID: #${active.bookingId}',
//                                     style: TextStyle(
//                                       fontSize: 11,
//                                       color: AppColors.textColorGrey,
//                                     ),
//                                   ),
//                                   const SizedBox(height: 6),
//                                   Text(
//                                     'Pickup: ${active.pickupAddress}',
//                                     style: const TextStyle(
//                                       fontSize: 12,
//                                       color: AppColors.commonBlack,
//                                     ),
//                                   ),
//                                   const SizedBox(height: 4),
//                                   Text(
//                                     'Drop: ${active.dropoffAddress}',
//                                     style: const TextStyle(
//                                       fontSize: 12,
//                                       color: AppColors.commonBlack,
//                                     ),
//                                   ),
//                                 ],
//                               ),
//                             ),
//                             const SizedBox(height: 16),
//                             _buildEtaRow(active),
//                             const SizedBox(height: 10),
//                             _buildActiveActionArea(active),
//                             const SizedBox(height: 10),
//                           ],
//
//                           const Padding(
//                             padding: EdgeInsets.symmetric(horizontal: 16),
//                             child: Text(
//                               'Next Stops',
//                               style: TextStyle(
//                                 fontSize: 16,
//                                 fontWeight: FontWeight.w600,
//                               ),
//                             ),
//                           ),
//                           const SizedBox(height: 8),
//
//                           if (sharedRideController.riders.isEmpty)
//                             const Padding(
//                               padding: EdgeInsets.all(20),
//                               child: Text('No riders in this shared trip'),
//                             )
//                           else
//                             Padding(
//                               padding: const EdgeInsets.symmetric(
//                                 horizontal: 16,
//                               ),
//                               child: Column(
//                                 children:
//                                     sharedRideController.riders
//                                         .map(_buildRiderRow)
//                                         .toList(),
//                               ),
//                             ),
//
//                           const SizedBox(height: 20),
//
//                           Padding(
//                             padding: const EdgeInsets.symmetric(
//                               horizontal: 20,
//                               vertical: 12,
//                             ),
//                             child: Column(
//                               crossAxisAlignment: CrossAxisAlignment.start,
//                               children: [
//                                 Obx(() {
//                                   final stopped =
//                                       driverStatusController
//                                           .isStopNewRequests
//                                           .value;
//
//                                   return Buttons.button(
//                                     borderColor: AppColors.buttonBorder,
//                                     buttonColor:
//                                         stopped
//                                             ? AppColors.containerColor
//                                             : AppColors.commonWhite,
//                                     borderRadius: 8,
//                                     textColor: AppColors.commonBlack,
//                                     onTap:
//                                         stopped
//                                             ? null
//                                             : () => Buttons.showDialogBox(
//                                               context: context,
//                                               onConfirmStop: () async {
//                                                 await driverStatusController
//                                                     .stopNewRideRequest(
//                                                       context: context,
//                                                       stop: true,
//                                                     );
//                                               },
//                                             ),
//                                     text: Text(
//                                       stopped
//                                           ? 'Already Stopped'
//                                           : 'Stop New Ride Requests',
//                                     ),
//                                   );
//                                 }),
//                                 const SizedBox(height: 10),
//
//                                 Buttons.button(
//                                   borderRadius: 8,
//                                   buttonColor: AppColors.red,
//                                   onTap: () {
//                                     Buttons.showCancelRideBottomSheet(
//                                       context,
//                                       onConfirmCancel: (reason) async {
//                                         if (Get.isBottomSheetOpen == true)
//                                           Get.back();
//
//                                         await driverStatusController
//                                             .cancelBooking(
//                                               context,
//                                               bookingId: widget.bookingId,
//                                               reason: reason,
//                                               silent: true,
//                                               navigate: true,
//                                             );
//                                       },
//                                     );
//                                   },
//                                   text: const Text('Cancel this Shared Ride'),
//                                 ),
//                                 const SizedBox(height: 20),
//                               ],
//                             ),
//                           ),
//                         ],
//                       );
//                     }),
//                   );
//                 },
//               ),
//
//               const BookingOverlayRequest(isSharedFlow: true),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }

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
// import 'package:hopper/Core/Constants/Colors.dart';
// import 'package:hopper/Core/Constants/log.dart';
// import 'package:hopper/Core/Utility/Buttons.dart';
// import 'package:hopper/Core/Utility/images.dart';
// import 'package:hopper/Presentation/Authentication/widgets/textFields.dart';
// import 'package:hopper/Presentation/DriverScreen/controller/driver_status_controller.dart';
// import 'package:hopper/Presentation/DriverScreen/screens/SharedBooking/Controller/shared_controller.dart';
// import 'package:hopper/Presentation/DriverScreen/screens/SharedBooking/Controller/shared_ride_controller.dart';
// import 'package:hopper/Presentation/DriverScreen/screens/SharedBooking/Screens/booking_overlay_request.dart';
// import 'package:hopper/Presentation/DriverScreen/screens/cash_collected_screen.dart';
// import 'package:hopper/Presentation/DriverScreen/screens/driver_main_screen.dart';
// import 'package:hopper/Presentation/DriverScreen/screens/verify_rider_screen.dart';
// import 'package:hopper/utils/map/driver_route.dart';
// import 'package:hopper/utils/map/shared_map.dart';
// import 'package:hopper/utils/netWorkHandling/network_handling_screen.dart';
// import '../../../../../utils/websocket/socket_io_client.dart';
// import '../Controller/booking_request_controller.dart';
//
// class ShareRideStartScreen extends StatefulWidget {
//   final String bookingId; // pool / main booking
//   final LatLng pickupLocation;
//   final LatLng driverLocation;
//
//   const ShareRideStartScreen({
//     Key? key,
//     required this.pickupLocation,
//     required this.driverLocation,
//     required this.bookingId,
//   }) : super(key: key);
//
//   @override
//   State<ShareRideStartScreen> createState() => _ShareRideStartScreenState();
// }
//
// class _ShareRideStartScreenState extends State<ShareRideStartScreen>
//     with SingleTickerProviderStateMixin {
//   late final DriverRouteController _routeController;
//
//   final SharedController sharedController = Get.put(SharedController());
//   final DriverStatusController driverStatusController = Get.put(
//     DriverStatusController(),
//   );
//   final BookingRequestController bookingController =
//       Get.find<BookingRequestController>();
//   final SharedRideController sharedRideController =
//       Get.find<SharedRideController>();
//
//   final GlobalKey<SharedMapState> _mapKey = GlobalKey<SharedMapState>();
//
//   LatLng? driverLocation;
//   double carBearing = 0.0;
//   List<LatLng> polylinePoints = [];
//   String directionText = '';
//   String distance = '';
//   String maneuver = '';
//
//   BitmapDescriptor? carIcon;
//   late SocketService socketService;
//
//   bool driverCompletedRide = false;
//   bool _isDriverFocused = false;
//
//   late final AnimationController _pulseController;
//   late final Animation<double> _pulseAnimation;
//
//   DateTime? _lastRouteUpdate;
//   final Set<String> _expandedCards = <String>{};
//
//   bool _leavingScreen = false;
//
//   Future<void> _exitToHomeSafely() async {
//     if (_leavingScreen) return;
//     _leavingScreen = true;
//
//     try {
//       Get.closeAllSnackbars();
//     } catch (_) {}
//     try {
//       if (Get.isBottomSheetOpen == true) Get.back();
//     } catch (_) {}
//     try {
//       if (Get.isDialogOpen == true) Get.back();
//     } catch (_) {}
//
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       if (!mounted) return;
//       if (Get.currentRoute == '/DriverMainScreen') return;
//       Get.offAll(() => const DriverMainScreen());
//     });
//   }
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
//
//     final initialTarget = sharedRideController.activeTarget.value;
//     final initialDestination =
//         initialTarget == null
//             ? widget.pickupLocation
//             : (initialTarget.stage == SharedRiderStage.waitingPickup
//                 ? initialTarget.pickupLatLng
//                 : initialTarget.dropLatLng);
//
//     _routeController = DriverRouteController(
//       destination: initialDestination,
//       onRouteUpdate: (update) {
//         final now = DateTime.now();
//         if (_lastRouteUpdate != null) {
//           final diff = now.difference(_lastRouteUpdate!).inMilliseconds;
//           if (diff < 300) return;
//         }
//         _lastRouteUpdate = now;
//
//         if (!mounted) return;
//         setState(() {
//           driverLocation = update.driverLocation;
//           carBearing = update.bearing;
//           polylinePoints = update.polylinePoints;
//           directionText = update.directionText;
//           distance = update.distanceText;
//           maneuver = update.maneuver;
//         });
//
//         sharedRideController.updateDriverLocation(update.driverLocation);
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
//     _routeController.dispose();
//     _pulseController.dispose();
//
//     try {
//       socketService.socket.off('driver-reached-destination');
//       socketService.socket.off('driver-location');
//       socketService.socket.off('driver-cancelled');
//       socketService.socket.off('customer-cancelled');
//       socketService.socket.off('joined-booking');
//       socketService.socket.off('booking-request');
//       socketService.socket.onAny((event, data) {});
//     } catch (_) {}
//
//     super.dispose();
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
//   double? _safeNum(dynamic v) {
//     if (v == null) return null;
//     try {
//       return (v as num).toDouble();
//     } catch (_) {
//       return null;
//     }
//   }
//
//   Future<void> _initSocket() async {
//     socketService = SocketService();
//
//     // 1) Driver reached destination
//     socketService.on('driver-reached-destination', (data) {
//       final status = data?['status'];
//       if (status == true || status?.toString() == 'true') {
//         if (!mounted) return;
//         setState(() => driverCompletedRide = true);
//         CommonLogger.log.i('✅ Driver reached destination');
//       }
//     });
//
//     // 2) joined-booking
//     socketService.on('joined-booking', (data) async {
//       try {
//         CommonLogger.log.i("[SHARED START] joined-booking → $data");
//
//         if (!mounted || data == null) return;
//
//         final customerLoc = data['customerLocation'];
//         if (customerLoc == null) {
//           CommonLogger.log.w(
//             '[SHARED START] joined-booking missing customerLocation',
//           );
//           return;
//         }
//
//         final fromLat = _safeNum(
//           customerLoc['fromLatitude'] ?? customerLoc['latitude'],
//         );
//         final fromLng = _safeNum(
//           customerLoc['fromLongitude'] ?? customerLoc['longitude'],
//         );
//         final toLat = _safeNum(
//           customerLoc['toLatitude'] ?? customerLoc['toLat'],
//         );
//         final toLng = _safeNum(
//           customerLoc['toLongitude'] ?? customerLoc['toLng'],
//         );
//
//         if (fromLat == null ||
//             fromLng == null ||
//             toLat == null ||
//             toLng == null) {
//           CommonLogger.log.w(
//             '[SHARED START] joined-booking missing lat/lng values → $customerLoc',
//           );
//           return;
//         }
//
//         final String pickupAddrs = await getAddressFromLatLng(fromLat, fromLng);
//         final String dropoffAddrs = await getAddressFromLatLng(toLat, toLng);
//
//         final String bookingIdStr = data['bookingId']?.toString() ?? '';
//         if (bookingIdStr.isEmpty) {
//           CommonLogger.log.w(
//             '[SHARED START] joined-booking missing bookingId → $data',
//           );
//           return;
//         }
//
//         final riders = sharedRideController.riders;
//         final existingIndex = riders.indexWhere(
//           (r) => r.bookingId.toString() == bookingIdStr,
//         );
//
//         if (existingIndex == -1) {
//           final newItem = SharedRiderItem(
//             bookingId: bookingIdStr,
//             name: data['customerName']?.toString() ?? 'Rider',
//             phone: data['customerPhone']?.toString() ?? '',
//             profilePic:
//                 data['customerProfilePic']?.toString() ??
//                 data['profilePic']?.toString() ??
//                 '',
//             pickupAddress: pickupAddrs,
//             dropoffAddress: dropoffAddrs,
//             amount: (data['amount'] as num?) ?? 0,
//             pickupLatLng: LatLng(fromLat, fromLng),
//             dropLatLng: LatLng(toLat, toLng),
//             arrived: false,
//             secondsLeft: 0,
//             sliderController: ActionSliderController(), // ✅ per rider
//             stage: SharedRiderStage.waitingPickup,
//           );
//           riders.add(newItem);
//         } else {
//           // ✅ preserve controller/state
//           final old = riders[existingIndex];
//
//           riders[existingIndex] = SharedRiderItem(
//             bookingId: bookingIdStr,
//             name: data['customerName']?.toString() ?? old.name,
//             phone: data['customerPhone']?.toString() ?? old.phone,
//             profilePic:
//                 data['customerProfilePic']?.toString() ??
//                 data['profilePic']?.toString() ??
//                 old.profilePic,
//             pickupAddress: pickupAddrs,
//             dropoffAddress: dropoffAddrs,
//             amount: (data['amount'] as num?) ?? old.amount,
//             pickupLatLng: LatLng(fromLat, fromLng),
//             dropLatLng: LatLng(toLat, toLng),
//             arrived: old.arrived,
//             secondsLeft: old.secondsLeft,
//             stage: old.stage,
//             sliderController: old.sliderController, // ✅ keep
//           );
//         }
//
//         CommonLogger.log.i(
//           '[SHARED START] riders after join: ${riders.length}',
//         );
//
//         var active = sharedRideController.activeTarget.value;
//
//         if (active == null ||
//             active.bookingId.toString() == bookingIdStr ||
//             riders.length == 1) {
//           sharedRideController.setActiveTarget(
//             bookingIdStr,
//             SharedRiderStage.waitingPickup,
//           );
//           active = sharedRideController.activeTarget.value;
//         }
//
//         if (active != null) {
//           final dest =
//               active.stage == SharedRiderStage.waitingPickup
//                   ? active.pickupLatLng
//                   : active.dropLatLng;
//
//           sharedController.pickupDistanceInMeters.value = 0;
//           sharedController.pickupDurationInMin.value = 0;
//           sharedController.dropDistanceInMeters.value = 0;
//           sharedController.dropDurationInMin.value = 0;
//
//           await _routeController.updateDestination(dest);
//           _mapKey.currentState?.focusPickup();
//         }
//
//         if (mounted) setState(() {});
//       } catch (e, st) {
//         CommonLogger.log.e('[SHARED START] Error in joined-booking handler');
//         debugPrint('$e');
//         debugPrint('$st');
//       }
//     });
//
//     // 3) booking-request
//     socketService.on('booking-request', (data) async {
//       if (data == null) return;
//       CommonLogger.log.i('[SHARED START] 📦 Booking Request → $data');
//
//       final incomingId = data['bookingId']?.toString();
//
//       if (incomingId == widget.bookingId) {
//         CommonLogger.log.i(
//           '[SHARED START] Ignoring booking-request for current bookingId=$incomingId',
//         );
//         return;
//       }
//
//       if (incomingId != null &&
//           incomingId == bookingController.lastHandledBookingId.value) {
//         CommonLogger.log.i(
//           '[SHARED START] Ignoring already-handled bookingId=$incomingId',
//         );
//         return;
//       }
//
//       final pickup = data['pickupLocation'];
//       final drop = data['dropLocation'];
//
//       if (pickup == null || drop == null) {
//         CommonLogger.log.w(
//           '[SHARED START] pickup/drop missing in booking-request',
//         );
//         return;
//       }
//
//       final pickupAddr = await getAddressFromLatLng(
//         _safeNum(pickup['latitude']) ?? 0,
//         _safeNum(pickup['longitude']) ?? 0,
//       );
//       final dropAddr = await getAddressFromLatLng(
//         _safeNum(drop['latitude']) ?? 0,
//         _safeNum(drop['longitude']) ?? 0,
//       );
//
//       bookingController.showRequest(
//         rawData: data,
//         pickupAddress: pickupAddr,
//         dropAddress: dropAddr,
//       );
//     });
//
//     // 4) Cancel events (✅ safe exit)
//     socketService.on('driver-cancelled', (data) async {
//       if (data?['status'] == true) {
//         await _exitToHomeSafely();
//       }
//     });
//
//     socketService.on('customer-cancelled', (data) async {
//       if (data?['status'] == true) {
//         await _exitToHomeSafely();
//       }
//     });
//
//     // 5) Debug all events
//     socketService.socket.onAny((event, data) {
//       CommonLogger.log.i('💡 📦 [onAny] $event → $data');
//     });
//
//     // 6) Connect if needed
//     if (!socketService.connected) {
//       socketService.connect();
//       socketService.onConnect(
//         () => CommonLogger.log.i('🔌 [SHARED START] socket connected'),
//       );
//     } else {
//       CommonLogger.log.i(
//         '💡 [SHARED START] already connected → listeners attached',
//       );
//     }
//   }
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
//         return "assets/images/straight.png";
//     }
//   }
//
//   String _formatDistance(double meters) {
//     final km = meters / 1000.0;
//     if (meters <= 0) return '0 Km';
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
//   Future<void> _setAsNextStop(SharedRiderItem r) async {
//     final stage = r.stage;
//
//     sharedRideController.setActiveTarget(r.bookingId, stage);
//
//     final ctrl = r.sliderController as ActionSliderController?;
//     ctrl?.reset();
//
//     final dest =
//         stage == SharedRiderStage.waitingPickup ? r.pickupLatLng : r.dropLatLng;
//
//     sharedController.pickupDistanceInMeters.value = 0;
//     sharedController.pickupDurationInMin.value = 0;
//     sharedController.dropDistanceInMeters.value = 0;
//     sharedController.dropDurationInMin.value = 0;
//
//     await _routeController.updateDestination(dest);
//     _mapKey.currentState?.focusPickup();
//     if (mounted) setState(() {});
//   }
//
//   Future<void> _onCurrentLegCompleted(SharedRiderItem completedRider) async {
//     final bool? cashCollected = await Navigator.push<bool>(
//       context,
//       MaterialPageRoute(
//         builder:
//             (_) => CashCollectedScreen(
//               name: completedRider.name,
//               imageUrl: completedRider.profilePic,
//               bookingId: completedRider.bookingId,
//               Amount: completedRider.amount,
//               isSharedRide: true,
//             ),
//       ),
//     );
//
//     // user closed / not completed
//     if (cashCollected != true) return;
//
//     // 1) mark dropped
//     sharedRideController.markDropped(completedRider.bookingId);
//
//     // 2) next pending rider?
//     final next = sharedRideController.recomputeNextTarget();
//
//     if (next == null) {
//       // ✅ last customer finished → go main screen
//       if (!mounted) return;
//       Navigator.pushAndRemoveUntil(
//         context,
//         MaterialPageRoute(builder: (_) => const DriverMainScreen()),
//         (route) => false,
//       );
//       return;
//     }
//
//     // ✅ still pending → update destination
//     final dest =
//         next.stage == SharedRiderStage.waitingPickup
//             ? next.pickupLatLng
//             : next.dropLatLng;
//
//     final ctrl = next.sliderController as ActionSliderController?;
//     ctrl?.reset();
//
//     await _routeController.updateDestination(dest);
//
//     if (mounted) setState(() {});
//   }
//
//   Widget _buildEtaRow(SharedRiderItem active) {
//     final isPickupLeg = active.stage == SharedRiderStage.waitingPickup;
//
//     return Obx(() {
//       final minutes =
//           isPickupLeg
//               ? sharedController.pickupDurationInMin.value
//               : sharedController.dropDurationInMin.value;
//
//       final meters =
//           isPickupLeg
//               ? sharedController.pickupDistanceInMeters.value
//               : sharedController.dropDistanceInMeters.value;
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
//   Widget _buildActiveActionArea(SharedRiderItem active) {
//     // 1) Not arrived yet
//     if (active.stage == SharedRiderStage.waitingPickup && !active.arrived) {
//       return Padding(
//         padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
//         child: Buttons.button(
//           buttonColor: AppColors.resendBlue,
//           borderRadius: 8,
//           onTap: () async {
//             try {
//               final result = await driverStatusController.driverArrived(
//                 context,
//                 bookingId: active.bookingId,
//               );
//
//               if (result != null && result.status == 200) {
//                 sharedRideController.markArrived(active.bookingId);
//                 if (mounted) setState(() {});
//               } else {
//                 ScaffoldMessenger.of(context).showSnackBar(
//                   SnackBar(
//                     content: Text(result?.message ?? "Something went wrong"),
//                   ),
//                 );
//               }
//             } catch (_) {
//               ScaffoldMessenger.of(context).showSnackBar(
//                 const SnackBar(
//                   content: Text('Unable to mark as arrived, please retry'),
//                 ),
//               );
//             }
//           },
//           text: Text('Arrived at pickup for ${active.name}'),
//         ),
//       );
//     }
//
//     // 2) Arrived -> Swipe to Start Ride (✅ per-rider controller)
//     if (active.stage == SharedRiderStage.waitingPickup && active.arrived) {
//       final riderCtrl = active.sliderController as ActionSliderController;
//
//       return Padding(
//         padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
//         child: ActionSlider.standard(
//           controller: riderCtrl,
//           height: 50,
//           backgroundColor: AppColors.drkGreen,
//           toggleColor: Colors.white,
//           icon: Icon(Icons.double_arrow, color: AppColors.drkGreen, size: 28),
//           child: Text(
//             'Swipe to Start Ride for ${active.name}',
//             style: const TextStyle(
//               color: Colors.white,
//               fontSize: 18,
//               fontWeight: FontWeight.bold,
//             ),
//           ),
//           action: (controller) async {
//             try {
//               controller.loading();
//
//               final msg = await driverStatusController.otpRequest(
//                 context,
//                 bookingId: active.bookingId,
//                 custName: active.name,
//                 pickupAddress: active.pickupAddress,
//                 dropAddress: active.dropoffAddress,
//               );
//
//               if (msg == null) {
//                 controller.failure();
//                 ScaffoldMessenger.of(context).showSnackBar(
//                   const SnackBar(content: Text('Failed to send OTP')),
//                 );
//                 await Future.delayed(const Duration(milliseconds: 800));
//                 controller.reset();
//                 return;
//               }
//
//               final verified = await Navigator.push<bool>(
//                 context,
//                 MaterialPageRoute(
//                   builder:
//                       (_) => VerifyRiderScreen(
//                         bookingId: active.bookingId,
//                         custName: active.name,
//                         pickupAddress: active.pickupAddress,
//                         dropAddress: active.dropoffAddress,
//                         isSharedRide: true,
//                       ),
//                 ),
//               );
//
//               if (verified == true) {
//                 controller.success();
//                 sharedRideController.markOnboard(active.bookingId);
//                 await _setAsNextStop(active);
//               } else {
//                 controller.reset();
//               }
//             } catch (_) {
//               controller.failure();
//               ScaffoldMessenger.of(context).showSnackBar(
//                 const SnackBar(
//                   content: Text('Something went wrong, please try again'),
//                 ),
//               );
//               await Future.delayed(const Duration(milliseconds: 800));
//               controller.reset();
//             }
//           },
//         ),
//       );
//     }
//
//     // 3) Onboard -> Complete stop
//     if (active.stage == SharedRiderStage.onboardDrop) {
//       final riderSlider = active.sliderController as ActionSliderController;
//
//       return Padding(
//         padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
//         child: ActionSlider.standard(
//           controller: riderSlider,
//           height: 50,
//           backgroundColor: AppColors.drkGreen,
//           toggleColor: Colors.white,
//           icon: Icon(Icons.double_arrow, color: AppColors.drkGreen, size: 28),
//           child: const Text(
//             'Complete Current Stop',
//             style: TextStyle(
//               color: Colors.white,
//               fontSize: 18,
//               fontWeight: FontWeight.bold,
//             ),
//           ),
//           action: (controller) async {
//             try {
//               controller.loading();
//               await Future.delayed(const Duration(milliseconds: 300));
//
//               final msg = await driverStatusController.completeRideRequest(
//                 context,
//                 Amount: active.amount,
//                 bookingId: active.bookingId,
//                 navigateToCashScreen: false,
//                 isSharedRide: true,
//               );
//
//               if (msg != null) {
//                 controller.success();
//                 await _onCurrentLegCompleted(active);
//               } else {
//                 controller.failure();
//                 ScaffoldMessenger.of(context).showSnackBar(
//                   const SnackBar(content: Text('Failed to complete stop')),
//                 );
//                 await Future.delayed(const Duration(milliseconds: 800));
//                 controller.reset();
//               }
//             } catch (_) {
//               controller.failure();
//               ScaffoldMessenger.of(context).showSnackBar(
//                 const SnackBar(
//                   content: Text('Something went wrong, please try again'),
//                 ),
//               );
//               await Future.delayed(const Duration(milliseconds: 800));
//               controller.reset();
//             }
//           },
//         ),
//       );
//     }
//
//     return const SizedBox.shrink();
//   }
//
//   Widget _buildRiderRow(SharedRiderItem r) {
//     final active = sharedRideController.activeTarget.value;
//     final isActive = active?.bookingId == r.bookingId;
//     final isDropped = r.stage == SharedRiderStage.dropped;
//
//     final isExpanded = _expandedCards.contains(r.bookingId);
//
//     String stageLabel;
//     switch (r.stage) {
//       case SharedRiderStage.waitingPickup:
//         stageLabel = 'Pending pickup';
//         break;
//       case SharedRiderStage.onboardDrop:
//         stageLabel = 'In car – drop pending';
//         break;
//       case SharedRiderStage.dropped:
//         stageLabel = 'Dropped';
//         break;
//     }
//
//     void toggleExpanded() {
//       setState(() {
//         if (isExpanded) {
//           _expandedCards.remove(r.bookingId);
//         } else {
//           _expandedCards.add(r.bookingId);
//         }
//       });
//     }
//
//     return Opacity(
//       opacity: isDropped ? 0.4 : 1,
//       child: Container(
//         margin: const EdgeInsets.symmetric(vertical: 6),
//         padding: const EdgeInsets.all(10),
//         decoration: BoxDecoration(
//           color:
//               isActive
//                   ? AppColors.containerColor1.withOpacity(0.1)
//                   : Colors.white,
//           borderRadius: BorderRadius.circular(8),
//           border: Border.all(
//             color:
//                 isActive ? AppColors.resendBlue : Colors.grey.withOpacity(0.3),
//           ),
//         ),
//         child: Row(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             ClipOval(
//               child: CachedNetworkImage(
//                 imageUrl: r.profilePic,
//                 height: 40,
//                 width: 40,
//                 fit: BoxFit.cover,
//                 placeholder:
//                     (c, u) => const SizedBox(
//                       height: 30,
//                       width: 30,
//                       child: CircularProgressIndicator(strokeWidth: 2),
//                     ),
//                 errorWidget: (c, u, e) => const Icon(Icons.person, size: 30),
//               ),
//             ),
//             const SizedBox(width: 10),
//             Expanded(
//               child: InkWell(
//                 onTap: toggleExpanded,
//                 borderRadius: BorderRadius.circular(6),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Row(
//                       crossAxisAlignment: CrossAxisAlignment.center,
//                       children: [
//                         Expanded(
//                           child: CustomTextfield.textWithStyles600(
//                             r.name,
//                             fontSize: 15,
//                           ),
//                         ),
//                         const SizedBox(width: 6),
//                         Text(
//                           '#${r.bookingId}',
//                           style: TextStyle(
//                             fontSize: 10,
//                             color: AppColors.textColorGrey,
//                           ),
//                         ),
//                         const SizedBox(width: 4),
//                         GestureDetector(
//                           onTap: toggleExpanded,
//                           child: AnimatedRotation(
//                             turns: isExpanded ? 0.5 : 0.0,
//                             duration: const Duration(milliseconds: 200),
//                             child: Icon(
//                               Icons.keyboard_arrow_down_rounded,
//                               size: 20,
//                               color: AppColors.textColorGrey,
//                             ),
//                           ),
//                         ),
//                       ],
//                     ),
//                     const SizedBox(height: 2),
//                     CustomTextfield.textWithStylesSmall(
//                       stageLabel,
//                       colors: AppColors.textColorGrey,
//                       fontSize: 12,
//                     ),
//                     const SizedBox(height: 4),
//                     AnimatedCrossFade(
//                       duration: const Duration(milliseconds: 220),
//                       crossFadeState:
//                           isExpanded
//                               ? CrossFadeState.showSecond
//                               : CrossFadeState.showFirst,
//                       firstChild: const SizedBox.shrink(),
//                       secondChild: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           CustomTextfield.textWithStylesSmall(
//                             'Pickup: ${r.pickupAddress}',
//                             colors: AppColors.textColorGrey,
//                             maxLine: 3,
//                             fontSize: 11,
//                           ),
//                           const SizedBox(height: 2),
//                           CustomTextfield.textWithStylesSmall(
//                             'Drop: ${r.dropoffAddress}',
//                             colors: AppColors.textColorGrey,
//                             maxLine: 3,
//                             fontSize: 11,
//                           ),
//                         ],
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//             const SizedBox(width: 8),
//             if (!isDropped)
//               TextButton(
//                 onPressed: () => _setAsNextStop(r),
//                 child: Text(
//                   isActive ? 'Current' : 'Set as Next',
//                   style: TextStyle(
//                     fontSize: 12,
//                     color: isActive ? AppColors.drkGreen : AppColors.resendBlue,
//                   ),
//                 ),
//               ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final active = sharedRideController.activeTarget.value;
//
//     final markers = <Marker>{
//       Marker(
//         markerId: const MarkerId('driver'),
//         position: driverLocation ?? widget.driverLocation,
//         icon: carIcon ?? BitmapDescriptor.defaultMarker,
//         rotation: carBearing,
//         anchor: const Offset(0.5, 0.5),
//         flat: true,
//       ),
//       if (active != null)
//         Marker(
//           markerId: const MarkerId('target'),
//           position:
//               active.stage == SharedRiderStage.waitingPickup
//                   ? active.pickupLatLng
//                   : active.dropLatLng,
//           infoWindow: InfoWindow(
//             title:
//                 active.stage == SharedRiderStage.waitingPickup
//                     ? 'Pickup ${active.name}'
//                     : 'Drop ${active.name}',
//           ),
//         ),
//     };
//
//     return NoInternetOverlay(
//       child: WillPopScope(
//         onWillPop: () async => false,
//         child: Scaffold(
//           body: Stack(
//             children: [
//               SizedBox(
//                 height: 550,
//                 width: double.infinity,
//                 child: SharedMap(
//                   key: _mapKey,
//                   initialPosition: widget.pickupLocation,
//                   pickupPosition: driverLocation ?? widget.driverLocation,
//                   markers: markers,
//                   polylines: {
//                     if (polylinePoints.length >= 2)
//                       Polyline(
//                         polylineId: const PolylineId("route"),
//                         color: AppColors.commonBlack,
//                         width: 5,
//                         points: polylinePoints,
//                       ),
//                   },
//                   myLocationEnabled: true,
//                   fitToBounds: true,
//                 ),
//               ),
//
//               // focus driver / fit bounds
//               Positioned(
//                 top: 350,
//                 right: 10,
//                 child: SafeArea(
//                   child: GestureDetector(
//                     onTap: () {
//                       final mapState = _mapKey.currentState;
//                       if (mapState == null) return;
//
//                       if (_isDriverFocused) {
//                         mapState.fitRouteBounds();
//                       } else {
//                         mapState.focusPickup();
//                       }
//
//                       setState(() => _isDriverFocused = !_isDriverFocused);
//                     },
//                     child: Container(
//                       height: 42,
//                       width: 42,
//                       decoration: BoxDecoration(
//                         color: Colors.white,
//                         borderRadius: BorderRadius.circular(10),
//                         boxShadow: const [
//                           BoxShadow(
//                             color: Colors.black12,
//                             blurRadius: 8,
//                             offset: Offset(0, 3),
//                           ),
//                         ],
//                         border: Border.all(
//                           color: Colors.black.withOpacity(0.05),
//                         ),
//                       ),
//                       child: Icon(
//                         _isDriverFocused
//                             ? Icons.crop_square_rounded
//                             : Icons.my_location,
//                         size: 22,
//                         color: Colors.black87,
//                       ),
//                     ),
//                   ),
//                 ),
//               ),
//
//               // Direction card
//               Positioned(
//                 top: 45,
//                 left: 10,
//                 right: 10,
//                 child: Row(
//                   children: [
//                     Expanded(
//                       flex: 1,
//                       child: Container(
//                         height: 100,
//                         color: AppColors.directionColor,
//                         child: Padding(
//                           padding: const EdgeInsets.symmetric(
//                             vertical: 20,
//                             horizontal: 10,
//                           ),
//                           child: Column(
//                             crossAxisAlignment: CrossAxisAlignment.center,
//                             children: [
//                               Image.asset(
//                                 getManeuverIcon(maneuver),
//                                 height: 32,
//                                 width: 32,
//                               ),
//                               const SizedBox(height: 5),
//                               CustomTextfield.textWithStyles600(
//                                 distance,
//                                 color: AppColors.commonWhite,
//                               ),
//                             ],
//                           ),
//                         ),
//                       ),
//                     ),
//                     Expanded(
//                       flex: 3,
//                       child: Container(
//                         height: 100,
//                         color: AppColors.directionColor1,
//                         child: Padding(
//                           padding: const EdgeInsets.symmetric(
//                             vertical: 20,
//                             horizontal: 10,
//                           ),
//                           child: Column(
//                             crossAxisAlignment: CrossAxisAlignment.center,
//                             mainAxisAlignment: MainAxisAlignment.center,
//                             children: [
//                               CustomTextfield.textWithStyles600(
//                                 maxLine: 2,
//                                 directionText,
//                                 fontSize: 13,
//                                 color: AppColors.commonWhite,
//                               ),
//                             ],
//                           ),
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//
//               // Bottom sheet
//               DraggableScrollableSheet(
//                 initialChildSize: 0.70,
//                 minChildSize: 0.40,
//                 maxChildSize: 0.85,
//                 builder: (context, scrollController) {
//                   return Container(
//                     color: Colors.white,
//                     child: Obx(() {
//                       final active = sharedRideController.activeTarget.value;
//
//                       return ListView(
//                         controller: scrollController,
//                         physics: const BouncingScrollPhysics(),
//                         children: [
//                           const SizedBox(height: 6),
//                           Center(
//                             child: Container(
//                               width: 60,
//                               height: 5,
//                               decoration: BoxDecoration(
//                                 color: Colors.grey[400],
//                                 borderRadius: BorderRadius.circular(10),
//                               ),
//                             ),
//                           ),
//                           const SizedBox(height: 20),
//
//                           if (!driverCompletedRide && active != null) ...[
//                             Container(
//                               color: AppColors.rideInProgress.withOpacity(0.1),
//                               padding: const EdgeInsets.all(15),
//                               child: Column(
//                                 crossAxisAlignment: CrossAxisAlignment.start,
//                                 children: [
//                                   CustomTextfield.textWithStyles600(
//                                     active.stage ==
//                                             SharedRiderStage.waitingPickup
//                                         ? 'Heading to pick up ${active.name}'
//                                         : 'Ride in Progress – Dropping ${active.name}',
//                                     color: AppColors.rideInProgress,
//                                     fontSize: 14,
//                                   ),
//                                   const SizedBox(height: 6),
//                                   Text(
//                                     'Booking ID: #${active.bookingId}',
//                                     style: TextStyle(
//                                       fontSize: 11,
//                                       color: AppColors.textColorGrey,
//                                     ),
//                                   ),
//                                   const SizedBox(height: 6),
//                                   Text(
//                                     'Pickup: ${active.pickupAddress}',
//                                     style: const TextStyle(
//                                       fontSize: 12,
//                                       color: AppColors.commonBlack,
//                                     ),
//                                   ),
//                                   const SizedBox(height: 4),
//                                   Text(
//                                     'Drop: ${active.dropoffAddress}',
//                                     style: const TextStyle(
//                                       fontSize: 12,
//                                       color: AppColors.commonBlack,
//                                     ),
//                                   ),
//                                 ],
//                               ),
//                             ),
//                             const SizedBox(height: 16),
//                             _buildEtaRow(active),
//                             const SizedBox(height: 10),
//                             _buildActiveActionArea(active),
//                             const SizedBox(height: 10),
//                           ],
//
//                           const Padding(
//                             padding: EdgeInsets.symmetric(horizontal: 16),
//                             child: Text(
//                               'Next Stops',
//                               style: TextStyle(
//                                 fontSize: 16,
//                                 fontWeight: FontWeight.w600,
//                               ),
//                             ),
//                           ),
//                           const SizedBox(height: 8),
//
//                           if (sharedRideController.riders.isEmpty)
//                             const Padding(
//                               padding: EdgeInsets.all(20),
//                               child: Text('No riders in this shared trip'),
//                             )
//                           else
//                             Padding(
//                               padding: const EdgeInsets.symmetric(
//                                 horizontal: 16,
//                               ),
//                               child: Column(
//                                 children:
//                                     sharedRideController.riders
//                                         .map(_buildRiderRow)
//                                         .toList(),
//                               ),
//                             ),
//
//                           const SizedBox(height: 20),
//
//                           Padding(
//                             padding: const EdgeInsets.symmetric(
//                               horizontal: 20,
//                               vertical: 12,
//                             ),
//                             child: Column(
//                               crossAxisAlignment: CrossAxisAlignment.start,
//                               children: [
//                                 Obx(() {
//                                   final stopped =
//                                       driverStatusController
//                                           .isStopNewRequests
//                                           .value;
//
//                                   return Buttons.button(
//                                     borderColor: AppColors.buttonBorder,
//                                     buttonColor:
//                                         stopped
//                                             ? AppColors.containerColor
//                                             : AppColors.commonWhite,
//                                     borderRadius: 8,
//                                     textColor: AppColors.commonBlack,
//                                     onTap:
//                                         stopped
//                                             ? null
//                                             : () => Buttons.showDialogBox(
//                                               context: context,
//                                               onConfirmStop: () async {
//                                                 await driverStatusController
//                                                     .stopNewRideRequest(
//                                                       context: context,
//                                                       stop: true,
//                                                     );
//                                               },
//                                             ),
//                                     text: Text(
//                                       stopped
//                                           ? 'Already Stopped'
//                                           : 'Stop New Ride Requests',
//                                     ),
//                                   );
//                                 }),
//                                 const SizedBox(height: 10),
//
//                                 // ✅ CANCEL shared ride (safe)
//                                 Buttons.button(
//                                   borderRadius: 8,
//                                   buttonColor: AppColors.red,
//                                   onTap: () {
//                                     Buttons.showCancelRideBottomSheet(
//                                       context,
//                                       onConfirmCancel: (reason) async {
//                                         // close sheet first
//                                         if (Get.isBottomSheetOpen == true) {
//                                           Get.back();
//                                         }
//
//                                         await driverStatusController
//                                             .cancelBooking(
//                                               context,
//                                               bookingId: widget.bookingId,
//                                               reason: reason,
//                                               silent: true,
//                                               navigate: true,
//                                             );
//                                       },
//                                     );
//                                   },
//                                   text: const Text('Cancel this Shared Ride'),
//                                 ),
//                                 const SizedBox(height: 20),
//                               ],
//                             ),
//                           ),
//                         ],
//                       );
//                     }),
//                   );
//                 },
//               ),
//
//               // Booking popup for shared flow
//               const BookingOverlayRequest(isSharedFlow: true),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }
