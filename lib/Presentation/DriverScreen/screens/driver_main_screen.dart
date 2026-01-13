import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:percent_indicator/percent_indicator.dart';

import 'package:hopper/Core/Constants/Colors.dart';
import 'package:hopper/Core/Constants/log.dart';
import 'package:hopper/Core/Utility/app_loader.dart';
import 'package:hopper/Core/Utility/Buttons.dart';
import 'package:hopper/Core/Utility/images.dart';
import 'package:hopper/api/repository/api_constents.dart';
import 'package:hopper/utils/sharedprefsHelper/sharedprefs_handler.dart';
import 'package:hopper/utils/sharedprefsHelper/booking_local_data.dart';
import 'package:hopper/utils/websocket/socket_io_client.dart';
import '../../../api/repository/api_config_controller.dart';
import '../../../utils/netWorkHandling/network_handling_screen.dart';

import 'package:hopper/Presentation/Drawer/screens/drawer_screens.dart';
import 'package:hopper/Presentation/DriverScreen/controller/driver_status_controller.dart';
import 'SharedBooking/Controller/booking_request_controller.dart';
import '../../Authentication/widgets/textFields.dart';

class DriverMainScreen extends StatefulWidget {
  const DriverMainScreen({super.key});

  @override
  State<DriverMainScreen> createState() => _DriverMainScreenState();
}

class _DriverMainScreenState extends State<DriverMainScreen>
    with SingleTickerProviderStateMixin {
  // Controllers
  final bookingController = Get.find<BookingRequestController>();
  final DriverStatusController statusController = Get.put(
    DriverStatusController(),
  );

  // Map
  GoogleMapController? _mapController;
  String? _mapStyle;
  LatLng? _currentPosition;

  // Marker + animation
  BitmapDescriptor? _carIcon;
  Marker? _carMarker;
  LatLng? _lastPosition;

  AnimationController? _animCtrl;
  Animation<double>? _anim;
  Tween<double>? _latTween;
  Tween<double>? _lngTween;
  Tween<double>? _rotTween;

  // Socket + location
  late SocketService socketService;
  StreamSubscription<Position>? _locationSub;
  Timer? _emitTimer;
  Map<String, dynamic>? _latestLocationPayload;

  String? driverId;
  String? _currentBookingId;

  // Countdown for request
  Timer? _countdownTimer;
  int remainingSeconds = 15;

  // Screen ready
  bool _ready = false;

  // Uber-like follow mode
  final RxBool followDriver = true.obs;
  Timer? _cameraFollowTimer;

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

  double _bearingBetween(LatLng start, LatLng end) {
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

  bool _movedEnough(LatLng a, LatLng b) {
    // ~2m threshold; prevents tiny jitter updates
    final dx = (a.latitude - b.latitude).abs();
    final dy = (a.longitude - b.longitude).abs();
    return (dx + dy) > 0.00002;
  }

  // ---------------- permissions ----------------
  Future<bool> _ensureLocationPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      Get.snackbar(
        "Location Disabled",
        "Please enable location services to use the app.",
      );
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

  Future<Position?> _getCurrentPos() async {
    final ok = await _ensureLocationPermission();
    if (!ok) return null;
    return Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  // ---------------- map style ----------------
  Future<void> _loadMapStyle() async {
    try {
      final style = await DefaultAssetBundle.of(
        context,
      ).loadString('assets/map_style/map_style.json');
      _mapStyle = style;
      if (_mapController != null) {
        await _mapController!.setMapStyle(style);
      }
    } catch (e) {
      if (kDebugMode) {
        CommonLogger.log.w("Map style load failed: $e");
      }
    }
  }

  // ---------------- icon ----------------
  Future<void> _loadCustomCarIcon() async {
    if (statusController.serviceType.value == "Car") {
      _carIcon = await BitmapDescriptor.asset(
        const ImageConfiguration(size: Size(57, 57)),
        AppImages.movingCar,
      );
    } else {
      _carIcon = await BitmapDescriptor.asset(
        const ImageConfiguration(size: Size(57, 57)),
        AppImages.parcelBike,
      );
    }
  }

  // ---------------- marker update ----------------
  void _updateCarMarker(LatLng newPos) {
    if (!mounted) return;
    if (_carIcon == null) return;
    if (_animCtrl == null || _anim == null) return;

    if (_lastPosition == null) {
      _carMarker = Marker(
        markerId: const MarkerId('car'),
        position: newPos,
        icon: _carIcon!,
        rotation: 0,
        anchor: const Offset(0.5, 0.5),
        flat: true,
      );
      _lastPosition = newPos;
      setState(() {});
      return;
    }

    if (!_movedEnough(_lastPosition!, newPos)) return;

    final bearing = _bearingBetween(_lastPosition!, newPos);

    _latTween = Tween(begin: _lastPosition!.latitude, end: newPos.latitude);
    _lngTween = Tween(begin: _lastPosition!.longitude, end: newPos.longitude);
    _rotTween = Tween(begin: _carMarker?.rotation ?? 0, end: bearing);

    _animCtrl!
      ..stop()
      ..reset()
      ..forward();

    _lastPosition = newPos;
  }

  // ---------------- init location ----------------
  Future<void> _initLocation() async {
    final pos = await _getCurrentPos();
    if (pos == null) return;

    final latLng = LatLng(pos.latitude, pos.longitude);

    if (!mounted) return;
    setState(() => _currentPosition = latLng);

    _updateCarMarker(latLng);

    await _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: latLng, zoom: 16.6, tilt: 35),
      ),
    );
  }

  Future<void> _goToCurrentLocation() async {
    final pos = await _getCurrentPos();
    if (pos == null) return;

    final latLng = LatLng(pos.latitude, pos.longitude);
    await _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: latLng, zoom: 16.8, tilt: 35),
      ),
    );
    _updateCarMarker(latLng);
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
  void _startCountdown() {
    _countdownTimer?.cancel();
    remainingSeconds = 15;

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;

      if (remainingSeconds > 0) {
        setState(() => remainingSeconds--);
      } else {
        t.cancel();
        bookingController.clear();
      }
    });
  }

  // ---------------- camera follow (Uber feel) ----------------
  void _startCameraFollow() {
    _cameraFollowTimer?.cancel();

    _cameraFollowTimer = Timer.periodic(const Duration(milliseconds: 900), (
      _,
    ) async {
      if (!followDriver.value) return;
      if (_lastPosition == null) return;
      if (_mapController == null) return;

      final bearing = _carMarker?.rotation ?? 0;

      await _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: _lastPosition!,
            zoom: 16.8,
            tilt: 40,
            bearing: bearing,
          ),
        ),
      );
    });
  }

  // ---------------- socket + location stream ----------------
  Future<void> _startEmitLoop() async {
    await _locationSub?.cancel();
    _emitTimer?.cancel();

    _locationSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 8, // ✅ smoother & less spam than 0/5
      ),
    ).listen((pos) {
      _latestLocationPayload = {
        'userId': driverId,
        'latitude': pos.latitude,
        'longitude': pos.longitude,
        if (_currentBookingId != null) 'bookingId': _currentBookingId,
      };

      // marker update locally for smooth UI
      _updateCarMarker(LatLng(pos.latitude, pos.longitude));
    });

    _emitTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (!statusController.isOnline.value) return;
      if (_latestLocationPayload == null) return;

      socketService.emit('updateLocation', _latestLocationPayload!);
    });
  }

  Future<void> _initSocketAndLocation() async {
    driverId = await SharedPrefHelper.getDriverId();
    if (driverId == null) return;
    final cfg = Get.find<ApiConfigController>();
    socketService = SocketService();
    socketService.initSocket(cfg.socketUrl);

    socketService.on('connect', (_) {
      socketService.registerDriver(
        driverId ?? '',
        bookingId: _currentBookingId,
        ack: (resp) {
          if (kDebugMode) CommonLogger.log.i("register ack: $resp");
        },
      );
    });

    socketService.on('registered', (_) async {
      await _startEmitLoop();
    });

    socketService.on('booking-request', (data) async {
      if (data == null) return;
      BookingDataService().setBookingData(data);

      if (data['type'] == 'active-bookings') {
        final List active = data['activeBookings'] ?? [];
        if (active.isEmpty) return;

        final booking = active.first;
        _currentBookingId = booking['bookingId']?.toString();

        final fromLat = (booking['fromLatitude'] as num?)?.toDouble();
        final fromLng = (booking['fromLongitude'] as num?)?.toDouble();
        final toLat = (booking['toLatitude'] as num?)?.toDouble();
        final toLng = (booking['toLongitude'] as num?)?.toDouble();
        if (fromLat == null ||
            fromLng == null ||
            toLat == null ||
            toLng == null)
          return;

        final pickupAddr = await getAddressFromLatLng(fromLat, fromLng);
        final dropAddr = await getAddressFromLatLng(toLat, toLng);

        bookingController.showRequest(
          rawData: booking,
          pickupAddress: pickupAddr,
          dropAddress: dropAddr,
        );
        _startCountdown();
        return;
      }

      _currentBookingId = data['bookingId']?.toString();
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
          dropLng == null)
        return;

      final pickupAddr = await getAddressFromLatLng(pickupLat, pickupLng);
      final dropAddr = await getAddressFromLatLng(dropLat, dropLng);

      bookingController.showRequest(
        rawData: data,
        pickupAddress: pickupAddr,
        dropAddress: dropAddr,
      );
      _startCountdown();
    });

    await _initLocation();
    _startCameraFollow();
  }

  // ---------------- toggle online ----------------
  Future<void> _toggleOnline() async {
    if (statusController.isLoading.value) return;
    statusController.isLoading.value = true;

    try {
      statusController.toggleStatus();
      final isOnline = statusController.isOnline.value;

      double lat = 0, lng = 0;
      if (isOnline) {
        final pos = await _getCurrentPos();
        if (pos == null) {
          statusController.toggleStatus();
          return;
        }
        lat = pos.latitude;
        lng = pos.longitude;
      }

      await statusController.onlineAcceptStatus(
        context,
        status: isOnline,
        latitude: lat,
        longitude: lng,
      );

      if (isOnline) {
        followDriver.value = true;
        await _goToCurrentLocation();
      }
    } catch (e) {
      statusController.toggleStatus();
      CommonLogger.log.e("toggle online error: $e");
    } finally {
      statusController.isLoading.value = false;
    }
  }

  // ---------------- init / dispose ----------------
  @override
  void initState() {
    super.initState();

    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650), // ✅ smoother
    );

    _anim = CurvedAnimation(parent: _animCtrl!, curve: Curves.easeOutCubic)
      ..addListener(() {
        if (!mounted) return;
        if (_latTween == null || _lngTween == null || _rotTween == null) return;

        final lat = _latTween!.evaluate(_anim!);
        final lng = _lngTween!.evaluate(_anim!);
        final rot = _rotTween!.evaluate(_anim!);

        setState(() {
          _carMarker = Marker(
            markerId: const MarkerId('car'),
            position: LatLng(lat, lng),
            icon: _carIcon ?? BitmapDescriptor.defaultMarker,
            rotation: rot,
            anchor: const Offset(0.5, 0.5),
            flat: true,
          );
        });
      });

    _prepare();
  }

  Future<void> _prepare() async {
    try {
      await statusController.getDriverStatus();
      await _loadCustomCarIcon();

      if (mounted) setState(() => _ready = true);

      SchedulerBinding.instance.addPostFrameCallback((_) async {
        await _loadMapStyle();

        statusController.weeklyChallenges();
        statusController.todayActivity();
        statusController.todayPackageActivity();
      });

      await _initSocketAndLocation();
    } catch (e) {
      CommonLogger.log.e("prepare error: $e");
      if (mounted) setState(() => _ready = true);
    }
  }

  @override
  void dispose() {

    _countdownTimer?.cancel();
    _emitTimer?.cancel();
    _cameraFollowTimer?.cancel();
    _locationSub?.cancel();
    _animCtrl?.dispose();

    try {
      socketService.dispose();
    } catch (_) {}

    super.dispose();
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    return NoInternetOverlay(
      child: WillPopScope(
        onWillPop: () async {
          return await true;
        },
        child: Scaffold(
          body: SafeArea(
            child:
                !_ready
                    ? Center(child: AppLoader.circularLoader())
                    : Column(
                      children: [
                        const SizedBox(height: 12),

                        // ✅ Glass header (premium feel)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: _GlassHeader(
                            onDrawer: () => Get.to(() => const DrawerScreen()),
                            onToggle: _toggleOnline,
                            statusController: statusController,
                          ),
                        ),

                        const SizedBox(height: 12),

                        Expanded(
                          child: Stack(
                            children: [
                              // ✅ Map NEVER depends on Obx => no rebuild => smooth
                              RepaintBoundary(
                                child: GoogleMap(
                                  mapType: MapType.normal,
                                  compassEnabled: false,
                                  myLocationEnabled: false,
                                  myLocationButtonEnabled: false,
                                  zoomControlsEnabled: false,
                                  buildingsEnabled: true,
                                  trafficEnabled: false,
                                  tiltGesturesEnabled: true,
                                  rotateGesturesEnabled: true,
                                  scrollGesturesEnabled: true,
                                  zoomGesturesEnabled: true,
                                  liteModeEnabled: false,

                                  padding: const EdgeInsets.only(bottom: 260),

                                  initialCameraPosition: CameraPosition(
                                    target:
                                        _currentPosition ??
                                        const LatLng(9.914, 78.097),
                                    zoom: 16,
                                  ),

                                  markers:
                                      _carMarker != null ? {_carMarker!} : {},

                                  onCameraMoveStarted: () {
                                    // ✅ stop follow when user touches map
                                    followDriver.value = false;
                                  },

                                  onMapCreated: (c) async {
                                    _mapController = c;
                                    if (_mapStyle != null) {
                                      await _mapController!.setMapStyle(
                                        _mapStyle,
                                      );
                                    }
                                  },

                                  gestureRecognizers: {
                                    Factory<OneSequenceGestureRecognizer>(
                                      () => EagerGestureRecognizer(),
                                    ),
                                  },
                                ),
                              ),

                              // ✅ Follow button (Uber)
                              Positioned(
                                top: 190,
                                right: 12,
                                child: Obx(() {
                                  return FloatingActionButton(
                                    mini: true,
                                    backgroundColor: Colors.white,
                                    onPressed: () async {
                                      followDriver.value = true;
                                      await _goToCurrentLocation();
                                    },
                                    child: Icon(
                                      followDriver.value
                                          ? Icons.gps_fixed
                                          : Icons.my_location,
                                      color: Colors.black,
                                    ),
                                  );
                                }),
                              ),

                              // ✅ Bottom sheet only rebuilds on online / service type etc
                              Obx(() {
                                final isOnline =
                                    statusController.isOnline.value;

                                return IgnorePointer(
                                  ignoring: !isOnline,
                                  child: Opacity(
                                    opacity: isOnline ? 1.0 : 0.9,
                                    child: DriverBottomSheet(
                                      statusController: statusController,
                                      bookingController: bookingController,
                                      remainingSeconds: remainingSeconds,
                                      safeToDouble: safeToDouble,
                                      safeToInt: safeToInt,
                                      formatDuration: formatDuration,
                                      formatDistance: formatDistance,
                                    ),
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                      ],
                    ),
          ),
        ),
      ),
    );
  }
}

// ==========================================================
// ✅ Glass Header widget (UI polish)
// ==========================================================
class _GlassHeader extends StatelessWidget {
  const _GlassHeader({
    required this.onDrawer,
    required this.onToggle,
    required this.statusController,
  });

  final VoidCallback onDrawer;
  final VoidCallback onToggle;
  final DriverStatusController statusController;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
        boxShadow: [
          BoxShadow(
            blurRadius: 20,
            offset: const Offset(0, 8),
            color: Colors.black.withOpacity(0.10),
          ),
        ],
      ),
      child: Row(
        children: [
          InkWell(
            onTap: onDrawer,
            child: Image.asset(AppImages.drawer, height: 26, width: 26),
          ),
          const Spacer(),

          GestureDetector(
            onTap: onToggle,
            child: Obx(() {
              final isOnline = statusController.isOnline.value;
              final isLoading = statusController.isLoading.value;

              return AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isOnline ? AppColors.nBlue : Colors.black,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isLoading) ...[
                      const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    if (isOnline) ...[
                      const Text(
                        "Online",
                        style: TextStyle(color: Colors.white),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Image.asset(
                          AppImages.offlineCar,
                          width: 18,
                          height: 18,
                          color: AppColors.nBlue,
                        ),
                      ),
                    ] else ...[
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Image.asset(
                          AppImages.offlineCar,
                          width: 18,
                          height: 18,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        "Offline",
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  ],
                ),
              );
            }),
          ),

          const Spacer(),
          const SizedBox(width: 10),
        ],
      ),
    );
  }
}

