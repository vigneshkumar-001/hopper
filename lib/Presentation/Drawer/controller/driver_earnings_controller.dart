import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hopper/Core/Constants/log.dart';
import 'package:hopper/Presentation/Drawer/model/driver_earnings_response.dart';
import 'package:hopper/api/dataSource/apiDataSource.dart';

class DriverEarningsController extends GetxController {
  final ApiDataSource _api = ApiDataSource();

  // Filters (defaults match the request sample)
  final RxString category = 'EARNING'.obs;
  final RxString bookingType = 'Ride'.obs;
  final RxString paymentMode = 'WALLET'.obs;
  final RxString status = 'PAID'.obs;
  final RxString transactionType = 'CASH_COMMISSION'.obs;

  final Rxn<DateTime> fromDate = Rxn<DateTime>();
  final Rxn<DateTime> toDate = Rxn<DateTime>();

  // Paging
  final RxBool isLoading = false.obs;
  final RxBool isLoadingMore = false.obs;
  final RxString errorText = ''.obs;

  final Rxn<DriverEarningsSummary> summary = Rxn<DriverEarningsSummary>();
  final RxList<DriverEarningsItem> items = <DriverEarningsItem>[].obs;

  String? _nextCursor;
  bool _hasMore = false;

  static const int _pageSize = 20;

  @override
  void onInit() {
    super.onInit();
    // Default to current month range for a good first-load UX.
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    fromDate.value = start;
    toDate.value = now;
    refreshList(silent: true);
  }

  String _fmtDate(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  Future<void> refreshList({bool silent = false}) async {
    if (isLoading.value) return;
    if (!silent) errorText.value = '';

    isLoading.value = true;
    _nextCursor = null;
    _hasMore = false;
    items.clear();

    try {
      final res = await _api.driverEarnings(
        limit: _pageSize,
        cursor: null,
        category: category.value,
        bookingType: bookingType.value,
        paymentMode: paymentMode.value,
        status: status.value,
        fromDate: fromDate.value != null ? _fmtDate(fromDate.value!) : null,
        toDate: toDate.value != null ? _fmtDate(toDate.value!) : null,
        transactionType: transactionType.value,
      );

      res.fold((l) {
        errorText.value = l.message;
      }, (r) {
        summary.value = r.summary;
        items.assignAll(r.items);
        _nextCursor = r.cursor.next;
        _hasMore = r.cursor.hasMore;
      });
    } catch (e, st) {
      CommonLogger.log.e(e);
      CommonLogger.log.e(st);
      errorText.value = 'Something went wrong';
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loadMore() async {
    if (isLoadingMore.value || isLoading.value) return;
    if (!_hasMore) return;
    final cursor = _nextCursor;
    if (cursor == null || cursor.trim().isEmpty) return;

    isLoadingMore.value = true;
    try {
      final res = await _api.driverEarnings(
        limit: _pageSize,
        cursor: cursor,
        category: category.value,
        bookingType: bookingType.value,
        paymentMode: paymentMode.value,
        status: status.value,
        fromDate: fromDate.value != null ? _fmtDate(fromDate.value!) : null,
        toDate: toDate.value != null ? _fmtDate(toDate.value!) : null,
        transactionType: transactionType.value,
      );

      res.fold((l) {
        errorText.value = l.message;
      }, (r) {
        summary.value = r.summary;
        items.addAll(r.items);
        _nextCursor = r.cursor.next;
        _hasMore = r.cursor.hasMore;
      });
    } catch (e, st) {
      CommonLogger.log.e(e);
      CommonLogger.log.e(st);
    } finally {
      isLoadingMore.value = false;
    }
  }

  Future<void> pickDateRange(BuildContext context) async {
    final initialStart = fromDate.value ?? DateTime.now().subtract(const Duration(days: 30));
    final initialEnd = toDate.value ?? DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: DateTimeRange(start: initialStart, end: initialEnd),
    );
    if (picked == null) return;
    fromDate.value = picked.start;
    toDate.value = picked.end;
    await refreshList();
  }

  Future<void> applyFilters({
    required String bookingTypeValue,
    required String paymentModeValue,
    required String statusValue,
    required String transactionTypeValue,
  }) async {
    bookingType.value = bookingTypeValue;
    paymentMode.value = paymentModeValue;
    status.value = statusValue;
    transactionType.value = transactionTypeValue;
    await refreshList();
  }
}

