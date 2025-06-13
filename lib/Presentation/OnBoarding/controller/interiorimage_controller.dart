import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../Core/Utility/snackbar.dart';
import '../../../api/dataSource/apiDataSource.dart';
import '../screens/ConsentForms.dart';
import 'chooseservice_controller.dart';

class InteriorImageController extends GetxController {
  String accessToken = '';
  ApiDataSource apiDataSource = ApiDataSource();
  RxBool isLoading = false.obs;
  RxList<String?> _selectedImages = List<String?>.filled(6, null).obs;
  List<String?> get selectedImages => _selectedImages;

  @override
  void onInit() {
    super.onInit();
    fetchAndSetUserData();
  }

  Future<void> interiorImageUpload({
    required List<String?> selectedImages,
    required BuildContext context,
    bool fromCompleteScreen = false,
  }) async {
    isLoading.value = true;

    List<String> uploadedUrls = [];

    for (int i = 0; i < selectedImages.length; i++) {
      final pathOrUrl = selectedImages[i];

      if (pathOrUrl == null || pathOrUrl.isEmpty) {
        // Missing image error
        CustomSnackBar.showError("Please upload all required images.");
        isLoading.value = false;
        return;
      }

      if (pathOrUrl.startsWith('http')) {
        // Already uploaded URL, add as-is
        uploadedUrls.add(pathOrUrl);
      } else {
        // Local file path, upload it
        final result = await apiDataSource.userProfileUpload(
          imageFile: File(pathOrUrl),
        );

        final url = result.fold((failure) {
          CustomSnackBar.showError(
            "Upload failed for image ${i + 1}: ${failure.message}",
          );
          return null;
        }, (success) => success.message);

        if (url == null) {
          isLoading.value = false;
          return; // Stop on failure
        }
        uploadedUrls.add(url);
      }
    }

    final ninResult = await apiDataSource.uploadInteriorImage(
      imageUrls: uploadedUrls,
    );

    ninResult.fold(
      (failure) {
        CustomSnackBar.showError(failure.message);
      },
      (success) {
        // CustomSnackBar.showSuccess(success.message);
        if (fromCompleteScreen) {
          Navigator.pop(context);
        } else {
          Get.to(() => ConsentForms());
        }
        // Navigator.push(
        //   context,
        //   MaterialPageRoute(builder: (context) => ConsentForms()),
        // );
      },
    );

    isLoading.value = false;
  }

  Future<void> fetchAndSetUserData() async {
    final profile = Get.find<ChooseServiceController>().userProfile.value;

    if (profile != null && profile.carInteriorPhotos != null) {
      final photos = profile.carInteriorPhotos!;
      for (int i = 0; i < photos.length && i < _selectedImages.length; i++) {
        _selectedImages[i] = photos[i];
      }
    }
  }
}