class DriverBottomSheet extends StatefulWidget {
  const DriverBottomSheet({
    super.key,
    required this.statusController,
    required this.bookingController,
    required this.remainingSeconds,
    required this.safeToDouble,
    required this.safeToInt,
    required this.formatDuration,
    required this.formatDistance,
  });

  final DriverStatusController statusController;
  final BookingRequestController bookingController;

  final int remainingSeconds;

  final double Function(dynamic) safeToDouble;
  final int Function(dynamic) safeToInt;
  final String Function(int) formatDuration;
  final String Function(double) formatDistance;

  @override
  State<DriverBottomSheet> createState() => _DriverBottomSheetState();
}

class _DriverBottomSheetState extends State<DriverBottomSheet> {
  final DraggableScrollableController _sheetCtrl =
      DraggableScrollableController();

  // ✅ Uber-like snap points (collapsed, mid, full)
  static const List<double> _snaps = [0.22, 0.65, 0.98];

  double _currentSize = _snaps[1];
  bool _isSnapping = false;
  Timer? _snapDebounce;

  double _nearestSnap(double size) {
    double best = _snaps.first;
    double bestDist = (size - best).abs();
    for (final s in _snaps) {
      final d = (size - s).abs();
      if (d < bestDist) {
        bestDist = d;
        best = s;
      }
    }
    return best;
  }

  void _scheduleSnap() {
    _snapDebounce?.cancel();
    _snapDebounce = Timer(const Duration(milliseconds: 120), () async {
      if (!mounted) return;
      if (_isSnapping) return;

      final target = _nearestSnap(_currentSize);

      // close enough -> ignore
      if ((_currentSize - target).abs() < 0.03) return;

      _isSnapping = true;
      try {
        await _sheetCtrl.animateTo(
          target,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
        );
      } catch (_) {
        // ignore
      } finally {
        _isSnapping = false;
      }
    });
  }

  @override
  void dispose() {
    _snapDebounce?.cancel();
    super.dispose();
  }

  Color getTextColor({Color color = Colors.black}) =>
      widget.statusController.isOnline.value ? color : Colors.black;

