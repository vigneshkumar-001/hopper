import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hopper/Core/Constants/log.dart';
import 'package:hopper/Core/Utility/snackbar.dart';
import 'package:hopper/Presentation/Authentication/screens/Otp_Screens.dart';
import 'package:hopper/Presentation/Authentication/screens/Terms_Screen.dart';
import 'package:hopper/api/dataSource/apiDataSource.dart';
import 'package:hopper/api/repository/failure.dart';

var getMobileNumber = '';
var countryCodes = '';
String selectedCountryFlag = '';

class AuthController extends GetxController {
  // String mobileNumber = '';
  TextEditingController mobileNumber = TextEditingController();
  TextEditingController countryCodeController = TextEditingController();

  String accessToken = '';
  RxString selectedCountryCode = ''.obs;
  ApiDataSource apiDataSource = ApiDataSource();
  RxBool isLoading = false.obs;
  RxBool isGoogleLoading = false.obs;

  Future<String?> login(BuildContext context) async {
    final number = mobileNumber.text.trim();
    final String countryCode = countryCodeController.text.trim();
    getMobileNumber = number;
    countryCodes = countryCode;

    CommonLogger.log.i('Get Mobile = $getMobileNumber');
    CommonLogger.log.i('selectedCountryCodes = $countryCode');
    isLoading.value = true;
    try {
      final results = await apiDataSource.mobileNumberLogin(
        mobileNumber.text.trim().toString(),
        countryCode,
      );
      results.fold(
        (failure) {
          CustomSnackBar.showError(failure.message);
          isLoading.value = false;

          return '';
        },
        (response) {
          CustomSnackBar.showSuccess(response.message.toString());
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => OtpScreens(mobileNumber: number),
            ),
          );

          isLoading.value = false;

          return ' ';
        },
      );
    } catch (e) {
      isLoading.value = false;
      return ' ';
    }
    isLoading.value = false;
    return '';
  }

  Future<String?> googleSignInWithFirebase(
    BuildContext context,
    String email,
    String uniqueId,
  ) async {
    isGoogleLoading.value = true;
    try {
      final results = await apiDataSource.googleSignInWithFirebase(
        uniqueId: uniqueId,
        email: email,
      );
      results.fold(
        (failure) {
          CustomSnackBar.showError(failure.message);
          isGoogleLoading.value = false;

          return '';
        },
        (response) {
          isGoogleLoading.value = false;
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => TermsScreen()),
          );
          accessToken = response.data.token;
          CustomSnackBar.showSuccess(response.message.toString());

          return ' ';
        },
      );
    } catch (e) {
      isGoogleLoading.value = false; // Stop loading
      return ' ';
    }

    isGoogleLoading.value = false; // Stop loading
    return '';
  }

  void clearState() {
    accessToken = '';
    selectedCountryCode.value = '';
  }
}
