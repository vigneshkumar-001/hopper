import 'dart:async';
import 'dart:io';
import 'dart:math';

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
import 'package:hopper/utils/location/location_permission_guard.dart';
import 'package:hopper/Presentation/DriverScreen/screens/background_service.dart'
    as bg;
import 'package:permission_handler/permission_handler.dart';

import 'package:hopper/Presentation/DriverScreen/controller/driver_status_controller.dart';
import 'package:hopper/Presentation/DriverScreen/models/driver_active_booking_response.dart';
import 'package:hopper/Presentation/DriverScreen/screens/SharedBooking/Screens/picking_shared_screens.dart';
import 'package:hopper/Presentation/DriverScreen/screens/SharedBooking/Screens/share_ride_start_screen.dart';
import 'package:hopper/Presentation/DriverScreen/screens/picking_customer_screen.dart';
import 'package:hopper/Presentation/DriverScreen/screens/ride_stats_screen.dart';
import 'package:hopper/Presentation/DriverScreen/screens/verify_rider_screen.dart';
import '../screens/SharedBooking/Controller/booking_request_controller.dart';

class DriverMainController extends GetxController
    with GetSingleTickerProviderStateMixin {
  // --- motion thresholds to tame jitter ---
  static const double _MAX_ACCURACY_M = 25.0; // ignore noisy GPS fixes
  static const double _STATIONARY_JUMP_M = 30.0; // ignore big jumps when idle
  static const double _JUMP_ACCEPT_ACCURACY_M = 12.0; // allow big move if very accurate

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

  // Marker
  BitmapDescriptor? carIcon;
  Marker? carMarker;
  LatLng? lastPosition;

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
  Map<String, dynamic>? latestLocationPayload;

  String? driverId;
  String? currentBookingId;

  // Countdown for request
  Timer? countdownTimer;
  final RxInt remainingSeconds = 15.obs;

  // Screen ready
  final RxBool ready = false.obs;

  // Follow mode
  final RxBool followDriver = true.obs;
  Timer? cameraFollowTimer;
  double _followZoom = 16.6;
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

  final Rxn<Map<String, dynamic>> activeBookingData = Rxn<Map<String, dynamic>>();
  final RxBool showActiveBookingCard = false.obs;

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
  Future<void> loadMapStyle(BuildContext context) async {
    try {
      final style = await AppMapStyle.loadUberLight();
      mapStyle = style;
      if (mapController != null) {
        await mapController!.setMapStyle(style);
      }
    } catch (e) {
      if (kDebugMode) CommonLogger.log.w("Map style load failed: $e");
    }
  }

  // ---------------- icon ----------------
  Future<void> loadCustomCarIcon() async {
    try {
      const cfg = ImageConfiguration(size: Size(36, 36));
      final asset =
          statusController.isCar ? AppImages.movingCar : AppImages.parcelBike;

      // Bike marker should be a bit smaller than car (but still readable).
      final markerHeight = statusController.isCar ? 36.0 : 36.0;
      carIcon = await BitmapDescriptor.asset(
        height: markerHeight,
        cfg,
        asset,
      );
    } catch (e) {
      if (kDebugMode) CommonLogger.log.w("Car icon load failed: $e");
      carIcon = BitmapDescriptor.defaultMarker;
    }
  }

  // ---------------- marker update (animated) ----------------
  void updateCarMarker(LatLng newPos) {
    // âœ… stop any callbacks after close
    if (_disposed || isClosed) return;
    if (carIcon == null) return;

    if (lastPosition == null || carMarker == null) {
      carMarker = Marker(
        markerId: const MarkerId('car'),
        position: newPos,
        icon: carIcon!,
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

    updateCarMarker(latLng);

    await mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: latLng, zoom: _followZoom, tilt: 35),
      ),
    );
  }

  Future<void> goToCurrentLocation() async {
    final pos = await getCurrentPos();
    if (_disposed || isClosed) return;
    if (pos == null) return;

    final latLng = LatLng(pos.latitude, pos.longitude);
    await mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: latLng, zoom: _followZoom, tilt: 35),
      ),
    );

    updateCarMarker(latLng);
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
            tilt: 35,
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

    final lat2 = asin(
      sin(lat1) * cos(d) + cos(lat1) * sin(d) * cos(b),
    );
    final lng2 =
        lng1 +
        atan2(
          sin(b) * sin(d) * cos(lat1),
          cos(d) - sin(lat1) * sin(lat2),
        );

    return LatLng(lat2 * 180.0 / pi, lng2 * 180.0 / pi);
  }

  String? _normalizeBookingId(dynamic raw) {
    final v = (raw ?? '').toString().trim();
    if (v.isEmpty) return null;
    if (v.toLowerCase() == 'null') return null;
    return v;
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
    await locationSub?.cancel();
    emitTimer?.cancel();

    if (_disposed || isClosed) return;

    locationSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 8,
      ),
    ).listen((pos) {
      if (_disposed || isClosed) return;

      final speedMs = (pos.speed.isFinite && pos.speed >= 0) ? pos.speed : 0.0;
      final accuracyM = (pos.accuracy.isFinite) ? pos.accuracy : 9999.0;
      final targetZoom = MapMotionProfile.targetZoomFromSpeed(speedMs);
      _followZoom = MapMotionProfile.smoothZoom(
        _followZoom,
        targetZoom.clamp(15.2, 17.8),
      ).clamp(15.2, 17.8);

      // 1) ignore very inaccurate fixes
      if (accuracyM > _MAX_ACCURACY_M) return;

      final current = LatLng(pos.latitude, pos.longitude);

      // 2) freeze drift/jumps when almost stationary
      final prev = lastPosition;
      if (prev != null) {
        final movedMeters = Geolocator.distanceBetween(
          prev.latitude,
          prev.longitude,
          current.latitude,
          current.longitude,
        );

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
      };

      updateCarMarker(current);
    });

    emitTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (_disposed || isClosed) return;
      if (!statusController.isOnline.value) return;
      final payload = latestLocationPayload;
      if (payload == null) return;

      socketService.emit('updateLocation', payload);
      Get.find<DriverAnalyticsController>().trackOnlineTick(
        const Duration(seconds: 7),
      );
       // Reference log is centralized in `SocketService.emit()` for `updateLocation`.
    });
  }

  // ---------------- socket init + listeners ----------------
  void _bindSocketListeners() {
    socketService.off('connect');
    socketService.off('registered');
    // socketService.off('booking-request');

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
    });

    socketService.on('booking-request', (data) async {
      if (_disposed || isClosed) return;
      if (data == null) return;

      BookingDataService().setBookingData(data);

      if (data['type'] == 'active-bookings') {
        final List active = data['activeBookings'] ?? [];
        if (active.isEmpty) return;

        final booking = active.first;
        currentBookingId = booking['bookingId']?.toString();

        if (statusController.isOnline.value) {
          unawaited(
            bg.ensureDriverTrackingServiceRunning(
              driverId: driverId,
              bookingId: _normalizeBookingId(currentBookingId),
            ),
          );
        }

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

      currentBookingId = data['bookingId']?.toString();

      if (statusController.isOnline.value) {
        unawaited(
          bg.ensureDriverTrackingServiceRunning(
            driverId: driverId,
            bookingId: _normalizeBookingId(currentBookingId),
          ),
        );
      }

      final pickup = data['pickupLocation'];
      final drop = data['dropLocation'];
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
        rawData: data,
        pickupAddress: pickupAddr,
        dropAddress: dropAddr,
      );
      startCountdown();
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
      if (lat is num && lng is num) return LatLng(lat.toDouble(), lng.toDouble());
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

  Future<void> checkAndResumeActiveBooking({bool force = false}) async {
    if (_disposed || isClosed) return;
    if (_checkingActiveBooking) return;

    final now = DateTime.now();
    final last = _lastActiveBookingCheckAt;
    if (!force && last != null && now.difference(last) < const Duration(seconds: 8)) {
      return;
    }
    _lastActiveBookingCheckAt = now;

    _checkingActiveBooking = true;
    try {
      final result = await _apiDataSource.getDriverActiveBooking();
      if (_disposed || isClosed) return;

      await result.fold(
        (_) async {},
        (DriverActiveBookingResponse response) async {
          if (!response.hasBooking) {
            activeBookingData.value = null;
            _lastDismissedBookingId = null;
            showActiveBookingCard.value = false;
            return;
          }
          final data = response.data;
          if (data == null) {
            activeBookingData.value = null;
            showActiveBookingCard.value = false;
            return;
          }

          final bookingId = (data['bookingId'] ?? '').toString().trim();
          if (bookingId.isEmpty) return;
          currentBookingId = bookingId;

          final did = driverId;
          if (did != null && did.trim().isNotEmpty) {
            socketService.registerDriver(did, bookingId: bookingId);
            socketService.joinBooking(bookingId, userId: did);
          }

          final status = (data['status'] ?? '').toString();
          final cancelled =
              _asBool(data['cancelled']) || _statusHas(status, ['cancel']);
          final completed =
              _asBool(data['destinationReached']) ||
              _statusHas(status, ['complete', 'completed', 'finished']);
          if (cancelled || completed) {
            activeBookingData.value = null;
            _lastDismissedBookingId = null;
            showActiveBookingCard.value = false;
            return;
          }

          activeBookingData.value = Map<String, dynamic>.from(data);

          // Keep service type in sync so map marker icon (car/bike) matches resumed booking.
          statusController.setServiceTypeFrom(data['rideType']);
          JoinedBookingData().setData(Map<String, dynamic>.from(data));

          if (_lastDismissedBookingId == bookingId) {
            showActiveBookingCard.value = false;
          } else {
            showActiveBookingCard.value = true;
          }
        },
      );
    } finally {
      _checkingActiveBooking = false;
    }
  }

  void dismissActiveBookingCard() {
    final id = activeBookingData.value?['bookingId']?.toString();
    if (id != null && id.trim().isNotEmpty) {
      _lastDismissedBookingId = id;
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
      if (lat is num && lng is num) return LatLng(lat.toDouble(), lng.toDouble());
      final latD = double.tryParse(lat?.toString() ?? '');
      final lngD = double.tryParse(lng?.toString() ?? '');
      if (latD != null && lngD != null) return LatLng(latD, lngD);
    }
    final driverLoc = data['driverLocation'];
    if (driverLoc is Map) {
      final lat = driverLoc['latitude'];
      final lng = driverLoc['longitude'];
      if (lat is num && lng is num) return LatLng(lat.toDouble(), lng.toDouble());
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
    if (_lastResumedBookingId == bookingId) return;

    final status = (data['status'] ?? '').toString();
    final cancelled =
        _asBool(data['cancelled']) || _statusHas(status, ['cancel']);
    final completed =
        _asBool(data['destinationReached']) ||
        _statusHas(status, ['complete', 'completed', 'finished']);
    if (cancelled || completed) return;

    final live = data['driverLiveTracking'];
    final isShared =
        _asBool(data['sharedBooking']) ||
        _asBool(data['isShared']) ||
        _asBool(data['shared']) ||
        (live is Map && _asBool(live['sharedBooking']));

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
        (data['dropAddress'] ?? data['dropLocationAddress'] ?? '')
            .toString();

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
      currentBookingId = bookingId;
      socketService.registerDriver(did, bookingId: bookingId);
      socketService.joinBooking(bookingId, userId: did);
    }

    _lastResumedBookingId = bookingId;
    showActiveBookingCard.value = false;

    await Future<void>.delayed(const Duration(milliseconds: 120));
    if (_disposed || isClosed) return;

    if (isShared) {
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

    await initLocation();
    startCameraFollow();
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

      final pos = lastPosition ?? currentPosition.value;
      if (pos != null) updateCarMarker(pos);
    });
  }

  // ---------------- toggle online ----------------
  Future<void> toggleOnline() async {
    if (_disposed || isClosed) return;
    if (statusController.isLoading.value) return;

    HapticFeedback.lightImpact();
    statusController.isLoading.value = true;

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
        unawaited(
          bg.ensureDriverTrackingServiceRunning(
            driverId: driverId,
            bookingId: _resolveBookingIdForLocationPayload(),
          ),
        );
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
      statusController.isLoading.value = false;
    }
  }

  Future<bool> _ensureNotificationPermissionForFgs() async {
    if (!Platform.isAndroid) return true;

    try {
      final android =
          FlutterLocalNotificationsPlugin()
              .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin>();
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

    _prepare();
  }

  Future<void> _prepare() async {
    try {
      // Keep marker icon synced with service type (Car/Bike), even if status arrives later.
      _listenServiceType();

      await statusController.getDriverStatus();
      if (_disposed || isClosed) return;

      await loadCustomCarIcon();
      if (_disposed || isClosed) return;

      ready.value = true;

      SchedulerBinding.instance.addPostFrameCallback((_) async {
        if (_disposed || isClosed) return;
        final ctx = Get.context;
        if (ctx != null) await loadMapStyle(ctx);

        statusController.weeklyChallenges();
        statusController.todayActivity();
        statusController.todayPackageActivity();
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

    _sharedToggleWorker?.dispose();
    _serviceTypeWorker?.dispose();

    countdownTimer?.cancel();
    emitTimer?.cancel();
    cameraFollowTimer?.cancel();

    locationSub?.cancel();

    // âœ… stop animation safely
    try {
      if (animCtrl.isAnimating) animCtrl.stop();
    } catch (_) {}
    try {
      animCtrl.dispose();
    } catch (_) {}

    super.onClose();
  }
}


