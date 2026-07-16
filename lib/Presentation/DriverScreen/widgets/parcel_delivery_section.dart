// Parcel delivery trust — driver-side PACKAGE DELIVERY panel.
//
// Step-based card stack shown on the drop screen for parcel bookings only:
//   1. header (title / PKG id / real parcelStatus badge / progress out of 5)
//   2. receiver card (name / call / instruction / address type)
//   3. address card (pickup / delivery / distance-ETA)
//   4. package details card (type / weight / description / fragile / payment)
//   5. trust checklist (Pickup OTP → Start delivery → Out for delivery →
//      Receiver OTP → POD photo → Complete)
//   6. ONE action card matching the current parcelStatus:
//      - pre-transit      -> Start Delivery  -> POST /users/parcel/start-delivery
//      - IN_TRANSIT       -> Out for Delivery -> POST /users/parcel/out-for-delivery
//      - OUT_FOR_DELIVERY -> delivery OTP action card, then POD photo action card
// The Complete slider itself lives in ride_stats_screen and stays LOCKED until
// receiver OTP + POD are done. Backend remains the source of truth throughout
// (parcelStatus is never advanced locally without a successful API response).
//
// The delivery OTP is NEVER displayed — the driver types the code the
// receiver got by SMS. The pickup OTP is verified on the earlier pickup
// screen (verify_rider_screen.dart), not here.

import 'dart:async';

import 'package:action_slider/action_slider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pin_code_fields/pin_code_fields.dart';

import 'package:hopper/Core/Constants/Colors.dart';
import 'package:hopper/Core/Utility/snackbar.dart';
import 'package:hopper/Presentation/CustomerSupport/screens/customer_support_list_screen.dart';
import 'package:hopper/Presentation/DriverScreen/controller/ride_starts_controller.dart';
import 'package:hopper/Presentation/DriverScreen/screens/chat_screen.dart';
import 'package:hopper/Presentation/DriverScreen/widgets/package_status_style.dart';
import 'package:hopper/Presentation/DriverScreen/widgets/parcel_dark_theme.dart';
import 'package:hopper/utils/widgets/hoppr_swipe_slider.dart';
import 'package:hopper/utils/phone/call_launcher.dart';

// Light-surface UI tokens (post-pickup panel redesign) — status-specific
// colors come from packageStatusStyle() in package_status_style.dart, which
// is already light-pastel (see its own file header). The panel's SURFACE
// previously used ParcelDarkTheme's full black surfaces, which — combined
// with a too-small DraggableScrollableSheet in ride_stats_screen.dart —
// read as "a large black empty area" rather than an intentional dark theme.
// Surfaces/text/borders now use this file-local light palette (reusing the
// exact pastel values already established in the customer app's
// package_status_style.dart, so this is not a new color palette); brand
// accent colors (green/blue/amber/red) still come straight from
// ParcelDarkTheme.accentXxx, unchanged, per "black/dark only for text,
// buttons, or branded accents". Scoped to this file only — the earlier
// pickup-flow screens (verify_rider_screen.dart, picking_customer_screen.dart)
// keep their existing ParcelDarkTheme surfaces untouched.
class _ParcelSurface {
  _ParcelSurface._();
  static const background = Colors.white;
  static const surface = Colors.white;
  static const surfaceSecondary = Color(0xFFF3F4F6);
  static const surfaceSunken = Color(0xFFF9FAFB);
  static const border = Color(0xFFE5E7EB);
  static const borderStrong = Color(0xFFD1D5DB);
  static const textPrimary = Color(0xFF111827);
  static const textSecondary = Color(0xFF6B7280);
  static const textMuted = Color(0xFF9CA3AF);
}

// Was blue — the app's theme is black/white, so the OTP-entry and POD-photo
// action color (previously named for its old blue value) is black now, with
// a neutral light-grey "soft" chip background instead of a blue tint.
const _kBlue = Color(0xFF0B0B0F);
const _kBlueSoft = Color(0xFFF3F4F6);
const _kGreen = ParcelDarkTheme.accentGreen;
const _kGreenSoft = Color(0xFFEAF9EE); // light green-tinted surface
const _kGreenLine = Color(0xFFBBE8CB);
const _kInk = _ParcelSurface.textPrimary;
const _kGrey = _ParcelSurface.textSecondary;
const _kGreyLight = _ParcelSurface.textMuted;
const _kLine = _ParcelSurface.border;
const _kAmber = ParcelDarkTheme.accentAmber;
const _kAmberSoft = Color(0xFFFFF6E9); // light amber-tinted surface
const _kRedSoft = Color(0xFFFDECEC); // light red-tinted surface

// Bike/Parcel delivery-leg screen redesign — primary brand accent (matches
// the supplied reference layout). Used for brand/identity elements (header,
// progress, route pickup marker, primary CTA); semantic green/amber above
// stay reserved for done/pending state, not brand identity.
const _kPurple = Color(0xFF6C4DFF);
const _kPurpleSoft = Color(0xFFF1EDFF); // lavender surface
const _kPurpleLight = Color(0xFF8B72FF); // gradient highlight stop

// Primary-CTA gradient — same brand purple, just given depth so the button
// reads as the one elevated, "premium" surface on an otherwise flat-card page.
const _kPurpleGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [_kPurpleLight, _kPurple],
);

// Swipe-slider gradient — black, not purple/blue, per the app's black &
// white theme. Used for the Start Delivery / Out for Delivery swipe tracks.
const _kSliderBlack = Color(0xFF17171B);
const _kSliderBlackGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF34343C), _kSliderBlack],
);

// Card border — teal instead of plain grey, a deliberate accent color pick
// for this screen (dividers/progress-track/checklist-connector stay neutral
// grey so they don't compete with it).
const _kTealBorder = Color(0xFF14B8A6);

// A few neutral/utility glyphs (chevrons, the route distance icon) render in
// solid black rather than muted grey for a touch more visual weight against
// the otherwise all-purple icon language.
const _kBlack = Color(0xFF0B0B0F);

// Delivery Actions / Help & Support rows share the same lavender/purple icon
// language as the rest of the sheet (header, route marker, CTA) for a single
// consistent identity end to end.
const _kActionChipBg = _kPurpleSoft;
const _kActionIcon = _kPurple;

