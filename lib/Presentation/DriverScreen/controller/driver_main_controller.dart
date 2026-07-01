import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:hopper/Core/Constants/log.dart';
import 'package:hopper/Core/Firebase/firebase_service.dart';
import 'package:hopper/Core/Utility/images.dart';
import 'package:hopper/Core/Utility/snackbar.dart';
import 'package:hopper/utils/sharedprefsHelper/sharedprefs_handler.dart';
import 'package:hopper/utils/sharedprefsHelper/local_data_store.dart';
import 'package:hopper/utils/sharedprefsHelper/booking_local_data.dart';
import 'package:hopper/utils/websocket/socket_io_client.dart';
import 'package:hopper/utils/websocket/secondary_dispatch_socket.dart';
import 'package:hopper/api/dataSource/apiDataSource.dart';
import '../../../api/repository/api_config_controller.dart';
import 'package:hopper/utils/map/navigation_assist.dart';
import 'package:hopper/Core/Services/navigation_service.dart';
import 'package:hopper/utils/map/map_motion_profile.dart';
import 'package:hopper/utils/map/app_map_style.dart';
import 'package:hopper/utils/map/vehicle_marker_icon.dart';
import 'package:hopper/utils/location/location_permission_guard.dart';
import 'package:hopper/utils/ride_map/marker_icon_cache.dart';
import 'package:hopper/utils/ride_map/ride_map_controller.dart';
import 'package:hopper/Presentation/DriverScreen/screens/background_service.dart'
    as bg;
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hopper/Presentation/DriverScreen/controller/driver_status_controller.dart';
import 'package:hopper/Presentation/Drawer/controller/ride_history_controller.dart';
import 'package:hopper/Presentation/DriverScreen/models/driver_active_booking_response.dart';
import 'package:hopper/Presentation/DriverScreen/models/demand_opportunities_models.dart';
import 'package:hopper/Presentation/DriverScreen/screens/SharedBooking/Screens/picking_shared_screens.dart';
import 'package:hopper/Presentation/DriverScreen/screens/SharedBooking/Screens/share_ride_start_screen.dart';
import 'package:hopper/Presentation/DriverScreen/screens/SharedBooking/Controller/shared_ride_controller.dart';
import 'package:hopper/Presentation/DriverScreen/screens/driver_main_screen.dart';
import 'package:hopper/Presentation/DriverScreen/screens/picking_customer_screen.dart';
import 'package:hopper/Presentation/DriverScreen/screens/ride_stats_screen.dart';
import 'package:hopper/Presentation/DriverScreen/screens/verify_rider_screen.dart';
import '../screens/SharedBooking/Controller/booking_request_controller.dart';

