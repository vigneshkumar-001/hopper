import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hopper/Core/Constants/log.dart';
import 'package:country_picker/country_picker.dart';

import 'package:hopper/Core/Utility/snackbar.dart';
import 'package:hopper/Presentation/Authentication/screens/Landing_Screens.dart';
import 'package:hopper/Presentation/Authentication/screens/Otp_Screens.dart';
import 'package:hopper/Presentation/Authentication/screens/Terms_Screen.dart';
import 'package:hopper/api/dataSource/apiDataSource.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hopper/utils/map/navigation_assist.dart';
import 'package:hopper/utils/session/logout_cleanup.dart';

var getMobileNumber = '';
var countryCodes = '';
String selectedCountryFlag = '';

// Default to India (matches your primary driver market UI)
const String kDefaultCountryCode = '+91';
const String kDefaultCountryFlagEmoji = '\u{1F1EE}\u{1F1F3}'; // 🇮🇳

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

  bool isValidEmail(String input) {
    final email = input.trim();
    if (email.isEmpty) return false;
    // Simple, strict-enough validation for user input (no spaces, has @ and domain).
    final emailRegex = RegExp(r'^[\w\.\-\+]+@([\w\-]+\.)+[\w\-]{2,}$');
    return emailRegex.hasMatch(email);
  }

  void resetPhoneInputToDefault({bool clearMobileNumber = true}) {
    selectedCountryCode.value = kDefaultCountryCode;
    countryCodeController.text = kDefaultCountryCode;
    selectedCountryFlag = kDefaultCountryFlagEmoji;
    errorText.value = '';
    if (clearMobileNumber) {
      mobileNumber.clear();
    }
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
          // CustomSnackBar.showSuccess(response.message.toString());
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
          // CustomSnackBar.showSuccess(response.message.toString());

          return ' ';
        },
      );
    } catch (e) {
      isGoogleLoading.value = false;
      return ' ';
    }

    isGoogleLoading.value = false;
    return '';
  }

  Future<void> logout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    // Try to call logout API before clearing token; never block UI too long.
    try {
      await apiDataSource
          .logout(token: token)
          .timeout(const Duration(seconds: 2));
    } catch (_) {}

    await performLogoutCleanup();
    await prefs.clear();
    if (Get.isRegistered<DriverAnalyticsController>()) {
      await Get.find<DriverAnalyticsController>().reset(clearPersisted: false);
    }
    accessToken = '';

    if (!context.mounted) return;
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
    final trimmed = email.trim();
    if (trimmed.isEmpty) {
      CustomSnackBar.showError('Please enter your email address');
      return '';
    }
    if (!isValidEmail(trimmed)) {
      CustomSnackBar.showError('Please enter a valid email address');
      return '';
    }

    isLoading.value = true;
    try {
      final results = await apiDataSource.emailLogin(trimmed);
      results.fold(
        (failure) {
          CustomSnackBar.showError(failure.message);
          isLoading.value = false;

          return '';
        },
        (response) {
          // CustomSnackBar.showSuccess(response.message.toString());
          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (context) => OtpScreens(
                    emailVerify: 'Email',
                    mobileNumber: trimmed,
                    type: 'basicInfo',
                    email: trimmed,
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
