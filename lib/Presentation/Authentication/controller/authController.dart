import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../Core/Constants/log.dart';
import 'package:country_picker/country_picker.dart';

import '../../../Core/Utility/snackbar.dart';
import '../screens/Landing_Screens.dart';
import '../screens/Otp_Screens.dart';
import '../screens/Terms_Screen.dart';
import '../../../api/dataSource/apiDataSource.dart';
import '../../../api/repository/failure.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  final errorText = ''.obs;

  @override
  void onInit() {
    super.onInit();
  }

  void setSelectedCountry(Country country) {
    selectedCountryCode.value = '+${country.phoneCode}';
    countryCodeController.text = '+${country.phoneCode}';
    selectedCountryFlag = country.flagEmoji;
    // WidgetsBinding.instance.addPostFrameCallback((_) {
    //   mobileNumber.clear();
    // });
  }

  Future<String?> login(BuildContext context, {String? type}) async {
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
          if (type == 'basicInfo') {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder:
                    (context) =>
                        OtpScreens(mobileNumber: number, type: 'basicInfo'),
              ),
            );
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => OtpScreens(mobileNumber: number),
              ),
            );
          }

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
        (response) async {
          isGoogleLoading.value = false;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TermsScreen(type: 'googleSignIn'),
            ),
          );
          accessToken = response.data.token;
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('token', response.data.token);
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

  Future<void> logout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.clear();
    await prefs.remove('token');
    accessToken = '';

    CustomSnackBar.showSuccess("Logged out successfully");

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => LandingScreens()),
      (route) => false,
    );
  }

  Future<String?> emailLoginOtp(
    BuildContext context,
    String email, {
    String? type,
  }) async {
    isLoading.value = true;
    try {
      final results = await apiDataSource.emailLogin(email);
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
              builder:
                  (context) => OtpScreens(
                     emailVerify: 'Email',
                    mobileNumber: email,
                    type: 'basicInfo',
                    email: email,
                  ),
            ),
          );
          // Navigator.push(
          //   context,
          //   MaterialPageRoute(
          //     builder:
          //         (context) =>
          //             OtpScreens(mobileNumber: email, type: 'basicInfo'),
          //   ),
          // );

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

  void clearState() {
    accessToken = '';
    selectedCountryCode.value = '';
  }
}
