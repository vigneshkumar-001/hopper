import 'dart:async';

import 'package:action_slider/action_slider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:hopper/Core/Constants/Colors.dart';
import 'package:hopper/Core/Utility/Buttons.dart';
import 'package:hopper/Core/Utility/app_loader.dart';
import 'package:hopper/Core/Utility/images.dart';
import 'package:hopper/Presentation/Authentication/widgets/textFields.dart';
import 'package:hopper/Presentation/DriverScreen/controller/driver_status_controller.dart';
import 'package:hopper/Presentation/DriverScreen/screens/SharedBooking/Controller/shared_ride_controller.dart';
import 'package:hopper/Presentation/DriverScreen/screens/SharedBooking/Screens/share_ride_start_screen.dart';
import 'package:hopper/Presentation/DriverScreen/screens/chat_screen.dart';
import 'package:hopper/Presentation/DriverScreen/screens/driver_main_screen.dart';
import 'package:hopper/utils/map/shared_map.dart';
import 'package:hopper/utils/map/navigation_voice_service.dart';
import 'package:hopper/utils/netWorkHandling/network_handling_screen.dart';

import '../Controller/booking_request_controller.dart';
import '../Controller/picking_customer_shared_controller.dart';
import '../../verify_rider_screen.dart';
import 'booking_overlay_request.dart';

// ─── Design tokens (Light theme) ─────────────────────────────────────────────
class _C {
  // Backgrounds
  static const bg = Color(0xFFF4F6FA);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceAlt = Color(0xFFF8F9FC);

  // Brand
  static const green = Color(0xFF00A85E);
  static const greenLight = Color(0xFFE6F7F0);
  static const greenBorder = Color(0x4000A85E);
  static const greenText = Color(0xFF00874C);

  // Semantic
  static const red = Color(0xFFE53935);
  static const redLight = Color(0xFFFFF0F0);
  static const blue = Color(0xFF1976D2);
  static const blueLight = Color(0xFFE8F1FB);
  static const amber = Color(0xFFF59E0B);
  static const amberLight = Color(0xFFFFFBEB);

  // Text
  static const text = Color(0xFF111827);
  static const textSub = Color(0xFF6B7280);
  static const textMuted = Color(0xFF9CA3AF);

  // Borders / dividers
  static const border = Color(0xFFE5E7EB);
  static const borderLight = Color(0xFFF3F4F6);

  // Shadows
  static const shadow = Color(0x14000000);
  static const shadowMd = Color(0x1F000000);
}

// ─── Screen ───────────────────────────────────────────────────────────────────
class PickingCustomerSharedScreen extends StatefulWidget {
  final LatLng pickupLocation;
  final String? pickupLocationAddress;
  final String? dropLocationAddress;
  final LatLng driverLocation;
  final String bookingId;

  const PickingCustomerSharedScreen({
    super.key,
    required this.pickupLocation,
    required this.driverLocation,
    required this.bookingId,
    this.pickupLocationAddress,
    this.dropLocationAddress,
  });

  @override
  State<PickingCustomerSharedScreen> createState() =>
      _PickingCustomerSharedScreenState();
}

