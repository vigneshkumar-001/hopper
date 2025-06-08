import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../Core/Constants/log.dart';
import '../../../Core/Utility/snackbar.dart';
import '../screens/Terms_Screen.dart';
import '../../OnBoarding/controller/chooseservice_controller.dart';
import '../../../api/dataSource/apiDataSource.dart';
import '../../../api/repository/failure.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OtpController extends GetxController {
  String accessToken = '';
  ApiDataSource apiDataSource = ApiDataSource();
  RxBool isLoading = false.obs;
  final RxBool isVerified = false.obs;
  final RxBool isEmailVerified = false.obs;

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
          if (type == 'basicInfo') {
            isVerified.value = response.status == 200;
            print("✅ isVerified: ${isVerified.value}");

            Navigator.pop(context);
          } else {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => TermsScreen()),
            );
          }
          isLoading.value = false;
          accessToken = response.data.token;

          CommonLogger.log.i('Response = $accessToken');
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('token', response.data.token);
          // await prefs.setString('userId', response.userId);
          CustomSnackBar.showSuccess(response.message);
          // await loadAndNavigate(context);

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
  }) async {
    isLoading.value = true;
    CommonLogger.log.i(type);
    try {
      final results = await apiDataSource.emailOtp(otp, email ?? '');

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
            Future.delayed(Duration(milliseconds: 300), () {
              isVerified.value = false;
            });
            print("✅ isVerified: ${isVerified.value}");
          }
          isLoading.value = false;
          accessToken = response.data.token;

          CommonLogger.log.i('Response = $accessToken');
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('token', response.data.token);
          // await prefs.setString('userId', response.userId);
          CustomSnackBar.showSuccess(response.message);
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
    await controller.getUserDetails();
    controller.handleLandingPageNavigation(Get.context!);
  }

  Future<String?> resendOtp(String mobileNumber) async {
    isLoading.value = true;
    try {
      final results = await apiDataSource.resendOtp(mobileNumber);

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
          accessToken = response.data.token;
          CommonLogger.log.i('Response = $accessToken');
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('token', response.data.token);
          // await prefs.setString('userId', response. data.);
          CustomSnackBar.showSuccess(response.message);

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
