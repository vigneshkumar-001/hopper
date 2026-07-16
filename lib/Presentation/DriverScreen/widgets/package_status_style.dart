// Package delivery trust — central status→style mapper (Driver App).
//
// Single source of truth for how a `parcelStatus` value renders anywhere in
// the package-delivery screens: label, one-line message, icon, and color.
// Widgets must read colors from here instead of hardcoding hex values, so a
// palette change never needs a multi-file hunt.

import 'package:flutter/material.dart';

/// Visual state of a single timeline entry — independent of the specific
/// status it represents.
enum PackageTimelineState { completed, active, pending, failed }

/// The 7 states in their canonical forward order. `FAILED_DELIVERY` is a
/// branch, not a forward step, so it is intentionally excluded from this
/// list — callers needing timeline position should special-case it.
const List<String> kPackageStatusOrder = [
  'ORDER_CONFIRMED',
  'COURIER_ASSIGNED',
  'PICKED_UP',
  'IN_TRANSIT',
  'OUT_FOR_DELIVERY',
  'DELIVERED',
];

class PackageStatusStyle {
  final String label;
  final String message;
  final IconData icon;
  final Color color;
  final Color background;

  const PackageStatusStyle({
    required this.label,
    required this.message,
    required this.icon,
    required this.color,
    required this.background,
  });
}

// Semantic colors not already present in AppColors — added here rather than
// duplicated per-widget (teal for picked-up, indigo for in-transit, amber
// for out-for-delivery have no existing equivalent in Core/Constants/Colors).
class _PackageColors {
  static const neutral = Color(0xFF64748B); // blue-gray — order confirmed
  static const blue = Color(0xFF2563EB); // courier assigned
  static const teal = Color(0xFF0D9488); // picked up
  static const indigo = Color(0xFF4F46E5); // in transit
  static const amber = Color(0xFFD97706); // out for delivery
  static const green = Color(0xFF15803D); // delivered
  static const red = Color(0xFFDC2626); // failed delivery
}

/// Resolve the full visual style for a `parcelStatus` value. Falls back to
/// the ORDER_CONFIRMED style for empty/unrecognized input (matches the
/// backend's "unset means ORDER_CONFIRMED" contract).
PackageStatusStyle packageStatusStyle(String status) {
  switch (status) {
    case 'COURIER_ASSIGNED':
      return const PackageStatusStyle(
        label: 'Courier assigned',
        message: 'Your courier is heading to the pickup location.',
        icon: Icons.person_pin_circle_rounded,
        color: _PackageColors.blue,
        background: Color(0xFFEFF4FF),
      );
    case 'PICKED_UP':
      return const PackageStatusStyle(
        label: 'Package collected',
        message: 'The package has been verified and collected successfully.',
        icon: Icons.inventory_2_rounded,
        color: _PackageColors.teal,
        background: Color(0xFFEBFAF8),
      );
    case 'IN_TRANSIT':
      return const PackageStatusStyle(
        label: 'Package on the way',
        message: 'The package is moving toward the delivery address.',
        icon: Icons.local_shipping_rounded,
        color: _PackageColors.indigo,
        background: Color(0xFFF0EFFE),
      );
    case 'OUT_FOR_DELIVERY':
      return const PackageStatusStyle(
        label: 'Out for delivery',
        message: 'You are approaching the receiver.',
        icon: Icons.directions_bike_rounded,
        color: _PackageColors.amber,
        background: Color(0xFFFFF6E9),
      );
    case 'DELIVERED':
      return const PackageStatusStyle(
        label: 'Package delivered',
        message: 'The package was handed over successfully.',
        icon: Icons.check_circle_rounded,
        color: _PackageColors.green,
        background: Color(0xFFEAF9EE),
      );
    case 'FAILED_DELIVERY':
      return const PackageStatusStyle(
        label: 'Delivery attempt unsuccessful',
        message: 'The delivery could not be completed.',
        icon: Icons.error_rounded,
        color: _PackageColors.red,
        background: Color(0xFFFDECEC),
      );
    case 'ORDER_CONFIRMED':
    default:
      return const PackageStatusStyle(
        label: 'Order confirmed',
        message: 'Waiting to be picked up.',
        icon: Icons.receipt_long_rounded,
        color: _PackageColors.neutral,
        background: Color(0xFFF1F5F9),
      );
  }
}

/// Timeline-row visual state for [step] given the package's current
/// [currentStatus]. `failedOnStep` lets a caller mark exactly one step (the
/// one in progress when FAILED_DELIVERY was reached) as failed instead of
/// pending.
PackageTimelineState packageTimelineStateFor({
  required String step,
  required String currentStatus,
  String? failedOnStep,
}) {
  if (currentStatus == 'FAILED_DELIVERY' && step == failedOnStep) {
    return PackageTimelineState.failed;
  }
  final effective =
      currentStatus == 'FAILED_DELIVERY'
          ? (failedOnStep ?? 'IN_TRANSIT')
          : (currentStatus.isEmpty ? 'ORDER_CONFIRMED' : currentStatus);
  final stepIndex = kPackageStatusOrder.indexOf(step);
  final currentIndex = kPackageStatusOrder.indexOf(effective);
  if (stepIndex < 0 || currentIndex < 0) return PackageTimelineState.pending;
  if (stepIndex < currentIndex) return PackageTimelineState.completed;
  if (stepIndex == currentIndex) return PackageTimelineState.active;
  return PackageTimelineState.pending;
}
