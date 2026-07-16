// Parcel delivery trust — driver-side DELIVERED success screen (parcel only).
//
// Shown instead of the generic CashCollectedScreen once the backend confirms
// DELIVERED for a parcel booking (completion API/logic unchanged — this is
// purely the post-success visual). Never shown for car/solo/shared rides.
//
// Rating: parcel-specific addition (mirrors CashCollectedScreen's existing
// "driver rates customer" bottom sheet, reusing the same
// DriverStatusController.driverRatingToCustomer() API and the same
// pop-sheet-before-hard-navigate sequencing that screen's own comments
// document as the fix for a "Duplicate GlobalKeys detected" crash — that
// call does its own Navigator.pushAndRemoveUntil on success, so the sheet
// must already be gone before it runs, not popped afterward).

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:hopper/Core/Constants/Colors.dart';
import 'package:hopper/Core/Utility/Buttons.dart';
import 'package:hopper/Core/Utility/snackbar.dart';
import 'package:hopper/Presentation/DriverScreen/controller/driver_status_controller.dart';
import 'package:hopper/Presentation/DriverScreen/screens/driver_main_screen.dart';
import 'package:hopper/Presentation/DriverScreen/widgets/parcel_dark_theme.dart';
import 'package:hopper/utils/widgets/hoppr_circular_loader.dart';

class ParcelDeliverySuccessScreen extends StatefulWidget {
  final String bookingId;
  final String receiverName;
  final String dropAddress;
  final String podPhotoUrl;
  final DateTime deliveredAt;
  final String? customerName;
  final String? customerProfilePic;

  const ParcelDeliverySuccessScreen({
    super.key,
    required this.bookingId,
    required this.receiverName,
    required this.dropAddress,
    required this.podPhotoUrl,
    required this.deliveredAt,
    this.customerName,
    this.customerProfilePic,
  });

  @override
  State<ParcelDeliverySuccessScreen> createState() =>
      _ParcelDeliverySuccessScreenState();
}

