import 'package:get/get.dart';
import 'package:hopper/Core/Constants/log.dart';

import 'package:hopper/Core/Utility/snackbar.dart';
import 'package:hopper/Presentation/Drawer/model/add_wallet_response.dart';
import 'package:hopper/Presentation/Drawer/model/ride_history_response.dart';
import 'package:hopper/api/dataSource/apiDataSource.dart';

import '../model/wallet_history_response.dart';

class RideHistoryController extends GetxController {
  ApiDataSource apiDataSource = ApiDataSource();
  RxBool isLoading = false.obs;
  RxBool isWithdrawLoading = false.obs;
  RxList<RideActivityHistoryData> rideHistoryData =
      RxList<RideActivityHistoryData>();

  Rx<AddWalletResponse?> walletData = Rx<AddWalletResponse?>(null);
  RxList<Transaction> traction = RxList<Transaction>([]);
  var balance = ''.obs; // ✅ Correct (RxString)
  var page = 1;
  var hasMore = true.obs;
  var isMoreLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    //  rideHistory();
  }

  Future<void> rideHistory({bool isRefresh = false}) async {
    if (isMoreLoading.value || isLoading.value) return;

    if (isRefresh) {
      page = 1;
      hasMore.value = true;
      rideHistoryData.clear();
      isLoading.value = true;
    } else {
      if (!hasMore.value) return; // stop if no more
      isMoreLoading.value = true;
    }

    try {
      final result = await apiDataSource.rideHistory(page: page);

      result.fold(
            (failure) {
          CustomSnackBar.showError(failure.message);
        },
            (response) {
          final newItems = response. bookings ?? [];

          if (isRefresh) {
            rideHistoryData.value = newItems;
          } else {
            rideHistoryData.addAll(newItems);
          }

          // Pagination logic
          if (newItems.length < 10) {
            hasMore.value = false;
          } else {
            page++;
          }
        },
      );
    } finally {
      isLoading.value = false;
      isMoreLoading.value = false;
    }
  }

  Future<void> customerWalletHistory({bool isRefresh = false}) async {

    if (isMoreLoading.value || isLoading.value) return;

    if (isRefresh) {
      page = 1;
      hasMore.value = true;
      traction.clear();
      isLoading.value = true;
    } else {
      if (!hasMore.value) return;
      isMoreLoading.value = true;
    }

    try {
      final results = await apiDataSource.customerWalletHistory(page: page);

      results.fold(
            (failure) {
          CustomSnackBar.showError(failure.message);
        },
            (response) {
          final newItems = response.transactions;

          if (isRefresh) {
            traction.value = newItems;
          } else {
            traction.addAll(newItems);
          }

          // Balance update
          final amount = response.balance?.amount ?? 0.0;
          balance.value = amount.toString();

          // Pagination check
          if (newItems.length < 10) {
            hasMore.value = false;
          } else {
            page++;
          }
        },
      );

    } finally {
      isLoading.value = false;
      isMoreLoading.value = false;
    }
  }


  // Future<void> rideHistory() async {
  //   isLoading.value = true;
  //   try {
  //     final results = await apiDataSource.rideHistory();
  //     results.fold(
  //       (failure) {
  //         CustomSnackBar.showError(failure.message);
  //         isLoading.value = false;
  //
  //         return;
  //       },
  //       (response) {
  //         isLoading.value = false;
  //         rideHistoryData.value = response.remappedBookings;
  //         return;
  //       },
  //     );
  //   } catch (e) {
  //     isLoading.value = false;
  //     return;
  //   }
  //   isLoading.value = false;
  //   return;
  // }

  // Future<void> customerWalletHistory() async {
  //   isLoading.value = true;
  //   try {
  //     final results = await apiDataSource.customerWalletHistory();
  //     results.fold(
  //       (failure) {
  //         print("❌ Ride history fetch failed: $failure");
  //       },
  //       (response) {
  //         traction.value = response.transactions;
  //         final amount = response.balance?.amount ?? 0.0;
  //         final cashOnHand = response.balance?.cashOnHand ?? 0.0;
  //
  //         balance.value = amount.toString() ?? '';
  //         print("✅ Raw response: ${response.transactions}");
  //         return response.transactions.toString();
  //       },
  //     );
  //   } catch (e) {
  //     print("❌ Exception while fetching rides: $e");
  //   } finally {
  //     isLoading.value = false;
  //   }
  //   return null;
  // }

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

          CommonLogger.log.i("✅ Raw response: ${response.toJson()}");
        },
      );
    } catch (e) {
      CommonLogger.log.e("❌ Exception while fetching rides: $e");
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> requestWithdraw({required double amount}) async {
    if (isWithdrawLoading.value) return;
    isWithdrawLoading.value = true;
    try {
      final results = await apiDataSource.requestWithdraw(amount: amount);
      results.fold(
        (failure) => CustomSnackBar.showError(failure.message),
        (response) async {
          if (response.success) {
            CustomSnackBar.showSuccess(
              response.message.isEmpty
                  ? 'Withdrawal request submitted successfully'
                  : response.message,
            );
            await customerWalletHistory(isRefresh: true);
          } else {
            CustomSnackBar.showError(
              response.message.isEmpty ? 'Withdrawal failed' : response.message,
            );
          }
        },
      );
    } catch (e) {
      CommonLogger.log.e(e);
      CustomSnackBar.showError('Something went wrong');
    } finally {
      isWithdrawLoading.value = false;
    }
  }
}
