import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Production-safe phone dialer launcher.
///
/// Avoids relying on `canLaunchUrl` (can be flaky on some Android devices due to
/// package visibility / queries) and uses a best-effort fallback strategy.
class CallLauncher {
  static String sanitizePhone(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return '';

    // Keep digits and a single leading '+'.
    final digits = trimmed.replaceAll(RegExp(r'[^0-9+]'), '');
    if (digits.isEmpty) return '';

    final hasPlus = digits.startsWith('+');
    final onlyDigits = digits.replaceAll('+', '');
    if (onlyDigits.isEmpty) return '';
    return hasPlus ? '+$onlyDigits' : onlyDigits;
  }

  static void _showFailure(BuildContext? context, String message) {
    if (context == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  static Future<bool> openDialer({
    required String phone,
    BuildContext? context,
    String failureMessage = 'Unable to open phone dialer',
  }) async {
    final sanitized = sanitizePhone(phone);
    if (sanitized.isEmpty) {
      _showFailure(context, 'Invalid phone number');
      return false;
    }

    final uri = Uri(scheme: 'tel', path: sanitized);

    Future<bool> _try(LaunchMode mode) async {
      try {
        return await launchUrl(uri, mode: mode);
      } catch (_) {
        return false;
      }
    }

    // Prefer external dialer app first; fall back to platform default.
    final ok = await _try(LaunchMode.externalApplication) ||
        await _try(LaunchMode.platformDefault);

    if (!ok) _showFailure(context, failureMessage);
    return ok;
  }
}