class _PickingCustomerSharedScreenState
    extends State<PickingCustomerSharedScreen>
    with TickerProviderStateMixin {
  final GlobalKey<SharedMapState> _mapKey = GlobalKey<SharedMapState>();

  static const double _ARRIVED_PICKUP_RADIUS_M = 500.0;

  late final PickingCustomerSharedController c;
  final SharedRideController sharedRideController =
      Get.find<SharedRideController>();
  final DriverStatusController driverStatusController =
      Get.find<DriverStatusController>();
  final BookingRequestController bookingController =
      Get.find<BookingRequestController>();

  Timer? _globalTimer;
  bool _routeRefreshQueued = false;

  late final AnimationController _headerAnim;
  late final AnimationController _sheetAnim;
  late final Animation<double> _headerFade;
  late final Animation<Offset> _headerSlide;
  late final Animation<double> _sheetFade;

  @override
  void initState() {
    super.initState();

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );

    _headerAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _sheetAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );
    _headerFade = CurvedAnimation(parent: _headerAnim, curve: Curves.easeOut);
    _headerSlide = Tween<Offset>(
      begin: const Offset(0, -0.4),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _headerAnim, curve: Curves.easeOutBack));
    _sheetFade = CurvedAnimation(
      parent: _sheetAnim,
      curve: Curves.easeOutCubic,
    );

    Future.delayed(const Duration(milliseconds: 80), () {
      if (!mounted) return;
      _headerAnim.forward();
      _sheetAnim.forward();
    });

    c = Get.put(
      PickingCustomerSharedController(
        pickupLocation: widget.pickupLocation,
        driverLocation: widget.driverLocation,
        bookingId: widget.bookingId,
      ),
      tag: widget.bookingId,
    );

    c.socketService.on('driver-cancelled', (data) {
      if (data != null && data['status'] == true) {
        if (!mounted) return;
        Get.offAll(() => const DriverMainScreen());
      }
    });

    c.socketService.on('customer-cancelled', (data) {
      if (data != null && data['status'] == true) {
        if (!mounted) return;
        Get.offAll(() => const DriverMainScreen());
      }
    });
  }

  @override
  void dispose() {
    _globalTimer?.cancel();
    _headerAnim.dispose();
    _sheetAnim.dispose();
    try {
      c.socketService.off('driver-cancelled');
      c.socketService.off('customer-cancelled');
    } catch (_) {}
    if (Get.isRegistered<PickingCustomerSharedController>(
      tag: widget.bookingId,
    )) {
      Get.delete<PickingCustomerSharedController>(tag: widget.bookingId);
    }
    super.dispose();
  }

  // ── Timer ─────────────────────────────────────────────────────────────────
  void _startNoShowTimer(SharedRiderItem rider) {
    rider.secondsLeft = 300;
    sharedRideController.riders.refresh();
    if (_globalTimer != null) return;
    _globalTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        _globalTimer = null;
        return;
      }
      bool anyActive = false;
      for (final r in sharedRideController.riders) {
        if (r.secondsLeft > 0) {
          r.secondsLeft--;
          anyActive = true;
        }
      }
      sharedRideController.riders.refresh();
      if (!anyActive) {
        timer.cancel();
        _globalTimer = null;
      }
    });
  }

  // ── Formatters ────────────────────────────────────────────────────────────
  String _formatTimer(int s) =>
      '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

  String _formatDistance(double m) =>
      '${(m <= 0 ? 0.0 : m / 1000.0).toStringAsFixed(1)} km';

  String _formatDuration(double minutes) {
    final total = minutes.isFinite ? minutes.round() : 0;
    final h = total ~/ 60;
    final m = total % 60;
    return h > 0 ? '${h}h ${m}m' : '$m min';
  }

  // ── Actions ───────────────────────────────────────────────────────────────
  Future<void> _launchPhone(String phone) async {
    final url = Uri.parse('tel:$phone');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Unable to open call app')));
  }

  Future<void> _onSelectRider(SharedRiderItem rider) async {
    await c.selectRider(rider);
    final ms = _mapKey.currentState;
    if (ms != null) {
      ms.pauseAutoFollow(const Duration(seconds: 2));
      await ms.focusOnCustomerRoute(
        c.routeUi.value.driverLocation,
        rider.pickupLatLng,
      );
    }
  }

  Future<void> _sendQuickReply(SharedRiderItem rider, String text) async {
    final delayMin = c.etaMinutes.value.round();
    await c.sendQuickMessage(
      bookingId: rider.bookingId,
      text: text,
      delayMinutes: delayMin,
    );
  }

  Future<void> _recenterToActiveRoute() async {
    final ms = _mapKey.currentState;
    if (ms == null) return;
    final active = sharedRideController.activeTarget.value;
    if (active == null) {
      await ms.fitRouteBounds();
      return;
    }
    ms.pauseAutoFollow(const Duration(seconds: 2));
    await ms.focusOnCustomerRoute(
      c.routeUi.value.driverLocation,
      active.stage == SharedRiderStage.onboardDrop
          ? active.dropLatLng
          : active.pickupLatLng,
    );
  }

  static IconData _maneuverIcon(String maneuverRaw, String directionRaw) {
    final m = maneuverRaw.toLowerCase();
    final d = directionRaw.toLowerCase();

    // Primary: maneuver from routes API
    if (m.contains('uturn')) return Icons.u_turn_right_rounded;
    if (m.contains('roundabout')) return Icons.roundabout_right;
    if (m.contains('left')) return Icons.turn_left_rounded;
    if (m.contains('right')) return Icons.turn_right_rounded;
    if (m.contains('fork-left')) return Icons.turn_slight_left_rounded;
    if (m.contains('fork-right')) return Icons.turn_slight_right_rounded;

    // Fallback: infer from instruction text
    if (d.contains('u-turn') || d.contains('uturn')) {
      return Icons.u_turn_right_rounded;
    }
    if (d.contains('roundabout')) return Icons.roundabout_right;
    if (d.contains('slight left') || d.contains('keep left')) {
      return Icons.turn_slight_left_rounded;
    }
    if (d.contains('slight right') || d.contains('keep right')) {
      return Icons.turn_slight_right_rounded;
    }
    if (d.contains('left')) return Icons.turn_left_rounded;
    if (d.contains('right')) return Icons.turn_right_rounded;

    return Icons.straight_rounded;
  }

  // ════════════════════════════════════════════════════════════════════════════
  // WIDGETS
  // ════════════════════════════════════════════════════════════════════════════

  // ── ETA row ───────────────────────────────────────────────────────────────
  Widget _buildEtaRow() {
    return Obx(() {
      final minutes = c.etaMinutes.value;
      final meters = c.etaMeters.value;
      final updating = c.isEtaUpdating.value;

      return AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        transitionBuilder:
            (child, anim) => FadeTransition(opacity: anim, child: child),
        child: Container(
          key: ValueKey(updating),
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
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
          child:
              updating
                  ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: _C.green,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Refreshing ETA…',
                        style: TextStyle(
                          fontSize: 14,
                          color: _C.textSub,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  )
                  : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.schedule_rounded,
                        color: _C.green,
                        size: 17,
                      ),
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
                      Icon(Icons.route_rounded, color: _C.textSub, size: 17),
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
        ),
      );
    });
  }

  // ── Offline banner ────────────────────────────────────────────────────────
  Widget _buildOfflineBanner() {
    return Obx(() {
      final offline = c.isNetworkOffline.value;
      final pending = c.pendingQueueCount.value;
      if (!offline && pending == 0) return const SizedBox.shrink();
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
                offline ? Icons.wifi_off_rounded : Icons.sync_rounded,
                color: _C.amber,
                size: 16,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  offline
                      ? 'No internet. Route cache active, syncing when online.'
                      : 'Sync pending: $pending message(s)',
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
    });
  }

  // ── Off-route banner ──────────────────────────────────────────────────────
  Widget _buildOffRouteBanner() {
    return Obx(() {
      if (!c.isOffRouteAlert.value) return const SizedBox.shrink();
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
              const Icon(
                Icons.warning_amber_rounded,
                color: _C.amber,
                size: 18,
              ),
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
                onPressed: _recenterToActiveRoute,
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
    });
  }

  // ── Direction header ──────────────────────────────────────────────────────
  String _sharedRouteDistanceText(String distanceText) {
    if (distanceText.trim().isNotEmpty) return distanceText;
    final meters = c.etaMeters.value;
    if (meters <= 0) return 'Locating';
    if (meters >= 1000) return '${(meters / 1000).toStringAsFixed(1)} km';
    return '${meters.round()} m';
  }

  String _sharedRouteDirectionText(String directionText) {
    if (directionText.trim().isNotEmpty) return directionText;
    final eta = c.etaMinutes.value;
    if (eta > 0) return 'Best route loading. ETA ${eta.round()} min';
    return 'Finding fastest route';
  }

  Widget _buildDirectionHeader(dynamic uiState) {
    final dist = _sharedRouteDistanceText(uiState.distanceText);
    final dir =
        uiState.directionText.isEmpty
            ? _sharedRouteDirectionText(uiState.directionText)
            : uiState.directionText;
    final lane = (uiState.laneGuidance ?? '').toString().trim();
    final maneuver = (uiState.maneuver ?? '').toString().toLowerCase();
    final isTurnAlert =
        maneuver.contains('left') ||
        maneuver.contains('right') ||
        maneuver.contains('uturn') ||
        maneuver.contains('roundabout');
    final leftColor =
        isTurnAlert ? const Color(0xFFFC1212) : const Color(0xFFF1A500);
    final rightColor =
        isTurnAlert ? const Color(0xFFE10606) : const Color(0xFFC88700);

    return SlideTransition(
      position: _headerSlide,
      child: FadeTransition(
        opacity: _headerFade,
        child: Container(
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
                            _maneuverIcon(
                              (uiState.maneuver ?? '').toString(),
                              dir,
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
        ),
      ),
    );
  }

  Widget _buildMapControlBtn({
    required IconData icon,
    required VoidCallback onTap,
    Color? iconColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: _C.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _C.border),
          boxShadow: [
            BoxShadow(
              color: _C.shadowMd,
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(
          icon,
          size: 20,
          color: iconColor ?? _C.text.withOpacity(0.7),
        ),
      ),
    );
  }

  Widget _buildFocusBtn() {
    return Obx(
      () => _buildMapControlBtn(
        icon:
            c.isDriverFocused.value
                ? Icons.fit_screen_rounded
                : Icons.my_location_rounded,
        iconColor: _C.green,
        onTap: () {
          final ms = _mapKey.currentState;
          if (ms == null) return;
          ms.pauseAutoFollow(const Duration(seconds: 4));
          if (c.isDriverFocused.value) {
            ms.fitRouteBounds();
          } else {
            ms.focusPickup();
          }
          c.isDriverFocused.value = !c.isDriverFocused.value;
        },
      ),
    );
  }

  Widget _buildVoiceBtn() {
    return ValueListenableBuilder<bool>(
      valueListenable: NavigationVoiceService.instance.mutedNotifier,
      builder:
          (context, muted, _) => _buildMapControlBtn(
            icon: muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
            iconColor: muted ? _C.red : _C.green,
            onTap: () => NavigationVoiceService.instance.toggleMuted(),
          ),
    );
  }

  List<String> _pickupQuickRepliesByDistance({
    required bool reachedPickup,
    required double meters,
    required int etaMinutes,
  }) {
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

  // ── Quick replies ─────────────────────────────────────────────────────────
  Widget _buildQuickReplies(SharedRiderItem rider) {
    final eta = c.etaMinutes.value.round();
    final meters = c.etaMeters.value;
    final chips = _pickupQuickRepliesByDistance(
      reachedPickup:
          rider.arrived || rider.stage == SharedRiderStage.onboardDrop,
      meters: meters,
      etaMinutes: eta,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
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
                        onTap: () => _sendQuickReply(rider, msg),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: _C.surface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: _C.border),
                            boxShadow: [
                              BoxShadow(
                                color: _C.shadow,
                                blurRadius: 2,
                                offset: const Offset(0, 0),
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
  }

  // ── Address section ───────────────────────────────────────────────────────
  Widget _buildAddressSection(SharedRiderItem rider) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _C.surfaceAlt,
          borderRadius: BorderRadius.circular(14),
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
                      margin: const EdgeInsets.symmetric(vertical: 4),
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
              const SizedBox(width: 12),
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
                      rider.pickupAddress,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: _C.text,
                        height: 1.35,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 14),
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
                      rider.dropoffAddress,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
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
    );
  }

  // ── CTA section ───────────────────────────────────────────────────────────
  Widget _buildCardCta(SharedRiderItem rider) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
      child: Column(
        children: [
          // Not arrived yet
          if (!rider.arrived && rider.stage == SharedRiderStage.waitingPickup)
            Obx(() {
              final loading =
                  driverStatusController.arrivedLoadingBookingId.value ==
                  rider.bookingId;

              final driverLoc = sharedRideController.driverLocation.value;
              final canShowArrived =
                  driverLoc != null &&
                  Geolocator.distanceBetween(
                        driverLoc.latitude,
                        driverLoc.longitude,
                        rider.pickupLatLng.latitude,
                        rider.pickupLatLng.longitude,
                      ) <=
                      _ARRIVED_PICKUP_RADIUS_M;

              return AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                child:
                    canShowArrived
                        ? KeyedSubtree(
                          key: ValueKey('arrived-${rider.bookingId}'),
                          child: _PrimaryButton(
                            label: 'Arrived at Pickup Point',
                            icon: Icons.location_on_rounded,
                            color: _C.blue,
                            textColor: Colors.white,
                            loading: loading,
                            onTap:
                                loading
                                    ? null
                                    : () async {
                                      final result =
                                          await driverStatusController
                                              .driverArrived(
                                                context,
                                                bookingId: rider.bookingId,
                                              );
                                      if (result != null &&
                                          result.status == 200) {
                                        rider.arrived = true;
                                        sharedRideController.markArrived(
                                          rider.bookingId,
                                        );
                                        _startNoShowTimer(rider);
                                        setState(() {});
                                      } else {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              result?.message ??
                                                  'Something went wrong',
                                            ),
                                          ),
                                        );
                                      }
                                    },
                          ),
                        )
                        : SizedBox.shrink(
                          key: ValueKey('arrived-hidden-${rider.bookingId}'),
                        ),
              );
            }),

          // Arrived – swipe to start
          if (rider.arrived && rider.stage == SharedRiderStage.waitingPickup)
            _buildSwipeSlider(rider),

          // Onboard
          if (rider.stage == SharedRiderStage.onboardDrop)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: _C.greenLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _C.greenBorder),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    color: _C.green,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Already onboard — manage drop from Start screen',
                      style: TextStyle(
                        fontSize: 12,
                        color: _C.greenText,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ── Swipe slider ──────────────────────────────────────────────────────────
  Widget _buildSwipeSlider(SharedRiderItem rider) {
    return Container(
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
        child: ActionSlider.standard(
          controller: rider.sliderController,
          action: (controller) async {
            controller.loading();
            final msg = await driverStatusController.otpRequest(
              context,
              bookingId: rider.bookingId,
              custName: rider.name,
              pickupAddress: rider.pickupAddress,
              dropAddress: rider.dropoffAddress,
            );
            if (msg == null) {
              controller.failure();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Failed to send OTP')),
              );
              return;
            }
            final verified = await Navigator.push<bool>(
              context,
              MaterialPageRoute(
                builder:
                    (_) => VerifyRiderScreen(
                      bookingId: rider.bookingId,
                      custName: rider.name,
                      pickupAddress: rider.pickupAddress,
                      dropAddress: rider.dropoffAddress,
                      isSharedRide: true,
                    ),
              ),
            );
            if (verified == true) {
              controller.success();
              sharedRideController.markOnboard(rider.bookingId);
              if (!mounted) return;
              Get.off(
                () => ShareRideStartScreen(
                  pickupLocation: rider.pickupLatLng,
                  driverLocation: c.routeUi.value.driverLocation,
                  bookingId: widget.bookingId,
                ),
              );
            } else {
              controller.reset();
            }
          },
          height: 56,
          backgroundColor: _C.greenLight,
          toggleColor: Colors.transparent,
          customForegroundBuilder:
              (context, state, child) => Container(
                margin: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: _C.green,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: _C.green.withOpacity(0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.double_arrow_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
          child: Text(
            'Swipe to Start  •  ${rider.name}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _C.greenText.withOpacity(0.8),
            ),
          ),
        ),
      ),
    );
  }

  // ── Rider card ────────────────────────────────────────────────────────────
  Widget _buildRiderCard(SharedRiderItem rider, {required bool isActive}) {
    final bool isRed = rider.secondsLeft > 0 && rider.secondsLeft <= 10;

    return GestureDetector(
      onTap: () => _onSelectRider(rider),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.fromLTRB(16, 6, 16, 6),
        decoration: BoxDecoration(
          color: _C.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? _C.green : _C.border,
            width: isActive ? 1.5 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: isActive ? _C.green.withOpacity(0.1) : _C.shadow,
              blurRadius: isActive ? 20 : 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Active tag
            if (isActive)
              Align(
                alignment: Alignment.topRight,
                child: Container(
                  margin: const EdgeInsets.fromLTRB(0, 10, 12, 0),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: _C.green,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Active Route',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ),

            // Timer
            if (rider.secondsLeft > 0) ...[
              const SizedBox(height: 8),
              Center(
                child: _TimerBadge(seconds: rider.secondsLeft, isRed: isRed),
              ),
            ],

            // Rider info row
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
              child: Row(
                children: [
                  // Avatar
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      ClipOval(
                        child: CachedNetworkImage(
                          imageUrl: rider.profilePic,
                          height: 50,
                          width: 50,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => _avatarPlaceholder(),
                          errorWidget: (_, __, ___) => _avatarPlaceholder(),
                        ),
                      ),
                      if (rider.stage == SharedRiderStage.onboardDrop)
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width: 13,
                            height: 13,
                            decoration: BoxDecoration(
                              color: _C.green,
                              shape: BoxShape.circle,
                              border: Border.all(color: _C.surface, width: 2),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 12),

                  // Name + tag
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          rider.name,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: _C.text,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          rider.stage == SharedRiderStage.onboardDrop
                              ? 'Onboard Rider'
                              : 'Shared Rider',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color:
                                rider.stage == SharedRiderStage.onboardDrop
                                    ? _C.green
                                    : _C.textSub,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Action buttons
                  _ActionBtn(
                    icon: Icons.call_rounded,
                    color: _C.green,
                    bgColor: _C.greenLight,
                    onTap: () => _launchPhone(rider.phone),
                  ),
                  const SizedBox(width: 8),
                  _ActionBtn(
                    icon: Icons.chat_bubble_rounded,
                    color: _C.blue,
                    bgColor: _C.blueLight,
                    onTap:
                        () => Get.to(
                          () => ChatScreen(bookingId: rider.bookingId),
                        ),
                  ),
                ],
              ),
            ),

            // Addresses
            _buildAddressSection(rider),

            // Quick replies
            _buildQuickReplies(rider),
            const SizedBox(height: 14),
            // CTA
            _buildCardCta(rider),

            const SizedBox(height: 14),
          ],
        ),
      ),
    );
  }

  // ── Bottom actions ────────────────────────────────────────────────────────
  Widget _buildBottomActions() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        children: [
          Container(
            height: 1,
            margin: const EdgeInsets.only(bottom: 14),
            color: _C.border,
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
                    if (Get.isBottomSheetOpen == true) {
                      Get.back();
                    }
                    await driverStatusController.cancelBooking(
                      context,
                      bookingId: widget.bookingId,
                      reason: reason,
                      navigate: true,
                      silent: true,
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

  // ── Bottom sheet ──────────────────────────────────────────────────────────
  Widget _buildBottomSheet() {
    return DraggableScrollableSheet(
      initialChildSize: 0.46,
      minChildSize: 0.36,
      maxChildSize: 0.99,
      builder: (ctx, scrollController) {
        return AnimatedBuilder(
          animation: _sheetFade,
          builder:
              (_, child) => Opacity(
                opacity: _sheetFade.value.clamp(0.0, 1.0),
                child: Transform.translate(
                  offset: Offset(0, 50 * (1 - _sheetFade.value)),
                  child: child,
                ),
              ),
          child: Container(
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
              final showEta =
                  active != null ||
                  c.isEtaUpdating.value ||
                  c.etaMinutes.value > 0 ||
                  c.etaMeters.value > 0;

              return Column(
                children: [
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
                  if (showEta) _buildEtaRow(),
                  const SizedBox(height: 6),
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.only(bottom: 16),
                      children: [
                        if (sharedRideController.riders.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 36,
                              horizontal: 24,
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.sensors_rounded,
                                  color: _C.textMuted,
                                  size: 36,
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'Waiting for shared ride requests…',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: _C.textSub,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          )
                        else
                          ...sharedRideController.riders.map((rider) {
                            final activeR =
                                sharedRideController.activeTarget.value;
                            final isActive =
                                activeR != null &&
                                activeR.bookingId == rider.bookingId;
                            return _buildRiderCard(rider, isActive: isActive);
                          }),
                        if (sharedRideController.riders.isNotEmpty)
                          _buildBottomActions(),
                      ],
                    ),
                  ),
                ],
              );
            }),
          ),
        );
      },
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return NoInternetOverlay(
      child: WillPopScope(
        onWillPop: () async => false,
        child: Scaffold(
          backgroundColor: _C.bg,
          body: Obx(() {
            final uiState = c.routeUi.value;
            final activeTarget = sharedRideController.activeTarget.value;
            final initialBookingRider = sharedRideController.riders
                .firstWhereOrNull((r) => r.bookingId == widget.bookingId);
            final resolvedTarget = activeTarget ?? initialBookingRider;
            final currentTarget =
                resolvedTarget == null
                    ? widget.pickupLocation
                    : (resolvedTarget.stage == SharedRiderStage.onboardDrop
                        ? resolvedTarget.dropLatLng
                        : resolvedTarget.pickupLatLng);

            final markers = <Marker>{
              Marker(
                markerId: const MarkerId('driver'),
                position: uiState.driverLocation,
                icon: c.carIcon.value ?? BitmapDescriptor.defaultMarker,
                rotation: uiState.bearing,
                anchor: const Offset(0.5, 0.5),
                flat: true,
              ),
              Marker(
                markerId: const MarkerId('pickup_target'),
                position: currentTarget,
                icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueRed,
                ),
                infoWindow: InfoWindow(
                  title:
                      activeTarget == null
                          ? 'Pickup Area'
                          : (activeTarget.stage == SharedRiderStage.onboardDrop
                              ? 'Drop Point'
                              : 'Customer Pickup'),
                ),
              ),
              ...sharedRideController.riders.map(
                (r) => Marker(
                  markerId: MarkerId('pickup_${r.bookingId}'),
                  position: r.pickupLatLng,
                  icon: BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueGreen,
                  ),
                  infoWindow: InfoWindow(title: r.name),
                ),
              ),
            };

            if (uiState.polyline.length < 2 &&
                !_routeRefreshQueued &&
                !c.isNetworkOffline.value) {
              _routeRefreshQueued = true;
              Future.microtask(() async {
                try {
                  await c.refreshRouteNow();
                } finally {
                  _routeRefreshQueued = false;
                }
              });
            }

            return Stack(
              children: [
                // Map
                SizedBox(
                  height: 560,
                  width: double.infinity,
                  child: SharedMap(
                    key: _mapKey,
                    initialPosition: uiState.driverLocation,
                    pickupPosition: currentTarget,
                    markers: markers,
                    followDriver: true,
                    followBearingEnabled: false,
                    followZoom: c.followZoom.value,
                    followTilt: 45,
                    trafficEnabled: false,
                    compassEnabled: false,
                    polylines: {
                      if (uiState.polyline.length >= 2)
                        Polyline(
                          polylineId: const PolylineId('route_to_rider_main'),
                          color: const Color(0xFF111111),
                          width: 2,
                          points: uiState.polyline,
                          startCap: Cap.roundCap,
                          endCap: Cap.roundCap,
                          jointType: JointType.round,
                        ),
                    },
                    myLocationEnabled: true,
                    fitToBounds: false,
                  ),
                ),

                // Direction header
                Positioned(
                  top: 52,
                  left: 0,
                  right: 0,
                  child: _buildDirectionHeader(uiState),
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
                        _buildVoiceBtn(),
                        const SizedBox(height: 10),
                        _buildFocusBtn(),
                      ],
                    ),
                  ),
                ),

                // Bottom sheet
                _buildBottomSheet(),

                // Booking overlay
                const BookingOverlayRequest(allowNavigate: false),
              ],
            );
          }),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// MICRO WIDGETS
// ════════════════════════════════════════════════════════════════════════════

/// Animated countdown timer badge
class _TimerBadge extends StatefulWidget {
  final int seconds;
  final bool isRed;
  const _TimerBadge({required this.seconds, required this.isRed});

  @override
  State<_TimerBadge> createState() => _TimerBadgeState();
}

class _TimerBadgeState extends State<_TimerBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _blink;

  @override
  void initState() {
    super.initState();
    _blink = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _blink.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.isRed ? _C.red : _C.green;
    final bgColor = widget.isRed ? _C.redLight : _C.greenLight;
    final m = widget.seconds ~/ 60;
    final s = widget.seconds % 60;
    final label =
        '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color.withOpacity(0.35), width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.isRed)
            FadeTransition(
              opacity: _blink,
              child: Container(
                width: 3,
                height: 6,
                margin: const EdgeInsets.only(right: 7),
                decoration: BoxDecoration(
                  color: _C.red,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: 2.0,
            ),
          ),
        ],
      ),
    );
  }
}

