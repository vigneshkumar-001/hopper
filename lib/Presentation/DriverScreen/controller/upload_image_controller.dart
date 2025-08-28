import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hopper/api/dataSource/apiDataSource.dart';
import '../../../Core/Utility/snackbar.dart';

class UploadImageController extends GetxController {
  final ApiDataSource apiDataSource = ApiDataSource();

  RxBool isLoading = false.obs;
  RxString frontImageUrl = ''.obs;

  Future<void> uploadImage(
      BuildContext context,
      File? frontImageFile,
      ) async {
    isLoading.value = true;

    String? uploadedUrl;

    if (frontImageFile != null) {
      // Upload new image
      final frontResult = await apiDataSource.userProfileUpload(
        imageFile: frontImageFile,
      );

      uploadedUrl = frontResult.fold(
            (failure) {
          CustomSnackBar.showError("Front Upload Failed: ${failure.message}");
          return null;
        },
            (success) => success.message,
      );

      if (uploadedUrl == null) {
        isLoading.value = false;
        return;
      }
    } else {
      // Use existing URL if no new file
      uploadedUrl = frontImageUrl.value.isNotEmpty ? frontImageUrl.value : null;
    }

    if (uploadedUrl != null) {
      frontImageUrl.value = uploadedUrl;
    }

    isLoading.value = false;
  }
}
