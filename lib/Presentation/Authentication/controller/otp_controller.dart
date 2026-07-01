import 'dart:async';
import 'package:hopper/utils/sharedprefsHelper/sharedprefs_handler.dart';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hopper/Core/Constants/log.dart';
import 'package:hopper/Core/Utility/snackbar.dart';
import 'package:hopper/Presentation/Authentication/screens/Terms_Screen.dart';
import 'package:hopper/Presentation/Authentication/screens/post_otp_routing_screen.dart';
import 'package:hopper/Presentation/DriverScreen/screens/driver_main_screen.dart';
import 'package:hopper/Presentation/OnBoarding/controller/chooseservice_controller.dart';
import 'package:hopper/Presentation/OnBoarding/screens/completedScreens.dart';
import 'package:hopper/api/dataSource/apiDataSource.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../DriverScreen/controller/driver_status_controller.dart';

class OtpController extends GetxController {
  String accessToken = '';
  String driverId = '';
  ApiDataSource apiDataSource = ApiDataSource();
  RxBool isLoading = false.obs;
  final RxBool isVerified = false.obs;
  final RxBool isEmailVerified = false.obs;
  final RxString verifiedEmail = ''.obs;
  final DriverStatusController controller = Get.put(DriverStatusController());

  @override
  void onInit() {
    super.onInit();
    isVerified.value = false;
  }

  Future<String?> verifyOtp(
    BuildContext context,
    String otp, {
    String? type,
  }) async {
    try {
      isLoading.value = true;
      final results = await apiDataSource.verifyOtp(otp);

      return results.fold(
        (failure) {
          isLoading.value = false;
          CustomSnackBar.showError(failure.message);
          return failure.message;
        },
        (response) async {
          final prefs = await SharedPreferences.getInstance();

          accessToken = response.data.token;
          driverId = response.data.driverId;

          if (accessToken.isNotEmpty) {
            await SharedPrefHelper.setToken(accessToken);
          }
          if (driverId.isNotEmpty) {
            await prefs.setString('driverId', driverId);
          }

          final formStatus = response.data.formStatus;
          final userStatus = response.data.userStatus;

          isLoading.value = false;

          if (formStatus == 3) {
            await prefs.setBool("isVerified", true);
            Get.offAll(() => DriverMainScreen());
            unawaited(controller.getDriverStatus());
          } else if (formStatus == 2) {
            await prefs.setBool("isVerified", true);
            Get.offAll(() => const CompletedScreens());
            final ChooseServiceController chooseCtrl = Get.put(
              ChooseServiceController(),
              permanent: true,
            );
            unawaited(chooseCtrl.getUserDetails());
          } else if (formStatus == 1 && userStatus == 'new') {
            Get.offAll(() => TermsScreen());
          } else if (formStatus == 1 && userStatus == 'exist') {
            Get.offAll(() => const PostOtpRoutingScreen());
          } else {
            CommonLogger.log.i('Basic Info');
          }

          final fcmToken = prefs.getString('fcmToken');
          unawaited(sendFcmToken(fcmToken: fcmToken ?? ''));

          return null;
        },
      );
    } catch (e) {
      isLoading.value = false;
      return 'An error occurred';
    }
  }

  Future<String?> emailVerifyOtp(
    BuildContext context,
    String otp, {
    String? type,
    String? email,
    String? emailOrMobile,
  }) async {
    isLoading.value = true;
    CommonLogger.log.i(type);
    try {
      final results = await apiDataSource.emailOtp(
        email: email ?? '',
        otp: otp,
        type: emailOrMobile ?? '',
      );

      return results.fold(
        (failure) {
          isLoading.value = false;

          CommonLogger.log.e(failure.message);
          CustomSnackBar.showError(failure.message);

          return failure.message;
        },
        (response) async {
          if (type == 'basicInfo') {
            isEmailVerified.value = response.status == 200;
            if (response.status == 200) {
              verifiedEmail.value = (email ?? '').trim();
            }
            Navigator.pop(context);
          }
          isLoading.value = false;
          accessToken = response.data.token;

          CommonLogger.log.d('Auth token stored');
          await SharedPrefHelper.setToken(response.data.token);

          return response.message;
        },
      );
    } catch (e) {
      isLoading.value = false;
      return 'An error occurred';
    }
  }

  Future<void> loadAndNavigate() async {
    final ChooseServiceController chooseCtrl = Get.put(
      ChooseServiceController(),
      permanent: true,
    );
    await chooseCtrl.getUserDetails();
    chooseCtrl.handleLandingPageNavigation(clearStack: false);
  }

  Future<String?> resendOtp(
    String mobileNumber,
    String email,
    String type,
  ) async {
    isLoading.value = true;
    try {
      final results = await apiDataSource.resendOtp(
        mobileNumber,
        type: type,
        email: email,
      );

      return results.fold(
        (failure) {
          isLoading.value = false;

          CommonLogger.log.e('Failure: ${failure.message}');
          CustomSnackBar.showError(failure.message);

          return failure.message;
        },
        (response) async {
          isLoading.value = false;
          return response.message;
        },
      );
    } catch (e) {
      isLoading.value = false;
      return 'An error occurred';
    }
  }

  Future<String?> sendFcmToken({required String fcmToken}) async {
    try {
      final results = await apiDataSource.sendFcmToken(fcmToken: fcmToken);
      results.fold(
        (failure) {
          isLoading.value = false;
        },
        (response) {
          isLoading.value = false;
          CommonLogger.log.i('I Sended Fresh FCM Token');
        },
      );
    } catch (e) {
      isLoading.value = false;
      return ' ';
    }
    isLoading.value = false;
    return ' ';
  }

  void clearState() {
    accessToken = '';
    isVerified.value = false;
    isEmailVerified.value = false;
    verifiedEmail.value = '';
  }
}