/// Icon action button
class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color bgColor;
  final VoidCallback onTap;
  const _ActionBtn({
    required this.icon,
    required this.color,
    required this.bgColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Icon(icon, color: color, size: 19),
      ),
    );
  }
}

/// Gradient primary button
class _PrimaryButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final Color textColor;
  final bool loading;
  final VoidCallback? onTap;
  const _PrimaryButton({
    required this.label,
    required this.icon,
    required this.color,
    this.textColor = Colors.white,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.25),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child:
            loading
                ? Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: textColor,
                    ),
                  ),
                )
                : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, color: textColor, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      label,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// HELPER FUNCTIONS
// ════════════════════════════════════════════════════════════════════════════

Widget _avatarPlaceholder() => Container(
  width: 50,
  height: 50,
  decoration: BoxDecoration(
    shape: BoxShape.circle,
    color: _C.borderLight,
    border: Border.all(color: _C.border),
  ),
  child: const Icon(Icons.person, color: _C.textMuted, size: 26),
);

Widget _addrDot(Color color, {bool glowing = false}) => Container(
  width: 12,
  height: 12,
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

// import 'dart:async';

// import 'package:action_slider/action_slider.dart';
// import 'package:cached_network_image/cached_network_image.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:get/get.dart';
// import 'package:google_maps_flutter/google_maps_flutter.dart';
// import 'package:url_launcher/url_launcher.dart';

// import 'package:hopper/Core/Constants/Colors.dart';
// import 'package:hopper/Core/Utility/Buttons.dart';
// import 'package:hopper/Core/Utility/app_loader.dart';
// import 'package:hopper/Core/Utility/images.dart';
// import 'package:hopper/Presentation/Authentication/widgets/textFields.dart';
// import 'package:hopper/Presentation/DriverScreen/controller/driver_status_controller.dart';
// import 'package:hopper/Presentation/DriverScreen/screens/SharedBooking/Controller/shared_ride_controller.dart';
// import 'package:hopper/Presentation/DriverScreen/screens/SharedBooking/Screens/share_ride_start_screen.dart';
// import 'package:hopper/Presentation/DriverScreen/screens/chat_screen.dart';
// import 'package:hopper/Presentation/DriverScreen/screens/driver_main_screen.dart';
// import 'package:hopper/utils/map/shared_map.dart';
// import 'package:hopper/utils/map/driver_message_suggestions.dart';
// import 'package:hopper/utils/map/navigation_voice_service.dart';
// import 'package:hopper/utils/netWorkHandling/network_handling_screen.dart';

// import '../Controller/booking_request_controller.dart';
// import '../Controller/picking_customer_shared_controller.dart';
// import '../../verify_rider_screen.dart';
// import 'booking_overlay_request.dart';

// // ─── Design tokens ────────────────────────────────────────────────────────────
// class _C {
//   static const bg          = Color(0xFFF8F9FB);
//   static const card        = Color(0xFFFFFFFF);
//   static const cardBorder  = Color(0xFFE5E7EB);
//   static const green       = Color(0xFF0EA65B);
//   static const greenBorder = Color(0x4D00C878);
//   static const red         = Color(0xFFFF4D6A);
//   static const blue        = Color(0xFF2563EB);
//   static const amber       = Color(0xFFFBBF24);
//   static const text        = Color(0xFF111827);
//   static const muted       = Color(0xFF6B7280);
// }

// // ─── Screen ───────────────────────────────────────────────────────────────────
// class PickingCustomerSharedScreen extends StatefulWidget {
//   final LatLng pickupLocation;
//   final String? pickupLocationAddress;
//   final String? dropLocationAddress;
//   final LatLng driverLocation;
//   final String bookingId;

//   const PickingCustomerSharedScreen({
//     super.key,
//     required this.pickupLocation,
//     required this.driverLocation,
//     required this.bookingId,
//     this.pickupLocationAddress,
//     this.dropLocationAddress,
//   });

//   @override
//   State<PickingCustomerSharedScreen> createState() =>
//       _PickingCustomerSharedScreenState();
// }

// class _PickingCustomerSharedScreenState
//     extends State<PickingCustomerSharedScreen>
//     with TickerProviderStateMixin {
//   final GlobalKey<SharedMapState> _mapKey = GlobalKey<SharedMapState>();

//   late final PickingCustomerSharedController c;
//   final SharedRideController sharedRideController =
//       Get.find<SharedRideController>();
//   final DriverStatusController driverStatusController =
//       Get.find<DriverStatusController>();
//   final BookingRequestController bookingController =
//       Get.find<BookingRequestController>();

//   Timer? _globalTimer;

//   // Entrance animations
//   late final AnimationController _headerAnim;
//   late final AnimationController _sheetAnim;
//   late final Animation<double> _headerFade;
//   late final Animation<Offset> _headerSlide;
//   late final Animation<double> _sheetFade;

//   @override
//   void initState() {
//     super.initState();

//     SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
//     SystemChrome.setSystemUIOverlayStyle(
//       const SystemUiOverlayStyle(
//         statusBarColor: Colors.transparent,
//         statusBarIconBrightness: Brightness.dark,
//         systemNavigationBarColor: Colors.transparent,
//       ),
//     );

//     _headerAnim = AnimationController(
//       vsync: this,
//       duration: const Duration(milliseconds: 500),
//     );
//     _sheetAnim = AnimationController(
//       vsync: this,
//       duration: const Duration(milliseconds: 550),
//     );
//     _headerFade = CurvedAnimation(
//       parent: _headerAnim,
//       curve: Curves.easeOut,
//     );
//     _headerSlide = Tween<Offset>(
//       begin: const Offset(0, -0.4),
//       end: Offset.zero,
//     ).animate(
//       CurvedAnimation(parent: _headerAnim, curve: Curves.easeOutBack),
//     );
//     _sheetFade = CurvedAnimation(
//       parent: _sheetAnim,
//       curve: Curves.easeOutCubic,
//     );

//     Future.delayed(const Duration(milliseconds: 80), () {
//       if (!mounted) return;
//       _headerAnim.forward();
//       _sheetAnim.forward();
//     });

//     c = Get.put(
//       PickingCustomerSharedController(
//         pickupLocation: widget.pickupLocation,
//         driverLocation: widget.driverLocation,
//         bookingId: widget.bookingId,
//       ),
//       tag: widget.bookingId,
//     );

//     c.socketService.on('driver-cancelled', (data) {
//       if (data != null && data['status'] == true) {
//         if (!mounted) return;
//         Get.offAll(() => const DriverMainScreen());
//       }
//     });

//     c.socketService.on('customer-cancelled', (data) {
//       if (data != null && data['status'] == true) {
//         if (!mounted) return;
//         Get.offAll(() => const DriverMainScreen());
//       }
//     });
//   }

//   @override
//   void dispose() {
//     _globalTimer?.cancel();
//     _headerAnim.dispose();
//     _sheetAnim.dispose();
//     try {
//       c.socketService.off('driver-cancelled');
//       c.socketService.off('customer-cancelled');
//     } catch (_) {}
//     if (Get.isRegistered<PickingCustomerSharedController>(
//         tag: widget.bookingId)) {
//       Get.delete<PickingCustomerSharedController>(tag: widget.bookingId);
//     }
//     super.dispose();
//   }

//   // ── Timer ─────────────────────────────────────────────────────────────────
//   void _startNoShowTimer(SharedRiderItem rider) {
//     rider.secondsLeft = 300;
//     sharedRideController.riders.refresh();
//     if (_globalTimer != null) return;
//     _globalTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
//       if (!mounted) {
//         timer.cancel();
//         _globalTimer = null;
//         return;
//       }
//       bool anyActive = false;
//       for (final r in sharedRideController.riders) {
//         if (r.secondsLeft > 0) {
//           r.secondsLeft--;
//           anyActive = true;
//         }
//       }
//       sharedRideController.riders.refresh();
//       if (!anyActive) {
//         timer.cancel();
//         _globalTimer = null;
//       }
//     });
//   }

//   // ── Formatters ────────────────────────────────────────────────────────────
//   String _formatTimer(int s) =>
//       '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

//   String _formatDistance(double m) =>
//       '${(m <= 0 ? 0.0 : m / 1000.0).toStringAsFixed(1)} km';

//   String _formatDuration(double minutes) {
//     final total = minutes.isFinite ? minutes.round() : 0;
//     final h = total ~/ 60;
//     final m = total % 60;
//     return h > 0 ? '${h}h ${m}m' : '$m min';
//   }

//   // ── Actions ───────────────────────────────────────────────────────────────
//   Future<void> _launchPhone(String phone) async {
//     final url = Uri.parse('tel:$phone');
//     if (await canLaunchUrl(url)) {
//       await launchUrl(url);
//       return;
//     }
//     if (!mounted) return;
//     ScaffoldMessenger.of(context).showSnackBar(
//       const SnackBar(content: Text('Unable to open call app')),
//     );
//   }

//   Future<void> _onSelectRider(SharedRiderItem rider) async {
//     await c.selectRider(rider);
//     final ms = _mapKey.currentState;
//     if (ms != null) {
//       ms.pauseAutoFollow(const Duration(seconds: 2));
//       await ms.focusOnCustomerRoute(
//         c.routeUi.value.driverLocation,
//         rider.pickupLatLng,
//       );
//     }
//   }

//   Future<void> _sendQuickReply(SharedRiderItem rider, String text) async {
//     final delayMin = c.etaMinutes.value.round();
//     await c.sendQuickMessage(
//       bookingId: rider.bookingId,
//       text: text,
//       delayMinutes: delayMin,
//     );
//     if (!mounted) return;
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text('Sent: $text'),
//         backgroundColor: _C.card,
//         behavior: SnackBarBehavior.floating,
//         shape: RoundedRectangleBorder(
//           borderRadius: BorderRadius.circular(12),
//         ),
//       ),
//     );
//   }

//   Future<void> _recenterToActiveRoute() async {
//     final ms = _mapKey.currentState;
//     if (ms == null) return;
//     final active = sharedRideController.activeTarget.value;
//     if (active == null) {
//       await ms.fitRouteBounds();
//       return;
//     }
//     ms.pauseAutoFollow(const Duration(seconds: 2));
//     await ms.focusOnCustomerRoute(
//       c.routeUi.value.driverLocation,
//       active.stage == SharedRiderStage.onboardDrop
//           ? active.dropLatLng
//           : active.pickupLatLng,
//     );
//   }

//   static IconData _maneuverIcon(String m) {
//     switch (m) {
//       case 'turn-right':
//         return Icons.turn_right_rounded;
//       case 'turn-left':
//         return Icons.turn_left_rounded;
//       case 'roundabout-left':
//         return Icons.roundabout_right;
//       case 'roundabout-right':
//         return Icons.roundabout_right;
//       default:
//         return Icons.straight_rounded;
//     }
//   }

//   // ════════════════════════════════════════════════════════════════════════════
//   // WIDGETS
//   // ════════════════════════════════════════════════════════════════════════════

//   // ── ETA row ───────────────────────────────────────────────────────────────
//   Widget _buildEtaRow() {
//     return Obx(() {
//       final minutes = c.etaMinutes.value;
//       final meters = c.etaMeters.value;
//       final updating = c.isEtaUpdating.value;

//       return AnimatedSwitcher(
//         duration: const Duration(milliseconds: 250),
//         transitionBuilder: (child, anim) =>
//             FadeTransition(opacity: anim, child: child),
//         child: Container(
//           key: ValueKey(updating),
//           margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
//           padding:
//               const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
//           decoration: BoxDecoration(
//             gradient: const LinearGradient(
//               colors: [Color(0x1A00C878), Color(0x0A00C878)],
//             ),
//             borderRadius: BorderRadius.circular(18),
//             border: Border.all(color: _C.greenBorder),
//             boxShadow: [
//               BoxShadow(
//                 color: _C.green.withOpacity(0.08),
//                 blurRadius: 20,
//                 offset: const Offset(0, 6),
//               ),
//             ],
//           ),
//           child: updating
//               ? Row(
//                   mainAxisAlignment: MainAxisAlignment.center,
//                   children: [
//                     const SizedBox(
//                       width: 16,
//                       height: 16,
//                       child: CircularProgressIndicator(
//                         strokeWidth: 2,
//                         color: _C.green,
//                       ),
//                     ),
//                     const SizedBox(width: 10),
//                     _mutedText('Refreshing ETA…', size: 14),
//                   ],
//                 )
//               : Row(
//                   mainAxisAlignment: MainAxisAlignment.center,
//                   children: [
//                     const Icon(Icons.schedule_rounded,
//                         color: _C.green, size: 16),
//                     const SizedBox(width: 6),
//                     _boldText(_formatDuration(minutes), size: 16),
//                     const SizedBox(width: 14),
//                     Container(
//                       width: 5,
//                       height: 5,
//                       decoration: BoxDecoration(
//                         color: _C.green,
//                         shape: BoxShape.circle,
//                         boxShadow: [
//                           BoxShadow(color: _C.green, blurRadius: 6)
//                         ],
//                       ),
//                     ),
//                     const SizedBox(width: 14),
//                     Icon(Icons.route_rounded,
//                         color: _C.text.withOpacity(0.5), size: 16),
//                     const SizedBox(width: 6),
//                     _boldText(_formatDistance(meters), size: 16),
//                   ],
//                 ),
//         ),
//       );
//     });
//   }

//   // ── Offline banner ────────────────────────────────────────────────────────
//   Widget _buildOfflineBanner() {
//     return Obx(() {
//       final offline = c.isNetworkOffline.value;
//       final pending = c.pendingQueueCount.value;
//       if (!offline && pending == 0) return const SizedBox.shrink();
//       return Positioned(
//         top: 150,
//         left: 12,
//         right: 12,
//         child: Container(
//           padding:
//               const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
//           decoration: BoxDecoration(
//             color: Colors.white,
//             borderRadius: BorderRadius.circular(14),
//             border: Border.all(color: const Color(0xFFE5E7EB)),
//           ),
//           child: Row(
//             children: [
//               Icon(
//                 offline
//                     ? Icons.wifi_off_rounded
//                     : Icons.sync_rounded,
//                 color: _C.amber,
//                 size: 16,
//               ),
//               const SizedBox(width: 8),
//               Expanded(
//                 child: Text(
//                   offline
//                       ? 'No internet. Route cache active, syncing when online.'
//                       : 'Sync pending: $pending message(s)',
//                   style: const TextStyle(
//                     color: Colors.black87,
//                     fontSize: 12,
//                     fontWeight: FontWeight.w600,
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       );
//     });
//   }

