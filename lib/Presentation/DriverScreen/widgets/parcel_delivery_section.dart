// Parcel delivery trust — driver-side PACKAGE DELIVERY panel.
//
// Step-based card stack shown on the drop screen for parcel bookings only:
//   1. header (title / PKG id / status badge / progress)
//   2. receiver card (name / call / instruction / address type)
//   3. address card (pickup / delivery / distance-ETA)
//   4. package details card (type / weight / description / fragile / payment)
//   5. trust checklist (Pickup OTP → Receiver OTP → POD photo → Complete)
//   6. delivery OTP action card  -> POST /users/parcel/verify-delivery-otp
//   7. POD photo action card     -> upload + POST /users/parcel/pod-photo
// The Complete slider itself lives in ride_stats_screen and stays LOCKED until
// steps 2+3 are done. Backend remains the source of truth for completion.
//
// The delivery OTP is NEVER displayed — the driver types the code the
// receiver got by SMS.

import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pin_code_fields/pin_code_fields.dart';

import 'package:hopper/Core/Constants/Colors.dart';
import 'package:hopper/Core/Utility/snackbar.dart';
import 'package:hopper/Presentation/DriverScreen/controller/ride_starts_controller.dart';
import 'package:hopper/utils/phone/call_launcher.dart';

// Design tokens — match the existing screen (Navigate button blue, drkGreen).
const _kBlue = Color(0xFF1A73E8);
const _kBlueSoft = Color(0xFFEAF1FE);
const _kGreen = Color(0xFF00A85E);
const _kGreenSoft = Color(0xFFEFFAF3);
const _kGreenLine = Color(0xFFBBE5C8);
const _kInk = Color(0xFF111827);
const _kGrey = Color(0xFF6B7280);
const _kGreyLight = Color(0xFF9CA3AF);
const _kLine = Color(0xFFE5E7EB);
const _kAmber = Color(0xFF92700C);

class ParcelDeliverySection extends StatelessWidget {
  final RideStatsController controller;

  /// true on the reached-drop (completed) sheet — unlocks the OTP/POD action
  /// cards. During transit the panel shows info + checklist preview only.
  final bool atDropLocation;

