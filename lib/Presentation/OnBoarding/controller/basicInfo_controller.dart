import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../Core/Constants/log.dart';
import '../../../Core/Utility/snackbar.dart';
import '../../Authentication/controller/authController.dart';
import 'chooseservice_controller.dart';
import '../screens/driverAddress.dart';
import '../../../api/dataSource/apiDataSource.dart';
import '../../../api/repository/failure.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BasicInfoController extends GetxController {
  TextEditingController name = TextEditingController();
  TextEditingController lastName = TextEditingController();
  TextEditingController dobController = TextEditingController();
  TextEditingController genderController = TextEditingController();
  TextEditingController emailController = TextEditingController();
  TextEditingController mobileNumber = TextEditingController();
  String accessToken = '';
  String serviceType = '';
  ApiDataSource apiDataSource = ApiDataSource();
  RxBool isLoading = false.obs;
  final ChooseServiceController getData = Get.find();
  @override
  void onInit() {
    super.onInit();
    fetchAndSetUserData();
  }

  Future<String?> basicInfo(
    BuildContext context,
    String countryCode,
    String mobileNumber, {
    bool fromCompleteScreen = false,
  }) async {
    isLoading.value = true;
    try {
      final results = await apiDataSource.basicInfo(
        dateOfBirth: dobController.text.trim(),
        email: emailController.text.trim(),
        gender: genderController.text.trim(),
        mobileNumber: mobileNumber,
        name: name.text.trim(),
        lastName: lastName.text.trim(),
        countryCode: countryCode,
      );

      return results.fold(
        (failure) {
          isLoading.value = false;
          // APi issues so here iam navigating
          // Navigator.push(
          //   context,
          //   MaterialPageRoute(builder: (context) => DriverAddress()),
          // );
          CustomSnackBar.showError(failure.message);

          return failure.message; // from ServerFailure('...')
        },
        (response) async {
          isLoading.value = false;
          CustomSnackBar.showSuccess(response.message);
          if (fromCompleteScreen) {
            Navigator.pop(context);
          } else {
            Get.to(() => DriverAddress());
          }
          // Navigator.push(
          //   context,
          //   MaterialPageRoute(builder: (context) => DriverAddress()),
          // );

          return '';
        },
      );
    } catch (e) {
      isLoading.value = false;
      return 'An error occurred';
    }
  }

  Future<void> fetchAndSetUserData() async {
    final profile = Get.find<ChooseServiceController>().userProfile.value;

    if (profile != null) {
      name.text = profile.firstName ?? '';
      lastName.text = profile.lastName ?? '';
      dobController.text = profile.dob ?? '';
      genderController.text = profile.gender ?? '';
      emailController.text = profile.email ?? '';
      serviceType = profile.serviceType ?? '';
    }
    //else {
    //   // If no profile data, keep fields empty (fresh insert)
    //   name.clear();
    //   lastName.clear();
    //   dobController.clear();
    //   genderController.clear();
    //   emailController.clear();
    //   mobileNumber.clear();
    // }
    update();
  }

  void clearState() {
    mobileNumber.clear();
    name.clear();
  }
}
