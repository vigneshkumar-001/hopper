import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../Core/Utility/snackbar.dart';
import 'chooseservice_controller.dart';
import '../screens/ConsentForms.dart';
import '../screens/chooseService.dart';
import '../screens/driverLicense.dart';
import '../screens/interiorUploadPhotos.dart';
import '../screens/uploadExteriorPhotos.dart';
import '../../../api/dataSource/apiDataSource.dart';

class ExteriorImageController extends GetxController {
  String accessToken = '';
  ApiDataSource apiDataSource = ApiDataSource();
  RxBool isLoading = false.obs;
  String vehicleType = '';
  RxList<String?> _selectedImages = List<String?>.filled(6, null).obs;
  List<String?> get selectedImages => _selectedImages;

  @override
  void onInit() {
    super.onInit();
  }

  // Future<void> exteriorImageUpload({
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
  //
  //   }
  //
  //   if (uploadedUrls.length == selectedImages.where((e) => e != null).length) {
  //     final ninResult = await apiDataSource.uploadExteriorImage(
  //       imageUrls: uploadedUrls,
  //     );
  //
  //     ninResult.fold(
  //       (failure) {
  //         CustomSnackBar.showError(failure.message);
  //       },
  //       (success) {
  //         CustomSnackBar.showSuccess(success.message);
  //         if (selectedService == "Car") {
  //           Get.to(() => InteriorUploadPhotos());
  //         } else {
  //           Navigator.push(
  //             context,
  //             MaterialPageRoute(builder: (context) => ConsentForms()),
  //           );
  //         }
  //       },
  //     );
  //   }
  //
  //   isLoading.value = false;
  // }
  Future<void> exteriorImageUpload({
    required List<String?> selectedImages,
    required BuildContext context,
    required String serviceType,
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

    final profile = Get.find<ChooseServiceController>().userProfile.value;
    // final isCar = profile?.serviceType == 'Car';
    // final serviceType = isCar ? 'Car' : 'Bike';
    final isCar = vehicleType == 'Car';

    final serviceTypes = isCar ? 'Car' : 'Bike';
    final ninResult = await apiDataSource.uploadExteriorImage(
      imageUrls: uploadedUrls,
      serviceType: serviceType,
    );

    ninResult.fold(
      (failure) {
        CustomSnackBar.showError(failure.message);
      },
      (success) {
        // CustomSnackBar.showSuccess(success.message);
        // final selectedServices =
        //     Get.find<ChooseServiceController>()
        //         .userProfile
        //         .value
        //         ?.serviceType ??
        //     '';
        if (fromCompleteScreen) {
          Navigator.pop(context);
          return;
        }
        if (serviceTypes == "Car") {
          Get.to(() => InteriorUploadPhotos());
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => ConsentForms()),
          );
        }
      },
    );

    isLoading.value = false;
  }
  //
  // Future<void> fetchAndSetUserData() async {
  //   final profile = Get.find<ChooseServiceController>().userProfile.value;
  //
  //   if (profile != null && profile.carExteriorPhotos != null) {
  //     final vehicleType = profile.serviceType;
  //     if (vehicleType == 'Car') {
  //       final photos = profile.carExteriorPhotos!;
  //       for (int i = 0; i < photos.length && i < _selectedImages.length; i++) {
  //         _selectedImages[i] = photos[i];
  //       }
  //     } else {
  //       final photos = profile.bikePhotos!;
  //       for (int i = 0; i < photos.length && i < _selectedImages.length; i++) {
  //         _selectedImages[i] = photos[i];
  //       }
  //     }
  //   }
  // }

  Future<void> fetchAndSetUserData() async {
    final profile = Get.find<ChooseServiceController>().userProfile.value;

    if (profile == null) return;

    vehicleType = profile.serviceType ?? '';

    List<String>? photos;

    if (vehicleType == 'Car') {
      photos = profile.carExteriorPhotos;
    } else if (vehicleType == 'Bike') {
      photos = profile.bikePhotos;
    }

    if (photos != null) {
      for (int i = 0; i < photos.length && i < _selectedImages.length; i++) {
        _selectedImages[i] = photos[i];
      }
    }
  }
}
