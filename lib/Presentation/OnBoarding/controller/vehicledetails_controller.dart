import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hopper/Core/Utility/snackbar.dart';
import 'package:hopper/Presentation/OnBoarding/controller/chooseservice_controller.dart';
import 'package:hopper/Presentation/OnBoarding/screens/uploadExteriorPhotos.dart';
import 'package:hopper/api/dataSource/apiDataSource.dart';

class VehicleDetailsController extends GetxController {
  String accessToken = '';
  ApiDataSource apiDataSource = ApiDataSource();
  RxBool isLoading = false.obs;
  RxString frontImageUrl = ''.obs;
  RxString backImageUrl = ''.obs;

  final TextEditingController carBrandController = TextEditingController();
  final TextEditingController carModelController = TextEditingController();
  final TextEditingController carYearController = TextEditingController();
  final TextEditingController carColorController = TextEditingController();
  final TextEditingController registrationController = TextEditingController();

  @override
  void onInit() {
    super.onInit();
    fetchAndSetUserData();
  }

  Future<void> vehicleDetails({
    required File frontImageFile,
    required String serviceType,
    required File backImageFile,
    required BuildContext context,
  }) async {
    isLoading.value = true;
    String? frontImageUrl;
    String? backImageUrl;

    final profile = Get.find<ChooseServiceController>().userProfile.value;
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
    final isCar = serviceType == 'Car';

    final serviceTypes = isCar ? 'Car' : 'Bike';

    final ninResult = await apiDataSource.vehicleDetails(
      serviceType: serviceTypes,
      backImageFile: backImageUrl,
      carBrand: carBrandController.text.trim(),
      carColor: carColorController.text.trim(),
      carModel: carModelController.text.trim(),
      carYear: carYearController.text.trim(),
      frontImageFile: frontImageUrl,
      registerNumber: registrationController.text.trim(),
    );

    ninResult.fold(
      (failure) {
        CustomSnackBar.showError(failure.message);
      },
      (success) {
        CustomSnackBar.showSuccess(success.message);
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => UploadExteriorPhotos()),
        );
      },
    );

    isLoading.value = false;
  }

  // Future<void> fetchAndSetUserData() async {
  //   final profile = Get.find<ChooseServiceController>().userProfile.value;
  //
  //   if (profile != null) {
  //     carBrandController.text = profile.carBrand ?? '';
  //     carModelController.text = profile.carModel ?? '';
  //     carYearController.text = profile.carYear ?? '';
  //     carColorController.text = profile.carColor ?? '';
  //     frontImageUrl.value = profile.carRoadWorthinessCertificate ?? '';
  //     backImageUrl.value = profile.carInsuranceDocument ?? '';
  //   } else {
  //     carBrandController.clear();
  //     carModelController.clear();
  //     carYearController.clear();
  //   }
  // }

  Future<void> fetchAndSetUserData() async {
    final profile = Get.find<ChooseServiceController>().userProfile.value;

    if (profile != null) {
      final vehicleType = profile.serviceType;

      if (vehicleType == 'Car') {
        carBrandController.text = profile.carBrand ?? '';
        carModelController.text = profile.carModel ?? '';
        carYearController.text = (profile.carYear ?? '').toString();
        carColorController.text = profile.carColor ?? '';
        registrationController.text = profile.carRegistrationNumber ?? '';
        frontImageUrl.value = profile.carRoadWorthinessCertificate ?? '';
        backImageUrl.value = profile.carInsuranceDocument ?? '';
      } else if (vehicleType == 'Bike') {
        carBrandController.text = profile.bikeBrand ?? '';
        carModelController.text = profile.bikeModel ?? '';
        carYearController.text = (profile.bikeYear ?? '').toString();
        carColorController.text = profile.carColor ?? '';
        registrationController.text = profile.bikeRegistrationNumber ?? '';
        frontImageUrl.value = profile.bikeRoadWorthinessCertificate ?? '';
        backImageUrl.value = profile.bikeInsuranceDocument ?? '';
      }
    } else {
      carBrandController.clear();
      carModelController.clear();
      carYearController.clear();
      carColorController.clear();
      registrationController.clear();
    }
  }
}