class _ParcelDeliverySuccessScreenState
    extends State<ParcelDeliverySuccessScreen> {
  late final DriverStatusController driverStatusController;
  bool _ratingSheetShown = false;

  @override
  void initState() {
    super.initState();
    driverStatusController =
        Get.isRegistered<DriverStatusController>()
            ? Get.find<DriverStatusController>()
            : Get.put(DriverStatusController());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _showRatingBottomSheet(context);
    });
  }

  String _formatTime(DateTime dt) {
    final local = dt.toLocal();
    final h = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final m = local.minute.toString().padLeft(2, '0');
    final ampm = local.hour >= 12 ? 'PM' : 'AM';
    return '${local.day}/${local.month}/${local.year}, $h:$m $ampm';
  }

  void _returnHome(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => DriverMainScreen()),
      (route) => false,
    );
  }

  void _showRatingBottomSheet(BuildContext pageContext) {
    if (_ratingSheetShown) return;
    _ratingSheetShown = true;
    var selectedRating = 0;
    var isSubmittingRating = false;
    final customerLabel =
        (widget.customerName?.trim().isNotEmpty == true)
            ? widget.customerName!.trim()
            : 'the customer';

    showModalBottomSheet(
      context: pageContext,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: SafeArea(
                top: false,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 48,
                        height: 5,
                        decoration: BoxDecoration(
                          color: const Color(0xFFD0D5DD),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      const SizedBox(height: 22),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: CachedNetworkImage(
                          imageUrl: widget.customerProfilePic ?? '',
                          height: 72,
                          width: 72,
                          fit: BoxFit.cover,
                          placeholder:
                              (context, url) => Container(
                                height: 72,
                                width: 72,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFF2F4F7),
                                  shape: BoxShape.circle,
                                ),
                                child: const Center(
                                  child: SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                ),
                              ),
                          errorWidget:
                              (context, url, error) => Container(
                                height: 72,
                                width: 72,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFF2F4F7),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.person,
                                  color: Color(0xFF98A2B3),
                                  size: 30,
                                ),
                              ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Delivery Completed',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF101828),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Rate your experience with $customerLabel',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.5,
                          color: Color(0xFF667085),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: List.generate(5, (index) {
                          final active = index < selectedRating;
                          return GestureDetector(
                            onTap:
                                () => setModalState(
                                  () => selectedRating = index + 1,
                                ),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              height: 54,
                              width: 54,
                              decoration: BoxDecoration(
                                color:
                                    active
                                        ? const Color(0xFFFFF4E5)
                                        : const Color(0xFFF5F6F8),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color:
                                      active
                                          ? const Color(0xFFF59E0B)
                                          : const Color(0xFFE4E7EC),
                                ),
                              ),
                              child: Icon(
                                active
                                    ? Icons.star_rounded
                                    : Icons.star_border_rounded,
                                color:
                                    active
                                        ? const Color(0xFFF59E0B)
                                        : const Color(0xFF98A2B3),
                                size: 30,
                              ),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: Buttons.button(
                              borderRadius: 16,
                              textColor: AppColors.commonBlack,
                              borderColor: const Color(0xFFD0D5DD),
                              buttonColor: Colors.white,
                              onTap: () {
                                Navigator.pop(sheetContext);
                                WidgetsBinding.instance.addPostFrameCallback((_) {
                                  if (!mounted) return;
                                  CustomSnackBar.dismiss();
                                  _returnHome(pageContext);
                                });
                              },
                              text: const Text('Skip'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Buttons.button(
                              borderRadius: 16,
                              buttonColor: AppColors.commonBlack,
                              onTap:
                                  isSubmittingRating
                                      ? null
                                      : () async {
                                        setModalState(
                                          () => isSubmittingRating = true,
                                        );
                                        // driverRatingToCustomer() does its
                                        // own hard pushAndRemoveUntil on
                                        // success — pop this sheet FIRST so
                                        // that stack wipe never has to tear a
                                        // still-live route out from under it
                                        // (see CashCollectedScreen's
                                        // equivalent comment for the crash
                                        // this avoids).
                                        final sheetNavigator = Navigator.of(
                                          sheetContext,
                                        );
                                        if (sheetNavigator.canPop()) {
                                          sheetNavigator.pop();
                                        }
                                        await driverStatusController
                                            .driverRatingToCustomer(
                                              context: pageContext,
                                              rating: selectedRating,
                                              bookingId: widget.bookingId,
                                              goToMainOnSuccess: true,
                                            );
                                      },
                              text:
                                  isSubmittingRating
                                      ? const HopprCircularLoader(
                                        size: 20,
                                        radius: 10,
                                        color: Colors.white,
                                      )
                                      : const Text('Submit Rating'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _returnHome(context);
      },
      child: Scaffold(
        backgroundColor: ParcelDarkTheme.background,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.6, end: 1),
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOutBack,
                          builder:
                              (context, scale, child) =>
                                  Transform.scale(scale: scale, child: child),
                          child: Container(
                            padding: const EdgeInsets.all(22),
                            decoration: const BoxDecoration(
                              color: Color(0xFFEAF9EE),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check_circle_rounded,
                              size: 56,
                              color: ParcelDarkTheme.accentGreen,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Delivery Completed',
                          style: TextStyle(
                            color: ParcelDarkTheme.textPrimary,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'The package has been delivered successfully.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: ParcelDarkTheme.textSecondary,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(18),
                          decoration: ParcelDarkTheme.card(),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _row('Package ID', 'PKG-${widget.bookingId}'),
                              _row('Delivered', _formatTime(widget.deliveredAt)),
                              if (widget.receiverName.trim().isNotEmpty)
                                _row('Receiver', widget.receiverName),
                              if (widget.dropAddress.trim().isNotEmpty)
                                _row(
                                  'Delivery Address',
                                  widget.dropAddress,
                                  isLast: widget.podPhotoUrl.isEmpty,
                                ),
                              if (widget.podPhotoUrl.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                const Text(
                                  'Proof of delivery',
                                  style: TextStyle(
                                    color: ParcelDarkTheme.textMuted,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(14),
                                  child: CachedNetworkImage(
                                    imageUrl: widget.podPhotoUrl,
                                    height: 180,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                    errorWidget:
                                        (_, __, ___) => Container(
                                          height: 100,
                                          color:
                                              ParcelDarkTheme.surfaceSecondary,
                                          alignment: Alignment.center,
                                          child: const Text(
                                            'Photo unavailable',
                                            style: TextStyle(
                                              color: ParcelDarkTheme.textMuted,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: () => _returnHome(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ParcelDarkTheme.accentGreen,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    child: const Text(
                      'Return to Home',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15.5,
                      ),
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

  Widget _row(String label, String value, {bool isLast = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                color: ParcelDarkTheme.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: ParcelDarkTheme.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
