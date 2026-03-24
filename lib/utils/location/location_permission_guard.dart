import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';

class LocationPermissionGuard extends GetxService with WidgetsBindingObserver {
  bool _dialogOpen = false;
  bool _checking = false;
  Timer? _retryTimer;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);

    // Wait for GetMaterialApp to build an overlay context.
    Future<void>.delayed(const Duration(milliseconds: 800), () {
      unawaited(checkAndHandle(showDialog: true));
    });
  }

  @override
  void onClose() {
    _retryTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.onClose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(checkAndHandle(showDialog: true));
    }
  }

  Future<bool> isReady() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    final permission = await Geolocator.checkPermission();
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  Future<bool> ensureReady({bool showDialog = true}) async {
    final ok = await isReady();
    if (ok) {
      _closeDialogIfOpen();
      return true;
    }

    if (showDialog) {
      await checkAndHandle(showDialog: true);
    }
    return false;
  }

  Future<void> checkAndHandle({required bool showDialog}) async {
    if (_checking) return;
    _checking = true;
    try {
      final ok = await isReady();
      if (ok) {
        _closeDialogIfOpen();
        return;
      }
      if (showDialog) {
        _showDialogIfNeeded();
      }
    } finally {
      _checking = false;
    }
  }

  void _closeDialogIfOpen() {
    if (!_dialogOpen) return;
    if (Get.isDialogOpen == true) {
      Get.back();
    }
    _dialogOpen = false;
    _retryTimer?.cancel();
    _retryTimer = null;
  }

  Future<void> _checkAndGate() async {
    await checkAndHandle(showDialog: false);
    final ok = await isReady();
    if (ok) _closeDialogIfOpen();
  }

  void open() {
    if (_dialogOpen) return;

    // If UI not ready yet, retry shortly.
    if (Get.overlayContext == null) {
      _retryTimer?.cancel();
      _retryTimer = Timer(const Duration(milliseconds: 500), () {
        unawaited(checkAndHandle(showDialog: true));
      });
      return;
    }

    _dialogOpen = true;

    Get.dialog(
      _locationBlockDialog(
        title: 'Turn on Location',
        message:
            'Please enable GPS/Location services. This app is location-based and needs your location to work.',
        primaryText: 'Open Settings',
        onPrimary: () async {
          await _openSettingsFlow();
        },
        secondaryText: 'Retry',
        onSecondary: () async {
          await _checkAndGate();
        },
        icon: Icons.location_on_rounded,
      ),
      barrierDismissible: false,
      useSafeArea: true,
    ).whenComplete(() {
      _dialogOpen = false;
    });
  }

  void _showDialogIfNeeded() {
    if (_dialogOpen) return;
    open();
  }

  Future<void> _openSettingsFlow() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      await Geolocator.openLocationSettings();
      return;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever ||
        permission == LocationPermission.denied) {
      await Geolocator.openAppSettings();
      return;
    }

    // In-app grant path.
    await checkAndHandle(showDialog: true);
  }
}

Widget _locationBlockDialog({
  required String title,
  required String message,
  required String primaryText,
  required Future<void> Function() onPrimary,
  required String secondaryText,
  required Future<void> Function() onSecondary,
  required IconData icon,
}) {
  return Dialog(
    insetPadding: const EdgeInsets.symmetric(horizontal: 22),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 52,
            width: 52,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.06),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 28, color: Colors.black),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              height: 1.35,
              color: Colors.black.withOpacity(0.74),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () async => onSecondary(),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    side: BorderSide(color: Colors.black.withOpacity(0.14)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text(
                    secondaryText,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () async => onPrimary(),
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    backgroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text(
                    primaryText,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