//   // ── Off-route banner ──────────────────────────────────────────────────────
//   Widget _buildOffRouteBanner() {
//     return Obx(() {
//       if (!c.isOffRouteAlert.value) return const SizedBox.shrink();
//       return Positioned(
//         top: 202,
//         left: 12,
//         right: 12,
//         child: Container(
//           padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
//           decoration: BoxDecoration(
//             color: Color(0xFFFFFBEB),
//             borderRadius: BorderRadius.circular(14),
//             border:
//                 Border.all(color: _C.amber.withOpacity(0.5)),
//           ),
//           child: Row(
//             children: [
//               const Icon(Icons.warning_amber_rounded,
//                   color: _C.amber, size: 18),
//               const SizedBox(width: 8),
//               const Expanded(
//                 child: Text(
//                   'Route deviation detected',
//                   style: TextStyle(
//                     color: Colors.black87,
//                     fontSize: 12,
//                     fontWeight: FontWeight.w700,
//                   ),
//                 ),
//               ),
//               TextButton(
//                 onPressed: _recenterToActiveRoute,
//                 style: TextButton.styleFrom(
//                   foregroundColor: _C.amber,
//                   padding: const EdgeInsets.symmetric(
//                       horizontal: 10, vertical: 6),
//                   tapTargetSize: MaterialTapTargetSize.shrinkWrap,
//                 ),
//                 child: const Text(
//                   'Recenter',
//                   style: TextStyle(
//                     fontSize: 12,
//                     fontWeight: FontWeight.w700,
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       );
//     });
//   }

//   // ── Direction header ──────────────────────────────────────────────────────
//   Widget _buildDirectionHeader(dynamic uiState) {
//     final dist =
//         uiState.distanceText.isEmpty ? '--' : uiState.distanceText;
//     final dir = uiState.directionText.isEmpty
//         ? 'Searching best route…'
//         : uiState.directionText;

//     return SlideTransition(
//       position: _headerSlide,
//       child: FadeTransition(
//         opacity: _headerFade,
//         child: Container(
//           margin: const EdgeInsets.symmetric(horizontal: 14),
//           decoration: BoxDecoration(
//             borderRadius: BorderRadius.circular(20),
//             boxShadow: [
//               BoxShadow(
//                 color: Colors.black.withOpacity(0.45),
//                 blurRadius: 28,
//                 offset: const Offset(0, 10),
//               ),
//             ],
//           ),
//           child: ClipRRect(
//             borderRadius: BorderRadius.circular(20),
//             child: Row(
//               children: [
//                 // Left panel
//                 Container(
//                   width: 88,
//                   padding: const EdgeInsets.symmetric(vertical: 16),
//                   decoration: const BoxDecoration(
//                     gradient: LinearGradient(
//                       begin: Alignment.topCenter,
//                       end: Alignment.bottomCenter,
//                       colors: [Color(0xFFEFFAF4), Color(0xFFFFFFFF)],
//                     ),
//                     border: Border(
//                       right: BorderSide(
//                           color: Color(0x2200C878), width: 1),
//                     ),
//                   ),
//                   child: Column(
//                     mainAxisAlignment: MainAxisAlignment.center,
//                     children: [
//                       Container(
//                         padding: const EdgeInsets.all(8),
//                         decoration: BoxDecoration(
//                           color: _C.green.withOpacity(0.14),
//                           borderRadius: BorderRadius.circular(12),
//                           border: Border.all(
//                               color: _C.green.withOpacity(0.3)),
//                         ),
//                         child: Icon(
//                           _maneuverIcon(uiState.maneuver),
//                           size: 22,
//                           color: _C.green,
//                         ),
//                       ),
//                       const SizedBox(height: 8),
//                       Text(
//                         dist,
//                         style: const TextStyle(
//                           fontSize: 13,
//                           fontWeight: FontWeight.w700,
//                           color: _C.green,
//                           letterSpacing: 0.3,
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//                 // Right panel
//                 Expanded(
//                   child: Container(
//                     padding: const EdgeInsets.symmetric(
//                         horizontal: 16, vertical: 18),
//                     decoration: const BoxDecoration(
//                       gradient: LinearGradient(
//                         colors: [
//                           Color(0xFFFFFFFF),
//                           Color(0xFFF8F9FB),
//                         ],
//                       ),
//                     ),
//                     child: Text(
//                       dir,
//                       maxLines: 2,
//                       overflow: TextOverflow.ellipsis,
//                       style: const TextStyle(
//                         fontSize: 14,
//                         fontWeight: FontWeight.w700,
//                         color: _C.text,
//                         height: 1.4,
//                         letterSpacing: 0.2,
//                       ),
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }

//   // ── Focus button ──────────────────────────────────────────────────────────
//   Widget _buildFocusBtn() {
//     return Obx(() => GestureDetector(
//           onTap: () {
//             final ms = _mapKey.currentState;
//             if (ms == null) return;
//             ms.pauseAutoFollow(const Duration(seconds: 4));
//             if (c.isDriverFocused.value) {
//               ms.fitRouteBounds();
//             } else {
//               ms.focusPickup();
//             }
//             c.isDriverFocused.value = !c.isDriverFocused.value;
//           },
//           child: Container(
//             width: 44,
//             height: 44,
//             decoration: BoxDecoration(
//               color: Colors.white,
//               borderRadius: BorderRadius.circular(14),
//               border: Border.all(color: const Color(0xFFE5E7EB)),
//               boxShadow: const [
//                 BoxShadow(
//                   color: Color(0x14000000),
//                   blurRadius: 16,
//                   offset: Offset(0, 4),
//                 ),
//               ],
//             ),
//             child: Icon(
//               c.isDriverFocused.value
//                   ? Icons.fit_screen_rounded
//                   : Icons.my_location_rounded,
//               size: 20,
//               color: Colors.black87,
//             ),
//           ),
//         ));
//   }

//   Widget _buildVoiceBtn() {
//     return ValueListenableBuilder<bool>(
//       valueListenable: NavigationVoiceService.instance.mutedNotifier,
//       builder: (context, muted, _) => GestureDetector(
//         onTap: () => NavigationVoiceService.instance.toggleMuted(),
//         child: Container(
//           width: 44,
//           height: 44,
//           decoration: BoxDecoration(
//             color: Colors.white,
//             borderRadius: BorderRadius.circular(14),
//             border: Border.all(color: const Color(0xFFE5E7EB)),
//             boxShadow: const [
//               BoxShadow(
//                 color: Color(0x14000000),
//                 blurRadius: 16,
//                 offset: Offset(0, 4),
//               ),
//             ],
//           ),
//           child: Icon(
//             muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
//             size: 20,
//             color: Colors.black87,
//           ),
//         ),
//       ),
//     );
//   }

//   // ── Quick replies ─────────────────────────────────────────────────────────
//   Widget _buildQuickReplies(SharedRiderItem rider) {
//     final eta = c.etaMinutes.value.round();
//     final chips = DriverMessageSuggestions.pickup(
//       reachedPickup:
//           rider.arrived || rider.stage == SharedRiderStage.onboardDrop,
//       etaMinutes: eta,
//     );
//     return Padding(
//       padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           _mutedText('Quick replies', size: 11),
//           const SizedBox(height: 6),
//           SingleChildScrollView(
//             scrollDirection: Axis.horizontal,
//             child: Row(
//               children: chips.map((msg) {
//                 return Padding(
//                   padding: const EdgeInsets.only(right: 7),
//                   child: GestureDetector(
//                     onTap: () => _sendQuickReply(rider, msg),
//                     child: Container(
//                       padding: const EdgeInsets.symmetric(
//                           horizontal: 11, vertical: 7),
//                       decoration: BoxDecoration(
//                         color: const Color(0xFFF3F4F6),
//                         borderRadius: BorderRadius.circular(20),
//                         border: Border.all(color: const Color(0xFFE5E7EB)),
//                       ),
//                       child: Text(
//                         msg,
//                         style: TextStyle(
//                           fontSize: 11.5,
//                           fontWeight: FontWeight.w600,
//                           color: _C.text.withOpacity(0.8),
//                         ),
//                       ),
//                     ),
//                   ),
//                 );
//               }).toList(),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   // ── Address section ───────────────────────────────────────────────────────
//   Widget _buildAddressSection(SharedRiderItem rider) {
//     return Padding(
//       padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
//       child: IntrinsicHeight(
//         child: Row(
//           crossAxisAlignment: CrossAxisAlignment.stretch,
//           children: [
//             Column(
//               children: [
//                 _addrDot(_C.green, glowing: true),
//                 Expanded(
//                   child: Container(
//                     width: 1.5,
//                     margin: const EdgeInsets.symmetric(vertical: 4),
//                     decoration: const BoxDecoration(
//                       gradient: LinearGradient(
//                         begin: Alignment.topCenter,
//                         end: Alignment.bottomCenter,
//                         colors: [
//                           Color(0x4000C878),
//                           Color(0x18FF4D6A),
//                         ],
//                       ),
//                     ),
//                   ),
//                 ),
//                 _addrDot(_C.red),
//               ],
//             ),
//             const SizedBox(width: 12),
//             Expanded(
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   _addrLabel('PICKUP'),
//                   const SizedBox(height: 2),
//                   _addrVal(rider.pickupAddress),
//                   const SizedBox(height: 16),
//                   _addrLabel('DROP OFF'),
//                   const SizedBox(height: 2),
//                   _addrVal(rider.dropoffAddress),
//                 ],
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   // ── CTA section ───────────────────────────────────────────────────────────
//   Widget _buildCardCta(SharedRiderItem rider) {
//     return Padding(
//       padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
//       child: Column(
//         children: [
//           // Not arrived yet
//           if (!rider.arrived &&
//               rider.stage == SharedRiderStage.waitingPickup)
//             Obx(() {
//               final loading =
//                   driverStatusController
//                       .arrivedLoadingBookingId.value ==
//                   rider.bookingId;
//               return _PrimaryButton(
//                 label: 'Arrived at Pickup Point',
//                 icon: Icons.location_on_rounded,
//                 color: _C.blue,
//                 loading: loading,
//                 onTap: loading
//                     ? null
//                     : () async {
//                         final result = await driverStatusController
//                             .driverArrived(context,
//                                 bookingId: rider.bookingId);
//                         if (result != null &&
//                             result.status == 200) {
//                           rider.arrived = true;
//                           sharedRideController
//                               .markArrived(rider.bookingId);
//                           _startNoShowTimer(rider);
//                           setState(() {});
//                         } else {
//                           ScaffoldMessenger.of(context)
//                               .showSnackBar(
//                             SnackBar(
//                               content: Text(result?.message ??
//                                   'Something went wrong'),
//                             ),
//                           );
//                         }
//                       },
//               );
//             }),

//           // Arrived – swipe to start
//           if (rider.arrived &&
//               rider.stage == SharedRiderStage.waitingPickup)
//             _buildSwipeSlider(rider),

//           // Onboard
//           if (rider.stage == SharedRiderStage.onboardDrop)
//             Container(
//               padding: const EdgeInsets.symmetric(
//                   horizontal: 12, vertical: 9),
//               decoration: BoxDecoration(
//                 color: _C.green.withOpacity(0.07),
//                 borderRadius: BorderRadius.circular(12),
//                 border: Border.all(
//                     color: _C.green.withOpacity(0.2)),
//               ),
//               child: Row(
//                 children: [
//                   const Icon(Icons.check_circle_rounded,
//                       color: _C.green, size: 15),
//                   const SizedBox(width: 8),
//                   Expanded(
//                     child: _mutedText(
//                       'Already onboard — manage drop from Start screen',
//                       size: 12,
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//         ],
//       ),
//     );
//   }

//   // ── Swipe slider ──────────────────────────────────────────────────────────
//   Widget _buildSwipeSlider(SharedRiderItem rider) {
//     return Container(
//       decoration: BoxDecoration(
//         borderRadius: BorderRadius.circular(16),
//         border: Border.all(color: _C.greenBorder, width: 1),
//       ),
//       child: ClipRRect(
//         borderRadius: BorderRadius.circular(15),
//         child: ActionSlider.standard(
//       controller: rider.sliderController,
//       action: (controller) async {
//         controller.loading();
//         final msg = await driverStatusController.otpRequest(
//           context,
//           bookingId: rider.bookingId,
//           custName: rider.name,
//           pickupAddress: rider.pickupAddress,
//           dropAddress: rider.dropoffAddress,
//         );
//         if (msg == null) {
//           controller.failure();
//           ScaffoldMessenger.of(context).showSnackBar(
//             const SnackBar(content: Text('Failed to send OTP')),
//           );
//           return;
//         }
//         final verified = await Navigator.push<bool>(
//           context,
//           MaterialPageRoute(
//             builder: (_) => VerifyRiderScreen(
//               bookingId: rider.bookingId,
//               custName: rider.name,
//               pickupAddress: rider.pickupAddress,
//               dropAddress: rider.dropoffAddress,
//               isSharedRide: true,
//             ),
//           ),
//         );
//         if (verified == true) {
//           controller.success();
//           sharedRideController.markOnboard(rider.bookingId);
//           if (!mounted) return;
//           Get.off(() => ShareRideStartScreen(
//                 pickupLocation: rider.pickupLatLng,
//                 driverLocation: c.routeUi.value.driverLocation,
//                 bookingId: widget.bookingId,
//               ));
//         } else {
//           controller.reset();
//         }
//       },
//       height: 56,
//       backgroundColor: const Color(0xFF0F1A12),
//       toggleColor: Colors.transparent,
//       customForegroundBuilder: (context, state, child) => Container(
//         margin: const EdgeInsets.all(5),
//         decoration: BoxDecoration(
//           gradient: const LinearGradient(
//             colors: [Color(0xFF00C878), Color(0xFF00A85E)],
//           ),
//           borderRadius: BorderRadius.circular(12),
//           boxShadow: [
//             BoxShadow(
//               color: _C.green.withOpacity(0.45),
//               blurRadius: 14,
//               offset: const Offset(0, 4),
//             ),
//           ],
//         ),
//         child: const Icon(
//           Icons.double_arrow_rounded,
//           color: Colors.black,
//           size: 26,
//         ),
//       ),
//       child: Text(
//         'Swipe to Start  •  ${rider.name}',
//         style: TextStyle(
//           fontSize: 13.5,
//           fontWeight: FontWeight.w600,
//           color: _C.text.withOpacity(0.6),
//         ),
//       ),
//         ),
//       ),
//     );
//   }

