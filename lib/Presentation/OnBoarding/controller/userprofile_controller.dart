import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hopper/Core/Constants/log.dart';

import 'package:hopper/Core/Utility/snackbar.dart';
import 'package:hopper/Presentation/OnBoarding/screens/docUploadPic.dart';
import 'package:hopper/Presentation/OnBoarding/screens/ninScreens.dart';

import 'package:hopper/api/dataSource/apiDataSource.dart';

class UserProfileController extends GetxController {
  String accessToken = '';
  ApiDataSource apiDataSource = ApiDataSource();
  RxBool isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
  }

  Future<String?> userProfileUpload(
    BuildContext context,
    File imageFile,
      {
        bool fromCompleteScreen = false,
      }
  ) async {
    isLoading.value = true;

    final frontResult = await apiDataSource.userProfileUpload(
      imageFile: imageFile,
    );

    final frontImageUrl = frontResult.fold((failure) {
      CustomSnackBar.showError("Front Upload Failed: ${failure.message}");
      return null;
    }, (success) => success.message);

    if (frontImageUrl != null) {
      final ninResult = await apiDataSource.userImageUpload(
        frontImage: frontImageUrl,
      );

      ninResult.fold(
        (failure) {
          CustomSnackBar.showError(failure.message);
        },
        (success) {
          CustomSnackBar.showSuccess(success.message);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => NinScreens()),
          );
        },
      );
    }

    isLoading.value = false;
    return null;
  }
}
