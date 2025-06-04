import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hopper/Core/Constants/log.dart';
import 'package:hopper/Core/Utility/snackbar.dart';
import 'package:hopper/Presentation/OnBoarding/models/guidelines_Models.dart';

import 'package:hopper/api/dataSource/apiDataSource.dart';

class GuidelinesController extends GetxController {
  final ApiDataSource apiDataSource = ApiDataSource();

  RxList<GuideLinesResponse> guidelinesList = <GuideLinesResponse>[].obs;
  RxBool isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    guideLines();
    // Optionally fetch default type:
    // guideLines("nin-verification");
  }

  /// Fetches guidelines for a given type (e.g., "nin-verification")
  Future<String?> guideLines() async {
    isLoading.value = true;
    try {
      final results = await apiDataSource.guideLines('profile-pic');

      return results.fold(
        (failure) {
          isLoading.value = false;
          CustomSnackBar.showError(failure.message);
          return failure.message;
        },
        (response) {
          guidelinesList.clear();
          guidelinesList.add(response);
          return null;
        },
      );
    } catch (e) {
      isLoading.value = false;
      CustomSnackBar.showError("An error occurred");
      CommonLogger.log.e("Exception: $e");
      return "An error occurred";
    }
  }

  void clearState() {
    guidelinesList.clear();
  }
}
