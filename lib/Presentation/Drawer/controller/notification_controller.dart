import 'package:get/get.dart';
import 'package:hopper/Core/Constants/log.dart';
import 'package:hopper/api/dataSource/apiDataSource.dart';
import 'package:hopper/Core/Utility/snackbar.dart';
import '../../../api/repository/api_config_controller.dart';
import '../../../utils/sharedprefsHelper/sharedprefs_handler.dart';
import 'package:hopper/Presentation/Drawer/model/notification_response.dart';

class NotificationController extends GetxController {
  final ApiDataSource apiDataSource = ApiDataSource();

  final RxBool isLoading = false.obs;
  final RxBool isMoreLoading = false.obs;
  final RxBool hasMore = true.obs;
  RxBool isSharedEnabled = false.obs;
  final cfg = Get.find<ApiConfigController>();
  RxList<NotificationData> notificationData = <NotificationData>[].obs;

  int page = 1;
  final int limit = 10;

  @override
  void onInit() {
    super.onInit();
    getNotification();
    _loadInitialValue();
  }

  Future<void> _loadInitialValue() async {
    final value = await SharedPrefHelper.instance.getSharedBookingEnabled();
    isSharedEnabled.value = value;

    CommonLogger.log.i(
      'Shared booking loaded from local: ${value ? 'ENABLED' : 'DISABLED'}',
    );
  }

  Future<void> setSharedEnabled(bool enabled) async {
    if (isLoading.value) return;

    final prev = isSharedEnabled.value;

    // ✅ Optimistic UI
    isSharedEnabled.value = enabled;
    _showSafeSnackbar(enabled, serverMessage: enabled ? 'Shared booking enabled' : 'Shared booking disabled');
    isLoading.value = true;

    try {
      // 1) Call server
      final result = await apiDataSource.setStatusEnabled(enabled: enabled);

      result.fold(
        (failure) {
          // ❌ revert on failure
          isSharedEnabled.value = prev;
          CommonLogger.log.e("Shared booking update failed: $failure");
          _showSafeSnackbar(false, serverMessage: 'Shared booking update failed');
        },
        (response) async {
          // server is source of truth
          final serverEnabled = response.status.isEnabled;
          isSharedEnabled.value = serverEnabled;


          // persist after showing UI feedback so snackbar is immediate
          await SharedPrefHelper.instance.setSharedBookingEnabled(
            serverEnabled,
          );
          await cfg.setSharedEnabled(serverEnabled);

          CommonLogger.log.i(
            "Shared booking saved: ${serverEnabled ? 'ENABLED' : 'DISABLED'}",
          );
        },
      );
    } catch (e) {
      // ❌ revert on crash
      isSharedEnabled.value = prev;
      CommonLogger.log.e("❌ Error in setSharedEnabled: $e");
      _showSafeSnackbar(false, serverMessage: 'Something went wrong');
    } finally {
      isLoading.value = false;
    }
  }

  //
  // Future<void> setSharedEnabled(bool value) async {
  //   isSharedEnabled.value = value;
  //   await cfg.setSharedEnabled(value);
  //   // await SharedPrefHelper.instance.setSharedBookingEnabled(value);
  //   // CommonLogger.log.i(
  //   //   'Shared booking is now: ${value ? 'ENABLED' : 'DISABLED'}',
  //   // );
  // }
  //
  void _showSafeSnackbar(bool enabled, {required String serverMessage}) {
    try {
      CustomSnackBar.showStatusToggle(enabled: enabled, label: 'Shared Booking');
    } catch (e) {
      CommonLogger.log.e('Snackbar show failed: $e | $serverMessage');
    }
  }

  Future<void> getNotification({bool isRefresh = false}) async {
    if (isRefresh) {
      page = 1;
      hasMore.value = true;
      notificationData.clear();
    }

    if (!hasMore.value) return;

    if (page == 1) {
      isLoading.value = true;
    } else {
      isMoreLoading.value = true;
    }

    try {
      final result = await apiDataSource.getNotification(page: page);

      result.fold(
        (failure) {
          CommonLogger.log.e("Error: $failure");
        },
        (response) {
          if (page == 1) {
            notificationData.value = response.data;
          } else {
            notificationData.addAll(response.data);
          }

          // STOP when data length < limit → no more pages
          if (response.data.length < limit) {
            hasMore.value = false;
          } else {
            page++;
          }

          CommonLogger.log.i(
            "📩 Loaded page: $page | Count: ${response.data.length}",
          );
        },
      );
    } catch (e) {
      CommonLogger.log.e("❌ Error in getNotification: $e");
    } finally {
      isLoading.value = false;
      isMoreLoading.value = false;
    }
  }
}

// import 'package:flutter/material.dart';
// import 'package:get/get.dart';
// import 'package:hopper/Core/Constants/log.dart';
//
// import 'package:hopper/api/dataSource/apiDataSource.dart';
// class NotificationController extends GetxController {
//   final ApiDataSource apiDataSource = ApiDataSource();
//
//   final RxBool isLoading = false.obs;
//   RxList<NotificationData> notificationData = <NotificationData>[].obs;
//
//   @override
//   void onInit() {
//     super.onInit();
//
//   }
//
//   Future<void> getNotification() async {
//     isLoading.value = true;
//     try {
//       final results = await apiDataSource.getNotification();
//       results.fold(
//         (failure) {
//           CommonLogger.log.e(" $failure");
//         },
//         (response) {
//           notificationData.value = response.data;
//           CommonLogger.log.i(
//             "✅ Raw response for Notification Data: ${response.toJson()}",
//           );
//         },
//       );
//     } catch (e) {
//       CommonLogger.log.e("❌ Exception while fetching rides: $e");
//     } finally {
//       isLoading.value = false;
//     }
//   }
// }




