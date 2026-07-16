// lib/Presentation/DriverScreen/controller/pickup_customer_controller.dart

import 'dart:async';
import 'dart:math' as math;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:hopper/Core/Services/driver_location_bus.dart';

import 'package:hopper/Core/Constants/log.dart';
import 'package:hopper/Presentation/DriverScreen/controller/driver_main_controller.dart';
import 'package:hopper/Presentation/DriverScreen/controller/driver_status_controller.dart';
import 'package:hopper/Presentation/DriverScreen/screens/verify_rider_screen.dart';
import 'package:hopper/api/dataSource/apiDataSource.dart';
import 'package:hopper/api/repository/api_config_controller.dart';
import 'package:hopper/api/repository/api_constents.dart';
import 'package:hopper/utils/map/route_info.dart';
import 'package:hopper/utils/sharedprefsHelper/local_data_store.dart';
import 'package:hopper/utils/sharedprefsHelper/sharedprefs_handler.dart';
import 'package:hopper/utils/websocket/socket_io_client.dart';
import 'package:hopper/utils/map/navigation_assist.dart';
import 'package:hopper/utils/map/navigation_voice_service.dart';
import 'package:hopper/utils/map/map_motion_profile.dart';
import 'package:hopper/utils/map/app_map_style.dart';
import 'package:hopper/utils/location/location_permission_guard.dart';
import 'package:hopper/utils/map/polyline_snap.dart';
import 'package:hopper/utils/map/maneuver_markers.dart';
import 'package:hopper/utils/ride_map/marker_icon_cache.dart';
import 'package:hopper/utils/ride_map/ride_map_controller.dart';
import 'package:hopper/utils/ride_map/travel_mode_resolver.dart';

/// UI snapshot (keeps widget build super clean)
class PickingUiState {
  final LatLng driverLocation;
  final double bearing;
  final List<LatLng> polyline;
  final String directionText;
  final String distanceText;
  final String maneuver;
  // Locally-computed driver->pickup ETA (minutes) from the route fetch. Used as
  // a fallback for the header "min" when the server socket ETA is 0/missing.
  final double routeDurationMin;

  const PickingUiState({
    required this.driverLocation,
    required this.bearing,
    required this.polyline,
    required this.directionText,
    required this.distanceText,
    required this.maneuver,
    this.routeDurationMin = 0.0,
  });

  PickingUiState copyWith({
    LatLng? driverLocation,
    double? bearing,
    List<LatLng>? polyline,
    String? directionText,
    String? distanceText,
    String? maneuver,
    double? routeDurationMin,
  }) {
    return PickingUiState(
      driverLocation: driverLocation ?? this.driverLocation,
      bearing: bearing ?? this.bearing,
      polyline: polyline ?? this.polyline,
      directionText: directionText ?? this.directionText,
      distanceText: distanceText ?? this.distanceText,
      maneuver: maneuver ?? this.maneuver,
      routeDurationMin: routeDurationMin ?? this.routeDurationMin,
    );
  }
}

class _QueuedSocketEmit {
  final String event;
  final Map<String, dynamic> payload;
  const _QueuedSocketEmit({required this.event, required this.payload});
}

class PickingCustomerController extends GetxController {
  // Toggle for local testing:
  // true  -> show Arrived controls immediately.
  // false -> normal behavior (auto-show when within 500m of pickup).
  static const bool enableArrivedTesting = false;

  // ----- inputs -----
  final LatLng pickupLocation;
  final LatLng driverLocation;
  final String bookingId;
  final String? pickupLocationAddress;
  final String? dropLocationAddress;

  PickingCustomerController({
    required this.pickupLocation,
    required this.driverLocation,
    required this.bookingId,
    this.pickupLocationAddress,
    this.dropLocationAddress,
    bool initialIsParcel = false,
  }) {
    // Car->Parcel UI flash fix: isParcel used to default false and only
    // flip true once the async 'joined-booking' socket reply or the
    // /active-booking REST fallback landed — both well after the first
    // build, so the Car UI rendered for a frame (or more, on a slow
    // network) before switching. Callers now already know the booking type
    // from data they fetched BEFORE navigating here (the accept-response or
    // the active-booking resume payload) — seeding it synchronously here
    // means the very first build already renders the right UI. The async
    // paths below are left untouched as a safety net (never downgrade).
    if (initialIsParcel) isParcel.value = true;
  }

  // ----- deps -----
  late final DriverStatusController driverStatusController =
      Get.isRegistered<DriverStatusController>()
          ? Get.find<DriverStatusController>()
          : Get.put(DriverStatusController(), permanent: true);

  // ----- map -----
  final RideMapController rideMap = RideMapController(
    mode: RideMapMode.pickupNavigation,
  );
  Worker? _serviceTypeWorker;
  Worker? _pickupMarkerWorker;
  Worker? _sheetHeightWorker;
  final Rxn<LatLng> adjustedPickupLocation = Rxn<LatLng>();
  final RxInt pickupAdjustMeters = 0.obs;

  // ----- socket -----
  late final SocketService socketService;

  // ----- REST fallback -----
  final ApiDataSource _restApi = ApiDataSource();

  // ----- rider meta -----
  final customerName = ''.obs;
  final customerPhone = ''.obs;
  final customerProfilePic = ''.obs;
  final pickupAddressText = ''.obs;
  final dropAddressText = ''.obs;

  /// Package delivery trust (Phase 2): true when the active booking is a
  /// parcel. Only used to route pickup-OTP verification to the dedicated
  /// hash-based endpoint instead of the shared ride-start OTP flow.
  final isParcel = false.obs;

  /// Display-only package fields for the parcel pickup screen (Phase 4 UI
  /// redesign) — sourced from the same `parcel` object RideStatsController
  /// already reads on the drop leg. Never written back to the backend from
  /// here; purely informational for the driver before pickup. (Package ID is
  /// just `bookingId`, already a field on this controller — no duplicate.)
  final parcelType = ''.obs;
  final parcelWeight = ''.obs;
  final deliveryInstruction = ''.obs;
  final addressType = ''.obs;

  void _applyParcelInfo(Map<String, dynamic> payload) {
    final raw = payload['parcel'];
    if (raw is! Map) return;
    final p = Map<String, dynamic>.from(raw);
    String clean(dynamic v) {
      final s = (v ?? '').toString().trim();
      return s == 'null' ? '' : s;
    }

    final type = clean(p['parcelType']);
    if (type.isNotEmpty) parcelType.value = type;
    final weight = clean(p['maxWeight']);
    if (weight.isNotEmpty && weight != '0') parcelWeight.value = weight;
    final instruction = clean(p['deliveryInstruction']);
    if (instruction.isNotEmpty) deliveryInstruction.value = instruction;
    final addrType = clean(p['addressType']);
    if (addrType.isNotEmpty) addressType.value = addrType;
  }

  // ----- flow flags -----
  final arrivedAtPickup = true.obs; // before pressing "Arrived at Pickup Point"
  // UI source-of-truth for "Arrived" CTA visibility.
  // Computed from GPS first; falls back to socket distance only if GPS is stale.
  final driverReached = false.obs;
  bool _driverReachedGps = false;
  bool _driverReachedSocket = false;
  DateTime? _lastGpsFixAt;
  DateTime? _lastSocketFixAt;
  final showRedTimer = false.obs;
  final isArrivedSubmitting = false.obs;
  bool _otpNavInFlight = false;
  final isOffRouteAlert = false.obs;
  final isNetworkOffline = false.obs;
  final pendingQueueCount = 0.obs;
  final followZoom = 17.0.obs;
  final isDriverFocused = false.obs;

  // ----- timer -----
  final secondsLeft = 0.obs;
  Timer? _timer;

  // Self-heal: if the server's `joined-booking` reply (customer name/phone +
  // pickup distance/ETA) is ever lost, re-emit join-booking AFTER the backend's
  // 2s duplicate-join window so it is not suppressed. Bounded retries.
  Timer? _joinedBookingRetryTimer;
  int _joinedBookingRetries = 0;
  static const int _maxJoinedBookingRetries = 3;

  // ----- UI state -----
  late final Rx<PickingUiState> ui;

  // ----- tracking -----
  StreamSubscription<Position>? _posSub;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  LatLng? _lastPos;
  bool _animating = false;
  LatLng? _queuedTarget;
  double? _queuedBearing;

  // ----- routing/polylines -----
  List<LatLng> _poly = [];
  bool _hasRoadRoute = false;
  final RxList<Marker> maneuverMarkers = <Marker>[].obs;
  int _maneuverGen = 0;
  DateTime _lastRouteFetch = DateTime.fromMillisecondsSinceEpoch(0);
  bool _routeFetchInFlight = false;
  DateTime _lastRouteRequestAt = DateTime.fromMillisecondsSinceEpoch(0);
  LatLng? _lastRouteOrigin;
  LatLng? _lastRouteDestination;
  PickingUiState? _cachedUiState;
  bool _pendingRouteRetry = false;
  Timer? _routeRetryTimer;
  final List<_QueuedSocketEmit> _socketRetryQueue = <_QueuedSocketEmit>[];
  String? _driverId;
  bool _routeRefreshQueued = false;

  // ----- thresholds (jitter control) -----
  static const double _MAX_ACCURACY_M = 25.0;
  static const double _MIN_MOVE_METERS = 3.0;
  static const double _MIN_SPEED_MS = 1.0;
  static const double _STATIONARY_DRIFT_M = 8.0;
  static const double _HEADING_TRUST_MS = 2.0;
  static const double _MIN_TURN_DEG = 10.0;
  static const double _OFF_ROUTE_TOLERANCE_M = 25.0;
  static const double _SNAP_TOLERANCE_M = 35.0; // project marker onto route
  static const double _ARRIVED_PICKUP_RADIUS_M = 500.0;
  static const double _ARRIVED_PICKUP_EXIT_RADIUS_M = 650.0;
  static const double _POLYLINE_TRIM_TOLERANCE_M = 30.0;
  static const int _POLYLINE_TRIM_LOOKAHEAD_POINTS = 40;
  static const int _OFF_ROUTE_LOOKAHEAD_POINTS = 80;

  static const Duration _gpsReachedTtl = Duration(seconds: 8);
  static const Duration _socketReachedTtl = Duration(seconds: 12);

