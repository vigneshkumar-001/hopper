import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../Presentation/Authentication/widgets/textFields.dart';
import '../Constants/Colors.dart';
import 'app_loader.dart';
import 'images.dart';

class Buttons {
  static final Buttons _singleton = Buttons._internal();

  Buttons._internal();

  static Buttons get instance => _singleton;
  static Widget button1({
    required GestureTapCallback? onTap,
    required Widget text,
    double? size = double.infinity,
    double? imgHeight = 24,
    double? imgWeight = 24,
    double? borderRadius = 4,

    Color? buttonColor,
    Color? foreGroundColor,
    Color? borderColor,
    Color? textColor = Colors.white,
    bool? isLoading,
    bool hasBorder = false,
    String? imagePath,
  }) {
    return SizedBox(
      width: size,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          foregroundColor: foreGroundColor,

          shape:
              hasBorder
                  ? RoundedRectangleBorder(
                    side: BorderSide(color: Color(0xff3F5FF2)),
                    borderRadius: BorderRadius.circular(borderRadius!),
                  )
                  : RoundedRectangleBorder(
                    side: BorderSide(color: borderColor ?? Colors.transparent),

                    borderRadius: BorderRadius.circular(borderRadius!),
                  ),
          elevation: 0,
          fixedSize: Size(150.w, 40.h),
          backgroundColor: buttonColor,
        ),
        child:
            isLoading == true
                ? SizedBox(
                  width: 20,
                  height: 20,
                  child: AppLoader.inlineCircularLoader(
                    size: 20,
                    strokeWidth: 2,
                    color: textColor ?? Colors.white,
                  ),
                )
                : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (imagePath != null) ...[
                      Image.asset(
                        imagePath,
                        height: imgHeight!.sp,
                        width: imgWeight!.sp,
                      ),
                      SizedBox(width: 10.w),
                    ],
                    DefaultTextStyle(
                      style: TextStyle(
                        fontFamily: "Roboto-normal",
                        fontSize: 16.sp,
                        color: textColor,
                        fontWeight: FontWeight.bold,
                      ),
                      child: text,
                    ),
                  ],
                ),
      ),
    );
  }

  static Widget button({
    required GestureTapCallback? onTap,
    required Widget text,
    double? size = double.infinity,
    double? imgHeight = 24,
    double? imgWeight = 24,
    double? borderRadius = 4,

    Color? buttonColor,
    Color? foreGroundColor,
    Color? borderColor,
    Color? textColor = Colors.white,
    bool? isLoading,
    bool hasBorder = false,
    String? imagePath,
  }) {
    return SizedBox(
      width: size,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          foregroundColor: foreGroundColor,

          shape:
              hasBorder
                  ? RoundedRectangleBorder(
                    side: BorderSide(color: Color(0xff3F5FF2)),
                    borderRadius: BorderRadius.circular(borderRadius!),
                  )
                  : RoundedRectangleBorder(
                    side: BorderSide(color: borderColor ?? Colors.transparent),

                    borderRadius: BorderRadius.circular(borderRadius!),
                  ),
          elevation: 0,
          fixedSize: Size(150.w, 40.h),
          backgroundColor: buttonColor,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (imagePath != null) ...[
              Image.asset(
                imagePath,
                height: imgHeight!.sp,
                width: imgWeight!.sp,
              ),
              SizedBox(width: 10.w),
            ],
            DefaultTextStyle(
              style: TextStyle(
                fontFamily: "Roboto-normal",
                fontSize: 16.sp,
                color: textColor,
                fontWeight: FontWeight.bold,
              ),
              child: text,
            ),
          ],
        ),
      ),
    );
  }

  // static button({
  //   required GestureTapCallback? onTap,
  //   required String text,
  //   required Widget texts,
  //
  //   double? size = double.infinity,
  //   Color? buttonColor,
  //   Color? textColor = Colors.white,
  //
  //   bool? isLoading,
  //   bool hasBorder = false,
  //   String? imagePath,
  // }) {
  //   return SizedBox(
  //     width: size,
  //
  //     child: ElevatedButton(
  //       onPressed: onTap,
  //       style: ElevatedButton.styleFrom(
  //         shape:
  //             hasBorder
  //                 ? RoundedRectangleBorder(
  //                   side: BorderSide(color: Color(0xff3F5FF2)),
  //                   borderRadius: BorderRadius.circular(4),
  //                 )
  //                 : RoundedRectangleBorder(
  //                   borderRadius: BorderRadius.circular(4),
  //                 ),
  //         elevation: 0,
  //         fixedSize: Size(150.w, 40.h),
  //         backgroundColor: buttonColor,
  //       ),
  //       child: Row(
  //         mainAxisAlignment: MainAxisAlignment.center,
  //         mainAxisSize: MainAxisSize.min,
  //         children: [
  //           if (imagePath != null) ...[
  //             Image.asset(imagePath, height: 24.sp, width: 24.sp),
  //             SizedBox(width: 10.w),
  //           ],
  //           Text(
  //             texts,
  //             style: TextStyle(
  //               fontFamily: "Roboto-normal",
  //               fontSize: 16.sp,
  //               color: textColor,
  //             ),
  //           ),
  //         ],
  //       ),
  //     ),
  //   );
  // }

  static backButton({required BuildContext context}) {
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Image.asset(AppImages.backButton, height: 18),
    );
  }

  static void showDialogBox({
    required BuildContext context,
    required Future<void> Function() onConfirmStop, // 👈 new param
  }) {
    showDialog(
      context: context,
      barrierDismissible: !false, // dialog not dismissible while loading
      builder: (BuildContext dialogContext) {
        bool isSubmitting = false;

        return StatefulBuilder(
          builder: (context, setState) {
            return Stack(
              children: [
                // MAIN ALERT DIALOG
                AbsorbPointer(
                  absorbing: isSubmitting, // 🔒 block taps when loading
                  child: AlertDialog(
                    backgroundColor: AppColors.commonWhite,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    title: Column(
                      children: [
                        Image.asset(AppImages.close, height: 40, width: 40),
                        const SizedBox(height: 10),
                        CustomTextfield.textWithStyles600(
                          'Stop new Ride Request?',
                        ),
                      ],
                    ),
                    content: CustomTextfield.textWithStylesSmall(
                      fontWeight: FontWeight.w500,
                      textAlign: TextAlign.center,
                      'You won’t receive any new request and you’ll be offline',
                    ),
                    actions: [
                      Row(
                        children: [
                          // ❌ Don't stop
                          Expanded(
                            child: Buttons.button(
                              buttonColor: AppColors.commonWhite,
                              textColor: AppColors.commonBlack,
                              borderRadius: 8,
                              borderColor: AppColors.buttonBorder,
                              onTap: () {
                                if (isSubmitting) return;
                                Navigator.pop(dialogContext);
                              },
                              text: CustomTextfield.textWithStyles600(
                                "Don't Stop",
                              ),
                            ),
                          ),
                          const SizedBox(width: 5),
                          // ✅ Yes, stop
                          Expanded(
                            child: Buttons.button(
                              buttonColor: AppColors.errorRed,
                              borderRadius: 8,
                              onTap: () async {
                                if (isSubmitting) return;

                                setState(() => isSubmitting = true);

                                try {
                                  await onConfirmStop(); // 🔥 your API / logic

                                  if (dialogContext.mounted) {
                                    Navigator.pop(dialogContext);
                                  }
                                } finally {
                                  if (dialogContext.mounted) {
                                    setState(() => isSubmitting = false);
                                  }
                                }
                              },
                              text: CustomTextfield.textWithStyles600('Yes'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // FULL-SCREEN LOADER OVERLAY
                if (isSubmitting)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black.withOpacity(0.30),
                      child: Center(
                        child: SizedBox(
                          height: 30,
                          width: 30,
                          child: AppLoader.inlineCircularLoader(
                            size: 30,
                            strokeWidth: 3,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  /*  static showDialogBox({
    required BuildContext context,

  }) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Column(
            children: [
              Image.asset(AppImages.close, height: 40, width: 40),
              SizedBox(height: 10),
              CustomTextfield.textWithStyles600('Stop new Ride Request?'),
            ],
          ),
          content: CustomTextfield.textWithStylesSmall(
            fontWeight: FontWeight.w500,
            textAlign: TextAlign.center,
            'You won’t receive any new request and you’ll be offline',
          ),
          backgroundColor: AppColors.commonWhite,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          actions: [
            Row(
              children: [
                Expanded(
                  child: Buttons.button(
                    buttonColor: AppColors.commonWhite,
                    textColor: AppColors.commonBlack,
                    borderRadius: 8,
                    borderColor: AppColors.buttonBorder,

                    onTap: () {
                      Navigator.pop(context);
                    },
                    text: CustomTextfield.textWithStyles600("Don't Stop"),
                  ),
                ),
                SizedBox(width: 5),
                Expanded(
                  child: Buttons.button(
                    buttonColor: AppColors.errorRed,
                    borderRadius: 8,

                    onTap: () {
                      Navigator.pop(context);
                    },
                    text: CustomTextfield.textWithStyles600('Yes'),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }*/

  static void showCancelRideBottomSheet(
    BuildContext context, {
    required Future<void> Function(String selectedReason) onConfirmCancel,
  }) {
    String? selectedReason;
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Stack(
              children: [
                // ───────── MAIN BOTTOM SHEET CONTENT ─────────
                DraggableScrollableSheet(
                  maxChildSize: 0.65,
                  minChildSize: 0.5,
                  initialChildSize: 0.65,
                  builder: (context, scrollController) {
                    return AbsorbPointer(
                      absorbing: isSubmitting, // 🔒 block taps while loading
                      child: Container(
                        decoration: const BoxDecoration(color: Colors.white),
                        padding: const EdgeInsets.all(20),
                        child: ListView(
                          controller: scrollController,
                          children: [
                            Center(
                              child: Container(
                                width: 40,
                                height: 5,
                                decoration: BoxDecoration(
                                  color: Colors.grey[300],
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            CustomTextfield.textWithStyles600(
                              textAlign: TextAlign.center,
                              fontSize: 20,
                              "Share the reason for cancelling the ride",
                            ),
                            const SizedBox(height: 5),
                            CustomTextfield.textWithStylesSmall(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              textAlign: TextAlign.center,
                              "Choose an issue",
                            ),
                            const SizedBox(height: 25),

                            ...[
                              'No face cover or mask',
                              'Can’t find the rider',
                              'Nowhere to stop',
                              'Rider’s items don’t fit',
                              'Too many riders',
                            ].map((reason) {
                              final isSelected = selectedReason == reason;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Buttons.button(
                                  borderColor:
                                      isSelected
                                          ? AppColors.commonBlack
                                          : AppColors.buttonBorder,
                                  buttonColor:
                                      isSelected
                                          ? AppColors.containerColor
                                          : AppColors.commonWhite,
                                  borderRadius: 8,
                                  textColor: AppColors.commonBlack,
                                  onTap: () {
                                    if (isSubmitting) return;
                                    setState(() => selectedReason = reason);
                                  },
                                  text: Text(reason),
                                ),
                              );
                            }).toList(),

                            const SizedBox(height: 10),

                            Buttons.button(
                              buttonColor:
                                  (selectedReason == null || isSubmitting)
                                      ? AppColors.containerColor
                                      : AppColors.commonBlack,
                              borderRadius: 8,
                              onTap: () async {
                                if (isSubmitting) return;

                                if (selectedReason == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        "Please select a reason before submitting",
                                      ),
                                    ),
                                  );
                                  return;
                                }

                                setState(() => isSubmitting = true);

                                try {
                                  await onConfirmCancel(selectedReason!);
                                  if (context.mounted) {
                                    Navigator.of(context).pop();
                                  }
                                } finally {
                                  if (context.mounted) {
                                    setState(() => isSubmitting = false);
                                  }
                                }
                              },
                              text: const Text('Submit Feedback'),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),

                // ───────── FULL-SCREEN LOADER OVERLAY ─────────
                if (isSubmitting)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black.withOpacity(0.35),
                      child: Center(
                        child: SizedBox(
                          height: 40,
                          width: 40,
                          child: AppLoader.inlineCircularLoader(
                            size: 40,
                            strokeWidth: 3,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  /// Unified shared-ride cancel sheet: the driver chooses to cancel ONE
  /// passenger (with a passenger picker) or ALL passengers, then a reason.
  /// Used on both the shared PICKUP and DROP screens.
  static void showSharedRideCancelSheet(
    BuildContext context, {
    required List<({String bookingId, String name})> riders,
    required Future<void> Function(String bookingId, String reason) onCancelOne,
    required Future<void> Function(String reason) onCancelAll,
  }) {
    String scope = riders.length <= 1 ? 'all' : 'one';
    String? selectedBookingId =
        riders.length == 1 ? riders.first.bookingId : null;
    String? selectedReason;
    bool isSubmitting = false;

    const reasons = <String>[
      'Can’t find the rider',
      'Rider not responding',
      'Nowhere to stop',
      'Rider’s items don’t fit',
      'Vehicle issue',
      'Other',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setState) {
            Widget scopeChip(String value, String label) {
              final sel = scope == value;
              return Expanded(
                child: GestureDetector(
                  onTap: isSubmitting ? null : () => setState(() => scope = value),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: sel ? AppColors.commonBlack : AppColors.commonWhite,
                      border: Border.all(
                        color: sel ? AppColors.commonBlack : AppColors.buttonBorder,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        label,
                        style: TextStyle(
                          color: sel ? Colors.white : AppColors.commonBlack,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }

            return Stack(
              children: [
                DraggableScrollableSheet(
                  maxChildSize: 0.9,
                  minChildSize: 0.5,
                  initialChildSize: 0.72,
                  builder: (context, scrollController) {
                    return AbsorbPointer(
                      absorbing: isSubmitting,
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          borderRadius:
                              BorderRadius.vertical(top: Radius.circular(25)),
                        ),
                        padding: const EdgeInsets.all(20),
                        child: ListView(
                          controller: scrollController,
                          children: [
                            Center(
                              child: Container(
                                width: 40,
                                height: 5,
                                decoration: BoxDecoration(
                                  color: Colors.grey[300],
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Center(
                              child: Text(
                                'Cancel ride',
                                style: TextStyle(
                                    fontSize: 20, fontWeight: FontWeight.w700),
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Center(
                              child: Text(
                                'Choose what to cancel and why',
                                style:
                                    TextStyle(fontSize: 13, color: Colors.grey),
                              ),
                            ),
                            const SizedBox(height: 18),
                            if (riders.length > 1) ...[
                              Row(
                                children: [
                                  scopeChip('one', 'This passenger'),
                                  scopeChip('all', 'All passengers'),
                                ],
                              ),
                              const SizedBox(height: 16),
                            ],
                            if (scope == 'one') ...[
                              const Text('Select passenger',
                                  style: TextStyle(fontWeight: FontWeight.w600)),
                              const SizedBox(height: 8),
                              ...riders.map((r) {
                                final sel = selectedBookingId == r.bookingId;
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: GestureDetector(
                                    onTap: isSubmitting
                                        ? null
                                        : () => setState(
                                            () => selectedBookingId = r.bookingId),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 14, vertical: 12),
                                      decoration: BoxDecoration(
                                        color: sel
                                            ? AppColors.containerColor
                                            : AppColors.commonWhite,
                                        border: Border.all(
                                          color: sel
                                              ? AppColors.commonBlack
                                              : AppColors.buttonBorder,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            sel
                                                ? Icons.radio_button_checked
                                                : Icons.radio_button_off,
                                            size: 20,
                                            color: sel
                                                ? AppColors.commonBlack
                                                : Colors.grey,
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              r.name,
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.w500),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }),
                              const SizedBox(height: 16),
                            ],
                            const Text('Reason',
                                style: TextStyle(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 8),
                            ...reasons.map((reason) {
                              final sel = selectedReason == reason;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Buttons.button(
                                  borderColor: sel
                                      ? AppColors.commonBlack
                                      : AppColors.buttonBorder,
                                  buttonColor: sel
                                      ? AppColors.containerColor
                                      : AppColors.commonWhite,
                                  borderRadius: 8,
                                  textColor: AppColors.commonBlack,
                                  onTap: () {
                                    if (isSubmitting) return;
                                    setState(() => selectedReason = reason);
                                  },
                                  text: Text(reason),
                                ),
                              );
                            }),
                            const SizedBox(height: 10),
                            Buttons.button(
                              buttonColor: AppColors.red,
                              borderRadius: 8,
                              onTap: () async {
                                if (isSubmitting) return;
                                if (scope == 'one' && selectedBookingId == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content:
                                          Text('Select a passenger to cancel'),
                                    ),
                                  );
                                  return;
                                }
                                if (selectedReason == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Please select a reason'),
                                    ),
                                  );
                                  return;
                                }
                                setState(() => isSubmitting = true);
                                try {
                                  if (scope == 'all') {
                                    await onCancelAll(selectedReason!);
                                  } else {
                                    await onCancelOne(
                                        selectedBookingId!, selectedReason!);
                                  }
                                  if (context.mounted) Navigator.of(context).pop();
                                } finally {
                                  if (context.mounted) {
                                    setState(() => isSubmitting = false);
                                  }
                                }
                              },
                              text: Text(
                                scope == 'all'
                                    ? 'Cancel all passengers'
                                    : 'Cancel this passenger',
                              ),
                            ),
                            const SizedBox(height: 10),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                if (isSubmitting)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black.withOpacity(0.35),
                      child: Center(
                        child: SizedBox(
                          height: 40,
                          width: 40,
                          child: AppLoader.inlineCircularLoader(
                            size: 40,
                            strokeWidth: 3,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  // static void showCancelRideBottomSheet(
  //   BuildContext context, {
  //   required Function(String selectedReason) onConfirmCancel,
  // }) {
  //   String? selectedReason;
  //
  //   showModalBottomSheet(
  //     context: context,
  //     isScrollControlled: true,
  //     backgroundColor: Colors.transparent,
  //     shape: RoundedRectangleBorder(
  //       borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
  //     ),
  //     builder: (_) {
  //       return StatefulBuilder(
  //         builder: (context, setState) {
  //           return DraggableScrollableSheet(
  //             maxChildSize: 0.65,
  //             minChildSize: 0.5,
  //             initialChildSize: 0.65,
  //             builder: (context, scrollController) {
  //               return Container(
  //                 decoration: BoxDecoration(
  //                   color: Colors.white,
  //                   // borderRadius: BorderRadius.vertical(
  //                   //   top: Radius.circular(25),
  //                   // ),
  //                 ),
  //                 padding: const EdgeInsets.all(20),
  //                 child: ListView(
  //                   controller: scrollController,
  //                   children: [
  //                     Center(
  //                       child: Container(
  //                         width: 40,
  //                         height: 5,
  //                         decoration: BoxDecoration(
  //                           color: Colors.grey[300],
  //                           borderRadius: BorderRadius.circular(10),
  //                         ),
  //                       ),
  //                     ),
  //                     const SizedBox(height: 20),
  //                     CustomTextfield.textWithStyles600(
  //                       textAlign: TextAlign.center,
  //                       fontSize: 20,
  //                       "Share the reason for cancelling the ride",
  //                     ),
  //                     const SizedBox(height: 5),
  //                     CustomTextfield.textWithStylesSmall(
  //                       fontSize: 14,
  //                       fontWeight: FontWeight.w500,
  //                       textAlign: TextAlign.center,
  //                       "Choose an issue",
  //                     ),
  //                     const SizedBox(height: 25),
  //
  //                     ...[
  //                       'No face cover or mask',
  //                       'Can’t find the rider',
  //                       'Nowhere to stop',
  //                       'Rider’s items don’t fit',
  //                       'Too many riders',
  //                     ].map((reason) {
  //                       final isSelected = selectedReason == reason;
  //                       return Padding(
  //                         padding: const EdgeInsets.only(bottom: 10),
  //                         child: Buttons.button(
  //                           borderColor:
  //                               isSelected
  //                                   ? AppColors.commonBlack
  //                                   : AppColors.buttonBorder,
  //                           buttonColor:
  //                               isSelected
  //                                   ? AppColors.containerColor
  //                                   : AppColors.commonWhite,
  //                           borderRadius: 8,
  //                           textColor: AppColors.commonBlack,
  //                           onTap: () {
  //                             setState(() => selectedReason = reason);
  //                           },
  //                           text: Text(reason),
  //                         ),
  //                       );
  //                     }).toList(),
  //
  //                     const SizedBox(height: 10),
  //                     Buttons.button(
  //                       buttonColor:
  //                           selectedReason == null
  //                               ? AppColors.containerColor
  //                               : AppColors.commonBlack,
  //                       borderRadius: 8,
  //                       onTap: () async {
  //                         if (selectedReason != null) {
  //                           await onConfirmCancel(
  //                             selectedReason!,
  //                           ); // ⬅️ callback with selected reason
  //                           Navigator.pop(context);
  //                         } else {
  //                           // Show a warning if no reason selected
  //                           ScaffoldMessenger.of(context).showSnackBar(
  //                             const SnackBar(
  //                               content: Text(
  //                                 "Please select a reason before submitting",
  //                               ),
  //                             ),
  //                           );
  //                         }
  //                       },
  //
  //                       text: Text('Submit Feedback'),
  //                     ),
  //                   ],
  //                 ),
  //               );
  //             },
  //           );
  //         },
  //       );
  //     },
  //   );
  // }
}

// Future<void> launchURL(Uri uri) async {
//   if (await canLaunchUrl(uri)) {
//     await launchUrl(uri);
//   } else {
//     throw 'Could not launch ${uri.path}';
//   }
// }