//   // ── Rider card ────────────────────────────────────────────────────────────
//   Widget _buildRiderCard(SharedRiderItem rider,
//       {required bool isActive}) {
//     final bool isRed =
//         rider.secondsLeft > 0 && rider.secondsLeft <= 10;

//     return GestureDetector(
//       onTap: () => _onSelectRider(rider),
//       child: AnimatedContainer(
//         duration: const Duration(milliseconds: 260),
//         curve: Curves.easeOutCubic,
//         margin: const EdgeInsets.fromLTRB(16, 6, 16, 6),
//         decoration: BoxDecoration(
//           gradient: LinearGradient(
//             begin: Alignment.topLeft,
//             end: Alignment.bottomRight,
//             colors: isActive
//                 ? [const Color(0xFFEFFAF4), const Color(0xFFFFFFFF)]
//                 : [
//                     const Color(0xFFFFFFFF),
//                     const Color(0xFFF8F9FB)
//                   ],
//           ),
//           borderRadius: BorderRadius.circular(22),
//           border: Border.all(
//             color: isActive ? _C.greenBorder : _C.cardBorder,
//             width: isActive ? 1.5 : 1.0,
//           ),
//           boxShadow: [
//             BoxShadow(
//               color: isActive
//                   ? _C.green.withOpacity(0.12)
//                   : Colors.black.withOpacity(0.08),
//               blurRadius: isActive ? 28 : 14,
//               offset: const Offset(0, 8),
//             ),
//           ],
//         ),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             // Active tag
//             if (isActive)
//               Align(
//                 alignment: Alignment.topRight,
//                 child: Container(
//                   margin:
//                       const EdgeInsets.fromLTRB(0, 10, 12, 0),
//                   padding: const EdgeInsets.symmetric(
//                       horizontal: 10, vertical: 3),
//                   decoration: BoxDecoration(
//                     color: _C.green,
//                     borderRadius: BorderRadius.circular(20),
//                   ),
//                   child: const Text(
//                     'Active Route',
//                     style: TextStyle(
//                       fontSize: 10,
//                       fontWeight: FontWeight.w800,
//                       color: Colors.black,
//                       letterSpacing: 0.8,
//                     ),
//                   ),
//                 ),
//               ),

//             // Timer
//             if (rider.secondsLeft > 0) ...[
//               const SizedBox(height: 8),
//               Center(
//                 child: _TimerBadge(
//                   seconds: rider.secondsLeft,
//                   isRed: isRed,
//                 ),
//               ),
//             ],

//             // Rider info row
//             Padding(
//               padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
//               child: Row(
//                 children: [
//                   // Avatar
//                   Stack(
//                     clipBehavior: Clip.none,
//                     children: [
//                       ClipOval(
//                         child: CachedNetworkImage(
//                           imageUrl: rider.profilePic,
//                           height: 48,
//                           width: 48,
//                           fit: BoxFit.cover,
//                           placeholder: (_, __) =>
//                               _avatarPlaceholder(),
//                           errorWidget: (_, __, ___) =>
//                               _avatarPlaceholder(),
//                         ),
//                       ),
//                       if (rider.stage ==
//                           SharedRiderStage.onboardDrop)
//                         Positioned(
//                           bottom: 0,
//                           right: 0,
//                           child: Container(
//                             width: 12,
//                             height: 12,
//                             decoration: BoxDecoration(
//                               color: _C.green,
//                               shape: BoxShape.circle,
//                               border: Border.all(
//                                   color: _C.card, width: 2),
//                               boxShadow: [
//                                 BoxShadow(
//                                     color: _C.green,
//                                     blurRadius: 5)
//                               ],
//                             ),
//                           ),
//                         ),
//                     ],
//                   ),
//                   const SizedBox(width: 12),

//                   // Name + tag
//                   Expanded(
//                     child: Column(
//                       crossAxisAlignment:
//                           CrossAxisAlignment.start,
//                       children: [
//                         Text(
//                           rider.name,
//                           style: const TextStyle(
//                             fontSize: 15.5,
//                             fontWeight: FontWeight.w700,
//                             color: _C.text,
//                           ),
//                         ),
//                         const SizedBox(height: 2),
//                         Text(
//                           rider.stage ==
//                                   SharedRiderStage.onboardDrop
//                               ? 'Onboard Rider'
//                               : 'Shared Rider',
//                           style: TextStyle(
//                             fontSize: 12,
//                             fontWeight: FontWeight.w500,
//                             color: rider.stage ==
//                                     SharedRiderStage.onboardDrop
//                                 ? _C.green
//                                 : _C.muted,
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),

//                   // Action buttons
//                   _ActionBtn(
//                     icon: Icons.call_rounded,
//                     color: _C.green,
//                     onTap: () => _launchPhone(rider.phone),
//                   ),
//                   const SizedBox(width: 8),
//                   _ActionBtn(
//                     icon: Icons.chat_bubble_rounded,
//                     color: _C.blue,
//                     onTap: () => Get.to(
//                       () => ChatScreen(bookingId: rider.bookingId),
//                     ),
//                   ),
//                 ],
//               ),
//             ),

//             // Addresses
//             _buildAddressSection(rider),

//             // Quick replies
//             _buildQuickReplies(rider),

//             // CTA
//             _buildCardCta(rider),

//             const SizedBox(height: 14),
//           ],
//         ),
//       ),
//     );
//   }

//   // ── Bottom actions ────────────────────────────────────────────────────────
//   Widget _buildBottomActions() {
//     return Padding(
//       padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
//       child: Column(
//         children: [
//           Container(
//             height: 1,
//             margin: const EdgeInsets.only(bottom: 14),
//             decoration: const BoxDecoration(
//               gradient: LinearGradient(
//                 colors: [
//                   Colors.transparent,
//                   Color(0x15FFFFFF),
//                   Colors.transparent,
//                 ],
//               ),
//             ),
//           ),
//           Obx(() {
//             final stopped =
//                 driverStatusController.isStopNewRequests.value;
//             return _OutlinedBtn(
//               label: stopped
//                   ? 'New Requests Stopped'
//                   : 'Stop New Ride Requests',
//               icon: stopped
//                   ? Icons.block_rounded
//                   : Icons.do_not_disturb_on_rounded,
//               disabled: stopped,
//               onTap: stopped
//                   ? null
//                   : () => Buttons.showDialogBox(
//                         context: context,
//                         onConfirmStop: () async {
//                           await driverStatusController
//                               .stopNewRideRequest(
//                                   context: context, stop: true);
//                         },
//                       ),
//             );
//           }),
//           const SizedBox(height: 10),
//           _DangerBtn(
//             label: 'Cancel this Shared Ride',
//             onTap: () => Buttons.showCancelRideBottomSheet(
//               context,
//               onConfirmCancel: (reason) async {
//                 if (Get.isBottomSheetOpen == true) Get.back();
//                 await driverStatusController.cancelBooking(
//                   context,
//                   bookingId: widget.bookingId,
//                   reason: reason,
//                   navigate: true,
//                   silent: true,
//                 );
//               },
//             ),
//           ),
//           const SizedBox(height: 16),
//         ],
//       ),
//     );
//   }

//   // ── Bottom sheet ──────────────────────────────────────────────────────────
//   Widget _buildBottomSheet() {
//     return DraggableScrollableSheet(
//       initialChildSize: 0.46,
//       minChildSize: 0.36,
//       maxChildSize: 0.99,
//       builder: (ctx, scrollController) {
//         return AnimatedBuilder(
//           animation: _sheetFade,
//           builder: (_, child) => Opacity(
//             opacity: _sheetFade.value.clamp(0.0, 1.0),
//             child: Transform.translate(
//               offset:
//                   Offset(0, 50 * (1 - _sheetFade.value)),
//               child: child,
//             ),
//           ),
//           child: Container(
//             decoration: const BoxDecoration(
//               gradient: LinearGradient(
//                 begin: Alignment.topCenter,
//                 end: Alignment.bottomCenter,
//                 colors: [Color(0xFFFFFFFF), Color(0xFFF8F9FB)],
//               ),
//               borderRadius: BorderRadius.vertical(
//                   top: Radius.circular(28)),
//               border: Border(
//                 top: BorderSide(color: Color(0xFFE5E7EB)),
//               ),
//             ),
//             child: Obx(() {
//               final active =
//                   sharedRideController.activeTarget.value;
//               final showEta = active != null ||
//                   c.isEtaUpdating.value ||
//                   c.etaMinutes.value > 0 ||
//                   c.etaMeters.value > 0;

//               return Column(
//                 children: [
//                   const SizedBox(height: 10),
//                   Center(
//                     child: Container(
//                       width: 40,
//                       height: 4,
//                       decoration: BoxDecoration(
//                         color: Colors.white.withOpacity(0.15),
//                         borderRadius: BorderRadius.circular(10),
//                       ),
//                     ),
//                   ),
//                   if (showEta) _buildEtaRow(),
//                   const SizedBox(height: 6),
//                   Expanded(
//                     child: ListView(
//                       controller: scrollController,
//                       physics: const BouncingScrollPhysics(),
//                       padding:
//                           const EdgeInsets.only(bottom: 16),
//                       children: [
//                         if (sharedRideController
//                             .riders.isEmpty)
//                           Padding(
//                             padding: const EdgeInsets.symmetric(
//                                 vertical: 36, horizontal: 24),
//                             child: Column(
//                               children: [
//                                 Icon(Icons.sensors_rounded,
//                                     color: _C.muted, size: 36),
//                                 const SizedBox(height: 12),
//                                 _mutedText(
//                                   'Waiting for shared ride requests…',
//                                   size: 14,
//                                 ),
//                               ],
//                             ),
//                           )
//                         else
//                           ...sharedRideController.riders
//                               .map((rider) {
//                             final activeR = sharedRideController
//                                 .activeTarget.value;
//                             final isActive = activeR != null &&
//                                 activeR.bookingId ==
//                                     rider.bookingId;
//                             return _buildRiderCard(rider,
//                                 isActive: isActive);
//                           }),
//                         if (sharedRideController
//                             .riders.isNotEmpty)
//                           _buildBottomActions(),
//                       ],
//                     ),
//                   ),
//                 ],
//               );
//             }),
//           ),
//         );
//       },
//     );
//   }

//   // ── Build ─────────────────────────────────────────────────────────────────
//   @override
//   Widget build(BuildContext context) {
//     return NoInternetOverlay(
//       child: WillPopScope(
//         onWillPop: () async => false,
//         child: Scaffold(
//           backgroundColor: _C.bg,
//           body: Obx(() {
//             final uiState = c.routeUi.value;
//             final currentTarget =
//                 sharedRideController.activeTarget.value
//                         ?.pickupLatLng ??
//                     widget.pickupLocation;

//             final markers = <Marker>{
//               Marker(
//                 markerId: const MarkerId('driver'),
//                 position: uiState.driverLocation,
//                 icon: c.carIcon.value ??
//                     BitmapDescriptor.defaultMarker,
//                 rotation: uiState.bearing,
//                 anchor: const Offset(0.5, 0.5),
//                 flat: true,
//               ),
//               Marker(
//                 markerId: const MarkerId('pickup_main'),
//                 position: widget.pickupLocation,
//                 infoWindow:
//                     const InfoWindow(title: 'Pickup Area'),
//               ),
//               ...sharedRideController.riders.map(
//                 (r) => Marker(
//                   markerId: MarkerId('pickup_${r.bookingId}'),
//                   position: r.pickupLatLng,
//                   icon: BitmapDescriptor.defaultMarkerWithHue(
//                       BitmapDescriptor.hueGreen),
//                   infoWindow: InfoWindow(title: r.name),
//                 ),
//               ),
//             };

//             return Stack(
//               children: [
//                 // Map
//                 SizedBox(
//                   height: 560,
//                   width: double.infinity,
//                   child: SharedMap(
//                     key: _mapKey,
//                     initialPosition: widget.pickupLocation,
//                     pickupPosition: currentTarget,
//                     markers: markers,
//                     followDriver: true,
//                     followZoom: c.followZoom.value,
//                     followTilt: 42,
//                     polylines: {
//                       if (uiState.polyline.length >= 2)
//                         Polyline(
//                           polylineId: const PolylineId(
//                               'route_to_rider'),
//                           color: _C.green,
//                           width: 5,
//                           points: uiState.polyline,
//                           patterns: [
//                             PatternItem.dash(24),
//                             PatternItem.gap(10),
//                           ],
//                         ),
//                     },
//                     myLocationEnabled: true,
//                     fitToBounds: false,
//                   ),
//                 ),

//                 // Top gradient fade
//                 Positioned(
//                   top: 0,
//                   left: 0,
//                   right: 0,
//                   height: 120,
//                   child: IgnorePointer(
//                     child: Container(
//                       decoration: const BoxDecoration(
//                         gradient: LinearGradient(
//                           begin: Alignment.topCenter,
//                           end: Alignment.bottomCenter,
//                           colors: [
//                             Color(0x99FFFFFF),
//                             Colors.transparent,
//                           ],
//                         ),
//                       ),
//                     ),
//                   ),
//                 ),

//                 // Direction header
//                 Positioned(
//                   top: 52,
//                   left: 0,
//                   right: 0,
//                   child: _buildDirectionHeader(uiState),
//                 ),

//                 // Offline banner
//                 _buildOfflineBanner(),

//                 // Off-route banner
//                 _buildOffRouteBanner(),

//                 // Focus button
//                 Positioned(
//                   top: 172,
//                   right: 14,
//                   child: SafeArea(
//                     child: Column(
//                       children: [
//                         _buildVoiceBtn(),
//                         const SizedBox(height: 10),
//                         _buildFocusBtn(),
//                       ],
//                     ),
//                   ),
//                 ),

//                 // Bottom sheet
//                 _buildBottomSheet(),

//                 // Booking overlay
//                 const BookingOverlayRequest(
//                     allowNavigate: false),
//               ],
//             );
//           }),
//         ),
//       ),
//     );
//   }
// }

// // ════════════════════════════════════════════════════════════════════════════
// // MICRO WIDGETS
// // ════════════════════════════════════════════════════════════════════════════

// /// Animated countdown timer badge
// class _TimerBadge extends StatefulWidget {
//   final int seconds;
//   final bool isRed;
//   const _TimerBadge({required this.seconds, required this.isRed});

