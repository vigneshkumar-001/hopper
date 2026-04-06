import 'dart:async';
import 'dart:math' as math;

import 'package:action_slider/action_slider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
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
import 'package:hopper/Core/Utility/snackbar.dart';
import 'package:hopper/Presentation/Authentication/widgets/textFields.dart';
import 'package:hopper/Presentation/DriverScreen/controller/driver_main_controller.dart';
import 'package:hopper/Presentation/DriverScreen/controller/driver_status_controller.dart';
import 'package:hopper/Presentation/DriverScreen/screens/SharedBooking/Controller/shared_controller.dart';
import 'package:hopper/Presentation/DriverScreen/screens/SharedBooking/Controller/shared_ride_controller.dart';
import 'package:hopper/Presentation/DriverScreen/screens/SharedBooking/Screens/booking_overlay_request.dart';
import 'package:hopper/Presentation/DriverScreen/screens/cash_collected_screen.dart';
import 'package:hopper/Presentation/DriverScreen/screens/driver_main_screen.dart';
import 'package:hopper/Presentation/DriverScreen/screens/verify_rider_screen.dart';
import 'package:hopper/utils/map/driver_route.dart';
import 'package:hopper/utils/map/route_info.dart';
import 'package:hopper/api/repository/api_constents.dart';
import 'package:hopper/utils/map/navigation_assist.dart';
import 'package:hopper/utils/widgets/hoppr_circular_loader.dart';
import 'package:hopper/utils/map/maneuver_markers.dart';
import 'package:hopper/utils/map/navigation_voice_service.dart';
import 'package:hopper/utils/map/shared_map.dart';
import 'package:hopper/utils/map/ride_route_overlays.dart';
import 'package:hopper/utils/map/map_control_button.dart';
import 'package:hopper/utils/map/map_motion_profile.dart';
import 'package:hopper/utils/widgets/hoppr_swipe_slider.dart';
import 'package:hopper/utils/netWorkHandling/network_handling_screen.dart';
import 'package:hopper/utils/sharedprefsHelper/sharedprefs_handler.dart';
import 'package:hopper/api/repository/api_config_controller.dart';

import '../../../../../utils/websocket/socket_io_client.dart';
import '../Controller/booking_request_controller.dart';

// Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬ Design tokens (matches PickingCustomerSharedScreen) Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
class _C {
  static const bg = Color(0xFFF4F6FA);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceAlt = Color(0xFFF8F9FC);

  static const green = Color(0xFF00A85E);
  static const greenLight = Color(0xFFE6F7F0);
  static const greenBorder = Color(0x4000A85E);
  static const greenText = Color(0xFF00874C);

  static const red = Color(0xFFE53935);
  static const redLight = Color(0xFFFFF0F0);
  static const blue = Color(0xFF1976D2);
  static const blueLight = Color(0xFFE8F1FB);
  static const amber = Color(0xFFF59E0B);
  static const amberLight = Color(0xFFFFFBEB);

  static const text = Color(0xFF111827);
  static const textSub = Color(0xFF6B7280);
  static const textMuted = Color(0xFF9CA3AF);

  static const border = Color(0xFFE5E7EB);
  static const borderLight = Color(0xFFF3F4F6);

  static const shadow = Color(0x14000000);
  static const shadowMd = Color(0x1F000000);
}

// Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬ Internal helpers Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
class _QueuedSocketEmit {
  final String event;
  final Map<String, dynamic> payload;
  const _QueuedSocketEmit({required this.event, required this.payload});
}

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
    onTick(pos, _norm(bearing));
  }

  void animateTo(LatLng newPos, double newBearing) {
    final nb = _norm(newBearing);
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
    _toBearing = _shortAngle(_fromBearing, nb);
    final total = _totalSteps;
    _timer = Timer.periodic(Duration(milliseconds: (1000 / fps).round()), (t) {
      if (shouldTick != null && shouldTick!() == false) {
        t.cancel();
        return;
      }
      _step++;
      final p = (_step / total).clamp(0.0, 1.0);
      final e = Curves.easeOutCubic.transform(p);
      onTick(
        _lerp(_fromPos!, _toPos!, e),
        _norm(_lerpD(_fromBearing, _toBearing, e)),
      );
      if (p >= 1.0) t.cancel();
    });
  }

  static LatLng _lerp(LatLng a, LatLng b, double t) => LatLng(
    a.latitude + (b.latitude - a.latitude) * t,
    a.longitude + (b.longitude - a.longitude) * t,
  );
  static double _lerpD(double a, double b, double t) => a + (b - a) * t;
  static double _norm(double b) {
    var x = b % 360;
    if (x < 0) x += 360;
    return x;
  }

  static double _shortAngle(double from, double to) {
    from = _norm(from);
    to = _norm(to);
    var d = to - from;
    if (d > 180) d -= 360;
    if (d < -180) d += 360;
    return from + d;
  }
}

// Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬ Screen Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
class ShareRideStartScreen extends StatefulWidget {
  final String bookingId;
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
  late final DriverStatusController driverStatusController =
      Get.isRegistered<DriverStatusController>()
          ? Get.find<DriverStatusController>()
          : Get.put(DriverStatusController(), permanent: true);
  final BookingRequestController bookingController =
      Get.find<BookingRequestController>();
  final SharedRideController sharedRideController =
      Get.find<SharedRideController>();

  final GlobalKey<SharedMapState> _mapKey = GlobalKey<SharedMapState>();

  LatLng? _animatedDriverPos;
  double _animatedBearing = 0.0;

  List<LatLng> polylinePoints = const [];
  Set<Marker> _maneuverMarkers = <Marker>{};
  String directionText = '';
  String distance = '';
  String maneuver = '';
  String laneGuidance = '';

  BitmapDescriptor? carIcon;
  late SocketService socketService;
  Worker? _serviceTypeWorker;

  bool driverCompletedRide = false;
  bool _isDriverFocused = true;
  bool _leavingScreen = false;
  bool _isNetworkOffline = false;
  bool _isOffRouteAlert = false;
  int _pendingQueueCount = 0;
  double _followZoom = 14.4;
  bool _isDisposing = false;

  late final _MarkerAnimator _markerAnimator;

  DateTime? _lastUiUpdate;
  List<LatLng>? _lastPolyline;
  LatLng? _adjustedTargetPos;
  String _lastDirectionText = '';
  String _lastDistanceText = '';
  String _lastManeuver = '';
  String _lastLaneGuidance = '';

  late final AnimationController _pulseController;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  final List<_QueuedSocketEmit> _socketRetryQueue = [];
  String? _driverId;
  DateTime? _lastSpeedAt;
  LatLng? _lastSpeedPos;
  Worker? _activeTargetWorker;
  String? _arrivedSubmittingBookingId;

  final Set<String> _expandedCards = {};

  // Ã¢â€â‚¬Ã¢â€â‚¬ Exit Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
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

  Future<void> _loadDriverId() async {
    _driverId = await SharedPrefHelper.getDriverId();
  }

