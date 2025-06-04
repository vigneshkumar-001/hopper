import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hopper/Core/Constants/log.dart';

import 'package:hopper/Core/Utility/snackbar.dart';
import 'package:hopper/Presentation/Authentication/screens/GetStarted_Screens.dart';
import 'package:hopper/Presentation/OnBoarding/models/getuserdetails_models.dart';
import 'package:hopper/Presentation/OnBoarding/screens/ConsentForms.dart';
import 'package:hopper/Presentation/OnBoarding/screens/basicInfo.dart';
import 'package:hopper/Presentation/OnBoarding/screens/carOwnerShip.dart';

import 'package:hopper/Presentation/OnBoarding/screens/chooseService.dart';
import 'package:hopper/Presentation/OnBoarding/screens/completedScreens.dart';
import 'package:hopper/Presentation/OnBoarding/screens/driverAddress.dart';
import 'package:hopper/Presentation/OnBoarding/screens/driverLicense.dart';
import 'package:hopper/Presentation/OnBoarding/screens/interiorUploadPhotos.dart';
import 'package:hopper/Presentation/OnBoarding/screens/ninScreens.dart';
import 'package:hopper/Presentation/OnBoarding/screens/profilePicAccess.dart';
import 'package:hopper/Presentation/OnBoarding/screens/takePictureScreen.dart';
import 'package:hopper/Presentation/OnBoarding/screens/uploadExteriorPhotos.dart';
import 'package:hopper/Presentation/OnBoarding/screens/vehicleDetails.dart';
import 'package:hopper/api/dataSource/apiDataSource.dart';

class ChooseServiceController extends GetxController {
  ApiDataSource apiDataSource = ApiDataSource();
  Rxn<GetUserProfileModel> userProfile = Rxn<GetUserProfileModel>();
  RxBool isLoading = false.obs;
  RxString serviceType = ''.obs;

  @override
  void onInit() {
    super.onInit();
    getUserDetails();
  }

  Future<String?> chooseServiceType(String selectedService) async {
    isLoading.value = true;
    try {
      // final selectedService = userProfile.value?. serviceType ?? "";
      final results = await apiDataSource.chooseService(
        serviceType: selectedService,
      );

      return results.fold(
        (failure) {
          isLoading.value = false;
          CustomSnackBar.showError(failure.message);

          return failure.message; // from ServerFailure('...')
        },
        (response) async {
          isLoading.value = false;
          serviceType.value = response.serviceType;
          CustomSnackBar.showSuccess(response.message);
          Get.to(() => CarOwnership());

          return '';
        },
      );
    } catch (e) {
      isLoading.value = false;
      return 'An error occurred';
    }
  }

  Future<GetUserProfileModel?> getUserDetails() async {
    isLoading.value = true;

    try {
      final results = await apiDataSource.getUserDetails();
      return results.fold(
        (failure) {
          isLoading.value = false;
          // CustomSnackBar.showError(failure.message);
          return null;
        },
        (response) {
          isLoading.value = false;
          userProfile.value = response;
          CommonLogger.log.i(userProfile.value);
          CommonLogger.log.i(response);
          CommonLogger.log.i(response.landingPage);
          CommonLogger.log.i("Landing Page: ${userProfile.value?.landingPage}");
          return response;
        },
      );
    } catch (e) {
      isLoading.value = false;
      CustomSnackBar.showError("An error occurred");
      return null;
    }
  }

  void handleLandingPageNavigation(BuildContext context) {
    final landingPage = userProfile.value?.landingPage ?? 0;

    switch (landingPage) {
      case 0:
        Get.offAll(() => BasicInfo());
        break;
      case 2:
        Get.offAll(() => DriverAddress());
        break;
      case 3:
        Get.offAll(() => ProfilePicAccess());
        break;
      case 4:
        Get.offAll(() => NinScreens());
        break;
      case 5:
        Get.offAll(() => NinScreens());
        break;
      case 6:
        Get.offAll(() => DriverLicense());
        break;
      case 7:
        Get.offAll(() => ChooseService());
        break;
      case 8:
        Get.offAll(() => CarOwnership());
        break;
      case 9:
        Get.offAll(() => VehicleDetails());
        break;
      case 10:
        Get.offAll(() => UploadExteriorPhotos());
        break;
      case 11:
        Get.offAll(() => InteriorUploadPhotos());
        break;
      case 12:
        Get.offAll(() => ConsentForms());
        break;
      case 13:
        Get.offAll(() => CompletedScreens());
        break;

      default:
        Get.offAll(() => GetStartedScreens());
    }
  }

  void clearState() {}
}
