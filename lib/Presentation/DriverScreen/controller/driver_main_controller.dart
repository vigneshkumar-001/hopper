import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:hopper/Core/Constants/log.dart';
import 'package:hopper/Core/Utility/images.dart';
import 'package:hopper/utils/sharedprefsHelper/sharedprefs_handler.dart';
import 'package:hopper/utils/sharedprefsHelper/booking_local_data.dart';
import 'package:hopper/utils/websocket/socket_io_client.dart';
import '../../../api/repository/api_config_controller.dart';
import 'package:hopper/utils/map/navigation_assist.dart';
import 'package:hopper/utils/map/map_motion_profile.dart';
import 'package:hopper/utils/map/app_map_style.dart';

import 'package:hopper/Presentation/DriverScreen/controller/driver_status_controller.dart';
import '../screens/SharedBooking/Controller/booking_request_controller.dart';

class DriverMainController extends GetxController
    with GetSingleTickerProviderStateMixin {
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
  double _followZoom = 15.7;

  // Config
  final ApiConfigController cfg = Get.find<ApiConfigController>();
  Worker? _sharedToggleWorker;

  // ✅ IMPORTANT: prevent callbacks after dispose
  bool _disposed = false;

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
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      Get.snackbar("Location Disabled", "Please enable location services.");
      return false;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) return false;
    if (permission == LocationPermission.deniedForever) {
      await Geolocator.openAppSettings();
      return false;
    }

    return true;
  }

  Future<Position?> getCurrentPos() async {
    final ok = await ensureLocationPermission();
    if (!ok) return null;
    return Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
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
      if (statusController.serviceType.value == "Car") {
        carIcon = await BitmapDescriptor.asset(
          const ImageConfiguration(size: Size(57, 57)),
          AppImages.movingCar,
        );
      } else {
        carIcon = await BitmapDescriptor.asset(
          const ImageConfiguration(size: Size(57, 57)),
          AppImages.parcelBike,
        );
      }
    } catch (e) {
      if (kDebugMode) CommonLogger.log.w("Car icon load failed: $e");
      carIcon = BitmapDescriptor.defaultMarker;
    }
  }

  // ---------------- marker update (animated) ----------------
  void updateCarMarker(LatLng newPos) {
    // ✅ stop any callbacks after close
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

    // ✅ guard animCtrl usage
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
    remainingSeconds.value = 15;

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

    cameraFollowTimer = Timer.periodic(const Duration(milliseconds: 900), (_) {
      if (_disposed || isClosed) return;
      if (!followDriver.value) return;
      if (lastPosition == null) return;
      if (mapController == null) return;

      final bearing = carMarker?.rotation ?? 0;
      mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: lastPosition!,
            zoom: _followZoom,
            tilt: 40,
            bearing: bearing,
          ),
        ),
      );
    });
  }

  // ---------------- location emit loop ----------------
  Future<void> startEmitLoop() async {
    await locationSub?.cancel();
    emitTimer?.cancel();

    if (_disposed || isClosed) return;

    locationSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 8,
      ),
    ).listen((pos) {
      if (_disposed || isClosed) return;

      final speedMs = (pos.speed.isFinite && pos.speed >= 0) ? pos.speed : 0.0;
      final targetZoom = MapMotionProfile.targetZoomFromSpeed(speedMs);
      _followZoom = MapMotionProfile.smoothZoom(_followZoom, targetZoom);

      latestLocationPayload = {
        'userId': driverId,
        'latitude': pos.latitude,
        'longitude': pos.longitude,
        if (currentBookingId != null) 'bookingId': currentBookingId,
      };

      updateCarMarker(LatLng(pos.latitude, pos.longitude));
    });

    emitTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (_disposed || isClosed) return;
      if (!statusController.isOnline.value) return;
      final payload = latestLocationPayload;
      if (payload == null) return;

      socketService.emit('updateLocation', payload);
      Get.find<DriverAnalyticsController>().trackOnlineTick(
        const Duration(seconds: 10),
      );
      CommonLogger.log.i('updateLocation :$payload');
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

  Future<void> initSocketAndLocation() async {
    driverId = await SharedPrefHelper.getDriverId();
    if (_disposed || isClosed) return;
    if (driverId == null) return;

    socketService.initSocket(cfg.socketUrl);
    _bindSocketListeners();

    await initLocation();
    startCameraFollow();
  }

  // ---------------- ✅ listen shared toggle ----------------
  void _listenSharedToggle() {
    _sharedToggleWorker?.dispose();

    _sharedToggleWorker = ever<bool>(cfg.isSharedEnabled, (enabled) async {
      if (_disposed || isClosed) return;

      try {
        final newUrl = cfg.socketUrl;
        CommonLogger.log.i(
          "🔁 Shared changed => $enabled | switch socket => $newUrl",
        );

        socketService.switchUrl(newUrl);
        _bindSocketListeners();

        socketService.registerDriver(
          driverId ?? '',
          bookingId: currentBookingId,
        );

        await startEmitLoop();
      } catch (e) {
        CommonLogger.log.e("❌ socket switch failed: $e");
      }
    });
  }

  // ---------------- toggle online ----------------
  Future<void> toggleOnline() async {
    if (_disposed || isClosed) return;
    if (statusController.isLoading.value) return;

    HapticFeedback.lightImpact();
    statusController.isLoading.value = true;

    try {
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
    } catch (e) {
      CommonLogger.log.e("prepare error: $e");
      ready.value = true;
    }
  }

  @override
  void onClose() {
    // ✅ FIRST: block any future callbacks
    _disposed = true;

    _sharedToggleWorker?.dispose();

    countdownTimer?.cancel();
    emitTimer?.cancel();
    cameraFollowTimer?.cancel();

    locationSub?.cancel();

    // ✅ stop animation safely
    try {
      if (animCtrl.isAnimating) animCtrl.stop();
    } catch (_) {}
    try {
      animCtrl.dispose();
    } catch (_) {}

    super.onClose();
  }
}

// import 'dart:async';
// import 'dart:math';
// import 'package:flutter/foundation.dart';
// import 'package:flutter/gestures.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter/scheduler.dart';
// import 'package:geocoding/geocoding.dart';
// import 'package:geolocator/geolocator.dart';
// import 'package:get/get.dart';
// import 'package:google_maps_flutter/google_maps_flutter.dart';
//
// import 'package:hopper/Core/Constants/log.dart';
// import 'package:hopper/Core/Utility/images.dart';
// import 'package:hopper/utils/sharedprefsHelper/sharedprefs_handler.dart';
// import 'package:hopper/utils/sharedprefsHelper/booking_local_data.dart';
// import 'package:hopper/utils/websocket/socket_io_client.dart';
// import '../../../api/repository/api_config_controller.dart';
//
// import 'package:hopper/Presentation/DriverScreen/controller/driver_status_controller.dart';
// import '../screens/SharedBooking/Controller/booking_request_controller.dart';
//
// class DriverMainController extends GetxController
//     with GetSingleTickerProviderStateMixin {
//   // External controllers
//   final BookingRequestController bookingController =
//   Get.find<BookingRequestController>();
//
//   final DriverStatusController statusController = Get.put(
//     DriverStatusController(),
//   );
//
//   // Map
//   GoogleMapController? mapController;
//   String? mapStyle;
//   final Rxn<LatLng> currentPosition = Rxn<LatLng>();
//
//   // Marker
//   BitmapDescriptor? carIcon;
//   Marker? carMarker;
//   LatLng? lastPosition;
//
//   // Animation
//   late final AnimationController animCtrl;
//   late final Animation<double> anim;
//   Tween<double>? latTween;
//   Tween<double>? lngTween;
//   Tween<double>? rotTween;
//
//   // Socket + location
//   final SocketService socketService = SocketService(); // ✅ singleton
//   StreamSubscription<Position>? locationSub;
//   Timer? emitTimer;
//   Map<String, dynamic>? latestLocationPayload;
//
//   String? driverId;
//   String? currentBookingId;
//
//   // Countdown for request
//   Timer? countdownTimer;
//   final RxInt remainingSeconds = 15.obs;
//
//   // Screen ready
//   final RxBool ready = false.obs;
//
//   // Follow mode
//   final RxBool followDriver = true.obs;
//   Timer? cameraFollowTimer;
//   double _followZoom = 15.7;
//
//   // Config
//   final ApiConfigController cfg = Get.find<ApiConfigController>();
//
//   Worker? _sharedToggleWorker;
//
//   // ---------------- helpers ----------------
//   double safeToDouble(dynamic value) {
//     if (value is double) return value;
//     if (value is int) return value.toDouble();
//     return double.tryParse(value.toString()) ?? 0.0;
//   }
//
//   int safeToInt(dynamic value) {
//     if (value is int) return value;
//     if (value is double) return value.round();
//     return int.tryParse(value.toString()) ?? 0;
//   }
//
//   String formatDistance(double meters) {
//     final km = meters / 1000;
//     return '${km.toStringAsFixed(1)} Km';
//   }
//
//   String formatDuration(int minutes) {
//     final hours = minutes ~/ 60;
//     final rem = minutes % 60;
//     return hours > 0 ? '$hours hr $rem min' : '$rem min';
//   }
//
//   double bearingBetween(LatLng start, LatLng end) {
//     final lat1 = start.latitude * (pi / 180.0);
//     final lon1 = start.longitude * (pi / 180.0);
//     final lat2 = end.latitude * (pi / 180.0);
//     final lon2 = end.longitude * (pi / 180.0);
//
//     final dLon = lon2 - lon1;
//     final y = sin(dLon) * cos(lat2);
//     final x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon);
//
//     final brng = atan2(y, x);
//     return (brng * 180 / pi + 360) % 360;
//   }
//
//   bool movedEnough(LatLng a, LatLng b) {
//     final dx = (a.latitude - b.latitude).abs();
//     final dy = (a.longitude - b.longitude).abs();
//     return (dx + dy) > 0.00002; // ~2m threshold
//   }
//
//   // ---------------- permissions ----------------
//   Future<bool> ensureLocationPermission() async {
//     final serviceEnabled = await Geolocator.isLocationServiceEnabled();
//     if (!serviceEnabled) {
//       Get.snackbar("Location Disabled", "Please enable location services.");
//       return false;
//     }
//
//     var permission = await Geolocator.checkPermission();
//     if (permission == LocationPermission.denied) {
//       permission = await Geolocator.requestPermission();
//     }
//
//     if (permission == LocationPermission.denied) return false;
//     if (permission == LocationPermission.deniedForever) {
//       await Geolocator.openAppSettings();
//       return false;
//     }
//
//     return true;
//   }
//
//   Future<Position?> getCurrentPos() async {
//     final ok = await ensureLocationPermission();
//     if (!ok) return null;
//     return Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
//   }
//
//   // ---------------- map style ----------------
//   Future<void> loadMapStyle(BuildContext context) async {
//     try {
//       final style = await DefaultAssetBundle.of(context)
//           .loadString('assets/map_style/map_style.json');
//       mapStyle = style;
//       if (mapController != null) {
//         await mapController!.setMapStyle(style);
//       }
//     } catch (e) {
//       if (kDebugMode) CommonLogger.log.w("Map style load failed: $e");
//     }
//   }
//
//   // ---------------- icon ----------------
//   Future<void> loadCustomCarIcon() async {
//     try {
//       if (statusController.serviceType.value == "Car") {
//         carIcon = await BitmapDescriptor.asset(
//           const ImageConfiguration(size: Size(57, 57)),
//           AppImages.movingCar,
//         );
//       } else {
//         carIcon = await BitmapDescriptor.asset(
//           const ImageConfiguration(size: Size(57, 57)),
//           AppImages.parcelBike,
//         );
//       }
//     } catch (e) {
//       if (kDebugMode) CommonLogger.log.w("Car icon load failed: $e");
//       carIcon = BitmapDescriptor.defaultMarker;
//     }
//   }
//
//   // ---------------- marker update (animated) ----------------
//   void updateCarMarker(LatLng newPos) {
//     if (carIcon == null) return;
//
//     if (lastPosition == null || carMarker == null) {
//       carMarker = Marker(
//         markerId: const MarkerId('car'),
//         position: newPos,
//         icon: carIcon!,
//         rotation: 0,
//         anchor: const Offset(0.5, 0.5),
//         flat: true,
//       );
//       lastPosition = newPos;
//       update(['map']);
//       return;
//     }
//
//     if (!movedEnough(lastPosition!, newPos)) return;
//
//     final rawBearing = bearingBetween(lastPosition!, newPos);
//     final currentBearing = carMarker?.rotation ?? 0;
//     final bearing = MapMotionProfile.smoothBearing(current: currentBearing, target: rawBearing, speedMs: 4.0);
//
//     latTween = Tween(begin: lastPosition!.latitude, end: newPos.latitude);
//     lngTween = Tween(begin: lastPosition!.longitude, end: newPos.longitude);
//     rotTween = Tween(begin: carMarker!.rotation, end: bearing);
//
//     animCtrl
//       ..stop()
//       ..reset()
//       ..forward();
//
//     lastPosition = newPos;
//   }
//
//   // ---------------- init location ----------------
//   Future<void> initLocation() async {
//     final pos = await getCurrentPos();
//     if (pos == null) return;
//
//     final latLng = LatLng(pos.latitude, pos.longitude);
//     currentPosition.value = latLng;
//
//     updateCarMarker(latLng);
//
//     await mapController?.animateCamera(
//       CameraUpdate.newCameraPosition(
//         CameraPosition(target: latLng, zoom: _followZoom, tilt: 35),
//       ),
//     );
//   }
//
//   Future<void> goToCurrentLocation() async {
//     final pos = await getCurrentPos();
//     if (pos == null) return;
//
//     final latLng = LatLng(pos.latitude, pos.longitude);
//     await mapController?.animateCamera(
//       CameraUpdate.newCameraPosition(
//         CameraPosition(target: latLng, zoom: _followZoom, tilt: 35),
//       ),
//     );
//     updateCarMarker(latLng);
//   }
//
//   // ---------------- reverse geo ----------------
//   Future<String> getAddressFromLatLng(double lat, double lng) async {
//     try {
//       final placemarks = await placemarkFromCoordinates(lat, lng);
//       if (placemarks.isEmpty) return "Location not available";
//       final place = placemarks.first;
//       return "${place.name}, ${place.locality}, ${place.administrativeArea}";
//     } catch (_) {
//       return "Location not available";
//     }
//   }
//
//   // ---------------- countdown ----------------
//   void startCountdown() {
//     countdownTimer?.cancel();
//     remainingSeconds.value = 15;
//
//     countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
//       final v = remainingSeconds.value;
//       if (v > 0) {
//         remainingSeconds.value = v - 1;
//       } else {
//         t.cancel();
//         bookingController.clear();
//       }
//     });
//   }
//
//   // ---------------- camera follow ----------------
//   void startCameraFollow() {
//     cameraFollowTimer?.cancel();
//
//     cameraFollowTimer = Timer.periodic(const Duration(milliseconds: 900), (_) {
//       if (!followDriver.value) return;
//       if (lastPosition == null) return;
//       if (mapController == null) return;
//
//       final bearing = carMarker?.rotation ?? 0;
//       mapController!.animateCamera(
//         CameraUpdate.newCameraPosition(
//           CameraPosition(
//             target: lastPosition!,
//             zoom: _followZoom,
//             tilt: 40,
//             bearing: bearing,
//           ),
//         ),
//       );
//     });
//   }
//
//   // ---------------- location emit loop ----------------
//   Future<void> startEmitLoop() async {
//     await locationSub?.cancel();
//     emitTimer?.cancel();
//
//     locationSub = Geolocator.getPositionStream(
//       locationSettings: const LocationSettings(
//         accuracy: LocationAccuracy.high,
//         distanceFilter: 8,
//       ),
//     ).listen((pos) {
//       latestLocationPayload = {
//         'userId': driverId,
//         'latitude': pos.latitude,
//         'longitude': pos.longitude,
//         if (currentBookingId != null) 'bookingId': currentBookingId,
//       };
//
//       updateCarMarker(LatLng(pos.latitude, pos.longitude));
//     });
//
//     emitTimer = Timer.periodic(const Duration(seconds: 10), (_) {
//       if (!statusController.isOnline.value) return;
//       final payload = latestLocationPayload;
//
//       if (payload == null) return;
//       socketService.emit('updateLocation', payload);
//       CommonLogger.log.i('updateLocation :$payload');
//     });
//   }
//
//   // ---------------- socket init + listeners ----------------
//   void _bindSocketListeners() {
//     // ✅ avoid duplicates when switching url / reinit
//     socketService.off('connect');
//     socketService.off('registered');
//     socketService.off('booking-request');
//
//     socketService.on('connect', (_) {
//       socketService.registerDriver(
//         driverId ?? '',
//         bookingId: currentBookingId,
//         ack: (resp) {
//           if (kDebugMode) CommonLogger.log.i("register ack: $resp");
//         },
//       );
//     });
//
//     socketService.on('registered', (_) async {
//       await startEmitLoop();
//     });
//
//     socketService.on('booking-request', (data) async {
//       if (data == null) return;
//       BookingDataService().setBookingData(data);
//
//       // active-bookings (resume)
//       if (data['type'] == 'active-bookings') {
//         final List active = data['activeBookings'] ?? [];
//         if (active.isEmpty) return;
//
//         final booking = active.first;
//         currentBookingId = booking['bookingId']?.toString();
//
//         final fromLat = (booking['fromLatitude'] as num?)?.toDouble();
//         final fromLng = (booking['fromLongitude'] as num?)?.toDouble();
//         final toLat = (booking['toLatitude'] as num?)?.toDouble();
//         final toLng = (booking['toLongitude'] as num?)?.toDouble();
//
//         if (fromLat == null || fromLng == null || toLat == null || toLng == null) {
//           return;
//         }
//
//         final pickupAddr = await getAddressFromLatLng(fromLat, fromLng);
//         final dropAddr = await getAddressFromLatLng(toLat, toLng);
//
//         bookingController.showRequest(
//           rawData: booking,
//           pickupAddress: pickupAddr,
//           dropAddress: dropAddr,
//         );
//         startCountdown();
//         return;
//       }
//
//       // normal booking
//       currentBookingId = data['bookingId']?.toString();
//       final pickup = data['pickupLocation'];
//       final drop = data['dropLocation'];
//       if (pickup == null || drop == null) return;
//
//       final pickupLat = (pickup['latitude'] as num?)?.toDouble();
//       final pickupLng = (pickup['longitude'] as num?)?.toDouble();
//       final dropLat = (drop['latitude'] as num?)?.toDouble();
//       final dropLng = (drop['longitude'] as num?)?.toDouble();
//
//       if (pickupLat == null || pickupLng == null || dropLat == null || dropLng == null) {
//         return;
//       }
//
//       final pickupAddr = await getAddressFromLatLng(pickupLat, pickupLng);
//       final dropAddr = await getAddressFromLatLng(dropLat, dropLng);
//
//       bookingController.showRequest(
//         rawData: data,
//         pickupAddress: pickupAddr,
//         dropAddress: dropAddr,
//       );
//       startCountdown();
//     });
//   }
//
//   Future<void> initSocketAndLocation() async {
//     driverId = await SharedPrefHelper.getDriverId();
//     if (driverId == null) return;
//
//     // ✅ init socket based on current cfg
//     socketService.initSocket(cfg.socketUrl);
//
//     // ✅ bind listeners once (safe, will off+on)
//     _bindSocketListeners();
//
//     await initLocation();
//     startCameraFollow();
//   }
//
//   // ---------------- ✅ listen shared toggle ----------------
//   void _listenSharedToggle() {
//     _sharedToggleWorker?.dispose();
//
//     _sharedToggleWorker = ever<bool>(cfg.isSharedEnabled, (enabled) async {
//       try {
//         final newUrl = cfg.socketUrl;
//         CommonLogger.log.i("🔁 Shared changed => $enabled | switch socket => $newUrl");
//
//         // ✅ Switch socket URL (disconnect old + connect new)
//         socketService.switchUrl(newUrl);
//
//         // ✅ Rebind listeners (important)
//         _bindSocketListeners();
//
//         // ✅ Re-register driver after switching url
//         socketService.registerDriver(
//           driverId ?? '',
//           bookingId: currentBookingId,
//         );
//
//         // ✅ restart emit loop
//         await startEmitLoop();
//       } catch (e) {
//         CommonLogger.log.e("❌ socket switch failed: $e");
//       }
//     });
//   }
//
//   // ---------------- toggle online ----------------
//   Future<void> toggleOnline() async {
//     if (statusController.isLoading.value) return;
//     statusController.isLoading.value = true;
//
//     try {
//       statusController.toggleStatus();
//       final isOnline = statusController.isOnline.value;
//
//       double lat = lastPosition?.latitude ?? currentPosition.value?.latitude ?? 0.0;
//       double lng = lastPosition?.longitude ?? currentPosition.value?.longitude ?? 0.0;
//
//       if (isOnline && (lat == 0.0 || lng == 0.0)) {
//         final pos = await getCurrentPos();
//         if (pos == null) {
//           statusController.toggleStatus();
//           return;
//         }
//         lat = pos.latitude;
//         lng = pos.longitude;
//
//         final latLng = LatLng(lat, lng);
//         currentPosition.value = latLng;
//         updateCarMarker(latLng);
//       }
//
//       await statusController.onlineAcceptStatus(
//         Get.context!,
//         status: isOnline,
//         latitude: lat,
//         longitude: lng,
//       );
//
//       if (isOnline) {
//         followDriver.value = true;
//         await goToCurrentLocation();
//       }
//     } catch (e) {
//       statusController.toggleStatus();
//       CommonLogger.log.e("toggle online error: $e");
//     } finally {
//       statusController.isLoading.value = false;
//     }
//   }
//
//   // ---------------- lifecycle ----------------
//   @override
//   void onInit() {
//     super.onInit();
//
//     animCtrl = AnimationController(
//       vsync: this,
//       duration: const Duration(milliseconds: 650),
//     );
//
//     anim = CurvedAnimation(parent: animCtrl, curve: Curves.easeOutCubic)
//       ..addListener(() {
//         final lt = latTween;
//         final lg = lngTween;
//         final rt = rotTween;
//         if (lt == null || lg == null || rt == null) return;
//
//         final lat = lt.evaluate(anim);
//         final lng = lg.evaluate(anim);
//         final rot = rt.evaluate(anim);
//
//         final icon = carIcon ?? BitmapDescriptor.defaultMarker;
//         carMarker = Marker(
//           markerId: const MarkerId('car'),
//           position: LatLng(lat, lng),
//           icon: icon,
//           rotation: rot,
//           anchor: const Offset(0.5, 0.5),
//           flat: true,
//         );
//
//         update(['map']);
//       });
//
//     _prepare();
//   }
//
//   Future<void> _prepare() async {
//     try {
//       await statusController.getDriverStatus();
//       await loadCustomCarIcon();
//
//       ready.value = true;
//
//       SchedulerBinding.instance.addPostFrameCallback((_) async {
//         final ctx = Get.context;
//         if (ctx != null) await loadMapStyle(ctx);
//
//         statusController.weeklyChallenges();
//         statusController.todayActivity();
//         statusController.todayPackageActivity();
//       });
//
//       // ✅ listen shared toggle
//       _listenSharedToggle();
//
//       await initSocketAndLocation();
//     } catch (e) {
//       CommonLogger.log.e("prepare error: $e");
//       ready.value = true;
//     }
//   }
//
//   @override
//   void onClose() {
//     _sharedToggleWorker?.dispose();
//
//     countdownTimer?.cancel();
//     emitTimer?.cancel();
//     cameraFollowTimer?.cancel();
//     locationSub?.cancel();
//     animCtrl.dispose();
//
//     // ⚠️ Do NOT dispose socket here if app uses socket elsewhere globally.
//     // If only this screen uses socket, then you can dispose.
//     // socketService.dispose();
//
//     super.onClose();
//   }
// }
//

//