  void _initConnectivityWatchdog() {
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      final offline = results.every((r) => r == ConnectivityResult.none);
      if (mounted && !_isDisposing) {
        setState(() => _isNetworkOffline = offline);
      } else {
        _isNetworkOffline = offline;
      }
      if (offline) return;
      if (!socketService.connected) socketService.connect();
      _flushSocketRetryQueue();
    });
  }

  // Ã¢â€â‚¬Ã¢â€â‚¬ Init / Dispose Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
  @override
  void initState() {
    super.initState();

    // IMPORTANT: needed for polyline/directions fetching when this screen is opened
    // directly from Resume (no other controller may have set it yet).
    DirectionsConfig.apiKey = ApiConstents.googleMapApiKey;

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.dark,
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
    _initConnectivityWatchdog();
    _loadDriverId();
    _loadMarkerIcons();
    _listenServiceTypeForIcon();

    final initialTarget = sharedRideController.activeTarget.value;
    final initialDestination =
        initialTarget == null
            ? widget.pickupLocation
            : (initialTarget.stage == SharedRiderStage.waitingPickup
                ? initialTarget.pickupLatLng
                : initialTarget.dropLatLng);

    // Show an immediate fallback route so UI doesn't look blank while waiting for API.
    polylinePoints = _buildFallbackRoute(
      widget.driverLocation,
      initialDestination,
    );
    _lastPolyline = polylinePoints;
    unawaited(
      _rebuildManeuverMarkers(
        polylinePoints,
        travelOrigin: widget.driverLocation,
        avoid: <LatLng>[initialDestination],
      ),
    );

    _routeController = DriverRouteController(
      destination: initialDestination,
      initialLocation: widget.driverLocation,
      onRouteUpdate: (update) {
        if (!mounted || _isDisposing) return;
        _markerAnimator.animateTo(update.driverLocation, update.bearing);
        sharedRideController.updateDriverLocation(update.driverLocation);
        _updateSmartAutoZoom(update.driverLocation);

        final now = DateTime.now();
        if (_lastUiUpdate != null &&
            now.difference(_lastUiUpdate!).inMilliseconds < 300)
          return;
        _lastUiUpdate = now;

        final poly = update.polylinePoints;
        final dText = update.directionText;
        final distText = update.distanceText;
        final man = update.maneuver;
        final lane = update.laneGuidance;
        final adjDest = update.destination;

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
            man != _lastManeuver ||
            lane != _lastLaneGuidance;
        final offRouteNow = _isOffRoute(update.driverLocation, poly);

        if (!mounted || _isDisposing) return;
        if (!polyChanged && !textChanged && _isOffRouteAlert == offRouteNow)
          return;

        setState(() {
          _adjustedTargetPos = adjDest;
          if (polyChanged) {
            polylinePoints = poly;
            _lastPolyline = poly;
          }
          if (textChanged) {
            directionText = dText;
            distance = distText;
            maneuver = man;
            laneGuidance = lane;
            _lastDirectionText = dText;
            _lastDistanceText = distText;
            _lastManeuver = man;
            _lastLaneGuidance = lane;
          }
          _isOffRouteAlert = offRouteNow;
        });

        if (polyChanged) {
          final activeNow = sharedRideController.activeTarget.value ?? initialTarget;
          final destNow =
              _adjustedTargetPos ??
              (activeNow == null
                  ? widget.pickupLocation
                  : _destinationForTarget(activeNow));

          unawaited(
            _rebuildManeuverMarkers(
              poly,
              maneuverPoints: update.maneuverPoints,
              travelOrigin: update.driverLocation,
              avoid: <LatLng>[destNow],
            ),
          );
        }

        final active = sharedRideController.activeTarget.value;
        final etaMinutes =
            active != null && active.stage == SharedRiderStage.waitingPickup
                ? sharedController.pickupDurationInMin.value
                : sharedController.dropDurationInMin.value;

        final voiceLine = NavigationAssist.buildVoiceLine(
          maneuver: man,
          distanceText: distText,
          directionText: dText,
        );
        NavigationVoiceService.instance.speakTurn(voiceLine);
      },
      onCameraUpdate: (_) {},
    );

    _routeController.start();

    _activeTargetWorker = ever<SharedRiderItem?>(
      sharedRideController.activeTarget,
      (active) {
        if (active == null || !mounted || _isDisposing) return;
        unawaited(_syncActiveTargetRoute(active: active));
      },
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  void _listenServiceTypeForIcon() {
    _serviceTypeWorker?.dispose();
    _serviceTypeWorker = ever<String>(
      driverStatusController.serviceType,
      (_) => _loadMarkerIcons(),
    );
  }

  @override
  void dispose() {
    _isDisposing = true;
    _connectivitySub?.cancel();
    try {
      _serviceTypeWorker?.dispose();
    } catch (_) {}
    try {
      _markerAnimator.dispose();
    } catch (_) {}
    try {
      _routeController.dispose();
    } catch (_) {}
    try {
      _activeTargetWorker?.dispose();
    } catch (_) {}
    try {
      _pulseController.stop();
      _pulseController.dispose();
    } catch (_) {}
    try {
      socketService.socket.off('driver-reached-destination');
      socketService.socket.off('driver-location');
      socketService.socket.off('driver-cancelled');
      socketService.socket.off('customer-cancelled');
      socketService.socket.off('joined-booking');
      socketService.socket.off('booking-request');
      try {
        socketService.socket.offAny();
      } catch (_) {}
    } catch (_) {}
    super.dispose();
  }

  // Ã¢â€â‚¬Ã¢â€â‚¬ Helpers Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
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

  LatLng _destinationForTarget(SharedRiderItem rider) {
    return rider.stage == SharedRiderStage.waitingPickup
        ? rider.pickupLatLng
        : rider.dropLatLng;
  }

  List<LatLng> _buildFallbackRoute(LatLng origin, LatLng destination) {
    if (origin.latitude == destination.latitude &&
        origin.longitude == destination.longitude) {
      return <LatLng>[origin];
    }
    return <LatLng>[origin, destination];
  }

  Future<void> _rebuildManeuverMarkers(
    List<LatLng> pts, {
    List<Map<String, dynamic>>? maneuverPoints,
    LatLng? travelOrigin,
    List<LatLng> avoid = const <LatLng>[],
  }) async {
    try {
      final markers = await ManeuverMarkers.build(
        polyline: pts,
        idPrefix: 'shared_route_${widget.bookingId}',
        travelOrigin: travelOrigin,
        avoidPositions: avoid,
        maneuverPoints: maneuverPoints,
      );
      if (!mounted || _isDisposing) return;
      setState(() {
        _maneuverMarkers = markers.toSet();
      });
    } catch (_) {
      // ignore
    }
  }

  Future<void> _syncActiveTargetRoute({
    SharedRiderItem? active,
    bool focusMap = true,
  }) async {
    final target = active ?? sharedRideController.activeTarget.value;
    if (target == null || !mounted || _isDisposing) return;

    final dest = _destinationForTarget(target);
    final origin =
        _animatedDriverPos ??
        sharedRideController.driverLocation.value ??
        widget.driverLocation;

    sharedController.pickupDistanceInMeters.value = 0;
    sharedController.pickupDurationInMin.value = 0;
    sharedController.dropDistanceInMeters.value = 0;
    sharedController.dropDurationInMin.value = 0;

    setState(() {
      polylinePoints = _buildFallbackRoute(origin, dest);
      _lastPolyline = polylinePoints;
      _adjustedTargetPos = null;
    });
    unawaited(
      _rebuildManeuverMarkers(
        polylinePoints,
        travelOrigin: origin,
        avoid: <LatLng>[dest],
      ),
    );

    await _routeController.updateDestination(dest);

    if (!mounted || _isDisposing) return;
    if (focusMap) {
      _mapKey.currentState?.focusPickup();
    }
    setState(() {});
  }

  bool _isOffRoute(LatLng current, List<LatLng> polyline) {
    if (polyline.isEmpty) return false;
    for (final p in polyline) {
      final d = Geolocator.distanceBetween(
        current.latitude,
        current.longitude,
        p.latitude,
        p.longitude,
      );
      if (d < 28.0) return false;
    }
    return true;
  }

  void _updateSmartAutoZoom(LatLng current) {
    double speedMs = 0;
    if (_lastSpeedPos != null && _lastSpeedAt != null) {
      final dt =
          DateTime.now().difference(_lastSpeedAt!).inMilliseconds / 1000.0;
      if (dt > 0.2) {
        final d = Geolocator.distanceBetween(
          _lastSpeedPos!.latitude,
          _lastSpeedPos!.longitude,
          current.latitude,
          current.longitude,
        );
        speedMs = d / dt;
      }
    }
    _lastSpeedPos = current;
    _lastSpeedAt = DateTime.now();

    final targetZoom = MapMotionProfile.targetZoomFromSpeed(
      speedMs,
    ).clamp(15.2, 17.8);
    _followZoom = MapMotionProfile.smoothZoom(
      _followZoom,
      targetZoom,
    ).clamp(15.2, 17.8);
  }

  String _formatDistance(double meters) {
    if (meters <= 0) return '0 km';
    return '${(meters / 1000.0).toStringAsFixed(1)} km';
  }

  String _formatDuration(double minutes) {
    if (minutes <= 0) return '0 min';
    final total = minutes.round();
    final h = total ~/ 60;
    final m = total % 60;
    return h > 0 ? '${h}h ${m}m' : '$m min';
  }

  // Ã¢â€â‚¬Ã¢â€â‚¬ Socket Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
  Future<void> _initSocket() async {
    socketService = SocketService();
    try {
      final cfg = Get.find<ApiConfigController>();
      socketService.initSocket(cfg.socketUrl);
      // Ensure we are in the correct room for this shared ride (parent room).
      final did = (await SharedPrefHelper.getDriverId()) ?? '';
      if (did.trim().isNotEmpty) {
        socketService.joinBooking(widget.bookingId, userId: did);
      } else {
        socketService.joinBooking(widget.bookingId);
      }
    } catch (_) {
      // ApiConfigController may not be registered in tests; ignore.
    }

    socketService.on('joined-booking', (data) async {
      try {
        if (!mounted || _isDisposing || data == null) return;

        // Server may send:
        // - a single booking map
        // - a list of booking maps (shared/pool)
        // - a socket args list where the first item is the actual payload
        final bookings = <Map<String, dynamic>>[];
        dynamic payload = data;
        if (payload is List && payload.length == 1) {
          final first = payload.first;
          if (first is Map || first is List) payload = first;
        }
        if (payload is Map) {
          bookings.add(Map<String, dynamic>.from(payload));
        } else if (payload is List) {
          for (final e in payload) {
            if (e is Map) bookings.add(Map<String, dynamic>.from(e));
          }
        }
        if (bookings.isEmpty) return;

        // Keep service type in sync so driver marker icon is correct (Car/Bike).
        try {
          final first = bookings.first;
          driverStatusController.setServiceTypeFrom(
            first['serviceType'] ?? first['rideType'] ?? first['vehicleType'],
          );
        } catch (_) {}

        for (final b in bookings) {
          try {
            final bid = (b['bookingId'] ?? '').toString().trim();
            if (bid.isNotEmpty) socketService.rememberBookingRoom(bid);
          } catch (_) {}
        }

        await Future.wait(bookings.map(sharedRideController.upsertFromSocket));

        final active = sharedRideController.activeTarget.value;
        if (active != null) {
          await _syncActiveTargetRoute(active: active);
        }
        if (!mounted || _isDisposing) return;
        setState(() {});
      } catch (e) {
        debugPrint('joined-booking error: $e');
      }
    });

    socketService.on('booking-request', (data) async {
      if (!mounted || _isDisposing || data == null) return;

      // New payload shape support: { type: active-bookings, activeBookings: [...] }
      if (data is Map && data['activeBookings'] is List) {
        final items =
            (data['activeBookings'] as List)
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList();

        for (final b in items) {
          final bookingId = b['bookingId']?.toString() ?? '';
          if (bookingId.isEmpty) continue;

          socketService.rememberBookingRoom(bookingId);

          final pickupGeo = b['bookingCustomerlocation'];
          final pickupCoords =
              pickupGeo is Map ? pickupGeo['coordinates'] as List? : null;

          final fromLat = _safeNum(
            b['fromLatitude'] ??
                b['pickupLocation']?['latitude'] ??
                (pickupCoords != null && pickupCoords.length >= 2
                    ? pickupCoords[1]
                    : null),
          );
          final fromLng = _safeNum(
            b['fromLongitude'] ??
                b['pickupLocation']?['longitude'] ??
                (pickupCoords != null && pickupCoords.length >= 2
                    ? pickupCoords[0]
                    : null),
          );
          final toLat =
              _safeNum(b['toLatitude'] ?? b['dropLocation']?['latitude']) ??
              fromLat;
          final toLng =
              _safeNum(b['toLongitude'] ?? b['dropLocation']?['longitude']) ??
              fromLng;
          if (fromLat == null ||
              fromLng == null ||
              toLat == null ||
              toLng == null) {
            continue;
          }

          final normalized = <String, dynamic>{
            'bookingId': bookingId,
            'amount': (b['amount'] as num?) ?? 0,
            'customerName': b['customerName']?.toString() ?? 'Rider',
            'customerPhone': b['customerPhone']?.toString() ?? '',
            'customerProfilePic':
                b['customerProfilePic']?.toString() ??
                b['profilePic']?.toString() ??
                '',
            'pickupLocationAddress': b['pickupAddress']?.toString() ?? '',
            'dropLocationAddress': b['dropAddress']?.toString() ?? '',
            'customerLocation': {
              'fromLatitude': fromLat,
              'fromLongitude': fromLng,
              'toLatitude': toLat,
              'toLongitude': toLng,
            },
          };

          await sharedRideController.upsertFromSocket(normalized);
        }

        if (mounted && !_isDisposing) setState(() {});
        return;
      }

      final incomingId = data['bookingId']?.toString();
      if (incomingId == widget.bookingId) return;
      if (incomingId != null &&
          incomingId == bookingController.lastHandledBookingId.value)
        return;

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
      if (!Get.isRegistered<DriverMainController>()) return;
      await Get.find<DriverMainController>().handleDriverCancelled(data);
    });
    socketService.on('customer-cancelled', (data) async {
      if (!Get.isRegistered<DriverMainController>()) return;
      await Get.find<DriverMainController>().handleCustomerCancelled(data);
    });

    socketService.on('driver-reached-destination', (data) {
      final status = data?['status'];
      if (status == true || status?.toString() == 'true') {
        if (!mounted || _isDisposing) return;
        setState(() => driverCompletedRide = true);
      }
    });

    socketService.on('driver-location', (data) {
      if (data == null) return;

      // Ensure driver marker uses correct car/bike icon.
      driverStatusController.setServiceTypeFrom(
        data['serviceType'] ?? data['rideType'] ?? data['vehicleType'],
      );

      final dropM = _safeNum(data['dropDistanceInMeters']) ?? 0.0;
      final dropMin = _safeNum(data['dropDurationInMin']) ?? 0.0;
      sharedController.dropDistanceInMeters.value = dropM;
      sharedController.dropDurationInMin.value = dropMin;

      final pickupM = _safeNum(data['pickupDistanceInMeters']);
      final pickupMin = _safeNum(data['pickupDurationInMin']);
      if (pickupM != null)
        sharedController.pickupDistanceInMeters.value = pickupM;
      if (pickupMin != null)
        sharedController.pickupDurationInMin.value = pickupMin;
    });

    if (!socketService.connected) {
      socketService.connect();
      socketService.onConnect(() => _flushSocketRetryQueue());
    }
  }

  Future<void> _loadMarkerIcons() async {
    try {
      final status =
          Get.isRegistered<DriverStatusController>()
              ? Get.find<DriverStatusController>()
              : Get.put(DriverStatusController(), permanent: true);

      final ctx = context;
      final dpr = MediaQuery.of(ctx).devicePixelRatio;

      final bool isCar = status.isCar;
      final String asset = isCar ? AppImages.movingCar : AppImages.parcelBike;

      // Keep consistent marker sizing across single/shared screens.
      final double markerHeight = 52.0;
      final double markerWidth = isCar ? 27.0 : 32.0;
      final ImageConfiguration cfg = ImageConfiguration(
        size: Size(markerWidth, markerHeight),
        devicePixelRatio: dpr,
      );

      final icon = await BitmapDescriptor.asset(
        cfg,
        asset,
        width: markerWidth,
        height: markerHeight,
      );
      if (!mounted || _isDisposing) return;
      setState(() => carIcon = icon);
    } catch (_) {
      carIcon = BitmapDescriptor.defaultMarker;
    }
  }

  // Ã¢â€â‚¬Ã¢â€â‚¬ Quick message Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
  Future<void> _sendQuickMessage(
    SharedRiderItem rider,
    String text, {
    int? delayMinutes,
  }) async {
    final driverId = _driverId ?? await SharedPrefHelper.getDriverId();
    final payload = <String, dynamic>{
      'bookingId': rider.bookingId,
      'parentBookingId': widget.bookingId,
      'driverId': driverId,
      'delayMinutes': (delayMinutes ?? 0) < 0 ? 0 : (delayMinutes ?? 0),
      'message': text,
    };
    if (_isNetworkOffline || !socketService.connected) {
      _enqueueSocketEmit('driver-message', payload);
      CustomSnackBar.showInfo('Queued: $text', title: 'Message');
      return;
    }
    socketService.emitWithAck('driver-message', payload, (ack) {
      final ok =
          (ack is Map && (ack['success'] == true || ack['status'] == true));
      if (ok) {
        CustomSnackBar.showSuccess('Sent: $text', title: 'Message');
        return;
      }
      _enqueueSocketEmit('driver-message', payload);
      CustomSnackBar.showError('Failed, queued: $text', title: 'Message');
    });
  }

  void _enqueueSocketEmit(String event, Map<String, dynamic> payload) {
    _socketRetryQueue.add(_QueuedSocketEmit(event: event, payload: payload));
    if (mounted && !_isDisposing) {
      setState(() => _pendingQueueCount = _socketRetryQueue.length);
    } else {
      _pendingQueueCount = _socketRetryQueue.length;
    }
  }

  void _flushSocketRetryQueue() {
    if (_socketRetryQueue.isEmpty || !socketService.connected) return;
    final queued = List<_QueuedSocketEmit>.from(_socketRetryQueue);
    _socketRetryQueue.clear();
    if (mounted && !_isDisposing) setState(() => _pendingQueueCount = 0);
    for (final q in queued) {
      socketService.emitWithAck(q.event, q.payload, (ack) {
        if (!(ack is Map && ack['success'] == true)) {
          _enqueueSocketEmit(q.event, q.payload);
        }
      });
    }
  }

  // Ã¢â€â‚¬Ã¢â€â‚¬ Nav / target Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
  Future<void> _setAsNextStop(SharedRiderItem r) async {
    if (!mounted || _isDisposing) return;
    if (r.stage == SharedRiderStage.dropped) return;
    sharedRideController.setActiveTarget(r.bookingId, r.stage);
    (r.sliderController as ActionSliderController?)?.reset();
    await _syncActiveTargetRoute(
      active: sharedRideController.activeTarget.value,
    );
    if (!mounted || _isDisposing) return;
    setState(() {});
  }

  Future<void> _onCurrentLegCompleted(SharedRiderItem completedRider) async {
    if (!mounted || _isDisposing) return;
    final bool? cashCollected = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder:
            (_) => CashCollectedScreen(
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
      (completedRider.sliderController as ActionSliderController?)?.reset();
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
    (next.sliderController as ActionSliderController?)?.reset();
    await _syncActiveTargetRoute(active: next, focusMap: false);
    if (!mounted || _isDisposing) return;
    setState(() {});
  }

  // Ã¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢Â
  // WIDGETS
  // Ã¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢Â

  // Ã¢â€â‚¬Ã¢â€â‚¬ Direction header Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
  Widget _buildDirectionHeader() {
    final dist = distance.isEmpty ? '--' : distance;
    final dir =
        directionText.isEmpty ? 'Searching best route...' : directionText;
    final lane = laneGuidance.trim();
    final man = maneuver.toLowerCase();
    final isTurnAlert =
        man.contains('left') ||
        man.contains('right') ||
        man.contains('uturn') ||
        man.contains('roundabout');
    final leftColor =
        isTurnAlert ? const Color(0xFFFC1212) : const Color(0xFFF1A500);
    final rightColor =
        isTurnAlert ? const Color(0xFFE10606) : const Color(0xFFC88700);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: SizedBox(
          height: 80,
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: Container(
                  color: leftColor,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 10,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        NavigationAssist.iconForManeuver(
                          maneuver,
                          directionText: dir,
                        ),
                        size: 25,
                        color: Colors.white,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        dist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                flex: 5,
                child: Container(
                  color: rightColor,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dir,
                        maxLines: lane.isNotEmpty ? 1 : 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          height: 1.15,
                        ),
                      ),
                      if (lane.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.35),
                            ),
                          ),
                          child: Text(
                            lane,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Ã¢â€â‚¬Ã¢â€â‚¬ Map control buttons Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
  Widget _buildMapControlBtn({
    required IconData icon,
    required VoidCallback onTap,
    Color? iconColor,
  }) {
    return MapControlButton(
      icon: icon,
      onTap: onTap,
      iconColor: iconColor ?? _C.text.withOpacity(0.7),
      backgroundColor: _C.surface,
    );
  }

  // Ã¢â€â‚¬Ã¢â€â‚¬ Offline / off-route banners Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
  Widget _buildOfflineBanner() {
    if (!_isNetworkOffline && _pendingQueueCount == 0)
      return const SizedBox.shrink();
    return Positioned(
      top: 150,
      left: 12,
      right: 12,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: _C.amberLight,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _C.amber.withOpacity(0.4)),
          boxShadow: [
            BoxShadow(
              color: _C.amber.withOpacity(0.1),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(
              _isNetworkOffline ? Icons.wifi_off_rounded : Icons.sync_rounded,
              color: _C.amber,
              size: 16,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _isNetworkOffline
                    ? 'No internet. Route cache active, syncing when online.'
                    : 'Sync pending: $_pendingQueueCount message(s)',
                style: TextStyle(
                  color: _C.amber.withOpacity(0.9),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOffRouteBanner() {
    if (!_isOffRouteAlert) return const SizedBox.shrink();
    return Positioned(
      top: 202,
      left: 12,
      right: 12,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF3CD),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _C.amber.withOpacity(0.5)),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: _C.amber, size: 18),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Route deviation detected',
                style: TextStyle(
                  color: Color(0xFF92400E),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            TextButton(
              onPressed: () => _mapKey.currentState?.focusPickup(),
              style: TextButton.styleFrom(
                foregroundColor: _C.amber,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'Recenter',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Ã¢â€â‚¬Ã¢â€â‚¬ ETA row Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
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

      return Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
        decoration: BoxDecoration(
          color: _C.greenLight,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _C.greenBorder),
          boxShadow: [
            BoxShadow(
              color: _C.green.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.schedule_rounded, color: _C.green, size: 17),
            const SizedBox(width: 6),
            Text(
              _formatDuration(minutes),
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: _C.greenText,
              ),
            ),
            const SizedBox(width: 14),
            Container(
              width: 4,
              height: 4,
              decoration: const BoxDecoration(
                color: _C.green,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 14),
            const Icon(Icons.route_rounded, color: _C.textSub, size: 17),
            const SizedBox(width: 6),
            Text(
              _formatDistance(meters),
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: _C.text,
              ),
            ),
          ],
        ),
      );
    });
  }

  // Ã¢â€â‚¬Ã¢â€â‚¬ Active info card Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
  Widget _buildActiveInfoCard(SharedRiderItem active) {
    final isPickup = active.stage == SharedRiderStage.waitingPickup;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isPickup ? _C.blue.withOpacity(0.3) : _C.greenBorder,
        ),
        boxShadow: [
          BoxShadow(
            color: (isPickup ? _C.blue : _C.green).withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status pill + name
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: isPickup ? _C.blueLight : _C.greenLight,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isPickup ? 'Heading to Pickup' : 'Ride in Progress',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isPickup ? _C.blue : _C.green,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  active.name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _C.text,
                  ),
                ),
              ),
              Text(
                '#${active.bookingId}',
                style: const TextStyle(fontSize: 10, color: _C.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Address section
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _C.surfaceAlt,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _C.borderLight),
            ),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Column(
                    children: [
                      _addrDot(_C.green, glowing: true),
                      Expanded(
                        child: Container(
                          width: 1.5,
                          margin: const EdgeInsets.symmetric(vertical: 3),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                _C.green.withOpacity(0.4),
                                _C.red.withOpacity(0.3),
                              ],
                            ),
                          ),
                        ),
                      ),
                      _addrDot(_C.red),
                    ],
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'PICKUP',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: _C.textMuted,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          active.pickupAddress,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: _C.text,
                            height: 1.35,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'DROP OFF',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: _C.textMuted,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          active.dropoffAddress,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: _C.text,
                            height: 1.35,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _buildQuickReplies(active),
          const SizedBox(height: 12),
          _buildActiveActionArea(active, inCard: true),
        ],
      ),
    );
  }

  List<String> _quickRepliesByDistance({
    required bool isPickupStage,
    required bool reachedPickup,
    required double meters,
    required int etaMinutes,
  }) {
    if (isPickupStage) {
      if (reachedPickup) {
        return const [
          'I reached pickup point',
          'I am waiting at pickup',
          'Please come to pickup gate',
          'Call me when you are outside',
        ];
      }
      if (meters <= 150) {
        return const [
          'I am very close',
          'Please come out now',
          'I am outside your pickup',
          'See you in a minute',
        ];
      }
      if (meters <= 500) {
        return const [
          'I am around 2 mins away',
          'Please be ready at pickup',
          'Reaching shortly',
          'Will call once I arrive',
        ];
      }
      if (meters <= 1500) {
        return [
          'I am $etaMinutes mins away',
          'Traffic is moderate, coming',
          'Please keep phone reachable',
          'I will reach your pickup soon',
        ];
      }
      return [
        'I am on the way',
        'Current ETA is $etaMinutes mins',
        'Slight delay due to traffic',
        'Please wait at pickup point',
      ];
    }

    if (meters <= 200) {
      return const [
        'We are near your drop',
        'Please be ready to get down',
        'Drop point is very close',
        'Reaching your stop now',
      ];
    }
    if (meters <= 1000) {
      return [
        'Drop in about $etaMinutes mins',
        'Please check your belongings',
        'We are approaching your drop',
        'I will stop at your drop point',
      ];
    }
    return [
      'Heading to your drop location',
      'ETA to drop is $etaMinutes mins',
      'Traffic ahead, slight delay',
      'Will update as we get closer',
    ];
  }

  // Ã¢â€â‚¬Ã¢â€â‚¬ Quick replies Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
  Widget _buildQuickReplies(SharedRiderItem active) {
    return Obx(() {
      final isPickupStage = active.stage == SharedRiderStage.waitingPickup;
      final eta =
          (isPickupStage
                  ? sharedController.pickupDurationInMin.value
                  : sharedController.dropDurationInMin.value)
              .round();
      final meters =
          isPickupStage
              ? sharedController.pickupDistanceInMeters.value
              : sharedController.dropDistanceInMeters.value;
      final chips = _quickRepliesByDistance(
        isPickupStage: isPickupStage,
        reachedPickup: active.arrived,
        meters: meters,
        etaMinutes: eta,
      );

      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Quick replies',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: _C.textMuted,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 7),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children:
                    chips.map((msg) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 7),
                        child: GestureDetector(
                          onTap:
                              () => _sendQuickMessage(
                                active,
                                msg,
                                delayMinutes: eta,
                              ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: _C.surface,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: _C.border),
                              boxShadow: const [
                                BoxShadow(
                                  color: _C.shadow,
                                  blurRadius: 6,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Text(
                              msg,
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: _C.text,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildActiveActionArea(SharedRiderItem active, {bool inCard = false}) {
    final areaPadding =
        inCard
            ? const EdgeInsets.only(top: 2)
            : const EdgeInsets.fromLTRB(16, 14, 16, 0);
    final isArrivedSubmitting = _arrivedSubmittingBookingId == active.bookingId;
    // Arrived button
    if (active.stage == SharedRiderStage.waitingPickup && !active.arrived) {
      return Obx(() {
        final canShow = sharedRideController.canArriveAtActivePickup.value;
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          child:
              canShow
                  ? Padding(
                    key: ValueKey('arrived-${active.bookingId}'),
                    padding: areaPadding,
                    child: GestureDetector(
                      onTap:
                          isArrivedSubmitting
                              ? null
                              : () async {
                                try {
                                  setState(() {
                                    _arrivedSubmittingBookingId =
                                        active.bookingId;
                                  });
                                  final result = await driverStatusController
                                      .driverArrived(
                                        context,
                                        bookingId: active.bookingId,
                                      );
                                  if (!mounted || _isDisposing) return;
                                  if (result != null && result.status == 200) {
                                    sharedRideController.markArrived(
                                      active.bookingId,
                                    );
                                    if (!mounted || _isDisposing) return;
                                    setState(() {
                                      _arrivedSubmittingBookingId = null;
                                    });
                                  } else {
                                    setState(() {
                                      _arrivedSubmittingBookingId = null;
                                    });
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          result?.message ??
                                              'Something went wrong',
                                        ),
                                      ),
                                    );
                                  }
                                } catch (_) {
                                  if (!mounted || _isDisposing) return;
                                  setState(() {
                                    _arrivedSubmittingBookingId = null;
                                  });
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Unable to mark as arrived, please retry',
                                      ),
                                    ),
                                  );
                                }
                              },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color:
                              isArrivedSubmitting
                                  ? _C.blue.withOpacity(0.82)
                                  : _C.blue,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: _C.blue.withOpacity(0.25),
                              blurRadius: 14,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (isArrivedSubmitting)
                              const HopprCircularLoader(
                                radius: 9,
                                size: 18,
                                color: Colors.white,
                              )
                            else
                              const Icon(
                                Icons.location_on_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                            const SizedBox(width: 8),
                            Text(
                              'Arrived at pickup for ${active.name}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                  : const SizedBox.shrink(key: ValueKey('arrived-hidden')),
        );
      });
    }

    // Swipe to start
    if (active.stage == SharedRiderStage.waitingPickup && active.arrived) {
      final riderCtrl = active.sliderController as ActionSliderController;
      return Padding(
        padding: areaPadding,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _C.green.withOpacity(0.3), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: _C.green.withOpacity(0.1),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: HopprSwipeSlider(
              key: ValueKey('start---'),
              controller: riderCtrl,
              height: 56,
              backgroundColor: _C.green,
              handleColor: Colors.white,
              handleIconColor: _C.green,
              borderRadius: BorderRadius.circular(15),
              text: 'Swipe to Start Ride',
              textStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
              onAction: (controller) async {
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
                      builder:
                          (_) => VerifyRiderScreen(
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
                    await _syncActiveTargetRoute();
                    await Future.delayed(const Duration(milliseconds: 250));
                    controller.reset();
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
          ),
        ),
      );
    }

    // Complete current stop
    if (active.stage == SharedRiderStage.onboardDrop) {
      final riderSlider = active.sliderController as ActionSliderController;
      return Obx(() {
        final canShow = sharedRideController.canCompleteActiveDrop.value;
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          child:
              canShow
                  ? Padding(
                    key: ValueKey('complete-${active.bookingId}'),
                    padding: areaPadding,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _C.green.withOpacity(0.3),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _C.green.withOpacity(0.1),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(15),
                        child: HopprSwipeSlider(
                          key: ValueKey(
                            'complete-${active.bookingId}-${active.stage}',
                          ),
                          controller: riderSlider,
                          height: 56,
                          backgroundColor: _C.green,
                          handleColor: Colors.white,
                          handleIconColor: _C.green,
                          idleIcon: Icons.check_rounded,
                          borderRadius: BorderRadius.circular(15),
                          text: 'Swipe to Complete Stop - ${active.name}',
                          textStyle: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                          onAction: (controller) async {
                            try {
                              controller.loading();
                              await Future.delayed(
                                const Duration(milliseconds: 200),
                              );
                              final msg = await driverStatusController
                                  .completeRideRequest(
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
                                await Future.delayed(
                                  const Duration(milliseconds: 250),
                                );
                                controller.reset();
                              } else {
                                controller.failure();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Failed to complete stop'),
                                  ),
                                );
                                await Future.delayed(
                                  const Duration(milliseconds: 700),
                                );
                                controller.reset();
                              }
                            } catch (_) {
                              if (!mounted || _isDisposing) return;
                              controller.failure();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Something went wrong, please try again',
                                  ),
                                ),
                              );
                              await Future.delayed(
                                const Duration(milliseconds: 700),
                              );
                              controller.reset();
                            }
                          },
                        ),
                      ),
                    ),
                  )
                  : const SizedBox.shrink(key: ValueKey('complete-hidden')),
        );
      });
    }

    return const SizedBox.shrink();
  }

  // Ã¢â€â‚¬Ã¢â€â‚¬ Rider list row Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
  Widget _buildRiderRow(SharedRiderItem r) {
    final active = sharedRideController.activeTarget.value;
    final isActive = active?.bookingId == r.bookingId;
    final isDropped = r.stage == SharedRiderStage.dropped;
    final isExpanded = _expandedCards.contains(r.bookingId);

    String stageLabel;
    Color stageColor;
    switch (r.stage) {
      case SharedRiderStage.waitingPickup:
        stageLabel = 'Pending pickup';
        stageColor = _C.blue;
        break;
      case SharedRiderStage.onboardDrop:
        stageLabel = 'In car - drop pending';
        stageColor = _C.green;
        break;
      case SharedRiderStage.dropped:
        stageLabel = 'Dropped';
        stageColor = _C.textMuted;
        break;
    }

    return Opacity(
      opacity: isDropped ? 0.45 : 1.0,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isActive ? _C.greenLight : _C.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive ? _C.green : _C.border,
            width: isActive ? 1.5 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: isActive ? _C.green.withOpacity(0.08) : _C.shadow,
              blurRadius: isActive ? 16 : 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar
            Stack(
              children: [
                ClipOval(
                  child: CachedNetworkImage(
                    imageUrl: r.profilePic,
                    height: 44,
                    width: 44,
                    fit: BoxFit.cover,
                    placeholder: (c, u) => _avatarPlaceholder(),
                    errorWidget: (c, u, e) => _avatarPlaceholder(),
                  ),
                ),
                if (isActive)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: _C.green,
                        shape: BoxShape.circle,
                        border: Border.all(color: _C.surface, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 10),

            // Info
            Expanded(
              child: InkWell(
                onTap: () {
                  if (!mounted || _isDisposing) return;
                  setState(() {
                    if (isExpanded) {
                      _expandedCards.remove(r.bookingId);
                    } else {
                      _expandedCards.add(r.bookingId);
                    }
                  });
                },
                borderRadius: BorderRadius.circular(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            r.name,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: _C.text,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: stageColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            stageLabel,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: stageColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        AnimatedRotation(
                          turns: isExpanded ? 0.5 : 0.0,
                          duration: const Duration(milliseconds: 200),
                          child: const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 18,
                            color: _C.textMuted,
                          ),
                        ),
                      ],
                    ),
                    AnimatedCrossFade(
                      duration: const Duration(milliseconds: 220),
                      crossFadeState:
                          isExpanded
                              ? CrossFadeState.showSecond
                              : CrossFadeState.showFirst,
                      firstChild: const SizedBox(height: 0),
                      secondChild: Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _addrLine(
                              Icons.radio_button_checked,
                              _C.green,
                              'Pickup: ${r.pickupAddress}',
                            ),
                            const SizedBox(height: 4),
                            _addrLine(
                              Icons.location_on_rounded,
                              _C.red,
                              'Drop: ${r.dropoffAddress}',
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

            // Set as next button
            if (!isDropped)
              GestureDetector(
                onTap: () => _setAsNextStop(r),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isActive ? _C.greenLight : _C.blueLight,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color:
                          isActive
                              ? _C.green.withOpacity(0.3)
                              : _C.blue.withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    isActive ? 'Active' : 'Next',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isActive ? _C.greenText : _C.blue,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Ã¢â€â‚¬Ã¢â€â‚¬ Bottom sheet Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
  Widget _buildBottomSheet() {
    return DraggableScrollableSheet(
      initialChildSize: 0.50,
      minChildSize: 0.40,
      maxChildSize: 0.85,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: _C.bg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Color(0x1A000000),
                blurRadius: 24,
                offset: Offset(0, -6),
              ),
            ],
          ),
          child: Obx(() {
            final active = sharedRideController.activeTarget.value;
            return ListView(
              controller: scrollController,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                // Handle
                const SizedBox(height: 10),
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: _C.border,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                if (!driverCompletedRide && active != null) ...[
                  // Active info card
                  _buildActiveInfoCard(active),
                  const SizedBox(height: 12),

                  // ETA
                  _buildEtaRow(active),

                  const SizedBox(height: 16),
                ],

                // Divider + section label
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Row(
                    children: [
                      const Text(
                        'All Stops',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _C.text,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _C.greenLight,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${sharedRideController.riders.length}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _C.greenText,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                if (sharedRideController.riders.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text(
                      'No riders in this shared trip',
                      style: TextStyle(color: _C.textSub, fontSize: 13),
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children:
                          sharedRideController.riders
                              .map(_buildRiderRow)
                              .toList(),
                    ),
                  ),

                // Bottom actions
                const SizedBox(height: 8),
                _buildBottomActions(),
              ],
            );
          }),
        );
      },
    );
  }

  // Ã¢â€â‚¬Ã¢â€â‚¬ Bottom actions (Stop requests / Cancel) Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
  Widget _buildBottomActions() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        children: [
          Container(
            height: 1,
            color: _C.border,
            margin: const EdgeInsets.only(bottom: 14),
          ),
          Obx(() {
            final stopped = driverStatusController.isStopNewRequests.value;
            return Buttons.button(
              borderColor: AppColors.buttonBorder,
              buttonColor:
                  stopped ? AppColors.containerColor : AppColors.commonWhite,
              borderRadius: 8,
              textColor: AppColors.commonBlack,
              onTap:
                  stopped
                      ? null
                      : () => Buttons.showDialogBox(
                        context: context,
                        onConfirmStop: () async {
                          await driverStatusController.stopNewRideRequest(
                            context: context,
                            stop: true,
                          );
                        },
                      ),
              text: Text(
                stopped ? 'Already Stopped' : 'Stop New Ride Requests',
              ),
            );
          }),
          const SizedBox(height: 10),
          Buttons.button(
            borderRadius: 8,
            buttonColor: AppColors.red,
            onTap:
                () => Buttons.showCancelRideBottomSheet(
                  context,
                  onConfirmCancel: (reason) async {
                    if (Get.isBottomSheetOpen == true) Get.back();
                    await driverStatusController.cancelBooking(
                      context,
                      bookingId: widget.bookingId,
                      reason: reason,
                      silent: true,
                      navigate: true,
                    );
                  },
                ),
            text: const Text('Cancel this Shared Ride'),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // Ã¢â€â‚¬Ã¢â€â‚¬ Build Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
  @override
  Widget build(BuildContext context) {
    final driverPos = _animatedDriverPos ?? widget.driverLocation;
    final active = sharedRideController.activeTarget.value;
    final rawTargetPos =
        active == null
            ? widget.pickupLocation
            : (active.stage == SharedRiderStage.waitingPickup
                ? active.pickupLatLng
                : active.dropLatLng);
    final targetPos = _adjustedTargetPos ?? rawTargetPos;

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
      ..._maneuverMarkers,
      if (active != null)
        Marker(
          markerId: const MarkerId('target_bounds'),
          position: targetPos,
          visible: false,
          infoWindow: InfoWindow.noText,
        ),
    };

    return NoInternetOverlay(
      child: WillPopScope(
        onWillPop: () async => false,
        child: Scaffold(
          backgroundColor: _C.bg,
          body: Stack(
            children: [
              // Map
              SizedBox(
                height: 560,
                width: double.infinity,
                child: SharedMap(
                  key: _mapKey,
                  followDriver: _isDriverFocused,
                  followZoom: _followZoom,
                  followTilt: 45,
                  initialPosition: targetPos,
                  pickupPosition: targetPos,
                  pickupIndicatorStyle: PickupIndicatorStyle.pulse,
                  pickupIndicatorColor: const Color(0xFF00A85E),
                  pickupTargetColor: AppColors.commonBlack,
                  markers: markers,
                  polylines: RideRouteOverlays.buildRoutePolylines(
                    routePoints: polylinePoints,
                    origin: driverPos,
                    destination: targetPos,
                    idPrefix: 'route_shared',
                  ),
                  // Avoid GoogleMap my-location layer blocking map render when
                  // permission/service is off. Driver marker already represents
                  // the current position.
                  myLocationEnabled: false,
                  fitToBounds: true,
                ),
              ),

              // Direction header
              Positioned(
                top: 52,
                left: 0,
                right: 0,
                child: _buildDirectionHeader(),
              ),

              // Offline banner
              _buildOfflineBanner(),

              // Off-route banner
              _buildOffRouteBanner(),

              // Map control buttons
              Positioned(
                top: 172,
                right: 14,
                child: SafeArea(
                  child: Column(
                    children: [
                      ValueListenableBuilder<bool>(
                        valueListenable:
                            NavigationVoiceService.instance.mutedNotifier,
                        builder:
                            (context, muted, _) => _buildMapControlBtn(
                              icon:
                                  muted
                                      ? Icons.volume_off_rounded
                                      : Icons.volume_up_rounded,
                              iconColor: muted ? _C.red : _C.green,
                              onTap:
                                  () =>
                                      NavigationVoiceService.instance
                                          .toggleMuted(),
                            ),
                      ),
                      const SizedBox(height: 10),
                      MapFocusToggleButton(
                        isDriverFocused: _isDriverFocused,
                        accentColor: _C.green,
                        onFocusDriver: () async {
                          final ms = _mapKey.currentState;
                          if (ms == null) return;
                          await ms.focusDriver(zoom: _followZoom, tilt: 45);
                        },
                        onFitBounds: () {
                          final ms = _mapKey.currentState;
                          if (ms == null) return;
                          ms.pauseAutoFollow(const Duration(seconds: 4));
                          final pts = polylinePoints;
                          if (pts.length >= 2) {
                            ms.fitPolylineBounds(pts);
                          } else {
                            ms.fitRouteBounds();
                          }
                        },
                        onDriverFocusedChanged: (v) {
                          if (!mounted || _isDisposing) return;
                          setState(() => _isDriverFocused = v);
                        },
                      ),
                    ],
                  ),
                ),
              ),

              // Bottom sheet
              _buildBottomSheet(),

              // Booking overlay
              const BookingOverlayRequest(allowNavigate: true),
            ],
          ),
        ),
      ),
    );
  }
}

// Ã¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢Â
// HELPER FUNCTIONS
// Ã¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢Â

Widget _avatarPlaceholder() => Container(
  width: 44,
  height: 44,
  decoration: BoxDecoration(
    shape: BoxShape.circle,
    color: _C.borderLight,
    border: Border.all(color: _C.border),
  ),
  child: const Icon(Icons.person, color: _C.textMuted, size: 22),
);

Widget _addrDot(Color color, {bool glowing = false}) => Container(
  width: 11,
  height: 11,
  decoration: BoxDecoration(
    shape: BoxShape.circle,
    color: color.withOpacity(0.15),
    border: Border.all(color: color, width: 2),
    boxShadow:
        glowing
            ? [BoxShadow(color: color.withOpacity(0.3), blurRadius: 5)]
            : null,
  ),
);

Widget _addrLine(IconData icon, Color color, String text) => Row(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Icon(icon, size: 13, color: color),
    const SizedBox(width: 5),
    Expanded(
      child: Text(
        text,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 11, color: _C.textSub, height: 1.4),
      ),
    ),
  ],
);

// import 'dart:async';
// import 'dart:math' as math;
// import 'dart:ui' as ui;

// import 'package:action_slider/action_slider.dart';
// import 'package:cached_network_image/cached_network_image.dart';
// import 'package:connectivity_plus/connectivity_plus.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:geocoding/geocoding.dart';
// import 'package:geolocator/geolocator.dart';
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
// import 'package:hopper/utils/map/navigation_assist.dart';
// import 'package:hopper/utils/map/driver_message_suggestions.dart';
// import 'package:hopper/utils/map/navigation_voice_service.dart';
// import 'package:hopper/utils/map/shared_map.dart';
// import 'package:hopper/utils/netWorkHandling/network_handling_screen.dart';
// import 'package:hopper/utils/sharedprefsHelper/sharedprefs_handler.dart';

// import '../../../../../utils/websocket/socket_io_client.dart';
// import '../Controller/booking_request_controller.dart';

// class _QueuedSocketEmit {
//   final String event;
//   final Map<String, dynamic> payload;
//   const _QueuedSocketEmit({required this.event, required this.payload});
// }

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
//     this.shouldTick,
//   });

//   final void Function(LatLng pos, double bearing) onTick;
//   final Duration duration;
//   final int fps;

//   /// Ã¢Å“â€¦ External guard (ex: widget disposing)
//   final bool Function()? shouldTick;

//   Timer? _timer;

//   LatLng? _fromPos;
//   LatLng? _toPos;

//   double _fromBearing = 0;
//   double _toBearing = 0;

//   int _step = 0;
//   int get _totalSteps =>
//       math.max(1, (duration.inMilliseconds / (1000 / fps)).round());

//   void dispose() => _timer?.cancel();

//   void jumpTo(LatLng pos, double bearing) {
//     _timer?.cancel();
//     if (shouldTick != null && shouldTick!() == false) return;
//     onTick(pos, _normalizeBearing(bearing));
//   }

//   void animateTo(LatLng newPos, double newBearing) {
//     final nb = _normalizeBearing(newBearing);

//     // if first time
//     if (_toPos == null) {
//       _fromPos = newPos;
//       _toPos = newPos;
//       _fromBearing = nb;
//       _toBearing = nb;
//       if (shouldTick != null && shouldTick!() == false) return;
//       onTick(newPos, nb);
//       return;
//     }

//     _timer?.cancel();
//     _step = 0;

//     _fromPos = _toPos;
//     _toPos = newPos;

//     _fromBearing = _toBearing;
//     _toBearing = _shortestAngleTarget(_fromBearing, nb);

//     final total = _totalSteps;
//     _timer = Timer.periodic(Duration(milliseconds: (1000 / fps).round()), (t) {
//       if (shouldTick != null && shouldTick!() == false) {
//         t.cancel();
//         return;
//       }

//       _step++;
//       final p = (_step / total).clamp(0.0, 1.0);
//       final eased = Curves.easeOutCubic.transform(p);

//       final pos = _lerpLatLng(_fromPos!, _toPos!, eased);
//       final bearing = _lerpDouble(_fromBearing, _toBearing, eased);

//       onTick(pos, _normalizeBearing(bearing));

//       if (p >= 1.0) t.cancel();
//     });
//   }

//   // ---------- helpers ----------
//   static LatLng _lerpLatLng(LatLng a, LatLng b, double t) {
//     final lat = a.latitude + (b.latitude - a.latitude) * t;
//     final lng = a.longitude + (b.longitude - a.longitude) * t;
//     return LatLng(lat, lng);
//   }

//   static double _lerpDouble(double a, double b, double t) => a + (b - a) * t;

//   static double _normalizeBearing(double b) {
//     var x = b % 360;
//     if (x < 0) x += 360;
//     return x;
//   }

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

// class _ThemeC {
//   static const bg = Color(0xFFF4F6FA);
//   static const surface = Color(0xFFFFFFFF);
//   static const surfaceAlt = Color(0xFFF8F9FC);

//   static const green = Color(0xFF00A85E);
//   static const greenLight = Color(0xFFE6F7F0);
//   static const greenBorder = Color(0x4000A85E);
//   static const greenText = Color(0xFF00874C);

//   static const red = Color(0xFFE53935);
//   static const redLight = Color(0xFFFFF0F0);
//   static const blue = Color(0xFF1976D2);
//   static const blueLight = Color(0xFFE8F1FB);
//   static const amber = Color(0xFFF59E0B);
//   static const amberLight = Color(0xFFFFFBEB);

//   static const text = Color(0xFF111827);
//   static const textSub = Color(0xFF6B7280);
//   static const textMuted = Color(0xFF9CA3AF);

//   static const border = Color(0xFFE5E7EB);
//   static const borderLight = Color(0xFFF3F4F6);

//   static const shadow = Color(0x14000000);
//   static const shadowMd = Color(0x1F000000);
// }

// class ShareRideStartScreen extends StatefulWidget {
//   final String bookingId; // pool / main booking
//   final LatLng pickupLocation;
//   final LatLng driverLocation;

//   const ShareRideStartScreen({
//     Key? key,
//     required this.pickupLocation,
//     required this.driverLocation,
//     required this.bookingId,
//   }) : super(key: key);

//   @override
//   State<ShareRideStartScreen> createState() => _ShareRideStartScreenState();
// }

// class _ShareRideStartScreenState extends State<ShareRideStartScreen>
//     with SingleTickerProviderStateMixin {
//   late final DriverRouteController _routeController;

//   final SharedController sharedController = Get.put(SharedController());
//   final DriverStatusController driverStatusController = Get.put(
//     DriverStatusController(),
//   );
//   final BookingRequestController bookingController =
//   Get.find<BookingRequestController>();
//   final SharedRideController sharedRideController =
//   Get.find<SharedRideController>();

//   final GlobalKey<SharedMapState> _mapKey = GlobalKey<SharedMapState>();

//   // Animated driver marker state
//   LatLng? _animatedDriverPos;
//   double _animatedBearing = 0.0;

//   // Route data
//   List<LatLng> polylinePoints = const [];
//   String directionText = '';
//   String distance = '';
//   String maneuver = '';

//   BitmapDescriptor? carIcon;
//   late SocketService socketService;

//   bool driverCompletedRide = false;
//   bool _isDriverFocused = false;
//   bool _leavingScreen = false;
//   bool _isNetworkOffline = false;
//   bool _isOffRouteAlert = false;
//   int _pendingQueueCount = 0;
//   double _followZoom = 15.0;

//   /// Ã¢Å“â€¦ critical: prevents setState while element is defunct
//   bool _isDisposing = false;

//   late final _MarkerAnimator _markerAnimator;

//   // UI update throttle
//   DateTime? _lastUiUpdate;
//   List<LatLng>? _lastPolyline;
//   String _lastDirectionText = '';
//   String _lastDistanceText = '';
//   String _lastManeuver = '';

//   late final AnimationController _pulseController;
//   StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
//   final List<_QueuedSocketEmit> _socketRetryQueue = <_QueuedSocketEmit>[];
//   String? _driverId;
//   DateTime? _lastSpeedAt;
//   LatLng? _lastSpeedPos;

//   final Set<String> _expandedCards = <String>{};

//   // -------------------- SAFE EXIT --------------------
//   Future<void> _exitToHomeSafely() async {
//     if (_leavingScreen) return;
//     _leavingScreen = true;

//     try {
//       Get.closeAllSnackbars();
//     } catch (_) {}
//     try {
//       if (Get.isBottomSheetOpen == true) Get.back();
//     } catch (_) {}
//     try {
//       if (Get.isDialogOpen == true) Get.back();
//     } catch (_) {}

//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       if (!mounted || _isDisposing) return;
//       if (Get.currentRoute == '/DriverMainScreen') return;
//       Get.offAll(() => const DriverMainScreen());
//     });
//   }

//   Future<void> _loadDriverId() async {
//     _driverId = await SharedPrefHelper.getDriverId();
//   }

//   void _initConnectivityWatchdog() {
//     _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
//       final offline = results.every((r) => r == ConnectivityResult.none);
//       if (mounted && !_isDisposing) {
//         setState(() => _isNetworkOffline = offline);
//       } else {
//         _isNetworkOffline = offline;
//       }
//       if (offline) return;
//       if (!socketService.connected) {
//         socketService.connect();
//       }
//       _flushSocketRetryQueue();
//     });
//   }

//   @override
//   void initState() {
//     super.initState();

//     SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
//     SystemChrome.setSystemUIOverlayStyle(
//       const SystemUiOverlayStyle(
//         statusBarColor: Colors.transparent,
//         statusBarIconBrightness: Brightness.dark,
//       ),
//     );

//     _animatedDriverPos = widget.driverLocation;

//     _markerAnimator = _MarkerAnimator(
//       shouldTick: () => mounted && !_isDisposing,
//       onTick: (pos, bearing) {
//         if (!mounted || _isDisposing) return;
//         setState(() {
//           _animatedDriverPos = pos;
//           _animatedBearing = bearing;
//         });
//       },
//     );

//     _initSocket();
//     _initConnectivityWatchdog();
//     _loadDriverId();
//     _loadMarkerIcons();

//     final initialTarget = sharedRideController.activeTarget.value;
//     final initialDestination =
//     initialTarget == null
//         ? widget.pickupLocation
//         : (initialTarget.stage == SharedRiderStage.waitingPickup
//         ? initialTarget.pickupLatLng
//         : initialTarget.dropLatLng);

//     _routeController = DriverRouteController(
//       destination: initialDestination,
//       onRouteUpdate: (update) {
//         // if screen is closing, ignore ALL ticks
//         if (!mounted || _isDisposing) return;

//         // 1) Smooth marker always
//         _markerAnimator.animateTo(update.driverLocation, update.bearing);

//         // 2) Update controller store for other logic
//         sharedRideController.updateDriverLocation(update.driverLocation);
//         _updateSmartAutoZoom(update.driverLocation);

//         // 3) Throttle heavy UI updates (polyline, text)
//         final now = DateTime.now();
//         if (_lastUiUpdate != null &&
//             now.difference(_lastUiUpdate!).inMilliseconds < 300) {
//           return;
//         }
//         _lastUiUpdate = now;

//         final poly = update.polylinePoints;
//         final dText = update.directionText;
//         final distText = update.distanceText;
//         final man = update.maneuver;

//         final polyChanged =
//             _lastPolyline == null ||
//                 poly.length != _lastPolyline!.length ||
//                 (poly.isNotEmpty &&
//                     _lastPolyline!.isNotEmpty &&
//                     (poly.first != _lastPolyline!.first ||
//                         poly.last != _lastPolyline!.last));

//         final textChanged =
//             dText != _lastDirectionText ||
//                 distText != _lastDistanceText ||
//                 man != _lastManeuver;
//         final offRouteNow = _isOffRoute(update.driverLocation, poly);

//         if (!mounted || _isDisposing) return;
//         if (!polyChanged && !textChanged && _isOffRouteAlert == offRouteNow) {
//           return;
//         }

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
//           _isOffRouteAlert = offRouteNow;
//         });

//         final active = sharedRideController.activeTarget.value;
//         final etaMinutes =
//             active != null && active.stage == SharedRiderStage.waitingPickup
//                 ? sharedController.pickupDurationInMin.value
//                 : sharedController.dropDurationInMin.value;
//         Get.find<DriverAnalyticsController>().setSlaFromEtaMinutes(etaMinutes);
//         final voiceLine = NavigationAssist.buildVoiceLine(
//           maneuver: man,
//           distanceText: distText,
//           directionText: dText,
//         );
//         NavigationVoiceService.instance.speakTurn(voiceLine);
//       },
//       onCameraUpdate: (_) {},
//     );

//     _routeController.start();

//     // Ã¢Å“â€¦ if you need pulse later, keep it but do NOT call setState in listener
//     _pulseController = AnimationController(
//       vsync: this,
//       duration: const Duration(seconds: 2),
//     )..repeat();
//   }

//   @override
//   void dispose() {
//     // Ã¢Å“â€¦ IMPORTANT: set first to stop setState during disposal window
//     _isDisposing = true;
//     _connectivitySub?.cancel();

//     // stop animations/timers FIRST
//     try {
//       _markerAnimator.dispose();
//     } catch (_) {}
//     try {
//       _routeController.dispose();
//     } catch (_) {}
//     try {
//       _pulseController.stop();
//       _pulseController.dispose();
//     } catch (_) {}

//     // socket cleanup
//     try {
//       socketService.socket.off('driver-reached-destination');
//       socketService.socket.off('driver-location');
//       socketService.socket.off('driver-cancelled');
//       socketService.socket.off('customer-cancelled');
//       socketService.socket.off('joined-booking');
//       socketService.socket.off('booking-request');

//       // if supported by your socket client:
//       try {
//         socketService.socket.offAny();
//       } catch (_) {}

//       try {
//         // socketService.disconnect();
//       } catch (_) {}
//     } catch (_) {}

//     super.dispose();
//   }

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

//   double? _safeNum(dynamic v) {
//     if (v == null) return null;
//     try {
//       return (v as num).toDouble();
//     } catch (_) {
//       return null;
//     }
//   }

//   // -------------------- SOCKET --------------------
//   Future<void> _initSocket() async {
//     socketService = SocketService();

//     socketService.on('driver-reached-destination', (data) {
//       if (!mounted || _isDisposing) return;
//       final status = data?['status'];
//       if (status == true || status?.toString() == 'true') {
//         setState(() => driverCompletedRide = true);
//         CommonLogger.log.i('Ã¢Å“â€¦ Driver reached destination');
//       }
//     });

//     socketService.on('joined-booking', (data) async {
//       try {
//         CommonLogger.log.i("[SHARED START] joined-booking Ã¢â€ â€™ $data");
//         if (!mounted || _isDisposing || data == null) return;

//         final customerLoc = data['customerLocation'];
//         if (customerLoc == null) return;

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

//         if (fromLat == null ||
//             fromLng == null ||
//             toLat == null ||
//             toLng == null) {
//           return;
//         }

//         final pickupAddrs = await getAddressFromLatLng(fromLat, fromLng);
//         final dropoffAddrs = await getAddressFromLatLng(toLat, toLng);

//         final String bookingIdStr = data['bookingId']?.toString() ?? '';
//         if (bookingIdStr.isEmpty) return;

//         final riders = sharedRideController.riders;
//         final existingIndex = riders.indexWhere(
//               (r) => r.bookingId.toString() == bookingIdStr,
//         );

//         if (existingIndex == -1) {
//           riders.add(
//             SharedRiderItem(
//               bookingId: bookingIdStr,
//               name: data['customerName']?.toString() ?? 'Rider',
//               phone: data['customerPhone']?.toString() ?? '',
//               profilePic:
//               data['customerProfilePic']?.toString() ??
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
//             data['customerProfilePic']?.toString() ??
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

//         var active = sharedRideController.activeTarget.value;
//         if (active == null || riders.length == 1) {
//           sharedRideController.setActiveTarget(
//             bookingIdStr,
//             SharedRiderStage.waitingPickup,
//           );
//           active = sharedRideController.activeTarget.value;
//         }

//         if (active != null) {
//           final dest =
//           active.stage == SharedRiderStage.waitingPickup
//               ? active.pickupLatLng
//               : active.dropLatLng;

//           sharedController.pickupDistanceInMeters.value = 0;
//           sharedController.pickupDurationInMin.value = 0;
//           sharedController.dropDistanceInMeters.value = 0;
//           sharedController.dropDurationInMin.value = 0;

//           await _routeController.updateDestination(dest);
//           _mapKey.currentState?.focusPickup();
//         }

//         if (!mounted || _isDisposing) return;
//         setState(() {});
//       } catch (e, st) {
//         CommonLogger.log.e('[SHARED START] Error joined-booking');
//         debugPrint('$e');
//         debugPrint('$st');
//       }
//     });

//     socketService.on('booking-request', (data) async {
//       if (!mounted || _isDisposing) return;
//       if (data == null) return;

//       final incomingId = data['bookingId']?.toString();
//       if (incomingId == widget.bookingId) return;

//       if (incomingId != null &&
//           incomingId == bookingController.lastHandledBookingId.value) {
//         return;
//       }

//       final pickup = data['pickupLocation'];
//       final drop = data['dropLocation'];
//       if (pickup == null || drop == null) return;

//       final pickupAddr = await getAddressFromLatLng(
//         _safeNum(pickup['latitude']) ?? 0,
//         _safeNum(pickup['longitude']) ?? 0,
//       );
//       final dropAddr = await getAddressFromLatLng(
//         _safeNum(drop['latitude']) ?? 0,
//         _safeNum(drop['longitude']) ?? 0,
//       );

//       if (!mounted || _isDisposing) return;
//       bookingController.showRequest(
//         rawData: data,
//         pickupAddress: pickupAddr,
//         dropAddress: dropAddr,
//       );
//     });

//     socketService.on('driver-cancelled', (data) async {
//       if (data?['status'] == true) await _exitToHomeSafely();
//     });

//     socketService.on('customer-cancelled', (data) async {
//       if (data?['status'] == true) await _exitToHomeSafely();
//     });

//     if (!socketService.connected) {
//       socketService.connect();
//       socketService.onConnect(
//             () {
//           CommonLogger.log.i('[SHARED START] socket connected');
//           _flushSocketRetryQueue();
//         },
//       );
//     }
//   }

//   Future<BitmapDescriptor> _bitmapFromAsset(
//       String path, {
//         int width = 48,
//       }) async {
//     final data = await rootBundle.load(path);
//     final codec = await ui.instantiateImageCodec(
//       data.buffer.asUint8List(),
//       targetWidth: width,
//     );
//     final frame = await codec.getNextFrame();
//     final bytes = await frame.image.toByteData(format: ui.ImageByteFormat.png);
//     return BitmapDescriptor.fromBytes(bytes!.buffer.asUint8List());
//   }

//   Future<void> _loadMarkerIcons() async {
//     try {
//       final icon = await _bitmapFromAsset(AppImages.movingCar, width: 74);
//       if (!mounted || _isDisposing) return;
//       setState(() => carIcon = icon);
//     } catch (_) {
//       carIcon = BitmapDescriptor.defaultMarker;
//     }
//   }

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

//   String _formatDistance(double meters) {
//     final km = meters / 1000.0;
//     if (meters <= 0) return '0 Km';
//     return '${km.toStringAsFixed(1)} Km';
//   }

//   String _formatDuration(double minutes) {
//     if (minutes <= 0) return '0 min';
//     final total = minutes.round();
//     final h = total ~/ 60;
//     final m = total % 60;
//     return h > 0 ? '$h hr $m min' : '$m min';
//   }

//   LatLng _destinationForTarget(SharedRiderItem rider) {
//     return rider.stage == SharedRiderStage.waitingPickup
//         ? rider.pickupLatLng
//         : rider.dropLatLng;
//   }

//   bool _isOffRoute(LatLng current, List<LatLng> polyline) {
//     if (polyline.isEmpty) return false;
//     for (final p in polyline) {
//       final d = Geolocator.distanceBetween(
//         current.latitude,
//         current.longitude,
//         p.latitude,
//         p.longitude,
//       );
//       if (d < 28.0) return false;
//     }
//     return true;
//   }

//   void _updateSmartAutoZoom(LatLng current) {
//     double kmh = 0;
//     if (_lastSpeedPos != null && _lastSpeedAt != null) {
//       final dt = DateTime.now().difference(_lastSpeedAt!).inMilliseconds / 1000.0;
//       if (dt > 0.2) {
//         final d = Geolocator.distanceBetween(
//           _lastSpeedPos!.latitude,
//           _lastSpeedPos!.longitude,
//           current.latitude,
//           current.longitude,
//         );
//         kmh = (d / dt) * 3.6;
//       }
//     }
//     _lastSpeedPos = current;
//     _lastSpeedAt = DateTime.now();

//     double targetZoom;
//     if (kmh >= 55) {
//       targetZoom = 14.1;
//     } else if (kmh >= 30) {
//       targetZoom = 14.7;
//     } else if (kmh >= 15) {
//       targetZoom = 15.2;
//     } else {
//       targetZoom = 15.8;
//     }
//     _followZoom = (_followZoom * 0.75) + (targetZoom * 0.25);
//   }

//   Future<void> _sendQuickMessage(
//     SharedRiderItem rider,
//     String text, {
//     int? delayMinutes,
//   }) async {
//     final driverId = _driverId ?? await SharedPrefHelper.getDriverId();
//     final payload = <String, dynamic>{
//       'bookingId': rider.bookingId,
//       'driverId': driverId,
//       'delayMinutes': (delayMinutes ?? 0) < 0 ? 0 : (delayMinutes ?? 0),
//       'message': text,
//     };
//     if (_isNetworkOffline || !socketService.connected) {
//       _enqueueSocketEmit('driver-message', payload);
//       return;
//     }
//     socketService.emitWithAck('driver-message', payload, (ack) {
//       final ok = (ack is Map && ack['success'] == true);
//       if (!ok) {
//         _enqueueSocketEmit('driver-message', payload);
//       }
//     });
//   }

//   void _enqueueSocketEmit(String event, Map<String, dynamic> payload) {
//     _socketRetryQueue.add(_QueuedSocketEmit(event: event, payload: payload));
//     if (mounted && !_isDisposing) {
//       setState(() => _pendingQueueCount = _socketRetryQueue.length);
//     } else {
//       _pendingQueueCount = _socketRetryQueue.length;
//     }
//   }

//   void _flushSocketRetryQueue() {
//     if (_socketRetryQueue.isEmpty || !socketService.connected) return;
//     final queued = List<_QueuedSocketEmit>.from(_socketRetryQueue);
//     _socketRetryQueue.clear();
//     if (mounted && !_isDisposing) {
//       setState(() => _pendingQueueCount = 0);
//     } else {
//       _pendingQueueCount = 0;
//     }
//     for (final q in queued) {
//       socketService.emitWithAck(q.event, q.payload, (ack) {
//         final ok = (ack is Map && ack['success'] == true);
//         if (!ok) {
//           _enqueueSocketEmit(q.event, q.payload);
//         }
//       });
//     }
//   }

//   // -------------------- NAV / TARGET --------------------
//   Future<void> _setAsNextStop(SharedRiderItem r) async {
//     if (!mounted || _isDisposing) return;
//     if (r.stage == SharedRiderStage.dropped) return;

//     sharedRideController.setActiveTarget(r.bookingId, r.stage);

//     final ctrl = r.sliderController as ActionSliderController?;
//     ctrl?.reset();

//     final dest =
//     r.stage == SharedRiderStage.waitingPickup
//         ? r.pickupLatLng
//         : r.dropLatLng;

//     sharedController.pickupDistanceInMeters.value = 0;
//     sharedController.pickupDurationInMin.value = 0;
//     sharedController.dropDistanceInMeters.value = 0;
//     sharedController.dropDurationInMin.value = 0;

//     await _routeController.updateDestination(dest);
//     _mapKey.currentState?.focusPickup();

//     if (!mounted || _isDisposing) return;
//     setState(() {});
//   }

//   Future<void> _onCurrentLegCompleted(SharedRiderItem completedRider) async {
//     if (!mounted || _isDisposing) return;

//     final bool? cashCollected = await Navigator.push<bool>(
//       context,
//       MaterialPageRoute(
//         builder: (_) => CashCollectedScreen(
//           name: completedRider.name,
//           imageUrl: completedRider.profilePic,
//           bookingId: completedRider.bookingId,
//           Amount: completedRider.amount,
//           isSharedRide: true,
//         ),
//       ),
//     );

//     if (!mounted || _isDisposing) return;
//     if (cashCollected != true) return;

//     sharedRideController.markDropped(completedRider.bookingId);

//     try {
//       final doneCtrl =
//       completedRider.sliderController as ActionSliderController?;
//       doneCtrl?.reset();
//     } catch (_) {}

//     final next = sharedRideController.recomputeNextTarget();

//     if (next == null) {
//       if (!mounted || _isDisposing) return;
//       Navigator.pushAndRemoveUntil(
//         context,
//         MaterialPageRoute(builder: (_) => const DriverMainScreen()),
//             (route) => false,
//       );
//       return;
//     }

//     sharedRideController.setActiveTarget(next.bookingId, next.stage);

//     final nextCtrl = next.sliderController as ActionSliderController?;
//     nextCtrl?.reset();

//     final dest =
//     next.stage == SharedRiderStage.waitingPickup
//         ? next.pickupLatLng
//         : next.dropLatLng;
//     await _routeController.updateDestination(dest);

//     if (!mounted || _isDisposing) return;
//     setState(() {});
//   }

//   // -------------------- UI PIECES --------------------
//   Widget _buildMapControlBtn({
//     required IconData icon,
//     required VoidCallback onTap,
//     Color? iconColor,
//   }) {
//     return GestureDetector(
//       onTap: onTap,
//       child: Container(
//         width: 44,
//         height: 44,
//         decoration: BoxDecoration(
//           color: _ThemeC.surface,
//           borderRadius: BorderRadius.circular(14),
//           border: Border.all(color: _ThemeC.border),
//           boxShadow: const [
//             BoxShadow(
//               color: _ThemeC.shadowMd,
//               blurRadius: 12,
//               offset: Offset(0, 4),
//             ),
//           ],
//         ),
//         child: Icon(
//           icon,
//           size: 20,
//           color: iconColor ?? _ThemeC.textSub,
//         ),
//       ),
//     );
//   }

//   Widget _buildDirectionHeader() {
//     final safeDistance = distance.isEmpty ? '--' : distance;
//     final safeDirection =
//         directionText.isEmpty ? 'Searching best route...' : directionText;
//     final m = maneuver.toLowerCase();
//     final isTurnAlert =
//         m.contains('left') || m.contains('right') || m.contains('uturn') || m.contains('roundabout');
//     final leftColor = isTurnAlert ? const Color(0xFFFC1212) : const Color(0xFFF1A500);
//     final rightColor = isTurnAlert ? const Color(0xFFE10606) : const Color(0xFFC88700);

//     return Container(
//       margin: const EdgeInsets.symmetric(horizontal: 14),
//       decoration: BoxDecoration(
//         borderRadius: BorderRadius.circular(18),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.12),
//             blurRadius: 20,
//             offset: const Offset(0, 6),
//           ),
//         ],
//       ),
//       child: ClipRRect(
//         borderRadius: BorderRadius.circular(18),
//         child: SizedBox(
//           height: 80,
//           child: Row(
//             children: [
//               Expanded(
//                 flex: 2,
//                 child: Container(
//                   color: leftColor,
//                   padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
//                   child: Column(
//                     mainAxisAlignment: MainAxisAlignment.center,
//                     children: [
//                       Icon(
//                         NavigationAssist.iconForManeuver(maneuver),
//                         size: 25,
//                         color: Colors.white,
//                       ),
//                       const SizedBox(height: 4),
//                       Text(
//                         safeDistance,
//                         maxLines: 1,
//                         overflow: TextOverflow.ellipsis,
//                         style: const TextStyle(
//                           fontSize: 13,
//                           fontWeight: FontWeight.w700,
//                           color: Colors.white,
//                           letterSpacing: 0.2,
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//               Expanded(
//                 flex: 5,
//                 child: Container(
//                   color: rightColor,
//                   padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
//                   child: Align(
//                     alignment: Alignment.centerLeft,
//                     child: Text(
//                       safeDirection,
//                       maxLines: 2,
//                       overflow: TextOverflow.ellipsis,
//                       style: const TextStyle(
//                         fontSize: 14,
//                         fontWeight: FontWeight.w700,
//                         color: Colors.white,
//                         height: 1.2,
//                       ),
//                     ),
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildEtaRow(SharedRiderItem active) {
//     final isPickupLeg = active.stage == SharedRiderStage.waitingPickup;

//     return Obx(() {
//       final minutes = isPickupLeg
//           ? sharedController.pickupDurationInMin.value
//           : sharedController.dropDurationInMin.value;

//       final meters = isPickupLeg
//           ? sharedController.pickupDistanceInMeters.value
//           : sharedController.dropDistanceInMeters.value;

//       return Container(
//         margin: const EdgeInsets.symmetric(horizontal: 16),
//         padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
//         decoration: BoxDecoration(
//           color: _ThemeC.greenLight,
//           borderRadius: BorderRadius.circular(16),
//           border: Border.all(color: _ThemeC.greenBorder),
//         ),
//         child: Row(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             const Icon(Icons.schedule_rounded, color: _ThemeC.green, size: 17),
//             const SizedBox(width: 6),
//             Text(
//               _formatDuration(minutes),
//               style: const TextStyle(
//                 fontSize: 15,
//                 fontWeight: FontWeight.w700,
//                 color: _ThemeC.greenText,
//               ),
//             ),
//             const SizedBox(width: 14),
//             Container(
//               width: 4,
//               height: 4,
//               decoration: const BoxDecoration(
//                 color: _ThemeC.green,
//                 shape: BoxShape.circle,
//               ),
//             ),
//             const SizedBox(width: 14),
//             const Icon(Icons.route_rounded, color: _ThemeC.textSub, size: 17),
//             const SizedBox(width: 6),
//             Text(
//               _formatDistance(meters),
//               style: const TextStyle(
//                 fontSize: 15,
//                 fontWeight: FontWeight.w700,
//                 color: _ThemeC.text,
//               ),
//             ),
//           ],
//         ),
//       );
//     });
//   }

//   Widget _buildActiveActionArea(SharedRiderItem active) {
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

//               if (!mounted || _isDisposing) return;

//               if (result != null && result.status == 200) {
//                 sharedRideController.markArrived(active.bookingId);
//                 if (!mounted || _isDisposing) return;
//                 setState(() {});
//               } else {
//                 ScaffoldMessenger.of(context).showSnackBar(
//                   SnackBar(
//                     content: Text(result?.message ?? "Something went wrong"),
//                   ),
//                 );
//               }
//             } catch (_) {
//               if (!mounted || _isDisposing) return;
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

//     if (active.stage == SharedRiderStage.waitingPickup && active.arrived) {
//       final riderCtrl = active.sliderController as ActionSliderController;

//       return Padding(
//         padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
//         child: ActionSlider.standard(
//           key: ValueKey(
//             'start-${active.bookingId}-${active.stage}-${active.arrived}',
//           ),
//           controller: riderCtrl,
//           height: 52,
//           backgroundColor: _ThemeC.greenLight,
//           toggleColor: Colors.transparent,
//           customForegroundBuilder: (context, state, child) => Container(
//             margin: const EdgeInsets.all(5),
//             decoration: BoxDecoration(
//               color: _ThemeC.green,
//               borderRadius: BorderRadius.circular(12),
//               boxShadow: [
//                 BoxShadow(
//                   color: _ThemeC.green.withOpacity(0.35),
//                   blurRadius: 10,
//                   offset: const Offset(0, 4),
//                 ),
//               ],
//             ),
//             child: const Icon(
//               Icons.double_arrow_rounded,
//               color: Colors.white,
//               size: 24,
//             ),
//           ),
//           child: Text(
//             'Swipe to Start Ride for ${active.name}',
//             style: TextStyle(
//               color: _ThemeC.greenText.withOpacity(0.9),
//               fontSize: 14,
//               fontWeight: FontWeight.w700,
//             ),
//           ),
//           action: (controller) async {
//             try {
//               controller.loading();

//               final msg = await driverStatusController.otpRequest(
//                 context,
//                 bookingId: active.bookingId,
//                 custName: active.name,
//                 pickupAddress: active.pickupAddress,
//                 dropAddress: active.dropoffAddress,
//               );

//               if (!mounted || _isDisposing) return;

//               if (msg == null) {
//                 controller.failure();
//                 ScaffoldMessenger.of(context).showSnackBar(
//                   const SnackBar(content: Text('Failed to send OTP')),
//                 );
//                 await Future.delayed(const Duration(milliseconds: 700));
//                 controller.reset();
//                 return;
//               }

//               final verified = await Navigator.push<bool>(
//                 context,
//                 MaterialPageRoute(
//                   builder: (_) => VerifyRiderScreen(
//                     bookingId: active.bookingId,
//                     custName: active.name,
//                     pickupAddress: active.pickupAddress,
//                     dropAddress: active.dropoffAddress,
//                     isSharedRide: true,
//                   ),
//                 ),
//               );

//               if (!mounted || _isDisposing) return;

//               if (verified == true) {
//                 controller.success();
//                 sharedRideController.markOnboard(active.bookingId);
//                 await _setAsNextStop(active);
//               } else {
//                 controller.reset();
//               }
//             } catch (_) {
//               if (!mounted || _isDisposing) return;
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

//     if (active.stage == SharedRiderStage.onboardDrop) {
//       final riderSlider = active.sliderController as ActionSliderController;

//       return Padding(
//         padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
//         child: ActionSlider.standard(
//           key: ValueKey('complete-${active.bookingId}-${active.stage}'),
//           controller: riderSlider,
//           height: 52,
//           backgroundColor: _ThemeC.greenLight,
//           toggleColor: Colors.transparent,
//           customForegroundBuilder: (context, state, child) => Container(
//             margin: const EdgeInsets.all(5),
//             decoration: BoxDecoration(
//               color: _ThemeC.green,
//               borderRadius: BorderRadius.circular(12),
//               boxShadow: [
//                 BoxShadow(
//                   color: _ThemeC.green.withOpacity(0.35),
//                   blurRadius: 10,
//                   offset: const Offset(0, 4),
//                 ),
//               ],
//             ),
//             child: const Icon(
//               Icons.double_arrow_rounded,
//               color: Colors.white,
//               size: 24,
//             ),
//           ),
//           child: const Text(
//             'Complete Current Stop',
//             style: TextStyle(
//               color: _ThemeC.greenText,
//               fontSize: 14,
//               fontWeight: FontWeight.w700,
//             ),
//           ),
//           action: (controller) async {
//             try {
//               controller.loading();
//               await Future.delayed(const Duration(milliseconds: 200));

//               final msg = await driverStatusController.completeRideRequest(
//                 context,
//                 Amount: active.amount,
//                 bookingId: active.bookingId,
//                 navigateToCashScreen: false,
//                 isSharedRide: true,
//               );

//               if (!mounted || _isDisposing) return;

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
//               if (!mounted || _isDisposing) return;
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

//     return const SizedBox.shrink();
//   }

//   Widget _buildRiderRow(SharedRiderItem r) {
//     final active = sharedRideController.activeTarget.value;
//     final isActive = active?.bookingId == r.bookingId;
//     final isDropped = r.stage == SharedRiderStage.dropped;
//     final isExpanded = _expandedCards.contains(r.bookingId);

//     String stageLabel;
//     switch (r.stage) {
//       case SharedRiderStage.waitingPickup:
//         stageLabel = 'Pending pickup';
//         break;
//       case SharedRiderStage.onboardDrop:
//         stageLabel = 'In car Ã¢â‚¬â€œ drop pending';
//         break;
//       case SharedRiderStage.dropped:
//         stageLabel = 'Dropped';
//         break;
//     }

//     void toggleExpanded() {
//       if (!mounted || _isDisposing) return;
//       setState(() {
//         if (isExpanded) {
//           _expandedCards.remove(r.bookingId);
//         } else {
//           _expandedCards.add(r.bookingId);
//         }
//       });
//     }

//     return Opacity(
//       opacity: isDropped ? 0.4 : 1,
//       child: Container(
//         margin: const EdgeInsets.symmetric(vertical: 6),
//         padding: const EdgeInsets.all(12),
//         decoration: BoxDecoration(
//           color: _ThemeC.surface,
//           borderRadius: BorderRadius.circular(16),
//           border: Border.all(
//             color: isActive ? _ThemeC.green : _ThemeC.border,
//             width: isActive ? 1.5 : 1.0,
//           ),
//           boxShadow: [
//             BoxShadow(
//               color: isActive ? _ThemeC.green.withOpacity(0.08) : _ThemeC.shadow,
//               blurRadius: isActive ? 14 : 8,
//               offset: const Offset(0, 3),
//             ),
//           ],
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
//                 placeholder: (c, u) => const SizedBox(
//                   height: 30,
//                   width: 30,
//                   child: CircularProgressIndicator(strokeWidth: 2),
//                 ),
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
//                             style: TextStyle(
//                               fontSize: 10,
//                               color: _ThemeC.textMuted,
//                             ),
//                           ),
//                         const SizedBox(width: 4),
//                         AnimatedRotation(
//                           turns: isExpanded ? 0.5 : 0.0,
//                           duration: const Duration(milliseconds: 200),
//                           child: Icon(
//                             Icons.keyboard_arrow_down_rounded,
//                             size: 20,
//                             color: _ThemeC.textMuted,
//                           ),
//                         ),
//                       ],
//                     ),
//                     const SizedBox(height: 2),
//                     CustomTextfield.textWithStylesSmall(
//                       stageLabel,
//                       colors: _ThemeC.textSub,
//                       fontSize: 12,
//                     ),
//                     AnimatedCrossFade(
//                       duration: const Duration(milliseconds: 220),
//                       crossFadeState: isExpanded
//                           ? CrossFadeState.showSecond
//                           : CrossFadeState.showFirst,
//                       firstChild: const SizedBox(height: 0),
//                       secondChild: Padding(
//                         padding: const EdgeInsets.only(top: 6),
//                         child: Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             CustomTextfield.textWithStylesSmall(
//                               'Pickup: ${r.pickupAddress}',
//                               colors: _ThemeC.textSub,
//                               maxLine: 3,
//                               fontSize: 11,
//                             ),
//                             const SizedBox(height: 2),
//                             CustomTextfield.textWithStylesSmall(
//                               'Drop: ${r.dropoffAddress}',
//                               colors: _ThemeC.textSub,
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
//                     color: isActive ? _ThemeC.green : _ThemeC.blue,
//                   ),
//                 ),
//               ),
//           ],
//         ),
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     final active = sharedRideController.activeTarget.value;
//     final driverPos = _animatedDriverPos ?? widget.driverLocation;

//     final markers = <Marker>{
//       Marker(
//         markerId: const MarkerId('driver'),
//         position: driverPos,
//         icon: carIcon ?? BitmapDescriptor.defaultMarker,
//         rotation: _animatedBearing,
//         anchor: const Offset(0.5, 0.5),
//         flat: true,
//         zIndex: 999,
//       ),
//       if (active != null)
//         Marker(
//           markerId: const MarkerId('target'),
//           position: active.stage == SharedRiderStage.waitingPickup
//               ? active.pickupLatLng
//               : active.dropLatLng,
//           infoWindow: InfoWindow(
//             title: active.stage == SharedRiderStage.waitingPickup
//                 ? 'Pickup ${active.name}'
//                 : 'Drop ${active.name}',
//           ),
//         ),
//     };

//     return NoInternetOverlay(
//       child: WillPopScope(
//         onWillPop: () async => false,
//         child: Scaffold(
//           backgroundColor: _ThemeC.bg,
//           body: Stack(
//             children: [
//               SizedBox(
//                 height: 550,
//                 width: double.infinity,
//                 child: SharedMap(
//                   key: _mapKey,
//                   followDriver: true,
//                   followZoom: _followZoom,
//                   followTilt: 0,
//                   initialPosition: widget.pickupLocation,
//                   pickupPosition: driverPos,
//                   markers: markers,
//                   polylines: {
//                     if (polylinePoints.length >= 2)
//                       Polyline(
//                         polylineId: const PolylineId("route"),
//                         color: _ThemeC.green,
//                         width: 5,
//                         points: polylinePoints,
//                         patterns: [
//                           PatternItem.dash(24),
//                           PatternItem.gap(10),
//                         ],
//                       ),
//                   },
//                   myLocationEnabled: true,
//                   fitToBounds: true,
//                 ),
//               ),

//               Positioned(
//                 top: 172,
//                 right: 14,
//                 child: SafeArea(
//                   child: Column(
//                     children: [
//                       ValueListenableBuilder<bool>(
//                         valueListenable:
//                             NavigationVoiceService.instance.mutedNotifier,
//                         builder: (context, muted, _) {
//                           return _buildMapControlBtn(
//                             icon: muted
//                                 ? Icons.volume_off_rounded
//                                 : Icons.volume_up_rounded,
//                             iconColor: muted ? _ThemeC.red : _ThemeC.green,
//                             onTap: () =>
//                                 NavigationVoiceService.instance.toggleMuted(),
//                           );
//                         },
//                       ),
//                       const SizedBox(height: 10),
//                       _buildMapControlBtn(
//                         icon: _isDriverFocused
//                             ? Icons.fit_screen_rounded
//                             : Icons.my_location_rounded,
//                         iconColor: _ThemeC.green,
//                         onTap: () {
//                           final mapState = _mapKey.currentState;
//                           if (mapState == null) return;

//                           if (_isDriverFocused) {
//                             mapState.fitRouteBounds();
//                           } else {
//                             mapState.focusPickup();
//                           }

//                           if (!mounted || _isDisposing) return;
//                           setState(() => _isDriverFocused = !_isDriverFocused);
//                         },
//                       ),
//                     ],
//                   ),
//                 ),
//               ),

//               Positioned(
//                 top: 52,
//                 left: 0,
//                 right: 0,
//                 child: _buildDirectionHeader(),
//               ),
//               if (_isNetworkOffline || _pendingQueueCount > 0)
//                 Positioned(
//                   top: 150,
//                   left: 12,
//                   right: 12,
//                   child: Container(
//                     padding: const EdgeInsets.symmetric(
//                       horizontal: 14,
//                       vertical: 10,
//                     ),
//                     decoration: BoxDecoration(
//                       color: _ThemeC.amberLight,
//                       borderRadius: BorderRadius.circular(14),
//                       border: Border.all(color: _ThemeC.amber.withOpacity(0.4)),
//                       boxShadow: [
//                         BoxShadow(
//                           color: _ThemeC.amber.withOpacity(0.1),
//                           blurRadius: 12,
//                           offset: const Offset(0, 4),
//                         ),
//                       ],
//                     ),
//                     child: Row(
//                       children: [
//                         Icon(
//                           _isNetworkOffline ? Icons.wifi_off_rounded : Icons.sync_rounded,
//                           color: _ThemeC.amber,
//                           size: 16,
//                         ),
//                         const SizedBox(width: 8),
//                         Expanded(
//                           child: Text(
//                             _isNetworkOffline
//                                 ? 'No internet. Route cache active, syncing when online.'
//                                 : 'Sync pending: $_pendingQueueCount message(s)',
//                             style: TextStyle(
//                               color: _ThemeC.amber.withOpacity(0.9),
//                               fontSize: 12,
//                               fontWeight: FontWeight.w600,
//                             ),
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                 ),
//               if (_isOffRouteAlert)
//                 Positioned(
//                   top: 202,
//                   left: 12,
//                   right: 12,
//                   child: Container(
//                     padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
//                     decoration: BoxDecoration(
//                       color: const Color(0xFFFFF3CD),
//                       borderRadius: BorderRadius.circular(14),
//                       border: Border.all(color: _ThemeC.amber.withOpacity(0.5)),
//                     ),
//                     child: Row(
//                       children: [
//                         const Icon(
//                           Icons.warning_amber_rounded,
//                           color: _ThemeC.amber,
//                           size: 18,
//                         ),
//                         const SizedBox(width: 8),
//                         const Expanded(
//                           child: Text(
//                             'Route deviation detected',
//                             style: TextStyle(
//                               color: Color(0xFF92400E),
//                               fontSize: 12,
//                               fontWeight: FontWeight.w700,
//                             ),
//                           ),
//                         ),
//                         TextButton(
//                           onPressed: () => _mapKey.currentState?.focusPickup(),
//                           style: TextButton.styleFrom(
//                             foregroundColor: _ThemeC.amber,
//                             padding:
//                                 const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
//                             tapTargetSize: MaterialTapTargetSize.shrinkWrap,
//                           ),
//                           child: const Text(
//                             'Recenter',
//                             style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                 ),

//               DraggableScrollableSheet(
//                 initialChildSize: 0.70,
//                 minChildSize: 0.40,
//                 maxChildSize: 0.85,
//                 builder: (context, scrollController) {
//                   return Container(
//                     decoration: const BoxDecoration(
//                       color: _ThemeC.bg,
//                       borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
//                       boxShadow: [
//                         BoxShadow(
//                           color: Color(0x1A000000),
//                           blurRadius: 24,
//                           offset: Offset(0, -6),
//                         ),
//                       ],
//                     ),
//                     child: Obx(() {
//                       final active = sharedRideController.activeTarget.value;

//                       return ListView(
//                         controller: scrollController,
//                         physics: const BouncingScrollPhysics(),
//                         children: [
//                           const SizedBox(height: 6),
//                           Center(
//                             child: Container(
//                               width: 40,
//                               height: 4,
//                               decoration: BoxDecoration(
//                                 color: _ThemeC.border,
//                                 borderRadius: BorderRadius.circular(10),
//                               ),
//                             ),
//                           ),
//                           const SizedBox(height: 20),

//                           if (!driverCompletedRide && active != null) ...[
//                             Container(
//                               margin: const EdgeInsets.symmetric(horizontal: 16),
//                               padding: const EdgeInsets.all(14),
//                               decoration: BoxDecoration(
//                                 color: _ThemeC.surfaceAlt,
//                                 borderRadius: BorderRadius.circular(14),
//                                 border: Border.all(color: _ThemeC.borderLight),
//                               ),
//                               child: Column(
//                                 crossAxisAlignment: CrossAxisAlignment.start,
//                                 children: [
//                                   CustomTextfield.textWithStyles600(
//                                     active.stage == SharedRiderStage.waitingPickup
//                                         ? 'Heading to pick up ${active.name}'
//                                         : 'Ride in Progress - Dropping ${active.name}',
//                                     color: _ThemeC.greenText,
//                                     fontSize: 14,
//                                   ),
//                                   const SizedBox(height: 6),
//                                   Text(
//                                     'Booking ID: #${active.bookingId}',
//                                     style: const TextStyle(
//                                       fontSize: 11,
//                                       color: _ThemeC.textMuted,
//                                     ),
//                                   ),
//                                   const SizedBox(height: 6),
//                                   Text(
//                                     'Pickup: ${active.pickupAddress}',
//                                     style: const TextStyle(
//                                       fontSize: 12,
//                                       color: _ThemeC.text,
//                                     ),
//                                   ),
//                                   const SizedBox(height: 4),
//                                   Text(
//                                     'Drop: ${active.dropoffAddress}',
//                                     style: const TextStyle(
//                                       fontSize: 12,
//                                       color: _ThemeC.text,
//                                     ),
//                                   ),
//                                 ],
//                               ),
//                             ),
//                             const SizedBox(height: 16),
//                             _buildEtaRow(active),
//                             const SizedBox(height: 10),
//                             Padding(
//                               padding: const EdgeInsets.symmetric(horizontal: 16),
//                               child: Obx(() {
//                                 final isPickupStage =
//                                     active.stage == SharedRiderStage.waitingPickup;
//                                 final eta = (isPickupStage
//                                         ? sharedController.pickupDurationInMin.value
//                                         : sharedController.dropDurationInMin.value)
//                                     .round();
//                                 final chips = isPickupStage
//                                     ? DriverMessageSuggestions.pickup(
//                                         reachedPickup: active.arrived,
//                                         etaMinutes: eta,
//                                       )
//                                     : DriverMessageSuggestions.drop(
//                                         etaMinutes: eta,
//                                       );
//                                 return SingleChildScrollView(
//                                   scrollDirection: Axis.horizontal,
//                                   child: Row(
//                                     children: chips
//                                         .map(
//                                           (msg) => Padding(
//                                             padding:
//                                                 const EdgeInsets.only(right: 8),
//                                             child: InkWell(
//                                               onTap: () => _sendQuickMessage(
//                                                 active,
//                                                 msg,
//                                                 delayMinutes: eta,
//                                               ),
//                                               borderRadius:
//                                                   BorderRadius.circular(18),
//                                               child: Container(
//                                                 padding:
//                                                     const EdgeInsets.symmetric(
//                                                   horizontal: 12,
//                                                   vertical: 8,
//                                                 ),
//                                                 decoration: BoxDecoration(
//                                                   color: _ThemeC.surface,
//                                                   borderRadius:
//                                                       BorderRadius.circular(18),
//                                                   border: Border.all(
//                                                     color: _ThemeC.border,
//                                                   ),
//                                                   boxShadow: const [
//                                                     BoxShadow(
//                                                       color: _ThemeC.shadow,
//                                                       blurRadius: 6,
//                                                       offset: Offset(0, 2),
//                                                     ),
//                                                   ],
//                                                 ),
//                                                 child: Text(
//                                                   msg,
//                                                   style: const TextStyle(
//                                                     fontSize: 12,
//                                                     fontWeight: FontWeight.w600,
//                                                     color: _ThemeC.text,
//                                                   ),
//                                                 ),
//                                               ),
//                                             ),
//                                           ),
//                                         )
//                                         .toList(),
//                                   ),
//                                 );
//                               }),
//                             ),
//                             const SizedBox(height: 10),
//                             _buildActiveActionArea(active),
//                             const SizedBox(height: 10),
//                           ],

//                           const Padding(
//                             padding: EdgeInsets.symmetric(horizontal: 16),
//                             child: Text(
//                               'Next Stops',
//                               style: TextStyle(
//                                 fontSize: 16,
//                                 fontWeight: FontWeight.w600,
//                                 color: _ThemeC.text,
//                               ),
//                             ),
//                           ),
//                           const SizedBox(height: 8),

//                           if (sharedRideController.riders.isEmpty)
//                             const Padding(
//                               padding: EdgeInsets.all(20),
//                               child: Text('No riders in this shared trip'),
//                             )
//                           else
//                             Padding(
//                               padding: const EdgeInsets.symmetric(horizontal: 16),
//                               child: Column(
//                                 children: sharedRideController.riders
//                                     .map(_buildRiderRow)
//                                     .toList(),
//                               ),
//                             ),

//                           const SizedBox(height: 20),

//                           Padding(
//                             padding: const EdgeInsets.symmetric(
//                               horizontal: 20,
//                               vertical: 12,
//                             ),
//                             child: Column(
//                               crossAxisAlignment: CrossAxisAlignment.start,
//                               children: [
//                                 Obx(() {
//                                   final stopped = driverStatusController
//                                       .isStopNewRequests
//                                       .value;

//                                   return Buttons.button(
//                                     borderColor: AppColors.buttonBorder,
//                                     buttonColor: stopped
//                                         ? AppColors.containerColor
//                                         : AppColors.commonWhite,
//                                     borderRadius: 8,
//                                     textColor: AppColors.commonBlack,
//                                     onTap: stopped
//                                         ? null
//                                         : () => Buttons.showDialogBox(
//                                               context: context,
//                                               onConfirmStop: () async {
//                                                 await driverStatusController
//                                                     .stopNewRideRequest(
//                                                   context: context,
//                                                   stop: true,
//                                                 );
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

//                                 Buttons.button(
//                                   borderRadius: 8,
//                                   buttonColor: AppColors.red,
//                                   onTap: () {
//                                     Buttons.showCancelRideBottomSheet(
//                                       context,
//                                       onConfirmCancel: (reason) async {
//                                         if (Get.isBottomSheetOpen == true) {
//                                           Get.back();
//                                         }

//                                         await driverStatusController
//                                             .cancelBooking(
//                                           context,
//                                           bookingId: widget.bookingId,
//                                           reason: reason,
//                                           silent: true,
//                                           navigate: true,
//                                         );
//                                       },
//                                     );
//                                   },
//                                   text: const Text('Cancel this Shared Ride'),
//                                 ),
//                                 const SizedBox(height: 20),                              ],
//                             ),
//                           ),
//                         ],
//                       );
//                     }),
//                   );
//                 },
//               ),

//               const BookingOverlayRequest(  allowNavigate : true),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }
