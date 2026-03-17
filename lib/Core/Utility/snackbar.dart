import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

class CustomSnackBar {
  static OverlayEntry? _currentEntry;
  static Timer? _dismissTimer;

  static void _showTopSnack({
    required String title,
    required String message,
    required Color backgroundColor,
    required IconData icon,
  }) {
    final overlay =
        Get.key.currentState?.overlay ??
        ((Get.overlayContext ?? Get.context) != null
            ? Overlay.maybeOf(
                Get.overlayContext ?? Get.context!,
                rootOverlay: true,
              )
            : null);
    if (overlay == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final retryOverlay =
            Get.key.currentState?.overlay ??
            ((Get.overlayContext ?? Get.context) != null
                ? Overlay.maybeOf(
                    Get.overlayContext ?? Get.context!,
                    rootOverlay: true,
                  )
                : null);
        if (retryOverlay == null) {
          return;
        }

        _dismissCurrent();
        _currentEntry = OverlayEntry(
          builder: (context) {
            return _TopSnackOverlay(
              title: title,
              message: message,
              backgroundColor: backgroundColor,
              icon: icon,
            );
          },
        );
        retryOverlay.insert(_currentEntry!);
        _dismissTimer = Timer(const Duration(seconds: 3), _dismissCurrent);
      });
      return;
    }

    _dismissCurrent();

    _currentEntry = OverlayEntry(
      builder: (context) {
        return _TopSnackOverlay(
          title: title,
          message: message,
          backgroundColor: backgroundColor,
          icon: icon,
        );
      },
    );

    overlay.insert(_currentEntry!);
    _dismissTimer = Timer(const Duration(seconds: 3), _dismissCurrent);
  }

  static void _dismissCurrent() {
    _dismissTimer?.cancel();
    _dismissTimer = null;
    _currentEntry?.remove();
    _currentEntry = null;
  }

  static void showSuccess(String message, {String title = 'Success'}) {
    _showTopSnack(
      title: title,
      message: message,
      backgroundColor: const Color(0xFF111827),
      icon: Icons.check_circle_rounded,
    );
  }

  static void showError(String message, {String title = 'Error'}) {
    _showTopSnack(
      title: title,
      message: message,
      backgroundColor: const Color(0xFFB42318),
      icon: Icons.error_rounded,
    );
  }

  static void showInfo(String message, {String title = 'Notice'}) {
    _showTopSnack(
      title: title,
      message: message,
      backgroundColor: const Color(0xFF1D4ED8),
      icon: Icons.info_rounded,
    );
  }

  static void showStatusToggle({required bool enabled, required String label}) {
    _showTopSnack(
      title: enabled ? '$label On' : '$label Off',
      message: enabled
          ? '$label is enabled now.'
          : '$label is disabled now.',
      backgroundColor:
          enabled ? const Color(0xFF111827) : const Color(0xFF475467),
      icon: enabled ? Icons.toggle_on_rounded : Icons.toggle_off_rounded,
    );
  }

  static void showDriverStatus({
    required bool isOnline,
    required String message,
  }) {
    _showTopSnack(
      title: 'Driver Status',
      message: message,
      backgroundColor:
          isOnline ? const Color(0xFF067647) : const Color(0xFFB42318),
      icon: isOnline ? Icons.wifi_tethering_rounded : Icons.wifi_off_rounded,
    );
  }
}

class _TopSnackOverlay extends StatefulWidget {
  const _TopSnackOverlay({
    required this.title,
    required this.message,
    required this.backgroundColor,
    required this.icon,
  });

  final String title;
  final String message;
  final Color backgroundColor;
  final IconData icon;

  @override
  State<_TopSnackOverlay> createState() => _TopSnackOverlayState();
}

class _TopSnackOverlayState extends State<_TopSnackOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    )..forward();
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -0.18),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
            child: SlideTransition(
              position: _slideAnimation,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 560),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: widget.backgroundColor,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x22000000),
                          blurRadius: 18,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Icon(widget.icon, color: Colors.white, size: 22),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                widget.message,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}


