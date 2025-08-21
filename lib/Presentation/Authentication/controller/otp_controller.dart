import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hopper/Core/Constants/log.dart';
import 'package:hopper/Core/Utility/snackbar.dart';
import 'package:hopper/Presentation/Authentication/screens/Terms_Screen.dart';
import 'package:hopper/Presentation/DriverScreen/screens/driver_main_screen.dart';
import 'package:hopper/Presentation/OnBoarding/controller/chooseservice_controller.dart';
import 'package:hopper/api/dataSource/apiDataSource.dart';
import 'package:hopper/api/repository/failure.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../DriverScreen/controller/driver_status_controller.dart';

class OtpController extends GetxController {
  String accessToken = '';
  String driverId = '';
  ApiDataSource apiDataSource = ApiDataSource();
  RxBool isLoading = false.obs;
  final RxBool isVerified = false.obs;
  final RxBool isEmailVerified = false.obs;
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
  }) async {
    // Safe way to trigger loading indicator
    WidgetsBinding.instance.addPostFrameCallback((_) {
      isLoading.value = true;
    });

    try {
      final results = await apiDataSource.verifyOtp(otp);

      return results.fold(
        (failure) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            isLoading.value = false;
            CustomSnackBar.showError(failure.message);
          });
          return failure.message;
        },
        (response) async {
          // Navigation should be deferred as well
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            if (response.data.formStatus == 3) {
              await controller.getDriverStatus();
              Get.offAll(() => DriverMainScreen());
            } else if (response.data.formStatus == 1 &&
                response.data.userStatus == 'new') {
              Get.offAll(() => TermsScreen());
            } else if (response.data.formStatus == 1 &&
                response.data.userStatus == 'exist') {
              await loadAndNavigate(context);
            } else {
              CommonLogger.log.i('Basic Info');
            }

            isLoading.value = false;
          });

          accessToken = response.data.token;
          driverId = response.data.driverId;

          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('token', response.data.token);
          await prefs.setString('driverId', response.data.driverId);

          return response.message;
        },
      );
    } catch (e) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        isLoading.value = false;
      });
      return 'An error occurred';
    }
  }

  /*  Future<String?> verifyOtp(
    BuildContext context,
    String otp, {
    String? type,
  }) async
  {
    isLoading.value = true;
    CommonLogger.log.i(type);
    try {
      final results = await apiDataSource.verifyOtp(otp);

      return results.fold(
        (failure) {
          isLoading.value = false;

          CommonLogger.log.e('${failure.message}');
          CustomSnackBar.showError(failure.message);

          return failure.message; // from ServerFailure('...')
        },
        (response) async {
          // 681889f5a36e808c5056d290
          if (response.data.formStatus == 3) {
            Get.offAll(DriverMainScreen());
          } else if (response.data.formStatus == 1 &&
              response.data.userStatus == 'new') {
            Get.offAll(TermsScreen());
          } else if (response.data.formStatus == 1 &&
              response.data.userStatus == 'exist') {
            await loadAndNavigate(context);
          } else {
            CommonLogger.log.i('Basic Info');
          }
          */ /*      if (type == 'basicInfo') {
            isVerified.value = response.status == 200;
            print("✅ isVerified: ${isVerified.value}");

            Navigator.pop(context);
          } else {
            isLoading.value = false;
            await loadAndNavigate(context);
            // Navigator.pushReplacement(
            //   context,
            //   MaterialPageRoute(builder: (context) => TermsScreen()),
            // );
          }*/ /*
          FocusScope.of(context).unfocus();
          // Navigator.pushReplacement(
          //   context,
          //   MaterialPageRoute(builder: (context) => DriverMainScreen()),
          // );
          isLoading.value = false;
          accessToken = response.data.token;
          driverId = response.data.driverId;

          CommonLogger.log.i('Response = $accessToken');
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('token', response.data.token);
          await prefs.setString('driverId', response.data.driverId);
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
  }*/

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
            print("✅ isVerified: ${isVerified.value}");

            Navigator.pop(context);

            print("✅ isVerified: ${isVerified.value}");
          }
          isLoading.value = false;
          accessToken = response.data.token;

          CommonLogger.log.i('Response = $accessToken');
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

  Future<void> loadAndNavigate(BuildContext context) async {
    final ChooseServiceController controller = Get.find();

    controller.handleLandingPageNavigation(Get.context!);
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

  void clearState() {
    accessToken = '';

    isVerified.value = false;
    isEmailVerified.value = false;
  }
}
