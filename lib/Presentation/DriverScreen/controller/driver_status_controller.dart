import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:hopper/Core/Constants/log.dart';
import 'package:hopper/Presentation/DriverScreen/models/weekly_challenge_models.dart';

import 'package:hopper/api/dataSource/apiDataSource.dart';

import '../../../Core/Utility/snackbar.dart';
import '../models/get_todays_activity_models.dart';
import '../screens/picking_customer_screen.dart';
import '../screens/ride_stats_screen.dart';
import '../screens/verify_rider_screen.dart';

class DriverStatusController extends GetxController {
  var isOnline = true.obs;
  RxBool isLoading = false.obs;

  Rxn<TodayActivityData> todayStatusData = Rxn<TodayActivityData>();
  Rxn<WeeklyActivityData> weeklyStatusData = Rxn<WeeklyActivityData>();
  ApiDataSource apiDataSource = ApiDataSource();

  @override
  void onInit() {
    super.onInit();
    todayActivity();
    weeklyChallenges();
  }

  void toggleStatus() {
    isOnline.value = !isOnline.value;
  }

  Future<String?> bookingAccept(
    BuildContext context, {
    required String bookingId,
    required String status,
    required LatLng pickupLocation,
    required LatLng driverLocation,
  }) async {
    isLoading.value = true;
    try {
      final results = await apiDataSource.bookingAccept(
        bookingId: bookingId,
        status: status,
      );
      results.fold(
        (failure) {
          CustomSnackBar.showError(failure.message);
          isLoading.value = false;

          return '';
        },
        (response) {
          // CustomSnackBar.showSuccess(response.message.toString());

          CommonLogger.log.i(response.data);
          Get.to(
            PickingCustomerScreen(
              pickupLocation: pickupLocation,
              driverLocation: driverLocation,
            ),
          );
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

  Future<String?> otpRequest(
    BuildContext context, {
    required String bookingId,
  }) async {
    isLoading.value = true;
    try {
      final results = await apiDataSource.otpRequest(bookingId: bookingId);

      String? resultMessage;

      results.fold(
        (failure) {
          isLoading.value = false;
          CustomSnackBar.showError(failure.message);
          resultMessage = null; // explicitly set null
        },
        (response) {
          isLoading.value = false;
          CustomSnackBar.showSuccess(response.message);
          CommonLogger.log.i(response.message);

          resultMessage = response.message;

          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => VerifyRiderScreen()),
          );
        },
      );

      return resultMessage;
    } catch (e) {
      isLoading.value = false;
      return 'Something went wrong';
    }
  }

  Future<String?> otpInsert(
    BuildContext context, {
    required String bookingId,
    required String otp,
  }) async {
    isLoading.value = true;

    try {
      final results = await apiDataSource.otpInsert(
        bookingId: bookingId,
        enteredOtp: otp,
      );

      return results.fold(
        (failure) {
          isLoading.value = false;
          return null;
        },
        (response) {
          // isLoading.value = false;

          return response.message; // ✅ just return message
        },
      );
    } catch (e) {
      isLoading.value = false;
      return null;
    }
  }

  // Future<String?> otpInsert(
  //   BuildContext context, {
  //   required String bookingId,
  //   required String otp,
  // }) async
  // {
  //   isLoading.value = true;
  //   try {
  //     final results = await apiDataSource.otpInsert(
  //       bookingId: bookingId,
  //       enteredOtp: otp,
  //     );
  //
  //     String? resultMessage;
  //
  //     results.fold(
  //       (failure) {
  //         isLoading.value = false;
  //         CustomSnackBar.showError(failure.message);
  //         resultMessage = null;
  //       },
  //       (response) async {
  //         isLoading.value = false;
  //
  //
  //
  //
  //
  //         // Step 2: Wait until frame is fully settled
  //         SchedulerBinding.instance.addPostFrameCallback((_) {
  //           Navigator.pushReplacement(
  //             context,
  //             MaterialPageRoute(builder: (context) => RideStatsScreen()),
  //           );
  //         });
  //
  //         CustomSnackBar.showSuccess(response.message);
  //         return response.message;
  //       },
  //     );
  //
  //     return resultMessage;
  //   } catch (e) {
  //     isLoading.value = false;
  //     return 'Something went wrong';
  //   }
  // }

  Future<String?> onlineAcceptStatus(
    BuildContext context, {

    required bool status,
  }) async {
    isLoading.value = true;
    try {
      final results = await apiDataSource.driverOnlineStatus(
        onlineStatus: status,
      );
      results.fold(
        (failure) {
          CustomSnackBar.showError(failure.message);
          isLoading.value = false;

          return '';
        },
        (response) {
          // CustomSnackBar.showSuccess(response.message.toString());
          CommonLogger.log.i(response.data);
          // Get.to(PickingCustomerScreen());

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

  Future<String?> todayActivity() async {
    try {
      final results = await apiDataSource.todayActivity();
      CommonLogger.log.i("API called. Awaiting result...");

      results.fold(
        (failure) {
          // CustomSnackBar.showError(failure.message);

          return null;
        },
        (response) {
          CommonLogger.log.i("Success block entered");
          CommonLogger.log.i("Response: ${response.toJson()}");

          todayStatusData.value = response.data;
          CommonLogger.log.i("Assigned to todayStatusData:");
          CommonLogger.log.i(todayStatusData.value.toString());
          return response;
        },
      );
    } catch (e) {
      return ' ';
    }

    return '';
  }

  Future<String?> weeklyChallenges() async {
    try {
      final results = await apiDataSource.weeklyChallenge();
      CommonLogger.log.i("API called. Awaiting result...");

      results.fold(
        (failure) {
          // CustomSnackBar.showError(failure.message);

          return null;
        },
        (response) {
          CommonLogger.log.i("Response: ${response.toJson()}");

          weeklyStatusData.value = response.data;
          CommonLogger.log.i("Assigned to todayStatusData:");
          CommonLogger.log.i(weeklyStatusData.value.toString());
          return response;
        },
      );
    } catch (e) {
      return ' ';
    }

    return '';
  }

  Future<String?> cancelBooking(
    BuildContext context, {
    required String reason,
  }) async {
    try {
      final results = await apiDataSource.cancelBooking(reason: reason);

      results.fold(
        (failure) {
          // CustomSnackBar.showError(failure.message);
          CommonLogger.log.e("failure: ${failure.message}");
          return '';
        },
        (response) {
          CommonLogger.log.i("Response: ${response.message}");
          CustomSnackBar.showSuccess(response.message);
          CommonLogger.log.i("Assigned to todayStatusData:");

          return '';
        },
      );
    } catch (e) {
      return ' ';
    }

    return '';
  }
}
