// Shared Ride UI — courier/driver info card.
//
// Premium horizontal card: photo, name, rating, vehicle, call/message.
// Generic "the other person on this trip" card — works equally for a
// package courier, a solo-ride driver, or a shared-ride driver.

import 'package:flutter/material.dart';
import 'ride_ui_theme.dart';

class DriverInfoCard extends StatelessWidget {
  final String name;
  final String? photoUrl;
  final double? rating;
  final String? vehicleLabel;
  final String? vehicleNumber;
  final VoidCallback? onCall;
  final VoidCallback? onMessage;

  const DriverInfoCard({
    super.key,
    required this.name,
    this.photoUrl,
    this.rating,
    this.vehicleLabel,
    this.vehicleNumber,
    this.onCall,
    this.onMessage,
  });

  @override
  Widget build(BuildContext context) {
    final vehicleText = [
      vehicleLabel,
      vehicleNumber,
    ].where((e) => e != null && e.isNotEmpty).join(' · ');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: RideUI.card(),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: RideUI.surfaceSecondary,
              borderRadius: BorderRadius.circular(14),
            ),
            clipBehavior: Clip.antiAlias,
            child:
                (photoUrl != null && photoUrl!.trim().isNotEmpty)
                    ? Image.network(
                      photoUrl!,
                      fit: BoxFit.cover,
                      errorBuilder:
                          (_, __, ___) => const Icon(
                            Icons.person_rounded,
                            color: RideUI.textSecondary,
                          ),
                    )
                    : const Icon(
                      Icons.person_rounded,
                      color: RideUI.textSecondary,
                    ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: RideUI.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    if (rating != null) ...[
                      const Icon(
                        Icons.star_rounded,
                        size: 14,
                        color: Color(0xFFE79700),
                      ),
                      const SizedBox(width: 2),
                      Text(
                        rating!.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: RideUI.textSecondary,
                        ),
                      ),
                      if (vehicleText.isNotEmpty) const SizedBox(width: 6),
                    ],
                    if (vehicleText.isNotEmpty)
                      Flexible(
                        child: Text(
                          vehicleText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: RideUI.textSecondary,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (onMessage != null) ...[
            _IconAction(
              icon: Icons.chat_bubble_rounded,
              background: RideUI.surfaceSecondary,
              foreground: RideUI.textPrimary,
              onTap: onMessage!,
            ),
            const SizedBox(width: 8),
          ],
          if (onCall != null)
            _IconAction(
              icon: Icons.call_rounded,
              background: const Color(0xFFEAF9EE),
              foreground: RideUI.brandGreen,
              onTap: onCall!,
            ),
        ],
      ),
    );
  }
}

class _IconAction extends StatelessWidget {
  final IconData icon;
  final Color background;
  final Color foreground;
  final VoidCallback onTap;

  const _IconAction({
    required this.icon,
    required this.background,
    required this.foreground,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(color: background, shape: BoxShape.circle),
        child: Icon(icon, size: 18, color: foreground),
      ),
    );
  }
}