  const ParcelDeliverySection({
    super.key,
    required this.controller,
    this.atDropLocation = true,
  });

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return Obx(() {
      if (!c.isParcel.value) return const SizedBox.shrink();

      final otpDone = c.deliveryOtpVerified.value;
      final podDone = c.podPhotoUrl.value.isNotEmpty;

      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _headerCard(otpDone: otpDone, podDone: podDone),
            const SizedBox(height: 10),
            _receiverCard(context, c),
            const SizedBox(height: 10),
            _addressCard(c),
            if (_hasPackageDetails(c)) ...[
              const SizedBox(height: 10),
              _packageCard(c),
            ],
            const SizedBox(height: 10),
            _checklistCard(otpDone: otpDone, podDone: podDone),
            if (atDropLocation) ...[
              const SizedBox(height: 10),
              _otpActionCard(context, c, done: otpDone),
              const SizedBox(height: 10),
              _podActionCard(context, c, done: podDone),
            ],
          ],
        ),
      );
    });
  }

  // ── 1. Header ──────────────────────────────────────────────────────────────

  Widget _headerCard({required bool otpDone, required bool podDone}) {
    // Pickup is inherently verified on this screen (backend only allows the
    // drop leg after the sender's pickup OTP). Complete = the 4th step.
    final doneSteps = 1 + (otpDone ? 1 : 0) + (podDone ? 1 : 0);
    final statusLabel = otpDone ? 'OUT FOR DELIVERY' : 'IN TRANSIT';

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: const BoxDecoration(
                  color: _kBlueSoft,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.inventory_2_rounded,
                  size: 19,
                  color: _kBlue,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Package Delivery',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: _kInk,
                      ),
                    ),
                    const SizedBox(height: 2),
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
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: otpDone ? _kGreenSoft : _kBlueSoft,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                    color: otpDone ? _kGreen : _kBlue,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: doneSteps / 4,
              minHeight: 6,
              backgroundColor: _kLine,
              valueColor: AlwaysStoppedAnimation<Color>(
                doneSteps >= 3 ? _kGreen : _kBlue,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$doneSteps of 4 steps completed',
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
                  color: const Color(0xFFF3F4F6),
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
                _chip(addressType, _kBlueSoft, _kBlue),
                const SizedBox(width: 8),
              ],
              if (phone.isNotEmpty)
                InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: () async {
                    await CallLauncher.openDialer(
                      phone: phone,
                      context: context,
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(
                      color: _kGreenSoft,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.call_rounded,
                      size: 19,
                      color: _kGreen,
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
                color: const Color(0xFFFFF8E6),
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
          _cardTitle('Route'),
          const SizedBox(height: 10),
          if (pickup.isNotEmpty)
            _addressRow(
              icon: Icons.trip_origin_rounded,
              iconColor: _kInk,
              label: 'Pickup',
              text: pickup,
            ),
          if (pickup.isNotEmpty && drop.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 7),
              child: Container(width: 2, height: 14, color: _kLine),
            ),
          if (drop.isNotEmpty)
            _addressRow(
              icon: Icons.location_on_rounded,
              iconColor: _kGreen,
              label: 'Delivery',
              text: drop,
            ),
          if (metaParts.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.route_outlined, size: 15, color: _kGrey),
                const SizedBox(width: 6),
                Text(
                  metaParts.join(' • '),
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: _kInk,
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

  // ── 4. Package details ─────────────────────────────────────────────────────

  bool _hasPackageDetails(RideStatsController c) =>
      c.parcelType.value.trim().isNotEmpty ||
      c.parcelWeight.value.trim().isNotEmpty ||
      c.parcelDescription.value.trim().isNotEmpty ||
      c.parcelPaymentMode.value.trim().isNotEmpty;

  bool _isFragile(RideStatsController c) {
    final haystack =
        '${c.parcelType.value} ${c.parcelDescription.value}'.toLowerCase();
    return haystack.contains('fragile') || haystack.contains('glass');
  }

  Widget _packageCard(RideStatsController c) {
    final type = c.parcelType.value.trim();
    final weight = c.parcelWeight.value.trim();
    final description = c.parcelDescription.value.trim();
    final payment = c.parcelPaymentMode.value.trim();

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle('Package details'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (type.isNotEmpty) _chip(type, _kBlueSoft, _kBlue),
              if (weight.isNotEmpty)
                _chip('$weight kg', const Color(0xFFF3F4F6), _kInk),
              if (_isFragile(c))
                _chip('FRAGILE', const Color(0xFFFEE4E2), AppColors.red),
              if (payment.isNotEmpty)
                _chip(
                  payment.toUpperCase() == 'COD'
                      ? 'CASH ON DELIVERY'
                      : payment.toUpperCase(),
                  _kGreenSoft,
                  _kGreen,
                ),
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

  // ── 5. Trust checklist ─────────────────────────────────────────────────────

  Widget _checklistCard({required bool otpDone, required bool podDone}) {
    final canComplete = otpDone && podDone;
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle('Delivery steps'),
          const SizedBox(height: 8),
          _checkRow(1, 'Pickup OTP verified', done: true, active: false),
          _checkRow(2, 'Verify receiver OTP', done: otpDone, active: !otpDone),
          _checkRow(
            3,
            'Upload proof of delivery photo',
            done: podDone,
            active: otpDone && !podDone,
          ),
          _checkRow(
            4,
            'Complete delivery',
            done: false,
            active: canComplete,
            isLast: true,
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
  }) {
    final color = done ? _kGreen : (active ? _kBlue : _kGreyLight);
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: done
                  ? _kGreen
                  : (active ? _kBlueSoft : const Color(0xFFF3F4F6)),
              shape: BoxShape.circle,
              border: active && !done ? Border.all(color: _kBlue) : null,
            ),
            alignment: Alignment.center,
            child: done
                ? const Icon(Icons.check_rounded, size: 15, color: Colors.white)
                : Text(
                    '$step',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: active ? _kBlue : _kGreyLight,
                    ),
                  ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: done || active ? _kInk : _kGreyLight,
              ),
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
            Icon(Icons.arrow_forward_ios_rounded, size: 12, color: color),
        ],
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle('Delivery OTP'),
          const SizedBox(height: 4),
          const Text(
            'Ask the receiver for the OTP sent by SMS.',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: _kGrey,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 46,
                  child: ElevatedButton.icon(
                    onPressed: () => showParcelDeliveryOtpSheet(context, c),
                    icon: const Icon(Icons.password_rounded, size: 18),
                    label: const Text(
                      'Enter OTP',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kBlue,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 46,
                child: OutlinedButton(
                  onPressed: (resending || cooldown > 0)
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
                      borderRadius: BorderRadius.circular(12),
                    ),
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
      final result =
          await c.captureAndUploadPodPhoto(source: ImageSource.camera);
      if (result.message.isEmpty) return; // user cancelled the camera
      if (result.success) {
        CustomSnackBar.showSuccess(result.message);
      } else {
        CustomSnackBar.showError(result.message);
      }
    }

    return _card(
      borderColor: done ? _kGreenLine : _kLine,
      background: done ? _kGreenSoft : Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _cardTitle('Proof of delivery photo')),
              if (done)
                const Text(
                  'Uploaded',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: _kGreen,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            done
                ? 'Photo saved as proof of handover.'
                : 'Take a photo of the package at handover.',
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: _kGrey,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (done) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: CachedNetworkImage(
                    imageUrl: c.podPhotoUrl.value,
                    width: 62,
                    height: 62,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => const Icon(
                      Icons.broken_image_rounded,
                      color: _kGrey,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: SizedBox(
                  height: 46,
                  child: uploading
                      ? const Center(
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.2),
                          ),
                        )
                      : (done
                          ? OutlinedButton.icon(
                              onPressed: takePhoto,
                              icon: const Icon(Icons.refresh_rounded, size: 18),
                              label: const Text(
                                'Retake',
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: _kGreen,
                                side: const BorderSide(
                                  color: _kGreen,
                                  width: 1.2,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            )
                          : ElevatedButton.icon(
                              onPressed: takePhoto,
                              icon: const Icon(
                                Icons.photo_camera_rounded,
                                size: 18,
                              ),
                              label: const Text(
                                'Take Photo',
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _kBlue,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            )),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── shared building blocks ─────────────────────────────────────────────────

  Widget _card({
    required Widget child,
    Color background = Colors.white,
    Color borderColor = _kLine,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 10,
            offset: Offset(0, 3),
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: _kGreenSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kGreenLine),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: _kGreen),
          const SizedBox(width: 10),
          Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: _kInk,
            ),
          ),
        ],
      ),
    );
  }
}

/// Locked state shown INSTEAD of the Complete slider until the trust steps
/// are done. Screen swaps it for the real slider reactively.
class ParcelCompleteLockedBar extends StatelessWidget {
  const ParcelCompleteLockedBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kLine),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: const Row(
        children: [
          Icon(Icons.lock_rounded, size: 18, color: _kGreyLight),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Verify receiver OTP and upload delivery photo to complete delivery.',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
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
    backgroundColor: Colors.white,
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
              // Pop FIRST, then show the snack on the next frame — inserting a
              // top-snack OverlayEntry in the same frame a route is removed
              // can reparent overlay GlobalKeys ("Duplicate GlobalKeys" crash).
              Navigator.of(sheetContext).pop();
              WidgetsBinding.instance.addPostFrameCallback((_) {
                CustomSnackBar.showSuccess(result.message);
              });
            } else {
              setSheetState(
                () => otpError =
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
                const SizedBox(height: 16),
                Obx(() {
                  final name = c.receiverName.value.trim();
                  return Text(
                    name.isEmpty
                        ? 'Enter the delivery code'
                        : "Enter $name's delivery code",
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
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: _kGrey,
                  ),
                ),
                const SizedBox(height: 14),
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
                  cursorColor: Colors.black,
                  mainAxisAlignment: MainAxisAlignment.center,
                  textStyle: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: otpError != null ? AppColors.red : Colors.black,
                  ),
                  pinTheme: PinTheme(
                    shape: PinCodeFieldShape.box,
                    borderRadius: BorderRadius.circular(4.sp),
                    fieldHeight: 48.sp,
                    fieldWidth: 48.sp,
                    selectedColor: otpError != null
                        ? AppColors.red
                        : AppColors.commonBlack,
                    activeColor: otpError != null
                        ? AppColors.red
                        : AppColors.containerColor,
                    activeFillColor: otpError != null
                        ? Colors.transparent
                        : AppColors.containerColor,
                    inactiveColor: otpError != null
                        ? AppColors.red
                        : AppColors.containerColor,
                    selectedFillColor: otpError != null
                        ? Colors.transparent
                        : AppColors.containerColor,
                    inactiveFillColor: otpError != null
                        ? Colors.transparent
                        : AppColors.containerColor,
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
                        style: TextStyle(color: AppColors.red, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                const SizedBox(height: 14),
                Obx(() {
                  final verifying = c.deliveryOtpVerifying.value;
                  return SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: verifying ? null : onVerify,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kBlue,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: verifying
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
                              style: TextStyle(fontWeight: FontWeight.w800),
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
                      onPressed: (resending || cooldown > 0)
                          ? null
                          : () async {
                              final result = await c.resendDeliveryOtp();
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
                          color: (resending || cooldown > 0)
                              ? AppColors.containerColor1
                              : AppColors.commonBlack,
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
