import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hopper/Core/Constants/log.dart';

import 'package:hopper/api/dataSource/apiDataSource.dart';

import '../../../Core/Utility/snackbar.dart';
import '../screens/picking_customer_screen.dart';

class DriverStatusController extends GetxController {
  var isOnline = true.obs;
  RxBool isLoading = false.obs;
  ApiDataSource apiDataSource = ApiDataSource();
  void toggleStatus() {
    isOnline.value = !isOnline.value;
  }

  Future<String?> bookingAccept(
    BuildContext context, {
    required String bookingId,
    required String status,
  }) async {
    isLoading.value = true;
    try {
      final results = await apiDataSource.bookingAccept(bookingId: bookingId, status: status);
      results.fold(
        (failure) {
          CustomSnackBar.showError(failure.message);
          isLoading.value = false;

          return '';
        },
        (response) {
          // CustomSnackBar.showSuccess(response.message.toString());
          CommonLogger.log.i(response.data);
          Get.to(PickingCustomerScreen());
          isLoading.value = false;

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
