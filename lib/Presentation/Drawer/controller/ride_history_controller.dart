import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hopper/Core/Constants/log.dart';
import 'package:country_picker/country_picker.dart';

import 'package:hopper/Core/Utility/snackbar.dart';
import 'package:hopper/Presentation/Authentication/screens/Landing_Screens.dart';
import 'package:hopper/Presentation/Authentication/screens/Otp_Screens.dart';
import 'package:hopper/Presentation/Authentication/screens/Terms_Screen.dart';
import 'package:hopper/Presentation/Drawer/model/ride_history_response.dart';
import 'package:hopper/api/dataSource/apiDataSource.dart';
import 'package:hopper/api/repository/failure.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RideHistoryController extends GetxController {
  ApiDataSource apiDataSource = ApiDataSource();
  RxBool isLoading = false.obs;
  RxList<RideActivityHistoryData> rideHistoryData =
      RxList<RideActivityHistoryData>();
  @override
  void onInit() {
    super.onInit();
    rideHistory();
  }

  Future<String?> rideHistory( ) async {
    isLoading.value = true;
    try {
      final results = await apiDataSource.rideHistory();
      results.fold(
        (failure) {
          CustomSnackBar.showError(failure.message);
          isLoading.value = false;

          return '';
        },
        (response) {
          isLoading.value = false;
          rideHistoryData.value = response.remappedBookings;
          return ' ';
        },
      );
    } catch (e) {
      isLoading.value = false;
      return ' ';
    }
    isLoading.value = false;
    return '';
  }
}