/// Const-constructible section-title text — lets card headers stay `const`
/// where the rest of the row already is.
class _CardTitle extends StatelessWidget {
  final String text;
  const _CardTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14.5,
        fontWeight: FontWeight.w800,
        color: _kInk,
      ),
    );
  }
}

/// Thin separator between stacked rows inside a Delivery Actions-style card.
class _ActionDivider extends StatelessWidget {
  const _ActionDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(height: 1, thickness: 1, color: _kLine);
  }
}

class ParcelDeliverySection extends StatefulWidget {
  final RideStatsController controller;

  /// Gates the action card (Start Delivery / Out for Delivery / OTP+POD).
  /// Both call sites in ride_stats_screen.dart now pass true throughout the
  /// whole drop leg — these are actions the driver takes WHILE traveling to
  /// the receiver, not only once GPS says they've arrived, so hiding the
  /// gate would leave the driver without a next-step button. Kept as a
  /// parameter (rather than removed) in case a future caller needs the
  /// info-only view.
  final bool atDropLocation;

  /// Reuses ride_stats_screen.dart's existing `_onNavigatePressed` (location
  /// permission priming + opening turn-by-turn nav) — threaded in rather than
  /// duplicated here so there is exactly one navigation code path.
  final VoidCallback? onNavigate;

  const ParcelDeliverySection({
    super.key,
    required this.controller,
    this.atDropLocation = true,
    this.onNavigate,
  });

  @override
  State<ParcelDeliverySection> createState() => _ParcelDeliverySectionState();
}

class _ParcelDeliverySectionState extends State<ParcelDeliverySection> {
  // Swipe sliders need a controller that survives Obx rebuilds (a fresh one
  // on every rebuild would reset any in-flight drag/loading animation) — owned
  // here by State instead of created inline in the build methods below.
  late final ActionSliderController _startDeliverySlider;
  late final ActionSliderController _outForDeliverySlider;

  RideStatsController get controller => widget.controller;
  bool get atDropLocation => widget.atDropLocation;
  VoidCallback? get onNavigate => widget.onNavigate;

  @override
  void initState() {
    super.initState();
    _startDeliverySlider = ActionSliderController();
    _outForDeliverySlider = ActionSliderController();
  }

  @override
  void dispose() {
    _startDeliverySlider.dispose();
    _outForDeliverySlider.dispose();
    super.dispose();
  }

