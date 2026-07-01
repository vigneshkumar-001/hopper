import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hopper/Core/Constants/Colors.dart';
import 'package:hopper/Core/Constants/log.dart';
import 'package:hopper/Core/Utility/Buttons.dart';
import 'package:hopper/Core/Utility/app_loader.dart';
import 'package:hopper/Core/Utility/images.dart';
import 'package:hopper/Presentation/Authentication/widgets/textFields.dart';
import 'package:hopper/Presentation/DriverScreen/controller/driver_status_controller.dart';
import 'package:hopper/Presentation/DriverScreen/screens/driver_main_screen.dart';
import 'package:hopper/utils/sharedprefsHelper/local_data_store.dart';
import 'package:hopper/utils/widgets/hoppr_circular_loader.dart';

import '../../../utils/netWorkHandling/network_handling_screen.dart';

class CashCollectedScreen extends StatefulWidget {
  final dynamic Amount;
  final String? bookingId;
  final String? imageUrl;
  final String? name;
  final bool isSharedRide;

  const CashCollectedScreen({
    super.key,
    this.Amount,
    this.bookingId,
    this.imageUrl,
    this.name,
    this.isSharedRide = false,
  });

  @override
  State<CashCollectedScreen> createState() => _CashCollectedScreenState();
}

class _CashCollectedScreenState extends State<CashCollectedScreen> {
  late final DriverStatusController driverStatusController;
  Timer? _timer;
  bool _isSubmittingCash = false;