class DriverMainController extends GetxController
    with GetTickerProviderStateMixin {
  // --- motion thresholds to tame jitter ---
  static const double _MAX_ACCURACY_M = 25.0; // ignore noisy GPS fixes
  static const double _STATIONARY_JUMP_M = 30.0; // ignore big jumps when idle
  static const double _JUMP_ACCEPT_ACCURACY_M =
      12.0; // allow big move if very accurate
  static const double _MOVING_SPEED_MS = 0.6;
  static const double _MOVING_METERS = 5.0;
  // Below this much real movement since the last fix we emit speed:0 — the car
  // physically hasn't progressed, so the customer must not dead-reckon it
  // forward (GPS often reports a phantom 1-2 m/s while standing still). Actual
  // position changes still animate via the customer's segment lerp; only the
  // forward extrapolation is suppressed.
  static const double _STATIONARY_EMIT_M = 1.5;

  // External controllers
  final BookingRequestController bookingController =
      Get.find<BookingRequestController>();

  final DriverStatusController statusController = Get.put(
    DriverStatusController(),
  );

  // Map
  GoogleMapController? mapController;
  String? mapStyle;
  final Rxn<LatLng> currentPosition = Rxn<LatLng>();
  final RideMapController rideMap = RideMapController(mode: RideMapMode.home);

  // Marker
  // Match Customer app marker clarity on Home map.
  static const double _kHomeVehicleMarkerSizeDp = 48.0;
  BitmapDescriptor? carIcon;
  String? _vehicleIconConfigKey;
  bool _vehicleIconLoading = false;
  Marker? carMarker;
  LatLng? lastPosition;
  BitmapDescriptor? demandPinIcon;

  // Animation
  late final AnimationController animCtrl;
  late final Animation<double> anim;
  Tween<double>? latTween;
  Tween<double>? lngTween;
  Tween<double>? rotTween;

  // Socket + location
  final SocketService socketService = SocketService();

  // FRAUD (CRIT-5): mock/fake-GPS state. Set true when a mocked fix is seen so the UI/server
  // can react; report is throttled via _lastMockLocationReportAt.
  final RxBool mockLocationDetected = false.obs;
  DateTime? _lastMockLocationReportAt;
  StreamSubscription<Position>? locationSub;
  Timer? emitTimer;
  Timer? heartbeatTimer;
  Map<String, dynamic>? latestLocationPayload;
  // Last GPS heading captured while actually moving. Reused when stopped so the
  // emitted bearing doesn't jump to random values (customer car won't spin).
  double _lastEmitBearing = 0.0;
  String? _lastSentLocationTimestamp;
  DateTime? _lastLocationEmitAt;
  DateTime? _lastDriverEmitMetricAt;
  DateTime? _lastMovedAt;
  DateTime? _lastUpdateLocationEmitAt;
  DateTime? _lastHeartbeatEmitAt;
  DateTime _lastHomeRefreshAt = DateTime.fromMillisecondsSinceEpoch(0);
  int _emitLoopToken = 0;
  DateTime _emitMetricsWindowStartedAt = DateTime.now().toUtc();
  int _emitCountWindow = 0;
  int _emitLastGapMs = 0;
  bool _backgroundServiceActive = false;
  // Tracks whether the live GPS stream was built for an active trip (so we can
  // rebuild it with a tighter distanceFilter when a trip starts / ends).
  bool _emitLoopForActiveTrip = false;

  String? driverId;
  String? currentBookingId;
  bool _cancelNavInFlight = false;

  // Countdown for request
  Timer? countdownTimer;
  final RxInt remainingSeconds = 15.obs;

  // Screen ready
  final RxBool ready = false.obs;

  // Follow mode
  final RxBool followDriver = true.obs;
  Timer? cameraFollowTimer;
  double _followZoom = 15.4;
  DateTime? _manualFollowZoomHoldUntil;
  LatLng? _lastCameraFollowTarget;
  double _lastCameraFollowBearing = 0;
  DateTime _lastCameraFollowMoveAt = DateTime.fromMillisecondsSinceEpoch(0);

  // Config
  final ApiConfigController cfg = Get.find<ApiConfigController>();

  // DUAL-CONNECT: stable per-install device id (FCM token) reused by the
  // secondary single-ride dispatch socket so bk can dedupe this device.
  String? _dispatchDeviceId;
  Worker? _sharedToggleWorker;
  Worker? _serviceTypeWorker;
  Worker? _autoOfflineWorker;
  final ApiDataSource _apiDataSource = ApiDataSource();

  // âœ… IMPORTANT: prevent callbacks after dispose
  bool _disposed = false;
  bool _checkingActiveBooking = false;
  DateTime? _lastActiveBookingCheckAt;
  String? _lastResumedBookingId;
  String? _lastDismissedBookingId;
  bool _appInForeground = true;
  // Debounce for the foreground single-session self-heal (see
  // _maybeReclaimRevokedSession). Stops a revoked foreground socket from sitting
  // dead (dropping location/heartbeat) when no resume event will fire to
  // reclaim it, without re-creating a tight revoke-war.
  DateTime _lastSessionReclaimAt = DateTime.fromMillisecondsSinceEpoch(0);
  bool _restoringPendingBookingRequest = false;

  final Rxn<Map<String, dynamic>> activeBookingData =
      Rxn<Map<String, dynamic>>();
  final RxBool showActiveBookingCard = false.obs;

  // Demand opportunities (Home card)
  final RxBool demandLoading = false.obs;
  final Rxn<DemandOpportunitiesData> demandData =
      Rxn<DemandOpportunitiesData>();
  final RxList<DemandOpportunity> demandOpportunities =
      <DemandOpportunity>[].obs;
  final Rxn<DemandOpportunitiesSummary> demandSummary =
      Rxn<DemandOpportunitiesSummary>();
  Marker? demandMarker;
  List<Circle> demandCircles = <Circle>[];
  final Rxn<ui.Offset> demandLabelOffset = Rxn<ui.Offset>();
  final RxnString selectedDemandId = RxnString();
  DateTime _lastDemandBannerAt = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastDemandRequestAt = DateTime.fromMillisecondsSinceEpoch(0);
  LatLng? _lastDemandRequestPos;
  double? _lastMapZoom;

  // Demand pulse (map ring animation)
  late final AnimationController _demandPulseCtrl;
  late final AnimationController _demandBounceCtrl;
  LatLng? _demandPulseCenter;
  Color? _demandPulseColor;
  DateTime _lastDemandPulsePaintAt = DateTime.fromMillisecondsSinceEpoch(0);

  // Demand marker style toggle (kept mutable to avoid constant-folding)
  bool useDefaultDemandMarker = false;

  // Active trip: emit ~1s so the customer map glides like Uber/Ola (was 3s,
  // which made the customer marker jump between updates). Idle/online intervals
  // below stay larger to protect battery + data when there's no live ride.
  static const Duration _activeTripFastEmitInterval = Duration(seconds: 1);
  static const Duration _onlineMovingEmitInterval = Duration(seconds: 5);
  static const Duration _onlineSlowEmitInterval = Duration(seconds: 8);
  static const Duration _movementIdleCutoff = Duration(seconds: 20);
  // On an active trip we keep the steady 1s feed alive through long stops
  // (red lights / tunnels) — but not forever. After this much continuous
  // no-movement we back off to the lighter 25s heartbeat. This also stops a
  // booking whose context wasn't cleared on completion from emitting 1Hz
  // indefinitely while the car is parked.
  static const Duration _activeTripIdleCutoff = Duration(minutes: 15);

  // Freshness guard: never build/emit from a GPS fix older than this. Android
  // can deliver a BACKLOG of buffered fixes after a stall; draining them makes
  // the customer track the driver's position from N seconds ago. We compare
  // `now` to the fix's OWN timestamp (same device clock -> immune to clock skew /
  // timezone) and drop stale fixes so only the current location is sent.
  // Generous enough for normal GPS provider latency (sub-second to ~2s).
  static const Duration _maxFixAgeForEmit = Duration(seconds: 5);

  // Expose demand micro-interaction animations (for UI overlays).
  Listenable get demandBounceListenable => _demandBounceCtrl;
  double get demandBounceT => _demandBounceCtrl.value;

  // ---------------- helpers ----------------
  double safeToDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0.0;
  }

  int safeToInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.round();
    return int.tryParse(value.toString()) ?? 0;
  }

  Duration _preferredLocationEmitInterval(Map<String, dynamic> payload) {
    final speed = safeToDouble(payload['speed']);
    final bookingId = payload['bookingId']?.toString().trim() ?? '';
    final hasActiveBooking = bookingId.isNotEmpty;

    if (hasActiveBooking) {
      // Steady 1s for the WHOLE active trip (driver approaching pickup +
      // passenger on board). Never downgrade to 5s/8s when the car slows in
      // traffic / at a signal — that starves the customer motion engine and
      // makes the marker freeze, then lurch. The speed-based downgrade is
      // intentionally bypassed here.
      return _activeTripFastEmitInterval;
    }

    if (speed >= 2.2) return _onlineMovingEmitInterval;
    return _onlineSlowEmitInterval;
  }

  String formatDistance(double meters) {
    final km = meters / 1000;
    return '${km.toStringAsFixed(1)} Km';
  }

  String formatDuration(int minutes) {
    final hours = minutes ~/ 60;
    final rem = minutes % 60;
    return hours > 0 ? '$hours hr $rem min' : '$rem min';
  }

  double bearingBetween(LatLng start, LatLng end) {
    final lat1 = start.latitude * (pi / 180.0);
    final lon1 = start.longitude * (pi / 180.0);
    final lat2 = end.latitude * (pi / 180.0);
    final lon2 = end.longitude * (pi / 180.0);

    final dLon = lon2 - lon1;
    final y = sin(dLon) * cos(lat2);
    final x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon);

    final brng = atan2(y, x);
    return (brng * 180 / pi + 360) % 360;
  }

  bool movedEnough(LatLng a, LatLng b) {
    final dx = (a.latitude - b.latitude).abs();
    final dy = (a.longitude - b.longitude).abs();
    return (dx + dy) > 0.00002; // ~2m threshold
  }

  // ---------------- permissions ----------------
  Future<bool> ensureLocationPermission() async {
    if (!Get.isRegistered<LocationPermissionGuard>()) return false;
    return Get.find<LocationPermissionGuard>().ensureReady(showDialog: true);
  }

  Future<Position?> getCurrentPos() async {
    final ok = await ensureLocationPermission();
    if (!ok) return null;
    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation,
        timeLimit: const Duration(seconds: 12),
      );
    } catch (_) {
      // fallback (older devices / timeouts)
      return Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    }
  }

  // ---------------- map style ----------------
  // ---------------- map style ----------------
  Future<void> loadMapStyle() async {
    try {
      final style = await AppMapStyle.loadUberLight();
      mapStyle = style;
      update(['map']);
    } catch (e) {
      if (kDebugMode) CommonLogger.log.w("Map style load failed: $e");
    }
  }

  // ---------------- icon ----------------
  // Future<void> loadCustomCarIcon() async {
  //   try {
  //     const cfg = ImageConfiguration(size: Size(52, 52));
  //     final asset =
  //         statusController.isCar ? AppImages.movingCar : AppImages.parcelBike;

  //     // Bike marker should be a bit smaller than car (but still readable).
  //     final markerHeight = statusController.isCar ? 36.0 : 52.0;
  //     carIcon = await BitmapDescriptor.asset(
  //       height: markerHeight,
  //       cfg,
  //       asset,
  //     );
  //   } catch (e) {
  //     if (kDebugMode) CommonLogger.log.w("Car icon load failed: $e");
  //     carIcon = BitmapDescriptor.defaultMarker;
  //   }
  // }
  Future<void> loadCustomCarIcon() async {
    // Keep RideMap vehicle type in sync (single source of marker sizing).
    _applyRideMapVehicleType();
    final desiredKey = HopprVehicleMarkerIcon.currentConfigKeyForServiceType(
      statusController.serviceType.value,
      logicalSizeDp: _kHomeVehicleMarkerSizeDp,
    );
    if (carIcon != null && _vehicleIconConfigKey == desiredKey) return;
    if (_vehicleIconLoading) return;
    _vehicleIconLoading = true;
    try {
      // No badge/circle: render crisp contained asset at customer-like size.
      carIcon = await HopprVehicleMarkerIcon.loadForServiceType(
        statusController.serviceType.value,
        logicalSizeDp: _kHomeVehicleMarkerSizeDp,
      );
      _vehicleIconConfigKey = desiredKey;
    } catch (e) {
      if (kDebugMode) {
        CommonLogger.log.w("Car icon load failed: $e");
      }
      carIcon = BitmapDescriptor.defaultMarker;
      _vehicleIconConfigKey = desiredKey;
    } finally {
      _vehicleIconLoading = false;
    }
  }

  void _refreshVehicleIconIfNeeded() {
    _applyRideMapVehicleType();
    final currentKey = HopprVehicleMarkerIcon.currentConfigKeyForServiceType(
      statusController.serviceType.value,
      logicalSizeDp: _kHomeVehicleMarkerSizeDp,
    );
    if (_vehicleIconConfigKey == currentKey) return;
    unawaited(loadCustomCarIcon());
  }

  RideVehicleType _rideVehicleTypeFromServiceType(String raw) {
    final v = raw.trim().toLowerCase();
    if (v.contains('package') || v.contains('parcel')) {
      return RideVehicleType.packageBike;
    }
    if (v.contains('bike')) return RideVehicleType.bike;
    return RideVehicleType.car;
  }

  void _applyRideMapVehicleType() {
    rideMap.setVehicleType(
      _rideVehicleTypeFromServiceType(statusController.serviceType.value),
    );
  }

  // ---------------- marker update (animated) ----------------
  void updateCarMarker(
    LatLng newPos, {
    double? speedMs,
    double? headingDeg,
    double? accuracyM,
    DateTime? timestamp,
  }) {
    // âœ… stop any callbacks after close
    if (_disposed || isClosed) return;
    _refreshVehicleIconIfNeeded();
    // This is the driver's live GPS stream tick (real source). Provide full
    // metadata; otherwise RideMapController assumes "stationary" and may ignore
    // small moves, which looks like the vehicle is stuck.
    rideMap.updateVehicleLocation(
      newPos,
      source: 'gps',
      speedMetersPerSecond: speedMs,
      headingDeg: headingDeg,
      accuracyMeters: accuracyM,
      timestamp: timestamp,
    );
    final icon = carIcon ?? BitmapDescriptor.defaultMarker;

    if (lastPosition == null || carMarker == null) {
      carMarker = Marker(
        markerId: const MarkerId('car'),
        position: newPos,
        icon: icon,
        rotation: 0,
        anchor: const Offset(0.5, 0.5),
        flat: true,
      );
      lastPosition = newPos;
      update(['map']);
      return;
    }

    if (!movedEnough(lastPosition!, newPos)) return;

    final rawBearing = bearingBetween(lastPosition!, newPos);
    final currentBearing = carMarker?.rotation ?? 0;
    final bearing = MapMotionProfile.smoothBearing(
      current: currentBearing,
      target: rawBearing,
      speedMs: 4.0,
    );

    latTween = Tween(begin: lastPosition!.latitude, end: newPos.latitude);
    lngTween = Tween(begin: lastPosition!.longitude, end: newPos.longitude);
    rotTween = Tween(begin: carMarker!.rotation, end: bearing);

    // âœ… guard animCtrl usage
    if (_disposed || isClosed) return;
    try {
      if (animCtrl.isAnimating) animCtrl.stop();
      animCtrl
        ..reset()
        ..forward();
    } catch (_) {
      // ignore if controller disposed between frames
    }

    lastPosition = newPos;
  }

  // ---------------- init location ----------------
  Future<void> initLocation() async {
    final pos = await getCurrentPos();
    if (_disposed || isClosed) return;
    if (pos == null) return;

    final latLng = LatLng(pos.latitude, pos.longitude);
    currentPosition.value = latLng;

    updateCarMarker(
      latLng,
      speedMs: pos.speed.isFinite ? pos.speed : null,
      headingDeg: pos.heading.isFinite ? pos.heading : null,
      accuracyM: pos.accuracy.isFinite ? pos.accuracy : null,
      timestamp: pos.timestamp,
    );

    await mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: latLng, zoom: _followZoom, tilt: 26),
      ),
    );
  }

  Future<void> goToCurrentLocation() async {
    // Recenter should feel "zoom-in" every time (like Uber).
    // Don't depend on speed-based follow zoom (which can be zoomed out).
    final target = lastPosition ?? currentPosition.value;
    LatLng? latLng = target;
    Position? fetched;

    if (latLng == null) {
      final pos = await getCurrentPos();
      if (_disposed || isClosed) return;
      if (pos == null) return;
      fetched = pos;
      latLng = LatLng(pos.latitude, pos.longitude);
    }

    // Hold zoom briefly so the next location tick won't immediately zoom-out.
    _followZoom = 15.8;
    _manualFollowZoomHoldUntil = DateTime.now().add(
      const Duration(milliseconds: 2600),
    );

    final bearing = carMarker?.rotation ?? 0.0;
    await mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: latLng,
          zoom: _followZoom,
          tilt: 26,
          bearing: bearing,
        ),
      ),
    );

    // If we fetched a fresh fix here, also update the marker with full metadata.
    // Otherwise, the normal position stream will update the marker.
    if (fetched != null) {
      updateCarMarker(
        latLng,
        speedMs: fetched!.speed.isFinite ? fetched!.speed : null,
        headingDeg: fetched!.heading.isFinite ? fetched!.heading : null,
        accuracyM: fetched!.accuracy.isFinite ? fetched!.accuracy : null,
        timestamp: fetched!.timestamp,
      );
    }
  }

  // ---------------- reverse geo ----------------
  Future<String> getAddressFromLatLng(double lat, double lng) async {
    try {
      final placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isEmpty) return "Location not available";
      final place = placemarks.first;
      return "${place.name}, ${place.locality}, ${place.administrativeArea}";
    } catch (_) {
      return "Location not available";
    }
  }

  String _preferredAddress(
    Map<String, dynamic> data, {
    required List<String> keys,
  }) {
    for (final key in keys) {
      final value = (data[key] ?? '').toString().trim();
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  // ---------------- countdown ----------------
  void startCountdown([int? secondsOverride]) {
    countdownTimer?.cancel();
    remainingSeconds.value = _normalizeRequestCountdown(secondsOverride);

    countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_disposed || isClosed) return;
      final v = remainingSeconds.value;
      if (v > 0) {
        remainingSeconds.value = v - 1;
      } else {
        t.cancel();
        bookingController.clear();
      }
    });
  }

  int _normalizeRequestCountdown(int? seconds) {
    final fallback = BookingRequestController.requestPopupSeconds;
    final value = seconds ?? fallback;
    if (value <= 0) return fallback;
    return value > fallback ? fallback : value;
  }

  int? _remainingSecondsFromPayload(Map<String, dynamic> data) {
    final raw = data['remainingSeconds'] ?? data['remainingTimeInSeconds'];
    if (raw is num) return raw.toInt();
    return int.tryParse(raw?.toString() ?? '');
  }

  Future<void> _showBookingRequestPopup({
    required Map<String, dynamic> booking,
    int? remainingSecondsOverride,
  }) async {
    final pickup = booking['pickupLocation'];
    final drop = booking['dropLocation'];

    double? pickupLat;
    double? pickupLng;
    double? dropLat;
    double? dropLng;

    if (pickup is Map) {
      pickupLat = (pickup['latitude'] as num?)?.toDouble();
      pickupLng = (pickup['longitude'] as num?)?.toDouble();
    }
    if (drop is Map) {
      dropLat = (drop['latitude'] as num?)?.toDouble();
      dropLng = (drop['longitude'] as num?)?.toDouble();
    }

    final pickupAddressText = _preferredAddress(
      booking,
      keys: const ['pickupAddress', 'pickupLocationAddress'],
    );
    final dropAddressText = _preferredAddress(
      booking,
      keys: const ['dropAddress', 'dropLocationAddress'],
    );

    final pickupAddr =
        pickupAddressText.isNotEmpty
            ? pickupAddressText
            : (pickupLat != null && pickupLng != null
                ? await getAddressFromLatLng(pickupLat, pickupLng)
                : 'Location not available');
    final dropAddr =
        dropAddressText.isNotEmpty
            ? dropAddressText
            : (dropLat != null && dropLng != null
                ? await getAddressFromLatLng(dropLat, dropLng)
                : 'Location not available');

    if (_disposed || isClosed) return;

    final countdown = _normalizeRequestCountdown(remainingSecondsOverride);
    bookingController.showRequest(
      rawData: booking,
      pickupAddress: pickupAddr,
      dropAddress: dropAddr,
      remainingSeconds: countdown,
    );
    startCountdown(countdown);
  }

  Future<void> restorePendingBookingRequestFromNotification({
    bool force = false,
  }) async {
    if (_disposed || isClosed) return;
    if (_restoringPendingBookingRequest) return;
    if (!force && bookingController.bookingRequestData.value != null) return;

    _restoringPendingBookingRequest = true;
    Map<String, dynamic>? queuedPayload;
    try {
      queuedPayload =
          await FirebaseService.consumeQueuedBookingRequestNotification();
      if (queuedPayload == null || queuedPayload.isEmpty) return;

      final route = (queuedPayload['screen'] ?? '').toString().trim();
      final type = (queuedPayload['type'] ?? '').toString().trim();
      final bookingId = (queuedPayload['bookingId'] ?? '').toString().trim();

      CommonLogger.log.i(
        'Restore booking request from notification route=$route '
        'type=$type bookingId=$bookingId payload=$queuedPayload',
      );

      if (bookingId.isEmpty) {
        CommonLogger.log.w(
          'Skipping booking-request restore because bookingId is empty',
        );
        return;
      }

      final result = await _apiDataSource.getPendingBookingRequest(
        bookingId: bookingId,
      );
      if (_disposed || isClosed) return;

      await result.fold((failure) async {
        CommonLogger.log.w(
          'Pending booking request restore failed for $bookingId: '
          '${failure.message}',
        );
        if (queuedPayload != null) {
          await FirebaseService.restoreQueuedBookingRequestNotification(
            queuedPayload!,
          );
        }
      }, (response) async {
        if (!response.success || !response.hasPendingBookingRequest) {
          CommonLogger.log.i(
            'Pending booking request no longer valid for $bookingId '
            'success=${response.success} '
            'hasPending=${response.hasPendingBookingRequest}',
          );
          return;
        }

        final booking = response.data;
        if (booking == null || booking.isEmpty) {
          CommonLogger.log.w(
            'Pending booking request restore returned empty data for $bookingId',
          );
          return;
        }

        final apiBookingId = (booking['bookingId'] ?? bookingId)
            .toString()
            .trim();
        if (apiBookingId.isEmpty) return;
        if (apiBookingId == bookingController.lastHandledBookingId.value) {
          CommonLogger.log.i(
            'Skipping restored popup because booking already handled: '
            '$apiBookingId',
          );
          return;
        }

        await _showBookingRequestPopup(
          booking: booking,
          remainingSecondsOverride: _remainingSecondsFromPayload(booking),
        );
      });
    } finally {
      _restoringPendingBookingRequest = false;
    }
  }

  // ---------------- camera follow ----------------
  void startCameraFollow() {
    cameraFollowTimer?.cancel();

    // Smoother follow (closer to Uber/Ola feel).
    cameraFollowTimer = Timer.periodic(const Duration(milliseconds: 420), (_) {
      if (_disposed || isClosed) return;
      if (!followDriver.value) return;
      if (lastPosition == null) return;
      if (mapController == null) return;

      final target = lastPosition!;
      final bearing = carMarker?.rotation ?? 0;

      final now = DateTime.now();
      if (now.difference(_lastCameraFollowMoveAt).inMilliseconds < 240) return;

      // avoid micro updates
      final prev = _lastCameraFollowTarget;
      if (prev != null) {
        final dx = (prev.latitude - target.latitude).abs();
        final dy = (prev.longitude - target.longitude).abs();
        final moved = (dx + dy) > 0.00002; // ~2m
        final rotDelta = (bearing - _lastCameraFollowBearing).abs() % 360;
        final rotOk = rotDelta > 5 && rotDelta < 355;
        if (!moved && !rotOk) return;
      }

      _lastCameraFollowTarget = target;
      _lastCameraFollowBearing = bearing;
      _lastCameraFollowMoveAt = now;

      // small lead so road ahead is visible
      final leadMeters =
          _followZoom >= 15.0 ? 70.0 : (_followZoom >= 14.3 ? 110.0 : 150.0);
      final followTarget = _offsetLatLng(target, bearing, leadMeters);

      mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: followTarget,
            zoom: _followZoom,
            tilt: 26,
            bearing: bearing,
          ),
        ),
      );
    });
  }

  LatLng _offsetLatLng(LatLng origin, double bearingDeg, double meters) {
    const earthRadiusM = 6378137.0;
    final b = bearingDeg * (pi / 180.0);
    final d = meters / earthRadiusM;

    final lat1 = origin.latitude * (pi / 180.0);
    final lng1 = origin.longitude * (pi / 180.0);

    final lat2 = asin(sin(lat1) * cos(d) + cos(lat1) * sin(d) * cos(b));
    final lng2 =
        lng1 +
        atan2(sin(b) * sin(d) * cos(lat1), cos(d) - sin(lat1) * sin(lat2));

    return LatLng(lat2 * 180.0 / pi, lng2 * 180.0 / pi);
  }

  String? _normalizeBookingId(dynamic raw) {
    final v = (raw ?? '').toString().trim();
    if (v.isEmpty) return null;
    if (v.toLowerCase() == 'null') return null;
    return v;
  }

  Map<String, dynamic>? _coerceSocketPayloadToMap(dynamic data) {
    if (data == null) return null;
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    if (data is List && data.isNotEmpty) {
      return _coerceSocketPayloadToMap(data.first);
    }
    return null;
  }

  Future<void> handleCustomerCancelled(dynamic raw) async {
    await _handleBookingCancellation(raw, cancelledBy: 'customer');
  }

  Future<void> handleDriverCancelled(dynamic raw) async {
    await _handleBookingCancellation(raw, cancelledBy: 'driver');
  }

  Future<void> _handleBookingCancellation(
    dynamic raw, {
    required String cancelledBy,
  }) async {
    if (_disposed || isClosed) return;
    if (_cancelNavInFlight) return;

    final payload = _coerceSocketPayloadToMap(raw);
    if (payload == null) return;

    final ok = _asBool(payload['status']);
    if (!ok) return;
    _cancelNavInFlight = true;

    final bookingId = _normalizeBookingId(payload['bookingId']);
    if (bookingId != null && Get.isRegistered<DriverAnalyticsController>()) {
      Get.find<DriverAnalyticsController>().trackCancel(bookingId: bookingId);
    }

    final msg =
        (payload['message'] ??
                payload['reason'] ??
                'Your trip has been cancelled.')
            .toString();

    // Shared-ride awareness: a single passenger cancelling out of a multi-rider
    // pool must NOT end the whole trip. Mark that passenger cancelled-by-customer
    // (disabled card + reason on the driver UI) and, when other riders are still
    // active, keep the driver on the ride instead of showing "Trip Cancelled".
    if (cancelledBy == 'customer' &&
        bookingId != null &&
        Get.isRegistered<SharedRideController>()) {
      final shared = Get.find<SharedRideController>();
      final inPool = shared.riders.any((r) => r.bookingId == bookingId);
      if (inPool) {
        // Prefer the customer's actual reason for the disabled card.
        final riderReason =
            (payload['reason'] ?? payload['message'] ?? '').toString().trim();
        shared.markCancelledByCustomer(bookingId, reason: riderReason);
        if (shared.getAllActiveRiders().isNotEmpty) {
          _cancelNavInFlight = false; // not a trip-ending cancellation
          return; // keep serving remaining passengers; UI shows disabled card
        }
        // Last active rider cancelled -> fall through to end the trip below.
      }
    }

    _showCancellationDialog(
      title: 'Trip Cancelled',
      message: msg,
    );

    await _cleanupAfterBookingEnded(bookingId: bookingId);

    await Future<void>.delayed(const Duration(seconds: 3));
    if (_disposed || isClosed) return;

    try {
      if (Get.isBottomSheetOpen == true) Get.back();
    } catch (_) {}
    try {
      if (Get.isDialogOpen == true) Get.back();
    } catch (_) {}

    if (Get.currentRoute != '/DriverMainScreen') {
      Get.offAll(() => const DriverMainScreen());
    }

    _cancelNavInFlight = false;
  }

  void _showCancellationDialog({
    required String title,
    required String message,
  }) {
    try {
      if (Get.isDialogOpen == true) return;
    } catch (_) {}

    try {
      Get.dialog(
        barrierDismissible: false,
        Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.cancel_rounded,
                    color: Color(0xFFB42318),
                    size: 30,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.3,
                    color: Colors.black.withOpacity(0.75),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Returning to Home…',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.black.withOpacity(0.55),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (_) {}
  }

  Future<void> _cleanupAfterBookingEnded({String? bookingId}) async {
    countdownTimer?.cancel();
    remainingSeconds.value = 0;
    followDriver.value = true;

    if (bookingId != null) {
      bookingController.markHandled(bookingId);
    } else {
      bookingController.clear();
    }

    BookingDataService().clear();
    socketService.clearAllBookingRooms();

    currentBookingId = null;
    _lastResumedBookingId = null;
    activeBookingData.value = null;

    // Wipe the shared-ride pool so a cancelled/ended shared ride never leaves
    // stale riders that would mix into the next shared ride.
    try {
      if (Get.isRegistered<SharedRideController>()) {
        Get.find<SharedRideController>().reset();
      }
    } catch (_) {}

    // DUAL-CONNECT: ride cancelled -> release the active-ride backend binding and
    // bring the secondary single-ride dispatch socket back if still idle+shared.
    unawaited(onActiveRideEnded());
    _lastDismissedBookingId = null;
    showActiveBookingCard.value = false;

    try {
      await bg.stopDriverTrackingService();
    } catch (_) {}

    // Refresh home cards (earnings/rides/today activity) after a booking ends so
    // the main screen shows updated totals without requiring manual pull-to-refresh.
    unawaited(refreshHomeStats(force: true));
  }

  Future<void> refreshHomeStats({bool force = false}) async {
    if (_disposed || isClosed) return;
    final now = DateTime.now();
    if (!force &&
        now.difference(_lastHomeRefreshAt) < const Duration(seconds: 8)) {
      return;
    }
    _lastHomeRefreshAt = now;

    try {
      await statusController.getDriverStatus();
    } catch (_) {}

    try {
      await statusController.weeklyChallenges();
    } catch (_) {}

    try {
      if (Get.isRegistered<RideHistoryController>()) {
        await Get.find<RideHistoryController>().customerWalletHistory(
          isRefresh: true,
          showErrors: false,
        );
      }
    } catch (_) {}

    final type = statusController.serviceType.value.trim().toLowerCase();
    try {
      if (type == 'car') {
        await statusController.todayActivity();
      } else {
        await statusController.todayPackageActivity();
      }
    } catch (_) {}

    // Demand opportunities: refresh with same throttle window.
    unawaited(fetchDemandOpportunities(silent: true));
  }

  bool get showDemandCard {
    final d = demandData.value;
    if (d == null) return demandOpportunities.isNotEmpty;
    if (d.eligible != true) return false;
    return demandOpportunities.isNotEmpty;
  }

  Future<void> fetchDemandOpportunities({bool silent = false}) async {
    if (_disposed || isClosed) return;
    if (!silent) demandLoading.value = true;

    try {
      final res = await _apiDataSource.getDemandOpportunities();
      res.fold(
        (failure) {
          if (!silent) CustomSnackBar.showError(failure.message);
        },
        (response) {
          final data = response.data;
          demandData.value = data;
          demandSummary.value = data?.summary;
          demandOpportunities.assignAll(data?.opportunities ?? const []);

          // If previously selected zone is gone, fall back to top item.
          final sel = selectedDemandId.value?.trim() ?? '';
          if (sel.isNotEmpty &&
              !demandOpportunities.any((e) => e.id.trim() == sel)) {
            selectedDemandId.value = null;
          }
          unawaited(_syncDemandMarkerFromTop());
        },
      );
    } catch (_) {
      // ignore (safe fail)
    } finally {
      if (!silent) demandLoading.value = false;
    }
  }

  void requestDemandOpportunities({required String reason}) {
    if (_disposed || isClosed) return;

    final now = DateTime.now();
    if (now.difference(_lastDemandRequestAt) < const Duration(seconds: 10)) {
      return;
    }
    _lastDemandRequestAt = now;

    if (socketService.connected) {
      socketService.emit('driver:request-demand-opportunities', {
        'reason': reason,
        'ts': now.toIso8601String(),
      });
    }

    // Backstop with REST (reconnect + network restore safe).
    unawaited(
      Future<void>.delayed(const Duration(milliseconds: 1200), () async {
        await fetchDemandOpportunities(silent: true);
      }),
    );
  }

  Future<void> _syncDemandMarkerFromTop() async {
    if (_disposed || isClosed) return;
    if (!showDemandCard) {
      demandMarker = null;
      demandCircles = <Circle>[];
      demandLabelOffset.value = null;
      _demandPulseCenter = null;
      _demandPulseColor = null;
      _stopDemandPulse();
      update(['map']);
      return;
    }

    final sel = selectedDemandId.value?.trim() ?? '';
    DemandOpportunity? top;
    if (sel.isNotEmpty) {
      for (final o in demandOpportunities) {
        if (o.id.trim() == sel) {
          top = o;
          break;
        }
      }
    }
    top ??= demandOpportunities.isNotEmpty ? demandOpportunities.first : null;
    final lat = top?.latitude;
    final lng = top?.longitude;
    if (lat == null || lng == null) {
      demandMarker = null;
      demandCircles = <Circle>[];
      demandLabelOffset.value = null;
      _demandPulseCenter = null;
      _demandPulseColor = null;
      _stopDemandPulse();
      update(['map']);
      return;
    }

    final isSelected =
        (top?.id.trim().isNotEmpty ?? false) && top?.id.trim() == sel;

    final level = (top?.demandLevel ?? '').trim().toLowerCase();
    final baseColor = _demandLevelColor(level);
    final pinColor = isSelected ? const Color(0xFF0EA5E9) : baseColor;

    // Use default marker hue (always visible) to avoid asset/theme issues.
    final icon = BitmapDescriptor.defaultMarkerWithHue(
      _demandMarkerHue(level, isSelected),
    );
    demandMarker = Marker(
      markerId: const MarkerId('demand_hotspot'),
      position: LatLng(lat, lng),
      icon: icon,
      infoWindow: InfoWindow.noText,
      anchor: const Offset(0.5, 1.0),
      onTap: () {
        _triggerDemandBounce();
      },
    );

    final center = LatLng(lat, lng);
    _demandPulseCenter = center;
    _demandPulseColor = pinColor;
    _startDemandPulse();

    demandCircles = _demandPulseRings(
      center: center,
      color: pinColor,
      t: _demandPulseCtrl.value,
    );
    unawaited(updateDemandLabelOffset());
    update(['map']);
  }

  Future<void> loadDemandPinIcon() async {
    try {
      // Compact pin (clean + premium; avoids overpowering the map).
      const double markerHeight = 36.0;
      const double markerWidth = 28.0;

      final ImageConfiguration cfg = const ImageConfiguration(
        size: Size(markerWidth, markerHeight),
      );

      demandPinIcon = await BitmapDescriptor.asset(
        cfg,
        AppImages.loc,
        width: markerWidth,
        height: markerHeight,
      );
    } catch (e) {
      if (kDebugMode) {
        CommonLogger.log.w("Demand pin icon load failed: $e");
      }
      demandPinIcon = null;
    }
  }

  double _demandMarkerHue(String level, bool isSelected) {
    if (isSelected) return BitmapDescriptor.hueAzure;
    if (level.contains('high')) return BitmapDescriptor.hueRed;
    if (level.contains('medium')) return BitmapDescriptor.hueOrange;
    if (level.contains('low')) return BitmapDescriptor.hueGreen;
    return BitmapDescriptor.hueAzure;
  }

  Future<void> updateDemandLabelOffset() async {
    final mc = mapController;
    final center = _demandPulseCenter;
    if (mc == null || center == null) {
      demandLabelOffset.value = null;
      return;
    }
    try {
      final sc = await mc.getScreenCoordinate(center);
      if (_disposed || isClosed) return;
      demandLabelOffset.value = ui.Offset(sc.x.toDouble(), sc.y.toDouble());
    } catch (_) {
      // ignore
    }
  }

  Color _demandLevelColor(String level) {
    if (level.contains('high')) return const Color(0xFFEF4444);
    if (level.contains('medium')) return const Color(0xFFF59E0B);
    if (level.contains('low')) return const Color(0xFF10B981);
    return const Color(0xFF0EA5E9);
  }

  void _startDemandPulse() {
    if (_disposed || isClosed) return;
    if (_demandPulseCenter == null || _demandPulseColor == null) return;
    if (_demandPulseCtrl.isAnimating) return;
    try {
      _demandPulseCtrl.repeat();
    } catch (_) {}
  }

  void _stopDemandPulse() {
    try {
      if (_demandPulseCtrl.isAnimating) _demandPulseCtrl.stop();
    } catch (_) {}
  }

  void _triggerDemandBounce() {
    try {
      _demandBounceCtrl.forward(from: 0);
    } catch (_) {}
  }

  List<Circle> _demandPulseRings({
    required LatLng center,
    required Color color,
    required double t,
  }) {
    Color a(double o) => color.withValues(alpha: o.clamp(0.0, 1.0));

    // t: 0..1
    // Compact pulse (keeps the map clean)
    final rippleRadius = ui.lerpDouble(110, 280, t) ?? 200;
    final rippleAlpha = (1 - t).clamp(0.0, 1.0);

    // A small breathing ring for "recommended zone" feel.
    final breath = (0.5 - (t - 0.5).abs()) * 2; // 0..1..0
    final bounce = Curves.elasticOut.transform(_demandBounceCtrl.value);
    final coreRadius = 78 + (breath * 10) + (bounce * 10);
    final coreFillAlpha = 0.08 + (bounce * 0.04);

    return <Circle>[
      Circle(
        circleId: const CircleId('demand_ripple'),
        center: center,
        radius: rippleRadius,
        strokeWidth: 2,
        strokeColor: a(0.18 * rippleAlpha),
        fillColor: a(0.00),
        zIndex: 1,
      ),
      Circle(
        circleId: const CircleId('demand_zone'),
        center: center,
        radius: 170,
        strokeWidth: 2,
        strokeColor: a(0.16),
        fillColor: a(0.06),
        zIndex: 2,
      ),
      Circle(
        circleId: const CircleId('demand_core'),
        center: center,
        radius: coreRadius,
        strokeWidth: 2,
        strokeColor: a(0.22),
        fillColor: a(coreFillAlpha),
        zIndex: 3,
      ),
    ];
  }

  void _upsertDemandOpportunity(DemandOpportunity opp) {
    if (_disposed || isClosed) return;
    if (demandData.value != null && demandData.value?.eligible != true) return;

    final id = opp.id.trim();
    if (id.isEmpty) {
      demandOpportunities.insert(0, opp);
      return;
    }

    final idx = demandOpportunities.indexWhere((e) => e.id.trim() == id);
    if (idx >= 0) {
      demandOpportunities[idx] = opp;
    } else {
      demandOpportunities.insert(0, opp);
    }

    unawaited(_syncDemandMarkerFromTop());
  }

  void _maybeShowDemandBanner(DemandOpportunity opp) {
    if (_disposed || isClosed) return;
    if (!_appInForeground) return;

    final now = DateTime.now();
    if (now.difference(_lastDemandBannerAt) < const Duration(seconds: 10)) {
      return;
    }
    _lastDemandBannerAt = now;

    Get.rawSnackbar(
      messageText: Text(
        opp.title,
        style: const TextStyle(color: Colors.white),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      snackPosition: SnackPosition.TOP,
      backgroundColor: Colors.black.withOpacity(0.88),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      borderRadius: 14,
      mainButton: TextButton(
        onPressed: () async {
          await focusDemandHotspot();
          if (Get.isSnackbarOpen) Get.back();
        },
        child: Text(
          opp.cta.isNotEmpty ? opp.cta : 'View',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      duration: const Duration(seconds: 4),
    );
  }

  Future<void> focusDemandHotspot() async {
    final top =
        demandOpportunities.isNotEmpty ? demandOpportunities.first : null;
    if (top == null) return;
    await focusDemandOpportunity(top);
  }

  void onMapCameraMove(CameraPosition pos) {
    _lastMapZoom = pos.zoom;
  }

  Future<void> focusDemandOpportunity(DemandOpportunity opp) async {
    if (_disposed || isClosed) return;

    final lat = opp.latitude;
    final lng = opp.longitude;
    if (lat == null || lng == null) return;

    final id = opp.id.trim();
    if (id.isNotEmpty) {
      selectedDemandId.value = id;
    }

    await _syncDemandMarkerFromTop();
    _triggerDemandBounce();

    final pos = LatLng(lat, lng);
    final baseZoom = _lastMapZoom ?? 0.0;
    final targetZoom = max(baseZoom, 15.8).clamp(14.8, 17.8);

    try {
      await mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: pos, zoom: targetZoom),
        ),
      );
    } catch (_) {}

    // Use the custom on-map label container (no default Google info window).
  }

  DemandOpportunity? get selectedDemandOpportunity {
    if (!showDemandCard) return null;
    final sel = selectedDemandId.value?.trim() ?? '';
    if (sel.isNotEmpty) {
      for (final o in demandOpportunities) {
        if (o.id.trim() == sel) return o;
      }
    }
    return demandOpportunities.isNotEmpty ? demandOpportunities.first : null;
  }

  /// Align the FOREGROUND location emitter to an in-progress trip (pickup or
  /// drop). The 1s emit loop streams at the smooth ~1Hz active-trip cadence and
  /// stamps `bookingId` on every packet ONLY while `currentBookingId` is set;
  /// otherwise it falls back to the idle 5–8s cadence with no bookingId, so the
  /// server cannot reliably route frames to the customer and the customer's car
  /// marker updates slowly / jerkily (notably during the drop leg, or after an
  /// app restart mid-ride where booking-request never re-ran). Ride screens call
  /// this on init so the foreground stream is always trip-aligned. The 1s timer
  /// detects the active-trip flip on its next tick and rebuilds the GPS stream
  /// (distanceFilter 0) automatically; here we also nudge socket registration so
  /// the booking context matches immediately. Idempotent / cheap to re-call.
  void setActiveTripBookingId(String bookingId) {
    final id = _normalizeBookingId(bookingId);
    if (id == null) return;
    if (_normalizeBookingId(currentBookingId) == id) return;
    currentBookingId = id;
    final did = driverId?.trim() ?? '';
    if (did.isNotEmpty) {
      socketService.setSingleActiveBookingRoom(id);
      socketService.registerDriver(did, bookingId: id);
    }
    CommonLogger.log.i(
      'Foreground emitter aligned to active trip bookingId=${_maskIdForLog(id)}',
    );
  }

  String? _resolveBookingIdForLocationPayload() {
    final direct = _normalizeBookingId(currentBookingId);
    if (direct != null) return direct;

    final cached = BookingDataService().getBookingData();
    if (cached == null) return null;

    final topLevel = _normalizeBookingId(cached['bookingId']);
    if (topLevel != null) return topLevel;

    final activeList = cached['activeBookings'];
    if (activeList is List && activeList.isNotEmpty) {
      final first = activeList.first;
      if (first is Map) {
        final activeId = _normalizeBookingId(first['bookingId']);
        if (activeId != null) return activeId;
      }
    }

    final activeCard = activeBookingData.value;
    final cardId = _normalizeBookingId(activeCard?['bookingId']);
    if (cardId != null) return cardId;

    return null;
  }

  String _maskIdForLog(String? raw) {
    final value = raw?.trim() ?? '';
    if (value.isEmpty) return '';
    if (value.length <= 4) return value;
    return '***${value.substring(value.length - 4)}';
  }

  void _noteDriverEmitMetric({
    required String event,
    required String? bookingId,
  }) {
    final now = DateTime.now().toUtc();
    final bool hadPrevEmit = _lastDriverEmitMetricAt != null;
    if (hadPrevEmit) {
      _emitLastGapMs =
          now.difference(_lastDriverEmitMetricAt!).inMilliseconds.clamp(
                0,
                1 << 30,
              );
    }
    _lastDriverEmitMetricAt = now;
    _emitCountWindow += 1;

    // [track-gap] DIAGNOSTIC (hop 1/4: driver → server, FOREGROUND path). The
    // background service already logs this for its path; the foreground emit —
    // used right after returning from Google-Maps navigation — was previously
    // NOT instrumented, a blind spot when localizing a ride-2 freeze. Fires only
    // when the app resumes emitting after an anomalous silence (>3s) during an
    // ACTIVE booking (the moment the customer marker would freeze), pinning the
    // stall to the device. Warning-level so it shows in release logcat; rare by
    // construction (no spam).
    final bool hasActiveBooking =
        bookingId != null && bookingId.trim().isNotEmpty;
    if (hadPrevEmit && hasActiveBooking && _emitLastGapMs > 3000) {
      CommonLogger.log.w(
        '[track-gap] hop=driver-emit-fg gap_ms=$_emitLastGapMs event=$event '
        'booking=${_maskIdForLog(bookingId)}',
      );
    }
    if (now.difference(_emitMetricsWindowStartedAt) < const Duration(minutes: 1)) {
      return;
    }
    if (kDebugMode) {
      CommonLogger.log.i(
        '[TRACK_METRIC] emit_rate=$_emitCountWindow/min '
        'last_gap_ms=$_emitLastGapMs event=$event '
        'bookingId=${_maskIdForLog(bookingId)}',
      );
    }
    _emitMetricsWindowStartedAt = now;
    _emitCountWindow = 0;
  }

  /// Platform-correct location settings for the live tracking stream.
  ///
  /// CRITICAL (Android): geolocator's base [LocationSettings] does NOT set an
  /// update interval, so the Android FusedLocationProvider falls back to its
  /// DEFAULT 5000ms interval — the stream then delivered a fix only every ~5s
  /// even though our emit timer ticks at 1s. That sparse 5s feed is what made
  /// the customer's car jitter / freeze / dead-reckon between points (the
  /// driver-side root cause of the "shaking, uneven, jumping" marker). Request
  /// ~1Hz fixes on an active trip via [AndroidSettings.intervalDuration]
  /// (Uber/Ola/Rapido-grade), and a gentler cadence when merely online/idle to
  /// protect battery. iOS already streams at the accuracy/distanceFilter rate
  /// (no fixed interval), so it keeps the base settings — no behaviour change.
  LocationSettings _trackingLocationSettings({required bool activeTrip}) {
    const accuracy = LocationAccuracy.bestForNavigation;
    final distanceFilter = activeTrip ? 0 : 5;
    // Force ~1Hz only during an active trip (Android). Idle/online keeps the
    // previous default behaviour, so there is no battery regression when nobody
    // is watching a live ride.
    if (activeTrip && Platform.isAndroid) {
      return AndroidSettings(
        accuracy: accuracy,
        distanceFilter: distanceFilter,
        intervalDuration: const Duration(seconds: 1),
      );
    }
    return LocationSettings(accuracy: accuracy, distanceFilter: distanceFilter);
  }

  // ---------------- location emit loop ----------------
  Future<void> startEmitLoop() async {
    final int token = ++_emitLoopToken;
    await locationSub?.cancel();
    emitTimer?.cancel();
    heartbeatTimer?.cancel();

    if (_disposed || isClosed) return;
    if (token != _emitLoopToken) return;

    // Active trip => distanceFilter 0 so the OS never withholds fixes at low
    // speed (traffic / signal); the customer then gets an even, fresh ~1s feed.
    // Idle/online => 5 to save battery when nobody is watching a live ride.
    // The stream is rebuilt (see the emit timer) when this state flips.
    final bool activeTripStream =
        _resolveBookingIdForLocationPayload() != null;
    _emitLoopForActiveTrip = activeTripStream;

    locationSub = Geolocator.getPositionStream(
      locationSettings: _trackingLocationSettings(activeTrip: activeTripStream),
    ).listen((pos) {
      if (_disposed || isClosed) return;
      if (token != _emitLoopToken) return;

      // FRAUD (CRIT-5): drop mock/fake-GPS fixes so spoofed coordinates never feed the live
      // trip or reach the server, and report the attempt (throttled) so the backend can flag
      // the driver. Without this a free fake-GPS app lets a driver fabricate trips/earnings.
      if (pos.isMocked) {
        if (mockLocationDetected.value != true) mockLocationDetected.value = true;
        final nowMock = DateTime.now();
        if (_lastMockLocationReportAt == null ||
            nowMock.difference(_lastMockLocationReportAt!) >
                const Duration(seconds: 15)) {
          _lastMockLocationReportAt = nowMock;
          if (socketService.connected) {
            socketService.emit('driver-integrity', {
              'driverId': driverId,
              'bookingId': _resolveBookingIdForLocationPayload(),
              'mock': true,
            });
          }
        }
        return;
      }

      final now = DateTime.now();
      // Freshness guard (skew-immune: same device clock for `now` and the fix).
      // Drop a stale/buffered fix so `latestLocationPayload` only ever holds the
      // current position — the customer never sees the driver lag behind.
      if (now.difference(pos.timestamp) > _maxFixAgeForEmit) {
        return;
      }
      final speedMs = (pos.speed.isFinite && pos.speed >= 0) ? pos.speed : 0.0;
      final accuracyM = (pos.accuracy.isFinite) ? pos.accuracy : 9999.0;
      final holdUntil = _manualFollowZoomHoldUntil;
      final holdActive = holdUntil != null && now.isBefore(holdUntil);
      if (!holdActive) {
        final targetZoom = MapMotionProfile.targetZoomFromSpeed(speedMs);
        _followZoom = MapMotionProfile.smoothZoom(
          _followZoom,
          targetZoom.clamp(14.4, 16.4),
        ).clamp(14.4, 16.4);
      } else {
        _followZoom = _followZoom.clamp(15.0, 16.4);
      }

      // 1) ignore very inaccurate fixes
      if (accuracyM > _MAX_ACCURACY_M) return;

      final current = LatLng(pos.latitude, pos.longitude);

      // Demand opportunities refresh on significant movement (avoid spam).
      final lastReqPos = _lastDemandRequestPos;
      if (lastReqPos == null) {
        _lastDemandRequestPos = current;
      } else {
        final moved = Geolocator.distanceBetween(
          lastReqPos.latitude,
          lastReqPos.longitude,
          current.latitude,
          current.longitude,
        );
        if (moved >= 500) {
          _lastDemandRequestPos = current;
          requestDemandOpportunities(
            reason: 'location_moved_${moved.round()}m',
          );
        }
      }

      // 2) freeze drift/jumps when almost stationary
      final prev = lastPosition;
      double? movedSinceLastFix;
      if (prev != null) {
        final movedMeters = Geolocator.distanceBetween(
          prev.latitude,
          prev.longitude,
          current.latitude,
          current.longitude,
        );
        movedSinceLastFix = movedMeters;

        final isMoving =
            speedMs >= _MOVING_SPEED_MS || movedMeters >= _MOVING_METERS;
        if (isMoving) {
          _lastMovedAt = now;
        }

        if (MapMotionProfile.shouldFreezeTurn(
          speedMs: speedMs,
          movedMeters: movedMeters,
          accuracyM: accuracyM,
        )) {
          return;
        }

        // Rare: GPS can "teleport" while idle (esp. indoors). Ignore unless very accurate.
        if (speedMs < MapMotionProfile.minSpeedMs &&
            movedMeters >= _STATIONARY_JUMP_M &&
            accuracyM > _JUMP_ACCEPT_ACCURACY_M) {
          return;
        }
      }

      // Bearing: trust GPS heading only while moving, and remember it. When
      // stopped (<1 m/s) GPS heading is random, so reuse the last good bearing.
      final headingValid = pos.heading.isFinite && pos.heading >= 0;
      if (speedMs >= 1.0 && headingValid) {
        _lastEmitBearing = pos.heading;
      }

      // Trust position over GPS-reported speed: when the car physically barely
      // moved since the last fix, send speed 0 so the customer holds the marker
      // (no forward dead-reckoning) even if GPS reports a phantom speed. Real
      // movement still carries the true speed and still animates via lerp.
      final double reportedSpeed = speedMs.isFinite ? speedMs : 0.0;
      final double emitSpeed = (movedSinceLastFix != null &&
              movedSinceLastFix < _STATIONARY_EMIT_M)
          ? 0.0
          : reportedSpeed;

      final bookingIdForPayload = _resolveBookingIdForLocationPayload();
      latestLocationPayload = {
        'userId': driverId,
        'driverId': driverId,
        'latitude': current.latitude,
        'longitude': current.longitude,
        'lat': current.latitude,
        'lng': current.longitude,
        'bearing': _lastEmitBearing,
        'speed': emitSpeed,
        'accuracy': accuracyM.isFinite ? accuracyM : null,
        if (bookingIdForPayload != null) 'bookingId': bookingIdForPayload,
        'seq': socketService.nextClientLocationSeq(),
        // DEVICE GPS fix time in UTC (not local send-time) so the customer can
        // order/interpolate points correctly.
        'timestamp': pos.timestamp.toUtc().toIso8601String(),
        'deviceTimestamp': pos.timestamp.toUtc().toIso8601String(),
        'clientSentAt': now.toUtc().toIso8601String(),
      };

      updateCarMarker(
        current,
        speedMs: speedMs.isFinite ? speedMs : null,
        headingDeg: pos.heading.isFinite ? pos.heading : null,
        accuracyM: accuracyM.isFinite ? accuracyM : null,
        timestamp: pos.timestamp,
      );
    }, onError: (Object e, StackTrace st) {
      // CRASH FIX: a denied/revoked location permission (or a transient platform
      // GPS error) emits a stream error. Without an onError handler it became an
      // unhandled "APP CRASH: User denied permissions". Swallow it so the app
      // stays alive — the emit loop re-subscribes on its next rebuild once
      // permission is granted again.
      if (kDebugMode) CommonLogger.log.w('location stream error (emitter): $e');
    }, cancelOnError: false);

    if (_disposed || isClosed) return;
    if (token != _emitLoopToken) return;

    // Check every 1s so an active trip can emit at ~1s. Idle/online emits stay
    // throttled by _preferredLocationEmitInterval (5–8s), so battery is safe.
    final localEmitTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_disposed || isClosed) return;
      if (token != _emitLoopToken) return;
      final payload = latestLocationPayload;
      if (payload == null) return;
      // A driver on an ACTIVE trip must keep streaming location even if the
      // `isOnline` flag is momentarily false — it is synced from the server
      // (`getDriverStatus.onlineStatus`) and can read false mid-ride (a booked
      // driver, a stale sync on resume, a brief toggle). Gating the emit on it
      // silently stopped all sends and FROZE the customer's car marker. So only
      // the gate idle/online emits on `isOnline`; an active trip (payload has a
      // bookingId) always streams. Mirrors the server, which keeps relaying
      // location for an active booking regardless of the cached online flag.
      final bool hasActiveBooking = payload['bookingId'] != null;
      if (!hasActiveBooking && !statusController.isOnline.value) return;
      // Foreground self-heal: reclaim a revoked-and-suppressed socket so it does
      // not sit dead while the app is the rightful (foreground) owner.
      _maybeReclaimRevokedSession();

      final ts = payload['timestamp']?.toString();
      if (ts == null || ts.isEmpty) return;

      final now = DateTime.now();
      final bool activeTrip = payload['bookingId'] != null;
      final bool isNewFix = ts != _lastSentLocationTimestamp;

      // Active-trip state flipped since the stream was built -> rebuild it so
      // the distanceFilter matches (0 on trip, 5 idle). startEmitLoop() bumps
      // the loop token, so this timer stops right after we return.
      if (activeTrip != _emitLoopForActiveTrip) {
        unawaited(startEmitLoop());
        return;
      }

      // Idle/online: only emit on a genuinely new GPS fix (battery + data).
      // Active trip: also re-emit the last position as a steady ~1s heartbeat
      // so the customer engine keeps gliding / dead-reckoning through GPS gaps
      // (tunnels, signal loss) instead of freezing then jumping.
      if (!isNewFix && !activeTrip) return;

      // Stop the 1s feed once the car has been stationary too long. An active
      // trip gets a long window (covers red lights / tunnels) before backing
      // off; idle uses the short cutoff. The active window also bounds a
      // booking whose context wasn't cleared on completion so it can't emit
      // 1Hz forever while parked.
      final movedAt = _lastMovedAt;
      final idleFor = movedAt == null
          ? const Duration(days: 9999)
          : now.difference(movedAt);
      final idleCutoff =
          activeTrip ? _activeTripIdleCutoff : _movementIdleCutoff;
      if (idleFor >= idleCutoff) {
        return;
      }

      final preferredInterval = _preferredLocationEmitInterval(payload);
      final lastEmitAt = _lastLocationEmitAt;
      if (lastEmitAt != null &&
          now.difference(lastEmitAt) < preferredInterval) {
        return;
      }

      // Build the outgoing payload. For a heartbeat re-emit (no fresh fix)
      // refresh the timestamp to send-time so the customer orders it after the
      // previous point; remember the GPS fix time so the next real fix is still
      // detected as new.
      //
      // CRITICAL: a re-emit means we have NO fresh evidence of motion. Send
      // speed:0 (keep the last bearing) so the customer engine HOLDS the marker
      // instead of dead-reckoning it forward. Otherwise a car stopped at a
      // signal (last known speed > 0) would visibly creep/drift past the line.
      final Map<String, dynamic> outPayload;
      if (isNewFix) {
        outPayload = payload;
        _lastSentLocationTimestamp = ts;
      } else {
        outPayload = Map<String, dynamic>.from(payload)
          ..['timestamp'] = now.toUtc().toIso8601String()
          ..['speed'] = 0.0;
      }

      _lastLocationEmitAt = now;
      _lastUpdateLocationEmitAt = now;
      if (_backgroundServiceActive) return;
      socketService.emit('updateLocation', outPayload);
      _noteDriverEmitMetric(
        event: 'updateLocation',
        bookingId: outPayload['bookingId']?.toString(),
      );
      Get.find<DriverAnalyticsController>().trackOnlineTick(
        const Duration(seconds: 7),
      );
      // Reference log is centralized in `SocketService.emit()` for `updateLocation`.
    });
    emitTimer = localEmitTimer;
    if (token != _emitLoopToken) {
      localEmitTimer.cancel();
      return;
    }

    // Not moving but online => emit `driver-heartbeat` every 20–30s (we use 25s).
    if (activeTripStream) {
      heartbeatTimer?.cancel();
      return;
    }
    final localHeartbeatTimer = Timer.periodic(const Duration(seconds: 25), (
      _,
    ) {
      if (_disposed || isClosed) return;
      if (token != _emitLoopToken) return;
      if (!statusController.isOnline.value) return;
      final did = driverId?.trim() ?? '';
      if (did.isEmpty) return;

      final now = DateTime.now();
      final lastLocAt = _lastUpdateLocationEmitAt;
      if (lastLocAt != null &&
          now.difference(lastLocAt) < const Duration(seconds: 20)) {
        return;
      }
      final lastHbAt = _lastHeartbeatEmitAt;
      if (lastHbAt != null &&
          now.difference(lastHbAt) < const Duration(seconds: 20)) {
        return;
      }

      final bookingIdForPayload = _resolveBookingIdForLocationPayload();
      if (bookingIdForPayload != null) {
        return;
      }
      final pos = lastPosition;
      final hb = <String, dynamic>{
        'userId': did,
        'driverId': did,
        if (bookingIdForPayload != null) 'bookingId': bookingIdForPayload,
        if (pos != null) 'latitude': pos.latitude,
        if (pos != null) 'longitude': pos.longitude,
        'seq': socketService.nextClientLocationSeq(),
        // UTC (consistent with updateLocation). Local time here made the
        // customer's strict ordering drop points when the source flipped.
        'timestamp': now.toUtc().toIso8601String(),
        'clientSentAt': now.toUtc().toIso8601String(),
      };
      _lastHeartbeatEmitAt = now;
      socketService.emit('driver-heartbeat', hb);
    });
    heartbeatTimer = localHeartbeatTimer;
    if (token != _emitLoopToken) {
      localHeartbeatTimer.cancel();
      return;
    }
  }

  // ---------------- socket init + listeners ----------------
  /// DUAL-CONNECT: process an incoming dispatch (booking) request from EITHER the
  /// primary socket (shared backend while shared-enabled, or single when shared
  /// off) OR the secondary single-ride (bk) dispatch socket. The ride's backend
  /// is bound at ACCEPT time from the payload's `sharedBooking` flag (see the
  /// accept button in driver_main_screen.dart), so no origin is threaded here.
  Future<void> _processBookingRequest(dynamic data) async {
      if (_disposed || isClosed) return;
      if (data == null) return;

      final payload = _coerceSocketPayloadToMap(data);
      if (payload == null) return;

      BookingDataService().setBookingData(payload);

      if (payload['type'] == 'active-bookings') {
        final List active = payload['activeBookings'] ?? [];
        if (active.isEmpty) return;

        final booking = active.first;
        currentBookingId = booking['bookingId']?.toString();
        // BG tracking is started only when app goes to background to avoid
        // `io server disconnect` caused by multiple sockets for same driverId.

        final fromLat = (booking['fromLatitude'] as num?)?.toDouble();
        final fromLng = (booking['fromLongitude'] as num?)?.toDouble();
        final toLat = (booking['toLatitude'] as num?)?.toDouble();
        final toLng = (booking['toLongitude'] as num?)?.toDouble();

        if (fromLat == null ||
            fromLng == null ||
            toLat == null ||
            toLng == null) {
          return;
        }

        final pickupAddressText = _preferredAddress(
          booking,
          keys: const ['pickupAddress', 'pickupLocationAddress'],
        );
        final dropAddressText = _preferredAddress(
          booking,
          keys: const ['dropAddress', 'dropLocationAddress'],
        );
        final pickupAddr =
            pickupAddressText.isNotEmpty
                ? pickupAddressText
                : await getAddressFromLatLng(fromLat, fromLng);
        final dropAddr =
            dropAddressText.isNotEmpty
                ? dropAddressText
                : await getAddressFromLatLng(toLat, toLng);

        if (_disposed || isClosed) return;

        bookingController.showRequest(
          rawData: booking,
          pickupAddress: pickupAddr,
          dropAddress: dropAddr,
        );
        startCountdown();
        return;
      }

      currentBookingId = payload['bookingId']?.toString();
      // BG tracking is started only when app goes to background.

      final pickup = payload['pickupLocation'];
      final drop = payload['dropLocation'];
      if (pickup == null || drop == null) return;

      final pickupLat = (pickup['latitude'] as num?)?.toDouble();
      final pickupLng = (pickup['longitude'] as num?)?.toDouble();
      final dropLat = (drop['latitude'] as num?)?.toDouble();
      final dropLng = (drop['longitude'] as num?)?.toDouble();

      if (pickupLat == null ||
          pickupLng == null ||
          dropLat == null ||
          dropLng == null) {
        return;
      }

      final pickupAddressText = _preferredAddress(
        payload,
        keys: const ['pickupAddress', 'pickupLocationAddress'],
      );
      final dropAddressText = _preferredAddress(
        payload,
        keys: const ['dropAddress', 'dropLocationAddress'],
      );
      final pickupAddr =
          pickupAddressText.isNotEmpty
              ? pickupAddressText
              : await getAddressFromLatLng(pickupLat, pickupLng);
      final dropAddr =
          dropAddressText.isNotEmpty
              ? dropAddressText
              : await getAddressFromLatLng(dropLat, dropLng);

      if (_disposed || isClosed) return;

      bookingController.showRequest(
        rawData: payload,
        pickupAddress: pickupAddr,
        dropAddress: dropAddr,
      );
      startCountdown();
  }

  /// DUAL-CONNECT: start/stop the secondary single-ride (bk) dispatch socket so
  /// it runs exactly when the driver SHOULD be discoverable in customer "Ride
  /// Only" while shared-enabled — i.e. shared preference ON, online, and NOT on
  /// an active ride (no backend binding). In every other state it is torn down,
  /// guaranteeing at most one socket per backend (no same-backend contention).
  void syncSecondaryDispatchSocket() {
    if (_disposed || isClosed) return;
    try {
      final did = driverId?.trim() ?? '';
      final shouldRun =
          cfg.isSharedEnabled.value &&
          cfg.activeRideBackendShared.value == null &&
          statusController.isOnline.value &&
          did.isNotEmpty;
      if (shouldRun) {
        SecondaryDispatchSocket().start(
          url: ApiConfigController.singleSocket,
          driverId: did,
          deviceId: _dispatchDeviceId,
          onBookingRequest: (data) => _processBookingRequest(data),
        );
      } else {
        SecondaryDispatchSocket().stop();
      }
    } catch (e) {
      CommonLogger.log.e("[dual-connect] syncSecondaryDispatchSocket error: $e");
    }
  }

  /// DUAL-CONNECT: called when the home screen is re-entered (the permanent
  /// controller is reused, so [_prepare] does NOT re-run). Refresh the active
  /// booking; if none remains (e.g. the ride just completed), release the
  /// backend binding and bring the secondary dispatch socket back.
  Future<void> reconcileDualConnectAfterNavigation() async {
    if (_disposed || isClosed) return;
    try {
      await checkAndResumeActiveBooking();
    } catch (_) {}
    if (_disposed || isClosed) return;
    if (activeBookingData.value == null) {
      await onActiveRideEnded();
    } else {
      syncSecondaryDispatchSocket();
    }
  }

  /// DUAL-CONNECT: an active ride has ended (completed / cancelled / driver went
  /// offline). Release the active-ride backend binding so the IDLE backend
  /// reverts to the user's preference, then re-evaluate the secondary socket.
  Future<void> onActiveRideEnded() async {
    try {
      await cfg.clearActiveRideBackend();
    } catch (_) {}
    syncSecondaryDispatchSocket();
  }

  void _bindSocketListeners() {
    socketService.off('connect');
    socketService.off('registered');
    socketService.off('booking-request');
    socketService.off('driver-cancelled');
    socketService.off('customer-cancelled');
    socketService.off('driver:demand-opportunity');
    socketService.off('driver:demand-opportunities');
    // Instant active-booking cleanup signals (backend emits after final payment).
    socketService.off('payment_success');
    socketService.off('ride_completed');
    socketService.off('active_booking_cleared');
    socketService.off('driver_released');

    // Server-authoritative online status: register the push listener (dedup-safe)
    // so a server-side flip (other device / inactivity / admin) reaches the UI.
    statusController.bindOnlineStatusListener();

    socketService.on('connect', (_) {
      if (_disposed || isClosed) return;
      socketService.registerDriver(
        driverId ?? '',
        bookingId: currentBookingId,
        ack: (resp) {
          if (kDebugMode) CommonLogger.log.i("register ack: $resp");
        },
      );
      // Fires on initial connect AND every reconnect -> always pull the true
      // online status from the server and apply it.
      statusController.requestOnlineStatus(driverId: driverId);
    });

    socketService.on('registered', (_) async {
      if (_disposed || isClosed) return;
      await startEmitLoop();
      requestDemandOpportunities(reason: 'socket_registered');
      // RECONNECT RECOVERY (backend = source of truth): re-fetch the active
      // booking so the driver resumes into their active ride. THROTTLED (no
      // `force`): the socket can emit `registered` many times/second (re-register
      // loop), and forcing a refetch each time re-joins the shared rooms and
      // re-processes the ride EVERY SECOND — which made the complete button + map
      // BLINK and the swipe slider un-swipeable. The built-in 8s throttle still
      // covers genuine reconnects without the spam.
      await checkAndResumeActiveBooking();
    });

    socketService.on('driver-cancelled', (data) async {
      await handleDriverCancelled(data);
    });

    socketService.on('customer-cancelled', (data) async {
      await handleCustomerCancelled(data);
    });

    // After a final (online or cash) payment the backend releases the driver and
    // emits these. Don't trust the socket alone: re-verify via the active-booking
    // API so the card clears instantly but only ever reflects backend truth.
    socketService.on('payment_success', (data) async {
      await _handleActiveBookingTerminalEvent(data, 'payment_success');
    });
    socketService.on('ride_completed', (data) async {
      await _handleActiveBookingTerminalEvent(data, 'ride_completed');
    });
    socketService.on('active_booking_cleared', (data) async {
      await _handleActiveBookingTerminalEvent(data, 'active_booking_cleared');
    });
    socketService.on('driver_released', (data) async {
      await _handleActiveBookingTerminalEvent(data, 'driver_released');
    });

    socketService.on('booking-request', (data) async {
      await _processBookingRequest(data);
    });

    socketService.on('driver:demand-opportunities', (data) {
      if (_disposed || isClosed) return;
      final payload = _coerceSocketPayloadToMap(data);
      if (payload == null) return;

      // Payload may be {success,data} or just {data}.
      final root =
          payload.containsKey('data')
              ? payload
              : <String, dynamic>{'success': true, 'data': payload};

      final parsed = DemandOpportunitiesResponse.fromJson(root);
      final d = parsed.data;
      if (d == null) return;

      demandData.value = d;
      demandSummary.value = d.summary;
      demandOpportunities.assignAll(d.opportunities);
      unawaited(_syncDemandMarkerFromTop());
    });

    socketService.on('driver:demand-opportunity', (data) {
      if (_disposed || isClosed) return;
      final payload = _coerceSocketPayloadToMap(data);
      if (payload == null) return;

      final opp = DemandOpportunity.fromJson(payload);

      // If REST snapshot hasn't arrived yet, allow socket pushes to render the card.
      demandData.value ??= DemandOpportunitiesData(
        eligible: true,
        driverStatus: '',
        serviceType: opp.serviceType,
        generatedAt: DateTime.now(),
        opportunities: const <DemandOpportunity>[],
        summary: null,
      );

      _upsertDemandOpportunity(opp);
      unawaited(_syncDemandMarkerFromTop());
      _maybeShowDemandBanner(opp);
    });
  }

  /// Backend signalled this booking reached a terminal/paid state. We do NOT
  /// trust the socket alone — we re-fetch the active booking and let the
  /// backend-authoritative [checkAndResumeActiveBooking] clear the local cache
  /// (BookingDataService / currentBookingId / booking rooms) when the API says
  /// hasBooking=false, or restore only a backend-confirmed booking otherwise.
  /// Ignores events for a DIFFERENT booking (e.g. another shared passenger).
  Future<void> _handleActiveBookingTerminalEvent(
    dynamic data,
    String event,
  ) async {
    if (_disposed || isClosed) return;
    final payload = _coerceSocketPayloadToMap(data);
    final evtBookingId = (payload?['bookingId'] ?? '').toString().trim();
    final cur = (currentBookingId ?? '').toString().trim();
    // If both ids are known and differ, this concerns someone else's leg.
    if (evtBookingId.isNotEmpty && cur.isNotEmpty && evtBookingId != cur) {
      return;
    }
    if (kDebugMode) {
      CommonLogger.log.i('[$event] re-verifying active booking via API');
    }
    await checkAndResumeActiveBooking();
  }

  LatLng? _extractLatLngFrom(
    Map<String, dynamic> data, {
    required String mapKey,
    required String latKey,
    required String lngKey,
  }) {
    final nested = data[mapKey];
    if (nested is Map) {
      final lat = nested['latitude'];
      final lng = nested['longitude'];
      if (lat is num && lng is num)
        return LatLng(lat.toDouble(), lng.toDouble());
      final latD = double.tryParse(lat?.toString() ?? '');
      final lngD = double.tryParse(lng?.toString() ?? '');
      if (latD != null && lngD != null) return LatLng(latD, lngD);
    }

    final lat = data[latKey];
    final lng = data[lngKey];
    if (lat is num && lng is num) return LatLng(lat.toDouble(), lng.toDouble());
    final latD = double.tryParse(lat?.toString() ?? '');
    final lngD = double.tryParse(lng?.toString() ?? '');
    if (latD != null && lngD != null) return LatLng(latD, lngD);
    return null;
  }

  bool _asBool(dynamic v) {
    if (v == true) return true;
    final s = v?.toString().toLowerCase().trim();
    return s == 'true' || s == '1' || s == 'yes';
  }

  bool _statusHas(String status, List<String> needles) {
    final s = status.toLowerCase();
    for (final n in needles) {
      if (s.contains(n)) return true;
    }
    return false;
  }

  bool _isBookingCancelled(Map<String, dynamic> data, String status) {
    return _asBool(data['cancelled']) || _statusHas(status, ['cancel']);
  }

  bool _isBookingCompleted(Map<String, dynamic> data, String status) {
    // Backend sometimes sets `destinationReached=true` while the ride is still
    // active (driver near drop). Do NOT treat that as completed for resume UI.
    if (_asBool(data['rideCompleted']) ||
        _asBool(data['completed']) ||
        _asBool(data['isCompleted'])) {
      return true;
    }
    return _statusHas(status, ['complete', 'completed', 'finished']);
  }

  List<Map<String, dynamic>> _normalizeConnectedCustomers(dynamic v) {
    if (v is! List) return const <Map<String, dynamic>>[];
    final out = <Map<String, dynamic>>[];
    for (final e in v) {
      if (e is Map) {
        out.add(Map<String, dynamic>.from(e));
      }
    }
    return out;
  }

  bool _isSharedActiveBooking(Map<String, dynamic> data) {
    final live = data['driverLiveTracking'];
    return _asBool(data['sharedBooking']) ||
        _asBool(data['isShared']) ||
        _asBool(data['shared']) ||
        (live is Map && _asBool(live['sharedBooking']));
  }

  Future<void> _seedSharedRideFromActiveBooking(
    Map<String, dynamic> data,
  ) async {
    try {
      final isShared = _isSharedActiveBooking(data);
      if (!isShared) return;

      final live = data['driverLiveTracking'];
      final lat = (live is Map) ? live['currentLatitude'] : null;
      final lng = (live is Map) ? live['currentLongitude'] : null;
      final latD = (lat is num) ? lat.toDouble() : double.tryParse('$lat');
      final lngD = (lng is num) ? lng.toDouble() : double.tryParse('$lng');

      if (Get.isRegistered<SharedRideController>()) {
        // ok
      } else {
        Get.put(SharedRideController(), permanent: true);
      }
      final sharedRide = Get.find<SharedRideController>();

      // When returning from external navigation, the active-booking API may only
      // return the single rider being navigated to. To prevent data loss, we
      // preserve the existing list of riders if a shared pool is already active.
      final hadActiveSharedPool = sharedRide.riders.any(
        (r) => r.stage != SharedRiderStage.dropped,
      );
      final previousActiveBookingId =
          sharedRide.activeTarget.value?.bookingId.trim() ?? '';

      // If a shared ride is NOT already in progress, clear the list to start fresh.
      // This handles cases where a new shared ride is being initiated.
      if (!hadActiveSharedPool) {
        sharedRide.riders.clear();
        sharedRide.activeTarget.value = null;
      }

      if (latD != null && lngD != null) {
        sharedRide.driverLocation.value = LatLng(latD, lngD);
      }

      final connected = _normalizeConnectedCustomers(
        data['connectedCustomers'],
      );
      final seedList =
          connected.isNotEmpty ? connected : <Map<String, dynamic>>[data];

      for (final r in seedList) {
        final bid = (r['bookingId'] ?? '').toString().trim();
        if (bid.isEmpty) continue;

        final fromLat = r['fromLatitude'];
        final fromLng = r['fromLongitude'];
        final toLat = r['toLatitude'];
        final toLng = r['toLongitude'];

        final payload = <String, dynamic>{
          'bookingId': bid,
          'customerName': r['customerName'] ?? r['custName'] ?? r['name'],
          'customerPhone': r['customerPhone'] ?? r['phone'] ?? r['mobile'],
          'customerProfilePic':
              r['customerProfilePic'] ?? r['profilePic'] ?? r['image'],
          'amount': r['amount'] ?? r['total'] ?? r['driverReceivedAmount'],
          'pickupLocationAddress': r['pickupAddress'],
          'dropLocationAddress': r['dropAddress'],
          'customerLocation': <String, dynamic>{
            'fromLatitude': fromLat,
            'fromLongitude': fromLng,
            'toLatitude': toLat,
            'toLongitude': toLng,
          },
          'status': r['status'],
          'rideStarted': r['rideStarted'],
          'destinationReached': r['destinationReached'],
        };

        await sharedRide.upsertFromSocket(payload);

        final status = (r['status'] ?? '').toString();
        final rideStarted =
            _asBool(r['rideStarted']) ||
            _statusHas(status, ['ride_in_progress', 'in_progress', 'started']);
        final dropped =
            _asBool(r['destinationReached']) ||
            _statusHas(status, ['complete', 'completed', 'finished']);

        if (dropped) {
          sharedRide.markDropped(bid);
        } else if (rideStarted) {
          sharedRide.markOnboard(bid);
        }
      }

      if (hadActiveSharedPool &&
          previousActiveBookingId.isNotEmpty &&
          sharedRide.riders.any((r) => r.bookingId == previousActiveBookingId)) {
        sharedRide.activeTarget.value = sharedRide.riders.firstWhereOrNull(
          (r) => r.bookingId == previousActiveBookingId,
        );
      }

      // COLD-START RESTORE (source of truth wins): if the backend resume payload
      // carries a resolved active stop (stops[0] — already legal, reflecting the
      // driver's selected stop), adopt it OVER local greedy / prior in-memory
      // target. So a killed+reopened app shows the SAME stop the backend selected
      // (e.g. Pickup Customer 2), not a greedy recompute. Missing → greedy stands.
      final activeStop = data['activeStop'];
      if (activeStop is Map) {
        final asBid = (activeStop['bookingId'] ?? '').toString().trim();
        if (asBid.isNotEmpty) {
          final idx =
              sharedRide.riders.indexWhere((r) => r.bookingId == asBid);
          if (idx != -1 &&
              sharedRide.riders[idx].stage != SharedRiderStage.dropped &&
              !sharedRide.riders[idx].cancelledByCustomer) {
            sharedRide.activeTarget.value = sharedRide.riders[idx];
          }
        }
      }
    } catch (_) {
      // best-effort only; socket joined-booking will still hydrate in most cases
    }
  }

  String _resolveParentRoomIdFromActiveBooking(Map<String, dynamic> data) {
    final bookingId = (data['bookingId'] ?? '').toString().trim();
    final sharedBookingId = (data['sharedBookingId'] ?? '').toString().trim();
    final isShared = _isSharedActiveBooking(data);
    if (isShared && sharedBookingId.isNotEmpty) return sharedBookingId;
    return bookingId;
  }

  String _resolveActiveBookingKeyId(Map<String, dynamic> data) {
    // Use parent shared room id so dismiss/resume stays stable even if backend
    // changes which rider booking it returns as `bookingId`.
    final parentRoomId = _resolveParentRoomIdFromActiveBooking(data).trim();
    if (parentRoomId.isNotEmpty) return parentRoomId;
    return (data['bookingId'] ?? '').toString().trim();
  }

  int _resolveConnectedCustomersCount(Map<String, dynamic> data) {
    final fromCount = int.tryParse(
      (data['connectedCustomersCount'] ?? '').toString(),
    );
    if (fromCount != null && fromCount > 0) return fromCount;

    final normalized = _normalizeConnectedCustomers(data['connectedCustomers']);
    if (normalized.isNotEmpty) return normalized.length;

    final live = data['driverLiveTracking'];
    if (live is Map) {
      final list = live['activeSharedBookings'];
      if (list is List) return list.length;
    }

    return 0;
  }

  void _joinSharedRoomsFromActiveBooking({
    required String driverId,
    required String bookingId,
    required String parentRoomId,
    required dynamic liveTracking,
    required dynamic connectedCustomers,
  }) {
    // For shared rides backend may use:
    // - parent shared room (sharedBookingId)
    // - individual rider booking rooms (bookingId / activeSharedBookings)
    final rooms = <String>{bookingId.trim(), parentRoomId.trim()}
      ..removeWhere((e) => e.isEmpty);

    // Newer API may return the full list of connected customers/riders.
    // Join both their bookingId rooms and their sharedBookingId rooms so we
    // keep receiving events even when `activeSharedBookings` is absent/stale.
    if (connectedCustomers is List) {
      for (final e in connectedCustomers) {
        if (e is! Map) continue;
        final bId = (e['bookingId'] ?? '').toString().trim();
        final sId = (e['sharedBookingId'] ?? '').toString().trim();
        if (bId.isNotEmpty) rooms.add(bId);
        if (sId.isNotEmpty) rooms.add(sId);
      }
    }

    if (liveTracking is Map) {
      final list = liveTracking['activeSharedBookings'];
      if (list is List) {
        for (final e in list) {
          final id = (e ?? '').toString().trim();
          if (id.isNotEmpty) rooms.add(id);
        }
      }
    }

    // Ensure emits/heartbeats go only to the currently active rooms.
    socketService.setActiveBookingRooms(rooms, primaryBookingId: bookingId);

    // Keep the primary booking context as the rider bookingId (matches normal
    // shared-accept flow). Also join the parent shared room (and others)
    // without overwriting the socket's active booking context.
    socketService.registerDriver(driverId, bookingId: bookingId);
    socketService.joinBooking(bookingId, userId: driverId);

    // Also explicitly join other rooms immediately when already connected so
    // we receive `joined-booking` payloads right away.
    for (final r in rooms) {
      if (r == bookingId) continue;
      socketService.emit('join-booking', <String, dynamic>{
        'bookingId': r,
        'userId': driverId,
      });
    }
  }

  Future<void> checkAndResumeActiveBooking({bool force = false}) async {
    if (_disposed || isClosed) return;
    if (_checkingActiveBooking) return;

    final shouldAutoResumeFromExternalNav =
        await NavigationService().hasExternalNavigationReturnPending();

    final now = DateTime.now();
    final last = _lastActiveBookingCheckAt;
    if (!force &&
        last != null &&
        now.difference(last) < const Duration(seconds: 8)) {
      return;
    }
    _lastActiveBookingCheckAt = now;

    _checkingActiveBooking = true;
    try {
      final result = await _apiDataSource.getDriverActiveBooking();
      if (_disposed || isClosed) return;

      await result.fold((_) async {}, (
        DriverActiveBookingResponse response,
      ) async {
        if (!response.hasBooking) {
          activeBookingData.value = null;
          _lastDismissedBookingId = null;
          showActiveBookingCard.value = false;
          // No active trip on the backend -> drop stale trip context so the
          // location emit loop reverts to idle (distanceFilter 5, 5/8s buckets,
          // 20s idle cutoff). Without this a completed ride leaves
          // currentBookingId/BookingDataService set, keeping the active-trip
          // stream (distanceFilter 0 + 1s) alive -> battery/data drain.
          currentBookingId = null;
          BookingDataService().clear();
          socketService.clearAllBookingRooms();
          if (shouldAutoResumeFromExternalNav) {
            await NavigationService().clearExternalNavigationReturnPending();
          }
          return;
        }
        final data = response.data;
        if (data == null) {
          activeBookingData.value = null;
          showActiveBookingCard.value = false;
          // No active trip on the backend -> drop stale trip context (see above)
          // so the emit loop reverts to idle settings.
          currentBookingId = null;
          BookingDataService().clear();
          socketService.clearAllBookingRooms();
          if (shouldAutoResumeFromExternalNav) {
            await NavigationService().clearExternalNavigationReturnPending();
          }
          return;
        }

        final bookingId = (data['bookingId'] ?? '').toString().trim();
        if (bookingId.isEmpty) return;

        final live = data['driverLiveTracking'];
        final isShared = _isSharedActiveBooking(data);

        final sharedBookingId =
            (data['sharedBookingId'] ?? '').toString().trim();
        // For shared rides, backend uses a parent shared booking id/room.
        // Join that room so we receive pooled rider list (joined-booking).
        final parentRoomId =
            (isShared && sharedBookingId.isNotEmpty)
                ? sharedBookingId
                : bookingId;
        final keyId = parentRoomId;

        // Keep current booking id as the rider bookingId (numeric) so the rest
        // of the app behaves the same as normal shared accept flow.
        currentBookingId = bookingId;

        final did = driverId;
        if (did != null && did.trim().isNotEmpty) {
          // Important: do NOT auto-disable shared mode here. That preference
          // is user-controlled (drawer toggle + server status) and is also
          // used to decide which backend to connect to. We only auto-enable
          // shared mode when the active booking is clearly a shared booking.
          try {
            final cfg = Get.find<ApiConfigController>();
            if (isShared && cfg.isSharedEnabled.value != true) {
              await cfg.setSharedEnabled(true);
            }
          } catch (_) {}

          if (isShared) {
            _joinSharedRoomsFromActiveBooking(
              driverId: did,
              bookingId: bookingId,
              parentRoomId: parentRoomId,
              liveTracking: live,
              connectedCustomers: data['connectedCustomers'],
            );
          } else {
            socketService.setActiveBookingRooms(<String>[
              bookingId,
            ], primaryBookingId: bookingId);
            socketService.registerDriver(did, bookingId: bookingId);
            socketService.joinBooking(bookingId, userId: did);
          }
        }

        final status = (data['status'] ?? '').toString();
        final cancelled = _isBookingCancelled(data, status);
        final completed = _isBookingCompleted(data, status);
        if (cancelled || completed) {
          activeBookingData.value = null;
          _lastDismissedBookingId = null;
          showActiveBookingCard.value = false;
          // Trip finished/cancelled on the backend -> drop stale trip context so
          // the emit loop reverts to idle (distanceFilter 5, 5/8s, 20s cutoff).
          currentBookingId = null;
          BookingDataService().clear();
          socketService.clearAllBookingRooms();
          // DUAL-CONNECT: trip ended on the backend -> release the active-ride
          // backend binding and restore the secondary dispatch socket if idle.
          unawaited(onActiveRideEnded());
          if (shouldAutoResumeFromExternalNav) {
            await NavigationService().clearExternalNavigationReturnPending();
          }
          return;
        }

        final normalized = Map<String, dynamic>.from(data);
        normalized['connectedCustomers'] = _normalizeConnectedCustomers(
          data['connectedCustomers'],
        );
        normalized['connectedCustomersCount'] = _resolveConnectedCustomersCount(
          data,
        );

        activeBookingData.value = normalized;

        // H-D1: re-arm background tracking on cold-start/resume of an IN-PROGRESS trip.
        // Previously the BG service was only (re)started on the external-nav handoff path,
        // so if the app was killed mid-trip the customer's car marker froze for the rest of
        // the ride. When the resumed ride is STARTED and we're online, ensure it's running.
        if (status.toUpperCase() == 'STARTED' && statusController.isOnline.value) {
          driverId ??= await SharedPrefHelper.getDriverId();
          final didRearm = driverId?.trim() ?? '';
          if (didRearm.isNotEmpty) {
            unawaited(
              bg
                  .ensureDriverTrackingServiceRunning(
                    driverId: didRearm,
                    bookingId: _resolveBookingIdForLocationPayload(),
                  )
                  .catchError((_) {}),
            );
          }
        }

        // DUAL-CONNECT: an active ride was resolved on launch/resume -> bind its
        // backend (single vs shared) so the primary socket + API target the
        // backend that owns it, then drop the secondary dispatch socket. Covers
        // app-restart mid single-ride while shared is enabled (otherwise the
        // primary would stay on the shared backend).
        try {
          await cfg.bindActiveRideBackend(isShared);
        } catch (_) {}
        SecondaryDispatchSocket().stop();

        // Keep service type in sync so map marker icon (car/bike) matches resumed booking.
        statusController.setServiceTypeFrom(data['rideType']);
        JoinedBookingData().setData(Map<String, dynamic>.from(normalized));
        unawaited(_seedSharedRideFromActiveBooking(normalized));

        if (_lastDismissedBookingId == keyId) {
          showActiveBookingCard.value = false;
        } else {
          showActiveBookingCard.value = true;
        }

        if (shouldAutoResumeFromExternalNav) {
          await NavigationService().clearExternalNavigationReturnPending();
          Future<void>.delayed(const Duration(milliseconds: 120), () async {
            if (_disposed || isClosed) return;
            await resumeActiveBooking();
          });
        }
      });
    } finally {
      _checkingActiveBooking = false;
    }
  }

  void dismissActiveBookingCard() {
    final data = activeBookingData.value;
    if (data != null) {
      final keyId = _resolveActiveBookingKeyId(data);
      if (keyId.trim().isNotEmpty) _lastDismissedBookingId = keyId;
    }
    showActiveBookingCard.value = false;
  }

  LatLng? _pickupFromActiveBooking(Map<String, dynamic> data) {
    final fromPickup = _extractLatLngFrom(
      data,
      mapKey: 'pickupLocation',
      latKey: 'fromLatitude',
      lngKey: 'fromLongitude',
    );
    if (fromPickup != null) return fromPickup;
    return _extractLatLngFrom(
      data,
      mapKey: 'customerLocation',
      latKey: 'fromLatitude',
      lngKey: 'fromLongitude',
    );
  }

  LatLng? _driverFromActiveBooking(Map<String, dynamic> data) {
    final live = data['driverLiveTracking'];
    if (live is Map) {
      final lat = live['currentLatitude'];
      final lng = live['currentLongitude'];
      if (lat is num && lng is num)
        return LatLng(lat.toDouble(), lng.toDouble());
      final latD = double.tryParse(lat?.toString() ?? '');
      final lngD = double.tryParse(lng?.toString() ?? '');
      if (latD != null && lngD != null) return LatLng(latD, lngD);
    }
    final driverLoc = data['driverLocation'];
    if (driverLoc is Map) {
      final lat = driverLoc['latitude'];
      final lng = driverLoc['longitude'];
      if (lat is num && lng is num)
        return LatLng(lat.toDouble(), lng.toDouble());
      final latD = double.tryParse(lat?.toString() ?? '');
      final lngD = double.tryParse(lng?.toString() ?? '');
      if (latD != null && lngD != null) return LatLng(latD, lngD);
    }
    return null;
  }

  Future<void> resumeActiveBooking({bool userInitiated = false}) async {
    if (_disposed || isClosed) return;
    // Guard against resuming a ride from the home-screen card while the driver
    // is offline. Only blocks an explicit user tap; programmatic auto-resume
    // (e.g. returning from external navigation during an active ride) is left
    // untouched.
    if (userInitiated && !statusController.isOnline.value) {
      Get.snackbar(
        'You are offline',
        'Go online to resume your active ride.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    final data = activeBookingData.value;
    if (data == null) return;

    final bookingId = (data['bookingId'] ?? '').toString().trim();
    if (bookingId.isEmpty) return;

    final status = (data['status'] ?? '').toString();
    final cancelled = _isBookingCancelled(data, status);
    final completed = _isBookingCompleted(data, status);
    if (cancelled || completed) return;

    final live = data['driverLiveTracking'];
    final isShared = _isSharedActiveBooking(data);

    final sharedBookingId = (data['sharedBookingId'] ?? '').toString().trim();
    final parentRoomId =
        (isShared && sharedBookingId.isNotEmpty) ? sharedBookingId : bookingId;
    final keyId = parentRoomId;

    if (_lastResumedBookingId == keyId) return;

    final pickup = _pickupFromActiveBooking(data);
    if (pickup == null) return;

    final driverLoc =
        _driverFromActiveBooking(data) ??
        lastPosition ??
        currentPosition.value ??
        pickup;

    final pickupAddress =
        (data['pickupAddress'] ?? data['pickupLocationAddress'] ?? '')
            .toString();
    final dropAddress =
        (data['dropAddress'] ?? data['dropLocationAddress'] ?? '').toString();

    final rideStarted =
        _asBool(data['rideStarted']) ||
        _asBool(data['rideStart']) ||
        _statusHas(status, [
          'ride_in_progress',
          'ride in progress',
          'ride_started',
          'ride started',
          'started',
          'in_progress',
        ]);

    final did = driverId;
    if (did != null && did.trim().isNotEmpty) {
      try {
        final cfg = Get.find<ApiConfigController>();
        if (isShared && cfg.isSharedEnabled.value != true) {
          await cfg.setSharedEnabled(true);
        }
      } catch (_) {}

      currentBookingId = bookingId;
      if (isShared) {
        _joinSharedRoomsFromActiveBooking(
          driverId: did,
          bookingId: bookingId,
          parentRoomId: parentRoomId,
          liveTracking: live,
          connectedCustomers: data['connectedCustomers'],
        );
      } else {
        socketService.setSingleActiveBookingRoom(bookingId);
        socketService.registerDriver(did, bookingId: bookingId);
        socketService.joinBooking(bookingId, userId: did);
      }
    }

    _lastResumedBookingId = keyId;
    showActiveBookingCard.value = false;

    await Future<void>.delayed(const Duration(milliseconds: 120));
    if (_disposed || isClosed) return;

    if (isShared) {
      await _seedSharedRideFromActiveBooking(data);
      if (rideStarted) {
        Get.off(
          () => ShareRideStartScreen(
            pickupLocation: pickup,
            driverLocation: driverLoc,
            bookingId: bookingId,
          ),
        );
        return;
      }

      Get.off(
        () => PickingCustomerSharedScreen(
          pickupLocation: pickup,
          driverLocation: driverLoc,
          bookingId: bookingId,
          pickupLocationAddress: pickupAddress,
          dropLocationAddress: dropAddress,
        ),
      );
      return;
    }

    if (rideStarted) {
      Get.off(
        () => RideStatsScreen(
          bookingId: bookingId,
          pickupAddress: pickupAddress,
          dropAddress: dropAddress,
        ),
      );
      return;
    }

    final arrived =
        _asBool(data['driverArrived']) || _statusHas(status, ['arrived']);
    final otpVerified = _asBool(data['otpVerified']);
    final custName =
        (data['custName'] ?? data['customerName'] ?? data['name'] ?? '')
            .toString();

    if (arrived && !otpVerified && custName.trim().isNotEmpty) {
      Get.off(
        () => VerifyRiderScreen(
          bookingId: bookingId,
          custName: custName,
          pickupAddress: pickupAddress,
          dropAddress: dropAddress,
        ),
      );
      return;
    }

    Get.off(
      () => PickingCustomerScreen(
        pickupLocation: pickup,
        driverLocation: driverLoc,
        bookingId: bookingId,
        pickupLocationAddress: pickupAddress,
        dropLocationAddress: dropAddress,
      ),
    );
  }

  Future<void> initSocketAndLocation() async {
    driverId = await SharedPrefHelper.getDriverId();
    if (_disposed || isClosed) return;
    if (driverId == null) return;

    // Stable per-install device id (FCM token) so the backend can dedupe this
    // device's foreground/background sockets instead of revoking the foreground
    // as a `new-device-login`. Set BEFORE register so the very first `register`
    // carries it. Safe no-op if the token isn't ready yet (re-register on
    // connect will include it once available).
    try {
      final prefs = await SharedPreferences.getInstance();
      final fcm = (prefs.getString('fcmToken') ?? '').trim();
      if (fcm.isNotEmpty) {
        socketService.setDeviceId(fcm);
        _dispatchDeviceId = fcm;
      }
    } catch (_) {}
    if (_disposed || isClosed) return;

    socketService.initSocket(cfg.socketUrl);
    _bindSocketListeners();

    // ✅ IMPORTANT: if the socket is already connected (singleton reused),
    // the 'connect' callback won't fire again. Register immediately so switching
    // Car -> Logout -> Bike works without app restart.
    final did = driverId?.trim() ?? '';
    if (did.isNotEmpty) {
      socketService.registerDriver(did, bookingId: currentBookingId);
      if (socketService.connected) {
        await startEmitLoop();
        requestDemandOpportunities(reason: 'socket_already_connected');
        // Socket already up (singleton reused) -> 'connect' won't refire, so
        // pull the authoritative online status now.
        statusController.requestOnlineStatus(driverId: did);
      }
    }

    await initLocation();
    startCameraFollow();

    // NOTE: Don’t start BG tracking while the app is foregrounded.
    // Running BG socket + foreground socket together causes `io server disconnect`
    // on servers that enforce a single active session per driverId.
  }

  /// Foreground single-session self-heal.
  ///
  /// When the backend revokes this socket (a newer session for the same userId
  /// took over), `SocketService` suppresses auto-reconnect to stop the
  /// revoke-war. That is correct WHILE the app is backgrounded (the background
  /// tracking isolate legitimately owns the session). But if the app is in the
  /// FOREGROUND and online, THIS isolate is the rightful owner — a suppressed
  /// socket would otherwise sit dead (dropping updateLocation/heartbeat) with no
  /// resume event to trigger a reclaim, so the customer's marker freezes.
  ///
  /// Here we reclaim: stop any background isolate first (so it can't fight back
  /// — it also self-stops on its own session-revoke), then intentionally
  /// reconnect (`connect()` clears the revoke flag) and re-register. Debounced
  /// to 5s so a genuinely contested session backs off instead of tight-looping.
  void _maybeReclaimRevokedSession() {
    if (_disposed || isClosed) return;
    if (!_appInForeground) return; // backgrounded -> BG isolate owns the session
    if (!statusController.isOnline.value) return; // offline -> nothing to own
    if (!socketService.sessionRevoked) return; // only when explicitly suppressed

    final now = DateTime.now();
    if (now.difference(_lastSessionReclaimAt) < const Duration(seconds: 5)) {
      return;
    }
    _lastSessionReclaimAt = now;

    unawaited(bg.stopDriverTrackingService());
    socketService.connect(); // intentional reclaim -> clears the revoke flag
    final did = driverId?.trim() ?? '';
    if (did.isNotEmpty) {
      socketService.registerDriver(did, bookingId: currentBookingId);
    }
    if (kDebugMode) {
      CommonLogger.log.w(
        '🩹 [SOCKET] Foreground reclaiming revoked session url=${socketService.currentUrl}',
      );
    }
  }

  Future<void> onAppPaused() async {
    if (_disposed || isClosed) return;
    _appInForeground = false;
    final handoffRequestedAt = DateTime.now().millisecondsSinceEpoch;

    // RACE-PROOF the foreground→background handoff. Suspend the foreground
    // socket's auto-reconnect SYNCHRONOUSLY, before the background isolate's
    // socket can register. When the background socket registers with a different/
    // missing deviceId, the backend revokes THIS foreground socket (single
    // session). The foreground would otherwise process that "io server disconnect"
    // and auto-reconnect BEFORE the buffered `session-revoked` event sets its
    // guard — re-registering and revoking the background socket, which then
    // `stopSelf()`s and freezes customer tracking while Google Maps is open.
    // Reclaimed by socketService.connect() in onAppResumed.
    socketService.suspendAutoReconnect();

    // Hand off to background service ONLY when online.
    var bgRunning = false;
    if (statusController.isOnline.value) {
      driverId ??= await SharedPrefHelper.getDriverId();
      final did = driverId?.trim() ?? '';
      if (did.isNotEmpty) {
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setInt('bg_handoff_requested_at', handoffRequestedAt);
        } catch (_) {}
        try {
          await bg.ensureDriverTrackingServiceRunning(
            driverId: did,
            bookingId: _resolveBookingIdForLocationPayload(),
          );
        } catch (_) {}
        bgRunning = await bg.isDriverTrackingServiceRunning();
        if (!bgRunning) {
          // RACE FIX: ensureDriverTrackingServiceRunning() only waits ~350ms after
          // startService(), but on many OEMs the foreground-service engine needs
          // longer (cold Flutter engine spin-up) before `isRunning()` reports true.
          // Concluding "not running" here is dangerous: the code below then KEEPS
          // the foreground socket alive (connect()) — and the BG service comes up a
          // moment later anyway, so BOTH end up on the same backend (bck) for this
          // driver. That is the single-session revoke-war / connect→forced-close
          // storm seen on return from Google Maps, AND the foreground GPS stream is
          // throttled by the OS once backgrounded → the customer's car freezes.
          // Poll briefly so we trust a slow-but-real BG start instead of duelling.
          final bgWaitUntil = DateTime.now().add(const Duration(seconds: 2));
          while (DateTime.now().isBefore(bgWaitUntil)) {
            await Future<void>.delayed(const Duration(milliseconds: 150));
            if (await bg.isDriverTrackingServiceRunning()) {
              bgRunning = true;
              break;
            }
          }
        }
        if (bgRunning) {
          // Best-effort: give the (usually COLD — onAppResumed stops the service
          // on every return, so each Navigate starts it fresh) background isolate
          // a moment to land its first emit BEFORE we cut the foreground, purely
          // to minimise the hand-off gap. The foreground keeps emitting during
          // this wait (the _backgroundServiceActive gate below is set AFTER it).
          //
          // CRITICAL: we must NOT demote a genuinely-running foreground service
          // to "not running" just because this first emit is still in flight. A
          // cold Flutter engine spin-up + socket connect + first bestForNavigation
          // fix routinely needs >1.6s, so the old code set bgRunning=false on
          // timeout and fell through to the "keep foreground socket" path below —
          // WHILE the background service was also running. That left TWO sockets
          // duelling for the backend's single session and a foreground GPS stream
          // the OS throttles once the app is backgrounded behind Google Maps,
          // which is exactly the "tracking freezes when the driver opens Maps"
          // bug. The FGS-backed background isolate is the RELIABLE emitter while
          // backgrounded; trust it once it is running. The brief sub-second gap
          // until its first emit is absorbed by the customer-side jitter buffer /
          // dead-reckoning.
          try {
            final prefs = await SharedPreferences.getInstance();
            final waitUntil = DateTime.now().add(
              const Duration(milliseconds: 1600),
            );
            while (DateTime.now().isBefore(waitUntil)) {
              final lastBgEmitAt = prefs.getInt('bg_last_emit_at') ?? 0;
              if (lastBgEmitAt >= handoffRequestedAt) {
                break;
              }
              await Future<void>.delayed(const Duration(milliseconds: 150));
            }
          } catch (_) {}
        }
      }
    }

    _backgroundServiceActive = bgRunning;

    // If BG service cannot run (most commonly notifications disabled / OEM blocks),
    // do NOT disconnect the foreground socket; otherwise customers will lose the
    // driver marker immediately when the app is minimized.
    if (statusController.isOnline.value && !bgRunning) {
      if (kDebugMode) {
        CommonLogger.log.w(
          '[BG_HANDOFF] BG service not running; keeping foreground socket active',
        );
      }
      // No handoff happened — the foreground stays the sole emitter, so restore
      // its normal auto-reconnect (clear the handoff suspension set above).
      socketService.connect();
      return;
    }

    // Stop foreground emit loop to avoid duplicates.
    await locationSub?.cancel();
    emitTimer?.cancel();
    heartbeatTimer?.cancel();

    // Disconnect foreground socket so BG can own the single connection.
    socketService.disconnect();
  }

  Future<void> onAppResumed() async {
    if (_disposed || isClosed) return;
    _appInForeground = true;
    _backgroundServiceActive = false;

    // Back in Hoppr — the floating "return to app" bubble over Google Maps is
    // now redundant. (MainActivity.onResume also removes it as a native safety
    // net; this covers resume paths that don't recreate the activity.)
    unawaited(NavigationService().hideReturnBubble());

    driverId ??= await SharedPrefHelper.getDriverId();
    final did = driverId?.trim() ?? '';
    if (did.isEmpty) return;

    // Stop BG socket/service before reconnecting foreground socket to avoid
    // `io server disconnect` loop (server enforces single active session).
    try {
      await bg.stopDriverTrackingService();
    } catch (_) {}
    await Future.delayed(const Duration(milliseconds: 350));

    // Some screens temporarily replace socket listeners; restore core listeners.
    _bindSocketListeners();

    // Ensure socket is connected & registered after background/resume cycles.
    socketService.connect();
    socketService.registerDriver(did, bookingId: currentBookingId);
    if (socketService.connected) {
      await startEmitLoop();
      requestDemandOpportunities(reason: 'app_resumed');
    }
    // Resume: the toggle must reflect the TRUE server status (it may have been
    // flipped offline by inactivity / another device while we were away).
    statusController.requestOnlineStatus(driverId: did);

    unawaited(restorePendingBookingRequestFromNotification(force: true));

    // Update home stats when returning from other screens / background.
    unawaited(refreshHomeStats());
  }

  // ---------------- âœ… listen shared toggle ----------------
  void _listenSharedToggle() {
    _sharedToggleWorker?.dispose();

    _sharedToggleWorker = ever<bool>(cfg.isSharedEnabled, (enabled) async {
      if (_disposed || isClosed) return;

      try {
        final newUrl = cfg.socketUrl;
        CommonLogger.log.i(
          "ðŸ” Shared changed => $enabled | switch socket => $newUrl",
        );

        socketService.switchUrl(newUrl);
        _bindSocketListeners();

        socketService.registerDriver(
          driverId ?? '',
          bookingId: currentBookingId,
        );

        await startEmitLoop();

        // DUAL-CONNECT: shared preference changed -> the primary socket just
        // switched backends; re-evaluate the secondary single-ride dispatch
        // socket (start when enabling+online+idle, stop when disabling).
        syncSecondaryDispatchSocket();

        if (statusController.isOnline.value) {
          if (_appInForeground) {
            unawaited(bg.stopDriverTrackingService());
          } else {
            unawaited(bg.stopDriverTrackingService());
            unawaited(
              Future.delayed(
                const Duration(milliseconds: 450),
                () => bg.ensureDriverTrackingServiceRunning(
                  driverId: driverId,
                  bookingId: _resolveBookingIdForLocationPayload(),
                ),
              ),
            );
          }
        }
      } catch (e) {
        CommonLogger.log.e("âŒ socket switch failed: $e");
      }
    });
  }

  void _listenServiceType() {
    _serviceTypeWorker?.dispose();

    _serviceTypeWorker = ever<String>(statusController.serviceType, (_) async {
      if (_disposed || isClosed) return;

      await loadCustomCarIcon();
      if (_disposed || isClosed) return;

      _refreshMarkerIcon();

      final pos = lastPosition ?? currentPosition.value;
      if (pos != null) updateCarMarker(pos);
    });
  }

  void _refreshMarkerIcon() {
    if (_disposed || isClosed) return;
    final icon = carIcon;
    final marker = carMarker;
    if (icon == null || marker == null) return;

    carMarker = Marker(
      markerId: marker.markerId,
      position: marker.position,
      icon: icon,
      rotation: marker.rotation,
      anchor: marker.anchor,
      flat: marker.flat,
    );

    update(['map']);
  }

  // ---------------- toggle online ----------------
  Future<void> toggleOnline() async {
    if (_disposed || isClosed) return;
    if (statusController.isToggleLoading.value) return;

    HapticFeedback.lightImpact();
    statusController.isToggleLoading.value = true;

    try {
      final nextOnline = !statusController.isOnline.value;

      // Android 13+ requires notification permission to post the mandatory
      // foreground-service notification. If it's blocked/denied, starting the
      // tracking service can crash the app on newer Android versions.
      if (nextOnline) {
        final ok = await _ensureNotificationPermissionForFgs();
        if (!ok) {
          CustomSnackBar.showError(
            'Enable notification permission to go online (needed for tracking).',
          );
          return;
        }
        // Going online: ask the OS to exempt Hoppr from battery optimization so
        // OEMs don't suspend the tracking FGS mid-trip (the driver-side "froze
        // then jumped" cause). Best-effort, never blocks going online.
        unawaited(_requestBatteryOptimizationExemptionOnce());
      }

      // Show a pending state until the server confirms via driver-online-status
      // (push) or the get-online-status ack below. Optimistic flip keeps the tap
      // responsive; the server's truth reconciles it (and reverts on failure).
      statusController.markTogglePending();
      statusController.toggleStatus();
      final isOnline = statusController.isOnline.value;

      double lat =
          lastPosition?.latitude ?? currentPosition.value?.latitude ?? 0.0;
      double lng =
          lastPosition?.longitude ?? currentPosition.value?.longitude ?? 0.0;

      if (isOnline && (lat == 0.0 || lng == 0.0)) {
        final pos = await getCurrentPos();
        if (_disposed || isClosed) return;

        if (pos == null) {
          statusController.toggleStatus();
          return;
        }
        lat = pos.latitude;
        lng = pos.longitude;

        final latLng = LatLng(lat, lng);
        currentPosition.value = latLng;
        updateCarMarker(latLng);
      }

      await statusController.onlineAcceptStatus(
        Get.context!,
        status: isOnline,
        latitude: lat,
        longitude: lng,
      );

      // Confirm with the server (its push/ack is the source of truth). If the
      // toggle failed server-side, this reconciles the optimistic flip back.
      statusController.requestOnlineStatus(driverId: driverId);

      // Background tracking (screen lock / app closed). Runs as Android foreground service.
      if (isOnline) {
        if (_appInForeground) {
          // Foreground uses SocketService (single connection). BG starts on pause.
          unawaited(bg.stopDriverTrackingService());
        } else {
          unawaited(
            bg.ensureDriverTrackingServiceRunning(
              driverId: driverId,
              bookingId: _resolveBookingIdForLocationPayload(),
            ),
          );
        }
      } else {
        unawaited(bg.stopDriverTrackingService());
      }

      if (isOnline) {
        followDriver.value = true;
        await goToCurrentLocation();
      }

      // DUAL-CONNECT: (re)evaluate the secondary single-ride dispatch socket now
      // that online state changed — starts it when going online while shared is
      // enabled and idle; stops it when going offline.
      syncSecondaryDispatchSocket();
    } catch (e) {
      statusController.toggleStatus();
      CommonLogger.log.e("toggle online error: $e");
    } finally {
      statusController.isToggleLoading.value = false;
    }
  }

  bool _batteryOptExemptionAsked = false;

  /// Uber/Ola-style battery-optimization opt-in. Aggressive OEMs (Xiaomi/Oppo/
  /// Vivo/Samsung) suspend a backgrounded foreground service unless exempted —
  /// that suspension froze the driver location feed mid-trip (the customer saw
  /// the car stop ~50s then jump). Like Uber, we DON'T fire the bare system
  /// dialog: we first show a clear rationale sheet explaining why, then the
  /// driver taps "Turn on" to grant. Once per session, best-effort, never blocks
  /// going online.
  Future<void> _requestBatteryOptimizationExemptionOnce() async {
    if (!Platform.isAndroid) return;
    if (_batteryOptExemptionAsked) return;
    _batteryOptExemptionAsked = true;
    try {
      // Already exempted -> nothing to ask.
      final status = await Permission.ignoreBatteryOptimizations.status;
      if (status.isGranted) return;
      if (Get.context == null) return;

      final accepted = await Get.bottomSheet<bool>(
        _batteryOptimizationSheet(),
        isScrollControlled: true,
        isDismissible: true,
        backgroundColor: Colors.transparent,
      );

      if (accepted == true) {
        await Permission.ignoreBatteryOptimizations.request();
      }
    } catch (_) {}
  }

  Widget _batteryOptimizationSheet() {
    const brand = Color(0xFF357AE9);
    Widget bullet(IconData icon, String title, String sub) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 38,
            width: 38,
            decoration: BoxDecoration(
              color: brand.withOpacity(0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: brand, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  sub,
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.3,
                    color: Colors.black.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 4,
              width: 44,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.12),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 18),
            Container(
              height: 56,
              width: 56,
              decoration: BoxDecoration(
                color: brand.withOpacity(0.10),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.battery_charging_full_rounded,
                color: brand,
                size: 30,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Keep Hoppr running',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Allow Hoppr to ignore battery optimization so it keeps working '
              'while you drive with the screen off.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.35,
                color: Colors.black.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 14),
            bullet(
              Icons.notifications_active_rounded,
              "Don't miss ride requests",
              'Get new trips even when the app is in the background.',
            ),
            bullet(
              Icons.my_location_rounded,
              'Smooth live tracking',
              'Your car stays accurate for the customer — no freezing or jumps.',
            ),
            bullet(
              Icons.account_balance_wallet_rounded,
              'No lost earnings',
              'Stay online reliably through your whole shift.',
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Get.back<bool>(result: true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: brand,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Turn on',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Get.back<bool>(result: false),
                child: Text(
                  'Not now',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black.withOpacity(0.55),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _ensureNotificationPermissionForFgs() async {
    if (!Platform.isAndroid) return true;

    try {
      final android =
          FlutterLocalNotificationsPlugin()
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >();
      final enabled = await android?.areNotificationsEnabled();
      if (enabled == false) return false;

      final status = await Permission.notification.status;
      if (status.isGranted) return true;
      final res = await Permission.notification.request();
      return res.isGranted;
    } catch (_) {
      // Be permissive on plugin/OS edge cases; service start still guarded by try/catch/logs.
      return true;
    }
  }

  // ---------------- lifecycle ----------------
  @override
  void onInit() {
    super.onInit();

    _disposed = false;

    animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );

    anim = CurvedAnimation(parent: animCtrl, curve: Curves.easeOutCubic)
      ..addListener(() {
        if (_disposed || isClosed) return;

        final lt = latTween;
        final lg = lngTween;
        final rt = rotTween;
        if (lt == null || lg == null || rt == null) return;

        final lat = lt.evaluate(anim);
        final lng = lg.evaluate(anim);
        final rot = rt.evaluate(anim);

        final icon = carIcon ?? BitmapDescriptor.defaultMarker;
        carMarker = Marker(
          markerId: const MarkerId('car'),
          position: LatLng(lat, lng),
          icon: icon,
          rotation: rot,
          anchor: const Offset(0.5, 0.5),
          flat: true,
        );

        update(['map']);
      });

    _demandPulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..addListener(() {
      if (_disposed || isClosed) return;
      final center = _demandPulseCenter;
      final color = _demandPulseColor;
      if (center == null || color == null) return;

      final now = DateTime.now();
      if (now.difference(_lastDemandPulsePaintAt) <
          const Duration(milliseconds: 50)) {
        return;
      }
      _lastDemandPulsePaintAt = now;

      demandCircles = _demandPulseRings(
        center: center,
        color: color,
        t: _demandPulseCtrl.value,
      );
      update(['map']);
    });

    _demandBounceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    )..addListener(() {
      if (_disposed || isClosed) return;
      final center = _demandPulseCenter;
      final color = _demandPulseColor;
      if (center == null || color == null) return;
      // Repaint rings while bounce is playing.
      demandCircles = _demandPulseRings(
        center: center,
        color: color,
        t: _demandPulseCtrl.value,
      );
      update(['map']);
    });

    // Inactivity / server auto-offline -> show a tappable banner so the driver
    // understands why their toggle flipped and can go back online.
    _autoOfflineWorker?.dispose();
    _autoOfflineWorker = ever<String>(statusController.autoOfflineReason, (
      reason,
    ) {
      if (_disposed || isClosed) return;
      if (reason == 'inactivity-auto-offline') _showInactivityOfflineBanner();
    });

    _prepare();
  }

  void _showInactivityOfflineBanner() {
    if (Get.context == null) return;
    if (Get.isSnackbarOpen) return;
    Get.snackbar(
      'You went offline',
      'You were set offline due to inactivity.',
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(12),
      borderRadius: 12,
      backgroundColor: Colors.black.withValues(alpha: 0.88),
      colorText: Colors.white,
      duration: const Duration(seconds: 6),
      mainButton: TextButton(
        onPressed: () {
          Get.closeCurrentSnackbar();
          if (!statusController.isOnline.value &&
              !statusController.isToggleLoading.value) {
            toggleOnline();
          }
        },
        child: const Text(
          'Go back online',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  /// Restores core socket listeners (especially `booking-request`) after other
  /// screens temporarily attach their own listeners.
  void ensureCoreSocketListeners() {
    if (_disposed || isClosed) return;
    _bindSocketListeners();
    final did = driverId?.trim() ?? '';
    if (did.isNotEmpty) {
      socketService.registerDriver(did, bookingId: currentBookingId);
    }
  }

  Future<void> _prepare() async {
    try {
      // Keep marker icon synced with service type (Car/Bike), even if status arrives later.
      _listenServiceType();

      await statusController.getDriverStatus();
      if (_disposed || isClosed) return;

      // ✅ Preload map style BEFORE first paint to avoid "color jumps" on first zoom.
      await loadMapStyle();
      if (_disposed || isClosed) return;

      await loadCustomCarIcon();
      if (_disposed || isClosed) return;

      await loadDemandPinIcon();
      if (_disposed || isClosed) return;

      ready.value = true;

      SchedulerBinding.instance.addPostFrameCallback((_) async {
        if (_disposed || isClosed) return;
        statusController.weeklyChallenges();
        statusController.todayActivity();
        statusController.todayPackageActivity();
        unawaited(fetchDemandOpportunities(silent: true));
      });

      _listenSharedToggle();
      await initSocketAndLocation();
      await checkAndResumeActiveBooking();
      await restorePendingBookingRequestFromNotification();

      // DUAL-CONNECT: reconcile backend binding on launch. If there is no active
      // ride, release any stale binding (e.g. left over from a completed single
      // ride) so the idle backend reverts to the preference and the secondary
      // single-ride dispatch socket comes up. If a ride WAS resumed, resolve/
      // resumeActiveBooking already bound the correct backend.
      if (activeBookingData.value == null) {
        await onActiveRideEnded();
      } else {
        syncSecondaryDispatchSocket();
      }
    } catch (e) {
      CommonLogger.log.e("prepare error: $e");
      ready.value = true;
    }
  }

  @override
  void onClose() {
    // âœ… FIRST: block any future callbacks
    _disposed = true;

    // Unbind socket listeners (avoid retaining this controller via closures).
    socketService.off('connect');
    socketService.off('registered');
    socketService.off('booking-request');
    socketService.off('driver-cancelled');
    socketService.off('customer-cancelled');
    socketService.off('driver:demand-opportunity');
    socketService.off('driver:demand-opportunities');

    // DUAL-CONNECT: drop the secondary single-ride dispatch socket.
    SecondaryDispatchSocket().stop();

    _sharedToggleWorker?.dispose();
    _serviceTypeWorker?.dispose();
    _autoOfflineWorker?.dispose();

    countdownTimer?.cancel();
    emitTimer?.cancel();
    heartbeatTimer?.cancel();
    cameraFollowTimer?.cancel();

    locationSub?.cancel();

    try {
      mapController?.dispose();
    } catch (_) {}
    mapController = null;

    // âœ… stop animation safely
    try {
      if (animCtrl.isAnimating) animCtrl.stop();
    } catch (_) {}
    try {
      animCtrl.dispose();
    } catch (_) {}

    try {
      if (_demandPulseCtrl.isAnimating) _demandPulseCtrl.stop();
    } catch (_) {}
    try {
      _demandPulseCtrl.dispose();
    } catch (_) {}

    try {
      if (_demandBounceCtrl.isAnimating) _demandBounceCtrl.stop();
    } catch (_) {}
    try {
      _demandBounceCtrl.dispose();
    } catch (_) {}

    rideMap.dispose();

    super.onClose();
  }
}
