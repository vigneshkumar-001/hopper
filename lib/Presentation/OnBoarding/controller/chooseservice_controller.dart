import 'package:get/get.dart';
import 'package:flutter/widgets.dart';

import '../../../Core/Constants/log.dart';
import '../../../Core/Utility/snackbar.dart';
import '../../../api/dataSource/apiDataSource.dart';
import '../../Authentication/screens/GetStarted_Screens.dart';
import '../../DriverScreen/screens/driver_main_screen.dart';
import 'package:hopper/Presentation/OnBoarding/models/getuserdetails_models.dart';
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
  var formStatus = 0.obs;
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
          formStatus.value = response.formStatus ?? 0;
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

  void handleLandingPageNavigation({bool clearStack = true}) {
    final landingPage = userProfile.value?.landingPage;
    final formStatus = userProfile.value?.formStatus;

    if (formStatus == 3) {
      if (clearStack) {
        Get.offAll(() => DriverMainScreen());
      } else {
        Get.off(() => DriverMainScreen());
      }
      return;
    }

    void goTo(Widget Function() page) {
      if (clearStack) {
        Get.offAll(page);
      } else {
        Get.off(page);
      }
    }

    switch (landingPage) {
      case 0:
        goTo(() => BasicInfo());
        break;
      case 2:
        goTo(() => DriverAddress());
        break;
      case 3:
        goTo(() => ProfilePicAccess());
        break;
      case 4:
        goTo(() => NinScreens());
        break;
      case 5:
        goTo(() => NinScreens());
        break;
      case 6:
        goTo(() => DriverLicense());
        break;
      case 7:
        goTo(() => ChooseService());
        break;
      case 8:
        goTo(() => CarOwnership());
        break;
      case 9:
        goTo(() => VehicleDetails());
        break;
      case 10:
        goTo(() => UploadExteriorPhotos());
        break;
      case 11:
        goTo(() => InteriorUploadPhotos());
        break;
      case 12:
        goTo(() => ConsentForms());
        break;
      case 13:
        goTo(() => CompletedScreens());
        break;
      default:
        goTo(() => GetStartedScreens());
    }
  }

  // void handleLandingPageNavigation( ) {
  //   CommonLogger.log.i('iam in handleLandingPageNavigation');
  //   final landingPage = userProfile.value?.landingPage;
  //   final formStatus = userProfile.value?.formStatus;
  //   CommonLogger.log.i('${landingPage}  ${formStatus}');
  //
  //   // Highest priority: formStatus = 3 → DriverMainScreen
  //   if (formStatus == 3) {
  //     Get.offAll(() => DriverMainScreen());
  //     return;
  //   }
  //   switch (landingPage) {
  //     case 0:
  //       Get.offAll(() => BasicInfo());
  //       break;
  //     case 2:
  //       Get.offAll(() => DriverAddress());
  //       break;
  //     case 3:
  //       Get.offAll(() => ProfilePicAccess());
  //       break;
  //     case 4:
  //       Get.offAll(() => NinScreens());
  //       break;
  //     case 5:
  //       Get.offAll(() => NinScreens());
  //       break;
  //     case 6:
  //       Get.offAll(() => DriverLicense());
  //       break;
  //     case 7:
  //       Get.offAll(() => ChooseService());
  //       break;
  //     case 8:
  //       Get.offAll(() => CarOwnership());
  //       break;
  //     case 9:
  //       Get.offAll(() => VehicleDetails());
  //       break;
  //     case 10:
  //       Get.offAll(() => UploadExteriorPhotos());
  //       break;
  //     case 11:
  //       Get.offAll(() => InteriorUploadPhotos());
  //       break;
  //     case 12:
  //       Get.offAll(() => ConsentForms());
  //       break;
  //     case 13:
  //       Get.offAll(() => CompletedScreens());
  //       break;
  //
  //     default:
  //       Get.offAll(() => GetStartedScreens());
  //   }
  // }

  void clearState() {}
}

