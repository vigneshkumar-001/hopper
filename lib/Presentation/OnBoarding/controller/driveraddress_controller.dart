import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../Core/Utility/snackbar.dart';
import 'chooseservice_controller.dart';
import '../screens/docUploadPic.dart';

import '../../../api/dataSource/apiDataSource.dart';

class DriverAddressController extends GetxController {
  TextEditingController addressController = TextEditingController();
  TextEditingController cityController = TextEditingController();
  TextEditingController stateController = TextEditingController();
  TextEditingController postController = TextEditingController();

  String accessToken = '';
  ApiDataSource apiDataSource = ApiDataSource();
  RxBool isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    fetchAndSetUserData();
  }

  Future<String?> driverDetails(
    BuildContext context, {
    bool fromCompleteScreen = false,
  }) async {
    isLoading.value = true;
    try {
      final results = await apiDataSource.driverAddress(
        address: addressController.text.trim(),
        city: cityController.text.trim(),
        state: stateController.text.trim(),

        postCode: postController.text.trim(),
      );

      return results.fold(
        (failure) {
          // APi issues so here iam navigating
          // Navigator.push(
          //   context,
          //   MaterialPageRoute(builder: (context) => DocUpLoadPic()),
          // );
          isLoading.value = false;
          CustomSnackBar.showError(failure.message);

          return failure.message; // from ServerFailure('...')
        },
        (response) async {
          isLoading.value = false;
          // CustomSnackBar.showSuccess(response.message);
          if (fromCompleteScreen) {
            Navigator.pop(context);
          } else {
            Get.to(() => DocUpLoadPic());
          }

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
      addressController.text = profile.address ?? '';
      cityController.text = profile.city ?? '';
      stateController.text = profile.state ?? '';
      postController.text = profile.postalCode ?? '';
    } else {
      addressController.clear();
      cityController.clear();
      stateController.clear();
      postController.clear();
    }
  }

  void clearState() {}
}
