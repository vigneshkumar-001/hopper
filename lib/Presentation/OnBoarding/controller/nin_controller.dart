import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hopper/Core/Utility/snackbar.dart';
import 'package:hopper/Presentation/OnBoarding/controller/chooseservice_controller.dart';
import 'package:hopper/Presentation/OnBoarding/screens/driverLicense.dart';
import 'package:hopper/api/dataSource/apiDataSource.dart';

class NinController extends GetxController {
  String accessToken = '';
  ApiDataSource apiDataSource = ApiDataSource();
  RxString frontImageUrl = ''.obs;
  RxString backImageUrl = ''.obs;

  RxBool isLoading = false.obs;
  TextEditingController ninNumberController = TextEditingController();
  @override
  void onInit() {
    super.onInit();
    fetchAndSetUserData();
  }
  //
  // Future<void> ninScreen(
  //   BuildContext context,
  //   File frontImageFile,
  //   File backImageFile,
  // )
  // async {
  //   isLoading.value = true;
  //
  //   final frontResult = await apiDataSource.userProfileUpload(
  //     imageFile: frontImageFile,
  //   );
  //   final backResult = await apiDataSource.userProfileUpload(
  //     imageFile: backImageFile,
  //   );
  //
  //   final frontImageUrl = frontResult.fold((failure) {
  //     CustomSnackBar.showError("Front Upload Failed: ${failure.message}");
  //     return null;
  //   }, (success) => success.message);
  //
  //   final backImageUrl = backResult.fold((failure) {
  //     CustomSnackBar.showError("Back Upload Failed: ${failure.message}");
  //     return null;
  //   }, (success) => success.message);
  //
  //   if (frontImageUrl != null && backImageUrl != null) {
  //     final ninResult = await apiDataSource.ninVerification(
  //       ninNumber: ninNumberController.text.trim(),
  //       frontImage: frontImageUrl,
  //       backImage: backImageUrl,
  //     );
  //
  //     ninResult.fold(
  //       (failure) {
  //         CustomSnackBar.showError(failure.message);
  //       },
  //       (success) {
  //         CustomSnackBar.showSuccess(success.message);
  //         Navigator.push(
  //           context,
  //           MaterialPageRoute(builder: (_) => DriverLicense()),
  //         );
  //       },
  //     );
  //   }
  //
  //   isLoading.value = false;
  // }

  Future<void> ninScreen(
    BuildContext context,
    File? frontImageFile,
    File? backImageFile,
  )
  async {
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

    final ninResult = await apiDataSource.ninVerification(
      ninNumber: ninNumberController.text.trim(),
      frontImage: frontImageUrl,
      backImage: backImageUrl,
    );

    ninResult.fold(
      (failure) {
        CustomSnackBar.showError(failure.message);
      },
      (success) {
        CustomSnackBar.showSuccess(success.message);
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => DriverLicense()),
        );
      },
    );

    isLoading.value = false;
  }

  Future<void> fetchAndSetUserData() async {
    final profile = Get.find<ChooseServiceController>().userProfile.value;

    if (profile != null) {
      ninNumberController.text = profile.nationalIdNumber ?? '';
      frontImageUrl.value = profile.frontIdCardNin ?? '';
      backImageUrl.value = profile.backIdCardNin ?? '';
    } else {
      ninNumberController.clear();
    }
  }
}
