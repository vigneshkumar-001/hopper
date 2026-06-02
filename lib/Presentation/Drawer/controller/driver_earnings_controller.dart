import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hopper/Core/Constants/log.dart';
import 'package:hopper/Presentation/Drawer/model/driver_earnings_response.dart';
import 'package:hopper/api/dataSource/apiDataSource.dart';

class DriverEarningsController extends GetxController {
  final ApiDataSource _api = ApiDataSource();

  // Filters (defaults match the request sample)
  final RxString category = 'EARNING'.obs; // ALL, EARNING, TOPUP, WITHDRAWAL, ADJUSTMENT
  // Empty string means "all booking types" (omit from payload).
  final RxString bookingType = ''.obs; // Ride, Parcel

  // API supports single value OR comma separated OR array.
  // Keep these as lists to match API response shape (filters.paymentModes/statuses/transactionTypes).
  // Empty list means "all" (omit from payload).
  final RxList<String> paymentModes = <String>[].obs;
  final RxList<String> statuses = <String>[].obs;
  final RxList<String> transactionTypes = <String>[].obs;

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
    // Default to last 30 days for a good first-load UX.
    final now = DateTime.now();
    fromDate.value = now.subtract(const Duration(days: 30));
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
        bookingType: bookingType.value.trim().isEmpty ? null : bookingType.value,
        paymentModes: paymentModes.toList(growable: false),
        statuses: statuses.toList(growable: false),
        fromDate: fromDate.value != null ? _fmtDate(fromDate.value!) : null,
        toDate: toDate.value != null ? _fmtDate(toDate.value!) : null,
        transactionTypes: transactionTypes.toList(growable: false),
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
        bookingType: bookingType.value.trim().isEmpty ? null : bookingType.value,
        paymentModes: paymentModes.toList(growable: false),
        statuses: statuses.toList(growable: false),
        fromDate: fromDate.value != null ? _fmtDate(fromDate.value!) : null,
        toDate: toDate.value != null ? _fmtDate(toDate.value!) : null,
        transactionTypes: transactionTypes.toList(growable: false),
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
    String? categoryValue,
    required String bookingTypeValue,
    required List<String> paymentModeValues,
    required List<String> statusValues,
    required List<String> transactionTypeValues,
  }) async {
    if (categoryValue != null && categoryValue.trim().isNotEmpty) {
      category.value = categoryValue.trim();
    }
    bookingType.value = bookingTypeValue.trim();

    paymentModes.assignAll(
      paymentModeValues.map((e) => e.trim()).where((e) => e.isNotEmpty),
    );
    statuses.assignAll(
      statusValues.map((e) => e.trim()).where((e) => e.isNotEmpty),
    );
    transactionTypes.assignAll(
      transactionTypeValues.map((e) => e.trim()).where((e) => e.isNotEmpty),
    );

    await refreshList();
  }
}