  // Pre-transit: driver hasn't tapped "Start Delivery" yet (or the snapshot
  // hasn't loaded). OTP/POD only become reachable once OUT_FOR_DELIVERY, per
  // the guided Start Delivery -> En Route to Delivery -> OTP -> POD sequence.
  static const _preTransitStatuses = {
    '',
    'ORDER_CONFIRMED',
    'COURIER_ASSIGNED',
    'PICKED_UP',
  };

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return Obx(() {
      if (!c.isParcel.value) return const SizedBox.shrink();

      final status = c.parcelStatus.value;
      final otpDone = c.deliveryOtpVerified.value;
      final podDone = c.podPhotoUrl.value.isNotEmpty;
      // CASH parcels are paid by the RECEIVER at drop-off, not the sender at
      // pickup — this must gate Complete Delivery the same way OTP/POD do,
      // independent of whatever happened (or didn't) during Start Delivery.
      final isCashMode = c.parcelPaymentMethod.value == 'CASH';
      final cashDone = !c.needsCashCollectionBeforeDelivery;
      final isPreTransit = _preTransitStatuses.contains(status);
      final isInTransit = status == 'IN_TRANSIT';
      final otpPodUnlocked =
          status == 'OUT_FOR_DELIVERY' || status == 'DELIVERED';
      final serverMin = c.driverStatusController.dropDurationInMin.value;
      final etaMin = serverMin > 0 ? serverMin : c.routeDurationMin.value;
      final distM = c.driverStatusController.dropDistanceInMeters.value;

      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isPreTransit || isInTransit) ...[
              _etaHeadline(c, onNavigate, etaMin: etaMin, distM: distM),
              const SizedBox(height: 14),
            ],
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 320),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              transitionBuilder:
                  (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SizeTransition(sizeFactor: animation, child: child),
                  ),
              child: _headerCard(
                key: ValueKey('header-$status-$otpDone-$podDone'),
                status: status,
                otpDone: otpDone,
                podDone: podDone,
              ),
            ),
            const SizedBox(height: 10),
            _receiverCard(context, c),
            const SizedBox(height: 10),
            _addressCard(c),
            const SizedBox(height: 10),
            _paymentStatusCard(c),
            if (_hasPackageDetails(c)) ...[
              const SizedBox(height: 10),
              _packageCard(c),
            ],
            const SizedBox(height: 10),
            _checklistCard(
              status: status,
              otpDone: otpDone,
              podDone: podDone,
              isCashMode: isCashMode,
              cashDone: cashDone,
            ),
            const SizedBox(height: 10),
            _deliveryActionsCard(context, c),
            if (atDropLocation) ...[
              if (isPreTransit) ...[
                const SizedBox(height: 10),
                _startDeliveryActionCard(context, c),
              ] else if (isInTransit) ...[
                const SizedBox(height: 10),
                _outForDeliveryActionCard(
                  context,
                  c,
                  eta: etaMin,
                  distM: distM,
                ),
              ] else if (otpPodUnlocked) ...[
                const SizedBox(height: 10),
                _otpActionCard(context, c, done: otpDone),
                const SizedBox(height: 10),
                _podActionCard(context, c, done: podDone),
                if (isCashMode) ...[
                  const SizedBox(height: 10),
                  _cashCollectionActionCard(context, c, done: cashDone),
                ],
              ],
            ],
            // Help & Support sits last — it's a fallback for when something's
            // wrong, not a step in the delivery flow, so it shouldn't compete
            // with the actions the driver actually needs next.
            const SizedBox(height: 10),
            _helpSupportCard(context, c),
          ],
        ),
      );
    });
  }

  // ── 0. ETA headline ─────────────────────────────────────────────────────

  Widget _etaHeadline(
    RideStatsController c,
    VoidCallback? onNavigate, {
    required double etaMin,
    required double distM,
  }) {
    return Obx(() {
      final name =
          c.receiverName.value.trim().isNotEmpty
              ? c.receiverName.value.trim()
              : c.custName.value.trim();
      // Sub-minute ETAs read as "<1 min" from the shared formatter, which
      // looked broken here — round up to "1 min" instead ("arriving" always
      // means at least a minute out to a driver glancing at this).
      final etaText =
          etaMin <= 0
              ? 'On the way to receiver'
              : 'Arriving in ${etaMin < 1 ? '1 min' : c.formatDuration(etaMin)}';
      final distText =
          distM.isFinite && distM > 0 ? c.formatDistance(distM) : null;
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  distText == null ? etaText : '$etaText  •  $distText',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: _kInk,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  name.isEmpty
                      ? 'Delivering package'
                      : 'Delivering package to $name',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _kGrey,
                  ),
                ),
              ],
            ),
          ),
          if (onNavigate != null) ...[
            const SizedBox(width: 10),
            InkWell(
              borderRadius: BorderRadius.circular(22),
              onTap: () {
                HapticFeedback.selectionClick();
                onNavigate();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: _kPurple, width: 1.3),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.navigation_rounded, size: 15, color: _kPurple),
                    SizedBox(width: 6),
                    Text(
                      'Navigate',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: _kPurple,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      );
    });
  }

  // ── Start Delivery / Out for Delivery actions ──────────────────────────────

  /// Blocks Start Delivery (or, when called at drop-off, Complete Delivery)
  /// for a CASH-mode parcel until the driver confirms they've physically
  /// collected payment — the backend enforces this atomically too
  /// (isParcelPaymentSatisfied), this is just the friendlier UX: ask before
  /// the swipe fails with a snackbar. Same backend call
  /// (confirmParcelCashCollected) either way — CASH is collected from
  /// whichever party actually has it in hand at the point of confirmation,
  /// [payer]/[momentLabel] only change the copy so the driver isn't asked to
  /// confirm collecting "from the sender" while standing at the receiver's
  /// door. Returns true only once confirmCashCollected() has actually
  /// succeeded.
  Future<bool> _confirmCashCollectedSheet(
    BuildContext context,
    RideStatsController c, {
    String payer = 'sender',
    String momentLabel = 'before starting delivery',
  }) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 48,
                        height: 5,
                        decoration: BoxDecoration(
                          color: _kLine,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: const BoxDecoration(
                          color: _kAmberSoft,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.payments_rounded,
                          color: _kAmber,
                          size: 28,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Center(
                      child: Text(
                        'Confirm Cash Collected',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          color: _kInk,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        c.amount.value.trim().isNotEmpty
                            ? 'Confirm you’ve collected ₦${c.amount.value} in cash from the $payer $momentLabel.'
                            : 'Confirm you’ve collected the cash payment from the $payer $momentLabel.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _kGrey,
                          height: 1.45,
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    Obx(
                      () => SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed:
                              c.confirmCashCollectedLoading.value
                                  ? null
                                  : () async {
                                    setSheetState(() {});
                                    final result =
                                        await c.confirmCashCollected();
                                    if (!sheetContext.mounted) return;
                                    if (result.success) {
                                      HapticFeedback.mediumImpact();
                                      Navigator.pop(sheetContext, true);
                                    } else {
                                      HapticFeedback.vibrate();
                                      CustomSnackBar.showError(
                                        result.message.isEmpty
                                            ? 'Could not confirm cash collected'
                                            : result.message,
                                      );
                                    }
                                  },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _kSliderBlack,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child:
                              c.confirmCashCollectedLoading.value
                                  ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                  : const Text(
                                    'Cash Collected',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: () => Navigator.pop(sheetContext, false),
                        child: const Text(
                          'Not yet',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _kGrey,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    return confirmed == true;
  }

  Widget _startDeliveryActionCard(BuildContext context, RideStatsController c) {
    // Title/icon intentionally omitted here — the header card just above
    // already establishes "Package collected" with the same icon, so
    // repeating it in this card read as duplicated content.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'The receiver’s Delivery OTP has been sent. Start the delivery leg when you’re ready.',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: _kGrey,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 14),
        HopprSwipeSlider(
          controller: _startDeliverySlider,
          height: 58,
          backgroundColor: _kSliderBlack,
          backgroundGradient: _kSliderBlackGradient,
          handleColor: Colors.white,
          handleIconColor: _kSliderBlack,
          textColor: Colors.white,
          idleIcon: Icons.two_wheeler_rounded,
          text: 'Swipe to Start Delivery',
          onAction: (slider) async {
            if (c.needsCashCollectionBeforeDelivery) {
              slider.reset();
              final collected = await _confirmCashCollectedSheet(context, c);
              if (!mounted || !collected) return;
            }
            slider.loading();
            final result = await c.startDelivery();
            // The booking may have been cancelled (disposing this screen and
            // _startDeliverySlider along with it) while the request was in
            // flight — touching the slider/snackbar after that throws.
            if (!mounted) return;
            if (result.success) {
              HapticFeedback.mediumImpact();
              slider.success();
            } else {
              HapticFeedback.vibrate();
              slider.failure();
              CustomSnackBar.showError(
                result.message.isEmpty
                    ? 'This package is no longer available for this action.'
                    : result.message,
              );
            }
            await Future<void>.delayed(const Duration(milliseconds: 600));
            if (!mounted) return;
            slider.reset();
          },
        ),
        const SizedBox(height: 8),
        const Center(
          child: Text(
            'Receiver OTP will be verified to complete delivery',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: _kGreyLight,
            ),
          ),
        ),
      ],
    );
  }

  Widget _outForDeliveryActionCard(
    BuildContext context,
    RideStatsController c, {
    required double eta,
    required double distM,
  }) {
    final metaText =
        distM.isFinite && distM > 0 ? c.formatDistance(distM) : null;
    return _card(
      padding: 20,
      radius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: const BoxDecoration(
                  color: _kPurpleSoft,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.local_shipping_rounded,
                  size: 18,
                  color: _kPurple,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(child: _CardTitle('Package on the way')),
              if (metaText != null)
                Text(
                  metaText,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: _kGreyLight,
                    letterSpacing: 0.3,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'On the way to the receiver. Mark out for delivery once you’re close by.',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: _kGrey,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          HopprSwipeSlider(
            controller: _outForDeliverySlider,
            height: 54,
            backgroundColor: _kSliderBlack,
            backgroundGradient: _kSliderBlackGradient,
            handleColor: Colors.white,
            handleIconColor: _kSliderBlack,
            textColor: Colors.white,
            idleIcon: Icons.two_wheeler_rounded,
            text: 'Swipe for Out for Delivery',
            onAction: (slider) async {
              slider.loading();
              final result = await c.markOutForDelivery();
              // Same cancellation-mid-flight guard as _startDeliverySlider
              // above.
              if (!mounted) return;
              if (result.success) {
                HapticFeedback.mediumImpact();
                slider.success();
              } else {
                HapticFeedback.vibrate();
                slider.failure();
                CustomSnackBar.showError(
                  result.message.isEmpty
                      ? 'This package is no longer available for this action.'
                      : result.message,
                );
              }
              await Future<void>.delayed(const Duration(milliseconds: 600));
              if (!mounted) return;
              slider.reset();
            },
          ),
        ],
      ),
    );
  }

  // ── 1. Header ──────────────────────────────────────────────────────────────

  Widget _headerCard({
    Key? key,
    required String status,
    required bool otpDone,
    required bool podDone,
  }) {
    // Pickup is inherently verified on this screen (backend only allows the
    // drop leg after the sender's pickup OTP). Steps: pickup, start delivery,
    // out for delivery, receiver OTP, POD photo — out of 5.
    final doneSteps =
        1 +
        (status == 'IN_TRANSIT' ||
                status == 'OUT_FOR_DELIVERY' ||
                status == 'DELIVERED'
            ? 1
            : 0) +
        (status == 'OUT_FOR_DELIVERY' || status == 'DELIVERED' ? 1 : 0) +
        (otpDone ? 1 : 0) +
        (podDone ? 1 : 0);
    // Pickup is already verified by the time this screen shows — the header
    // should never read "Order confirmed"/"Courier assigned" here.
    final style = packageStatusStyle(status.isEmpty ? 'PICKED_UP' : status);

    return _card(
      key: key,
      padding: 20,
      radius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: _kPurpleSoft,
                  shape: BoxShape.circle,
                ),
                child: Icon(style.icon, size: 22, color: _kPurple),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      style.label,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: _kInk,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      style.message,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: _kGrey,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _kPurpleSoft,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  style.label.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                    color: _kPurple,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                'PKG-${controller.bookingId}',
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: _kGreyLight,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: doneSteps / 5),
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
              builder:
                  (context, value, _) => LinearProgressIndicator(
                    value: value,
                    minHeight: 6,
                    backgroundColor: _kLine,
                    valueColor: const AlwaysStoppedAnimation<Color>(_kPurple),
                  ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$doneSteps of 5 steps completed',
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: _kGrey,
            ),
          ),
        ],
      ),
    );
  }

  // ── 2. Receiver ────────────────────────────────────────────────────────────

  Widget _receiverCard(BuildContext context, RideStatsController c) {
    final name = c.receiverName.value.trim();
    final phone = c.receiverPhone.value.trim();
    final instruction = c.deliveryInstruction.value.trim();
    final addressType = c.parcelAddressType.value.trim();

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle('Receiver'),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _ParcelSurface.surfaceSecondary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.person_rounded, color: _kGrey),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.isEmpty ? 'Receiver' : name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: _kInk,
                      ),
                    ),
                    if (phone.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        phone,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: _kGrey,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (addressType.isNotEmpty) ...[
                _chip(addressType, _kPurpleSoft, _kPurple),
                const SizedBox(width: 8),
              ],
              if (phone.isNotEmpty)
                InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: () async {
                    HapticFeedback.selectionClick();
                    await CallLauncher.openDialer(
                      phone: phone,
                      context: context,
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: _kPurple, width: 1.3),
                    ),
                    child: const Icon(
                      Icons.call_rounded,
                      size: 19,
                      color: _kPurple,
                    ),
                  ),
                ),
            ],
          ),
          if (instruction.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: _kAmberSoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.sticky_note_2_rounded,
                    size: 15,
                    color: _kAmber,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      instruction,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: _kAmber,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── 3. Addresses ───────────────────────────────────────────────────────────

  Widget _addressCard(RideStatsController c) {
    final pickup = c.customerFrom.value.trim();
    final drop = c.customerTo.value.trim();
    final distM = c.driverStatusController.dropDistanceInMeters.value;
    final etaMin = c.driverStatusController.dropDurationInMin.value;
    final metaParts = <String>[
      if (distM.isFinite && distM > 0) c.formatDistance(distM),
      if (etaMin.isFinite && etaMin > 0) '${c.formatDuration(etaMin)} to drop',
    ];

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle('Route Summary'),
          const SizedBox(height: 10),
          if (pickup.isNotEmpty)
            _addressRow(
              icon: Icons.trip_origin_rounded,
              iconColor: _kPurple,
              label: 'Pickup',
              text: pickup,
            ),
          if (pickup.isNotEmpty && drop.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 7),
              child: Container(
                width: 2,
                height: 16,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [_kPurple.withOpacity(0.6), _kLine],
                  ),
                ),
              ),
            ),
          if (drop.isNotEmpty)
            // Same symmetric circle glyph as the pickup marker (not a
            // location-pin, whose "point" sits low in its box) — otherwise
            // the connector line above lines up with pickup but visibly
            // misses the delivery marker's actual dot.
            _addressRow(
              icon: Icons.circle_outlined,
              iconColor: _kGreyLight,
              label: 'Delivery',
              text: drop,
            ),
          if (metaParts.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.route_outlined, size: 15, color: _kBlack),
                const SizedBox(width: 6),
                Text(
                  metaParts.join(' • '),
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: _kBlack,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _addressRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String text,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: iconColor),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: _kGreyLight,
                  letterSpacing: 0.4,
                ),
              ),
              Text(
                text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: _kInk,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── 3b. Payment status (always visible — cash AND online) ──────────────────
  //
  // Previously the only payment-related UI on this screen was the CASH-mode
  // "Confirm Cash Collected" checklist row — an ONLINE payment (Paystack/
  // Flutterwave/Wallet) had NO confirmation UI at all, so the driver could
  // only infer "must be paid online, I guess" from the cash row's absence.
  // `parcelPaymentMethod`/`parcelPaymentStatus` are already updated live via
  // the 'booking-update' socket handler (applyPackageSocketUpdate) — this
  // card just finally renders that already-live data instead of leaving it
  // gating logic invisibly.
  Widget _paymentStatusCard(RideStatsController c) {
    final mode = c.parcelPaymentMethod.value.trim().toUpperCase();
    final status = c.parcelPaymentStatus.value.trim().toUpperCase();
    if (mode.isEmpty && status.isEmpty) return const SizedBox.shrink();

    const methodLabels = {
      'CASH': 'Cash',
      'PAYSTACK': 'Paystack',
      'FLUTTERWAVE': 'Flutterwave',
      'WALLET': 'Hoppr Wallet',
    };
    final methodLabel =
        methodLabels[mode] ?? (mode.isNotEmpty ? mode : 'Payment');

    final settled = status == 'PAID' || status == 'CASH_COLLECTED';
    final cashPending = mode == 'CASH' && status == 'CASH_PENDING';
    final failed = status == 'FAILED';

    late final Color accent;
    late final Color accentSoft;
    late final IconData icon;
    late final String badge;
    late final String sub;
    if (settled) {
      accent = _kGreen;
      accentSoft = _kGreenSoft;
      icon = Icons.verified_rounded;
      badge = 'Paid';
      sub = mode == 'CASH' ? 'Cash collected' : 'Paid online';
    } else if (cashPending) {
      accent = _kAmber;
      accentSoft = _kAmberSoft;
      icon = Icons.payments_rounded;
      badge = 'Pending';
      sub = 'Collect cash from the receiver at drop-off';
    } else if (failed) {
      accent = AppColors.red;
      accentSoft = _kRedSoft;
      icon = Icons.error_outline_rounded;
      badge = 'Failed';
      sub = 'Sender needs to retry payment';
    } else {
      accent = _kAmber;
      accentSoft = _kAmberSoft;
      icon = Icons.hourglass_top_rounded;
      badge = 'Pending';
      sub = 'Waiting for the sender to complete payment';
    }

    return _card(
      padding: 14,
      radius: 16,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: accentSoft,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 16, color: accent),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  methodLabel,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13.5,
                    color: _kInk,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  sub,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: _kGrey,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: accentSoft,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              badge,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: accent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 4. Package details ─────────────────────────────────────────────────────

  bool _hasPackageDetails(RideStatsController c) =>
      c.parcelType.value.trim().isNotEmpty ||
      c.parcelWeight.value.trim().isNotEmpty ||
      c.parcelDescription.value.trim().isNotEmpty;

  bool _isFragile(RideStatsController c) {
    final haystack =
        '${c.parcelType.value} ${c.parcelDescription.value}'.toLowerCase();
    return haystack.contains('fragile') || haystack.contains('glass');
  }

  Widget _packageCard(RideStatsController c) {
    final type = c.parcelType.value.trim();
    final weight = c.parcelWeight.value.trim();
    final description = c.parcelDescription.value.trim();

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: const BoxDecoration(
                  color: _kPurpleSoft,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.inventory_2_rounded,
                  size: 14,
                  color: _kPurple,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: _cardTitle('Package Details')),
              const Icon(Icons.chevron_right_rounded, size: 20, color: _kBlack),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (type.isNotEmpty) _chip(type, _kBlueSoft, _kBlue),
              if (weight.isNotEmpty)
                _chip('$weight kg', _ParcelSurface.surfaceSecondary, _kInk),
              if (_isFragile(c)) _chip('FRAGILE', _kRedSoft, AppColors.red),
            ],
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              description,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: _kGrey,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── 4b. Delivery Actions / Help & Support ───────────────────────────────────

  Widget _deliveryActionsCard(BuildContext context, RideStatsController c) {
    final receiver = c.receiverPhone.value.trim();
    final phone = receiver.isNotEmpty ? receiver : c.customerPhone.value.trim();

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle('Delivery Actions'),
          const SizedBox(height: 6),
          _actionRow(
            icon: Icons.call_rounded,
            title: 'Call Receiver',
            subtitle: phone.isEmpty ? 'Number unavailable' : phone,
            onTap:
                phone.isEmpty
                    ? null
                    : () async {
                      await CallLauncher.openDialer(
                        phone: phone,
                        context: context,
                      );
                    },
          ),
          const _ActionDivider(),
          _actionRow(
            icon: Icons.chat_bubble_rounded,
            title: 'Chat with Receiver',
            subtitle: 'Send a message',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (_) => ChatScreen(
                        bookingId: c.bookingId,
                        initialPhone: phone,
                      ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _helpSupportCard(BuildContext context, RideStatsController c) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle('Help & Support'),
          const SizedBox(height: 6),
          _actionRow(
            icon: Icons.support_agent_rounded,
            title: 'Need help?',
            subtitle: 'Contact support',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (_) => CustomerSupportListScreen(bookingId: c.bookingId),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _actionRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap:
          onTap == null
              ? null
              : () {
                HapticFeedback.selectionClick();
                onTap();
              },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: _kActionChipBg,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 18, color: _kActionIcon),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: _kInk,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _kGrey,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, size: 20, color: _kBlack),
          ],
        ),
      ),
    );
  }

  // ── 5. Trust checklist ─────────────────────────────────────────────────────

  /// Focused once OUT_FOR_DELIVERY (the two remaining requirements for
  /// completion); a lighter 3-item journey view before that — never all 6
  /// steps at once, so the driver always sees only what matters right now.
  Widget _checklistCard({
    required String status,
    required bool otpDone,
    required bool podDone,
    bool isCashMode = false,
    bool cashDone = false,
  }) {
    final startedDelivery =
        status == 'IN_TRANSIT' ||
        status == 'OUT_FOR_DELIVERY' ||
        status == 'DELIVERED';
    final outForDelivery =
        status == 'OUT_FOR_DELIVERY' || status == 'DELIVERED';

    if (outForDelivery) {
      return _card(
        padding: 20,
        radius: 20,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _CardTitle('Delivery requirements'),
            const SizedBox(height: 14),
            _requirementRow(
              icon: Icons.password_rounded,
              label: 'Receiver OTP',
              done: otpDone,
            ),
            const SizedBox(height: 12),
            _requirementRow(
              icon: Icons.photo_camera_rounded,
              label: 'Delivery Photo',
              done: podDone,
              isLast: !isCashMode,
            ),
            if (isCashMode) ...[
              const SizedBox(height: 12),
              _requirementRow(
                icon: Icons.payments_rounded,
                label: 'Cash Payment',
                done: cashDone,
                isLast: true,
              ),
            ],
          ],
        ),
      );
    }

    final delivered = status == 'DELIVERED';

    return _card(
      padding: 20,
      radius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardTitle('Delivery Steps'),
          const SizedBox(height: 14),
          _checkRow(1, 'Pickup OTP verified', done: true, active: false),
          _checkRow(
            2,
            'Start delivery',
            done: startedDelivery,
            active: !startedDelivery,
            subLabel: !startedDelivery ? 'Receiver OTP sent' : null,
          ),
          _checkRow(
            3,
            'Out for delivery',
            done: outForDelivery,
            active: startedDelivery && !outForDelivery,
          ),
          _checkRow(
            4,
            'Delivered',
            done: delivered,
            active: outForDelivery && !delivered,
            isLast: true,
          ),
        ],
      ),
    );
  }

  /// "Receiver OTP — Status: Verified/Required" style row for the focused
  /// two-item completion checklist.
  Widget _requirementRow({
    required IconData icon,
    required String label,
    required bool done,
    bool isLast = false,
  }) {
    final color = done ? _kGreen : _kAmber;
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 4),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: done ? _kGreenSoft : _kAmberSoft,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(
              done ? Icons.check_rounded : icon,
              size: 18,
              color: color,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: _kInk,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: done ? _kGreenSoft : _kAmberSoft,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              done ? 'Verified' : 'Required',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _checkRow(
    int step,
    String label, {
    required bool done,
    required bool active,
    bool isLast = false,
    String? subLabel,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 4),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color:
                        done
                            ? _kPurple
                            : (active
                                ? _kPurpleSoft
                                : _ParcelSurface.surfaceSecondary),
                    shape: BoxShape.circle,
                    border:
                        active && !done ? Border.all(color: _kPurple) : null,
                  ),
                  alignment: Alignment.center,
                  child:
                      done
                          ? const Icon(
                            Icons.check_rounded,
                            size: 15,
                            color: Colors.white,
                          )
                          : Text(
                            '$step',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: active ? _kPurple : _kGreyLight,
                            ),
                          ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 2),
                      color: done ? _kPurple.withOpacity(0.35) : _kLine,
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            label,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: done || active ? _kInk : _kGreyLight,
                            ),
                          ),
                          if (subLabel != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              subLabel,
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: _kPurple,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (done)
                      const Text(
                        'Done',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: _kGreen,
                        ),
                      ),
                    if (active && !done)
                      const Icon(
                        Icons.chevron_right_rounded,
                        size: 20,
                        color: _kPurple,
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 6. Delivery OTP action ─────────────────────────────────────────────────

  Widget _otpActionCard(
    BuildContext context,
    RideStatsController c, {
    required bool done,
  }) {
    if (done) {
      return _successBar(
        icon: Icons.verified_user_rounded,
        text: 'Receiver OTP verified',
      );
    }
    final cooldown = c.deliveryOtpResendCooldown.value;
    final resending = c.deliveryOtpResending.value;

    return _card(
      padding: 20,
      radius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardTitle('Delivery OTP'),
          const SizedBox(height: 4),
          const Text(
            'Ask the receiver for the OTP sent by SMS.',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: _kGrey,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: () => showParcelDeliveryOtpSheet(context, c),
                    icon: const Icon(Icons.password_rounded, size: 20),
                    label: const Text(
                      'Enter OTP',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kBlue,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 52,
                child: OutlinedButton(
                  onPressed:
                      (resending || cooldown > 0)
                          ? null
                          : () async {
                            final result = await c.resendDeliveryOtp();
                            if (result.success) {
                              CustomSnackBar.showSuccess(result.message);
                            } else if (result.message.isNotEmpty) {
                              CustomSnackBar.showError(result.message);
                            }
                          },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _kBlue,
                    side: const BorderSide(color: _kBlue, width: 1.2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    minimumSize: const Size(48, 48),
                  ),
                  child: Text(
                    cooldown > 0
                        ? 'Resend ${cooldown}s'
                        : (resending ? 'Sending…' : 'Resend'),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── 7. POD photo action ────────────────────────────────────────────────────

  Widget _podActionCard(
    BuildContext context,
    RideStatsController c, {
    required bool done,
  }) {
    final uploading = c.podUploading.value;

    Future<void> takePhoto() async {
      HapticFeedback.selectionClick();
      final result = await c.captureAndUploadPodPhoto(
        source: ImageSource.camera,
      );
      // The booking may have been cancelled (tearing this screen down) while
      // the capture/upload was in flight — never touch the snackbar overlay
      // after that.
      if (!mounted) return;
      if (result.message.isEmpty) return; // user cancelled the camera
      if (result.success) {
        HapticFeedback.mediumImpact();
        CustomSnackBar.showSuccess(result.message);
      } else {
        CustomSnackBar.showError(result.message);
      }
    }

    void viewFullPhoto() {
      showDialog(
        context: context,
        barrierColor: Colors.black,
        builder:
            (_) => GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Scaffold(
                backgroundColor: Colors.black,
                body: SafeArea(
                  child: Stack(
                    children: [
                      Center(
                        child: InteractiveViewer(
                          minScale: 1,
                          maxScale: 4,
                          child: CachedNetworkImage(
                            imageUrl: c.podPhotoUrl.value,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(
                            Icons.close_rounded,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
      );
    }

    return _card(
      padding: 20,
      radius: 20,
      borderColor: done ? _kGreenLine : _kTealBorder,
      background: done ? _kGreenSoft : _ParcelSurface.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: _CardTitle('Proof of delivery photo')),
              if (done)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _ParcelSurface.surfaceSecondary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Uploaded',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: _kGreen,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            done
                ? 'Photo saved as proof of handover.'
                : 'Take a clear photo showing the package at the delivery location.',
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: _kGrey,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          if (done) ...[
            InkWell(
              onTap: viewFullPhoto,
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.easeOut,
                    builder:
                        (context, value, child) => Opacity(
                          opacity: value,
                          child: Transform.scale(
                            scale: 0.96 + 0.04 * value,
                            child: child,
                          ),
                        ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: CachedNetworkImage(
                        imageUrl: c.podPhotoUrl.value,
                        width: double.infinity,
                        height: 190,
                        fit: BoxFit.cover,
                        errorWidget:
                            (_, __, ___) => Container(
                              height: 190,
                              color: _ParcelSurface.surfaceSecondary,
                              child: const Icon(
                                Icons.broken_image_rounded,
                                color: _kGrey,
                                size: 32,
                              ),
                            ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 10,
                    bottom: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.55),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.zoom_in_rounded,
                            size: 14,
                            color: Colors.white,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'View full photo',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: uploading ? null : takePhoto,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text(
                  'Replace Photo',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _kGreen,
                  side: const BorderSide(color: _kGreen, width: 1.2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ] else ...[
            InkWell(
              onTap: uploading ? null : takePhoto,
              borderRadius: BorderRadius.circular(16),
              child: DottedBorder(
                options: RoundedRectDottedBorderOptions(
                  color: _kGreyLight,
                  radius: const Radius.circular(16),
                  dashPattern: const [7, 5],
                  strokeWidth: 1.5,
                ),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 28),
                  decoration: BoxDecoration(
                    color: _ParcelSurface.surfaceSunken,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child:
                        uploading
                            ? const Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 26,
                                  height: 26,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.4,
                                    color: _kBlue,
                                  ),
                                ),
                                SizedBox(height: 10),
                                Text(
                                  'Uploading…',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: _kGrey,
                                  ),
                                ),
                              ],
                            )
                            : TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0, end: 1),
                              duration: const Duration(milliseconds: 400),
                              curve: Curves.easeOutBack,
                              builder:
                                  (context, value, child) => Transform.scale(
                                    scale: value,
                                    child: child,
                                  ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: const BoxDecoration(
                                      color: _kBlueSoft,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.photo_camera_rounded,
                                      size: 26,
                                      color: _kBlue,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'Capture Delivery Photo',
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w800,
                                      color: _kInk,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  const Text(
                                    'Tap to open the camera',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                      color: _kGreyLight,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── 8. Cash payment action (CASH-mode parcels only) ────────────────────────
  //
  // Real cash-on-delivery is collected from the RECEIVER at drop-off, not the
  // sender at pickup — the pickup-time sheet (_confirmCashCollectedSheet,
  // reused here with different copy) only covers a BEFORE_DISPATCH/AT_PICKUP
  // plan. This card is what actually unblocks Complete Delivery for a CASH
  // parcel that reaches drop-off still CASH_PENDING.

  Widget _cashCollectionActionCard(
    BuildContext context,
    RideStatsController c, {
    required bool done,
  }) {
    if (done) {
      return _successBar(
        icon: Icons.payments_rounded,
        text: 'Cash payment collected',
      );
    }
    return _card(
      padding: 20,
      radius: 20,
      borderColor: _kAmber,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardTitle('Cash Payment'),
          const SizedBox(height: 4),
          Text(
            c.amount.value.trim().isNotEmpty
                ? 'Collect ₦${c.amount.value} in cash from the receiver before completing delivery.'
                : 'Collect the cash payment from the receiver before completing delivery.',
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: _kGrey,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          Obx(
            () => SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed:
                    c.confirmCashCollectedLoading.value
                        ? null
                        : () async {
                          final collected = await _confirmCashCollectedSheet(
                            context,
                            c,
                            payer: 'receiver',
                            momentLabel: 'before completing delivery',
                          );
                          if (!mounted || !collected) return;
                          HapticFeedback.mediumImpact();
                        },
                icon:
                    c.confirmCashCollectedLoading.value
                        ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                        : const Icon(Icons.payments_rounded, size: 20),
                label: const Text(
                  'Confirm Cash Collected',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kBlue,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── shared building blocks ─────────────────────────────────────────────────

  Widget _card({
    Key? key,
    required Widget child,
    Color background = _ParcelSurface.surface,
    Color borderColor = _kTealBorder,
    double padding = 16,
    double radius = 18,
  }) {
    return Container(
      key: key,
      width: double.infinity,
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor.withOpacity(0.55)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _cardTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13.5,
        fontWeight: FontWeight.w800,
        color: _kInk,
      ),
    );
  }

  Widget _chip(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.3,
          color: fg,
        ),
      ),
    );
  }

  Widget _successBar({required IconData icon, required String text}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: _kGreenSoft,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _kGreenLine),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: _kGreen),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: _kInk,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Locked state shown INSTEAD of the Complete slider until the trust steps
/// are done — the sticky bottom action bar's "locked" visual state. Screen
/// swaps it for the real slider reactively once unlocked.
class ParcelCompleteLockedBar extends StatelessWidget {
  /// Defaults to the OTP+POD-only message for backwards compatibility, but
  /// callers that also gate on cash collection should pass the specific
  /// reason — otherwise a CASH parcel that's done with OTP+POD but not yet
  /// paid shows a message that no longer matches what's actually blocking it.
  final String message;

  const ParcelCompleteLockedBar({
    super.key,
    this.message =
        'Verify receiver OTP and upload delivery photo to complete delivery.',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      width: double.infinity,
      decoration: BoxDecoration(
        color: _ParcelSurface.surfaceSecondary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kLine),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          const Icon(Icons.lock_rounded, size: 18, color: _kGreyLight),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: _kGrey,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet where the driver types the RECEIVER's 4-digit delivery OTP.
/// Mirrors the pickup-OTP UX (PinCodeTextField + resend with cooldown).
Future<void> showParcelDeliveryOtpSheet(
  BuildContext context,
  RideStatsController c,
) async {
  final otpController = TextEditingController();
  final errorController = StreamController<ErrorAnimationType>.broadcast();

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: _ParcelSurface.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (sheetContext) {
      String? otpError;
      return StatefulBuilder(
        builder: (context, setSheetState) {
          Future<void> onVerify() async {
            final entered = otpController.text.trim();
            if (entered.length != 4) {
              setSheetState(() => otpError = 'OTP must be 4 digits');
              errorController.add(ErrorAnimationType.shake);
              return;
            }
            setSheetState(() => otpError = null);
            FocusScope.of(context).unfocus();

            final result = await c.verifyDeliveryOtp(entered);
            if (!context.mounted) return;
            if (result.success) {
              // Let the parent checklist rebuild before removing this route.
              // Do not insert a raw top-snack during the reverse animation.
              CustomSnackBar.dismiss();
              await WidgetsBinding.instance.endOfFrame;
              if (!sheetContext.mounted) return;
              Navigator.of(sheetContext).pop();
            } else {
              setSheetState(
                () =>
                    otpError =
                        result.message.trim().isEmpty
                            ? 'Invalid delivery OTP'
                            : result.message,
              );
              errorController.add(ErrorAnimationType.shake);
            }
          }

          return Padding(
            padding: EdgeInsets.only(
              left: 18,
              right: 18,
              top: 18,
              bottom: MediaQuery.of(context).viewInsets.bottom + 18,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: _kLine,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: const BoxDecoration(
                          color: _kBlueSoft,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.verified_user_rounded,
                          size: 26,
                          color: _kBlue,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Obx(() {
                        final name = c.receiverName.value.trim();
                        return Text(
                          name.isEmpty
                              ? 'Enter the delivery code'
                              : "Enter $name's delivery code",
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            color: _kInk,
                          ),
                        );
                      }),
                      const SizedBox(height: 4),
                      const Text(
                        'The receiver got this code by SMS when the package was picked up.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: _kGrey,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                PinCodeTextField(
                  appContext: context,
                  length: 4,
                  controller: otpController,
                  errorAnimationController: errorController,
                  autoDisposeControllers: false,
                  autoFocus: true,
                  autoDismissKeyboard: true,
                  keyboardType: TextInputType.number,
                  animationType: AnimationType.fade,
                  enableActiveFill: true,
                  cursorColor: ParcelDarkTheme.accentGreen,
                  mainAxisAlignment: MainAxisAlignment.center,
                  textStyle: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color:
                        otpError != null
                            ? ParcelDarkTheme.accentRed
                            : _ParcelSurface.textPrimary,
                  ),
                  pinTheme: PinTheme(
                    shape: PinCodeFieldShape.box,
                    borderRadius: BorderRadius.circular(12),
                    fieldHeight: 54.sp,
                    fieldWidth: 54.sp,
                    selectedColor:
                        otpError != null
                            ? ParcelDarkTheme.accentRed
                            : ParcelDarkTheme.accentGreen,
                    activeColor:
                        otpError != null
                            ? ParcelDarkTheme.accentRed
                            : _ParcelSurface.borderStrong,
                    activeFillColor: _ParcelSurface.surfaceSunken,
                    inactiveColor:
                        otpError != null
                            ? ParcelDarkTheme.accentRed
                            : _ParcelSurface.border,
                    selectedFillColor: _ParcelSurface.surfaceSunken,
                    inactiveFillColor: _ParcelSurface.surfaceSunken,
                    fieldOuterPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 10,
                    ),
                  ),
                  onChanged: (value) {
                    if (otpError != null) setSheetState(() => otpError = null);
                  },
                  beforeTextPaste: (_) => true,
                ),
                if (otpError != null)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        otpError!,
                        style: const TextStyle(
                          color: ParcelDarkTheme.accentRed,
                          fontSize: 13,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Icon(
                      Icons.shield_outlined,
                      size: 14,
                      color: _kGreyLight,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Verify only after confirming the package details.',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: _kGreyLight,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Obx(() {
                  final verifying = c.deliveryOtpVerifying.value;
                  return SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: verifying ? null : onVerify,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kBlue,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: _kBlue.withOpacity(0.5),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      child:
                          verifying
                              ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  color: Colors.white,
                                ),
                              )
                              : const Text(
                                'Verify Delivery OTP',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15.5,
                                ),
                              ),
                    ),
                  );
                }),
                const SizedBox(height: 6),
                Center(
                  child: Obx(() {
                    final cooldown = c.deliveryOtpResendCooldown.value;
                    final resending = c.deliveryOtpResending.value;
                    return TextButton(
                      onPressed:
                          (resending || cooldown > 0)
                              ? null
                              : () async {
                                final result = await c.resendDeliveryOtp();
                                // Booking may have been cancelled (forcing
                                // this sheet closed) while the request was
                                // in flight — guard the same way onVerify()
                                // does, so a stale route/context is never
                                // touched after the async gap.
                                if (!context.mounted) return;
                                if (result.success) {
                                  CustomSnackBar.showSuccess(result.message);
                                } else if (result.message.isNotEmpty) {
                                  CustomSnackBar.showError(result.message);
                                }
                              },
                      child: Text(
                        cooldown > 0
                            ? 'Resend code to receiver in ${cooldown}s'
                            : (resending
                                ? 'Resending…'
                                : "Receiver didn't get it? Resend code"),
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color:
                              (resending || cooldown > 0)
                                  ? _ParcelSurface.textMuted
                                  : _ParcelSurface.textPrimary,
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          );
        },
      );
    },
  );

  await errorController.close();
  otpController.dispose();
}

/// Confirmation sheet shown before the final "Complete Delivery" swipe fires
/// the (irreversible) completion call. The backend re-validates OTP+POD
/// regardless of this answer — this is purely a driver-facing double-check.
Future<bool> showCompleteDeliveryConfirmSheet(BuildContext context) async {
  final confirmed = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: _ParcelSurface.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (sheetContext) {
      return Padding(
        padding: EdgeInsets.only(
          left: 18,
          right: 18,
          top: 18,
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 18,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: _kLine,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: _kGreenSoft,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                size: 24,
                color: _kGreen,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Complete delivery?',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: _kInk,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Confirm that the package has been handed to the receiver.',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: _kGrey,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(sheetContext).pop(false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _kInk,
                        side: const BorderSide(color: _kLine, width: 1.2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      child: const Text(
                        'Go Back',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(sheetContext).pop(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kGreen,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      child: const Text(
                        'Complete Delivery',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    },
  );
  return confirmed ?? false;
}
