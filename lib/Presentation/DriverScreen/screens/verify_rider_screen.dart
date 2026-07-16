// lib/Presentation/DriverScreen/screens/verify_rider_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:pin_code_fields/pin_code_fields.dart';

import 'package:hopper/Core/Constants/Colors.dart';
import 'package:hopper/Core/Utility/Buttons.dart';
import 'package:hopper/Core/Utility/app_loader.dart';
import 'package:hopper/Core/Utility/images.dart';
import 'package:hopper/Core/Utility/snackbar.dart';
import 'package:hopper/Presentation/Authentication/widgets/bottomNavigation.dart';
import 'package:hopper/Presentation/DriverScreen/controller/driver_status_controller.dart';
import 'package:hopper/Presentation/DriverScreen/screens/ride_stats_screen.dart';
import 'package:hopper/Presentation/DriverScreen/widgets/parcel_dark_theme.dart';

class VerifyRiderScreen extends StatefulWidget {
  final String bookingId;
  final String custName;
  final String? pickupAddress;
  final String? dropAddress;

  /// 👉 For shared ride flow, set this to true and we will just `pop(true)`
  /// instead of navigating to RideStatsScreen.
  final bool isSharedRide;

  /// Package delivery trust (Phase 2): when true, this is the SENDER's
  /// pickup OTP for a parcel booking — verified against the dedicated
  /// hash-based `/parcel/verify-pickup-otp` endpoint instead of the shared
  /// ride-start OTP flow. UI copy adapts; the PIN entry itself is reused.
  final bool isParcel;

  /// Display-only, for the parcel package-summary card (Phase 4 UI redesign).
  final String? parcelType;
  final String? parcelWeight;

  const VerifyRiderScreen({
    super.key,
    required this.bookingId,
    required this.custName,
    this.pickupAddress,
    this.dropAddress,
    this.isSharedRide = false,
    this.isParcel = false,
    this.parcelType,
    this.parcelWeight,
  });

  @override
  State<VerifyRiderScreen> createState() => _VerifyRiderScreenState();
}

class _VerifyRiderScreenState extends State<VerifyRiderScreen> {
  final TextEditingController otp = TextEditingController(text: "");
  final formKey = GlobalKey<FormState>();
  final FocusNode otpFocusNode = FocusNode();

  /// ✅ Use GetX controller (same instance everywhere)
  final DriverStatusController driverStatusController =
      Get.find<DriverStatusController>();

  String verifyCode = '';
  String? otpError;
  bool otpVerified = false;
  bool _isNavigating = false;

  // "Resend OTP to rider": client cooldown + busy flag mirror the server's
  // 30s / 5-attempt policy so the button can't be spammed.
  bool _resending = false;
  int _resendCooldown = 0;
  Timer? _resendTimer;

  Color enableColor = AppColors.commonBlack.withOpacity(0.35);
  late final StreamController<ErrorAnimationType> errorController;

  @override
  void initState() {
    super.initState();
    errorController = StreamController<ErrorAnimationType>.broadcast();
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    errorController.close();
    if (!_isNavigating) {
      otp.dispose();
      otpFocusNode.dispose();
    }
    super.dispose();
  }

  /// Driver taps "Resend OTP to rider" when the customer didn't get the PIN.
  /// Server re-delivers over socket + push + SMS; cooldown/limits are enforced
  /// server-side, with an immediate client cooldown to prevent spam.
  Future<void> _onResendTap() async {
    if (_resending || _resendCooldown > 0) return;
    setState(() => _resending = true);
    _startResendCooldown(30);
    final result = await driverStatusController.resendRideOtp(
      bookingId: widget.bookingId,
    );
    if (!mounted) return;
    setState(() => _resending = false);
    if (result.success) {
      CustomSnackBar.showSuccess(result.message);
    } else {
      CustomSnackBar.showError(result.message);
    }
  }

