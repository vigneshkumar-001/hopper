// Shared Ride UI — design tokens.
//
// Single source of truth for the premium light-surface look shared by the
// reusable ride-status widgets in this folder. Values are NOT new — they
// reuse the pastel palette already established in package_status_style.dart
// (both apps) and the ink/grey/border tones already used throughout
// package_map_confrim_screen.dart, just centralized so every widget in this
// folder draws from one place. Mirrored 1:1 in the driver app's copy of
// this file so both apps render an identical design language.
//
// These are ride-type-agnostic: nothing here is package/parcel-specific.
// Semantic status colors (blue/teal/indigo/amber/green/red) still come from
// packageStatusStyle() per-screen — this file only owns neutral surface,
// text, border, and the two deliberately-dark "vault" accent tokens used by
// OtpCard (security-sensitive content gets a dark card even though the rest
// of the UI is light — a deliberate accent, not an inconsistency).

import 'package:flutter/material.dart';

class RideUI {
  RideUI._();

  // Neutral surfaces
  static const pageBackground = Color(0xFFF4F5F7);
  static const surface = Colors.white;
  static const surfaceSecondary = Color(0xFFF3F4F6);
  static const surfaceSunken = Color(0xFFF9FAFB);

  // Borders
  static const border = Color(0xFFE5E7EB);
  static const borderStrong = Color(0xFFD1D5DB);

  // Text
  static const textPrimary = Color(0xFF111827);
  static const textSecondary = Color(0xFF6B7280);
  static const textMuted = Color(0xFF9CA3AF);

  // Brand
  static const brandGreen = Color(0xFF009721);
  static const brandBlue = Color(0xFF2563EB);

  // Dark "vault" accent — OtpCard and other security-sensitive emphasis
  // surfaces only. Never used for a whole-screen background.
  static const vault = Color(0xFF111827);
  static const vaultField = Color(0x14FFFFFF);
  static const vaultFieldBorder = Color(0x24FFFFFF);
  static const vaultTextPrimary = Color(0xFFF5F5F7);
  static const vaultTextSecondary = Color(0xFFC7CBD3);

  static const radiusCard = 18.0;
  static const radiusCardLg = 22.0;
  static const radiusPill = 20.0;

  static const List<BoxShadow> cardShadow = [
    BoxShadow(color: Color(0x0F000000), blurRadius: 12, offset: Offset(0, 4)),
  ];

  static BoxDecoration card({
    Color? color,
    double radius = radiusCard,
    Color? borderColor,
    List<BoxShadow>? shadow,
  }) {
    return BoxDecoration(
      color: color ?? surface,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: borderColor ?? border),
      boxShadow: shadow ?? cardShadow,
    );
  }

  static const Duration motionFast = Duration(milliseconds: 180);
  static const Duration motionBase = Duration(milliseconds: 220);
  static const Curve motionCurve = Curves.easeOutCubic;
}
