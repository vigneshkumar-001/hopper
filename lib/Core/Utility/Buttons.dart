import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'images.dart';

class Buttons {
  static final Buttons _singleton = Buttons._internal();

  Buttons._internal();

  static Buttons get instance => _singleton;

  static Widget button({
    required GestureTapCallback? onTap,
    required Widget text,
    double? size = double.infinity,
    double? imgHeight = 24,
    double? imgWeight = 24,

    Color? buttonColor,
    Color? foreGroundColor,
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
                    side: const BorderSide(color: Color(0xff3F5FF2)),
                    borderRadius: BorderRadius.circular(4),
                  )
                  : RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
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
              Image.asset(imagePath, height: imgHeight!.sp, width: imgWeight!.sp),
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
}

// Future<void> launchURL(Uri uri) async {
//   if (await canLaunchUrl(uri)) {
//     await launchUrl(uri);
//   } else {
//     throw 'Could not launch ${uri.path}';
//   }
// }
