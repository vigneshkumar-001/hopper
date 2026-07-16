// Shared Ride UI — floating status header.
//
// Premium glass-dark pill meant to float over the map (top of the screen).
// Deliberately dark/translucent regardless of the rest of the screen being
// light — high-contrast legibility over a bright map, the same treatment
// already used ad hoc in the driver app's pickup screen. Generic: takes
// plain strings/colors, nothing package-specific, reusable for any ride type.

import 'package:flutter/material.dart';
import 'ride_ui_theme.dart';

class RideStatusHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? referenceId;
  final String? etaText;
  final Color accentColor;
  final IconData? icon;

  const RideStatusHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.referenceId,
    this.etaText,
    this.accentColor = RideUI.brandGreen,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: RideUI.motionBase,
      curve: RideUI.motionCurve,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: const Color(0xDE111827),
        borderRadius: BorderRadius.circular(RideUI.radiusCard),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.18),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 17, color: accentColor),
            ),
            const SizedBox(width: 10),
          ] else ...[
            AnimatedContainer(
              duration: RideUI.motionBase,
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: accentColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: RideUI.vaultTextPrimary,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (referenceId != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        referenceId!,
                        style: const TextStyle(
                          color: RideUI.vaultTextSecondary,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 1),
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: RideUI.vaultTextSecondary,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (etaText != null && etaText!.isNotEmpty) ...[
            const SizedBox(width: 8),
            Text(
              etaText!,
              style: TextStyle(
                color: accentColor,
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
