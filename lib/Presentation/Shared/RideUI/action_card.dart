// Shared Ride UI — current-action card.
//
// The one card that tells the user (or driver) what to do right now: icon,
// title, message, single primary button with a loading state. Generic —
// used for "Start Delivery" today, any other single-CTA moment tomorrow.

import 'package:flutter/material.dart';
import 'ride_ui_theme.dart';

class ActionCard extends StatelessWidget {
  final IconData icon;
  final Color accentColor;
  final Color accentBackground;
  final String title;
  final String message;
  final String buttonLabel;
  final bool loading;
  final VoidCallback? onPressed;
  final IconData? buttonIcon;

  const ActionCard({
    super.key,
    required this.icon,
    required this.accentColor,
    required this.accentBackground,
    required this.title,
    required this.message,
    required this.buttonLabel,
    this.loading = false,
    required this.onPressed,
    this.buttonIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: RideUI.card(radius: RideUI.radiusCardLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: accentBackground,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 18, color: accentColor),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: RideUI.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: RideUI.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: loading ? null : onPressed,
              icon:
                  loading
                      ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                      : Icon(
                        buttonIcon ?? Icons.arrow_forward_rounded,
                        size: 20,
                      ),
              label: Text(
                buttonLabel,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                foregroundColor: Colors.white,
                disabledBackgroundColor: accentColor.withOpacity(0.5),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
