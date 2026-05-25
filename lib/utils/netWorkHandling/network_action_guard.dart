import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hopper/Presentation/Authentication/controller/network_handling_controller.dart';

class NetworkActionGuard {
  static NetworkController _controller() {
    if (Get.isRegistered<NetworkController>()) {
      return Get.find<NetworkController>();
    }
    return Get.put(NetworkController(), permanent: true);
  }

  /// Returns true when online; if offline shows a user-friendly message and
  /// returns false.
  static Future<bool> ensureOnline({
    BuildContext? context,
    String title = 'No Internet Connection',
    String message =
        'You are offline. Please turn on mobile data or Wi‑Fi and try again.',
  }) async {
    final messenger =
        context == null ? null : ScaffoldMessenger.maybeOf(context);
    final c = _controller();
    await c.checkConnectionNow();
    if (c.isConnected.value) return true;

    _showOfflineMessage(messenger, title: title, message: message);
    return false;
  }

  static void _showOfflineMessage(
    ScaffoldMessengerState? messenger, {
    required String title,
    required String message,
  }) {
    // Prefer ScaffoldMessenger when available (doesn't rely on Overlay.of).
    if (messenger != null) {
      messenger
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFF111827),
            duration: const Duration(seconds: 3),
            content: Text(
              '$title\n$message',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        );
      return;
    }

    // Fallback to GetX snackbar only if we have an overlay-capable context.
    final overlayCtx = Get.overlayContext ?? Get.context;
    if (overlayCtx != null && Overlay.maybeOf(overlayCtx) != null) {
      Get.closeAllSnackbars();
      Get.snackbar(
        title,
        message,
        snackPosition: SnackPosition.TOP,
        backgroundColor: const Color(0xFF111827),
        colorText: Colors.white,
        margin: const EdgeInsets.all(12),
        duration: const Duration(seconds: 3),
      );
      return;
    }

    // Last resort: avoid crashing if no overlay exists (e.g. during tests).
    debugPrint('[offline] $title: $message');
  }
}
