// Shared Ride UI — pickup/drop address card.
//
// Two-point route summary + optional distance/ETA meta line. Long Nigerian
// addresses wrap cleanly (maxLines: 2, ellipsis) rather than overflowing.

import 'package:flutter/material.dart';
import 'ride_ui_theme.dart';

class AddressCard extends StatelessWidget {
  final String? title;
  final String? pickupLabel;
  final String? pickupText;
  final String? dropLabel;
  final String? dropText;
  final String? metaText;

  const AddressCard({
    super.key,
    this.title,
    this.pickupLabel = 'Pickup',
    this.pickupText,
    this.dropLabel = 'Delivery',
    this.dropText,
    this.metaText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: RideUI.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(
              title!,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: RideUI.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
          ],
          if (pickupText != null && pickupText!.isNotEmpty)
            _AddressRow(
              icon: Icons.trip_origin_rounded,
              iconColor: RideUI.textPrimary,
              label: pickupLabel ?? 'Pickup',
              text: pickupText!,
            ),
          if (pickupText != null &&
              pickupText!.isNotEmpty &&
              dropText != null &&
              dropText!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 7),
              child: Container(width: 2, height: 14, color: RideUI.border),
            ),
          if (dropText != null && dropText!.isNotEmpty)
            _AddressRow(
              icon: Icons.location_on_rounded,
              iconColor: RideUI.brandGreen,
              label: dropLabel ?? 'Delivery',
              text: dropText!,
            ),
          if (metaText != null && metaText!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.route_outlined,
                  size: 15,
                  color: RideUI.textSecondary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    metaText!,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: RideUI.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _AddressRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String text;

  const _AddressRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: iconColor),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: RideUI.textMuted,
                  letterSpacing: 0.4,
                ),
              ),
              Text(
                text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: RideUI.textPrimary,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