  @override
  void onInit() {
    super.onInit();

    // ÃƒÆ’Ã‚Â¢Ãƒâ€¦Ã¢â‚¬Å“ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¦ MUST SET BEFORE _fetchRoute()
    DirectionsConfig.apiKey = ApiConstents.googleMapApiKey;

    ui =
        PickingUiState(
          driverLocation: driverLocation,
          bearing: 0,
          // Do NOT seed route/vehicle from `driverLocation` param. That value can
          // be stale/incorrect when navigating between screens. We wait for the
          // first live GPS fix before drawing route + placing vehicle marker.
          polyline: const <LatLng>[],
          directionText: '',
          distanceText: '',
          maneuver: '',
        ).obs;

    _applySystemUi();
    _initConnectivityWatchdog();
    _loadDriverId();
    _applyVehicleType();
    _listenServiceTypeForVehicle();
    _initSocket();
    unawaited(_joinBookingRoom());
    // Align the foreground emitter to this trip so it streams at the smooth
    // ~1Hz active-trip cadence (bookingId on every packet) while approaching
    // pickup, instead of the idle 5–8s cadence. See setActiveTripBookingId().
    if (Get.isRegistered<DriverMainController>()) {
      Get.find<DriverMainController>().setActiveTripBookingId(bookingId);
    }
    _bootFromJoinedOrReverseGeocode();
    // Reliable REST fallback for customer name / phone / photo. The socket
    // `joined-booking` reply can be missed; this guarantees the call button,
    // rider name and addresses are populated regardless of socket timing.
    unawaited(_hydrateCustomerInfoFromRest());
    _startTracking();
    rideMap.setPickupDrop(pickup: pickupLocation, showPickupPin: true);
    rideMap.setShowCompletedRoute(false);
    if (kDebugMode) {
      debugPrint(
        '[PICKUP_MARKER] source=actualPickup lat=${pickupLocation.latitude} lng=${pickupLocation.longitude}',
      );
      debugPrint(
        '[DESTINATION] mode=pickupNavigation lat=${pickupLocation.latitude} lng=${pickupLocation.longitude}',
      );
    }

    // Pickup marker must always be the actual pickup destination (never driver/adjusted).
    _pickupMarkerWorker?.dispose();
    _pickupMarkerWorker = null;

    _sheetHeightWorker?.dispose();
    void applySheetHeight(bool arrived) {
      // Padding hint used by RideMapView -> GoogleMap.padding.
      // Keep it conservative so Google attribution stays as low as possible
      // while not being obscured by the pickup bottom sheet.
      rideMap.setBottomSheetHeight(arrived ? 280.0 : 150.0);
    }

    applySheetHeight(arrivedAtPickup.value);
    _sheetHeightWorker = ever<bool>(arrivedAtPickup, applySheetHeight);

    if (enableArrivedTesting) {
      driverReached.value = true;
      CommonLogger.log.i("Test mode enabled: driverReached forced to true");
    }
  }

  @override
  void onClose() {
    _posSub?.cancel();
    _connectivitySub?.cancel();
    _stopNoShowTimer();
    _routeRetryTimer?.cancel();
    _joinedBookingRetryTimer?.cancel();
    _serviceTypeWorker?.dispose();
    _pickupMarkerWorker?.dispose();
    _sheetHeightWorker?.dispose();
    try {
      socketService.socket.off('joined-booking');
      socketService.socket.off('driver-location');
      socketService.socket.off('driver-arrived');
      // NOTE: never call socket.off('driver-cancelled'/'customer-cancelled')
      // here — the raw off(event) with no handler removes ALL listeners for
      // that event, including DriverMainController's app-lifetime
      // cancellation handler, silently breaking cancellation detection for
      // every screen opened afterward.
    } catch (_) {}
    _queuedTarget = null;
    _queuedBearing = null;
    rideMap.dispose();
    super.onClose();
  }

  Future<void> _loadDriverId() async {
    _driverId = await SharedPrefHelper.getDriverId();
  }

