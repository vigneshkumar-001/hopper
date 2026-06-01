import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hopper/Core/Constants/Colors.dart';
import 'package:hopper/Presentation/Drawer/controller/driver_earnings_controller.dart';
import 'package:hopper/utils/widgets/hoppr_circular_loader.dart';

class DriverEarningsScreen extends StatefulWidget {
  const DriverEarningsScreen({super.key});

  @override
  State<DriverEarningsScreen> createState() => _DriverEarningsScreenState();
}

class _DriverEarningsScreenState extends State<DriverEarningsScreen> {
  late final DriverEarningsController c;
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    c = Get.put(DriverEarningsController());
    _scroll.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final pos = _scroll.position;
    if (pos.pixels >= pos.maxScrollExtent - 240) {
      c.loadMore();
    }
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    if (Get.isRegistered<DriverEarningsController>()) {
      Get.delete<DriverEarningsController>();
    }
    super.dispose();
  }

  Widget _summaryCard(String title, String value, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.nBlue.withValues(alpha: 0.18),
                  AppColors.drkGreen.withValues(alpha: 0.18),
                ],
              ),
            ),
            child: Icon(icon ?? Icons.payments_rounded, color: AppColors.nBlue),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF111827),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openFilters() async {
    final bookingTypes = const <String>['Ride', 'Package'];
    final paymentModes = const <String>['WALLET', 'CASH', 'CARD'];
    final statuses = const <String>['PAID', 'PENDING'];
    final transactionTypes = const <String>[
      'CASH_COMMISSION',
      'RIDE_EARNING',
      'PACKAGE_EARNING',
    ];

    String bt = c.bookingType.value;
    String pm = c.paymentMode.value;
    String st = c.status.value;
    String tt = c.transactionType.value;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        Widget dd<T>({
          required String label,
          required T value,
          required List<T> items,
          required ValueChanged<T> onChanged,
        }) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF374151),
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<T>(
                value: value,
                items: items
                    .map((e) => DropdownMenuItem<T>(
                          value: e,
                          child: Text(e.toString()),
                        ))
                    .toList(),
                onChanged: (v) {
                  if (v == null) return;
                  onChanged(v);
                },
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFFF9FAFB),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: Colors.black.withValues(alpha: 0.08),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: Colors.black.withValues(alpha: 0.08),
                    ),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ],
          );
        }

        return SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              12,
              16,
              16 + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: StatefulBuilder(
              builder: (context, setModal) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Filters',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 14),
                    dd<String>(
                      label: 'Booking Type',
                      value: bt,
                      items: bookingTypes,
                      onChanged: (v) => setModal(() => bt = v),
                    ),
                    const SizedBox(height: 12),
                    dd<String>(
                      label: 'Payment Mode',
                      value: pm,
                      items: paymentModes,
                      onChanged: (v) => setModal(() => pm = v),
                    ),
                    const SizedBox(height: 12),
                    dd<String>(
                      label: 'Status',
                      value: st,
                      items: statuses,
                      onChanged: (v) => setModal(() => st = v),
                    ),
                    const SizedBox(height: 12),
                    dd<String>(
                      label: 'Transaction Type',
                      value: tt,
                      items: transactionTypes,
                      onChanged: (v) => setModal(() => tt = v),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              side: BorderSide(
                                color: Colors.black.withValues(alpha: 0.12),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(fontWeight: FontWeight.w900),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              Navigator.pop(context);
                              await c.applyFilters(
                                bookingTypeValue: bt,
                                paymentModeValue: pm,
                                statusValue: st,
                                transactionTypeValue: tt,
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Text(
                              'Apply',
                              style: TextStyle(fontWeight: FontWeight.w900),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _earningItemTile(int index) {
    final it = c.items[index];
    final bookingId = it.booking.bookingId.trim().isEmpty ? '-' : it.booking.bookingId;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  it.title.isNotEmpty ? it.title : 'Earning',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF111827),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '₦ ${it.amount}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF111827),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Booking: $bookingId • ${it.type}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.black.withValues(alpha: 0.55),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            it.booking.pickupAddress,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.black.withValues(alpha: 0.60),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            it.booking.dropAddress,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.black.withValues(alpha: 0.60),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          'Earnings',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        actions: [
          IconButton(
            tooltip: 'Date range',
            onPressed: () => c.pickDateRange(context),
            icon: const Icon(Icons.date_range_rounded),
          ),
          IconButton(
            tooltip: 'Filters',
            onPressed: _openFilters,
            icon: const Icon(Icons.tune_rounded),
          ),
        ],
      ),
      body: Obx(() {
        if (c.isLoading.value && c.items.isEmpty) {
          return const Center(child: HopprCircularLoader());
        }
        if (c.errorText.value.isNotEmpty && c.items.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                c.errorText.value,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          );
        }

        final s = c.summary.value;
        return RefreshIndicator(
          onRefresh: () => c.refreshList(),
          child: ListView(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
            children: [
              if (s != null) ...[
                Row(
                  children: [
                    Expanded(
                      child: _summaryCard(
                        'Available Balance',
                        '₦ ${s.availableBalance}',
                        icon: Icons.account_balance_wallet_rounded,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _summaryCard(
                        'Cash on Hand',
                        '₦ ${s.cashOnHand}',
                        icon: Icons.payments_rounded,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _summaryCard(
                        'Lifetime Earnings',
                        '₦ ${s.lifetimeEarnings}',
                        icon: Icons.trending_up_rounded,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _summaryCard(
                        'Withdrawals',
                        '₦ ${s.totalWithdrawals}',
                        icon: Icons.savings_rounded,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
              ],
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
                      ),
                      child: Obx(() {
                        final fd = c.fromDate.value;
                        final td = c.toDate.value;
                        String text = 'All time';
                        if (fd != null && td != null) {
                          text =
                              '${fd.year}-${fd.month.toString().padLeft(2, '0')}-${fd.day.toString().padLeft(2, '0')}  →  '
                              '${td.year}-${td.month.toString().padLeft(2, '0')}-${td.day.toString().padLeft(2, '0')}';
                        }
                        return Text(
                          text,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        );
                      }),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (c.items.isEmpty && !c.isLoading.value)
                const Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: Center(
                    child: Text(
                      'No earnings found for the selected filters.',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                )
              else
                ...List.generate(c.items.length, _earningItemTile),
              if (c.isLoadingMore.value)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Center(child: HopprCircularLoader()),
                ),
              const SizedBox(height: 20),
            ],
          ),
        );
      }),
    );
  }
}

