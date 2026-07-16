// Shared Ride UI — success/completion screen.
//
// Full-screen completion moment: animated check, title/subtitle, optional
// preview image (POD photo etc.), a list of detail rows, one primary
// button. Generic — works for a package delivered, a ride completed.

import 'package:flutter/material.dart';
import 'ride_info_card.dart';
import 'ride_ui_theme.dart';

class SuccessView extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? previewImage;
  final List<RideInfoRow>? details;
  final String buttonLabel;
  final VoidCallback onButtonPressed;

  const SuccessView({
    super.key,
    required this.title,
    required this.subtitle,
    this.previewImage,
    this.details,
    required this.buttonLabel,
    required this.onButtonPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RideUI.pageBackground,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                child: Column(
                  children: [
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.6, end: 1.0),
                      duration: const Duration(milliseconds: 320),
                      curve: Curves.easeOutBack,
                      builder:
                          (context, scale, child) =>
                              Transform.scale(scale: scale, child: child),
                      child: Container(
                        width: 84,
                        height: 84,
                        decoration: const BoxDecoration(
                          color: Color(0xFFEAF9EE),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check_circle_rounded,
                          size: 48,
                          color: RideUI.brandGreen,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                        color: RideUI.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: RideUI.textSecondary,
                        height: 1.4,
                      ),
                    ),
                    if (previewImage != null) ...[
                      const SizedBox(height: 20),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: previewImage,
                      ),
                    ],
                    if (details != null && details!.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      RideInfoCard(rows: details!),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: onButtonPressed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: RideUI.brandGreen,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  child: Text(
                    buttonLabel,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15.5,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
