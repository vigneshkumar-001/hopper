import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hopper/Core/Constants/log.dart';

import 'package:hopper/api/dataSource/apiDataSource.dart';

import '../model/notification_response.dart';

class NotificationController extends GetxController {
  final ApiDataSource apiDataSource = ApiDataSource();

  final RxBool isLoading = false.obs;
  RxList<NotificationData> notificationData = <NotificationData>[].obs;

  @override
  void onInit() {
    super.onInit();

  }

  Future<void> getNotification() async {
    isLoading.value = true;
    try {
      final results = await apiDataSource.getNotification();
      results.fold(
        (failure) {
          CommonLogger.log.e(" $failure");
        },
        (response) {
          notificationData.value = response.data;
          CommonLogger.log.i(
            "✅ Raw response for Notification Data: ${response.toJson()}",
          );
        },
      );
    } catch (e) {
      CommonLogger.log.e("❌ Exception while fetching rides: $e");
    } finally {
      isLoading.value = false;
    }
  }
}