  void _startResendCooldown(int seconds) {
    _resendTimer?.cancel();
    setState(() => _resendCooldown = seconds);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_resendCooldown <= 1) {
        setState(() => _resendCooldown = 0);
        t.cancel();
      } else {
        setState(() => _resendCooldown -= 1);
      }
    });
  }

  Future<void> _onVerifyTap() async {
    final enteredOtp = otp.text.trim();

    if (enteredOtp.isEmpty) {
      setState(() {
        otpError = "Please enter the OTP";
        enableColor = AppColors.commonBlack.withOpacity(0.35);
      });
      errorController.add(ErrorAnimationType.shake);
      return;
    } else if (enteredOtp.length != 4) {
      setState(() {
        otpError = "OTP must be 4 digits";
        enableColor = AppColors.commonBlack.withOpacity(0.35);
      });
      errorController.add(ErrorAnimationType.shake);
      return;
    }

    setState(() => otpError = null);

    // Hide keyboard
    FocusScope.of(context).unfocus();

    // Package delivery trust (Phase 2): parcels verify against the dedicated
    // hash-based pickup-OTP endpoint; rides keep the unmodified legacy path.
    final result =
        widget.isParcel
            ? await driverStatusController.verifyParcelPickupOtp(
              context,
              bookingId: widget.bookingId,
              otp: enteredOtp,
            )
            : await driverStatusController.otpInsert(
              context,
              bookingId: widget.bookingId,
              otp: enteredOtp,
            );

    if (!mounted) return;

    if (!result.success) {
      setState(() {
        otpError =
            result.message.trim().isEmpty
                ? (widget.isParcel
                    ? 'The Pickup OTP is incorrect or expired.'
                    : 'Invalid OTP. Please try again.')
                : result.message;
        enableColor = AppColors.commonBlack.withOpacity(0.35);
      });
      errorController.add(ErrorAnimationType.shake);
      return;
    }

    // ✅ OTP success
    otpVerified = true;

    // Small delay for UI smoothness
    await Future.delayed(const Duration(milliseconds: 120));

    _isNavigating = true;

    // CRASH FIX: a live top-snack OverlayEntry (e.g. the "OTP resent"
    // confirmation shown seconds earlier) must not survive the route-stack
    // replacement below — Get.offAll rebuilds the overlay and the stale entry
    // reparents its GlobalKey ("Duplicate GlobalKeys detected" → app crash).
    CustomSnackBar.dismiss();

    if (widget.isSharedRide) {
      // 👉 Shared ride flow: just tell previous screen "OTP verified"
      Get.back<bool>(result: true);
    } else {
      // 👉 Normal flow: go to RideStatsScreen (your existing behaviour)
      Get.offAll(
        () => RideStatsScreen(
          pickupAddress: widget.pickupAddress,
          dropAddress: widget.dropAddress,
          bookingId: widget.bookingId,
          isParcel: widget.isParcel,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Bike/Parcel pickup verification: fully separate black-theme layout.
    // Normal ride OTP verification (below) is completely untouched.
    if (widget.isParcel) {
      return _buildParcelVerificationBody(context);
    }
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          child: Obx(() {
            // Show the spinner ON the Verify button instead of blanking the whole
            // screen, so the driver keeps seeing the OTP boxes while verifying.
            final verifying = driverStatusController.isLoading.value;

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 20),
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: 32,
                        children: [
                          // Back button (tap can be wired later if needed)
                          Container(
                            decoration: BoxDecoration(
                              color: AppColors.commonBlack.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Image.asset(
                                AppImages.backButton,
                                height: 25,
                                width: 25,
                              ),
                            ),
                          ),

                          if (widget.isParcel)
                            Center(
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: AppColors.drkGreen.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.shield_rounded,
                                  size: 26,
                                  color: AppColors.drkGreen,
                                ),
                              ),
                            ),
                          Text(
                            textAlign: TextAlign.center,
                            widget.isParcel
                                ? 'Pickup Verification'
                                : 'Enter the ${widget.custName}’s Verification Code',
                            style: TextStyle(
                              color: AppColors.commonBlack,
                              fontSize: 25,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (widget.isParcel)
                            Text(
                              textAlign: TextAlign.center,
                              'Ask the sender for the 4-digit Pickup OTP when collecting the package.',
                              style: TextStyle(
                                color: AppColors.commonBlack.withOpacity(0.6),
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),

                          // OTP field + error text
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Form(
                                key: formKey,
                                child: PinCodeTextField(
                                  errorAnimationController: errorController,
                                  autoDisposeControllers: false,
                                  textStyle: TextStyle(
                                    fontSize: 20,
                                    color:
                                        otpError != null
                                            ? AppColors.red
                                            : Colors.black,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  autoFocus: !otpVerified,
                                  autoDismissKeyboard: true,
                                  focusNode: otpFocusNode,
                                  appContext: context,
                                  length: 4,
                                  blinkWhenObscuring: true,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  animationType: AnimationType.fade,
                                  controller: otp,
                                  keyboardType: TextInputType.number,
                                  enableActiveFill: true,
                                  cursorColor: Colors.black,
                                  animationDuration: const Duration(
                                    milliseconds: 300,
                                  ),
                                  boxShadows: const [
                                    BoxShadow(
                                      offset: Offset(0, 1),
                                      color: Colors.black12,
                                      blurRadius: 5,
                                    ),
                                  ],
                                  pinTheme: PinTheme(
                                    shape: PinCodeFieldShape.box,
                                    borderRadius: BorderRadius.circular(4.sp),
                                    fieldHeight: 48.sp,
                                    fieldWidth: 48.sp,
                                    selectedColor:
                                        otpError != null
                                            ? AppColors.red
                                            : AppColors.commonBlack,
                                    activeColor:
                                        otpError != null
                                            ? AppColors.red
                                            : AppColors.containerColor,
                                    activeFillColor:
                                        otpError != null
                                            ? Colors.transparent
                                            : AppColors.containerColor,
                                    inactiveColor:
                                        otpError != null
                                            ? AppColors.red
                                            : AppColors.containerColor,
                                    selectedFillColor:
                                        otpError != null
                                            ? Colors.transparent
                                            : AppColors.containerColor,
                                    inactiveFillColor:
                                        otpError != null
                                            ? Colors.transparent
                                            : AppColors.containerColor,
                                    fieldOuterPadding:
                                        const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 10,
                                        ),
                                  ),
                                  onChanged: (value) {
                                    setState(() {
                                      verifyCode = value;
                                      // Clear error state once user edits again.
                                      if (otpError != null) otpError = null;

                                      // Full black when OTP complete; muted-but-
                                      // VISIBLE black (not near-white) otherwise,
                                      // so the bottom button is always readable.
                                      enableColor =
                                          value.trim().length == 4
                                              ? AppColors.commonBlack
                                              : AppColors.commonBlack
                                                  .withOpacity(0.35);
                                    });
                                  },
                                  beforeTextPaste: (text) => true,
                                ),
                              ),
                              if (otpError != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    otpError!,
                                    style: TextStyle(
                                      color: AppColors.red,
                                      fontSize: 14,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  if (widget.isParcel)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          Icon(
                            Icons.shield_outlined,
                            size: 14,
                            color: AppColors.commonBlack.withOpacity(0.45),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Verify only after confirming the package details.',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.commonBlack.withOpacity(0.45),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Verify button
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 0),
                    child: Buttons.button(
                      borderRadius: widget.isParcel ? 15 : 7,
                      height: widget.isParcel ? 54 : null,
                      buttonColor: enableColor,
                      isLoading: verifying,
                      onTap:
                          verifying
                              ? null
                              : () async {
                                await _onVerifyTap();
                              },
                      text: Text('Verify ${widget.custName}'),
                    ),
                  ),

                  // "Didn't get the OTP?" — resend to the rider (socket+push+SMS).
                  // Not available for parcels: the pickup OTP is generated by a
                  // separate hashed mechanism at booking-confirm time with no
                  // dedicated resend endpoint (Phase 1 scope) — resending via the
                  // legacy ride-OTP route would issue a code that can never
                  // verify here, so the control is hidden rather than shown broken.
                  if (!widget.isParcel)
                    Padding(
                      padding: const EdgeInsets.only(top: 10, bottom: 4),
                      child: Center(
                        child: TextButton(
                          onPressed:
                              (_resending || _resendCooldown > 0)
                                  ? null
                                  : _onResendTap,
                          child: Text(
                            _resendCooldown > 0
                                ? 'Resend OTP to rider in ${_resendCooldown}s'
                                : (_resending
                                    ? 'Resending…'
                                    : "Rider didn't get it? Resend OTP"),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color:
                                  (_resending || _resendCooldown > 0)
                                      ? AppColors.containerColor1
                                      : AppColors.commonBlack,
                            ),
                          ),
                        ),
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.only(top: 10, bottom: 4),
                      child: Center(
                        child: Text(
                          'Ask the sender to check their booking confirmation for the Pickup OTP.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.commonBlack.withOpacity(0.5),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }

  // ---------------- PARCEL PICKUP VERIFICATION (BLACK THEME) ----------------
  // Reuses the exact same state (otp controller, errorController, otpError,
  // enableColor is unused here — a dedicated dark-aware color is used
  // instead) and the exact same `_onVerifyTap`/`_onResendTap` callbacks as
  // the ride path above. Only the visual layer is new.

  Widget _buildParcelVerificationBody(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: ParcelDarkTheme.background,
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          child: Obx(() {
            final verifying = driverStatusController.isLoading.value;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              child: Column(
                children: [
                  Row(
                    children: [
                      InkWell(
                        borderRadius: BorderRadius.circular(24),
                        onTap: () => Navigator.of(context).maybePop(),
                        child: Container(
                          padding: const EdgeInsets.all(9),
                          decoration: const BoxDecoration(
                            color: ParcelDarkTheme.surfaceSecondary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.arrow_back_rounded,
                            color: ParcelDarkTheme.textPrimary,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: const BoxDecoration(
                              color: ParcelDarkTheme.surfaceSecondary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.shield_rounded,
                              size: 30,
                              color: ParcelDarkTheme.accentGreen,
                            ),
                          ),
                          const SizedBox(height: 18),
                          const Text(
                            'Pickup Verification',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: ParcelDarkTheme.textPrimary,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Ask the sender for the 4-digit Pickup OTP when collecting the package.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: ParcelDarkTheme.textSecondary,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w500,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 20),
                          if (widget.bookingId.isNotEmpty ||
                              widget.custName.isNotEmpty)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: ParcelDarkTheme.card(),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _summaryRow(
                                    'Package ID',
                                    'PKG-${widget.bookingId}',
                                  ),
                                  if (widget.custName.trim().isNotEmpty)
                                    _summaryRow('Sender', widget.custName),
                                  if ((widget.pickupAddress ?? '')
                                      .trim()
                                      .isNotEmpty)
                                    _summaryRow(
                                      'Pickup Address',
                                      widget.pickupAddress!,
                                    ),
                                  if ((widget.parcelType ?? '')
                                      .trim()
                                      .isNotEmpty)
                                    _summaryRow('Type', widget.parcelType!),
                                  if ((widget.parcelWeight ?? '')
                                      .trim()
                                      .isNotEmpty)
                                    _summaryRow(
                                      'Weight',
                                      '${widget.parcelWeight} kg',
                                      isLast: true,
                                    ),
                                ],
                              ),
                            ),
                          const SizedBox(height: 22),
                          Form(
                            key: formKey,
                            child: PinCodeTextField(
                              errorAnimationController: errorController,
                              autoDisposeControllers: false,
                              textStyle: const TextStyle(
                                fontSize: 20,
                                color: ParcelDarkTheme.textPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                              autoFocus: !otpVerified,
                              autoDismissKeyboard: true,
                              focusNode: otpFocusNode,
                              appContext: context,
                              length: 4,
                              blinkWhenObscuring: true,
                              mainAxisAlignment: MainAxisAlignment.center,
                              animationType: AnimationType.fade,
                              controller: otp,
                              keyboardType: TextInputType.number,
                              enableActiveFill: true,
                              cursorColor: ParcelDarkTheme.accentGreen,
                              animationDuration: const Duration(
                                milliseconds: 300,
                              ),
                              pinTheme: PinTheme(
                                shape: PinCodeFieldShape.box,
                                borderRadius: BorderRadius.circular(12),
                                fieldHeight: 54,
                                fieldWidth: 54,
                                selectedColor:
                                    otpError != null
                                        ? ParcelDarkTheme.accentRed
                                        : ParcelDarkTheme.accentGreen,
                                activeColor:
                                    otpError != null
                                        ? ParcelDarkTheme.accentRed
                                        : ParcelDarkTheme.borderStrong,
                                activeFillColor: ParcelDarkTheme.surfaceSunken,
                                inactiveColor:
                                    otpError != null
                                        ? ParcelDarkTheme.accentRed
                                        : ParcelDarkTheme.border,
                                selectedFillColor:
                                    ParcelDarkTheme.surfaceSunken,
                                inactiveFillColor:
                                    ParcelDarkTheme.surfaceSunken,
                                fieldOuterPadding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 10,
                                ),
                              ),
                              onChanged: (value) {
                                if (otpError != null) {
                                  setState(() => otpError = null);
                                }
                              },
                              beforeTextPaste: (text) => true,
                            ),
                          ),
                          if (otpError != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: Text(
                                otpError!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: ParcelDarkTheme.accentRed,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          const SizedBox(height: 16),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.shield_outlined,
                                size: 14,
                                color: ParcelDarkTheme.textMuted,
                              ),
                              const SizedBox(width: 6),
                              const Expanded(
                                child: Text(
                                  'Verify only after checking the package details.',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: ParcelDarkTheme.textMuted,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed:
                          verifying
                              ? null
                              : () async {
                                await _onVerifyTap();
                              },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ParcelDarkTheme.accentGreen,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor:
                            ParcelDarkTheme.surfaceSecondary,
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
                                'Verify Pickup OTP',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15.5,
                                ),
                              ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.only(top: 6, bottom: 4),
                    child: Text(
                      'Ask the sender to check their booking confirmation for the Pickup OTP.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: ParcelDarkTheme.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value, {bool isLast = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
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
