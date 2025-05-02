import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class CustomLinearProgress {
  static linearProgressIndicator({
    required double value,
    double minHeight = 10,
    Color? backgroundColor,
    Color? progressColor,
    double borderRadius = 15,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: LinearProgressIndicator(
        value: value,
        minHeight: minHeight,
        borderRadius: BorderRadius.circular(15),
        backgroundColor: backgroundColor ?? Colors.grey[300],
        valueColor: AlwaysStoppedAnimation<Color>(
          progressColor ?? Colors.black,
        ),
      ),
    );
  }
}