//   @override
//   State<_TimerBadge> createState() => _TimerBadgeState();
// }

// class _TimerBadgeState extends State<_TimerBadge>
//     with SingleTickerProviderStateMixin {
//   late final AnimationController _blink;

//   @override
//   void initState() {
//     super.initState();
//     _blink = AnimationController(
//       vsync: this,
//       duration: const Duration(milliseconds: 900),
//     )..repeat(reverse: true);
//   }

//   @override
//   void dispose() {
//     _blink.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     final color = widget.isRed ? _C.red : _C.green;
//     final m = widget.seconds ~/ 60;
//     final s = widget.seconds % 60;
//     final label =
//         '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';

//     return Container(
//       padding: const EdgeInsets.symmetric(
//           horizontal: 16, vertical: 6),
//       decoration: BoxDecoration(
//         color: color.withOpacity(0.08),
//         borderRadius: BorderRadius.circular(30),
//         border: Border.all(
//             color: color.withOpacity(0.4), width: 1.5),
//       ),
//       child: Row(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           if (widget.isRed)
//             FadeTransition(
//               opacity: _blink,
//               child: Container(
//                 width: 3,
//                 height: 6,
//                 margin: const EdgeInsets.only(right: 7),
//                 decoration: BoxDecoration(
//                   color: _C.red,
//                   shape: BoxShape.circle,
//                   boxShadow: [
//                     BoxShadow(color: _C.red, blurRadius: 4)
//                   ],
//                 ),
//               ),
//             ),
//           Text(
//             label,
//             style: TextStyle(
//               fontSize: 13,
//               fontWeight: FontWeight.w800,
//               color: color,
//               letterSpacing: 2.0,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// /// Circular icon action button
// class _ActionBtn extends StatelessWidget {
//   final IconData icon;
//   final Color color;
//   final VoidCallback onTap;
//   const _ActionBtn(
//       {required this.icon,
//       required this.color,
//       required this.onTap});

//   @override
//   Widget build(BuildContext context) {
//     return GestureDetector(
//       onTap: onTap,
//       child: Container(
//         width: 40,
//         height: 40,
//         decoration: BoxDecoration(
//           color: color.withOpacity(0.1),
//           borderRadius: BorderRadius.circular(12),
//           border: Border.all(color: color.withOpacity(0.25)),
//         ),
//         child: Icon(icon, color: color, size: 19),
//       ),
//     );
//   }
// }

// /// Gradient primary button
// class _PrimaryButton extends StatelessWidget {
//   final String label;
//   final IconData icon;
//   final Color color;
//   final bool loading;
//   final VoidCallback? onTap;
//   const _PrimaryButton({
//     required this.label,
//     required this.icon,
//     required this.color,
//     required this.loading,
//     required this.onTap,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return GestureDetector(
//       onTap: onTap,
//       child: Container(
//         width: double.infinity,
//         padding: const EdgeInsets.symmetric(vertical: 14),
//         decoration: BoxDecoration(
//           gradient: LinearGradient(
//             colors: [color, color.withOpacity(0.8)],
//           ),
//           borderRadius: BorderRadius.circular(14),
//           boxShadow: [
//             BoxShadow(
//               color: color.withOpacity(0.3),
//               blurRadius: 18,
//               offset: const Offset(0, 6),
//             ),
//           ],
//         ),
//         child: loading
//             ? const Center(
//                 child: SizedBox(
//                   width: 20,
//                   height: 20,
//                   child: CircularProgressIndicator(
//                     strokeWidth: 2.2,
//                     color: Colors.white,
//                   ),
//                 ),
//               )
//             : Row(
//                 mainAxisAlignment: MainAxisAlignment.center,
//                 children: [
//                   Icon(icon, color: Colors.white, size: 18),
//                   const SizedBox(width: 8),
//                   Text(
//                     label,
//                     style: const TextStyle(
//                       color: Colors.white,
//                       fontSize: 14,
//                       fontWeight: FontWeight.w700,
//                       letterSpacing: 0.3,
//                     ),
//                   ),
//                 ],
//               ),
//       ),
//     );
//   }
// }

// /// Outlined secondary button
// class _OutlinedBtn extends StatelessWidget {
//   final String label;
//   final IconData icon;
//   final VoidCallback? onTap;
//   final bool disabled;
//   const _OutlinedBtn({
//     required this.label,
//     required this.icon,
//     this.onTap,
//     this.disabled = false,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return GestureDetector(
//       onTap: onTap,
//       child: Container(
//         width: double.infinity,
//         padding: const EdgeInsets.symmetric(vertical: 13),
//         decoration: BoxDecoration(
//           color: disabled
//               ? const Color(0xFFF3F4F6)
//               : Colors.white,
//           borderRadius: BorderRadius.circular(14),
//           border: Border.all(
//             color: disabled
//                 ? const Color(0xFFE5E7EB)
//                 : const Color(0xFFE5E7EB),
//           ),
//         ),
//         child: Row(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             Icon(
//               icon,
//               size: 16,
//               color: disabled
//                   ? _C.muted
//                   : _C.text.withOpacity(0.7),
//             ),
//             const SizedBox(width: 8),
//             Text(
//               label,
//               style: TextStyle(
//                 color: disabled
//                     ? _C.muted
//                     : _C.text.withOpacity(0.8),
//                 fontSize: 13,
//                 fontWeight: FontWeight.w600,
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

// /// Red danger/cancel button
// class _DangerBtn extends StatelessWidget {
//   final String label;
//   final VoidCallback onTap;
//   const _DangerBtn({required this.label, required this.onTap});

//   @override
//   Widget build(BuildContext context) {
//     return GestureDetector(
//       onTap: onTap,
//       child: Container(
//         width: double.infinity,
//         padding: const EdgeInsets.symmetric(vertical: 13),
//         decoration: BoxDecoration(
//           color: _C.red.withOpacity(0.08),
//           borderRadius: BorderRadius.circular(14),
//           border: Border.all(color: _C.red.withOpacity(0.3)),
//         ),
//         child: Row(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             const Icon(Icons.cancel_rounded,
//                 color: _C.red, size: 17),
//             const SizedBox(width: 8),
//             Text(
//               label,
//               style: const TextStyle(
//                 color: _C.red,
//                 fontSize: 13,
//                 fontWeight: FontWeight.w700,
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

// // ════════════════════════════════════════════════════════════════════════════
// // HELPER FUNCTIONS
// // ════════════════════════════════════════════════════════════════════════════

// Widget _avatarPlaceholder() => Container(
//       width: 48,
//       height: 48,
//       decoration: const BoxDecoration(
//         shape: BoxShape.circle,
//         gradient: LinearGradient(
//           colors: [Color(0xFF1A2E38), Color(0xFF243040)],
//         ),
//       ),
//       child: const Icon(Icons.person, color: _C.muted, size: 24),
//     );

// Widget _addrDot(Color color, {bool glowing = false}) => Container(
//       width: 12,
//       height: 12,
//       decoration: BoxDecoration(
//         shape: BoxShape.circle,
//         color: color.withOpacity(0.18),
//         border: Border.all(color: color, width: 2),
//         boxShadow: glowing
//             ? [BoxShadow(color: color.withOpacity(0.5), blurRadius: 6)]
//             : null,
//       ),
//     );

// Widget _addrLabel(String t) => Text(
//       t,
//       style: const TextStyle(
//         fontSize: 10,
//         fontWeight: FontWeight.w700,
//         color: _C.muted,
//         letterSpacing: 1.0,
//       ),
//     );

// Widget _addrVal(String t) => Text(
//       t,
//       maxLines: 2,
//       overflow: TextOverflow.ellipsis,
//       style: TextStyle(
//         fontSize: 12.5,
//         color: _C.text.withOpacity(0.75),
//         height: 1.35,
//         fontWeight: FontWeight.w400,
//       ),
//     );

// Widget _boldText(String t,
//         {double size = 14, Color color = _C.text}) =>
//     Text(
//       t,
//       style: TextStyle(
//         fontSize: size,
//         fontWeight: FontWeight.w700,
//         color: color,
//       ),
//     );

// Widget _mutedText(String t, {double size = 13}) => Text(
//       t,
//       style: TextStyle(
//         fontSize: size,
//         fontWeight: FontWeight.w500,
//         color: _C.muted,
//       ),
//     );

// import 'dart:async';

// import 'package:action_slider/action_slider.dart';
// import 'package:cached_network_image/cached_network_image.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:get/get.dart';
// import 'package:google_maps_flutter/google_maps_flutter.dart';
// import 'package:url_launcher/url_launcher.dart';

// import 'package:hopper/Core/Constants/Colors.dart';
// import 'package:hopper/Core/Utility/Buttons.dart';
// import 'package:hopper/Core/Utility/app_loader.dart';
// import 'package:hopper/Core/Utility/images.dart';
// import 'package:hopper/Presentation/Authentication/widgets/textFields.dart';
// import 'package:hopper/Presentation/DriverScreen/controller/driver_status_controller.dart';
// import 'package:hopper/Presentation/DriverScreen/screens/SharedBooking/Controller/shared_ride_controller.dart';
// import 'package:hopper/Presentation/DriverScreen/screens/SharedBooking/Screens/share_ride_start_screen.dart';
// import 'package:hopper/Presentation/DriverScreen/screens/chat_screen.dart';
// import 'package:hopper/Presentation/DriverScreen/screens/driver_main_screen.dart';
// import 'package:hopper/utils/map/shared_map.dart';
// import 'package:hopper/utils/netWorkHandling/network_handling_screen.dart';
// import 'package:hopper/utils/map/navigation_assist.dart';

// import '../Controller/booking_request_controller.dart';
// import '../Controller/picking_customer_shared_controller.dart';
// import '../../verify_rider_screen.dart';
// import 'booking_overlay_request.dart';

// class PickingCustomerSharedScreen extends StatefulWidget {
//   final LatLng pickupLocation;
//   final String? pickupLocationAddress;
//   final String? dropLocationAddress;
//   final LatLng driverLocation;
//   final String bookingId;

//   const PickingCustomerSharedScreen({
//     super.key,
//     required this.pickupLocation,
//     required this.driverLocation,
//     required this.bookingId,
//     this.pickupLocationAddress,
//     this.dropLocationAddress,
//   });

//   @override
//   State<PickingCustomerSharedScreen> createState() =>
//       _PickingCustomerSharedScreenState();
// }

// class _PickingCustomerSharedScreenState
//     extends State<PickingCustomerSharedScreen> {
//   static const List<String> _quickReplies = <String>[
//     "I reached pickup",
//     "2 mins away",
//     "Please come to gate",
//     "Traffic, little delay",
//   ];

//   final GlobalKey<SharedMapState> _mapKey = GlobalKey<SharedMapState>();

//   late final PickingCustomerSharedController c;
//   final SharedRideController sharedRideController =
//       Get.find<SharedRideController>();
//   final DriverStatusController driverStatusController =
//       Get.find<DriverStatusController>();
//   final BookingRequestController bookingController =
//       Get.find<BookingRequestController>();

//   Timer? _globalTimer;

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

//     c = Get.put(
//       PickingCustomerSharedController(
//         pickupLocation: widget.pickupLocation,
//         driverLocation: widget.driverLocation,
//         bookingId: widget.bookingId,
//       ),
//       tag: widget.bookingId,
//     );

//     c.socketService.on('driver-cancelled', (data) {
//       if (data != null && data['status'] == true) {
//         if (!mounted) return;
//         Get.offAll(() => const DriverMainScreen());
//       }
//     });

//     c.socketService.on('customer-cancelled', (data) {
//       if (data != null && data['status'] == true) {
//         if (!mounted) return;
//         Get.offAll(() => const DriverMainScreen());
//       }
//     });

//   }

//   @override
//   void dispose() {
//     _globalTimer?.cancel();

//     try {
//       c.socketService.off('driver-cancelled');
//       c.socketService.off('customer-cancelled');
//     } catch (_) {}

//     if (Get.isRegistered<PickingCustomerSharedController>(
//       tag: widget.bookingId,
//     )) {
//       Get.delete<PickingCustomerSharedController>(tag: widget.bookingId);
//     }

//     super.dispose();
//   }

//   // ---------------- timer for no-show ----------------
//   void _startNoShowTimer(SharedRiderItem rider) {
//     rider.secondsLeft = 300;
//     sharedRideController.riders.refresh();

//     if (_globalTimer != null) return;

//     _globalTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
//       if (!mounted) {
//         timer.cancel();
//         _globalTimer = null;
//         return;
//       }

//       bool anyActive = false;

//       for (final r in sharedRideController.riders) {
//         if (r.secondsLeft > 0) {
//           if (r.secondsLeft == 1) {
//             Get.find<DriverAnalyticsController>().trackNoShow();
//           }
//           r.secondsLeft--;
//           anyActive = true;
//         }
//       }

//       sharedRideController.riders.refresh();

//       if (!anyActive) {
//         timer.cancel();
//         _globalTimer = null;
//       }
//     });
//   }

//   String _formatTimer(int seconds) {
//     final m = (seconds ~/ 60).toString().padLeft(2, '0');
//     final s = (seconds % 60).toString().padLeft(2, '0');
//     return '$m:$s';
//   }

//   String _formatDistance(double meters) {
//     final km = (meters <= 0) ? 0.0 : meters / 1000.0;
//     return '${km.toStringAsFixed(1)} Km';
//   }

//   String _formatDuration(double minutes) {
//     final total = minutes.isFinite ? minutes.round() : 0;
//     final h = total ~/ 60;
//     final m = total % 60;
//     return h > 0 ? '$h hr $m min' : '$m min';
//   }

//   Future<void> _launchPhone(String phone) async {
//     final Uri url = Uri.parse('tel:$phone');
//     if (await canLaunchUrl(url)) {
//       await launchUrl(url);
//       return;
//     }

//     if (!mounted) return;
//     ScaffoldMessenger.of(context).showSnackBar(
//       const SnackBar(content: Text('Unable to open call app')),
//     );
//   }

//   Future<void> _onSelectRider(SharedRiderItem rider) async {
//     await c.selectRider(rider);

//     final mapState = _mapKey.currentState;
//     if (mapState != null) {
//       mapState.pauseAutoFollow(const Duration(seconds: 2));
//       await mapState.focusOnCustomerRoute(
//         c.routeUi.value.driverLocation,
//         rider.pickupLatLng,
//       );
//     }
//   }

