import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hopper/Core/Constants/log.dart';
import 'package:country_picker/country_picker.dart';

import 'package:hopper/Core/Utility/snackbar.dart';
import 'package:hopper/Presentation/Authentication/screens/Landing_Screens.dart';
import 'package:hopper/Presentation/Authentication/screens/Otp_Screens.dart';
import 'package:hopper/Presentation/Authentication/screens/Terms_Screen.dart';
import 'package:hopper/Presentation/Drawer/model/add_wallet_response.dart';
import 'package:hopper/Presentation/Drawer/model/ride_history_response.dart';
import 'package:hopper/api/dataSource/apiDataSource.dart';
import 'package:hopper/api/repository/failure.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../model/wallet_history_response.dart';
import '../screens/wallet_payment_screen.dart';

class RideHistoryController extends GetxController {
  ApiDataSource apiDataSource = ApiDataSource();
  RxBool isLoading = false.obs;
  RxList<RideActivityHistoryData> rideHistoryData =
      RxList<RideActivityHistoryData>();

  Rx<AddWalletResponse?> walletData = Rx<AddWalletResponse?>(null);
  RxList<Transaction> traction = RxList<Transaction>([]);
  var balance = ''.obs; // ✅ Correct (RxString)

  @override
  void onInit() {
    super.onInit();
    //  rideHistory();
  }

  Future<void> rideHistory() async {
    isLoading.value = true;
    try {
      final results = await apiDataSource.rideHistory();
      results.fold(
        (failure) {
          CustomSnackBar.showError(failure.message);
          isLoading.value = false;

          return;
        },
        (response) {
          isLoading.value = false;
          rideHistoryData.value = response.remappedBookings;
          return;
        },
      );
    } catch (e) {
      isLoading.value = false;
      return;
    }
    isLoading.value = false;
    return;
  }

  Future<void> customerWalletHistory() async {
    isLoading.value = true;
    try {
      final results = await apiDataSource.customerWalletHistory();
      results.fold(
        (failure) {
          print("❌ Ride history fetch failed: $failure");
        },
        (response) {
          traction.value = response.transactions;
          final amount = response.balance?.amount ?? 0.0;
          final cashOnHand = response.balance?.cashOnHand ?? 0.0;

          balance.value = amount.toString() ?? '';
          print("✅ Raw response: ${response.transactions}");
          return response.transactions.toString();
        },
      );
    } catch (e) {
      print("❌ Exception while fetching rides: $e");
    } finally {
      isLoading.value = false;
    }
    return null;
  }

  Future<void> addWallet({
    required double amount,
    required String method,
  }) async {
    isLoading.value = true;
    try {
      final results = await apiDataSource.addWallet(
        amount: amount,
        method: method,
      );
      results.fold(
        (failure) {
          CommonLogger.log.e("❌ Ride history fetch failed: $failure");
        },
        (response) {
          walletData.value = response;
          Get.to(
            () => WalletPaymentScreens(
              clientSecret: response.clientSecret,
              publishableKey: response.publishableKey,
              transactionId: response.transactionId,

              amount: amount.toInt(),
            ),
          );
          CommonLogger.log.i("✅ Raw response: ${response.toJson()}");
        },
      );
    } catch (e) {
      CommonLogger.log.e("❌ Exception while fetching rides: $e");
    } finally {
      isLoading.value = false;
    }
  }
}
