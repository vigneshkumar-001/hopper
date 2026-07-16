import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:hopper/Core/Utility/snackbar.dart';
import 'package:hopper/Presentation/Authentication/screens/Landing_Screens.dart';
import 'package:hopper/utils/session/logout_cleanup.dart';
import 'package:hopper/utils/sharedprefsHelper/sharedprefs_handler.dart';

class DriverSessionExpiryHandler {
  DriverSessionExpiryHandler._();

  static bool _handling = false;

  static Future<void> handle({required String message}) async {
    if (_handling) return;
    _handling = true;

    try {
      CustomSnackBar.dismiss();
      await SharedPrefHelper.clearAll();
      Get.offAll(
        () => const LandingScreens(),
        transition: Transition.noTransition,
      );
      await WidgetsBinding.instance.endOfFrame;
      await performLogoutCleanup();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        CustomSnackBar.showError(message);
      });
    } finally {
      _handling = false;
    }
  }
}