//   Future<void> _sendQuickReply(SharedRiderItem rider, String text) async {
//     await c.sendQuickMessage(bookingId: rider.bookingId, text: text);
//     if (!mounted) return;
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(content: Text('Sent: $text')),
//     );
//   }

//   Future<void> _recenterToActiveRoute() async {
//     final mapState = _mapKey.currentState;
//     if (mapState == null) return;
//     final active = sharedRideController.activeTarget.value;
//     if (active == null) {
//       await mapState.fitRouteBounds();
//       return;
//     }
//     mapState.pauseAutoFollow(const Duration(seconds: 2));
//     await mapState.focusOnCustomerRoute(
//       c.routeUi.value.driverLocation,
//       active.stage == SharedRiderStage.onboardDrop
//           ? active.dropLatLng
//           : active.pickupLatLng,
//     );
//   }

//   // ✅ professional ETA row (uses controller ETA + updating state)
//   Widget _buildPickupEtaRow() {
//     return Obx(() {
//       final minutes = c.etaMinutes.value;
//       final meters = c.etaMeters.value;
//       final updating = c.isEtaUpdating.value;

//       return AnimatedSwitcher(
//         duration: const Duration(milliseconds: 220),
//         child: Container(
//           key: ValueKey(updating ? "updating" : "eta"),
//           margin: const EdgeInsets.symmetric(horizontal: 16),
//           padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
//           decoration: BoxDecoration(
//             borderRadius: BorderRadius.circular(14),
//             gradient: LinearGradient(
//               colors: [
//                 AppColors.commonWhite,
//                 AppColors.commonWhite.withOpacity(0.94),
//               ],
//             ),
//             border: Border.all(color: AppColors.commonBlack.withOpacity(0.07)),
//             boxShadow: [
//               BoxShadow(
//                 color: AppColors.commonBlack.withOpacity(0.06),
//                 blurRadius: 16,
//                 offset: const Offset(0, 6),
//               ),
//             ],
//           ),
//           child:
//               updating
//                   ? Row(
//                     mainAxisAlignment: MainAxisAlignment.center,
//                     children: [
//                       const SizedBox(
//                         height: 18,
//                         width: 18,
//                         child: CircularProgressIndicator(strokeWidth: 2),
//                       ),
//                       const SizedBox(width: 10),
//                       CustomTextfield.textWithStyles600(
//                         'Refreshing ETA',
//                         fontSize: 14,
//                         color: AppColors.textColorGrey,
//                       ),
//                     ],
//                   )
//                   : Row(
//                     mainAxisAlignment: MainAxisAlignment.center,
//                     children: [
//                       Icon(
//                         Icons.schedule_rounded,
//                         color: AppColors.drkGreen,
//                         size: 16,
//                       ),
//                       const SizedBox(width: 6),
//                       CustomTextfield.textWithStyles600(
//                         _formatDuration(minutes),
//                         fontSize: 16,
//                       ),
//                       const SizedBox(width: 12),
//                       Container(
//                         height: 6,
//                         width: 3,
//                         decoration: BoxDecoration(
//                           color: AppColors.drkGreen,
//                           borderRadius: BorderRadius.circular(20),
//                         ),
//                       ),
//                       const SizedBox(width: 12),
//                       Icon(
//                         Icons.route_rounded,
//                         color: AppColors.commonBlack.withOpacity(0.7),
//                         size: 16,
//                       ),
//                       const SizedBox(width: 6),
//                       CustomTextfield.textWithStyles600(
//                         _formatDistance(meters),
//                         fontSize: 16,
//                       ),
//                     ],
//                   ),
//         ),
//       );
//     });
//   }

//   Widget _buildRiderCard(SharedRiderItem rider, {required bool isActive}) {
//     final bool showRedTimer = rider.secondsLeft > 0 && rider.secondsLeft <= 10;

