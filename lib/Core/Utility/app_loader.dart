import 'package:flutter/material.dart';
import 'package:hopper/Core/Utility/images.dart';
import 'package:hopper/utils/widgets/hoppr_circular_loader.dart';

import '../Constants/Colors.dart';

class AppLoader {
  static Widget appLoader({double? imgHeight = 70, double? imgWeight = 70}) {
    return Image.asset(
      AppImages.animation,
      fit: BoxFit.contain,
      height: imgHeight,
      width: imgWeight,
    );
  }

  static Widget inlineCircularLoader({
    double radius = 14,
    double strokeWidth = 2,
    Color? color,
    double? size,
  }) {
    return HopprCircularLoader(
      radius: radius,
      color: color ?? AppColors.commonBlack,
      size: size,
    );
  }

  static Widget circularLoader({
    double radius = 14,
    double strokeWidth = 2,
    Color? color,
    double? size,
  }) {
    return Center(
      child: inlineCircularLoader(
        radius: radius,
        strokeWidth: strokeWidth,
        color: color,
        size: size,
      ),
    );
  }
}
