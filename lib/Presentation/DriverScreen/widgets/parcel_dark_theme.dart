// Parcel delivery trust — light-surface design tokens (Driver App, parcel-only).
//
// Originally a full black theme (see git history) — moved to a light
// surface + colorful branded accents to match the rest of the app (which
// is white/light throughout) and the customer app's parcel screens, which
// have no dark theme at all. A full-black sheet combined with sparse
// content was reading as "a large black empty area" rather than an
// intentional design. Class name kept as ParcelDarkTheme (not renamed) to
// avoid churn across its 5 consumers — read it as "the parcel design
// tokens", not literally "dark". Applied ONLY behind
// `controller.isParcel.value` checks; car/solo/shared ride UI never
// imports this file.

import 'package:flutter/material.dart';

class ParcelDarkTheme {
  ParcelDarkTheme._();

  // Surfaces
  static const background = Colors.white;
  static const surface = Colors.white;
  static const surfaceSecondary = Color(0xFFF3F4F6);
  static const surfaceSunken = Color(0xFFF9FAFB); // dashed capture area, inputs

  // Borders
  static const border = Color(0xFFE5E7EB);
  static const borderStrong = Color(0xFFD1D5DB);

  // Text
  static const textPrimary = Color(0xFF111827);
  static const textSecondary = Color(0xFF6B7280);
  static const textMuted = Color(0xFF9CA3AF);

  // Brand — reused verbatim from Core/Constants/Colors.dart AppColors,
  // duplicated here as const only because AppColors declares them `final`
  // (computed at runtime), which can't be used in const contexts.
  static const accentGreen = Color(0xFF009721); // AppColors.drkGreen
  static const accentBlue = Color(0xFF006FD0); // AppColors.resendBlue
  static const accentRed = Color(0xFFF71609); // AppColors.red
  static const accentAmber = Color(0xFFEEA000); // AppColors.directionColor

  static BoxDecoration card({
    Color? color,
    double radius = 20,
    Color? borderColor,
  }) {
    return BoxDecoration(
      color: color ?? surface,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: borderColor ?? border),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0F000000),
          blurRadius: 12,
          offset: Offset(0, 4),
        ),
      ],
    );
  }
}
