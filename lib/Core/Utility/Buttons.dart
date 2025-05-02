import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class Buttons {
  static final Buttons _singleton = Buttons._internal();

  Buttons._internal();

  static Buttons get instance => _singleton;

  static button({
    required GestureTapCallback? onTap,
    required String text,
    double? size = double.infinity,
    Color? buttonColor,
    Color? textColor = Colors.white,
    bool? isLoading,
    bool hasBorder = false,
    String? imagePath,
  }) {
    return SizedBox(
      width: size,
      height: 50.sp,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          shape:
              hasBorder
                  ? RoundedRectangleBorder(
                    side: BorderSide(color: Color(0xff3F5FF2)),
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
              Image.asset(imagePath, height: 24.sp, width: 24.sp),
              SizedBox(width: 10.w),
            ],
            Text(
              text,
              style: TextStyle(
                fontFamily: "Roboto-normal",
                fontSize: 16.sp,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
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