  void _initConnectivityWatchdog() {
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      final offline = results.every((r) => r == ConnectivityResult.none);
      isNetworkOffline.value = offline;
      if (offline) return;

      if (!socketService.connected) {
        socketService.connect();
      }
      _flushSocketRetryQueue();
      if (_pendingRouteRetry) {
        _fetchRoute(force: true);
      }
    });
  }

  // ===================== UI / SYSTEM =====================

  void _applySystemUi() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );
  }

  RideVehicleType _vehicleTypeFromServiceType(String raw) {
    final v = raw.trim().toLowerCase();
    if (v.contains('package') || v.contains('parcel')) {
      return RideVehicleType.packageBike;
    }
    if (v.contains('bike')) return RideVehicleType.bike;
    return RideVehicleType.car;
  }

  void _applyVehicleType() {
    rideMap.setVehicleType(
      _vehicleTypeFromServiceType(driverStatusController.serviceType.value),
    );
  }

  void _listenServiceTypeForVehicle() {
    _serviceTypeWorker?.dispose();
    _serviceTypeWorker = ever<String>(
      driverStatusController.serviceType,
      (_) => _applyVehicleType(),
    );
  }

  // ===================== SOCKET =====================

  void _initSocket() {
    socketService = SocketService();
    final cfg = Get.find<ApiConfigController>();
    socketService.initSocket(cfg.socketUrl);
    socketService.on('joined-booking', (data) async {
      if (data == null) return;
      if (data is! Map) return;

      final joined = Map<String, dynamic>.from(data as Map);
      JoinedBookingData().setData(joined);

      // Defer Rx updates until after the first frame to avoid
      // "markNeedsBuild during build" crashes from Obx.
      final serviceType = joined['rideType'] ?? joined['serviceType'];
      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          driverStatusController.setServiceTypeFrom(serviceType);
        } catch (_) {}
      });

      // âœ… IMPORTANT: fill these so UI shows customer name
      customerName.value = (joined['customerName'] ?? '').toString();
      customerPhone.value = (joined['customerPhone'] ?? '').toString();
      customerProfilePic.value =
          (joined['customerProfilePic'] ?? '').toString();

      // Package delivery trust (Phase 2): detect parcel bookings so the OTP
      // screen can route to the dedicated pickup-OTP endpoint. Never downgrade
      // — a later payload without the marker must not un-flag a parcel.
      final joinedBookingType =
          (joined['bookingType'] ?? '').toString().trim().toLowerCase();
      if (joinedBookingType == 'parcel' || joined['parcel'] is Map) {
        isParcel.value = true;
      }
      _applyParcelInfo(joined);

      double? asDouble(dynamic v) {
        if (v is num) return v.toDouble();
        return double.tryParse(v?.toString() ?? '');
      }

      final locRaw = joined['customerLocation'];
      final loc =
          locRaw is Map
              ? Map<String, dynamic>.from(locRaw as Map)
              : <String, dynamic>{};

      final fromLat = asDouble(
        joined['fromLatitude'] ?? loc['fromLatitude'] ?? loc['latitude'],
      );
      final fromLng = asDouble(
        joined['fromLongitude'] ?? loc['fromLongitude'] ?? loc['longitude'],
      );
      final toLat = asDouble(joined['toLatitude'] ?? loc['toLatitude']);
      final toLng = asDouble(joined['toLongitude'] ?? loc['toLongitude']);

      // If joined-booking already contains a driverLocation, show vehicle marker
      // immediately (do not wait for driver-location event).
      final driverLocRaw = joined['driverLocation'];
      if (driverLocRaw is Map) {
        final d = Map<String, dynamic>.from(driverLocRaw as Map);
        final dLat = asDouble(d['latitude'] ?? d['lat']);
        final dLng = asDouble(d['longitude'] ?? d['lng']);
        if (dLat != null && dLng != null) {
          final joinedDriver = LatLng(dLat, dLng);
          // Comes from backend payload => treat as socket source.
          rideMap.updateVehicleLocation(joinedDriver, source: 'socket');
          _lastPos ??= joinedDriver;
          ui.value = ui.value.copyWith(driverLocation: joinedDriver);
          // Ensure polyline is visible immediately while API route loads.
          // If we already have a road route, never overwrite it with a straight line.
          if (!_hasRoadRoute) {
            _setDirectPolyline(joinedDriver, pickupLocation);
          }
          unawaited(_fetchRoute(force: true));
        }
      }

      if (fromLat != null && fromLng != null) {
        pickupAddressText.value = await getAddressFromLatLng(fromLat, fromLng);
      }
      if (toLat != null && toLng != null) {
        dropAddressText.value = await getAddressFromLatLng(toLat, toLng);
      }

      CommonLogger.log.i(
        "Joined booking loaded for customer: ${customerName.value}",
      );
    });
    socketService.on('driver-location', (data) {
      if (data == null) return;
      if (data is! Map) return;
      final payload = Map<String, dynamic>.from(data as Map);

      // Live driver position from backend/socket.
      double? asDouble(dynamic v) {
        if (v is num) return v.toDouble();
        return double.tryParse(v?.toString() ?? '');
      }

      final lat = asDouble(payload['latitude'] ?? payload['lat']);
      final lng = asDouble(payload['longitude'] ?? payload['lng']);
      if (lat != null && lng != null) {
        final p = LatLng(lat, lng);
        rideMap.updateVehicleLocation(p, source: 'socket');
      }

      final pickupM = asDouble(payload['pickupDistanceInMeters']);
      if (pickupM != null) {
        // A transient/stale 0 during the pickup phase must NOT blank the
        // "X km" / "X min" card. Accept a 0 only once the driver has genuinely
        // reached pickup (_driverReachedSocket — set from a real positive
        // in-radius reading or a driver-arrived event); positive values are
        // always accepted. Otherwise keep the last good value.
        // NOTE: do NOT gate on `pickupM <= _ARRIVED_PICKUP_RADIUS_M` here — when
        // pickupM is 0 that test is vacuously true and would re-admit the poison
        // 0 (and the radius is 500 m, nowhere near "arrived").
        if (pickupM > 0 || _driverReachedSocket) {
          driverStatusController.pickupDistanceInMeters.value = pickupM;

          _lastSocketFixAt = DateTime.now();
          if (!_driverReachedSocket &&
              pickupM > 0 &&
              pickupM <= _ARRIVED_PICKUP_RADIUS_M) {
            _driverReachedSocket = true;
            CommonLogger.log.i(
              'Auto driverReached TRUE (socket) pickupDistanceInMeters=${pickupM.toStringAsFixed(1)}m',
            );
          } else if (_driverReachedSocket &&
              pickupM >= _ARRIVED_PICKUP_EXIT_RADIUS_M) {
            _driverReachedSocket = false;
          }

          _recomputeDriverReached();
        }
      }
      final pickupMin = asDouble(payload['pickupDurationInMin']);
      if (pickupMin != null) {
        // Same guard: ignore a transient 0-min ETA unless genuinely arrived.
        if (pickupMin > 0 || _driverReachedSocket) {
          driverStatusController.pickupDurationInMin.value = pickupMin;
        }
      }

      driverStatusController.setLastDriverLocationAtFrom(
        payload['timestamp'] ?? payload['ts'] ?? payload['time'],
      );
    });

    socketService.on('driver-arrived', (data) {
      if (data == null || data is! Map) return;
      final payload = Map<String, dynamic>.from(data as Map);
      final eventBookingId = (payload['bookingId'] ?? '').toString().trim();
      if (eventBookingId.isNotEmpty && eventBookingId != bookingId) return;
      if (!arrivedAtPickup.value || _driverReachedGps || driverReached.value) {
        return;
      }

      final status = payload['status'];
      final arrivedFlag = payload['arrived'];
      final ok =
          status == true ||
          status?.toString().toLowerCase() == 'true' ||
          arrivedFlag == true ||
          arrivedFlag?.toString().toLowerCase() == 'true';
      if (!ok) return;

      _lastSocketFixAt = DateTime.now();
      if (!_driverReachedSocket) {
        _driverReachedSocket = true;
        CommonLogger.log.i(
          'Auto driverReached TRUE (driver-arrived socket fallback after GPS priority) bookingId=$bookingId',
        );
      }
      _recomputeDriverReached();
    });

    socketService.on('driver-cancelled', (data) {
      if (!Get.isRegistered<DriverMainController>()) return;
      Get.find<DriverMainController>().handleDriverCancelled(data);
    });

    socketService.on('customer-cancelled', (data) {
      if (!Get.isRegistered<DriverMainController>()) return;
      Get.find<DriverMainController>().handleCustomerCancelled(data);
    });

    if (!socketService.connected) {
      socketService.connect();
      socketService.onConnect(() {
        CommonLogger.log.i("Socket connected");
        _flushSocketRetryQueue();
      });
    }
  }

  /// Reliable REST fallback for the rider's name / phone / profile photo and
  /// pickup-drop addresses. These normally arrive via the `joined-booking`
  /// socket reply, but that single shot can be missed (slow screen build, a
  /// dropped packet, or backend de-dupe), which left the pickup screen showing
  /// "Picking up Rider", a dead call button and no addresses. GET /active-booking
  /// returns the same fields straight from the DB, so we fill any value that is
  /// still empty (the socket still wins if it already populated it).
  Future<void> _hydrateCustomerInfoFromRest() async {
    try {
      final result = await _restApi.getDriverActiveBooking();
      if (isClosed) return;
      result.fold(
        (failure) {
          CommonLogger.log.w(
            'active-booking customer-info fallback failed: ${failure.message}',
          );
        },
        (resp) {
          final data = resp.data;
          if (data == null) return;
          // Apply only to THIS booking (ignore a stale/other active booking).
          final id = (data['bookingId'] ?? '').toString().trim();
          if (id.isNotEmpty && id != bookingId.trim()) return;

          void fillIfEmpty(RxString field, dynamic value) {
            if (field.value.trim().isNotEmpty) return;
            final v = (value ?? '').toString().trim();
            if (v.isNotEmpty) field.value = v;
          }

          fillIfEmpty(customerName, data['customerName']);
          fillIfEmpty(customerPhone, data['customerPhone']);
          fillIfEmpty(customerProfilePic, data['customerProfilePic']);
          fillIfEmpty(pickupAddressText, data['pickupAddress']);
          fillIfEmpty(dropAddressText, data['dropAddress']);

          final restBookingType =
              (data['bookingType'] ?? '').toString().trim().toLowerCase();
          if (restBookingType == 'parcel' || data['parcel'] is Map) {
            isParcel.value = true;
          }
          if (data is Map) {
            _applyParcelInfo(Map<String, dynamic>.from(data));
          }

          CommonLogger.log.i(
            'Customer info hydrated from /active-booking '
            'name=${customerName.value.isNotEmpty} '
            'phone=${customerPhone.value.isNotEmpty}',
          );
        },
      );
    } catch (e) {
      CommonLogger.log.w('active-booking customer-info fallback error: $e');
    }
  }

  Future<void> _joinBookingRoom() async {
    final did =
        (_driverId ?? await SharedPrefHelper.getDriverId())
            ?.toString()
            .trim() ??
        '';
    if (did.isNotEmpty) {
      socketService.registerDriver(did, bookingId: bookingId);
      socketService.joinBooking(bookingId, userId: did);
    } else {
      socketService.joinBooking(bookingId);
    }
    _scheduleJoinedBookingRetry(did);
  }

  /// Re-emit join-booking if the customer details never arrived. The backend
  /// suppresses join-booking re-emits within a 2s window, so we wait past it.
  void _scheduleJoinedBookingRetry(String did) {
    _joinedBookingRetryTimer?.cancel();
    if (_joinedBookingRetries >= _maxJoinedBookingRetries) return;

    _joinedBookingRetryTimer = Timer(const Duration(milliseconds: 2600), () {
      if (isClosed) return;
      // Already hydrated -> nothing to do.
      if (customerName.value.trim().isNotEmpty ||
          customerPhone.value.trim().isNotEmpty) {
        return;
      }
      if (isNetworkOffline.value || !socketService.connected) {
        // Wait for connectivity watchdog / reconnect to restore the room first.
        _scheduleJoinedBookingRetry(did);
        return;
      }

      _joinedBookingRetries++;
      CommonLogger.log.w(
        'joined-booking not received; re-emitting join-booking '
        '(attempt $_joinedBookingRetries) bookingId=$bookingId',
      );
      if (did.isNotEmpty) {
        socketService.joinBooking(bookingId, userId: did);
      } else {
        socketService.joinBooking(bookingId);
      }
      _scheduleJoinedBookingRetry(did);
    });
  }

  // ===================== BOOT DATA =====================

  Future<void> _bootFromJoinedOrReverseGeocode() async {
    // if joined-booking already saved, hydrate now
    final joined = JoinedBookingData().getData();
    if (joined != null) {
      // Avoid "setState/markNeedsBuild during build" from GetX Obx trees.
      // Defer Rx updates until after the first frame.
      final serviceType = joined['rideType'] ?? joined['serviceType'];
      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          driverStatusController.setServiceTypeFrom(serviceType);
        } catch (_) {}
      });

      customerName.value = (joined['customerName'] ?? '').toString();
      customerPhone.value = (joined['customerPhone'] ?? '').toString();
      customerProfilePic.value =
          (joined['customerProfilePic'] ?? '').toString();

      final pickText =
          (joined['pickupAddress'] ??
                  joined['pickupLocationAddress'] ??
                  pickupLocationAddress ??
                  '')
              .toString();
      final dropText =
          (joined['dropAddress'] ??
                  joined['dropLocationAddress'] ??
                  dropLocationAddress ??
                  '')
              .toString();

      if (pickText.trim().isNotEmpty) pickupAddressText.value = pickText;
      if (dropText.trim().isNotEmpty) dropAddressText.value = dropText;

      if (pickupAddressText.value.isNotEmpty &&
          dropAddressText.value.isNotEmpty) {
        return;
      }

      double? asDouble(dynamic v) {
        if (v is num) return v.toDouble();
        return double.tryParse(v?.toString() ?? '');
      }

      final locRaw = joined['customerLocation'];
      final loc =
          locRaw is Map
              ? Map<String, dynamic>.from(locRaw as Map)
              : <String, dynamic>{};

      final fromLat = asDouble(
        joined['fromLatitude'] ?? loc['fromLatitude'] ?? loc['latitude'],
      );
      final fromLng = asDouble(
        joined['fromLongitude'] ?? loc['fromLongitude'] ?? loc['longitude'],
      );
      final toLat = asDouble(joined['toLatitude'] ?? loc['toLatitude']);
      final toLng = asDouble(joined['toLongitude'] ?? loc['toLongitude']);

      if (pickupAddressText.value.isEmpty &&
          fromLat != null &&
          fromLng != null) {
        pickupAddressText.value = await getAddressFromLatLng(fromLat, fromLng);
      }
      if (dropAddressText.value.isEmpty && toLat != null && toLng != null) {
        dropAddressText.value = await getAddressFromLatLng(toLat, toLng);
      }

      return;
    }

    // fallback: use passed addresses OR reverse geocode pickup
    if ((pickupLocationAddress ?? '').isNotEmpty) {
      pickupAddressText.value = pickupLocationAddress!;
    } else {
      pickupAddressText.value = await getAddressFromLatLng(
        pickupLocation.latitude,
        pickupLocation.longitude,
      );
    }
    if ((dropLocationAddress ?? '').isNotEmpty) {
      dropAddressText.value = dropLocationAddress!;
    }
  }

  Future<String> getAddressFromLatLng(double lat, double lng) async {
    try {
      final placemarks = await placemarkFromCoordinates(lat, lng);
      final p = placemarks.first;
      return "${p.name}, ${p.locality}, ${p.administrativeArea}";
    } catch (_) {
      return "Location not available";
    }
  }

  // ===================== MAP EVENTS =====================

  Future<void> onMapCreated(
    GoogleMapController gm,
    BuildContext context,
  ) async {
    // Map controller is attached by RideMapView; keep style behavior here.
    try {
      final style = await AppMapStyle.loadUberLight();
      await gm.setMapStyle(style);
    } catch (_) {}

    await Future<void>.delayed(const Duration(milliseconds: 250));
    await rideMap.fitToBounds(padding: 90);
  }

  Future<void> goToCurrentLocation() async {
    final ok = await _ensureLocationPermission();
    if (!ok) return;
    final pos = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    rideMap.updateVehicleLocation(
      LatLng(pos.latitude, pos.longitude),
      source: 'gps',
      speedMetersPerSecond: pos.speed.isFinite ? pos.speed : null,
      headingDeg: pos.heading.isFinite ? pos.heading : null,
      accuracyMeters: pos.accuracy.isFinite ? pos.accuracy : null,
      timestamp: pos.timestamp,
    );
    await rideMap.focusVehicle(zoom: 17.0, tilt: 0, bearingEnabled: false);
  }

  Future<bool> _ensureLocationPermission() async {
    if (!Get.isRegistered<LocationPermissionGuard>()) return false;
    return Get.find<LocationPermissionGuard>().ensureReady(showDialog: true);
  }

  Future<void> fitBoundsToDriverAndPickup() async {
    await rideMap.fitToBounds(padding: 90);
  }

  // ===================== ROUTE =====================

  String _stripHtml(String s) {
    return s
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&');
  }

  Future<void> _fetchRoute({bool force = false}) async {
    try {
      if (isNetworkOffline.value) {
        _pendingRouteRetry = true;
        _scheduleRouteRetry();
        return;
      }

      if (_routeFetchInFlight) {
        if (kDebugMode) {
          debugPrint('[ROUTE_DEDUPE] skipped reason=loading');
        }
        return;
      }

      final now = DateTime.now();
      if (_lastPos == null) {
        // Wait for a real driver location (GPS/socket). Never route from pickup/drop.
        return;
      }
      final origin = _lastPos!;
      final dest = pickupLocation;

      final sameOrigin =
          _lastRouteOrigin != null &&
          Geolocator.distanceBetween(
                _lastRouteOrigin!.latitude,
                _lastRouteOrigin!.longitude,
                origin.latitude,
                origin.longitude,
              ) <=
              10.0;
      final sameDest =
          _lastRouteDestination != null &&
          Geolocator.distanceBetween(
                _lastRouteDestination!.latitude,
                _lastRouteDestination!.longitude,
                dest.latitude,
                dest.longitude,
              ) <=
              10.0;
      final driverMovedSinceLast =
          _lastRouteOrigin == null
              ? 9999.0
              : Geolocator.distanceBetween(
                _lastRouteOrigin!.latitude,
                _lastRouteOrigin!.longitude,
                origin.latitude,
                origin.longitude,
              );
      final recentlyRequested =
          now.difference(_lastRouteRequestAt).inSeconds < (force ? 12 : 15);

      if (sameOrigin &&
          sameDest &&
          recentlyRequested &&
          driverMovedSinceLast < 50) {
        if (kDebugMode) {
          debugPrint(
            '[ROUTE_DEDUPE] skipped reason=same_origin_dest_recent '
            'force=$force moved=${driverMovedSinceLast.toStringAsFixed(1)}m',
          );
        }
        return;
      }

      if (!force &&
          now.difference(_lastRouteFetch).inSeconds < 8 &&
          driverMovedSinceLast < 30) {
        if (kDebugMode) {
          debugPrint('[ROUTE_DEDUPE] skipped reason=throttle');
        }
        return;
      }

      _lastRouteFetch = now;
      _lastRouteRequestAt = now;
      _lastRouteOrigin = origin;
      _lastRouteDestination = dest;
      _routeFetchInFlight = true;

      if (kDebugMode) {
        debugPrint(
          '[ROUTE_REQUEST] origin=driver lat=${origin.latitude} lng=${origin.longitude} '
          'dest=pickup lat=${pickupLocation.latitude} lng=${pickupLocation.longitude}',
        );
      }

      CommonLogger.log.i(
        '[PICKUP_ROUTE] request origin=$origin dest=$pickupLocation force=$force',
      );
      // Pickup navigation must always route to the *actual* pickup marker.
      // Do NOT use "driver friendly stop" adjusted destinations here, otherwise
      // the polyline can end before the pickup marker (screenshot issue).
      final result = await getRouteInfo(
        origin: origin,
        destination: dest,
        alternatives: false,
        traffic: true,
        mode: TravelModeResolver.getTravelMode(rideMap.vehicleType),
        routeIndex: 0,
      );

      // Route rendering must end at the actual pickup marker.
      adjustedPickupLocation.value = null;
      pickupAdjustMeters.value = 0;
      final poly = (result['polyline'] ?? '').toString();
      final rawPts = decodePolyline(poly);
      final pts = _simplifyPolyline(
        rawPts,
        // Preserve turns (less corner cutting) for a cleaner, Uber-like route.
        minStepMeters: 2.5,
        maxPoints: 650,
      );

      if (pts.length < 2) {
        _setDirectPolyline(origin, pickupLocation);
        if ((_cachedUiState?.polyline.length ?? 0) >= 2) {
          ui.value = _cachedUiState!;
        }
        _scheduleRouteRetry();
        CommonLogger.log.w(
          '[PICKUP_ROUTE] got <2 points, fallback direct polyline',
        );
        if (kDebugMode) {
          debugPrint(
            '[PICKUP_POLYLINE] driver=${origin.latitude},${origin.longitude} '
            'pickup=${pickupLocation.latitude},${pickupLocation.longitude}',
          );
          debugPrint('[PICKUP_POLYLINE] apiPoints=${pts.length}');
          debugPrint('[PICKUP_POLYLINE] fallbackDirect=true');
          debugPrint('[PICKUP_POLYLINE] setRoutePoints count=2');
        }
        return;
      }

      CommonLogger.log.i('[PICKUP_ROUTE] route pts=${pts.length}');

      // ================= Polyline validation/fix (must reach pickup marker) =================
      final double firstDistToDriver = Geolocator.distanceBetween(
        pts.first.latitude,
        pts.first.longitude,
        origin.latitude,
        origin.longitude,
      );
      final double lastDistToPickup = Geolocator.distanceBetween(
        pts.last.latitude,
        pts.last.longitude,
        pickupLocation.latitude,
        pickupLocation.longitude,
      );
      if (kDebugMode) {
        debugPrint(
          '[POLYLINE_VALIDATE] firstDistToDriver=${firstDistToDriver.toStringAsFixed(1)} '
          'lastDistToPickup=${lastDistToPickup.toStringAsFixed(1)} count=${pts.length}',
        );
      }

      final fixed = <LatLng>[...pts];
      if (firstDistToDriver > 10.0) {
        fixed.insert(0, origin);
        if (kDebugMode) {
          debugPrint(
            '[POLYLINE_FIX] prepended driver origin distance=${firstDistToDriver.toStringAsFixed(1)}m',
          );
        }
      }
      if (lastDistToPickup > 10.0) {
        fixed.add(pickupLocation);
        if (kDebugMode) {
          debugPrint(
            '[POLYLINE_FIX] appended pickup endpoint distance=${lastDistToPickup.toStringAsFixed(1)}m',
          );
        }
      }
      if (kDebugMode) {
        debugPrint(
          '[DISPLAY_POLYLINE] count=${fixed.length} first=${fixed.first.latitude},${fixed.first.longitude} '
          'last=${fixed.last.latitude},${fixed.last.longitude}',
        );
      }

      _hasRoadRoute = true;
      _poly = fixed;

      final routeDurMin =
          (result['durationMin'] is num)
              ? (result['durationMin'] as num).toDouble()
              : 0.0;
      ui.value = ui.value.copyWith(
        polyline: fixed,
        directionText: _stripHtml((result['direction'] ?? '').toString()),
        distanceText: (result['distance'] ?? '').toString(),
        maneuver: (result['maneuver'] ?? '').toString(),
        routeDurationMin: routeDurMin,
      );

      // Pickup marker must always equal active pickup destination.
      if (kDebugMode) {
        debugPrint(
          '[PICKUP_MARKER] lat=${pickupLocation.latitude} lng=${pickupLocation.longitude}',
        );
      }
      rideMap.setPickupDrop(pickup: pickupLocation, showPickupPin: true);
      rideMap.setRoutePoints(fixed);
      rideMap.setNavigationDestination(
        pickupLocation,
        driverFriendlyStop: false,
      );
      if (kDebugMode) {
        debugPrint(
          '[FIT_FULL_TRIP] mode=pickupNavigation points=${fixed.length} zoomClamp=true',
        );
      }
      unawaited(rideMap.fitFullTrip(padding: 95, clampMinZoom: true));
      final mp = result['maneuverPoints'];
      final maneuverPoints =
          mp is List
              ? mp
                  .whereType<Map>()
                  .map((e) => Map<String, dynamic>.from(e))
                  .toList()
              : const <Map<String, dynamic>>[];

      unawaited(
        _rebuildManeuverMarkers(
          // Use raw polyline for maneuver marker placement/rotation.
          rawPts.length >= 2 ? rawPts : pts,
          idPrefix: 'pickup_$bookingId',
          travelOrigin: origin,
          avoid: <LatLng>[pickupLocation],
          maneuverPoints: maneuverPoints,
        ),
      );
      final analytics = Get.find<DriverAnalyticsController>();
      analytics.setSlaFromEtaMinutes(
        driverStatusController.pickupDurationInMin.value,
      );
      final voiceLine = NavigationAssist.buildVoiceLine(
        maneuver: ui.value.maneuver,
        distanceText: ui.value.distanceText,
        directionText: ui.value.directionText,
      );
      NavigationVoiceService.instance.speakTurn(voiceLine);
      _cachedUiState = ui.value;
      _pendingRouteRetry = false;
    } catch (e) {
      CommonLogger.log.e("Route fetch failed: $e");
      _pendingRouteRetry = true;
      if (_cachedUiState != null) {
        ui.value = _cachedUiState!;
      }
      final origin = _lastPos ?? ui.value.driverLocation;
      if (origin != null) {
        _setDirectPolyline(origin, pickupLocation);
      }
      _scheduleRouteRetry();
    } finally {
      _routeFetchInFlight = false;
    }
  }

  void _setDirectPolyline(LatLng origin, LatLng dest) {
    if (_hasRoadRoute) return;
    // Fallback polyline must always connect real driver -> actual pickup destination.
    final direct = <LatLng>[origin, dest];
    _poly = direct;
    ui.value = ui.value.copyWith(polyline: direct);
    maneuverMarkers.clear();
    rideMap.setRoutePoints(direct);
    rideMap.setPickupDrop(pickup: pickupLocation, showPickupPin: true);
    rideMap.setNavigationDestination(pickupLocation, driverFriendlyStop: false);
  }

  Future<void> _rebuildManeuverMarkers(
    List<LatLng> pts, {
    required String idPrefix,
    LatLng? travelOrigin,
    List<LatLng> avoid = const <LatLng>[],
    List<Map<String, dynamic>>? maneuverPoints,
  }) async {
    final gen = ++_maneuverGen;
    try {
      final m = await ManeuverMarkers.build(
        polyline: pts,
        idPrefix: idPrefix,
        travelOrigin: travelOrigin,
        avoidPositions: avoid,
        maneuverPoints: maneuverPoints,
      );
      if (isClosed || gen != _maneuverGen) return;
      maneuverMarkers.assignAll(m);
      rideMap.setOverlays(markers: m.toSet());
    } catch (_) {
      // ignore
    }
  }

  void _scheduleRouteRetry() {
    _routeRetryTimer?.cancel();
    _routeRetryTimer = Timer(const Duration(seconds: 3), () {
      if (isNetworkOffline.value) return;
      _fetchRoute(force: true);
    });
  }

  void _trimPolyline(LatLng current) {
    if (_poly.length < 2) return;

    final closest = _closestPoint(
      current,
      _poly,
      limit: _POLYLINE_TRIM_LOOKAHEAD_POINTS,
    );
    final idx = closest.$1;
    final bestDistance = closest.$2;
    if (idx <= 0) return;
    if (bestDistance > _POLYLINE_TRIM_TOLERANCE_M) return;

    final keepFrom = (idx - 1).clamp(0, _poly.length - 2);
    final trimmed = _poly.sublist(keepFrom);
    if (trimmed.length < 2) return;

    _poly = trimmed;
    ui.value = ui.value.copyWith(polyline: _poly);
  }

  (int, double) _closestPoint(LatLng pos, List<LatLng> pts, {int? limit}) {
    double best = double.infinity;
    int idx = 0;
    final searchLimit =
        limit == null ? pts.length : math.min(pts.length, limit);
    for (int i = 0; i < searchLimit; i++) {
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
    return (idx, best);
  }

  LatLng _maybeSnapToRoute(LatLng raw) {
    // Avoid snapping when we only have a direct 2-point fallback line.
    if (_poly.length < 6) return raw;

    final snap = snapToPolyline(
      raw,
      _poly,
      maxSegments: _OFF_ROUTE_LOOKAHEAD_POINTS,
    );
    return snap.distanceMeters <= _SNAP_TOLERANCE_M ? snap.point : raw;
  }

  bool _isOffRoute(LatLng raw) {
    if (_poly.length < 6) return _poly.isEmpty;

    final snap = snapToPolyline(
      raw,
      _poly,
      maxSegments: _OFF_ROUTE_LOOKAHEAD_POINTS,
    );
    return snap.distanceMeters > _OFF_ROUTE_TOLERANCE_M;
  }

  // ===================== TRACKING + ANIMATION =====================

  void _startTracking() async {
    final ok = await _ensureLocationPermission();
    if (!ok) return;

    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation,
      );
      final raw = LatLng(pos.latitude, pos.longitude);
      final current = _maybeSnapToRoute(raw);
      _lastPos = current;
      _setDirectPolyline(current, pickupLocation);
      ui.value = ui.value.copyWith(driverLocation: current);
      _updateDriverReachedByDistance(current);
      await _fetchRoute(force: true);
    } catch (_) {}

    // Shared foreground GPS bus (one OS stream for all driver map screens).
    _posSub = DriverLocationBus.instance.stream.listen((pos) async {
      final acc = (pos.accuracy.isFinite) ? pos.accuracy : 9999.0;
      final raw = LatLng(pos.latitude, pos.longitude);
      final current = _maybeSnapToRoute(raw);

      // Always update "Arrived" gating from UI-side GPS, even if accuracy is
      // moderate (helps when socket is delayed).
      _updateDriverReachedByDistance(current);

      if (acc > _MAX_ACCURACY_M) return;
      final speed = (pos.speed.isFinite) ? pos.speed : 0.0;
      final heading = (pos.heading.isFinite) ? pos.heading : -1.0;
      _updateSmartAutoZoom(speed);

      if (_lastPos == null) {
        _lastPos = current;
        ui.value = ui.value.copyWith(driverLocation: current);
        rideMap.updateVehicleLocation(
          raw,
          source: 'gps',
          speedMetersPerSecond: speed.isFinite ? speed : null,
          headingDeg: heading >= 0 ? heading : null,
          accuracyMeters: acc,
          timestamp: pos.timestamp,
        );
        await _fetchRoute(force: true);
        return;
      }

      final moved = Geolocator.distanceBetween(
        _lastPos!.latitude,
        _lastPos!.longitude,
        current.latitude,
        current.longitude,
      );

      if (moved < _MIN_MOVE_METERS) {
        // tiny drift -> update location silently without rotation
        ui.value = ui.value.copyWith(driverLocation: current);
        rideMap.updateVehicleLocation(
          raw,
          source: 'gps',
          speedMetersPerSecond: speed.isFinite ? speed : null,
          headingDeg: heading >= 0 ? heading : null,
          accuracyMeters: acc,
          timestamp: pos.timestamp,
        );
        _lastPos = current;
        if (ui.value.polyline.length < 2) {
          await _fetchRoute(force: true);
        }
        return;
      }

      if (MapMotionProfile.shouldFreezeTurn(
        speedMs: speed,
        movedMeters: moved,
        accuracyM: acc,
      )) {
        ui.value = ui.value.copyWith(
          driverLocation: current,
          bearing: ui.value.bearing,
        );
        rideMap.updateVehicleLocation(
          raw,
          source: 'gps',
          speedMetersPerSecond: speed.isFinite ? speed : null,
          headingDeg: heading >= 0 ? heading : null,
          accuracyMeters: acc,
          timestamp: pos.timestamp,
        );
        _lastPos = current;
        _updateDriverReachedByDistance(current);
        return;
      }

      double targetBearing = ui.value.bearing;

      final shouldHoldBearing =
          speed < _MIN_SPEED_MS || moved < _STATIONARY_DRIFT_M;

      if (shouldHoldBearing) {
        targetBearing = ui.value.bearing;
      } else if (speed >= _HEADING_TRUST_MS && heading >= 0) {
        targetBearing = heading;
      } else {
        targetBearing = _bearingBetween(ui.value.driverLocation, current);
      }

      final diff = MapMotionProfile.angleDelta(ui.value.bearing, targetBearing);
      if (speed < _MIN_SPEED_MS && diff < _MIN_TURN_DEG) {
        targetBearing = ui.value.bearing;
      }

      targetBearing = MapMotionProfile.smoothBearing(
        current: ui.value.bearing,
        target: targetBearing,
        speedMs: speed,
      );

      ui.value = ui.value.copyWith(
        driverLocation: current,
        bearing: targetBearing,
      );
      rideMap.updateVehicleLocation(
        raw,
        source: 'gps',
        speedMetersPerSecond: speed.isFinite ? speed : null,
        headingDeg: heading >= 0 ? heading : null,
        accuracyMeters: acc,
        timestamp: pos.timestamp,
      );

      _lastPos = current;
      _updateDriverReachedByDistance(current);

      final offRoute = _isOffRoute(raw);
      isOffRouteAlert.value = offRoute;
      if (offRoute) {
        await _fetchRoute(force: true);
      } else {
        await _fetchRoute(force: false);
      }
    });
  }

  void _updateDriverReachedByDistance(LatLng current) {
    if (enableArrivedTesting) {
      driverReached.value = true;
      _driverReachedGps = true;
      return;
    }

    final distanceToPickup = Geolocator.distanceBetween(
      current.latitude,
      current.longitude,
      pickupLocation.latitude,
      pickupLocation.longitude,
    );

    _lastGpsFixAt = DateTime.now();
    if (!_driverReachedGps && distanceToPickup <= _ARRIVED_PICKUP_RADIUS_M) {
      _driverReachedGps = true;
      CommonLogger.log.i(
        "Auto driverReached TRUE (gps) at ${distanceToPickup.toStringAsFixed(1)}m from pickup",
      );
    } else if (_driverReachedGps &&
        distanceToPickup >= _ARRIVED_PICKUP_EXIT_RADIUS_M) {
      // Hysteresis: avoid flicker around the threshold.
      _driverReachedGps = false;
    }

    _recomputeDriverReached();
  }

  void _recomputeDriverReached() {
    if (!arrivedAtPickup.value) return;

    final now = DateTime.now();
    final gpsFresh =
        _lastGpsFixAt != null &&
        now.difference(_lastGpsFixAt!) <= _gpsReachedTtl;
    final socketFresh =
        _lastSocketFixAt != null &&
        now.difference(_lastSocketFixAt!) <= _socketReachedTtl;

    // Priority rule:
    // - If GPS is fresh, trust GPS (even if socket says otherwise).
    // - Else fall back to socket.
    final next =
        gpsFresh
            ? _driverReachedGps
            : (socketFresh ? _driverReachedSocket : false);

    if (driverReached.value != next) {
      driverReached.value = next;
    }
  }

  void _updateSmartAutoZoom(double speedMs) {
    final targetZoom = MapMotionProfile.targetZoomFromSpeed(
      speedMs,
    ).clamp(15.2, 17.8);
    followZoom.value = MapMotionProfile.smoothZoom(
      followZoom.value,
      targetZoom,
    ).clamp(15.2, 17.8);
  }

  Future<void> _animateTo(LatLng to, double bearing) async {
    if (_animating) {
      _queuedTarget = to;
      _queuedBearing = bearing;
      return;
    }
    _animating = true;

    final from = ui.value.driverLocation;
    final startBearing = ui.value.bearing;
    final endBearing = MapMotionProfile.shortestAngle(startBearing, bearing);

    const steps = 24;
    const total = Duration(milliseconds: 620);
    final stepMs = total.inMilliseconds ~/ steps;

    for (int i = 1; i <= steps; i++) {
      await Future.delayed(Duration(milliseconds: stepMs));
      final linearT = i / steps;
      final t = Curves.easeInOut.transform(linearT);

      final lat = _lerp(from.latitude, to.latitude, t);
      final lng = _lerp(from.longitude, to.longitude, t);
      final b = _lerpBearing(startBearing, endBearing, t);

      ui.value = ui.value.copyWith(
        driverLocation: LatLng(lat, lng),
        bearing: MapMotionProfile.normalizeAngle(b),
      );
    }

    _animating = false;
    if (_queuedTarget != null && _queuedBearing != null) {
      final nextTarget = _queuedTarget!;
      final nextBearing = _queuedBearing!;
      _queuedTarget = null;
      _queuedBearing = null;
      await _animateTo(nextTarget, nextBearing);
    }
  }

  LatLngBounds _safeBounds(
    double minLat,
    double minLng,
    double maxLat,
    double maxLng,
  ) {
    const eps = 0.00012;
    if ((maxLat - minLat).abs() < eps) {
      maxLat += eps;
      minLat -= eps;
    }
    if ((maxLng - minLng).abs() < eps) {
      maxLng += eps;
      minLng -= eps;
    }
    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  Future<void> refreshRouteNow() async {
    await _fetchRoute(force: true);
  }

  void ensureRouteReady() {
    if (ui.value.polyline.length >= 2 || isNetworkOffline.value) return;
    if (_routeRefreshQueued) return;
    _routeRefreshQueued = true;
    Future.microtask(() async {
      try {
        await refreshRouteNow();
      } finally {
        _routeRefreshQueued = false;
      }
    });
  }

  Future<void> focusRouteOverview() async {
    isDriverFocused.value = false;
    rideMap.setAutoFollowEnabled(false);
    // Second tap behavior: fit full trip route when available.
    // If route isn't ready yet, RideMapController safely falls back.
    await rideMap.fitFullTrip(padding: 95);
  }

  Future<void> focusDriverNow() async {
    isDriverFocused.value = true;
    rideMap.setAutoFollowEnabled(true);
    await rideMap.focusVehicle(zoom: 17.2, tilt: 0, bearingEnabled: true);
  }

  Future<void> focusDriverMarker({double? zoom}) async {
    isDriverFocused.value = true;
    final z = (zoom ?? followZoom.value).clamp(14.8, 18.0);
    rideMap.setAutoFollowEnabled(true);
    await rideMap.focusVehicle(zoom: z, tilt: 0, bearingEnabled: true);
  }

  Future<bool> sendQuickMessage(String text, {int? delayMinutes}) async {
    final driverId = _driverId ?? await SharedPrefHelper.getDriverId();
    final payload = <String, dynamic>{
      'bookingId': bookingId,
      'driverId': driverId,
      'delayMinutes': (delayMinutes ?? 0) < 0 ? 0 : (delayMinutes ?? 0),
      'message': text,
    };

    if (isNetworkOffline.value || !socketService.connected) {
      _enqueueSocketEmit('driver-message', payload);
      return false; // queued (offline / not connected)
    }

    final completer = Completer<bool>();
    Timer? timeout;
    timeout = Timer(const Duration(milliseconds: 1200), () {
      if (completer.isCompleted) return;
      // If the server doesn't ACK quickly, treat this as "sent" for UI feedback.
      // The queue fallback still protects delivery if ACK later fails.
      completer.complete(true);
    });

    socketService.emitWithAck('driver-message', payload, (ack) {
      final ok = (ack is Map && ack['success'] == true);
      if (!ok) {
        _enqueueSocketEmit('driver-message', payload);
      }
      timeout?.cancel();
      if (!completer.isCompleted) completer.complete(ok);
    });

    return completer.future;
  }

  void _enqueueSocketEmit(String event, Map<String, dynamic> payload) {
    _socketRetryQueue.add(_QueuedSocketEmit(event: event, payload: payload));
    pendingQueueCount.value = _socketRetryQueue.length;
  }

  void _flushSocketRetryQueue() {
    if (_socketRetryQueue.isEmpty || !socketService.connected) return;
    final queued = List<_QueuedSocketEmit>.from(_socketRetryQueue);
    _socketRetryQueue.clear();
    pendingQueueCount.value = 0;
    for (final q in queued) {
      socketService.emitWithAck(q.event, q.payload, (ack) {
        final ok = (ack is Map && ack['success'] == true);
        if (!ok) {
          _enqueueSocketEmit(q.event, q.payload);
        }
      });
    }
  }

  double _lerp(double a, double b, double t) => a + (b - a) * t;

  double _lerpBearing(double start, double end, double t) {
    double difference = ((end - start + 540) % 360) - 180;
    return (start + difference * t + 360) % 360;
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

  double _angleDeltaDeg(double a, double b) {
    double d = (b - a) % 360;
    if (d > 180) d -= 360;
    if (d < -180) d += 360;
    return d.abs();
  }

  double _smoothBearing({
    required double current,
    required double target,
    required double speedMs,
  }) {
    final delta = ((target - current + 540) % 360) - 180;

    final gain =
        speedMs >= 8
            ? 0.65
            : speedMs >= 4
            ? 0.55
            : 0.42;

    return _normalizeAngle(current + (delta * gain));
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

  double _degToRad(double d) => d * (math.pi / 180.0);

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

  // ===================== TIMER =====================

  void startNoShowTimer() {
    _stopNoShowTimer();
    secondsLeft.value = 300;
    showRedTimer.value = false;

    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (secondsLeft.value <= 0) {
        t.cancel();
        Get.find<DriverAnalyticsController>().trackNoShow();
        return;
      }
      secondsLeft.value--;
      showRedTimer.value = secondsLeft.value <= 10;
    });
  }

  void _stopNoShowTimer() {
    _timer?.cancel();
    _timer = null;
    secondsLeft.value = 0;
    showRedTimer.value = false;
  }

  String formatTimer(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // ===================== ACTIONS =====================

  Future<void> onArrivedAtPickupPressed(BuildContext context) async {
    if (isArrivedSubmitting.value) return;
    isArrivedSubmitting.value = true;
    try {
      final res = await driverStatusController.driverArrived(
        context,
        bookingId: bookingId,
      );

      if (res != null && res.status == 200) {
        arrivedAtPickup.value = false;
        // Freeze reached state once we transition out of pickup-navigation UI.
        driverReached.value = true;
        startNoShowTimer();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res?.message ?? "Something went wrong")),
        );
      }
    } finally {
      isArrivedSubmitting.value = false;
    }
  }

  Future<void> onSwipeStartRide(BuildContext context) async {
    if (_otpNavInFlight) return;
    _otpNavInFlight = true;

    // request OTP
    try {
      final msg = await driverStatusController.otpRequest(
        context,
        bookingId: bookingId,
        custName: customerName.value,
        pickupAddress: pickupLocationAddress ?? pickupAddressText.value,
        dropAddress: dropLocationAddress ?? dropAddressText.value,
      );

      if (msg == null) return;

      _stopNoShowTimer();

      // Navigate to verify screen (prevent duplicate pushes)
      if (Get.currentRoute.contains('VerifyRiderScreen')) return;

      Get.to(
        () => VerifyRiderScreen(
          bookingId: bookingId,
          custName: customerName.value,
          pickupAddress: pickupLocationAddress ?? pickupAddressText.value,
          dropAddress: dropLocationAddress ?? dropAddressText.value,
          isSharedRide: false,
          isParcel: isParcel.value,
          parcelType: parcelType.value,
          parcelWeight: parcelWeight.value,
        ),
      );
    } finally {
      _otpNavInFlight = false;
    }
  }

  void debugSetDriverReachedTrue() {
    driverReached.value = true;
    CommonLogger.log.i("Test action: driverReached set to true manually");
  }
  // ===================== ICON HELPERS =====================

  String getManeuverIcon(String maneuver) {
    switch (maneuver) {
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
}

// // lib/Presentation/DriverScreen/controller/picking_customer_controller.dart
//
// import 'dart:async';
// import 'dart:math' as math;
//
// import 'package:flutter/foundation.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:geocoding/geocoding.dart';
// import 'package:geolocator/geolocator.dart';
// import 'package:get/get.dart';
// import 'package:google_maps_flutter/google_maps_flutter.dart';
//
// import 'package:hopper/Core/Constants/log.dart';
// import 'package:hopper/Core/Utility/images.dart';
// import 'package:hopper/Presentation/DriverScreen/controller/driver_status_controller.dart';
// import 'package:hopper/utils/websocket/socket_io_client.dart';
//
// import '../../../utils/map/route_info.dart';
// import '../screens/verify_rider_screen.dart';
//
// // keep your existing map helpers
//
// class PickingCustomerUiState {
//   final LatLng driverLocation;
//   final double bearing;
//   final List<LatLng> polyline;
//   final String directionText;
//   final String distanceText;
//   final String maneuver;
//
//   const PickingCustomerUiState({
//     required this.driverLocation,
//     required this.bearing,
//     required this.polyline,
//     required this.directionText,
//     required this.distanceText,
//     required this.maneuver,
//   });
//
//   PickingCustomerUiState copyWith({
//     LatLng? driverLocation,
//     double? bearing,
//     List<LatLng>? polyline,
//     String? directionText,
//     String? distanceText,
//     String? maneuver,
//   }) {
//     return PickingCustomerUiState(
//       driverLocation: driverLocation ?? this.driverLocation,
//       bearing: bearing ?? this.bearing,
//       polyline: polyline ?? this.polyline,
//       directionText: directionText ?? this.directionText,
//       distanceText: distanceText ?? this.distanceText,
//       maneuver: maneuver ?? this.maneuver,
//     );
//   }
// }
//
// class PickingCustomerController extends GetxController
//     with GetSingleTickerProviderStateMixin {
//   PickingCustomerController({
//     required this.pickupLocation,
//     required this.bookingId,
//     required LatLng driverLocation, // ÃƒÆ’Ã‚Â¢Ãƒâ€¦Ã¢â‚¬Å“ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¦ add this
//     this.pickupLocationAddress,
//     this.dropLocationAddress,
//   }) : _initialDriverLocation = driverLocation;
//
//   // Inputs
//   final LatLng pickupLocation;
//   final String bookingId;
//   final String? pickupLocationAddress;
//   final String? dropLocationAddress;
//
//   final LatLng _initialDriverLocation;
//
//   // External
//   final DriverStatusController driverStatusController = Get.put(
//     DriverStatusController(),
//   );
//
//   // Socket
//   late final SocketService socketService;
//
//   // Map controller
//   GoogleMapController? mapController;
//
//   // UI State
//   final Rx<PickingCustomerUiState> ui =
//       PickingCustomerUiState(
//         driverLocation: const LatLng(0, 0),
//         bearing: 0,
//         polyline: const [],
//         directionText: '',
//         distanceText: '',
//         maneuver: '',
//       ).obs;
//
//   // Marker icon
//   final Rxn<BitmapDescriptor> carIcon = Rxn<BitmapDescriptor>();
//
//   // Rider meta (keep your fields)
//   final RxString customerName = ''.obs;
//   final RxString customerPhone = ''.obs;
//   final RxString customerProfilePic = ''.obs;
//
//   final RxString pickupAddressText = ''.obs;
//   final RxString dropAddressText = ''.obs;
//
//   final RxBool driverReached = false.obs; // from server driver-arrived
//   final RxBool arrivedAtPickup =
//       true.obs; // your UI flow (before arrived button)
//
//   // Timer (No-show)
//   Timer? _timer;
//   final RxInt secondsLeft = 0.obs;
//   final RxBool showRedTimer = false.obs;
//
//   // Location stream
//   StreamSubscription<Position>? _posSub;
//
//   // Route throttle
//   DateTime? _lastRouteTick;
//   LatLng? _lastDriverLocForUi;
//   double _lastBearingForUi = 0;
//
//   // Smooth animation
//   late final AnimationController animCtrl;
//   late final Animation<double> anim;
//   Tween<double>? latTween;
//   Tween<double>? lngTween;
//   Tween<double>? rotTween;
//
//   LatLng? _lastPosition;
//
//   // Performance tuning
//   static const double _maxAccuracyM = 25.0;
//   static const double _minMoveMeters = 2.5;
//   static const int _routeThrottleMs = 350;
//   static const double _bearingChangeMin = 3.0;
//
//   // -------------------- lifecycle --------------------
//
//   @override
//   void onInit() {
//     super.onInit();
//
//     ui.value = ui.value.copyWith(driverLocation: _initialDriverLocation);
//
//     animCtrl = AnimationController(
//       vsync: this,
//       duration: const Duration(milliseconds: 650),
//     );
//
//     anim = CurvedAnimation(parent: animCtrl, curve: Curves.easeOutCubic)
//       ..addListener(_onAnimTick);
//
//     _loadCarIcon();
//     _initSocket();
//     _initFirstRouteAndStartTracking();
//   }
//
//   @override
//   void onClose() {
//     _timer?.cancel();
//     _posSub?.cancel();
//     animCtrl.dispose();
//
//     try {
//       socketService.socket.off('joined-booking');
//       socketService.socket.off('driver-location');
//       socketService.socket.off('driver-cancelled');
//       socketService.socket.off('customer-cancelled');
//       socketService.socket.off('driver-arrived');
//     } catch (_) {}
//
//     super.onClose();
//   }
//
//   // -------------------- map --------------------
//
//   Future<void> onMapCreated(GoogleMapController c, BuildContext context) async {
//     mapController = c;
//
//     try {
//       final style = await DefaultAssetBundle.of(
//         context,
//       ).loadString('assets/map_style/map_style1.json');
//       await mapController?.setMapStyle(style);
//     } catch (e) {
//       if (kDebugMode) CommonLogger.log.w("Map style load failed: $e");
//     }
//
//     await fitBoundsToDriverAndPickup();
//   }
//
//   Future<void> fitBoundsToDriverAndPickup() async {
//     if (mapController == null) return;
//
//     final d = ui.value.driverLocation;
//     final bounds = LatLngBounds(
//       southwest: LatLng(
//         math.min(d.latitude, pickupLocation.latitude),
//         math.min(d.longitude, pickupLocation.longitude),
//       ),
//       northeast: LatLng(
//         math.max(d.latitude, pickupLocation.latitude),
//         math.max(d.longitude, pickupLocation.longitude),
//       ),
//     );
//
//     await mapController!.animateCamera(
//       CameraUpdate.newLatLngBounds(bounds, 90),
//     );
//
//     final zoom = await mapController!.getZoomLevel();
//     if (zoom > 16) {
//       await mapController!.animateCamera(CameraUpdate.zoomTo(16));
//     }
//   }
//
//   Future<void> goToCurrentLocation() async {
//     final pos = await _getCurrentPos();
//     if (pos == null) return;
//
//     final latLng = LatLng(pos.latitude, pos.longitude);
//     await mapController?.animateCamera(CameraUpdate.newLatLngZoom(latLng, 17));
//   }
//
//   // -------------------- icon --------------------
//
//   Future<void> _loadCarIcon() async {
//     try {
//       final cfg = const ImageConfiguration(size: Size(42, 42));
//       final String asset =
//           driverStatusController.serviceType.value == "Bike"
//               ? AppImages.parcelBike
//               : AppImages.movingCar;
//
//       final icon = await BitmapDescriptor.asset(cfg, asset);
//       carIcon.value = icon;
//     } catch (_) {
//       carIcon.value = BitmapDescriptor.defaultMarker;
//     }
//   }
//
//   // -------------------- socket --------------------
//
//   Future<void> _initSocket() async {
//     socketService = SocketService();
//     // your SocketService already knows where to connect (based on your app)
//     // if you need initSocket(url), do it here.
//     // socketService.initSocket(ApiConstents.socketUrl);
//
//     socketService.on('joined-booking', (data) async {
//       if (data == null) return;
//
//       try {
//         // if you store joined data somewhere, keep it
//         // JoinedBookingData().setData(data);
//
//         final vehicle = data['vehicle'] ?? {};
//         final String customerN = (data['customerName'] ?? '').toString();
//         final String customerP = (data['customerPhone'] ?? '').toString();
//         final String customerPic =
//             (data['customerProfilePic'] ?? '').toString();
//
//         customerName.value = customerN;
//         customerPhone.value = customerP;
//         customerProfilePic.value = customerPic;
//
//         // addresses from customerLocation
//         final customerLoc = data['customerLocation'];
//         if (customerLoc != null) {
//           final double fromLat =
//               (customerLoc['fromLatitude'] as num).toDouble();
//           final double fromLng =
//               (customerLoc['fromLongitude'] as num).toDouble();
//           final double toLat = (customerLoc['toLatitude'] as num).toDouble();
//           final double toLng = (customerLoc['toLongitude'] as num).toDouble();
//
//           pickupAddressText.value = await getAddressFromLatLng(
//             fromLat,
//             fromLng,
//           );
//           dropAddressText.value = await getAddressFromLatLng(toLat, toLng);
//         } else {
//           pickupAddressText.value = pickupLocationAddress ?? '';
//           dropAddressText.value = dropLocationAddress ?? '';
//         }
//
//         CommonLogger.log.i("ÃƒÆ’Ã‚Â¢Ãƒâ€¦Ã¢â‚¬Å“ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¦ joined-booking handled for $bookingId");
//         CommonLogger.log.i("vehicle: $vehicle");
//       } catch (e) {
//         CommonLogger.log.e("joined-booking parse error: $e");
//       }
//     });
//
//     socketService.on('driver-location', (data) {
//       if (data == null) return;
//
//       // ETA meters/min update (your existing logic)
//       if (data['pickupDistanceInMeters'] != null) {
//         driverStatusController.pickupDistanceInMeters.value =
//             (data['pickupDistanceInMeters'] as num).toDouble();
//       }
//       if (data['pickupDurationInMin'] != null) {
//         driverStatusController.pickupDurationInMin.value =
//             (data['pickupDurationInMin'] as num).toDouble();
//       }
//     });
//
//     socketService.on('driver-arrived', (data) {
//       final status = data?['status'];
//       final ok = status == true || status.toString() == 'true';
//       if (ok) {
//         driverReached.value = true;
//       }
//     });
//
//     socketService.on('driver-cancelled', (data) {
//       final ok = data != null && data['status'] == true;
//       if (ok) {
//         Get.offAllNamed('/driverMain'); // or push DriverMainScreen()
//       }
//     });
//
//     socketService.on('customer-cancelled', (data) {
//       final ok = data != null && data['status'] == true;
//       if (ok) {
//         Get.offAllNamed('/driverMain');
//       }
//     });
//
//     if (!socketService.connected) {
//       socketService.connect();
//       socketService.onConnect(() => CommonLogger.log.i("ÃƒÆ’Ã‚Â¢Ãƒâ€¦Ã¢â‚¬Å“ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¦ socket connected"));
//     }
//   }
//
//   // -------------------- permissions + pos --------------------
//
//   Future<bool> _ensureLocationPermission() async {
//     final serviceEnabled = await Geolocator.isLocationServiceEnabled();
//     if (!serviceEnabled) return false;
//
//     var permission = await Geolocator.checkPermission();
//     if (permission == LocationPermission.denied) {
//       permission = await Geolocator.requestPermission();
//     }
//
//     return permission == LocationPermission.always ||
//         permission == LocationPermission.whileInUse;
//   }
//
//   Future<Position?> _getCurrentPos() async {
//     final ok = await _ensureLocationPermission();
//     if (!ok) return null;
//
//     return Geolocator.getCurrentPosition(
//       desiredAccuracy: LocationAccuracy.bestForNavigation,
//     );
//   }
//
//   // -------------------- route + tracking --------------------
//
//   Future<void> _initFirstRouteAndStartTracking() async {
//     final pos = await _getCurrentPos();
//     if (pos != null) {
//       final latLng = LatLng(pos.latitude, pos.longitude);
//       ui.value = ui.value.copyWith(driverLocation: latLng);
//       _lastPosition = latLng;
//       _lastDriverLocForUi = latLng;
//     } else {
//       _lastPosition = ui.value.driverLocation;
//       _lastDriverLocForUi = ui.value.driverLocation;
//     }
//
//     await _fetchRoute(origin: ui.value.driverLocation);
//     _startTrackingStream();
//   }
//
//   void _startTrackingStream() {
//     _posSub?.cancel();
//
//     _posSub = Geolocator.getPositionStream(
//       locationSettings: const LocationSettings(
//         accuracy: LocationAccuracy.bestForNavigation,
//         distanceFilter: 3,
//       ),
//     ).listen((p) async {
//       final acc = p.accuracy.isFinite ? p.accuracy : 9999.0;
//       if (acc > _maxAccuracyM) return;
//
//       final newLoc = LatLng(p.latitude, p.longitude);
//       final last = _lastPosition ?? newLoc;
//
//       final moved = Geolocator.distanceBetween(
//         last.latitude,
//         last.longitude,
//         newLoc.latitude,
//         newLoc.longitude,
//       );
//       if (moved < _minMoveMeters) return;
//
//       // bearing from path (more stable)
//       final newBearing = _bearingBetween(last, newLoc);
//
//       // smooth animate marker
//       _animateMarkerTo(newLoc, newBearing);
//
//       _lastPosition = newLoc;
//
//       // route tick throttle
//       final now = DateTime.now();
//       if (_lastRouteTick != null &&
//           now.difference(_lastRouteTick!).inMilliseconds < _routeThrottleMs) {
//         return;
//       }
//       _lastRouteTick = now;
//
//       final double movedUi =
//           _lastDriverLocForUi == null
//               ? 999
//               : _haversineMeters(_lastDriverLocForUi!, newLoc);
//       final bool bearingChanged =
//           (newBearing - _lastBearingForUi).abs() > _bearingChangeMin;
//
//       if (movedUi < 2.0 && !bearingChanged) return;
//
//       _lastDriverLocForUi = newLoc;
//       _lastBearingForUi = newBearing;
//
//       // trim polyline + reroute if off-route
//       _trimPolylineFromCurrent(newLoc);
//
//       if (_isOffRoute(newLoc)) {
//         await _fetchRoute(origin: newLoc);
//       }
//     });
//   }
//
//   Future<void> _fetchRoute({required LatLng origin}) async {
//     try {
//       final result = await getRouteInfo(
//         origin: origin,
//         destination: pickupLocation,
//       );
//
//       final String dir = (result['direction'] ?? '').toString();
//       final String dist = (result['distance'] ?? '').toString();
//       final String man = (result['maneuver'] ?? '').toString();
//
//       List<LatLng> pts = decodePolyline((result['polyline'] ?? '').toString());
//
//       // simplify polyline for performance
//       pts = _simplifyPolyline(pts, minStepMeters: 8, maxPoints: 180);
//
//       ui.value = ui.value.copyWith(
//         directionText: _stripHtml(dir),
//         distanceText: dist,
//         maneuver: man,
//         polyline: pts,
//       );
//     } catch (e) {
//       CommonLogger.log.e("route fetch error: $e");
//     }
//   }
//
//   void _trimPolylineFromCurrent(LatLng current) {
//     final pts = ui.value.polyline;
//     if (pts.isEmpty) return;
//
//     int closestIndex = _closestPointIndex(current, pts);
//     if (closestIndex <= 0) return;
//     if (closestIndex >= pts.length) return;
//
//     // Trim once (fixed your old double sublist bug)
//     final trimmed = pts.sublist(closestIndex);
//
//     ui.value = ui.value.copyWith(polyline: trimmed);
//   }
//
//   int _closestPointIndex(LatLng pos, List<LatLng> pts) {
//     double min = double.infinity;
//     int best = 0;
//
//     for (int i = 0; i < pts.length; i++) {
//       final d = Geolocator.distanceBetween(
//         pos.latitude,
//         pos.longitude,
//         pts[i].latitude,
//         pts[i].longitude,
//       );
//       if (d < min) {
//         min = d;
//         best = i;
//       }
//     }
//     return best;
//   }
//
//   bool _isOffRoute(LatLng pos) {
//     final pts = ui.value.polyline;
//     if (pts.isEmpty) return true;
//
//     for (final p in pts) {
//       final d = Geolocator.distanceBetween(
//         pos.latitude,
//         pos.longitude,
//         p.latitude,
//         p.longitude,
//       );
//       if (d < 20) return false; // within 20m = on route
//     }
//     return true;
//   }
//
//   // -------------------- smooth marker --------------------
//
//   void _animateMarkerTo(LatLng newPos, double bearing) {
//     final current = ui.value.driverLocation;
//
//     latTween = Tween(begin: current.latitude, end: newPos.latitude);
//     lngTween = Tween(begin: current.longitude, end: newPos.longitude);
//
//     // rotate via shortest path
//     final curRot = ui.value.bearing;
//     final endRot = _shortestAngle(curRot, bearing);
//     rotTween = Tween(begin: curRot, end: endRot);
//
//     animCtrl
//       ..stop()
//       ..reset()
//       ..forward();
//   }
//
//   void _onAnimTick() {
//     final lt = latTween;
//     final lg = lngTween;
//     final rt = rotTween;
//     if (lt == null || lg == null || rt == null) return;
//
//     final lat = lt.evaluate(anim);
//     final lng = lg.evaluate(anim);
//     final rot = rt.evaluate(anim);
//
//     ui.value = ui.value.copyWith(
//       driverLocation: LatLng(lat, lng),
//       bearing: _normalizeAngle(rot),
//     );
//
//     // optional: camera follow if you want Uber feel (can be heavy if always)
//     // mapController?.animateCamera(
//     //   CameraUpdate.newCameraPosition(
//     //     CameraPosition(target: ui.value.driverLocation, zoom: 17, tilt: 60, bearing: ui.value.bearing),
//     //   ),
//     // );
//   }
//
//   // -------------------- timer controls --------------------
//
//   void startNoShowTimer() {
//     _timer?.cancel();
//     secondsLeft.value = 300;
//     showRedTimer.value = false;
//
//     _timer = Timer.periodic(const Duration(seconds: 1), (t) {
//       if (secondsLeft.value > 0) {
//         secondsLeft.value -= 1;
//         showRedTimer.value = secondsLeft.value <= 10;
//       } else {
//         t.cancel();
//       }
//     });
//   }
//
//   void stopNoShowTimer() {
//     _timer?.cancel();
//     _timer = null;
//     secondsLeft.value = 0;
//     showRedTimer.value = false;
//   }
//
//   String formatTimer(int seconds) {
//     final m = (seconds ~/ 60).toString().padLeft(2, '0');
//     final s = (seconds % 60).toString().padLeft(2, '0');
//     return '$m:$s';
//   }
//
//   // -------------------- actions used by UI --------------------
//
//   Future<void> onArrivedAtPickupPressed(BuildContext context) async {
//     final result = await driverStatusController.driverArrived(
//       context,
//       bookingId: bookingId,
//     );
//
//     if (result != null && result.status == 200) {
//       arrivedAtPickup.value = false; // move to waiting rider flow
//       startNoShowTimer();
//     } else {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text(result?.message ?? "Something went wrong")),
//       );
//     }
//   }
//
//   Future<void> onSwipeStartRide(BuildContext context) async {
//     // 1) Request OTP
//     final msg = await driverStatusController.otpRequest(
//       context,
//       bookingId: bookingId,
//       custName: customerName.value,
//       pickupAddress: pickupLocationAddress ?? pickupAddressText.value,
//       dropAddress: dropLocationAddress ?? dropAddressText.value,
//     );
//
//     // 2) If OTP request failed -> stop here
//     if (msg == null) return;
//
//     // 3) Stop timer (no-show timer etc.)
//     stopNoShowTimer();
//
//     // 4) Navigate to Verify screen
//     //    ÃƒÆ’Ã‚Â¢Ãƒâ€¦Ã¢â‚¬Å“ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¦ single ride -> it will go RideStatsScreen after verify
//     Get.to(
//       () => VerifyRiderScreen(
//         bookingId: bookingId,
//         custName: customerName.value,
//         pickupAddress: pickupLocationAddress ?? pickupAddressText.value,
//         dropAddress: dropLocationAddress ?? dropAddressText.value,
//         isSharedRide: false, // ÃƒÆ’Ã‚Â¢Ãƒâ€¦Ã¢â‚¬Å“ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¦ single pickup screen
//       ),
//     );
//   }
//
//   // Future<void> onSwipeStartRide(BuildContext context) async {
//   //   final msg = await driverStatusController.otpRequest(
//   //     context,
//   //     bookingId: bookingId,
//   //     custName: customerName.value,
//   //     pickupAddress: pickupLocationAddress ?? pickupAddressText.value,
//   //     dropAddress: dropLocationAddress ?? dropAddressText.value,
//   //   );
//   //
//   //   if (msg != null) {
//   //     stopNoShowTimer();
//   //   }
//   // }
//
//   // -------------------- helpers --------------------
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
//   double _bearingBetween(LatLng start, LatLng end) {
//     final lat1 = start.latitude * (math.pi / 180.0);
//     final lon1 = start.longitude * (math.pi / 180.0);
//     final lat2 = end.latitude * (math.pi / 180.0);
//     final lon2 = end.longitude * (math.pi / 180.0);
//
//     final dLon = lon2 - lon1;
//     final y = math.sin(dLon) * math.cos(lat2);
//     final x =
//         math.cos(lat1) * math.sin(lat2) -
//         math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
//
//     final brng = math.atan2(y, x);
//     return (brng * 180 / math.pi + 360) % 360;
//   }
//
//   double _shortestAngle(double from, double to) {
//     double diff = (to - from) % 360;
//     if (diff > 180) diff -= 360;
//     return from + diff;
//   }
//
//   double _normalizeAngle(double a) {
//     a %= 360;
//     if (a < 0) a += 360;
//     return a;
//   }
//
//   String _stripHtml(String htmlText) {
//     return htmlText
//         .replaceAll(RegExp(r'<[^>]*>'), '')
//         .replaceAll('&nbsp;', ' ')
//         .replaceAll('&amp;', '&');
//   }
//
//   double _degToRad(double d) => d * (math.pi / 180.0);
//
//   double _haversineMeters(LatLng a, LatLng b) {
//     const r = 6371000.0;
//     final dLat = _degToRad(b.latitude - a.latitude);
//     final dLon = _degToRad(b.longitude - a.longitude);
//     final lat1 = _degToRad(a.latitude);
//     final lat2 = _degToRad(b.latitude);
//
//     final h =
//         math.sin(dLat / 2) * math.sin(dLat / 2) +
//         math.cos(lat1) *
//             math.cos(lat2) *
//             math.sin(dLon / 2) *
//             math.sin(dLon / 2);
//
//     return 2 * r * math.asin(math.sqrt(h));
//   }
//
//   List<LatLng> _simplifyPolyline(
//     List<LatLng> points, {
//     required double minStepMeters,
//     required int maxPoints,
//   }) {
//     if (points.length <= 2) return points;
//     final simplified = <LatLng>[points.first];
//
//     LatLng last = points.first;
//     for (int i = 1; i < points.length - 1; i++) {
//       final p = points[i];
//       if (_haversineMeters(last, p) >= minStepMeters) {
//         simplified.add(p);
//         last = p;
//         if (simplified.length >= maxPoints) break;
//       }
//     }
//     simplified.add(points.last);
//     return simplified;
//   }
// }
