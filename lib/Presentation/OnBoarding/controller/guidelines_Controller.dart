import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../Core/Constants/log.dart';
import '../../../Core/Utility/snackbar.dart';
import '../models/guidelines_Models.dart';

import '../../../api/dataSource/apiDataSource.dart';

class GuidelinesController extends GetxController {
  final ApiDataSource apiDataSource = ApiDataSource();

  RxList<GuideLinesResponse> guidelinesList = <GuideLinesResponse>[].obs;
  RxBool isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    // guideLines();
    // Optionally fetch default type:
    // guideLines("nin-verification");
  }

  /// Fetches guidelines for a given type (e.g., "nin-verification")
  Future<String?> guideLines(String type) async {
    isLoading.value = true;
    try {
      final results = await apiDataSource.guideLines(type);

      return results.fold(
        (failure) {
          isLoading.value = false;
          CustomSnackBar.showError(failure.message);
          return failure.message;
        },
        (response) {
          isLoading.value = false;
          guidelinesList.clear();
          guidelinesList.add(response);
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
