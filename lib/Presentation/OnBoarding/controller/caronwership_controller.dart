import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../Core/Constants/log.dart';
import '../../../Core/Utility/snackbar.dart';
import 'chooseservice_controller.dart';
import '../screens/chooseService.dart';
import '../screens/vehicleDetails.dart';
import '../../../api/dataSource/apiDataSource.dart';
import 'dart:async';

class CarOwnerShipController extends GetxController {
  ApiDataSource apiDataSource = ApiDataSource();
  String serviceType = '';
  String countryCode = '';
  RxBool isLoading = false.obs;
  late Timer _timer;
  TextEditingController carOwnershipController = TextEditingController();
  TextEditingController carOwnerNameController = TextEditingController();
  TextEditingController carPlateNumberController = TextEditingController();

  // Bike
  TextEditingController bikeOwnershipController = TextEditingController();
  TextEditingController bikeOwnerNameController = TextEditingController();
  TextEditingController bikePlateNumberController = TextEditingController();
  @override
  void onInit() {
    super.onInit();

    fetchAndSetUserData();
    // Fetch repeatedly every 2 seconds
  }

  @override
  void onClose() {
    _timer.cancel();
    super.onClose();
  }

  Future<String?> carOwnerShip(
    BuildContext context,
    String serviceTypes, {
    bool fromCompleteScreen = false,
  }) async {
    isLoading.value = true;
    final profile = Get.find<ChooseServiceController>().userProfile.value;
    final isCar = serviceType == 'Car';
    try {
      final results = await apiDataSource.carOwnerShip(
        serviceType: serviceType,
        carOwnerName:
            isCar
                ? carOwnerNameController.text.trim()
                : bikeOwnerNameController.text.trim(),
        carOwnerPlateNumber:
            isCar
                ? carPlateNumberController.text.trim()
                : bikePlateNumberController.text.trim(),
        carOwnership:
            isCar
                ? carOwnershipController.text.trim()
                : bikeOwnershipController.text.trim(),
      );
      CommonLogger.log.i(results);
      return results.fold(
        (failure) {
          isLoading.value = false;
          CustomSnackBar.showError(failure.message);
          return failure.message;
        },
        (response) async {
          isLoading.value = false;
          CustomSnackBar.showSuccess(response.message);
          if (fromCompleteScreen) {
            Navigator.pop(context);
          } else {
            Get.to(() => VehicleDetails());
          }
          // Navigator.push(
          //   context,
          //   MaterialPageRoute(builder: (context) => VehicleDetails()),
          // );

          return '';
        },
      );
    } catch (e) {
      isLoading.value = false;
      return 'An error occurred';
    }
  }

  // Future<void> fetchAndSetUserData() async {
  //   final profile = Get.find<ChooseServiceController>().userProfile.value;
  //
  //   if (profile != null) {
  //     ownerShip.text = profile.carOwnership ?? '';
  //     ownerName.text = profile.carOwnerName ?? '';
  //     carPlateNumber.text = profile.carPlateNumber ?? '';
  //   } else {
  //     ownerShip.clear();
  //     ownerName.clear();
  //     carPlateNumber.clear();
  //   }
  // }

  Future<void> fetchAndSetUserData() async {
    final profile = Get.find<ChooseServiceController>().userProfile.value;

    if (profile != null) {
      serviceType = profile.serviceType ?? '';
      countryCode = profile.countryCode ?? '';
      CommonLogger.log.i(serviceType);
      if (profile.serviceType == 'Car') {
        carOwnershipController.text = profile.carOwnership ?? '';
        carOwnerNameController.text = profile.carOwnerName ?? '';
        carPlateNumberController.text = profile.carPlateNumber ?? '';
      } else {
        bikeOwnershipController.text = profile.bikeOwnership ?? '';
        bikeOwnerNameController.text = profile.bikeOwnerName ?? '';
        bikePlateNumberController.text = profile.bikePlateNumber ?? '';
      }
    } else {
      carOwnershipController.clear();
      carOwnerNameController.clear();
      carPlateNumberController.clear();
      bikeOwnershipController.clear();
      bikeOwnerNameController.clear();
      bikePlateNumberController.clear();
    }

    isLoading.value = false;
  }

  void clearState() {
    carOwnershipController.clear();
    carOwnerNameController.clear();
    carPlateNumberController.clear();
    bikeOwnershipController.clear();
    bikeOwnerNameController.clear();
    bikePlateNumberController.clear();
  }
}
