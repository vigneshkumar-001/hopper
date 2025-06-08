import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../Core/Utility/snackbar.dart';
import 'chooseservice_controller.dart';
import '../screens/carOwnerShip.dart';
import '../screens/chooseService.dart';
import '../screens/driverLicense.dart';
import '../../../api/dataSource/apiDataSource.dart';

class DriverLicenseController extends GetxController {
  String accessToken = '';
  ApiDataSource apiDataSource = ApiDataSource();
  final TextEditingController driverLicenseController = TextEditingController();
  RxBool isLoading = false.obs;
  RxString frontImageUrl = ''.obs;
  RxString backImageUrl = ''.obs;

  @override
  void onInit() {
    super.onInit();
    fetchAndSetUserData();
  }

  Future<void> driverLicense(
    BuildContext context,
    File? frontImageFile,
    File? backImageFile, {
    bool fromCompleteScreen = false,
  }) async {
    isLoading.value = true;

    String? frontImageUrl;
    String? backImageUrl;

    if (frontImageFile != null) {
      final frontResult = await apiDataSource.userProfileUpload(
        imageFile: frontImageFile,
      );

      frontImageUrl = frontResult.fold((failure) {
        CustomSnackBar.showError("Front Upload Failed: ${failure.message}");
        return null;
      }, (success) => success.message);

      if (frontImageUrl == null) {
        isLoading.value = false;
        return;
      }
    } else {
      // Use existing URL if no new file
      frontImageUrl = this.frontImageUrl.value;
    }

    if (backImageFile != null) {
      final backResult = await apiDataSource.userProfileUpload(
        imageFile: backImageFile,
      );

      backImageUrl = backResult.fold((failure) {
        CustomSnackBar.showError("Back Upload Failed: ${failure.message}");
        return null;
      }, (success) => success.message);

      if (backImageUrl == null) {
        isLoading.value = false;
        return;
      }
    } else {
      backImageUrl = this.backImageUrl.value;
    }

    final ninResult = await apiDataSource.driverLicense(
      licenseNumber: driverLicenseController.text.trim(),
      frontImage: frontImageUrl,
      backImage: backImageUrl,
    );

    ninResult.fold(
      (failure) {
        CustomSnackBar.showError(failure.message);
      },
      (success) {
        CustomSnackBar.showSuccess(success.message);
        if (fromCompleteScreen) {
          Navigator.pop(context);
        } else {
          Get.to(() => ChooseService());
        }
        // Navigator.push(
        //   context,
        //   MaterialPageRoute(builder: (context) => ChooseService()),
        // );
      },
    );

    isLoading.value = false;
  }

  Future<void> fetchAndSetUserData() async {
    final profile = Get.find<ChooseServiceController>().userProfile.value;

    if (profile != null) {
      driverLicenseController.text = profile.driverLicenseNumber ?? '';
      frontImageUrl.value = profile.frontIdCardDln ?? '';
      backImageUrl.value = profile.backIdCardDln ?? '';
    } else {
      driverLicenseController.clear();
    }
  }
}
