import 'dart:math' as math;

import 'package:action_slider/action_slider.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// A production-friendly swipe button:
/// - Large draggable hit-area (so users can drag without first tapping the knob)
/// - Cupertino loader on iOS (still looks fine on Android)
/// - Keeps ActionSliderController API (loading/success/failure/reset)
class HopprSwipeSlider extends StatelessWidget {
  final ActionSliderController? controller;
  final Future<void> Function(ActionSliderController controller) onAction;
  final String text;
  final TextStyle? textStyle;
  final double height;
  final Color backgroundColor;
  final Color textColor;
  final Color handleColor;
  final Color handleIconColor;
  final BorderRadius borderRadius;
  final IconData idleIcon;
  final double minTravelDistance;

  const HopprSwipeSlider({
    super.key,
    this.controller,
    required this.onAction,
    required this.text,
    this.textStyle,
    this.height = 56,
    this.backgroundColor = const Color(0xFF1C1C1C),
    this.textColor = Colors.white,
    this.handleColor = Colors.white,
    this.handleIconColor = Colors.black,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
    this.idleIcon = Icons.double_arrow,
    this.minTravelDistance = 56,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w =
            constraints.hasBoundedWidth
                ? constraints.maxWidth
                : MediaQuery.sizeOf(context).width;
        // Make the draggable area big enough so user can start swiping from
        // almost anywhere, but still keep some travel distance.
        final margin = 5.0;
        final maxW = math.max(0.0, w - margin * 2);
        // Keep at least a small travel distance, otherwise the slider has no room to move.
        final travel = minTravelDistance.clamp(56.0, w);
        final maxToggleWidth = math.max(0.0, maxW - travel);
        final desiredToggleWidth = math.max(height - margin * 2, maxToggleWidth);
        final toggleWidth =
            maxW <= 56.0 ? maxW : desiredToggleWidth.clamp(56.0, maxW);

        return ActionSlider.custom(
          controller: controller,
          height: height,
          width: w,
          toggleWidth: toggleWidth,
          toggleMargin: EdgeInsets.all(margin),
          actionThresholdType: ThresholdType.release,
          actionThreshold: 0.98,
          // Disable tap-to-jump; we want pure swipe.
          onTap: null,
          outerBackgroundBuilder: (context, state, child) {
            return DecoratedBox(
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: borderRadius,
              ),
              child: child,
            );
          },
          backgroundBuilder: (context, state, _) {
            return Center(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    textStyle ??
                    TextStyle(
                      color: textColor,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            );
          },
          foregroundBuilder: (context, state, _) {
            Widget icon;
            switch (state.sliderMode) {
              case SliderMode.loading:
                icon = CupertinoActivityIndicator(
                  color: handleIconColor,
                  radius: 12,
                );
                break;
              case SliderMode.success:
                icon = Icon(Icons.check_rounded, color: handleIconColor, size: 26);
                break;
              case SliderMode.failure:
                icon = Icon(Icons.close_rounded, color: handleIconColor, size: 26);
                break;
              default:
                icon = Icon(idleIcon, color: handleIconColor, size: 28);
            }

            // Only the small handle is visible; rest is transparent but still draggable.
            final handleSize = height - margin * 2;
            return Stack(
              fit: StackFit.expand,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    width: handleSize,
                    height: handleSize,
                    decoration: BoxDecoration(
                      color: handleColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(child: icon),
                  ),
                ),
              ],
            );
          },
          action: (c) async {
            await onAction(c);
          },
        );
      },
    );
  }
}
