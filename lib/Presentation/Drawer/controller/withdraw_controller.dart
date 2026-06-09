import 'package:get/get.dart';

import 'package:hopper/Core/Constants/log.dart';
import 'package:hopper/Core/Utility/snackbar.dart';
import 'package:hopper/api/dataSource/apiDataSource.dart';

import '../model/bank_details_models.dart';
import '../utils/bank_list_service.dart';
import '../utils/saved_bank_store.dart';

/// Owns the driver withdraw bank-details state: the bank picker list, the saved
/// bank account (cached locally — backend has no GET), and the save call.
/// The actual withdraw REQUEST stays in RideHistoryController.
class WithdrawController extends GetxController {
  final ApiDataSource _api = ApiDataSource();

  final RxList<NigerianBank> banks = <NigerianBank>[].obs;
  final RxBool isBanksLoading = false.obs;

  final Rxn<SavedBankDetails> savedBank = Rxn<SavedBankDetails>();
  final RxBool isSaving = false.obs;

  bool get hasBank => savedBank.value?.isComplete == true;

  @override
  void onInit() {
    super.onInit();
    loadSavedBank();
    loadBanks();
  }

  Future<void> loadSavedBank() async {
    savedBank.value = await SavedBankStore.load();
  }

  Future<void> loadBanks() async {
    if (banks.isNotEmpty || isBanksLoading.value) return;
    isBanksLoading.value = true;
    try {
      banks.value = await BankListService.getBanks();
    } catch (e) {
      CommonLogger.log.w('loadBanks failed: $e');
    } finally {
      isBanksLoading.value = false;
    }
  }

  /// Saves bank details to the backend and caches them locally.
  /// Returns true on success.
  Future<bool> saveBankDetails({
    required String accountHolderName,
    required NigerianBank bank,
    required String accountNumber,
    String branchName = '',
    String swiftCode = '',
  }) async {
    if (isSaving.value) return false;
    isSaving.value = true;
    try {
      final res = await _api.updateDriverWithdrawPaymentDetails(
        accountHolderName: accountHolderName,
        bankName: bank.name,
        bankCode: bank.code,
        accountNumber: accountNumber,
        branchName: branchName,
        swiftCode: swiftCode,
      );

      return await res.fold(
        (failure) {
          CustomSnackBar.showError(failure.message);
          return false;
        },
        (response) async {
          if (!response.success) {
            CustomSnackBar.showError(
              response.message.isEmpty
                  ? 'Failed to save bank details'
                  : response.message,
            );
            return false;
          }

          // Persist locally (no GET to read it back). Prefer the server echo,
          // but keep the user's entered values for any field the server omits
          // (e.g. older backends that don't return holderName / bankCode).
          final server = response.data;
          final merged = SavedBankDetails(
            accountHolderName:
                (server?.accountHolderName.isNotEmpty ?? false)
                    ? server!.accountHolderName
                    : accountHolderName,
            bankName: (server?.bankName.isNotEmpty ?? false)
                ? server!.bankName
                : bank.name,
            bankCode: (server?.bankCode.isNotEmpty ?? false)
                ? server!.bankCode
                : bank.code,
            accountNumber: (server?.accountNumber.isNotEmpty ?? false)
                ? server!.accountNumber
                : accountNumber,
            branchName: (server?.branchName.isNotEmpty ?? false)
                ? server!.branchName
                : branchName,
            swiftCode: (server?.swiftCode.isNotEmpty ?? false)
                ? server!.swiftCode
                : swiftCode,
            status: server?.status ?? '',
            image: server?.image ?? '',
          );

          await SavedBankStore.save(merged);
          savedBank.value = merged;
          CustomSnackBar.showSuccess(
            response.message.isEmpty
                ? 'Bank details saved successfully'
                : response.message,
          );
          return true;
        },
      );
    } catch (e) {
      CommonLogger.log.e(e);
      CustomSnackBar.showError('Something went wrong');
      return false;
    } finally {
      isSaving.value = false;
    }
  }
}