  @override
  void initState() {
    super.initState();
    driverStatusController =
        Get.isRegistered<DriverStatusController>()
            ? Get.find<DriverStatusController>()
            : Get.put(DriverStatusController());

    final bookingId = widget.bookingId?.toString() ?? '';
    if (bookingId.isNotEmpty) {
      driverStatusController.getAmountStatus(bookingId: bookingId);
      _timer = Timer.periodic(const Duration(seconds: 3), (_) {
        driverStatusController.getAmountStatus(bookingId: bookingId);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _finishSharedAndPop({required bool success}) async {
    _timer?.cancel();
    try {
      Get.closeAllSnackbars();
    } catch (_) {}

    if (!mounted) return;

    if (Navigator.of(context).canPop()) {
      Navigator.pop<bool>(context, success);
    }
  }

  Future<void> _submitCashCollected() async {
    if (_isSubmittingCash) return;

    final bookingId = widget.bookingId?.toString() ?? '';
    if (bookingId.isEmpty) {
      Get.snackbar(
        'Missing booking',
        'Booking id not found for cash collection.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    setState(() => _isSubmittingCash = true);

    var success = false;
    await driverStatusController.amountCollectedStatus(
      booking: bookingId,
      onSuccess: () {
        success = true;
      },
    );

    if (!mounted) return;
    setState(() => _isSubmittingCash = false);

    if (success) {
      _showRatingBottomSheet(context);
    }
  }

  ({String name, String imageUrl}) _customerInfo() {
    final widgetName = widget.name?.toString().trim() ?? '';
    final widgetImage = widget.imageUrl?.toString().trim() ?? '';

    if (widgetName.isNotEmpty || widgetImage.isNotEmpty) {
      return (
        name: widgetName.isNotEmpty ? widgetName : 'Customer',
        imageUrl: widgetImage,
      );
    }

    final joined = JoinedBookingData().getData();
    final joinedName =
        (joined?['custName'] ?? joined?['customerName'] ?? joined?['name'] ?? '')
            .toString()
            .trim();
    final joinedImage = (joined?['customerProfilePic'] ??
            joined?['profilePic'] ??
            joined?['imageUrl'] ??
            joined?['image'] ??
            '')
        .toString()
        .trim();

    return (
      name: joinedName.isNotEmpty ? joinedName : 'Customer',
      imageUrl: joinedImage,
    );
  }

  String _displayAmount() {
    final amount = widget.Amount?.toString().trim() ?? '';
    return amount.isEmpty ? '0' : amount;
  }

  Color _paymentStatusColor(String value) {
    return value.toUpperCase() == 'PAID'
        ? const Color(0xFF1E8E5A)
        : const Color(0xFFD93025);
  }

  /// ONLINE payment (Paystack/Flutterwave/PayPal/etc.) — anything that isn't
  /// cash/COD. The backend releases the driver on payment_success, so there is
  /// NO cash to collect; showing "Cash Collected" here would be wrong/confusing.
  bool _isOnlinePaymentMethod() {
    final t = driverStatusController.paymentType.value.toUpperCase().trim();
    if (t.isEmpty) return false; // unknown yet → treat as cash (safe default)
    return t != 'CASH' && t != 'COD';
  }

  /// Payment already settled (online webhook marked it, or cash was collected).
  bool _isPaymentSettled() {
    final s = driverStatusController.paymentStatus.value.toUpperCase().trim();
    return s == 'PAID' || s == 'SUCCESS' || s == 'COMPLETED';
  }

  Widget _buildPaymentInfoTile({
    required IconData icon,
    required String title,
    required Widget trailing,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFD0D5DD),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Align(alignment: Alignment.centerRight, child: trailing),
        ],
      ),
    );
  }

  Widget _buildAvatar(String imageUrl) {
    if (imageUrl.isEmpty) {
      return Container(
        height: 96,
        width: 96,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFFF2F4F7),
          border: Border.all(color: const Color(0xFFE4E7EC)),
        ),
        child: const Icon(
          Icons.person_rounded,
          size: 44,
          color: Color(0xFF667085),
        ),
      );
    }

    return CachedNetworkImage(
      imageUrl: imageUrl,
      imageBuilder:
          (context, imageProvider) => Container(
            height: 96,
            width: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFE4E7EC), width: 3),
              image: DecorationImage(image: imageProvider, fit: BoxFit.cover),
            ),
          ),
      placeholder:
          (context, url) => Container(
            height: 96,
            width: 96,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFF2F4F7),
            ),
            child: const Center(child: HopprCircularLoader(size: 24, radius: 12)),
          ),
      errorWidget:
          (context, url, error) => Container(
            height: 96,
            width: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFF2F4F7),
              border: Border.all(color: const Color(0xFFE4E7EC)),
            ),
            child: const Icon(
              Icons.person_rounded,
              size: 44,
              color: Color(0xFF667085),
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return NoInternetOverlay(
      child: WillPopScope(
        onWillPop: () async {
          return false;
        },
        child: Scaffold(
          backgroundColor: const Color(0xFFF8F9FB),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () async {
                      if (widget.isSharedRide) {
                        await _finishSharedAndPop(success: false);
                      } else if (Navigator.of(context).canPop()) {
                        Navigator.pop(context);
                      }
                    },
                    child: Container(
                      height: 42,
                      width: 42,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x12000000),
                            blurRadius: 16,
                            offset: Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Image.asset(
                          AppImages.backButton,
                          height: 18,
                          width: 18,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Expanded(
                      child: SingleChildScrollView(
                        child: Obx(() {
                          final paymentType =
                              driverStatusController.paymentType.value;
                          final paymentStatus =
                              driverStatusController.paymentStatus.value;
                          final customer = _customerInfo();
                          final imageUrl = customer.imageUrl;
                          final riderName = customer.name;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.fromLTRB(
                                20,
                                24,
                                20,
                                20,
                              ),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xFF101828),
                                    Color(0xFF1D2939),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(28),
                              ),
                              child: Column(
                                children: [
                                  _buildAvatar(imageUrl),
                                  const SizedBox(height: 16),
                                  CustomTextfield.textWithStylesSmall(
                                    'Collect cash from $riderName',
                                    colors: const Color(0xFFD0D5DD),
                                    fontSize: 14,
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    _displayAmount(),
                                    style: const TextStyle(
                                      fontSize: 34,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 18),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: 0.08,
                                      ),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: Colors.white.withValues(
                                          alpha: 0.12,
                                        ),
                                      ),
                                    ),
                                   child: Column(
                                      children: [
                                        _buildPaymentInfoTile(
                                          icon: Icons.payments_outlined,
                                          title: 'Payment type',
                                          trailing: Text(
                                            paymentType.isEmpty
                                                ? 'Cash'
                                                : paymentType,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 14),
                                        _buildPaymentInfoTile(
                                          icon: Icons.verified_outlined,
                                          title: 'Payment status',
                                          trailing: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 7,
                                            ),
                                            decoration: BoxDecoration(
                                              color: _paymentStatusColor(
                                                paymentStatus,
                                              ).withValues(alpha: 0.18),
                                              borderRadius:
                                                  BorderRadius.circular(999),
                                            ),
                                            child: Text(
                                              paymentStatus.isEmpty
                                                  ? 'Pending'
                                                  : paymentStatus,
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                color: _paymentStatusColor(
                                                  paymentStatus,
                                                ),
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 18),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF7ED),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: const Color(0xFFFED7AA),
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    height: 36,
                                    width: 36,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFEDD5),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Center(
                                      child: Image.asset(
                                        AppImages.exclamationCircle,
                                        width: 18,
                                        height: 18,
                                        color: const Color(0xFFEA580C),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: CustomTextfield.textWithStylesSmall(
                                      'If the rider does not have change, ask for a whole amount. Any extra collected amount will be credited to the rider account.',
                                      colors: const Color(0xFF9A3412),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      }),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SafeArea(
                    top: false,
                    child: Obx(() {
                      // ONLINE or already-settled → no cash to collect. Show a
                      // Finish action instead of "Cash Collected" (which would
                      // wrongly imply the driver must collect cash for a ride the
                      // customer already paid online).
                      if (_isOnlinePaymentMethod() || _isPaymentSettled()) {
                        return Buttons.button(
                          borderRadius: 18,
                          buttonColor: AppColors.commonBlack,
                          onTap: () => _showRatingBottomSheet(context),
                          text: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.check_circle_outline_rounded,
                                size: 18,
                                color: Colors.white,
                              ),
                              SizedBox(width: 8),
                              Text('Payment completed · Finish'),
                            ],
                          ),
                        );
                      }
                      // CASH and not yet paid → collect cash.
                      return Buttons.button(
                        borderRadius: 18,
                        buttonColor: AppColors.commonBlack,
                        onTap: _isSubmittingCash ? null : _submitCashCollected,
                        text:
                            _isSubmittingCash
                                ? const HopprCircularLoader(
                                  size: 20,
                                  radius: 10,
                                  color: Colors.white,
                                )
                                : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.check_circle_outline_rounded,
                                      size: 18,
                                      color: Colors.white,
                                    ),
                                    SizedBox(width: 8),
                                    Text('Cash Collected'),
                                  ],
                                ),
                      );
                    }),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showRatingBottomSheet(BuildContext pageContext) {
    var selectedRating = 0;
    var isSubmittingRating = false;

    showModalBottomSheet(
      context: pageContext,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final customer = _customerInfo();
        final profilePic = customer.imageUrl;
        final riderName = customer.name;

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
                      _buildAvatar(profilePic),
                      const SizedBox(height: 18),
                      const Text(
                        'Trip Completed',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF101828),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Rate your experience with $riderName',
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
                              onTap: () async {
                                Navigator.pop(sheetContext);
                                if (widget.isSharedRide) {
                                  await _finishSharedAndPop(success: true);
                                } else {
                                  Navigator.of(pageContext).pushAndRemoveUntil(
                                    MaterialPageRoute(
                                      builder: (_) => DriverMainScreen(),
                                    ),
                                    (route) => false,
                                  );
                                }
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
                                        _timer?.cancel();
                                        final sheetNavigator = Navigator.of(
                                          sheetContext,
                                        );
                                        setModalState(
                                          () => isSubmittingRating = true,
                                        );

                                        await driverStatusController
                                            .driverRatingToCustomer(
                                              context: pageContext,
                                              rating: selectedRating,
                                              bookingId:
                                                  widget.bookingId.toString(),
                                              goToMainOnSuccess:
                                                  !widget.isSharedRide,
                                            );

                                        CommonLogger.log.i('Selected Rating: ');

                                        if (widget.isSharedRide && mounted) {
                                          sheetNavigator.pop();
                                          await _finishSharedAndPop(
                                            success: true,
                                          );
                                          return;
                                        }

                                        if (sheetNavigator.canPop()) {
                                          setModalState(
                                            () => isSubmittingRating = false,
                                          );
                                        }
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
}
