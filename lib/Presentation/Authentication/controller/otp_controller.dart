import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hopper/Core/Constants/log.dart';
import 'package:hopper/Core/Utility/snackbar.dart';
import 'package:hopper/Presentation/Authentication/screens/Terms_Screen.dart';
import 'package:hopper/Presentation/OnBoarding/controller/chooseservice_controller.dart';
import 'package:hopper/api/dataSource/apiDataSource.dart';
import 'package:hopper/api/repository/failure.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OtpController extends GetxController {
  String accessToken = '';
  ApiDataSource apiDataSource = ApiDataSource();
  RxBool isLoading = false.obs;

  // Constructor to accept phone number
  // OtpController({required String phoneNumber}) {
  //   mobileNumber.text = phoneNumber;
  // }
  @override
  void onInit() {
    super.onInit();
  }

  Future<String?> verifyOtp(BuildContext context, String otp) async {
    isLoading.value = true;
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
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => TermsScreen()),
          );
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
  // Future<String?> resendOtp() async {
  //   isLoading.value = true;
  //   try {
  //     final results = await apiDataSource.verifyOtp( );
  //
  //     return results.fold(
  //       (failure) {
  //         isLoading.value = false;
  //
  //         CommonLogger.log.e('Failure: ${failure.message}');
  //         CustomSnackBar.showError(failure.message);
  //
  //         return failure.message; // from ServerFailure('...')
  //       },
  //       (response) async {
  //         // 681889f5a36e808c5056d290
  //         isLoading.value = false;
  //         accessToken = response.token;
  //         CommonLogger.log.i('Response = $accessToken');
  //         final prefs = await SharedPreferences.getInstance();
  //         await prefs.setString('token', response.token);
  //         await prefs.setString('userId', response.userId);
  //         CustomSnackBar.showSuccess(response.message);
  //
  //         return response.message;
  //       },
  //     );
  //   } catch (e) {
  //     isLoading.value = false;
  //     return 'An error occurred';
  //   }
  // }

  void clearState() {
    accessToken = '';
  }
}
