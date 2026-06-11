import 'package:flutter/material.dart';

/// Unified empty / error state used across the app: an illustration with a
/// title and an optional subtitle, plus an optional "Try again" action.
///
/// Every empty page (ride history, wallet, earnings, notifications, no driver
/// found, server errors) renders through this widget so they all share one
/// consistent font style, weight and layout — only the [image] and copy change.
class EmptyStateView extends StatelessWidget {
  /// Illustration asset (see [AppImages] empty-state entries).
  final String image;

  /// Bold primary line, e.g. "No rides yet".
  final String title;

  /// Optional lighter supporting line below the title.
  final String? subtitle;

  /// When provided, shows an amber "Try again" pill that calls this.
  final VoidCallback? onRetry;

  /// Label for the retry pill.
  final String retryText;

  /// Illustration width/height (defaults to 150).
  final double imageSize;

  const EmptyStateView({
    super.key,
    required this.image,
    required this.title,
    this.subtitle,
    this.onRetry,
    this.retryText = 'Try again',
    this.imageSize = 150,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              image,
              width: imageSize,
              height: imageSize,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF14213A),
              ),
            ),
            if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!.trim(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF667085),
                  height: 1.4,
                ),
              ),
            ],
            if (onRetry != null) ...[
              const SizedBox(height: 22),
              GestureDetector(
                onTap: onRetry,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8A317),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Text(
                    retryText,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
