import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hopper/Core/Utility/snackbar.dart';
import 'package:hopper/Presentation/OnBoarding/controller/chooseservice_controller.dart';
import 'package:hopper/Presentation/OnBoarding/screens/ConsentForms.dart';
import 'package:hopper/api/dataSource/apiDataSource.dart';

class InteriorImageController extends GetxController {
  String accessToken = '';
  ApiDataSource apiDataSource = ApiDataSource();
  RxBool isLoading = false.obs;
  final RxList<String?> _selectedImages = List<String?>.filled(6, null).obs;
  List<String?> get selectedImages => _selectedImages;

  @override
  void onInit() {
    super.onInit();
    fetchAndSetUserData();
  }

  // Future<void> interiorImageUpload({
  //   required List<String?> selectedImages,
  //   required BuildContext context,
  // })
  // async {
  //   isLoading.value = true;
  //
  //   List<String> uploadedUrls = [];
  //
  //   for (int i = 0; i < selectedImages.length; i++) {
  //     final path = selectedImages[i];
  //     if (path != null) {
  //       final result = await apiDataSource.userProfileUpload(
  //         imageFile: File(path),
  //       );
  //
  //       final url = result.fold((failure) {
  //         CustomSnackBar.showError(
  //           "Upload failed for image ${i + 1}: ${failure.message}",
  //         );
  //         return null;
  //       }, (success) => success.message);
  //
  //       if (url != null) {
  //         uploadedUrls.add(url);
  //       }
  //     }
  //   }
  //
  //   if (uploadedUrls.length == selectedImages.where((e) => e != null).length) {
  //     final ninResult = await apiDataSource.uploadInteriorImage(
  //       imageUrls: uploadedUrls,
  //     );
  //
  //     ninResult.fold(
  //       (failure) {
  //         CustomSnackBar.showError(failure.message);
  //       },
  //       (success) {
  //         CustomSnackBar.showSuccess(success.message);
  //         Get.to(() => ConsentForms());
  //       },
  //     );
  //   }
  //
  //   isLoading.value = false;
  // }

  Future<void> interiorImageUpload({
    required List<String?> selectedImages,
    required BuildContext context,
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

    // Upload all URLs to backend
    final ninResult = await apiDataSource.uploadInteriorImage(
      imageUrls: uploadedUrls,
    );

    ninResult.fold(
      (failure) {
        CustomSnackBar.showError(failure.message);
      },
      (success) {
        CustomSnackBar.showSuccess(success.message);

        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => ConsentForms()),
        );
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
