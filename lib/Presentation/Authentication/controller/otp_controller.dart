import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hopper/Core/Constants/log.dart';
import 'package:hopper/Core/Utility/snackbar.dart';
import 'package:hopper/Presentation/Authentication/screens/Terms_Screen.dart';
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
  // Constructor to accept phone number
  // OtpController({required String phoneNumber}) {
  //   mobileNumber.text = phoneNumber;
  // }
  @override
  void onInit() {
    super.onInit();
    isVerified.value = false;
  }

  Future<String?> verifyOtp(
    BuildContext context,
    String otp, {
    String? type,
  }) async
  {
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

          // ✅ Persist auth BEFORE any follow-up calls (getUserDetails/getDriverStatus)
          if (accessToken.isNotEmpty) {
            await prefs.setString('token', accessToken);
          }
            if (driverId.isNotEmpty) {
              await prefs.setString('driverId', driverId);
            }

            if (response.data.formStatus == 3) {
              await prefs.setBool("isVerified", true);
              // Navigate immediately; fetch status without blocking UI.
              Get.off(() => DriverMainScreen());
              // ignore: unawaited_futures
              controller.getDriverStatus();
            } else if (response.data.formStatus == 2) {
              // formStatus=2 => onboarding submitted / in-review: show CompletedScreens.
              await prefs.setBool("isVerified", true);
              final ChooseServiceController chooseCtrl =
                  Get.put(ChooseServiceController(), permanent: true);
              try {
                await chooseCtrl.getUserDetails();
              } catch (_) {}
              Get.offAll(() => const CompletedScreens());
            } else if (response.data.formStatus == 1 &&
                response.data.userStatus == 'new') {
              Get.off(() => TermsScreen());
            } else if (response.data.formStatus == 1 &&
              response.data.userStatus == 'exist') {
            await loadAndNavigate();
          } else {
            CommonLogger.log.i('Basic Info');
          }
          final fcmToken = prefs.getString('fcmToken');
          sendFcmToken(fcmToken: fcmToken ?? '');
          isLoading.value = false;

          return response.message;
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

          CommonLogger.log.e('${failure.message}');
          CustomSnackBar.showError(failure.message);

          return failure.message; // from ServerFailure('...')
        },
        (response) async {
          // 681889f5a36e808c5056d290
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
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('token', response.data.token);
          // await prefs.setString('userId', response.userId);
          // CustomSnackBar.showSuccess(response.message);
          // await loadAndNavigate(context);

          return response.message;
        },
      );
    } catch (e) {
      isLoading.value = false;
      return 'An error occurred';
    }
  }

  Future<void> loadAndNavigate() async {
    final ChooseServiceController chooseCtrl = Get.put(ChooseServiceController(), permanent: true);
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

          return failure.message; // from ServerFailure('...')
        },
        (response) async {
          // 681889f5a36e808c5056d290
          isLoading.value = false;
          // accessToken = response.data.token;
          // CommonLogger.log.i('Response = $accessToken');
          // final prefs = await SharedPreferences.getInstance();
          // await prefs.setString('token', response.data.token);
          // // await prefs.setString('userId', response. data.);
          // CustomSnackBar.showSuccess(response.message);

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
          // Get.snackbar(
          //   "Error",
          //   failure.message,
          //   snackPosition: SnackPosition.TOP,
          //   backgroundColor: Get.theme.colorScheme.secondary,
          //   colorText: Get.theme.colorScheme.onSecondary,
          // );
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
