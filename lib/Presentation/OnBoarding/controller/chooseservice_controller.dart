import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../Core/Constants/log.dart';
import '../../../Core/Utility/snackbar.dart';
import '../../../api/dataSource/apiDataSource.dart';
import '../../Authentication/screens/GetStarted_Screens.dart';
import '../models/getuserdetails_models.dart';
import '../screens/ConsentForms.dart';
import '../screens/basicInfo.dart';
import '../screens/carOwnerShip.dart';
import '../screens/chooseService.dart';
import '../screens/completedScreens.dart';
import '../screens/driverAddress.dart';
import '../screens/driverLicense.dart';
import '../screens/interiorUploadPhotos.dart';
import '../screens/ninScreens.dart';
import '../screens/profilePicAccess.dart';
import '../screens/uploadExteriorPhotos.dart';
import '../screens/vehicleDetails.dart';

class ChooseServiceController extends GetxController {
  ApiDataSource apiDataSource = ApiDataSource();
  Rxn<GetUserProfileModel> userProfile = Rxn<GetUserProfileModel>();
  RxBool isLoading = false.obs;
  RxBool isGetLoading = false.obs;
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
          await getUserDetails();
          isLoading.value = false;

          serviceType.value = response.serviceType;
          // CustomSnackBar.showSuccess(response.message);

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
    isGetLoading.value = true;

    try {
      final results = await apiDataSource.getUserDetails();
      return results.fold(
        (failure) {
          isGetLoading.value = false;
          // CustomSnackBar.showError(failure.message);
          return null;
        },
        (response) {
          isGetLoading.value = false;
          userProfile.value = response;
          CommonLogger.log.i(userProfile.value);
          CommonLogger.log.i(response);
          CommonLogger.log.i(response.landingPage);
          CommonLogger.log.i("Landing Page: ${userProfile.value?.landingPage}");
          return response;
        },
      );
    } catch (e) {
      isGetLoading.value = false;
      CustomSnackBar.showError("An error occurred");
      return null;
    }
  }

  void handleLandingPageNavigation(BuildContext context) {
    final landingPage = userProfile.value?.landingPage  ;

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
      case 14:
        Get.offAll(() => CompletedScreens());
        break;

      default:
        Get.offAll(() => GetStartedScreens());
    }
  }

  void clearState() {}
}
