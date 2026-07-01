import 'package:get/get.dart';
import 'package:hopper/Core/Constants/log.dart';

import 'package:hopper/Core/Utility/snackbar.dart';
import 'package:hopper/Presentation/Drawer/model/add_wallet_response.dart';
import 'package:hopper/Presentation/Drawer/model/ride_history_response.dart';
import 'package:hopper/api/dataSource/apiDataSource.dart';

import 'package:hopper/Presentation/Drawer/model/wallet_history_response.dart';

class RideHistoryController extends GetxController {
  ApiDataSource apiDataSource = ApiDataSource();
  RxBool isLoading = false.obs;
  RxBool isWithdrawLoading = false.obs;

  /// True when the last first-page fetch failed (network / 500) so the screen
  /// can show the server-error state with a "Try again" action. Tracked
  /// separately for ride history and wallet history.
  RxBool rideHasError = false.obs;
  RxBool walletHasError = false.obs;
  RxList<RideActivityHistoryData> rideHistoryData =
      RxList<RideActivityHistoryData>();

  Rx<AddWalletResponse?> walletData = Rx<AddWalletResponse?>(null);
  RxList<Transaction> traction = RxList<Transaction>([]);
  var balance = ''.obs; // ✅ Correct (RxString)
  var page = 1;
  var hasMore = true.obs;
  var isMoreLoading = false.obs;

  // Ride Activity filters (backend-driven). Defaults show everything.
  final RxString filterStatus = 'all'.obs; // all | completed | cancelled
  final RxString filterRideType = 'all'.obs; // all | single | shared | parcel
  final Rxn<DateTime> filterFrom = Rxn<DateTime>();
  final Rxn<DateTime> filterTo = Rxn<DateTime>();

  /// True when any non-default filter is active (drives the "clear" chip).
  bool get hasActiveFilter =>
      filterStatus.value != 'all' ||
      filterRideType.value != 'all' ||
      filterFrom.value != null ||
      filterTo.value != null;

  /// Apply new filter selections and reload from page 1 (backend filters).
  Future<void> applyFilters({
    String? status,
    String? rideType,
    DateTime? from,
    DateTime? to,
    bool clearDates = false,
    bool clearAll = false,
  }) async {
    if (clearAll) {
      filterStatus.value = 'all';
      filterRideType.value = 'all';
      filterFrom.value = null;
      filterTo.value = null;
    } else {
      if (status != null) filterStatus.value = status;
      if (rideType != null) filterRideType.value = rideType;
      if (clearDates) {
        filterFrom.value = null;
        filterTo.value = null;
      } else {
        if (from != null) filterFrom.value = from;
        if (to != null) filterTo.value = to;
      }
    }
    await rideHistory(isRefresh: true);
  }

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
      rideHasError.value = false;
      isLoading.value = true;
    } else {
      if (!hasMore.value) return; // stop if no more
      isMoreLoading.value = true;
    }

    try {
      final result = await apiDataSource.rideHistory(
        page: page,
        status: filterStatus.value == 'all' ? null : filterStatus.value,
        rideType: filterRideType.value == 'all' ? null : filterRideType.value,
        from: filterFrom.value?.toIso8601String(),
        to: filterTo.value?.toIso8601String(),
      );

      result.fold(
            (failure) {
          if (isRefresh) rideHasError.value = true;
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

  Future<void> customerWalletHistory({
    bool isRefresh = false,
    bool showErrors = true,
  }) async {

    if (isMoreLoading.value || isLoading.value) return;

    if (isRefresh) {
      page = 1;
      hasMore.value = true;
      traction.clear();
      walletHasError.value = false;
      isLoading.value = true;
    } else {
      if (!hasMore.value) return;
      isMoreLoading.value = true;
    }

    try {
      final results = await apiDataSource.customerWalletHistory(page: page);

      results.fold(
            (failure) {
          if (isRefresh) walletHasError.value = true;
          if (showErrors) {
            CustomSnackBar.showError(failure.message);
          }
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

  /// Returns true only when the backend confirms the withdrawal request.
  Future<bool> requestWithdraw({required double amount}) async {
    if (isWithdrawLoading.value) return false;
    isWithdrawLoading.value = true;
    try {
      final results = await apiDataSource.requestWithdraw(amount: amount);
      return await results.fold(
        (failure) async {
          CustomSnackBar.showError(failure.message);
          return false;
        },
        (response) async {
          if (response.success) {
            CustomSnackBar.showSuccess(
              response.message.isEmpty
                  ? 'Withdrawal request submitted successfully'
                  : response.message,
            );
            await customerWalletHistory(isRefresh: true);
            return true;
          } else {
            CustomSnackBar.showError(
              response.message.isEmpty ? 'Withdrawal failed' : response.message,
            );
            return false;
          }
        },
      );
    } catch (e) {
      CommonLogger.log.e(e);
      CustomSnackBar.showError('Something went wrong');
      return false;
    } finally {
      isWithdrawLoading.value = false;
    }
  }
}
