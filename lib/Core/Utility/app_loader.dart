import 'package:flutter/material.dart';
import 'package:hopper/Core/Utility/images.dart';

import '../Constants/Colors.dart';

class AppLoader {
  static Widget appLoader({double? imgHeight = 70, double? imgWeight = 70}) {
    return Image.asset(
      AppImages. animation,
      fit: BoxFit.contain,
      height: imgHeight,
      width: imgWeight,
    );
  }

  static circularLoader() {
    return Center(
      child: CircularProgressIndicator(
        color: AppColors.commonBlack,
        strokeWidth: 2,
      ),
    );
  }
}