//     return InkWell(
//       onTap: () => _onSelectRider(rider),
//       child: AnimatedContainer(
//         duration: const Duration(milliseconds: 220),
//         curve: Curves.easeOut,
//         margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
//         padding: const EdgeInsets.symmetric(vertical: 10),
//         decoration: BoxDecoration(
//           gradient: LinearGradient(
//             begin: Alignment.topCenter,
//             end: Alignment.bottomCenter,
//             colors: [
//               Colors.white,
//               Colors.white.withOpacity(0.97),
//             ],
//           ),
//           borderRadius: BorderRadius.circular(16),
//           border: Border.all(
//             color: isActive ? AppColors.drkGreen : Colors.grey.shade300,
//             width: isActive ? 2.0 : 1,
//           ),
//           boxShadow:
//               isActive
//                   ? [
//                     BoxShadow(
//                       color: AppColors.drkGreen.withOpacity(0.18),
//                       blurRadius: 20,
//                       offset: const Offset(0, 8),
//                     ),
//                   ]
//                   : const [
//                     BoxShadow(
//                       color: Color(0x1A000000),
//                       blurRadius: 14,
//                       offset: Offset(0, 6),
//                     ),
//                   ],
//         ),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             if (rider.secondsLeft > 0)
//               Center(
//                 child: Container(
//                   padding: const EdgeInsets.symmetric(
//                     horizontal: 16,
//                     vertical: 7,
//                   ),
//                   decoration: BoxDecoration(
//                     color: showRedTimer ? AppColors.red.withOpacity(0.08) : Colors.white,
//                     borderRadius: BorderRadius.circular(30),
//                     border: Border.all(
//                       color:
//                           showRedTimer
//                               ? AppColors.timerBorderColor
//                               : AppColors.commonBlack.withOpacity(0.15),
//                       width: 3.2,
//                     ),
//                   ),
//                   child: Text(
//                     _formatTimer(rider.secondsLeft),
//                     style: TextStyle(
//                       fontSize: 13,
//                       fontWeight: FontWeight.bold,
//                       letterSpacing: 1.4,
//                       color:
//                           showRedTimer
//                               ? AppColors.timerBorderColor
//                               : AppColors.commonBlack,
//                     ),
//                   ),
//                 ),
//               ),
//             const SizedBox(height: 6),
//             ListTile(
//               contentPadding: const EdgeInsets.symmetric(horizontal: 12),
//               minLeadingWidth: 48,
//               trailing: Row(
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   GestureDetector(
//                     onTap: () => _launchPhone(rider.phone),
//                     child: Container(
//                       decoration: BoxDecoration(
//                         color: AppColors.drkGreen.withOpacity(0.12),
//                         borderRadius: BorderRadius.circular(30),
//                         border: Border.all(
//                           color: AppColors.drkGreen.withOpacity(0.28),
//                         ),
//                       ),
//                       padding: const EdgeInsets.all(10),
//                       child: Icon(
//                         Icons.call_rounded,
//                         color: AppColors.drkGreen,
//                         size: 22,
//                       ),
//                     ),
//                   ),
//                   const SizedBox(width: 10),
//                   GestureDetector(
//                     onTap:
//                         () => Get.to(() => ChatScreen(bookingId: rider.bookingId)),
//                     child: Container(
//                       decoration: BoxDecoration(
//                         color: AppColors.commonBlack.withOpacity(0.05),
//                         borderRadius: BorderRadius.circular(30),
//                         border: Border.all(
//                           color: AppColors.commonBlack.withOpacity(0.06),
//                         ),
//                       ),
//                       padding: const EdgeInsets.all(10),
//                       child: Image.asset(AppImages.msg, height: 25, width: 25),
//                     ),
//                   ),
//                 ],
//               ),
//               leading: GestureDetector(
//                 onTap: () => _launchPhone(rider.phone),
//                 child: Padding(
//                   padding: const EdgeInsets.all(5),
//                   child: ClipOval(
//                     child: CachedNetworkImage(
//                       imageUrl: rider.profilePic,
//                       height: 46,
//                       width: 46,
//                       fit: BoxFit.cover,
//                       placeholder:
//                           (_, __) => const SizedBox(
//                             height: 40,
//                             width: 40,
//                             child: CircularProgressIndicator(strokeWidth: 2),
//                           ),
//                       errorWidget:
//                           (_, __, ___) => const Icon(
//                             Icons.person,
//                             size: 30,
//                             color: Colors.black,
//                           ),
//                     ),
//                   ),
//                 ),
//               ),
//               title: CustomTextfield.textWithStyles600(
//                 rider.name,
//                 fontSize: 17,
//               ),
//               subtitle: CustomTextfield.textWithStylesSmall(
//                 rider.stage == SharedRiderStage.onboardDrop
//                     ? 'Onboard Rider'
//                     : 'Shared Rider',
//                 fontSize: 13,
//                 colors: AppColors.textColorGrey,
//               ),
//             ),
//             const SizedBox(height: 6),
//             Padding(
//               padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
//               child: Column(
//                 children: [
//                   _addrRow(
//                     title: 'Pickup',
//                     address: rider.pickupAddress,
//                     dotColor: Colors.black,
//                   ),
//                   const SizedBox(height: 10),
//                   _addrRow(
//                     title: 'Drop off',
//                     address: rider.dropoffAddress,
//                     dotColor: AppColors.grey,
//                   ),
//                 ],
//               ),
//             ),
//             Padding(
//               padding: const EdgeInsets.symmetric(horizontal: 16),
//               child: Wrap(
//                 spacing: 8,
//                 runSpacing: 8,
//                 children:
//                     _quickReplies
//                         .map(
//                           (msg) => InkWell(
//                             onTap: () => _sendQuickReply(rider, msg),
//                             borderRadius: BorderRadius.circular(18),
//                             child: Container(
//                               padding: const EdgeInsets.symmetric(
//                                 horizontal: 12,
//                                 vertical: 8,
//                               ),
//                               decoration: BoxDecoration(
//                                 color: AppColors.commonBlack.withOpacity(0.04),
//                                 borderRadius: BorderRadius.circular(18),
//                                 border: Border.all(
//                                   color: AppColors.commonBlack.withOpacity(0.08),
//                                 ),
//                               ),
//                               child: Text(
//                                 msg,
//                                 style: const TextStyle(
//                                   fontSize: 12,
//                                   fontWeight: FontWeight.w600,
//                                 ),
//                               ),
//                             ),
//                           ),
//                         )
//                         .toList(),
//               ),
//             ),
//             const SizedBox(height: 10),
//             Padding(
//               padding: const EdgeInsets.symmetric(horizontal: 16),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   if (!rider.arrived &&
//                       rider.stage == SharedRiderStage.waitingPickup) ...[
//                     Obx(() {
//                       final isLoading =
//                           driverStatusController
//                               .arrivedLoadingBookingId
//                               .value ==
//                           rider.bookingId;

//                       return Buttons.button(
//                         buttonColor: AppColors.resendBlue,
//                         borderRadius: 10,
//                         onTap:
//                             isLoading
//                                 ? null
//                                 : () async {
//                                   final result = await driverStatusController
//                                       .driverArrived(
//                                         context,
//                                         bookingId: rider.bookingId,
//                                       );

//                                   if (result != null && result.status == 200) {
//                                     rider.arrived = true;
//                                     sharedRideController.markArrived(
//                                       rider.bookingId,
//                                     );
//                                     _startNoShowTimer(rider);
//                                     setState(() {});
//                                   } else {
//                                     ScaffoldMessenger.of(context).showSnackBar(
//                                       SnackBar(
//                                         content: Text(
//                                           result?.message ??
//                                               "Something went wrong",
//                                         ),
//                                       ),
//                                     );
//                                   }
//                                 },
//                         text:
//                             isLoading
//                                 ? SizedBox(
//                                   height: 20,
//                                   width: 20,
//                                   child: AppLoader.circularLoader(),
//                                 )
//                                 : const Text('Arrived at Shared Pickup Point'),
//                       );
//                     }),
//                   ] else if (rider.arrived &&
//                       rider.stage == SharedRiderStage.waitingPickup) ...[
//                     ActionSlider.standard(
//                       controller: rider.sliderController,
//                       action: (controller) async {
//                         controller.loading();

//                         final msg = await driverStatusController.otpRequest(
//                           context,
//                           bookingId: rider.bookingId,
//                           custName: rider.name,
//                           pickupAddress: rider.pickupAddress,
//                           dropAddress: rider.dropoffAddress,
//                         );

//                         if (msg == null) {
//                           controller.failure();
//                           ScaffoldMessenger.of(context).showSnackBar(
//                             const SnackBar(content: Text('Failed to send OTP')),
//                           );
//                           return;
//                         }

//                         final verified = await Navigator.push<bool>(
//                           context,
//                           MaterialPageRoute(
//                             builder:
//                                 (_) => VerifyRiderScreen(
//                                   bookingId: rider.bookingId,
//                                   custName: rider.name,
//                                   pickupAddress: rider.pickupAddress,
//                                   dropAddress: rider.dropoffAddress,
//                                   isSharedRide: true,
//                                 ),
//                           ),
//                         );

//                         if (verified == true) {
//                           controller.success();
//                           sharedRideController.markOnboard(rider.bookingId);
//                           if (!mounted) return;

//                           Get.off(
//                             () => ShareRideStartScreen(
//                               pickupLocation: rider.pickupLatLng,
//                               driverLocation: c.routeUi.value.driverLocation,
//                               bookingId: widget.bookingId,
//                             ),
//                           );
//                         } else {
//                           controller.reset();
//                         }
//                       },
//                       height: 50,
//                       backgroundColor: const Color(0xFF1C1C1C),
//                       toggleColor: Colors.white,
//                       icon: const Icon(
//                         Icons.double_arrow,
//                         color: Colors.black,
//                         size: 28,
//                       ),
//                       child: Text(
//                         'Swipe to Start Ride for ${rider.name}',
//                         style: const TextStyle(
//                           color: Colors.white,
//                           fontSize: 18,
//                           fontWeight: FontWeight.bold,
//                         ),
//                       ),
//                     ),
//                   ] else if (rider.stage == SharedRiderStage.onboardDrop) ...[
//                     CustomTextfield.textWithStylesSmall(
//                       'Already onboard (drop from Start screen)',
//                       colors: AppColors.textColorGrey,
//                       fontSize: 13,
//                     ),
//                   ],
//                 ],
//               ),
//             ),
//             const SizedBox(height: 10),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _addrRow({
//     required String title,
//     required String address,
//     required Color dotColor,
//   }) {
//     return Row(
//       children: [
//         Container(
//           decoration: BoxDecoration(
//             borderRadius: BorderRadius.circular(40),
//             color: AppColors.commonBlack.withOpacity(0.08),
//           ),
//           padding: const EdgeInsets.all(4),
//           child: Icon(Icons.circle, size: 10, color: dotColor),
//         ),
//         const SizedBox(width: 16),
//         Expanded(
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               CustomTextfield.textWithStyles600(title, fontSize: 14),
//               CustomTextfield.textWithStylesSmall(
//                 address,
//                 colors: AppColors.textColorGrey,
//                 maxLine: 2,
//               ),
//             ],
//           ),
//         ),
//       ],
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return NoInternetOverlay(
//       child: WillPopScope(
//         onWillPop: () async => false,
//         child: Scaffold(
//           body: Obx(() {
//             final uiState = c.routeUi.value;

//             final currentTarget =
//                 sharedRideController.activeTarget.value?.pickupLatLng ??
//                 widget.pickupLocation;

//             final markers = <Marker>{
//               Marker(
//                 markerId: const MarkerId('driver'),
//                 position: uiState.driverLocation,
//                 icon: c.carIcon.value ?? BitmapDescriptor.defaultMarker,
//                 rotation: uiState.bearing,
//                 anchor: const Offset(0.5, 0.5),
//                 flat: true,
//               ),
//               Marker(
//                 markerId: const MarkerId('pickup_main'),
//                 position: widget.pickupLocation,
//                 infoWindow: const InfoWindow(title: 'Pickup Area'),
//               ),
//               ...sharedRideController.riders.map(
//                 (r) => Marker(
//                   markerId: MarkerId('pickup_${r.bookingId}'),
//                   position: r.pickupLatLng,
//                   icon: BitmapDescriptor.defaultMarkerWithHue(
//                     BitmapDescriptor.hueGreen,
//                   ),
//                   infoWindow: InfoWindow(title: r.name),
//                 ),
//               ),
//             };

//             return Stack(
//               children: [
//                 SizedBox(
//                   height: 550,
//                   width: double.infinity,
//                   child: SharedMap(
//                     key: _mapKey,
//                     initialPosition: widget.pickupLocation,
//                     pickupPosition: currentTarget,
//                     markers: markers,
//                     followDriver: true,
//                     followZoom: c.followZoom.value,
//                     followTilt: 42,
//                     polylines: {
//                       if (uiState.polyline.length >= 2)
//                         Polyline(
//                           polylineId: const PolylineId("route_to_rider"),
//                           color: AppColors.commonBlack,
//                           width: 5,
//                           points: uiState.polyline,
//                         ),
//                     },
//                     myLocationEnabled: true,
//                     fitToBounds: false,
//                   ),
//                 ),
//                 Positioned(
//                   top: 45,
//                   left: 10,
//                   right: 10,
//                   child: _DirectionHeader(
//                     maneuver: uiState.maneuver,
//                     distanceText: uiState.distanceText,
//                     directionText: uiState.directionText,
//                   ),
//                 ),
//                 if (c.isNetworkOffline.value || c.pendingQueueCount.value > 0)
//                   Positioned(
//                     top: 145,
//                     left: 12,
//                     right: 12,
//                     child: Container(
//                       padding: const EdgeInsets.symmetric(
//                         horizontal: 12,
//                         vertical: 10,
//                       ),
//                       decoration: BoxDecoration(
//                         color: const Color(0xFF1F2937),
//                         borderRadius: BorderRadius.circular(12),
//                       ),
//                       child: Text(
//                         c.isNetworkOffline.value
//                             ? 'No internet. Route cache active, syncing when online.'
//                             : 'Sync pending: ${c.pendingQueueCount.value} message(s)',
//                         style: const TextStyle(
//                           color: Colors.white,
//                           fontSize: 12,
//                           fontWeight: FontWeight.w600,
//                         ),
//                       ),
//                     ),
//                   ),
//                 if (c.isOffRouteAlert.value)
//                   Positioned(
//                     top: 198,
//                     left: 12,
//                     right: 12,
//                     child: Container(
//                       padding: const EdgeInsets.symmetric(
//                         horizontal: 12,
//                         vertical: 10,
//                       ),
//                       decoration: BoxDecoration(
//                         color: Colors.amber.shade100,
//                         borderRadius: BorderRadius.circular(12),
//                         border: Border.all(color: Colors.amber.shade700),
//                       ),
//                       child: Row(
//                         children: [
//                           const Icon(Icons.warning_amber_rounded, size: 18),
//                           const SizedBox(width: 8),
//                           const Expanded(
//                             child: Text(
//                               'Route deviation detected',
//                               style: TextStyle(
//                                 fontSize: 12,
//                                 fontWeight: FontWeight.w700,
//                               ),
//                             ),
//                           ),
//                           TextButton(
//                             onPressed: _recenterToActiveRoute,
//                             child: const Text('Recenter'),
//                           ),
//                         ],
//                       ),
//                     ),
//                   ),
//                 Positioned(
//                   top: 350,
//                   right: 10,
//                   child: SafeArea(
//                     child: GestureDetector(
//                       onTap: () {
//                         final mapState = _mapKey.currentState;
//                         if (mapState == null) return;
//                         mapState.pauseAutoFollow(const Duration(seconds: 4));

//                         if (c.isDriverFocused.value) {
//                           mapState.fitRouteBounds();
//                         } else {
//                           mapState.focusPickup();
//                         }
//                         c.isDriverFocused.value = !c.isDriverFocused.value;
//                       },
//                       child: Container(
//                         height: 42,
//                         width: 42,
//                         decoration: BoxDecoration(
//                           color: Colors.white,
//                           borderRadius: BorderRadius.circular(12),
//                           boxShadow: const [
//                             BoxShadow(
//                               color: Colors.black12,
//                               blurRadius: 10,
//                               offset: Offset(0, 4),
//                             ),
//                           ],
//                           border: Border.all(
//                             color: Colors.black.withOpacity(0.05),
//                           ),
//                         ),
//                         child: Icon(
//                           c.isDriverFocused.value
//                               ? Icons.crop_square_rounded
//                               : Icons.my_location,
//                           size: 22,
//                           color: Colors.black87,
//                         ),
//                       ),
//                     ),
//                   ),
//                 ),
//                 DraggableScrollableSheet(
//                   initialChildSize: 0.45,
//                   minChildSize: 0.35,
//                   maxChildSize: 0.99,
//                   builder: (context, scrollController) {
//                     return Container(
//                       decoration: BoxDecoration(
//                         color: const Color(0xFFF8F9FB),
//                         borderRadius: const BorderRadius.vertical(
//                           top: Radius.circular(26),
//                         ),
//                         boxShadow: [
//                           BoxShadow(
//                             color: AppColors.commonBlack.withOpacity(0.12),
//                             blurRadius: 28,
//                             offset: const Offset(0, -8),
//                           ),
//                         ],
//                       ),
//                       child: Obx(() {
//                         final active = sharedRideController.activeTarget.value;
//                         final showEta =
//                             active != null ||
//                             c.isEtaUpdating.value ||
//                             c.etaMinutes.value > 0 ||
//                             c.etaMeters.value > 0;

//                         return ListView(
//                           controller: scrollController,
//                           physics: const BouncingScrollPhysics(),
//                           children: [
//                             const SizedBox(height: 6),
//                             Center(
//                               child: Container(
//                                 width: 64,
//                                 height: 6,
//                                 decoration: BoxDecoration(
//                                   color: Colors.grey[350],
//                                   borderRadius: BorderRadius.circular(10),
//                                 ),
//                               ),
//                             ),
//                             const SizedBox(height: 8),
//                             if (showEta) ...[
//                               const SizedBox(height: 8),
//                               _buildPickupEtaRow(),
//                               const SizedBox(height: 12),
//                             ],
//                             if (sharedRideController.riders.isEmpty)
//                               Padding(
//                                 padding: const EdgeInsets.all(24.0),
//                                 child: Center(
//                                   child: CustomTextfield.textWithStylesSmall(
//                                     'Waiting for shared ride requests…',
//                                     colors: AppColors.textColorGrey,
//                                   ),
//                                 ),
//                               )
//                             else
//                               ...sharedRideController.riders.map((rider) {
//                                 final activeR =
//                                     sharedRideController.activeTarget.value;
//                                 final isActive =
//                                     activeR != null &&
//                                     activeR.bookingId == rider.bookingId;

//                                 return _buildRiderCard(
//                                   rider,
//                                   isActive: isActive,
//                                 );
//                               }).toList(),
//                             if (sharedRideController.riders.isNotEmpty)
//                               Padding(
//                                 padding: const EdgeInsets.symmetric(
//                                   horizontal: 20,
//                                   vertical: 12,
//                                 ),
//                                 child: Column(
//                                   crossAxisAlignment: CrossAxisAlignment.start,
//                                   children: [
//                                     Obx(() {
//                                       final stopped =
//                                           driverStatusController
//                                               .isStopNewRequests
//                                               .value;

//                                       return Buttons.button(
//                                         borderColor: AppColors.buttonBorder,
//                                         buttonColor:
//                                             stopped
//                                                 ? AppColors.containerColor
//                                                 : AppColors.commonWhite,
//                                         borderRadius: 10,
//                                         textColor: AppColors.commonBlack,
//                                         onTap:
//                                             stopped
//                                                 ? null
//                                                 : () => Buttons.showDialogBox(
//                                                   context: context,
//                                                   onConfirmStop: () async {
//                                                     await driverStatusController
//                                                         .stopNewRideRequest(
//                                                           context: context,
//                                                           stop: true,
//                                                         );
//                                                   },
//                                                 ),
//                                         text: Text(
//                                           stopped
//                                               ? 'Already Stopped'
//                                               : 'Stop New Ride Requests',
//                                         ),
//                                       );
//                                     }),
//                                     const SizedBox(height: 10),
//                                     Buttons.button(
//                                       borderRadius: 10,
//                                       buttonColor: AppColors.red,
//                                       onTap: () {
//                                         Buttons.showCancelRideBottomSheet(
//                                           context,
//                                           onConfirmCancel: (reason) async {
//                                             // ✅ Close bottomsheet first (ONLY ONCE)
//                                             if (Get.isBottomSheetOpen == true) {
//                                               Get.back();
//                                             }

//                                             await driverStatusController
//                                                 .cancelBooking(
//                                                   context,
//                                                   bookingId: widget.bookingId,
//                                                   reason: reason,
//                                                   navigate:
//                                                       true, // ✅ always go main
//                                                   silent: true,
//                                                 );
//                                           },
//                                         );
//                                       },
//                                       text: const Text(
//                                         'Cancel this Shared Ride',
//                                       ),
//                                     ),

//                                     // Buttons.button(
//                                     //   borderRadius: 10,
//                                     //   buttonColor: AppColors.red,
//                                     //   onTap: () {
//                                     //     Buttons.showCancelRideBottomSheet(
//                                     //       context,
//                                     //       onConfirmCancel: (reason) async {
//                                     //         await driverStatusController
//                                     //             .cancelBooking(
//                                     //           bookingId: widget.bookingId,
//                                     //           context,
//                                     //           reason: reason,
//                                     //         );
//                                     //       },
//                                     //     );
//                                     //   },
//                                     //   text: const Text('Cancel this Shared Ride'),
//                                     // ),
//                                     const SizedBox(height: 20),
//                                   ],
//                                 ),
//                               ),
//                           ],
//                         );
//                       }),
//                     );
//                   },
//                 ),
//                 const BookingOverlayRequest(allowNavigate: false),
//               ],
//             );
//           }),
//         ),
//       ),
//     );
//   }
// }

// class _DirectionHeader extends StatelessWidget {
//   final String maneuver;
//   final String distanceText;
//   final String directionText;

//   const _DirectionHeader({
//     required this.maneuver,
//     required this.distanceText,
//     required this.directionText,
//   });

//   @override
//   Widget build(BuildContext context) {
//     final safeDistance = distanceText.isEmpty ? '--' : distanceText;
//     final safeDirection =
//         directionText.isEmpty ? 'Searching best route…' : directionText;

//     return Container(
//       decoration: BoxDecoration(
//         borderRadius: BorderRadius.circular(16),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.2),
//             blurRadius: 20,
//             offset: const Offset(0, 8),
//           ),
//         ],
//       ),
//       child: ClipRRect(
//         borderRadius: BorderRadius.circular(16),
//         child: Row(
//           children: [
//             Expanded(
//               flex: 1,
//               child: Container(
//                 height: 94,
//                 decoration: BoxDecoration(
//                   gradient: LinearGradient(
//                     begin: Alignment.topCenter,
//                     end: Alignment.bottomCenter,
//                     colors: [
//                       AppColors.directionColor.withOpacity(0.95),
//                       AppColors.directionColor,
//                     ],
//                   ),
//                 ),
//                 child: Padding(
//                   padding: const EdgeInsets.symmetric(
//                     vertical: 12,
//                     horizontal: 10,
//                   ),
//                   child: Column(
//                     mainAxisAlignment: MainAxisAlignment.center,
//                     children: [
//                       Container(
//                         padding: const EdgeInsets.all(6),
//                         decoration: BoxDecoration(
//                           color: Colors.white.withOpacity(0.12),
//                           borderRadius: BorderRadius.circular(10),
//                         ),
//                         child: Icon(
//                           NavigationAssist.iconForManeuver(maneuver),
//                           size: 24,
//                           color: Colors.white,
//                         ),
//                       ),
//                       const SizedBox(height: 8),
//                       CustomTextfield.textWithStyles600(
//                         safeDistance,
//                         color: AppColors.commonWhite,
//                         fontSize: 13,
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//             ),
//             Expanded(
//               flex: 3,
//               child: Container(
//                 height: 94,
//                 decoration: BoxDecoration(
//                   gradient: LinearGradient(
//                     begin: Alignment.topLeft,
//                     end: Alignment.bottomRight,
//                     colors: [
//                       AppColors.directionColor1,
//                       AppColors.directionColor1.withOpacity(0.95),
//                     ],
//                   ),
//                 ),
//                 child: Padding(
//                   padding: const EdgeInsets.symmetric(
//                     vertical: 14,
//                     horizontal: 14,
//                   ),
//                   child: Align(
//                     alignment: Alignment.centerLeft,
//                     child: CustomTextfield.textWithStyles600(
//                       safeDirection,
//                       fontSize: 13,
//                       color: AppColors.commonWhite,
//                       maxLine: 2,
//                     ),
//                   ),
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