  @override
  Widget build(BuildContext context) {
    // ✅ IMPORTANT: read serviceType inside Obx, otherwise it won’t update instantly
    return Obx(() {
      final serviceType = widget.statusController.serviceType.value;

      return NotificationListener<DraggableScrollableNotification>(
        onNotification: (n) {
          _currentSize = n.extent;

          // ✅ Snap when user stops dragging (debounced)
          if (n.extent <= _snaps.last && n.extent >= _snaps.first) {
            _scheduleSnap();
          }
          return false;
        },
        child: DraggableScrollableSheet(
          controller: _sheetCtrl,
          initialChildSize: _snaps[1],
          minChildSize: _snaps[0],
          maxChildSize: _snaps[2],
          snap: false, // manual snap for consistent Uber feel
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(22),
                ),
                boxShadow: [
                  BoxShadow(
                    blurRadius: 26,
                    offset: const Offset(0, -10),
                    color: Colors.black.withOpacity(0.10),
                  ),
                ],
              ),
              child: RefreshIndicator(
                onRefresh: () async {
                  await widget.statusController.weeklyChallenges();
                  if (serviceType == 'Car') {
                    await widget.statusController.todayActivity();
                  } else {
                    await widget.statusController.todayPackageActivity();
                  }
                },
                child: ListView(
                  controller: scrollController,
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  children: [
                    // drag handle only
                    Center(
                      child: Container(
                        width: 44,
                        height: 4,
                        margin: const EdgeInsets.only(top: 10),
                        decoration: BoxDecoration(
                          color: Colors.grey[350],
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // =========================
                    // ✅ Booking Request Area
                    // =========================
                    if (serviceType == 'Car') ...[
                      Center(
                        child: CustomTextfield.textWithStyles700(
                          'Hoppr Car',
                          color: AppColors.commonBlack.withOpacity(0.55),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Obx(() {
                        final data =
                            widget.bookingController.bookingRequestData.value;
                        if (data == null) return const SizedBox.shrink();

                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.red,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: CustomTextfield.textWithStyles600(
                                      color: AppColors.commonWhite,
                                      '${widget.remainingSeconds}s',
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  const Text(
                                    "Respond within 15 seconds",
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              _CarBookingCardUI(
                                data: data,
                                statusController: widget.statusController,
                                bookingController: widget.bookingController,
                                safeToDouble: widget.safeToDouble,
                                safeToInt: widget.safeToInt,
                                formatDuration: widget.formatDuration,
                                formatDistance: widget.formatDistance,
                              ),
                            ],
                          ),
                        );
                      }),
                    ] else ...[
                      Center(
                        child: Opacity(
                          opacity: 0.65,
                          child: Image.asset(
                            AppImages.hopprPackage,
                            height: 26,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Obx(() {
                        final data =
                            widget.bookingController.bookingRequestData.value;
                        if (data == null) return const SizedBox.shrink();

                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.red,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: CustomTextfield.textWithStyles600(
                                      color: AppColors.commonWhite,
                                      '${widget.remainingSeconds}s',
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  const Text(
                                    "Respond within 15 seconds",
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              _ParcelBookingCardUI(
                                data: data,
                                statusController: widget.statusController,
                                bookingController: widget.bookingController,
                                safeToDouble: widget.safeToDouble,
                                safeToInt: widget.safeToInt,
                                formatDuration: widget.formatDuration,
                                formatDistance: widget.formatDistance,
                              ),
                            ],
                          ),
                        );
                      }),
                    ],

                    // =========================
                    // ✅ Offline banner (keep)
                    // =========================
                    Obx(() {
                      if (widget.statusController.isOnline.value)
                        return const SizedBox(height: 6);
                      return Container(
                        height: 54,
                        color: AppColors.commonBlack,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Image.asset(
                              AppImages.graph,
                              color: AppColors.commonWhite,
                              height: 20,
                            ),
                            const SizedBox(width: 10),
                            CustomTextfield.textWithStyles600(
                              fontSize: 13,
                              color: AppColors.commonWhite,
                              'You are Offline - Go Online to get requests',
                            ),
                          ],
                        ),
                      );
                    }),

                    const SizedBox(height: 18),

                    // =========================
                    // ✅ Weekly + Today (FULL)
                    // =========================
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 17),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CustomTextfield.textWithStyles700(
                            'Weekly Challenges',
                            fontSize: 16,
                            color: getTextColor(),
                          ),
                          const SizedBox(height: 10),

                          // ✅ Weekly widget (FULL)
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.commonBlack.withOpacity(0.08),
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 15,
                                vertical: 20,
                              ),
                              child: Obx(() {
                                final weeklyData =
                                    widget
                                        .statusController
                                        .weeklyStatusData
                                        .value;

                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          CustomTextfield.textWithStylesSmall(
                                            'Ends on Monday',
                                            colors: AppColors.grey,
                                            fontWeight: FontWeight.w500,
                                          ),
                                          const SizedBox(height: 5),
                                          CustomTextfield.textWithStyles600(
                                            'Complete ${weeklyData?.goal.toString() ?? '0'} trips and get ${weeklyData?.reward.toString() ?? '0'} extra',
                                            fontSize: 17,
                                          ),
                                          const SizedBox(height: 5),
                                          CustomTextfield.textWithStylesSmall(
                                            colors: getTextColor(
                                              color: AppColors.drkGreen,
                                            ),
                                            '${weeklyData?.totalTrips.toString() ?? '0'} trips done out of 20',
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 15),
                                    CircularPercentIndicator(
                                      radius: 45.0,
                                      lineWidth: 10.0,
                                      animation: true,
                                      percent: ((weeklyData?.progressPercent ??
                                                  0) /
                                              100)
                                          .clamp(0.0, 1.0),
                                      center: Text(
                                        "${weeklyData?.progressPercent.toString() ?? '0'}%",
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      circularStrokeCap:
                                          CircularStrokeCap.round,
                                      backgroundColor: AppColors.drkGreen
                                          .withOpacity(0.1),
                                      progressColor: getTextColor(
                                        color: AppColors.drkGreen,
                                      ),
                                    ),
                                  ],
                                );
                              }),
                            ),
                          ),

                          const SizedBox(height: 18),

                          // ✅ Today Activity (FULL)
                          CustomTextfield.textWithStyles700(
                            "Today's Activity",
                            fontSize: 16,
                          ),
                          const SizedBox(height: 10),

                          if (serviceType == 'Car')
                            _TodayActivityCar(
                              statusController: widget.statusController,
                            )
                          else
                            _TodayActivityParcel(
                              statusController: widget.statusController,
                            ),

                          const SizedBox(height: 18),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    });
  }
}

/// ==========================================================
/// ✅ CAR Booking Card UI (your UI, optimized)
/// ==========================================================
class _CarBookingCardUI extends StatelessWidget {
  const _CarBookingCardUI({
    required this.data,
    required this.statusController,
    required this.bookingController,
    required this.safeToDouble,
    required this.safeToInt,
    required this.formatDuration,
    required this.formatDistance,
  });

  final Map<String, dynamic> data;
  final DriverStatusController statusController;
  final BookingRequestController bookingController;

  final double Function(dynamic) safeToDouble;
  final int Function(dynamic) safeToInt;
  final String Function(int) formatDuration;
  final String Function(double) formatDistance;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.commonWhite,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            // header
            Container(
              width: double.infinity,
              height: 54,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(10),
                  topRight: Radius.circular(10),
                ),
                color: AppColors.nBlue,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 15),
                child: Row(
                  children: [
                    Image.asset(AppImages.notification, height: 25, width: 25),
                    const SizedBox(width: 10),
                    CustomTextfield.textWithStyles600(
                      data['rideType'] == 'Bike'
                          ? 'New Package Request'
                          : 'New Ride Request',
                      color: AppColors.commonWhite,
                    ),
                    const Spacer(),
                    CustomTextfield.textWithImage(
                      imageColors: AppColors.commonWhite,
                      text: '${data['estimatedPrice'] ?? ''}',
                      imagePath: AppImages.bCurrency,
                      colors: AppColors.commonWhite,
                      fontWeight: FontWeight.w700,
                    ),
                  ],
                ),
              ),
            ),

            // addresses
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.circle, color: Colors.green, size: 12),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          data['pickupAddress'] ?? '',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.circle, color: Colors.red, size: 12),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          data['dropAddress'] ?? '',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              child: Divider(color: AppColors.commonBlack.withOpacity(0.1)),
            ),

            // duration + distance
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Row(
                    children: [
                      Image.asset(AppImages.time, height: 20, width: 20),
                      const SizedBox(width: 10),
                      Text(
                        formatDuration(safeToInt(data['estimateDuration'])),
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                  SizedBox(
                    height: 40,
                    child: VerticalDivider(
                      color: AppColors.commonBlack.withOpacity(0.1),
                    ),
                  ),
                  Row(
                    children: [
                      Image.asset(AppImages.distance, height: 20, width: 20),
                      const SizedBox(width: 10),
                      Text(
                        formatDistance(safeToDouble(data['estimatedDistance'])),
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              child: Divider(color: AppColors.commonBlack.withOpacity(0.1)),
            ),

            // buttons
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 8.0,
                vertical: 10,
              ),
              child: Row(
                children: [
                  // DECLINE
                  Expanded(
                    child: Buttons.button(
                      borderRadius: 10,
                      buttonColor: AppColors.red,
                      onTap:
                          statusController.isLoading.value
                              ? null
                              : () {
                                final id = data['bookingId']?.toString();
                                if (id != null) {
                                  bookingController.markHandled(id);
                                } else {
                                  bookingController.clear();
                                }
                              },
                      text: const Text('Decline'),
                    ),
                  ),
                  const SizedBox(width: 20),

                  // ACCEPT
                  Expanded(
                    child: Buttons.button(
                      borderRadius: 10,
                      buttonColor: AppColors.drkGreen,
                      onTap:
                          statusController.isLoading.value
                              ? null
                              : () async {
                                try {
                                  final bookingId = data['bookingId'];

                                  final pickupAddress =
                                      data['pickupAddress'] ?? '';
                                  final dropAddress = data['dropAddress'] ?? '';

                                  final pickup = LatLng(
                                    (data['pickupLocation']['latitude'] as num)
                                        .toDouble(),
                                    (data['pickupLocation']['longitude'] as num)
                                        .toDouble(),
                                  );

                                  // driver current location
                                  // (keep as-is; your controller already handles)
                                  await statusController.bookingAccept(
                                    pickupLocationAddress: pickupAddress,
                                    dropLocationAddress: dropAddress,
                                    context,
                                    bookingId: bookingId,
                                    status: 'ACCEPT',
                                    pickupLocation: pickup,
                                    driverLocation:
                                        pickup, // NOTE: you can pass driver actual LatLng if you have it here
                                  );

                                  bookingController.markHandled(
                                    bookingId.toString(),
                                  );
                                } catch (e) {
                                  bookingController.clear();
                                  CommonLogger.log.e(
                                    "Booking accept failed: $e",
                                  );
                                }
                              },
                      text:
                          statusController.isLoading.value
                              ? SizedBox(
                                height: 20,
                                width: 20,
                                child: AppLoader.circularLoader(),
                              )
                              : const Text('Accept'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ==========================================================
/// ✅ Parcel card - keep same UI (if you want different, modify here)
/// ==========================================================
class _ParcelBookingCardUI extends StatelessWidget {
  const _ParcelBookingCardUI({
    required this.data,
    required this.statusController,
    required this.bookingController,
    required this.safeToDouble,
    required this.safeToInt,
    required this.formatDuration,
    required this.formatDistance,
  });

  final Map<String, dynamic> data;
  final DriverStatusController statusController;
  final BookingRequestController bookingController;

  final double Function(dynamic) safeToDouble;
  final int Function(dynamic) safeToInt;
  final String Function(int) formatDuration;
  final String Function(double) formatDistance;

  @override
  Widget build(BuildContext context) {
    return _CarBookingCardUI(
      data: data,
      statusController: statusController,
      bookingController: bookingController,
      safeToDouble: safeToDouble,
      safeToInt: safeToInt,
      formatDuration: formatDuration,
      formatDistance: formatDistance,
    );
  }
}

/// ==========================================================
/// ✅ Today Activity - CAR
/// ==========================================================
class _TodayActivityCar extends StatelessWidget {
  const _TodayActivityCar({required this.statusController});
  final DriverStatusController statusController;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.commonBlack.withOpacity(0.1)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 15),
        child: Obx(() {
          final data = statusController.todayStatusData.value;
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                children: [
                  CustomTextfield.textWithStyles600(
                    'Earnings',
                    color: AppColors.grey,
                  ),
                  CustomTextfield.textWithImage(
                    text: data?.earnings.toString() ?? '0',
                    colors: AppColors.commonBlack,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    imagePath: AppImages.bCurrency,
                  ),
                ],
              ),
              SizedBox(
                height: 50,
                child: VerticalDivider(
                  color: AppColors.commonBlack.withOpacity(0.2),
                ),
              ),
              Column(
                children: [
                  CustomTextfield.textWithStyles600(
                    'Online',
                    color: AppColors.grey,
                  ),
                  CustomTextfield.textWithImage(
                    text: data?.online.toString() ?? '0',
                    colors: AppColors.commonBlack,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ],
              ),
              SizedBox(
                height: 50,
                child: VerticalDivider(
                  color: AppColors.commonBlack.withOpacity(0.2),
                ),
              ),
              Column(
                children: [
                  CustomTextfield.textWithStyles600(
                    'Rides',
                    color: AppColors.grey,
                  ),
                  CustomTextfield.textWithImage(
                    text: data?.rides.toString() ?? '0',
                    colors: AppColors.commonBlack,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ],
              ),
            ],
          );
        }),
      ),
    );
  }
}

/// ==========================================================
/// ✅ Today Activity - PARCEL
/// ==========================================================
class _TodayActivityParcel extends StatelessWidget {
  const _TodayActivityParcel({required this.statusController});
  final DriverStatusController statusController;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 15),
        child: Obx(() {
          final data = statusController.parcelBookingData.value;
          return Row(
            children: [
              Expanded(
                flex: 2,
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 10,
                      ),
                      decoration: const BoxDecoration(
                        color: Color(0xFFE2FBE9),
                        shape: BoxShape.circle,
                      ),
                      child: Image.asset(
                        AppImages.bCurrency,
                        height: 17,
                        color: const Color(0xff009721),
                      ),
                    ),
                    const SizedBox(height: 5),
                    CustomTextfield.textWithImage(
                      text: ((data?.earning ?? 0).toDouble()).toStringAsFixed(
                        2,
                      ),
                      colors: AppColors.commonBlack,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      imagePath: AppImages.bCurrency,
                    ),
                    const SizedBox(height: 5),
                    CustomTextfield.textWithStylesSmall(
                      'Earnings',
                      colors: AppColors.grey,
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Expanded(
                flex: 1,
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 10,
                      ),
                      decoration: const BoxDecoration(
                        color: Color(0XFFDEEAFC),
                        shape: BoxShape.circle,
                      ),
                      child: Image.asset(AppImages.boxLine, height: 17),
                    ),
                    const SizedBox(height: 5),
                    CustomTextfield.textWithImage(
                      text: data?.completed.toString() ?? '0',
                      colors: AppColors.commonBlack,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                    const SizedBox(height: 5),
                    CustomTextfield.textWithStylesSmall(
                      'Deliveries',
                      colors: AppColors.grey,
                      maxLine: 1,
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Expanded(
                flex: 1,
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.starColors,
                        shape: BoxShape.circle,
                      ),
                      child: Image.asset(
                        AppImages.star,
                        height: 17,
                        color: const Color(0XFFC18C30),
                      ),
                    ),
                    const SizedBox(height: 5),
                    CustomTextfield.textWithImage(
                      text: data?.rating.toString() ?? '0',
                      colors: AppColors.commonBlack,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                    const SizedBox(height: 5),
                    CustomTextfield.textWithStylesSmall(
                      'Rating',
                      colors: AppColors.grey,
                    ),
                  ],
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}

// import 'dart:async';
// import 'dart:math';
// import 'package:flutter/foundation.dart';
// import 'package:flutter/scheduler.dart';
// import 'package:flutter_compass/flutter_compass.dart';
// import 'package:geocoding/geocoding.dart';
// import 'package:hopper/Core/Constants/log.dart';
// import 'package:hopper/Core/Utility/app_loader.dart';
// import 'package:hopper/Presentation/Drawer/screens/drawer_screens.dart';
// import 'package:hopper/Presentation/DriverScreen/screens/SharedBooking/Screens/booking_overlay_request.dart';
// import 'package:hopper/Presentation/DriverScreen/screens/SharedBooking/Screens/shared_screens.dart';
// import 'package:hopper/Presentation/DriverScreen/screens/picking_customer_screen.dart';
// import 'package:hopper/api/repository/api_constents.dart';
// import 'package:hopper/utils/sharedprefsHelper/sharedprefs_handler.dart';
// import 'package:percent_indicator/percent_indicator.dart';
// import 'package:hopper/Core/Utility/Buttons.dart';
// import '../../../utils/netWorkHandling/network_handling_screen.dart';
// import '../../../utils/sharedprefsHelper/booking_local_data.dart';
// import '../../../utils/websocket/socket_io_client.dart';
// import '../../Authentication/screens/GetStarted_Screens.dart';
// import '../../Authentication/widgets/textFields.dart';
// import 'package:flutter/gestures.dart';
// import 'package:flutter/material.dart';
// import 'package:geolocator/geolocator.dart';
// import 'package:google_maps_flutter/google_maps_flutter.dart';
// import 'package:hopper/Core/Constants/Colors.dart';
// import 'package:hopper/Core/Utility/images.dart';
// import 'package:get/get.dart';
// import 'package:hopper/Presentation/DriverScreen/controller/driver_status_controller.dart';
//
// import '../../Drawer/controller/ride_history_controller.dart';
// import 'SharedBooking/Controller/booking_request_controller.dart';
//
// class DriverMainScreen extends StatefulWidget {
//   const DriverMainScreen({super.key});
//
//   @override
//   State<DriverMainScreen> createState() => _DriverMainScreenState();
// }
//
// class _DriverMainScreenState extends State<DriverMainScreen>
//     with SingleTickerProviderStateMixin {
//   AnimationController? _animationController;
//   Tween<double>? _latTween;
//   Tween<double>? _lngTween;
//   Tween<double>? _rotationTween;
//   Animation<double>? _animation;
//   final bookingController = Get.find<BookingRequestController>();
//   final RideHistoryController controller = Get.put(RideHistoryController());
//   final DriverStatusController statusController = Get.put(
//     DriverStatusController(),
//   );
//   LatLng? _currentPosition;
//   GoogleMapController? _mapController;
//   bool _isAcceptingRide = false;
//   int remainingSeconds = 15;
//   Timer? _timer;
//
//   bool isOnline = false;
//   bool driverAccepted = false;
//   Map<String, dynamic>? bookingRequestData;
//   double _heading = 0;
//   Marker? _carMarker;
//   late SocketService socketService;
//   StreamSubscription<Position>? _positionStream;
//   StreamSubscription<CompassEvent>? _compassStream;
//
//   BitmapDescriptor? _carIcon;
//
//   double getFixedRotation(double heading) {
//     if (heading < 0 || heading > 360) return 0;
//
//     if (heading >= 315 || heading < 45) return 0; // North
//     if (heading >= 45 && heading < 135) return 90; // East
//     if (heading >= 135 && heading < 225) return 180; // South
//     if (heading >= 225 && heading < 315) return 270; // West
//
//     return 0;
//   }
//
//   String getDirectionLabel(double heading) {
//     if (heading >= 315 || heading < 45) return 'North';
//     if (heading >= 45 && heading < 135) return 'East';
//     if (heading >= 135 && heading < 225) return 'South';
//     if (heading >= 225 && heading < 315) return 'West';
//     return 'Unknown';
//   }
//
//   LatLng? _lastPosition;
//   void _updateCarMarker(LatLng newPosition) {
//     if (!mounted) return;
//     if (_carIcon == null) return;
//     if (_animationController == null || _animation == null) return;
//
//     if (_lastPosition == null) {
//       // First time placement – no animation
//       _carMarker = Marker(
//         markerId: const MarkerId('car'),
//         position: newPosition,
//         icon: _carIcon!,
//         rotation: 0,
//         anchor: const Offset(0.5, 0.5),
//         flat: true,
//       );
//       _lastPosition = newPosition;
//       setState(() {});
//       return;
//     }
//
//     // compute bearing
//     double bearing = _bearingBetween(_lastPosition!, newPosition);
//
//     // update tweens for new animation
//     _latTween = Tween(
//       begin: _lastPosition!.latitude,
//       end: newPosition.latitude,
//     );
//     _lngTween = Tween(
//       begin: _lastPosition!.longitude,
//       end: newPosition.longitude,
//     );
//     _rotationTween = Tween(begin: _carMarker?.rotation ?? 0, end: bearing);
//
//     // restart animation
//     _animationController!
//       ..reset()
//       ..forward();
//
//     _lastPosition = newPosition;
//   }
//
//   Future<void> _loadCustomCarIcon() async {
//     if (statusController.serviceType.value == "Car") {
//       _carIcon = await BitmapDescriptor.asset(
//         const ImageConfiguration(size: Size(57, 57)),
//         AppImages.movingCar, // <-- your car icon asset
//       );
//     } else if (statusController.serviceType.value == "Bike") {
//       _carIcon = await BitmapDescriptor.asset(
//         const ImageConfiguration(size: Size(57, 57)),
//         AppImages.parcelBike, // <-- your bike icon asset
//       );
//     } else {
//       // Default marker if service type not matched
//       _carIcon = BitmapDescriptor.defaultMarker;
//     }
//   }
//
//   Color getTextColor({Color color = Colors.black}) =>
//       statusController.isOnline.value ? color : Colors.black;
//
//   void _goToCurrentLocation() async {
//     Position position = await Geolocator.getCurrentPosition(
//       desiredAccuracy: LocationAccuracy.high,
//     );
//
//     final latLng = LatLng(position.latitude, position.longitude);
//
//     _mapController?.animateCamera(CameraUpdate.newLatLngZoom(latLng, 17));
//   }
//
//   Future<void> _initLocation(BuildContext context) async {
//     bool serviceEnabled;
//     LocationPermission permission;
//
//     serviceEnabled = await Geolocator.isLocationServiceEnabled();
//     if (!serviceEnabled) {
//       Get.snackbar(
//         "Location Disabled",
//         "Please enable location services to use the app.",
//       );
//       return;
//     }
//
//     permission = await Geolocator.checkPermission();
//     if (permission == LocationPermission.denied) {
//       permission = await Geolocator.requestPermission();
//       if (permission == LocationPermission.denied) {
//         _showPermissionDialog(context);
//         return;
//       }
//     }
//
//     if (permission == LocationPermission.deniedForever) {
//       _showPermissionDialog(context, openSettings: true);
//       return;
//     }
//
//     Position position = await Geolocator.getCurrentPosition(
//       desiredAccuracy: LocationAccuracy.high,
//     );
//
//     final userLatLng = LatLng(position.latitude, position.longitude);
//
//     if (!mounted) return;
//
//     setState(() {
//       _currentPosition = userLatLng;
//     });
//
//     // ✅ Recreate marker immediately when location available
//     if (_carIcon != null) {
//       _updateCarMarker(userLatLng);
//     }
//
//     // ✅ Move camera
//     _mapController?.animateCamera(
//       CameraUpdate.newCameraPosition(
//         CameraPosition(target: userLatLng, zoom: 16),
//       ),
//     );
//   }
//
//   void _showPermissionDialog(
//     BuildContext context, {
//     bool openSettings = false,
//   }) {
//     showDialog(
//       context: context,
//       builder:
//           (_) => AlertDialog(
//             title: Text("Permission Required"),
//             content: Text(
//               openSettings
//                   ? "Location permission is permanently denied. Please enable it in settings."
//                   : "Location permission is required to continue.",
//             ),
//             actions: [
//               TextButton(
//                 onPressed: () => Navigator.pop(context),
//                 child: Text("Cancel"),
//               ),
//               TextButton(
//                 onPressed: () {
//                   Navigator.pop(context);
//                   if (openSettings) {
//                     Geolocator.openAppSettings();
//                   } else {
//                     Geolocator.requestPermission();
//                   }
//                 },
//                 child: Text("Allow"),
//               ),
//             ],
//           ),
//     );
//   }
//
//   late StreamSubscription<Position> _locationStream;
//   String? driverId;
//   String? _currentBookingId;
//   String? pickupAddress;
//   String? dropAddress;
//   StreamSubscription? locationSub;
//   Timer? emitTimer;
//   Map<String, dynamic>? latestLocation;
//
//   double safeToDouble(dynamic value) {
//     if (value is double) return value;
//     if (value is int) return value.toDouble();
//     return double.tryParse(value.toString()) ?? 0.0;
//   }
//
//   int safeToInt(dynamic value) {
//     if (value is int) return value;
//     if (value is double) return value.round(); // or floor()
//     return int.tryParse(value.toString()) ?? 0;
//   }
//
//   String formatDistance(double meters) {
//     double kilometers = meters / 1000;
//     return '${kilometers.toStringAsFixed(1)} Km';
//   }
//
//   String formatDuration(int minutes) {
//     int hours = minutes ~/ 60;
//     int remainingMinutes = minutes % 60;
//     return hours > 0
//         ? '$hours hr $remainingMinutes min'
//         : '$remainingMinutes min';
//   }
//
//   Future<void> _initSocketAndLocation() async {
//     driverId = await SharedPrefHelper.getDriverId();
//
//     if (driverId == null) {
//       CommonLogger.log.e('Driver ID is null! Cannot initialize socket.');
//       return;
//     }
//
//     socketService = SocketService();
//
//     socketService.initSocket(ApiConstents.baseUrl1);
//
//     // When socket connects
//     socketService.on('connect', (_) {
//       CommonLogger.log.i('🟢 Connected to socket');
//
//       socketService.registerDriver(
//         driverId ?? '',
//         bookingId: _currentBookingId,
//         ack: (response) {
//           // response comes from server
//           if (response['status'] == true) {
//             CommonLogger.log.i("✅ Driver registration ACK received: $response");
//           } else {
//             CommonLogger.log.e("❌ Driver registration failed: $response");
//           }
//         },
//       );
//     });
//
//     int emitCount = 0;
//
//     socketService.on('registered', (data) {
//       CommonLogger.log.i('✅ Driver Registered: $data');
//
//       // STOP OLD STREAM + TIMER (avoid duplicate emissions)
//       locationSub?.cancel();
//       emitTimer?.cancel();
//
//       // 1. Listen to geolocator fast stream
//       locationSub = Geolocator.getPositionStream(
//         locationSettings: const LocationSettings(
//           accuracy: LocationAccuracy.high,
//           distanceFilter: 0,
//         ),
//       ).listen((position) {
//         latestLocation = {
//           'userId': driverId,
//           'latitude': position.latitude,
//           'longitude': position.longitude,
//           if (_currentBookingId != null) 'bookingId': _currentBookingId,
//         };
//       });
//
//       emitTimer = Timer.periodic(const Duration(seconds: 10), (_) {
//         if (latestLocation != null) {
//           emitCount++;
//
//           socketService.emit('updateLocation', latestLocation!);
//
//           CommonLogger.log.i(
//             "📍 [$emitCount] Emitted Location → $latestLocation",
//           );
//
//           final newLatLng = LatLng(
//             latestLocation!['latitude'],
//             latestLocation!['longitude'],
//           );
//           _updateCarMarker(newLatLng);
//         }
//       });
//     });
//
//     socketService.on('booking-request', (data) async {
//       if (data == null) return;
//
//       BookingDataService().setBookingData(data);
//       CommonLogger.log.i('📦 Booking Request → $data');
//
//       // 🔹 CASE 1: active-bookings payload (from your log)
//       if (data['type'] == 'active-bookings') {
//         final List active = data['activeBookings'] ?? [];
//         if (active.isEmpty) {
//           CommonLogger.log.w('⚠️ activeBookings empty, nothing to show');
//           return;
//         }
//
//         final booking = active.first;
//
//         _currentBookingId = booking['bookingId']?.toString();
//
//         final fromLat = (booking['fromLatitude'] as num?)?.toDouble();
//         final fromLng = (booking['fromLongitude'] as num?)?.toDouble();
//         final toLat = (booking['toLatitude'] as num?)?.toDouble();
//         final toLng = (booking['toLongitude'] as num?)?.toDouble();
//
//         if (fromLat == null ||
//             fromLng == null ||
//             toLat == null ||
//             toLng == null) {
//           CommonLogger.log.w(
//             '⚠️ Missing coords in activeBookings booking: $booking',
//           );
//           return;
//         }
//
//         final pickupAddr = await getAddressFromLatLng(fromLat, fromLng);
//         final dropAddr = await getAddressFromLatLng(toLat, toLng);
//
//         bookingController.showRequest(
//           rawData: booking, // 👈 or `data` if you need full wrapper
//           pickupAddress: pickupAddr,
//           dropAddress: dropAddr,
//         );
//         return; // ✅ don’t fall through to normal path
//       }
//
//       // 🔹 CASE 2: normal payload with pickupLocation / dropLocation
//       _currentBookingId = data['bookingId']?.toString();
//
//       final pickup = data['pickupLocation'];
//       final drop = data['dropLocation'];
//
//       if (pickup == null || drop == null) {
//         CommonLogger.log.w(
//           '⚠️ pickupLocation/dropLocation missing in booking-request: $data',
//         );
//         return;
//       }
//
//       final pickupLat = (pickup['latitude'] as num?)?.toDouble();
//       final pickupLng = (pickup['longitude'] as num?)?.toDouble();
//       final dropLat = (drop['latitude'] as num?)?.toDouble();
//       final dropLng = (drop['longitude'] as num?)?.toDouble();
//
//       if (pickupLat == null ||
//           pickupLng == null ||
//           dropLat == null ||
//           dropLng == null) {
//         CommonLogger.log.w(
//           '⚠️ latitude/longitude missing in pickup/drop: pickup=$pickup drop=$drop',
//         );
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
//     });
//
//     _initLocation(context);
//   }
//
//   Future<String> getAddressFromLatLng(double lat, double lng) async {
//     try {
//       List<Placemark> placemarks = await placemarkFromCoordinates(lat, lng);
//       Placemark place = placemarks[0];
//       return "${place.name}, ${place.locality}, ${place.administrativeArea}";
//     } catch (e) {
//       return "Location not available";
//     }
//   }
//
//   String formatCountdown(int seconds) {
//     final mins = (seconds ~/ 60).toString().padLeft(2, '0');
//     final secs = (seconds % 60).toString().padLeft(2, '0');
//     return "$mins:$secs";
//   }
//
//   double _bearingBetween(LatLng start, LatLng end) {
//     double lat1 = start.latitude * (pi / 180.0);
//     double lon1 = start.longitude * (pi / 180.0);
//     double lat2 = end.latitude * (pi / 180.0);
//     double lon2 = end.longitude * (pi / 180.0);
//
//     double dLon = lon2 - lon1;
//
//     double y = sin(dLon) * cos(lat2);
//     double x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon);
//
//     double brng = atan2(y, x);
//
//     return (brng * 180 / pi + 360) % 360;
//   }
//
//   @override
//   void initState() {
//     super.initState();
//
//     _animationController = AnimationController(
//       vsync: this,
//       duration: const Duration(milliseconds: 1500),
//     );
//
//     _animation = CurvedAnimation(
//       parent: _animationController!,
//       curve: Curves.easeInOut,
//     )..addListener(() {
//       if (!mounted) return;
//       if (_latTween == null || _lngTween == null || _rotationTween == null) {
//         return;
//       }
//
//       final lat = _latTween!.evaluate(_animation!);
//       final lng = _lngTween!.evaluate(_animation!);
//       final rotation = _rotationTween!.evaluate(_animation!);
//
//       setState(() {
//         _carMarker = Marker(
//           markerId: const MarkerId('car'),
//           position: LatLng(lat, lng),
//           icon: _carIcon ?? BitmapDescriptor.defaultMarker,
//           rotation: rotation,
//           anchor: const Offset(0.5, 0.5),
//           flat: true,
//         );
//       });
//     });
//
//     // 2️⃣ then your existing setup
//     _prepareApp();
//   }
//
//   Future<void> _prepareApp() async {
//     await statusController.getDriverStatus();
//
//     await _loadCustomCarIcon();
//
//     setState(() {});
//
//     _initSocketAndLocation();
//
//     SchedulerBinding.instance.addPostFrameCallback((_) {
//       statusController.weeklyChallenges();
//       statusController.todayActivity();
//       statusController.todayPackageActivity();
//     });
//   }
//
//   void _startTimer() {
//     _timer?.cancel();
//     remainingSeconds = 15;
//     _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
//       if (remainingSeconds > 0) {
//         setState(() {
//           remainingSeconds--;
//         });
//       } else {
//         timer.cancel();
//         setState(() {
//           bookingRequestData = null;
//         });
//       }
//     });
//   }
//
//   bool isonline = false;
//   bool status = true;
//
//   @override
//   Widget build(BuildContext context) {
//     return NoInternetOverlay(
//       child: WillPopScope(
//         onWillPop: () async {
//           return await true;
//         },
//         child: Scaffold(
//           body: SafeArea(
//             child: Padding(
//               padding: const EdgeInsets.symmetric(vertical: 20),
//               child: Column(
//                 children: [
//                   Padding(
//                     padding: const EdgeInsets.symmetric(horizontal: 15),
//                     child: Row(
//                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                       children: [
//                         InkWell(
//                           onTap: () {
//                             Get.to(DrawerScreen());
//                           },
//                           child: Image.asset(
//                             AppImages.drawer,
//                             height: 28,
//                             width: 28,
//                           ),
//                         ),
//
//                         GestureDetector(
//                           onTap: () async {
//                             statusController.toggleStatus();
//                             final isOnline = statusController.isOnline.value;
//                             Position position =
//                                 await Geolocator.getCurrentPosition(
//                                   desiredAccuracy: LocationAccuracy.high,
//                                 );
//                             statusController.onlineAcceptStatus(
//                               context,
//                               status: isOnline,
//                               latitude: position.latitude,
//                               longitude: position.longitude,
//                             );
//                           },
//                           // onTap: () => statusController.toggleStatus(),
//                           child: Obx(() {
//                             final isOnline = statusController.isOnline.value;
//
//                             return Container(
//                               padding: const EdgeInsets.symmetric(
//                                 horizontal: 9,
//                                 vertical: 5,
//                               ),
//                               decoration: BoxDecoration(
//                                 color:
//                                     isOnline ? AppColors.nBlue : Colors.black,
//                                 borderRadius: BorderRadius.circular(30),
//                                 boxShadow: [
//                                   BoxShadow(
//                                     color: Colors.black.withOpacity(0.25),
//                                     offset: const Offset(0, 4),
//                                     blurRadius: 10,
//                                   ),
//                                 ],
//                               ),
//                               child: Row(
//                                 mainAxisSize: MainAxisSize.min,
//                                 children:
//                                     isOnline
//                                         ? [
//                                           Text(
//                                             "Online",
//                                             style: TextStyle(
//                                               color: Colors.white,
//                                             ),
//                                           ),
//                                           const SizedBox(width: 12),
//                                           Container(
//                                             padding: const EdgeInsets.all(5),
//                                             decoration: const BoxDecoration(
//                                               color: Colors.white,
//                                               shape: BoxShape.circle,
//                                             ),
//                                             child: Image.asset(
//                                               AppImages.offlineCar,
//                                               width: 20,
//                                               height: 20,
//                                               color: AppColors.nBlue,
//                                             ),
//                                           ),
//                                         ]
//                                         : [
//                                           Container(
//                                             padding: const EdgeInsets.all(5),
//                                             decoration: const BoxDecoration(
//                                               color: Colors.white,
//                                               shape: BoxShape.circle,
//                                             ),
//                                             child: Image.asset(
//                                               AppImages.offlineCar,
//                                               width: 20,
//                                               height: 20,
//                                               color: Colors.black,
//                                             ),
//                                           ),
//                                           const SizedBox(width: 12),
//                                           Text(
//                                             "Offline",
//                                             style: TextStyle(
//                                               color: Colors.white,
//                                             ),
//                                           ),
//                                         ],
//                               ),
//                             );
//                           }),
//                         ),
//                         // Obx(() {
//                         //   final isOnline = statusController.isOnline.value;
//                         //   return Image.asset(
//                         //     AppImages.search,
//                         //     height: 28,
//                         //     width: 28,
//                         //     color: isOnline ? Colors.black : Colors.grey.shade400,
//                         //   );
//                         // }),
//                         Text(''),
//                         // Image.asset(AppImages.search, height: 28, width: 28),
//                       ],
//                     ),
//                   ),
//
//                   const SizedBox(height: 15),
//
//                   Expanded(
//                     child: Obx(
//                       () => IgnorePointer(
//                         ignoring: !statusController.isOnline.value,
//                         child: Opacity(
//                           opacity: statusController.isOnline.value ? 1.0 : 0.4,
//                           child: Stack(
//                             children: [
//                               SizedBox(
//                                 height: 350,
//                                 width: double.infinity,
//                                 child: GoogleMap(
//                                   compassEnabled: false,
//
//                                   initialCameraPosition: CameraPosition(
//                                     target: LatLng(0, 0),
//                                     zoom: 16,
//                                   ),
//
//                                   // onMapCreated: (controller) {
//                                   //   _mapController = controller;
//                                   //   _initLocation(context);
//                                   // },
//                                   onMapCreated: (controller) async {
//                                     _mapController = controller;
//                                     _initLocation(context);
//
//                                     String style = await DefaultAssetBundle.of(
//                                       context,
//                                     ).loadString(
//                                       'assets/map_style/map_style.json',
//                                     );
//                                     _mapController!.setMapStyle(style);
//                                   },
//                                   myLocationEnabled: false,
//                                   myLocationButtonEnabled: false,
//                                   zoomControlsEnabled: false,
//                                   markers:
//                                       _carMarker != null ? {_carMarker!} : {},
//                                   gestureRecognizers: {
//                                     Factory<OneSequenceGestureRecognizer>(
//                                       () => EagerGestureRecognizer(),
//                                     ),
//                                   },
//                                 ),
//                               ),
//
//                               Positioned(
//                                 top: 200,
//                                 right: 10,
//                                 child: FloatingActionButton(
//                                   mini: true,
//                                   backgroundColor: Colors.white,
//                                   onPressed: _goToCurrentLocation,
//                                   child: const Icon(
//                                     Icons.my_location,
//                                     color: Colors.black,
//                                   ),
//                                 ),
//                               ),
//
//                               if (statusController.serviceType == 'Car') ...[
//                                 DraggableScrollableSheet(
//                                   initialChildSize:
//                                       0.65, // Start with 80% height
//                                   minChildSize: 0.65,
//                                   maxChildSize:
//                                       0.9999, // Can expand up to 95% height
//                                   builder: (context, scrollController) {
//                                     return Container(
//                                       decoration: const BoxDecoration(
//                                         color: Colors.white,
//                                         // borderRadius: BorderRadius.vertical(
//                                         //   top: Radius.circular(20),
//                                         // ),
//                                       ),
//                                       child: RefreshIndicator(
//                                         onRefresh: () async {
//                                           await statusController
//                                               .weeklyChallenges();
//                                           await statusController
//                                               .todayActivity();
//                                         },
//                                         child: ListView(
//                                           physics:
//                                               const AlwaysScrollableScrollPhysics(
//                                                 parent: BouncingScrollPhysics(),
//                                               ), // Important!
//                                           controller: scrollController,
//                                           children: [
//                                             Center(
//                                               child: Container(
//                                                 width: 40,
//                                                 height: 4,
//                                                 margin: const EdgeInsets.only(
//                                                   top: 10,
//                                                 ),
//                                                 decoration: BoxDecoration(
//                                                   color: Colors.grey[400],
//                                                   borderRadius:
//                                                       BorderRadius.circular(10),
//                                                 ),
//                                               ),
//                                             ),
//
//                                             const SizedBox(height: 20),
//
//                                             GestureDetector(
//                                               onTap: () {},
//                                               child: Center(
//                                                 child:
//                                                     CustomTextfield.textWithStyles700(
//                                                       'Hoppr Car',
//                                                       color: AppColors
//                                                           .commonBlack
//                                                           .withOpacity(0.5),
//                                                     ),
//                                               ),
//                                             ),
//
//                                             Obx(() {
//                                               final data =
//                                                   bookingController
//                                                       .bookingRequestData
//                                                       .value;
//                                               if (data == null) {
//                                                 return const SizedBox.shrink();
//                                               }
//
//                                               final secondsText =
//                                                   bookingController
//                                                       .formatCountdown();
//
//                                               return Column(
//                                                 children: [
//                                                   Row(
//                                                     mainAxisAlignment:
//                                                         MainAxisAlignment
//                                                             .center,
//                                                     children: [
//                                                       Container(
//                                                         padding:
//                                                             const EdgeInsets.symmetric(
//                                                               horizontal: 10,
//                                                               vertical: 5,
//                                                             ),
//                                                         decoration: BoxDecoration(
//                                                           color: AppColors.red,
//                                                           borderRadius:
//                                                               BorderRadius.circular(
//                                                                 5,
//                                                               ),
//                                                         ),
//                                                         child: CustomTextfield.textWithStyles600(
//                                                           color:
//                                                               AppColors
//                                                                   .commonWhite,
//                                                           '${secondsText}s',
//                                                         ),
//                                                       ),
//                                                       const SizedBox(width: 15),
//                                                       const Text(
//                                                         "Respond within 15 seconds",
//                                                         style: TextStyle(
//                                                           fontWeight:
//                                                               FontWeight.w700,
//                                                         ),
//                                                       ),
//                                                     ],
//                                                   ),
//                                                   const SizedBox(height: 10),
//                                                   Card(
//                                                     elevation: 3,
//                                                     child: Container(
//                                                       decoration: BoxDecoration(
//                                                         color:
//                                                             AppColors
//                                                                 .commonWhite,
//                                                         borderRadius:
//                                                             BorderRadius.circular(
//                                                               10,
//                                                             ),
//                                                       ),
//                                                       child: Column(
//                                                         children: [
//                                                           // header
//                                                           Container(
//                                                             width:
//                                                                 double.infinity,
//                                                             height: 54,
//                                                             decoration: BoxDecoration(
//                                                               borderRadius:
//                                                                   const BorderRadius.only(
//                                                                     topLeft:
//                                                                         Radius.circular(
//                                                                           10,
//                                                                         ),
//                                                                     topRight:
//                                                                         Radius.circular(
//                                                                           10,
//                                                                         ),
//                                                                   ),
//                                                               color:
//                                                                   AppColors
//                                                                       .nBlue,
//                                                             ),
//                                                             child: Padding(
//                                                               padding:
//                                                                   const EdgeInsets.symmetric(
//                                                                     horizontal:
//                                                                         15,
//                                                                   ),
//                                                               child: Row(
//                                                                 children: [
//                                                                   Image.asset(
//                                                                     AppImages
//                                                                         .notification,
//                                                                     height: 25,
//                                                                     width: 25,
//                                                                   ),
//                                                                   const SizedBox(
//                                                                     width: 10,
//                                                                   ),
//                                                                   CustomTextfield.textWithStyles600(
//                                                                     data['rideType'] ==
//                                                                             'Bike'
//                                                                         ? 'New Package Request'
//                                                                         : 'New Ride Request',
//                                                                     color:
//                                                                         AppColors
//                                                                             .commonWhite,
//                                                                   ),
//                                                                   const Spacer(),
//                                                                   CustomTextfield.textWithImage(
//                                                                     imageColors:
//                                                                         AppColors
//                                                                             .commonWhite,
//                                                                     text:
//                                                                         '${data['estimatedPrice']}',
//                                                                     imagePath:
//                                                                         AppImages
//                                                                             .bCurrency,
//                                                                     colors:
//                                                                         AppColors
//                                                                             .commonWhite,
//                                                                     fontWeight:
//                                                                         FontWeight
//                                                                             .w700,
//                                                                   ),
//                                                                 ],
//                                                               ),
//                                                             ),
//                                                           ),
//
//                                                           // addresses
//                                                           Padding(
//                                                             padding:
//                                                                 const EdgeInsets.all(
//                                                                   8.0,
//                                                                 ),
//                                                             child: Column(
//                                                               children: [
//                                                                 Row(
//                                                                   children: [
//                                                                     const Icon(
//                                                                       Icons
//                                                                           .circle,
//                                                                       color:
//                                                                           Colors
//                                                                               .green,
//                                                                       size: 12,
//                                                                     ),
//                                                                     const SizedBox(
//                                                                       width: 8,
//                                                                     ),
//                                                                     Expanded(
//                                                                       child: Text(
//                                                                         data['pickupAddress'] ??
//                                                                             '',
//                                                                         maxLines:
//                                                                             2,
//                                                                         overflow:
//                                                                             TextOverflow.ellipsis,
//                                                                       ),
//                                                                     ),
//                                                                   ],
//                                                                 ),
//                                                                 const SizedBox(
//                                                                   height: 8,
//                                                                 ),
//                                                                 Row(
//                                                                   children: [
//                                                                     const Icon(
//                                                                       Icons
//                                                                           .circle,
//                                                                       color:
//                                                                           Colors
//                                                                               .red,
//                                                                       size: 12,
//                                                                     ),
//                                                                     const SizedBox(
//                                                                       width: 8,
//                                                                     ),
//                                                                     Expanded(
//                                                                       child: Text(
//                                                                         data['dropAddress'] ??
//                                                                             '',
//                                                                         maxLines:
//                                                                             2,
//                                                                         overflow:
//                                                                             TextOverflow.ellipsis,
//                                                                       ),
//                                                                     ),
//                                                                   ],
//                                                                 ),
//                                                               ],
//                                                             ),
//                                                           ),
//
//                                                           Padding(
//                                                             padding:
//                                                                 const EdgeInsets.symmetric(
//                                                                   horizontal:
//                                                                       15,
//                                                                 ),
//                                                             child: Divider(
//                                                               color: AppColors
//                                                                   .commonBlack
//                                                                   .withOpacity(
//                                                                     0.1,
//                                                                   ),
//                                                             ),
//                                                           ),
//
//                                                           // duration + distance
//                                                           Padding(
//                                                             padding:
//                                                                 const EdgeInsets.symmetric(
//                                                                   horizontal:
//                                                                       30,
//                                                                 ),
//                                                             child: Row(
//                                                               mainAxisAlignment:
//                                                                   MainAxisAlignment
//                                                                       .spaceAround,
//                                                               children: [
//                                                                 Row(
//                                                                   children: [
//                                                                     Image.asset(
//                                                                       AppImages
//                                                                           .time,
//                                                                       height:
//                                                                           20,
//                                                                       width: 20,
//                                                                     ),
//                                                                     const SizedBox(
//                                                                       width: 10,
//                                                                     ),
//                                                                     Text(
//                                                                       formatDuration(
//                                                                         safeToInt(
//                                                                           data['estimateDuration'],
//                                                                         ),
//                                                                       ),
//                                                                       style: const TextStyle(
//                                                                         fontWeight:
//                                                                             FontWeight.w500,
//                                                                       ),
//                                                                     ),
//                                                                   ],
//                                                                 ),
//                                                                 SizedBox(
//                                                                   height: 40,
//                                                                   child: VerticalDivider(
//                                                                     color: AppColors
//                                                                         .commonBlack
//                                                                         .withOpacity(
//                                                                           0.1,
//                                                                         ),
//                                                                   ),
//                                                                 ),
//                                                                 Row(
//                                                                   children: [
//                                                                     Image.asset(
//                                                                       AppImages
//                                                                           .distance,
//                                                                       height:
//                                                                           20,
//                                                                       width: 20,
//                                                                     ),
//                                                                     const SizedBox(
//                                                                       width: 10,
//                                                                     ),
//                                                                     Text(
//                                                                       formatDistance(
//                                                                         safeToDouble(
//                                                                           data['estimatedDistance'],
//                                                                         ),
//                                                                       ),
//                                                                       style: const TextStyle(
//                                                                         fontWeight:
//                                                                             FontWeight.w500,
//                                                                       ),
//                                                                     ),
//                                                                   ],
//                                                                 ),
//                                                               ],
//                                                             ),
//                                                           ),
//
//                                                           Padding(
//                                                             padding:
//                                                                 const EdgeInsets.symmetric(
//                                                                   horizontal:
//                                                                       15,
//                                                                 ),
//                                                             child: Divider(
//                                                               color: AppColors
//                                                                   .commonBlack
//                                                                   .withOpacity(
//                                                                     0.1,
//                                                                   ),
//                                                             ),
//                                                           ),
//
//                                                           // buttons
//                                                           Padding(
//                                                             padding:
//                                                                 const EdgeInsets.symmetric(
//                                                                   horizontal:
//                                                                       8.0,
//                                                                   vertical: 10,
//                                                                 ),
//                                                             child: Row(
//                                                               children: [
//                                                                 // DECLINE
//                                                                 Expanded(
//                                                                   child: Buttons.button(
//                                                                     borderRadius:
//                                                                         10,
//                                                                     buttonColor:
//                                                                         AppColors
//                                                                             .red,
//                                                                     onTap:
//                                                                         statusController.isLoading.value
//                                                                             ? null
//                                                                             : () {
//                                                                               final id =
//                                                                                   data['bookingId']?.toString();
//                                                                               if (id !=
//                                                                                   null) {
//                                                                                 bookingController.markHandled(
//                                                                                   id,
//                                                                                 );
//                                                                               } else {
//                                                                                 bookingController.clear();
//                                                                               }
//                                                                               // just hide popup (optionally call REJECT API)
//                                                                             },
//                                                                     text: const Text(
//                                                                       'Decline',
//                                                                     ),
//                                                                   ),
//                                                                 ),
//                                                                 const SizedBox(
//                                                                   width: 20,
//                                                                 ),
//
//                                                                 Obx(() {
//                                                                   return Expanded(
//                                                                     child: Buttons.button(
//                                                                       borderRadius:
//                                                                           10,
//                                                                       buttonColor:
//                                                                           AppColors
//                                                                               .drkGreen,
//                                                                       onTap:
//                                                                           statusController.isLoading.value
//                                                                               ? null
//                                                                               : () async {
//                                                                                 try {
//                                                                                   final bookingId =
//                                                                                       data['bookingId'];
//                                                                                   final pickupAddress =
//                                                                                       data['pickupAddress'] ??
//                                                                                       '';
//                                                                                   final dropAddress =
//                                                                                       data['dropAddress'] ??
//                                                                                       '';
//
//                                                                                   final pickup = LatLng(
//                                                                                     data['pickupLocation']['latitude']
//                                                                                         as double,
//                                                                                     data['pickupLocation']['longitude']
//                                                                                         as double,
//                                                                                   );
//
//                                                                                   final position = await Geolocator.getCurrentPosition(
//                                                                                     desiredAccuracy:
//                                                                                         LocationAccuracy.high,
//                                                                                   );
//
//                                                                                   final driverLocation = LatLng(
//                                                                                     position.latitude,
//                                                                                     position.longitude,
//                                                                                   );
//
//                                                                                   await statusController.bookingAccept(
//                                                                                     pickupLocationAddress:
//                                                                                         pickupAddress,
//                                                                                     dropLocationAddress:
//                                                                                         dropAddress,
//                                                                                     context,
//                                                                                     bookingId:
//                                                                                         bookingId,
//                                                                                     status:
//                                                                                         'ACCEPT',
//                                                                                     pickupLocation:
//                                                                                         pickup,
//                                                                                     driverLocation:
//                                                                                         driverLocation,
//                                                                                   );
//
//                                                                                   bookingController.markHandled(
//                                                                                     bookingId.toString(),
//                                                                                   );
//                                                                                 } catch (
//                                                                                   e
//                                                                                 ) {
//                                                                                   bookingController.clear();
//                                                                                   CommonLogger.log.e(
//                                                                                     "Booking accept failed: $e",
//                                                                                   );
//                                                                                 }
//                                                                               },
//                                                                       text:
//                                                                           statusController.isLoading.value
//                                                                               ? SizedBox(
//                                                                                 height:
//                                                                                     20,
//                                                                                 width:
//                                                                                     20,
//                                                                                 child:
//                                                                                     AppLoader.circularLoader(),
//                                                                               )
//                                                                               : const Text(
//                                                                                 'Accept',
//                                                                               ),
//                                                                     ),
//                                                                   );
//                                                                 }),
//                                                               ],
//                                                             ),
//                                                           ),
//                                                         ],
//                                                       ),
//                                                     ),
//                                                   ),
//                                                 ],
//                                               );
//                                             }),
//                                             statusController.isOnline.value
//                                                 ? SizedBox.shrink()
//                                                 : GestureDetector(
//                                                   onTap: () {},
//                                                   child: Container(
//                                                     width: double.infinity,
//                                                     height: 54,
//                                                     decoration: BoxDecoration(
//                                                       color:
//                                                           AppColors.commonBlack,
//                                                     ),
//                                                     child: Row(
//                                                       mainAxisAlignment:
//                                                           MainAxisAlignment
//                                                               .center,
//                                                       children: [
//                                                         Image.asset(
//                                                           AppImages.graph,
//                                                           color:
//                                                               AppColors
//                                                                   .commonWhite,
//                                                           height: 20,
//                                                           width: 20,
//                                                         ),
//
//                                                         SizedBox(width: 10),
//                                                         CustomTextfield.textWithStyles600(
//                                                           fontSize: 13,
//                                                           color:
//                                                               AppColors
//                                                                   .commonWhite,
//                                                           'Requests are Surging - Go Online Now!',
//                                                         ),
//                                                       ],
//                                                     ),
//                                                   ),
//                                                 ),
//                                             const SizedBox(height: 20),
//
//                                             Padding(
//                                               padding:
//                                                   const EdgeInsets.symmetric(
//                                                     horizontal: 17,
//                                                   ),
//                                               child: Column(
//                                                 crossAxisAlignment:
//                                                     CrossAxisAlignment.start,
//                                                 children: [
//                                                   CustomTextfield.textWithStyles700(
//                                                     'Weekly Challenges',
//                                                     fontSize: 16,
//                                                     color: getTextColor(),
//                                                   ),
//                                                   const SizedBox(height: 10),
//                                                   Container(
//                                                     decoration: BoxDecoration(
//                                                       borderRadius:
//                                                           BorderRadius.circular(
//                                                             10,
//                                                           ),
//                                                       border: Border.all(
//                                                         color: AppColors
//                                                             .commonBlack
//                                                             .withOpacity(0.1),
//                                                       ),
//                                                     ),
//                                                     child: Padding(
//                                                       padding:
//                                                           const EdgeInsets.symmetric(
//                                                             horizontal: 15,
//                                                             vertical: 22,
//                                                           ),
//                                                       child: Obx(() {
//                                                         final weeklyData =
//                                                             statusController
//                                                                 .weeklyStatusData
//                                                                 .value;
//                                                         final serviceType =
//                                                             statusController
//                                                                 .serviceType
//                                                                 .value;
//                                                         return Row(
//                                                           crossAxisAlignment:
//                                                               CrossAxisAlignment
//                                                                   .start,
//                                                           children: [
//                                                             Expanded(
//                                                               child: Column(
//                                                                 crossAxisAlignment:
//                                                                     CrossAxisAlignment
//                                                                         .start,
//                                                                 children: [
//                                                                   CustomTextfield.textWithStylesSmall(
//                                                                     'Ends on Monday',
//                                                                     colors:
//                                                                         AppColors
//                                                                             .grey,
//                                                                     fontWeight:
//                                                                         FontWeight
//                                                                             .w500,
//                                                                   ),
//                                                                   const SizedBox(
//                                                                     height: 5,
//                                                                   ),
//                                                                   CustomTextfield.textWithStyles600(
//                                                                     'Complete ${weeklyData?.goal.toString() ?? ''} trips and get ${weeklyData?.reward.toString() ?? ''} extra',
//                                                                     fontSize:
//                                                                         17,
//                                                                   ),
//                                                                   const SizedBox(
//                                                                     height: 5,
//                                                                   ),
//                                                                   CustomTextfield.textWithStylesSmall(
//                                                                     colors: getTextColor(
//                                                                       color:
//                                                                           AppColors
//                                                                               .drkGreen,
//                                                                     ),
//
//                                                                     '${weeklyData?.totalTrips.toString() ?? ''} trips done out of 20',
//                                                                     fontWeight:
//                                                                         FontWeight
//                                                                             .w500,
//                                                                   ),
//                                                                 ],
//                                                               ),
//                                                             ),
//                                                             const SizedBox(
//                                                               width: 15,
//                                                             ),
//                                                             CircularPercentIndicator(
//                                                               radius: 45.0,
//                                                               lineWidth: 10.0,
//                                                               animation: true,
//                                                               percent:
//                                                                   (weeklyData
//                                                                           ?.progressPercent ??
//                                                                       0) /
//                                                                   100,
//                                                               center: Text(
//                                                                 "${weeklyData?.progressPercent.toString() ?? ''}%",
//                                                                 style: TextStyle(
//                                                                   fontWeight:
//                                                                       FontWeight
//                                                                           .w600,
//                                                                 ),
//                                                               ),
//                                                               circularStrokeCap:
//                                                                   CircularStrokeCap
//                                                                       .round,
//                                                               backgroundColor:
//                                                                   AppColors
//                                                                       .drkGreen
//                                                                       .withOpacity(
//                                                                         0.1,
//                                                                       ),
//                                                               progressColor:
//                                                                   getTextColor(
//                                                                     color:
//                                                                         AppColors
//                                                                             .drkGreen,
//                                                                   ),
//                                                             ),
//                                                           ],
//                                                         );
//                                                       }),
//                                                     ),
//                                                   ),
//
//                                                   const SizedBox(height: 20),
//                                                   CustomTextfield.textWithStyles700(
//                                                     "Today's Activity",
//                                                     fontSize: 16,
//                                                   ),
//                                                   const SizedBox(height: 10),
//                                                   Container(
//                                                     decoration: BoxDecoration(
//                                                       borderRadius:
//                                                           BorderRadius.circular(
//                                                             10,
//                                                           ),
//                                                       border: Border.all(
//                                                         color: AppColors
//                                                             .commonBlack
//                                                             .withOpacity(0.1),
//                                                       ),
//                                                     ),
//                                                     child: Padding(
//                                                       padding:
//                                                           const EdgeInsets.symmetric(
//                                                             horizontal: 25,
//                                                             vertical: 15,
//                                                           ),
//                                                       child: Obx(() {
//                                                         final data =
//                                                             statusController
//                                                                 .todayStatusData
//                                                                 .value;
//                                                         return Row(
//                                                           mainAxisAlignment:
//                                                               MainAxisAlignment
//                                                                   .spaceBetween,
//                                                           children: [
//                                                             Column(
//                                                               children: [
//                                                                 CustomTextfield.textWithStyles600(
//                                                                   'Earnings',
//                                                                   color:
//                                                                       AppColors
//                                                                           .grey,
//                                                                 ),
//                                                                 CustomTextfield.textWithImage(
//                                                                   text:
//                                                                       data?.earnings
//                                                                           .toString() ??
//                                                                       '',
//                                                                   colors:
//                                                                       AppColors
//                                                                           .commonBlack,
//                                                                   fontWeight:
//                                                                       FontWeight
//                                                                           .w700,
//                                                                   fontSize: 16,
//                                                                   imagePath:
//                                                                       AppImages
//                                                                           .bCurrency,
//                                                                 ),
//                                                               ],
//                                                             ),
//
//                                                             SizedBox(
//                                                               height: 50,
//                                                               child: VerticalDivider(
//                                                                 color: AppColors
//                                                                     .commonBlack
//                                                                     .withOpacity(
//                                                                       0.2,
//                                                                     ),
//                                                               ),
//                                                             ),
//
//                                                             Column(
//                                                               children: [
//                                                                 CustomTextfield.textWithStyles600(
//                                                                   'Online',
//                                                                   color:
//                                                                       AppColors
//                                                                           .grey,
//                                                                 ),
//                                                                 CustomTextfield.textWithImage(
//                                                                   colors:
//                                                                       AppColors
//                                                                           .commonBlack,
//                                                                   fontWeight:
//                                                                       FontWeight
//                                                                           .w700,
//                                                                   fontSize: 16,
//                                                                   text:
//                                                                       data?.online
//                                                                           .toString() ??
//                                                                       '',
//                                                                 ),
//                                                               ],
//                                                             ),
//
//                                                             SizedBox(
//                                                               height: 50,
//                                                               child: VerticalDivider(
//                                                                 color: AppColors
//                                                                     .commonBlack
//                                                                     .withOpacity(
//                                                                       0.2,
//                                                                     ),
//                                                               ),
//                                                             ),
//
//                                                             Column(
//                                                               children: [
//                                                                 CustomTextfield.textWithStyles600(
//                                                                   'Rides',
//                                                                   color:
//                                                                       AppColors
//                                                                           .grey,
//                                                                 ),
//
//                                                                 CustomTextfield.textWithImage(
//                                                                   text:
//                                                                       data?.rides
//                                                                           .toString() ??
//                                                                       '',
//                                                                   colors:
//                                                                       AppColors
//                                                                           .commonBlack,
//                                                                   fontWeight:
//                                                                       FontWeight
//                                                                           .w700,
//                                                                   fontSize: 16,
//                                                                 ),
//                                                               ],
//                                                             ),
//                                                           ],
//                                                         );
//                                                       }),
//                                                     ),
//                                                   ),
//
//                                                   const SizedBox(height: 20),
//                                                 ],
//                                               ),
//                                             ),
//                                           ],
//                                         ),
//                                       ),
//                                     );
//                                   },
//                                 ),
//                               ] else ...[
//                                 DraggableScrollableSheet(
//                                   initialChildSize: 0.65,
//                                   minChildSize: 0.62,
//                                   maxChildSize: 1.0,
//
//                                   builder: (context, scrollController) {
//                                     return Container(
//                                       decoration: const BoxDecoration(
//                                         color: Colors.white,
//                                         // borderRadius: BorderRadius.vertical(
//                                         //   top: Radius.circular(20),
//                                         // ),
//                                       ),
//                                       child: RefreshIndicator(
//                                         onRefresh: () async {
//                                           await statusController
//                                               .weeklyChallenges();
//                                           await statusController
//                                               .todayPackageActivity();
//                                         },
//                                         child: ListView(
//                                           physics:
//                                               AlwaysScrollableScrollPhysics(
//                                                 parent: BouncingScrollPhysics(),
//                                               ),
//                                           controller: scrollController,
//                                           children: [
//                                             Center(
//                                               child: Container(
//                                                 width: 40,
//                                                 height: 4,
//                                                 margin: const EdgeInsets.only(
//                                                   top: 10,
//                                                 ),
//                                                 decoration: BoxDecoration(
//                                                   color: Colors.grey[400],
//                                                   borderRadius:
//                                                       BorderRadius.circular(10),
//                                                 ),
//                                               ),
//                                             ),
//
//                                             const SizedBox(height: 20),
//                                             if (bookingRequestData != null) ...[
//                                               Column(
//                                                 children: [
//                                                   Row(
//                                                     mainAxisAlignment:
//                                                         MainAxisAlignment
//                                                             .center,
//                                                     children: [
//                                                       Container(
//                                                         padding:
//                                                             EdgeInsets.symmetric(
//                                                               horizontal: 10,
//                                                               vertical: 5,
//                                                             ),
//                                                         decoration: BoxDecoration(
//                                                           color: AppColors.red,
//                                                           borderRadius:
//                                                               BorderRadius.circular(
//                                                                 5,
//                                                               ),
//                                                         ),
//                                                         child: CustomTextfield.textWithStyles600(
//                                                           color:
//                                                               AppColors
//                                                                   .commonWhite,
//                                                           '${formatCountdown(remainingSeconds)} ',
//                                                         ),
//                                                       ),
//                                                       SizedBox(width: 15),
//                                                       Text(
//                                                         "Respond within 15 seconds",
//                                                         style: TextStyle(
//                                                           fontWeight:
//                                                               FontWeight.w700,
//                                                         ),
//                                                       ),
//                                                     ],
//                                                   ),
//                                                   SizedBox(height: 10),
//                                                   Card(
//                                                     elevation: 3,
//                                                     child: Container(
//                                                       decoration: BoxDecoration(
//                                                         color:
//                                                             AppColors
//                                                                 .commonWhite,
//                                                         borderRadius:
//                                                             BorderRadius.circular(
//                                                               10,
//                                                             ),
//                                                       ),
//
//                                                       child: Column(
//                                                         children: [
//                                                           Container(
//                                                             width:
//                                                                 double.infinity,
//                                                             height: 54,
//                                                             decoration: BoxDecoration(
//                                                               borderRadius:
//                                                                   BorderRadius.only(
//                                                                     topLeft:
//                                                                         Radius.circular(
//                                                                           10,
//                                                                         ),
//                                                                     topRight:
//                                                                         Radius.circular(
//                                                                           10,
//                                                                         ),
//                                                                   ),
//                                                               color:
//                                                                   AppColors
//                                                                       .nBlue,
//                                                             ),
//                                                             child: Padding(
//                                                               padding:
//                                                                   const EdgeInsets.symmetric(
//                                                                     horizontal:
//                                                                         15,
//                                                                   ),
//                                                               child: Row(
//                                                                 children: [
//                                                                   Image.asset(
//                                                                     AppImages
//                                                                         .notification,
//                                                                     height: 25,
//                                                                     width: 25,
//                                                                   ),
//                                                                   SizedBox(
//                                                                     width: 10,
//                                                                   ),
//                                                                   CustomTextfield.textWithStyles600(
//                                                                     bookingRequestData!['rideType'] ==
//                                                                             'Bike'
//                                                                         ? 'New Package Request'
//                                                                         : 'New Ride Request',
//                                                                     color:
//                                                                         AppColors
//                                                                             .commonWhite,
//                                                                   ),
//
//                                                                   Spacer(),
//                                                                   CustomTextfield.textWithImage(
//                                                                     imageColors:
//                                                                         AppColors
//                                                                             .commonWhite,
//                                                                     text:
//                                                                         '${bookingRequestData!['estimatedPrice']}',
//                                                                     imagePath:
//                                                                         AppImages
//                                                                             .bCurrency,
//                                                                     colors:
//                                                                         AppColors
//                                                                             .commonWhite,
//                                                                     fontWeight:
//                                                                         FontWeight
//                                                                             .w700,
//                                                                   ),
//                                                                 ],
//                                                               ),
//                                                             ),
//                                                           ),
//                                                           Padding(
//                                                             padding:
//                                                                 const EdgeInsets.all(
//                                                                   8.0,
//                                                                 ),
//                                                             child: Column(
//                                                               children: [
//                                                                 Row(
//                                                                   children: [
//                                                                     Icon(
//                                                                       Icons
//                                                                           .circle,
//                                                                       color:
//                                                                           Colors
//                                                                               .green,
//                                                                       size: 12,
//                                                                     ),
//                                                                     SizedBox(
//                                                                       width: 8,
//                                                                     ),
//                                                                     Expanded(
//                                                                       child: Text(
//                                                                         bookingRequestData!['pickupAddress'] ??
//                                                                             '',
//                                                                       ),
//                                                                     ),
//                                                                   ],
//                                                                 ),
//                                                                 const SizedBox(
//                                                                   height: 8,
//                                                                 ),
//                                                                 Row(
//                                                                   children: [
//                                                                     Icon(
//                                                                       Icons
//                                                                           .circle,
//                                                                       color:
//                                                                           Colors
//                                                                               .red,
//                                                                       size: 12,
//                                                                     ),
//                                                                     SizedBox(
//                                                                       width: 8,
//                                                                     ),
//                                                                     Expanded(
//                                                                       child: Text(
//                                                                         bookingRequestData!['dropAddress'] ??
//                                                                             "",
//                                                                       ),
//                                                                     ),
//                                                                   ],
//                                                                 ),
//                                                               ],
//                                                             ),
//                                                           ),
//
//                                                           Padding(
//                                                             padding:
//                                                                 const EdgeInsets.symmetric(
//                                                                   horizontal:
//                                                                       15,
//                                                                 ),
//                                                             child: Divider(
//                                                               color: AppColors
//                                                                   .commonBlack
//                                                                   .withOpacity(
//                                                                     0.1,
//                                                                   ),
//                                                             ),
//                                                           ),
//
//                                                           Padding(
//                                                             padding:
//                                                                 const EdgeInsets.symmetric(
//                                                                   horizontal:
//                                                                       30,
//                                                                 ),
//                                                             child: Row(
//                                                               mainAxisAlignment:
//                                                                   MainAxisAlignment
//                                                                       .spaceAround,
//                                                               children: [
//                                                                 // Row(
//                                                                 //   children: [
//                                                                 //     Icon(
//                                                                 //       Icons
//                                                                 //           .person_outline,
//                                                                 //       color:
//                                                                 //           AppColors.nBlue,
//                                                                 //     ),
//                                                                 //     const SizedBox(
//                                                                 //       width: 10,
//                                                                 //     ),
//                                                                 //     Text(
//                                                                 //       '${bookingRequestData!['sharedCount']}',
//                                                                 //       style: TextStyle(
//                                                                 //         fontWeight:
//                                                                 //             FontWeight
//                                                                 //                 .w500,
//                                                                 //       ),
//                                                                 //     ),
//                                                                 //   ],
//                                                                 // ),
//                                                                 // SizedBox(
//                                                                 //   height: 40,
//                                                                 //   child: VerticalDivider(
//                                                                 //     color: AppColors
//                                                                 //         .commonBlack
//                                                                 //         .withOpacity(0.1),
//                                                                 //   ),
//                                                                 // ),
//                                                                 Row(
//                                                                   children: [
//                                                                     Image.asset(
//                                                                       AppImages
//                                                                           .time,
//                                                                       height:
//                                                                           20,
//                                                                       width: 20,
//                                                                     ),
//                                                                     const SizedBox(
//                                                                       width: 10,
//                                                                     ),
//                                                                     Text(
//                                                                       formatDuration(
//                                                                         safeToInt(
//                                                                           bookingRequestData?['estimateDuration'],
//                                                                         ),
//                                                                       ),
//                                                                       style: TextStyle(
//                                                                         fontWeight:
//                                                                             FontWeight.w500,
//                                                                       ),
//                                                                     ),
//                                                                   ],
//                                                                 ),
//                                                                 SizedBox(
//                                                                   height: 40,
//                                                                   child: VerticalDivider(
//                                                                     color: AppColors
//                                                                         .commonBlack
//                                                                         .withOpacity(
//                                                                           0.1,
//                                                                         ),
//                                                                   ),
//                                                                 ),
//                                                                 Row(
//                                                                   children: [
//                                                                     Image.asset(
//                                                                       AppImages
//                                                                           .distance,
//                                                                       height:
//                                                                           20,
//                                                                       width: 20,
//                                                                     ),
//                                                                     const SizedBox(
//                                                                       width: 10,
//                                                                     ),
//                                                                     Text(
//                                                                       formatDistance(
//                                                                         safeToDouble(
//                                                                           bookingRequestData?['estimatedDistance'],
//                                                                         ),
//                                                                       ),
//                                                                       style: TextStyle(
//                                                                         fontWeight:
//                                                                             FontWeight.w500,
//                                                                       ),
//                                                                     ),
//                                                                   ],
//                                                                 ),
//                                                               ],
//                                                             ),
//                                                           ),
//                                                           Padding(
//                                                             padding:
//                                                                 const EdgeInsets.symmetric(
//                                                                   horizontal:
//                                                                       15,
//                                                                 ),
//                                                             child: Divider(
//                                                               color: AppColors
//                                                                   .commonBlack
//                                                                   .withOpacity(
//                                                                     0.1,
//                                                                   ),
//                                                             ),
//                                                           ),
//
//                                                           Padding(
//                                                             padding:
//                                                                 const EdgeInsets.symmetric(
//                                                                   horizontal:
//                                                                       8.0,
//                                                                   vertical: 10,
//                                                                 ),
//                                                             child: Row(
//                                                               children: [
//                                                                 Expanded(
//                                                                   child: Buttons.button(
//                                                                     borderRadius:
//                                                                         10,
//                                                                     buttonColor:
//                                                                         AppColors
//                                                                             .red,
//                                                                     onTap:
//                                                                         statusController.isLoading.value
//                                                                             ? null
//                                                                             : () {
//                                                                               final bookingId =
//                                                                                   bookingRequestData!['bookingId'];
//                                                                               CommonLogger.log.i(
//                                                                                 bookingId,
//                                                                               );
//
//                                                                               // Get.to(
//                                                                               //   PickingCustomerScreen(),
//                                                                               // );
//                                                                               // statusController
//                                                                               //     .bookingAccept(
//                                                                               //       context,
//                                                                               //       bookingId:
//                                                                               //           bookingId,
//                                                                               //       status:
//                                                                               //           'REJECT',
//                                                                               //
//                                                                               //
//                                                                               //     );
//                                                                               setState(
//                                                                                 () {
//                                                                                   bookingRequestData =
//                                                                                       null;
//                                                                                 },
//                                                                               );
//                                                                             },
//                                                                     text: Text(
//                                                                       'Decline',
//                                                                     ),
//                                                                   ),
//                                                                 ),
//                                                                 SizedBox(
//                                                                   width: 20,
//                                                                 ),
//                                                                 Obx(() {
//                                                                   return Expanded(
//                                                                     child: Buttons.button(
//                                                                       borderRadius:
//                                                                           10,
//                                                                       buttonColor:
//                                                                           AppColors
//                                                                               .drkGreen,
//                                                                       onTap:
//                                                                           statusController.isLoading.value
//                                                                               ? null
//                                                                               : () async {
//                                                                                 try {
//                                                                                   final bookingId =
//                                                                                       bookingRequestData!['bookingId'];
//                                                                                   final address =
//                                                                                       bookingRequestData!['pickupAddress'] ??
//                                                                                       '';
//
//                                                                                   final dropAddress =
//                                                                                       bookingRequestData!['dropAddress'] ??
//                                                                                       '';
//
//                                                                                   final pickup = LatLng(
//                                                                                     bookingRequestData!['pickupLocation']['latitude'],
//                                                                                     bookingRequestData!['pickupLocation']['longitude'],
//                                                                                   );
//
//                                                                                   final position = await Geolocator.getCurrentPosition(
//                                                                                     desiredAccuracy:
//                                                                                         LocationAccuracy.high,
//                                                                                   );
//
//                                                                                   final driverLocation = LatLng(
//                                                                                     position.latitude,
//                                                                                     position.longitude,
//                                                                                   );
//
//                                                                                   await statusController.bookingAccept(
//                                                                                     pickupLocationAddress:
//                                                                                         address,
//                                                                                     dropLocationAddress:
//                                                                                         dropAddress,
//
//                                                                                     context,
//                                                                                     bookingId:
//                                                                                         bookingId,
//                                                                                     status:
//                                                                                         'ACCEPT',
//                                                                                     pickupLocation:
//                                                                                         pickup,
//                                                                                     driverLocation:
//                                                                                         driverLocation,
//                                                                                   );
//                                                                                   setState(
//                                                                                     () {
//                                                                                       bookingRequestData =
//                                                                                           null;
//                                                                                     },
//                                                                                   );
//                                                                                 } catch (
//                                                                                   e
//                                                                                 ) {
//                                                                                   CommonLogger.log.e(
//                                                                                     "Booking accept failed: $e",
//                                                                                   );
//                                                                                 }
//                                                                               },
//                                                                       text:
//                                                                           statusController.isLoading.value
//                                                                               ? SizedBox(
//                                                                                 height:
//                                                                                     20,
//                                                                                 width:
//                                                                                     20,
//                                                                                 child:
//                                                                                     AppLoader.circularLoader(),
//                                                                               )
//                                                                               : Text(
//                                                                                 'Accept',
//                                                                               ),
//                                                                     ),
//                                                                   );
//                                                                 }),
//                                                               ],
//                                                             ),
//                                                           ),
//                                                         ],
//                                                       ),
//                                                     ),
//                                                   ),
//                                                 ],
//                                               ),
//                                             ] else
//                                               ...[],
//                                             statusController.isOnline.value
//                                                 ? SizedBox.shrink()
//                                                 : GestureDetector(
//                                                   onTap: () {},
//                                                   child: Container(
//                                                     width: double.infinity,
//                                                     height: 54,
//                                                     decoration: BoxDecoration(
//                                                       color:
//                                                           AppColors.commonBlack,
//                                                     ),
//                                                     child: Row(
//                                                       mainAxisAlignment:
//                                                           MainAxisAlignment
//                                                               .center,
//                                                       children: [
//                                                         Image.asset(
//                                                           AppImages.graph,
//                                                           color:
//                                                               AppColors
//                                                                   .commonWhite,
//                                                           height: 20,
//                                                           width: 20,
//                                                         ),
//
//                                                         SizedBox(width: 10),
//                                                         CustomTextfield.textWithStyles600(
//                                                           fontSize: 13,
//                                                           color:
//                                                               AppColors
//                                                                   .commonWhite,
//                                                           'Requests are Surging - Go Online Now!',
//                                                         ),
//                                                       ],
//                                                     ),
//                                                   ),
//                                                 ),
//
//                                             Center(
//                                               child: Opacity(
//                                                 opacity:
//                                                     0.7, // 👈 0.0 = fully transparent, 1.0 = fully opaque
//                                                 child: Image.asset(
//                                                   AppImages.hopprPackage,
//                                                   height: 25,
//                                                 ),
//                                               ),
//                                             ),
//
//                                             const SizedBox(height: 20),
//                                             Padding(
//                                               padding:
//                                                   const EdgeInsets.symmetric(
//                                                     horizontal: 17,
//                                                   ),
//                                               child: Column(
//                                                 crossAxisAlignment:
//                                                     CrossAxisAlignment.start,
//                                                 children: [
//                                                   CustomTextfield.textWithStyles700(
//                                                     "Today's Activity",
//                                                     fontSize: 16,
//                                                   ),
//                                                   const SizedBox(height: 10),
//                                                   Container(
//                                                     decoration: BoxDecoration(
//                                                       borderRadius:
//                                                           BorderRadius.circular(
//                                                             10,
//                                                           ),
//                                                     ),
//                                                     child: Padding(
//                                                       padding:
//                                                           const EdgeInsets.symmetric(
//                                                             horizontal: 25,
//                                                             vertical: 15,
//                                                           ),
//                                                       child: Obx(() {
//                                                         final data =
//                                                             statusController
//                                                                 .parcelBookingData
//                                                                 .value;
//                                                         return Row(
//                                                           children: [
//                                                             Expanded(
//                                                               flex: 2,
//                                                               child: Column(
//                                                                 children: [
//                                                                   Container(
//                                                                     padding: EdgeInsets.symmetric(
//                                                                       horizontal:
//                                                                           10,
//                                                                       vertical:
//                                                                           10,
//                                                                     ),
//                                                                     decoration: BoxDecoration(
//                                                                       color: const Color(
//                                                                         0xFFE2FBE9,
//                                                                       ),
//                                                                       shape:
//                                                                           BoxShape
//                                                                               .circle,
//                                                                     ),
//                                                                     child: Image.asset(
//                                                                       height:
//                                                                           17,
//                                                                       AppImages
//                                                                           .bCurrency,
//                                                                       color: Color(
//                                                                         0xff009721,
//                                                                       ),
//                                                                     ),
//                                                                   ),
//                                                                   SizedBox(
//                                                                     height: 5,
//                                                                   ),
//                                                                   CustomTextfield.textWithImage(
//                                                                     text: (data?.earning ??
//                                                                             0)
//                                                                         .toStringAsFixed(
//                                                                           2,
//                                                                         ),
//                                                                     colors:
//                                                                         AppColors
//                                                                             .commonBlack,
//                                                                     fontWeight:
//                                                                         FontWeight
//                                                                             .w700,
//                                                                     fontSize:
//                                                                         15,
//                                                                     imagePath:
//                                                                         AppImages
//                                                                             .bCurrency,
//                                                                   ),
//
//                                                                   SizedBox(
//                                                                     height: 5,
//                                                                   ),
//                                                                   CustomTextfield.textWithStylesSmall(
//                                                                     'Earnings',
//                                                                     colors:
//                                                                         AppColors
//                                                                             .grey,
//                                                                   ),
//                                                                 ],
//                                                               ),
//                                                             ),
//                                                             Spacer(),
//                                                             Expanded(
//                                                               flex: 1,
//                                                               child: Column(
//                                                                 children: [
//                                                                   Container(
//                                                                     padding: EdgeInsets.symmetric(
//                                                                       horizontal:
//                                                                           10,
//                                                                       vertical:
//                                                                           10,
//                                                                     ),
//                                                                     decoration: BoxDecoration(
//                                                                       color: const Color(
//                                                                         0XFFDEEAFC,
//                                                                       ),
//                                                                       shape:
//                                                                           BoxShape
//                                                                               .circle,
//                                                                     ),
//                                                                     child: Image.asset(
//                                                                       height:
//                                                                           17,
//                                                                       AppImages
//                                                                           .boxLine,
//                                                                     ),
//                                                                   ),
//                                                                   SizedBox(
//                                                                     height: 5,
//                                                                   ),
//                                                                   CustomTextfield.textWithImage(
//                                                                     colors:
//                                                                         AppColors
//                                                                             .commonBlack,
//                                                                     fontWeight:
//                                                                         FontWeight
//                                                                             .w700,
//                                                                     fontSize:
//                                                                         16,
//                                                                     text:
//                                                                         data?.completed
//                                                                             .toString() ??
//                                                                         '0',
//                                                                   ),
//                                                                   SizedBox(
//                                                                     height: 5,
//                                                                   ),
//                                                                   CustomTextfield.textWithStylesSmall(
//                                                                     'Deliveries',
//                                                                     colors:
//                                                                         AppColors
//                                                                             .grey,
//                                                                     maxLine: 1,
//                                                                   ),
//                                                                 ],
//                                                               ),
//                                                             ),
//                                                             Spacer(),
//                                                             Expanded(
//                                                               flex: 1,
//                                                               child: Column(
//                                                                 children: [
//                                                                   Container(
//                                                                     padding: EdgeInsets.symmetric(
//                                                                       horizontal:
//                                                                           10,
//                                                                       vertical:
//                                                                           10,
//                                                                     ),
//                                                                     decoration: BoxDecoration(
//                                                                       color:
//                                                                           AppColors
//                                                                               .starColors,
//                                                                       shape:
//                                                                           BoxShape
//                                                                               .circle,
//                                                                     ),
//                                                                     child: Image.asset(
//                                                                       height:
//                                                                           17,
//                                                                       color: Color(
//                                                                         0XFFC18C30,
//                                                                       ),
//                                                                       AppImages
//                                                                           .star,
//                                                                     ),
//                                                                   ),
//                                                                   SizedBox(
//                                                                     height: 5,
//                                                                   ),
//                                                                   CustomTextfield.textWithImage(
//                                                                     colors:
//                                                                         AppColors
//                                                                             .commonBlack,
//                                                                     fontWeight:
//                                                                         FontWeight
//                                                                             .w700,
//                                                                     fontSize:
//                                                                         16,
//                                                                     text:
//                                                                         data?.rating
//                                                                             .toString() ??
//                                                                         '0',
//                                                                   ),
//                                                                   SizedBox(
//                                                                     height: 5,
//                                                                   ),
//                                                                   CustomTextfield.textWithStylesSmall(
//                                                                     'Rating',
//                                                                     colors:
//                                                                         AppColors
//                                                                             .grey,
//                                                                   ),
//                                                                 ],
//                                                               ),
//                                                             ),
//                                                           ],
//                                                         );
//                                                       }),
//                                                     ),
//                                                   ),
//                                                   const SizedBox(height: 10),
//                                                   CustomTextfield.textWithStyles700(
//                                                     'Weekly Challenges',
//                                                     fontSize: 16,
//                                                     color: getTextColor(),
//                                                   ),
//                                                   const SizedBox(height: 10),
//                                                   Container(
//                                                     decoration: BoxDecoration(
//                                                       borderRadius:
//                                                           BorderRadius.circular(
//                                                             10,
//                                                           ),
//                                                       border: Border.all(
//                                                         color: AppColors
//                                                             .commonBlack
//                                                             .withOpacity(0.1),
//                                                       ),
//                                                     ),
//                                                     child: Padding(
//                                                       padding:
//                                                           const EdgeInsets.symmetric(
//                                                             horizontal: 15,
//                                                             vertical: 15,
//                                                           ),
//                                                       child: Obx(() {
//                                                         final weeklyData =
//                                                             statusController
//                                                                 .parcelBookingData
//                                                                 .value;
//
//                                                         return Row(
//                                                           crossAxisAlignment:
//                                                               CrossAxisAlignment
//                                                                   .start,
//                                                           children: [
//                                                             Expanded(
//                                                               child: Column(
//                                                                 crossAxisAlignment:
//                                                                     CrossAxisAlignment
//                                                                         .start,
//                                                                 children: [
//                                                                   CustomTextfield.textWithStylesSmall(
//                                                                     'Ends on Monday',
//                                                                     colors:
//                                                                         AppColors
//                                                                             .grey,
//                                                                     fontWeight:
//                                                                         FontWeight
//                                                                             .w500,
//                                                                   ),
//                                                                   const SizedBox(
//                                                                     height: 5,
//                                                                   ),
//                                                                   CustomTextfield.textWithStyles600(
//                                                                     // and\nget ${weeklyData?.reward.toString() ?? ''} extra
//                                                                     'Complete ${weeklyData?.weeklyProgress.goal.toString() ?? '0'} orders',
//                                                                     fontSize:
//                                                                         17,
//                                                                   ),
//                                                                   const SizedBox(
//                                                                     height: 10,
//                                                                   ),
//                                                                   CustomTextfield.textWithStylesSmall(
//                                                                     colors: getTextColor(
//                                                                       color:
//                                                                           AppColors
//                                                                               .drkGreen,
//                                                                     ),
//
//                                                                     '${weeklyData?.weeklyProgress.totalTrips.toString() ?? '0'} trips done out of 20',
//                                                                     fontWeight:
//                                                                         FontWeight
//                                                                             .w500,
//                                                                   ),
//                                                                 ],
//                                                               ),
//                                                             ),
//                                                             const SizedBox(
//                                                               width: 15,
//                                                             ),
//                                                             CircularPercentIndicator(
//                                                               radius: 45.0,
//                                                               lineWidth: 10.0,
//                                                               animation: true,
//                                                               percent:
//                                                                   (weeklyData
//                                                                           ?.weeklyProgress
//                                                                           .progressPercent ??
//                                                                       0) /
//                                                                   100,
//                                                               center: Text(
//                                                                 "${weeklyData?.weeklyProgress.progressPercent.toString() ?? ''}%",
//                                                                 style: TextStyle(
//                                                                   fontWeight:
//                                                                       FontWeight
//                                                                           .w600,
//                                                                 ),
//                                                               ),
//                                                               circularStrokeCap:
//                                                                   CircularStrokeCap
//                                                                       .round,
//                                                               backgroundColor:
//                                                                   AppColors
//                                                                       .drkGreen
//                                                                       .withOpacity(
//                                                                         0.1,
//                                                                       ),
//                                                               progressColor:
//                                                                   getTextColor(
//                                                                     color:
//                                                                         AppColors
//                                                                             .drkGreen,
//                                                                   ),
//                                                             ),
//                                                           ],
//                                                         );
//                                                       }),
//                                                     ),
//                                                   ),
//
//                                                   const SizedBox(height: 20),
//                                                   CustomTextfield.textWithStyles700(
//                                                     'Recent Deliveries',
//                                                     fontSize: 17,
//                                                   ),
//                                                   const SizedBox(height: 20),
//                                                   Obx(() {
//                                                     final history =
//                                                         statusController
//                                                             .parcelBookingData
//                                                             .value;
//
//                                                     return Column(
//                                                       children: [
//                                                         if (history?.recentBookings ==
//                                                                 null ||
//                                                             history!
//                                                                 .recentBookings
//                                                                 .isEmpty)
//                                                           Center(
//                                                             child: Padding(
//                                                               padding:
//                                                                   const EdgeInsets.symmetric(
//                                                                     vertical:
//                                                                         20,
//                                                                   ),
//                                                               child: Text(
//                                                                 "No recent deliveries",
//                                                                 style: TextStyle(
//                                                                   fontSize: 16,
//                                                                   color:
//                                                                       AppColors
//                                                                           .commonBlack,
//                                                                   fontWeight:
//                                                                       FontWeight
//                                                                           .w500,
//                                                                 ),
//                                                               ),
//                                                             ),
//                                                           )
//                                                         else
//                                                           ListView.builder(
//                                                             shrinkWrap: true,
//                                                             physics:
//                                                                 NeverScrollableScrollPhysics(),
//                                                             itemCount:
//                                                                 history
//                                                                     .recentBookings
//                                                                     .length,
//                                                             itemBuilder: (
//                                                               context,
//                                                               index,
//                                                             ) {
//                                                               final data =
//                                                                   history
//                                                                       .recentBookings[index];
//                                                               return Padding(
//                                                                 padding:
//                                                                     const EdgeInsets.symmetric(
//                                                                       vertical:
//                                                                           4,
//                                                                     ),
//                                                                 child: Container(
//                                                                   decoration: BoxDecoration(
//                                                                     borderRadius:
//                                                                         BorderRadius.circular(
//                                                                           10,
//                                                                         ),
//                                                                     color:
//                                                                         AppColors
//                                                                             .containerColor1,
//                                                                   ),
//                                                                   child: Padding(
//                                                                     padding: const EdgeInsets.symmetric(
//                                                                       horizontal:
//                                                                           15,
//                                                                       vertical:
//                                                                           10,
//                                                                     ),
//                                                                     child: Row(
//                                                                       crossAxisAlignment:
//                                                                           CrossAxisAlignment
//                                                                               .start,
//                                                                       children: [
//                                                                         Padding(
//                                                                           padding: const EdgeInsets.only(
//                                                                             top:
//                                                                                 2.0,
//                                                                           ),
//                                                                           child: Container(
//                                                                             padding: EdgeInsets.symmetric(
//                                                                               horizontal:
//                                                                                   10,
//                                                                               vertical:
//                                                                                   10,
//                                                                             ),
//                                                                             decoration: BoxDecoration(
//                                                                               color: getTextColor(
//                                                                                 color:
//                                                                                     AppColors.changeButtonColor,
//                                                                               ),
//                                                                               shape:
//                                                                                   BoxShape.circle,
//                                                                             ),
//                                                                             child: Image.asset(
//                                                                               AppImages.boxLine,
//                                                                               color:
//                                                                                   AppColors.commonWhite,
//                                                                               height:
//                                                                                   17,
//                                                                             ),
//                                                                           ),
//                                                                         ),
//                                                                         SizedBox(
//                                                                           width:
//                                                                               10,
//                                                                         ),
//                                                                         Expanded(
//                                                                           child: Column(
//                                                                             crossAxisAlignment:
//                                                                                 CrossAxisAlignment.start,
//                                                                             children: [
//                                                                               CustomTextfield.textWithStyles600(
//                                                                                 data.customerName.toString(),
//                                                                                 fontSize:
//                                                                                     15,
//                                                                               ),
//                                                                               CustomTextfield.textWithStylesSmall(
//                                                                                 '2:45 PM', // You might want to use data.statusTime here
//                                                                               ),
//                                                                             ],
//                                                                           ),
//                                                                         ),
//                                                                         Spacer(),
//                                                                         Column(
//                                                                           crossAxisAlignment:
//                                                                               CrossAxisAlignment.end,
//                                                                           children: [
//                                                                             CustomTextfield.textWithImage(
//                                                                               fontWeight:
//                                                                                   FontWeight.w600,
//                                                                               text:
//                                                                                   data.amount.toString(),
//                                                                               colors: getTextColor(
//                                                                                 color:
//                                                                                     AppColors.drkGreen,
//                                                                               ),
//                                                                               imagePath:
//                                                                                   AppImages.bCurrency,
//                                                                               fontSize:
//                                                                                   16,
//                                                                               imageColors: getTextColor(
//                                                                                 color:
//                                                                                     AppColors.drkGreen,
//                                                                               ),
//                                                                             ),
//                                                                             Padding(
//                                                                               padding: const EdgeInsets.only(
//                                                                                 right:
//                                                                                     8.0,
//                                                                               ),
//                                                                               child: Container(
//                                                                                 padding: EdgeInsets.symmetric(
//                                                                                   horizontal:
//                                                                                       20,
//                                                                                   vertical:
//                                                                                       5,
//                                                                                 ),
//                                                                                 decoration: BoxDecoration(
//                                                                                   borderRadius: BorderRadius.circular(
//                                                                                     8,
//                                                                                   ),
//                                                                                   color:
//                                                                                       AppColors.chatCallContainerColor,
//                                                                                 ),
//                                                                                 child: CustomTextfield.textWithStylesSmall(
//                                                                                   data.status.toString(),
//                                                                                   fontWeight:
//                                                                                       FontWeight.w500,
//                                                                                   colors: getTextColor(
//                                                                                     color:
//                                                                                         AppColors.drkGreen,
//                                                                                   ),
//                                                                                 ),
//                                                                               ),
//                                                                             ),
//                                                                           ],
//                                                                         ),
//                                                                       ],
//                                                                     ),
//                                                                   ),
//                                                                 ),
//                                                               );
//                                                             },
//                                                           ),
//                                                       ],
//                                                     );
//                                                   }),
//
//                                                   SizedBox(height: 20),
//                                                 ],
//                                               ),
//                                             ),
//                                           ],
//                                         ),
//                                       ),
//                                     );
//                                   },
//                                 ),
//                               ],
//                             ],
//                           ),
//                         ),
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }
