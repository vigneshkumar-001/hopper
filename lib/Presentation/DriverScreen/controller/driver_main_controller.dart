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
import 'package:hopper/Core/Utility/images.dart';
import 'package:hopper/Core/Utility/snackbar.dart';
import 'package:hopper/utils/sharedprefsHelper/sharedprefs_handler.dart';
import 'package:hopper/utils/sharedprefsHelper/local_data_store.dart';
import 'package:hopper/utils/sharedprefsHelper/booking_local_data.dart';
import 'package:hopper/utils/websocket/socket_io_client.dart';
import 'package:hopper/api/dataSource/apiDataSource.dart';
import '../../../api/repository/api_config_controller.dart';
import 'package:hopper/utils/map/navigation_assist.dart';
import 'package:hopper/utils/map/map_motion_profile.dart';
import 'package:hopper/utils/map/app_map_style.dart';
import 'package:hopper/utils/map/vehicle_marker_icon.dart';
import 'package:hopper/utils/location/location_permission_guard.dart';
import 'package:hopper/utils/ride_map/marker_icon_cache.dart';
import 'package:hopper/utils/ride_map/ride_map_controller.dart';
import 'package:hopper/Presentation/DriverScreen/screens/background_service.dart'
    as bg;
import 'package:permission_handler/permission_handler.dart';

import 'package:hopper/Presentation/DriverScreen/controller/driver_status_controller.dart';
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
  StreamSubscription<Position>? locationSub;
  Timer? emitTimer;
  Timer? heartbeatTimer;
  Map<String, dynamic>? latestLocationPayload;
  String? _lastSentLocationTimestamp;
  DateTime? _lastMovedAt;
  DateTime? _lastUpdateLocationEmitAt;
  DateTime? _lastHeartbeatEmitAt;
  DateTime _lastHomeRefreshAt = DateTime.fromMillisecondsSinceEpoch(0);
  int _emitLoopToken = 0;

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
  Worker? _sharedToggleWorker;
  Worker? _serviceTypeWorker;
  final ApiDataSource _apiDataSource = ApiDataSource();

  // âœ… IMPORTANT: prevent callbacks after dispose
  bool _disposed = false;
  bool _checkingActiveBooking = false;
  DateTime? _lastActiveBookingCheckAt;
  String? _lastResumedBookingId;
  String? _lastDismissedBookingId;
  bool _appInForeground = true;

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

  // ---------------- countdown ----------------
  void startCountdown() {
    countdownTimer?.cancel();
    remainingSeconds.value = BookingRequestController.requestPopupSeconds;

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
        (payload['message'] ?? 'Your trip has been cancelled.').toString();
    _showCancellationDialog(
      title: cancelledBy == 'customer' ? 'Trip Cancelled' : 'Trip Cancelled',
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
    socketService.clearBookingContext(bookingId: bookingId);

    currentBookingId = null;
    _lastResumedBookingId = null;
    activeBookingData.value = null;
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

  // ---------------- location emit loop ----------------
  Future<void> startEmitLoop() async {
    final int token = ++_emitLoopToken;
    await locationSub?.cancel();
    emitTimer?.cancel();
    heartbeatTimer?.cancel();

    if (_disposed || isClosed) return;
    if (token != _emitLoopToken) return;

    locationSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 8,
      ),
    ).listen((pos) {
      if (_disposed || isClosed) return;
      if (token != _emitLoopToken) return;

      final now = DateTime.now();
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
      if (prev != null) {
        final movedMeters = Geolocator.distanceBetween(
          prev.latitude,
          prev.longitude,
          current.latitude,
          current.longitude,
        );

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

      final bookingIdForPayload = _resolveBookingIdForLocationPayload();
      latestLocationPayload = {
        'userId': driverId,
        'latitude': current.latitude,
        'longitude': current.longitude,
        if (bookingIdForPayload != null) 'bookingId': bookingIdForPayload,
        'timestamp': now.toIso8601String(),
      };

      updateCarMarker(
        current,
        speedMs: speedMs.isFinite ? speedMs : null,
        headingDeg: pos.heading.isFinite ? pos.heading : null,
        accuracyM: accuracyM.isFinite ? accuracyM : null,
        timestamp: pos.timestamp,
      );
    });

    if (_disposed || isClosed) return;
    if (token != _emitLoopToken) return;

    final localEmitTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (_disposed || isClosed) return;
      if (token != _emitLoopToken) return;
      if (!statusController.isOnline.value) return;
      final payload = latestLocationPayload;
      if (payload == null) return;

      // Moving => `updateLocation` (only when we have a *new* fix)
      final ts = payload['timestamp']?.toString();
      if (ts == null || ts.isEmpty) return;
      if (ts == _lastSentLocationTimestamp) return;

      final movedAt = _lastMovedAt;
      final idleFor =
          movedAt == null
              ? const Duration(days: 9999)
              : DateTime.now().difference(movedAt);
      if (idleFor >= const Duration(seconds: 20)) {
        return;
      }

      _lastSentLocationTimestamp = ts;
      _lastUpdateLocationEmitAt = DateTime.now();
      socketService.emit('updateLocation', payload);
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
      final pos = lastPosition;
      final hb = <String, dynamic>{
        'userId': did,
        if (bookingIdForPayload != null) 'bookingId': bookingIdForPayload,
        if (pos != null) 'latitude': pos.latitude,
        if (pos != null) 'longitude': pos.longitude,
        'timestamp': now.toIso8601String(),
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
  void _bindSocketListeners() {
    socketService.off('connect');
    socketService.off('registered');
    socketService.off('booking-request');
    socketService.off('driver-cancelled');
    socketService.off('customer-cancelled');
    socketService.off('driver:demand-opportunity');
    socketService.off('driver:demand-opportunities');

    socketService.on('connect', (_) {
      if (_disposed || isClosed) return;
      socketService.registerDriver(
        driverId ?? '',
        bookingId: currentBookingId,
        ack: (resp) {
          if (kDebugMode) CommonLogger.log.i("register ack: $resp");
        },
      );
    });

    socketService.on('registered', (_) async {
      if (_disposed || isClosed) return;
      await startEmitLoop();
      requestDemandOpportunities(reason: 'socket_registered');
    });

    socketService.on('driver-cancelled', (data) async {
      await handleDriverCancelled(data);
    });

    socketService.on('customer-cancelled', (data) async {
      await handleCustomerCancelled(data);
    });

    socketService.on('booking-request', (data) async {
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

        final pickupAddr = await getAddressFromLatLng(fromLat, fromLng);
        final dropAddr = await getAddressFromLatLng(toLat, toLng);

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

      final pickupAddr = await getAddressFromLatLng(pickupLat, pickupLng);
      final dropAddr = await getAddressFromLatLng(dropLat, dropLng);

      if (_disposed || isClosed) return;

      bookingController.showRequest(
        rawData: payload,
        pickupAddress: pickupAddr,
        dropAddress: dropAddr,
      );
      startCountdown();
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

      // Reset so stale riders from previous sessions don't block UI on resume.
      sharedRide.riders.clear();
      sharedRide.activeTarget.value = null;

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
          socketService.clearAllBookingRooms();
          return;
        }
        final data = response.data;
        if (data == null) {
          activeBookingData.value = null;
          showActiveBookingCard.value = false;
          socketService.clearAllBookingRooms();
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
          socketService.clearAllBookingRooms();
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

        // Keep service type in sync so map marker icon (car/bike) matches resumed booking.
        statusController.setServiceTypeFrom(data['rideType']);
        JoinedBookingData().setData(Map<String, dynamic>.from(normalized));
        unawaited(_seedSharedRideFromActiveBooking(normalized));

        if (_lastDismissedBookingId == keyId) {
          showActiveBookingCard.value = false;
        } else {
          showActiveBookingCard.value = true;
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

  Future<void> resumeActiveBooking() async {
    if (_disposed || isClosed) return;
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
      }
    }

    await initLocation();
    startCameraFollow();

    // NOTE: Don’t start BG tracking while the app is foregrounded.
    // Running BG socket + foreground socket together causes `io server disconnect`
    // on servers that enforce a single active session per driverId.
  }

  Future<void> onAppPaused() async {
    if (_disposed || isClosed) return;
    _appInForeground = false;

    // Hand off to background service ONLY when online.
    var bgRunning = false;
    if (statusController.isOnline.value) {
      driverId ??= await SharedPrefHelper.getDriverId();
      final did = driverId?.trim() ?? '';
      if (did.isNotEmpty) {
        try {
          await bg.ensureDriverTrackingServiceRunning(
            driverId: did,
            bookingId: _resolveBookingIdForLocationPayload(),
          );
        } catch (_) {}
        bgRunning = await bg.isDriverTrackingServiceRunning();
      }
    }

    // If BG service cannot run (most commonly notifications disabled / OEM blocks),
    // do NOT disconnect the foreground socket; otherwise customers will lose the
    // driver marker immediately when the app is minimized.
    if (statusController.isOnline.value && !bgRunning) {
      if (kDebugMode) {
        CommonLogger.log.w(
          '[BG_HANDOFF] BG service not running; keeping foreground socket active',
        );
      }
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
      }

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
    } catch (e) {
      statusController.toggleStatus();
      CommonLogger.log.e("toggle online error: $e");
    } finally {
      statusController.isToggleLoading.value = false;
    }
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

    _prepare();
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

    _sharedToggleWorker?.dispose();
    _serviceTypeWorker?.dispose();

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
