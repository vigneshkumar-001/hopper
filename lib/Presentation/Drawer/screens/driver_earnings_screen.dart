import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hopper/Core/Constants/Colors.dart';
import 'package:hopper/Core/Utility/images.dart';
import 'package:hopper/Core/Utility/empty_state_view.dart';
import 'package:hopper/Presentation/Drawer/controller/driver_earnings_controller.dart';
import 'package:hopper/utils/widgets/hoppr_circular_loader.dart';
import 'package:hopper/Core/Utility/skeleton_loaders.dart';

class DriverEarningsScreen extends StatefulWidget {
  const DriverEarningsScreen({super.key});

  @override
  State<DriverEarningsScreen> createState() => _DriverEarningsScreenState();
}

class _DriverEarningsScreenState extends State<DriverEarningsScreen> {
  late final DriverEarningsController c;
  final ScrollController _scroll = ScrollController();
  final RxInt selectedTab = 0.obs;

  // Reference-style blue/indigo palette (clean fintech earnings look).
  static const Color bgColor = Color(0xFFF7F8FC);
  static const Color cardColor = AppColors.commonWhite;
  static const Color navy = Color(0xFF111315); // headings + amount + bars (black)
  static const Color primaryColor = Color(0xFF111315); // black accent / selected
  static final Color lightPrimary = const Color(0xFF111315).withValues(alpha: 0.08);
  static const Color blackColor = navy;
  static const Color textGrey = Color(0xFF9AA1B8);
  static final Color cardBorder = Colors.black.withValues(alpha: 0.06);
  static final Color lineColor = Colors.black.withValues(alpha: 0.06);

  final List<Map<String, String>> tabs = const [
    {'title': 'All', 'type': ''},
    {'title': 'Ride', 'type': 'Ride'},
    {'title': 'Parcel', 'type': 'Parcel'},
  ];

  @override
  void initState() {
    super.initState();
    c = Get.put(DriverEarningsController());
    _scroll.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 240) {
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

  static String _rupee(String amount) => '\u20A6$amount';

  // ---- Reference-style week selector + weekly bar chart ----
  static const List<String> _wdFull = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const List<String> _mon = [
    'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
    'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC',
  ];

  String _money(double v) => '₦${v.toStringAsFixed(2)}';

  // ---- Period filter (Today / This Week / This Month) ----
  static const List<String> _periods = ['Today', 'This Week', 'This Month'];
  final RxString _period = 'This Week'.obs;

  DateTimeRange _rangeFor(String p) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (p) {
      case 'Today':
        return DateTimeRange(start: today, end: today);
      case 'This Month':
        return DateTimeRange(
          start: DateTime(now.year, now.month, 1),
          end: DateTime(now.year, now.month + 1, 0),
        );
      case 'This Week':
      default:
        final monday = today.subtract(Duration(days: today.weekday - 1));
        return DateTimeRange(
          start: monday,
          end: monday.add(const Duration(days: 6)),
        );
    }
  }

  Future<void> _applyPeriod(String p) async {
    _period.value = p;
    final r = _rangeFor(p);
    c.fromDate.value = r.start;
    c.toDate.value = r.end;
    await c.applyFilters(
      bookingTypeValue: c.bookingType.value,
      paymentModeValues: c.paymentModes.toList(growable: false),
      statusValues: c.statuses.toList(growable: false),
      transactionTypeValues: c.transactionTypes.toList(growable: false),
    );
  }

  // Small period dropdown chip (Today / This Week / This Month).
  Widget _periodDropdown() {
    return Obx(() {
      return PopupMenuButton<String>(
        onSelected: _applyPeriod,
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        offset: const Offset(0, 42),
        itemBuilder: (_) => _periods
            .map(
              (p) => PopupMenuItem<String>(
                value: p,
                height: 42,
                child: Text(
                  p,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: _period.value == p ? primaryColor : navy,
                  ),
                ),
              ),
            )
            .toList(),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white.withValues(alpha: 0.20)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _period.value,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 3),
              const Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 18,
                color: Colors.white,
              ),
            ],
          ),
        ),
      );
    });
  }

  String _weekLabel(DateTimeRange w) {
    final s = w.start, e = w.end;
    return s.month == e.month
        ? '${s.day}-${e.day} ${_mon[e.month - 1]}'
        : '${s.day} ${_mon[s.month - 1]}-${e.day} ${_mon[e.month - 1]}';
  }

  // Sum item amounts per weekday (Mon=0..Sun=6) within [w].
  List<double> _dailyTotals(DateTimeRange w) {
    final t = List<double>.filled(7, 0);
    for (final it in c.items) {
      final dt = DateTime.tryParse(it.createdAtIso)?.toLocal();
      if (dt == null) continue;
      final d = DateTime(dt.year, dt.month, dt.day);
      if (d.isBefore(w.start) || d.isAfter(w.end)) continue;
      final idx = d.weekday - 1;
      if (idx >= 0 && idx < 7) t[idx] += double.tryParse(it.amount) ?? 0;
    }
    return t;
  }

  String _periodSubtitle(String p, DateTimeRange r) {
    switch (p) {
      case 'Today':
        return 'Today, ${r.start.day} ${_mon[r.start.month - 1]}';
      case 'This Month':
        return '${_mon[r.start.month - 1]} ${r.start.year}';
      case 'This Week':
      default:
        return _weekLabel(r);
    }
  }

  // Premium dark hero card: label + period pill + big amount + the chart, all in
  // one elevated black card (clean, modern fintech look).
  Widget _heroCard(List<double> totals, DateTimeRange range, String period) {
    final total = totals.fold<double>(0, (a, b) => a + b);
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2A2D36), Color(0xFF141519)],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 34,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'YOUR EARNINGS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.3,
                  color: Colors.white.withValues(alpha: 0.55),
                ),
              ),
              const Spacer(),
              _periodDropdown(),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            _money(total),
            style: const TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: -1.4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _periodSubtitle(period, range),
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 24),
          _barChart(totals, range, showDates: period != 'This Month', onDark: true),
        ],
      ),
    );
  }

  // Weekly bars + baseline. Tallest day gets a soft value chip. `onDark` renders
  // white bars/labels for the dark hero card; otherwise dark bars on light.
  Widget _barChart(
    List<double> totals,
    DateTimeRange w, {
    bool showDates = true,
    bool onDark = false,
  }) {
    final maxV = totals.fold<double>(0, (a, b) => b > a ? b : a);
    final hasData = maxV > 0;
    int peak = 0;
    for (int i = 1; i < 7; i++) {
      if (totals[i] > totals[peak]) peak = i;
    }
    const chartH = 130.0;
    final barColor = onDark ? Colors.white : navy;
    final dateColor = onDark ? Colors.white : navy;
    final wdColor =
        onDark ? Colors.white.withValues(alpha: 0.55) : textGrey;
    final baseLine =
        onDark ? Colors.white.withValues(alpha: 0.14) : lineColor;

    return Column(
      children: [
        // Bars (with a value chip over the tallest).
        SizedBox(
          height: chartH + 26,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(7, (i) {
              final v = totals[i];
              final frac = hasData ? (v / maxV) : 0.0;
              final barH = (hasData && v > 0) ? (8 + frac * (chartH - 8)) : 0.0;
              final isPeak = hasData && i == peak && v > 0;
              return Expanded(
                child: SizedBox(
                  height: chartH + 26,
                  child: Stack(
                    alignment: Alignment.bottomCenter,
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 14,
                        height: barH,
                        decoration: BoxDecoration(
                          color: barColor,
                          borderRadius: BorderRadius.circular(7),
                        ),
                      ),
                      if (isPeak)
                        Positioned(
                          bottom: barH + 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: onDark ? Colors.white : navy,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _money(v),
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w900,
                                color: onDark ? navy : Colors.white,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
        Container(height: 1, color: baseLine),
        const SizedBox(height: 9),
        // Labels row (aligned to the bars above).
        Row(
          children: List.generate(7, (i) {
            final d = w.start.add(Duration(days: i));
            return Expanded(
              child: Column(
                children: [
                  if (showDates) ...[
                    Text(
                      '${d.day}',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: dateColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _wdFull[i],
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: wdColor,
                      ),
                    ),
                  ] else
                    Text(
                      _wdFull[i],
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: dateColor,
                      ),
                    ),
                ],
              ),
            );
          }),
        ),
      ],
    );
  }

  Future<void> _openFilters() async {
    final bookingTypes = const ['All', 'Ride', 'Parcel'];
    final paymentModes = const ['All', 'WALLET', 'CASH', 'CARD'];
    final statuses = const ['All', 'PAID', 'PENDING'];
    final transactionTypes = const [
      'All',
      'CASH_COMMISSION',
      'RIDE_EARNING',
      'PACKAGE_EARNING',
    ];

    String bt = c.bookingType.value.trim().isEmpty ? 'All' : c.bookingType.value;
    String pm = c.paymentModes.isNotEmpty ? c.paymentModes.first : 'All';
    String st = c.statuses.isNotEmpty ? c.statuses.first : 'All';
    String tt = c.transactionTypes.isNotEmpty ? c.transactionTypes.first : 'All';

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        Widget dropdown({
          required String label,
          required String value,
          required List<String> items,
          required ValueChanged<String> onChanged,
        }) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: blackColor,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: value,
                items: items
                    .map((e) => DropdownMenuItem<String>(
                          value: e,
                          child: Text(e),
                        ))
                    .toList(),
                onChanged: (v) {
                  if (v != null) onChanged(v);
                },
                decoration: InputDecoration(
                  filled: true,
                  fillColor: bgColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          );
        }

        return SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              18,
              14,
              18,
              18 + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: StatefulBuilder(
              builder: (context, setModal) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 42,
                        height: 5,
                        decoration: BoxDecoration(
                          color: lineColor,
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Filter Earnings',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: blackColor,
                      ),
                    ),
                    const SizedBox(height: 16),
                    dropdown(
                      label: 'Booking Type',
                      value: bt,
                      items: bookingTypes,
                      onChanged: (v) => setModal(() => bt = v),
                    ),
                    const SizedBox(height: 12),
                    dropdown(
                      label: 'Payment Mode',
                      value: pm,
                      items: paymentModes,
                      onChanged: (v) => setModal(() => pm = v),
                    ),
                    const SizedBox(height: 12),
                    dropdown(
                      label: 'Status',
                      value: st,
                      items: statuses,
                      onChanged: (v) => setModal(() => st = v),
                    ),
                    const SizedBox(height: 12),
                    dropdown(
                      label: 'Transaction Type',
                      value: tt,
                      items: transactionTypes,
                      onChanged: (v) => setModal(() => tt = v),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: blackColor,
                              side: BorderSide(color: lineColor),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
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

                              selectedTab.value = bt == 'Ride'
                                  ? 1
                                  : bt == 'Parcel'
                                      ? 2
                                      : 0;

                              await c.applyFilters(
                                bookingTypeValue: bt == 'All' ? '' : bt,
                                paymentModeValues: pm == 'All' ? const [] : [pm],
                                statusValues: st == 'All' ? const [] : [st],
                                transactionTypeValues: tt == 'All' ? const [] : [tt],
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: lightPrimary,
                              foregroundColor: primaryColor,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
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
    final bookingId =
        it.booking.bookingId.trim().isEmpty ? '-' : it.booking.bookingId;

    return Container(
      margin: const EdgeInsets.only(bottom: 13),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 22,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: lightPrimary,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.call_made_rounded,
              color: primaryColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        it.title.isNotEmpty ? it.title : 'Earning',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: blackColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                      Text(
                        _rupee(it.amount),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: primaryColor,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  '$bookingId • ${it.type}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: textGrey,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'From ${it.booking.pickupAddress}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: textGrey,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'To ${it.booking.dropAddress}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: textGrey,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyView() {
    final hasError = c.errorText.value.trim().isNotEmpty;
    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: hasError
          ? EmptyStateView(
              image: AppImages.errorServer,
              title: "Something went wrong",
              subtitle:
                  "We couldn't load your earnings. Please try again.",
              onRetry: () => c.refreshList(),
            )
          : EmptyStateView(
              image: AppImages.emptyEarnings,
              title: "No earnings yet",
              subtitle:
                  "Your earnings for the selected filters will appear here.",
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: navy),
        title: const Text(
          'Your earnings',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: navy,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Filter',
            onPressed: _openFilters,
            icon: const Icon(Icons.tune_rounded, color: navy),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Obx(() {
        if (c.isLoading.value && c.items.isEmpty) {
          return SkeletonLoaders.earnings();
        }

        if (c.errorText.value.isNotEmpty && c.items.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Text(
                c.errorText.value,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          );
        }

        final period = _period.value;
        final range = _rangeFor(period);
        final totals = _dailyTotals(range);

        return RefreshIndicator(
          color: primaryColor,
          onRefresh: () => c.refreshList(),
          child: ListView(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(18, 6, 18, 28),
            children: [
              _heroCard(totals, range, period),
              const SizedBox(height: 24),
              Text(
                'DETAILS',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                  color: textGrey,
                ),
              ),
              const SizedBox(height: 12),
              if (c.items.isEmpty && !c.isLoading.value)
                _emptyView()
              else
                ...List.generate(c.items.length, _earningItemTile),
              if (c.isLoadingMore.value)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(child: HopprCircularLoader()),
                ),
            ],
          ),
        );
      }),
    );
  }
}

// import 'package:flutter/material.dart';
// import 'package:get/get.dart';
// import 'package:hopper/Presentation/Drawer/controller/driver_earnings_controller.dart';
// import 'package:hopper/utils/widgets/hoppr_circular_loader.dart';

// class DriverEarningsScreen extends StatefulWidget {
//   const DriverEarningsScreen({super.key});

//   @override
//   State<DriverEarningsScreen> createState() => _DriverEarningsScreenState();
// }

// class _DriverEarningsScreenState extends State<DriverEarningsScreen> {
//   late final DriverEarningsController c;
//   final ScrollController _scroll = ScrollController();
//   final RxInt selectedTab = 0.obs;

// static const Color bgColor = Color(0xFFE9EEF8);  
// static const Color cardColor = Color(0xFFFFFFFF);
//   static const Color blackColor = Color(0xFF111827);
//   static const Color blueColor = Color(0xFF2563EB);
//   static const Color lightBlue = Color(0xFF60A5FA);
//   static const Color textGrey = Color(0xFF6B7280);
//   static const Color cardBorder = Color(0x0D111827);
//   static const Color cardShadow = Color(0x0A111827);

//   final List<Map<String, String>> tabs = const [
//     {'title': 'All', 'type': ''},
//     {'title': 'Ride', 'type': 'Ride'},
//     {'title': 'Package', 'type': 'Package'},
//   ];

//   @override
//   void initState() {
//     super.initState();
//     c = Get.put(DriverEarningsController());
//     _scroll.addListener(_onScroll);
//   }

//   void _onScroll() {
//     if (!_scroll.hasClients) return;
//     if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 240) {
//       c.loadMore();
//     }
//   }

//   @override
//   void dispose() {
//     _scroll.removeListener(_onScroll);
//     _scroll.dispose();
//     if (Get.isRegistered<DriverEarningsController>()) {
//       Get.delete<DriverEarningsController>();
//     }
//     super.dispose();
//   }

//   static String _rupee(String amount) => '\u20A6$amount';

//   static String _formatDateTime(String iso) {
//     final dt = DateTime.tryParse(iso);
//     if (dt == null) return '';
//     final d = dt.toLocal();
//     const months = <String>[
//       'Jan',
//       'Feb',
//       'Mar',
//       'Apr',
//       'May',
//       'Jun',
//       'Jul',
//       'Aug',
//       'Sep',
//       'Oct',
//       'Nov',
//       'Dec',
//     ];
//     final hh = d.hour % 12 == 0 ? 12 : d.hour % 12;
//     final mm = d.minute.toString().padLeft(2, '0');
//     final ap = d.hour >= 12 ? 'PM' : 'AM';
//     return '${d.day} ${months[d.month - 1]} • $hh:$mm $ap';
//   }

//   static Color _statusColor(String raw) {
//     final s = raw.trim().toUpperCase();
//     if (s == 'PAID' || s == 'SUCCESS') return const Color(0xFF16A34A);
//     if (s == 'PENDING') return const Color(0xFFF59E0B);
//     if (s == 'FAILED') return const Color(0xFFEF4444);
//     return const Color(0xFF64748B);
//   }

//   Widget _balanceCard(dynamic s) {
//     return Container(
//       padding: const EdgeInsets.all(22),
//       decoration: BoxDecoration(
//         borderRadius: BorderRadius.circular(30),
//         gradient: const LinearGradient(
//           begin: Alignment.topLeft,
//           end: Alignment.bottomRight,
//           colors: [blackColor, blueColor, lightBlue],
//         ),
//         boxShadow: [
//           BoxShadow(
//             color: blueColor.withValues(alpha: 0.24),
//             blurRadius: 34,
//             offset: const Offset(0, 16),
//           ),
//         ],
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           const Row(
//             children: [
//               Text(
//                 'Available Balance',
//                 style: TextStyle(
//                   fontSize: 13,
//                   fontWeight: FontWeight.w800,
//                   color: Colors.white70,
//                 ),
//               ),
//               Spacer(),
//               _StatusPill(),
//             ],
//           ),
//           const SizedBox(height: 14),
//           Text(
//             _rupee(s.availableBalance),
//             style: const TextStyle(
//               fontSize: 36,
//               fontWeight: FontWeight.w900,
//               color: Colors.white,
//               letterSpacing: -1.2,
//             ),
//           ),
//           const SizedBox(height: 20),
//           Row(
//             children: [
//               Expanded(child: _smallStat('Cash on Hand', _rupee(s.cashOnHand))),
//               const SizedBox(width: 12),
//               Expanded(child: _smallStat('Withdrawals', _rupee(s.totalWithdrawals))),
//             ],
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _smallStat(String title, String value) {
//     return Container(
//       padding: const EdgeInsets.all(15),
//       decoration: BoxDecoration(
//         color: Colors.white.withValues(alpha: 0.18),
//         borderRadius: BorderRadius.circular(22),
//         border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Text(title,
//               maxLines: 1,
//               overflow: TextOverflow.ellipsis,
//               style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white70)),
//           const SizedBox(height: 7),
//           Text(value,
//               maxLines: 1,
//               overflow: TextOverflow.ellipsis,
//               style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Colors.white)),
//         ],
//       ),
//     );
//   }

//   Widget _filterTabs() {
//     return Obx(() {
//       // Read the observable inside this Obx scope. If we only read it inside
//       // ListView's itemBuilder (lazy build), GetX may throw "improper use".
//       final selected = selectedTab.value;
//       return Container(
//         padding: const EdgeInsets.all(6),
//         decoration: BoxDecoration(
//           color: Colors.white,
//           borderRadius: BorderRadius.circular(18),
//           border: Border.all(color: cardBorder),
//           boxShadow: const [
//             BoxShadow(
//               color: cardShadow,
//               blurRadius: 22,
//               offset: Offset(0, 10),
//             ),
//           ],
//         ),
//         child: Row(
//           children: List.generate(tabs.length, (index) {
//             final isSelected = selected == index;
//             return Expanded(
//               child: InkWell(
//                 borderRadius: BorderRadius.circular(14),
//                 onTap: () async {
//                   selectedTab.value = index;
//                   final type = tabs[index]['type'] ?? '';

//                   if (type.isEmpty) {
//                     await c.refreshList();
//                   } else {
//                     await c.applyFilters(
//                       bookingTypeValue: type,
//                       paymentModeValue: c.paymentMode.value,
//                       statusValue: c.status.value,
//                       transactionTypeValue: c.transactionType.value,
//                     );
//                   }
//                 },
//                 child: AnimatedContainer(
//                   duration: const Duration(milliseconds: 220),
//                   curve: Curves.easeOut,
//                   padding: const EdgeInsets.symmetric(vertical: 10),
//                   decoration: BoxDecoration(
//                     color: isSelected ? const Color(0xFF111827) : Colors.transparent,
//                     borderRadius: BorderRadius.circular(14),
//                   ),
//                   child: Center(
//                     child: Text(
//                       tabs[index]['title'] ?? '',
//                       style: TextStyle(
//                         color: isSelected ? Colors.white : const Color(0xFF111827),
//                         fontSize: 13,
//                         fontWeight: FontWeight.w900,
//                       ),
//                     ),
//                   ),
//                 ),
//               ),
//             );
//           }),
//         ),
//       );
//     });
//   }

//   Widget _dateAndFilterRow() {
//     return Obx(() {
//       final fd = c.fromDate.value;
//       final td = c.toDate.value;

//       String dateText = 'All Time';
//       if (fd != null && td != null) {
//         dateText =
//             '${fd.day.toString().padLeft(2, '0')}-${fd.month.toString().padLeft(2, '0')} → '
//             '${td.day.toString().padLeft(2, '0')}-${td.month.toString().padLeft(2, '0')}';
//       }

//       return Row(
//         children: [
//           Expanded(
//             child: _actionChip(
//               icon: Icons.calendar_month_rounded,
//               text: dateText,
//               onTap: () => c.pickDateRange(context),
//             ),
//           ),
//           const SizedBox(width: 10),
//           Expanded(
//             child: _actionChip(
//               icon: Icons.tune_rounded,
//               text: 'More Filter',
//               onTap: _openFilters,
//             ),
//           ),
//         ],
//       );
//     });
//   }

//   Widget _actionChip({
//     required IconData icon,
//     required String text,
//     required VoidCallback onTap,
//   }) {
//     return InkWell(
//       borderRadius: BorderRadius.circular(20),
//       onTap: onTap,
//       child: Container(
//         padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
//         decoration: BoxDecoration(
//           color: Colors.white,
//           borderRadius: BorderRadius.circular(20),
//           border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
//           boxShadow: [
//             BoxShadow(
//               color: Colors.black.withValues(alpha: 0.035),
//               blurRadius: 20,
//               offset: const Offset(0, 8),
//             ),
//           ],
//         ),
//         child: Row(
//           children: [
//             Icon(icon, size: 18, color: blueColor),
//             const SizedBox(width: 8),
//             Expanded(
//               child: Text(
//                 text,
//                 maxLines: 1,
//                 overflow: TextOverflow.ellipsis,
//                 style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: blackColor),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Future<void> _openFilters() async {
//     final bookingTypes = const ['Ride', 'Package'];
//     final paymentModes = const ['WALLET', 'CASH', 'CARD'];
//     final statuses = const ['PAID', 'PENDING'];
//     final transactionTypes = const ['CASH_COMMISSION', 'RIDE_EARNING', 'PACKAGE_EARNING'];

//     String bt = c.bookingType.value;
//     String pm = c.paymentMode.value;
//     String st = c.status.value;
//     String tt = c.transactionType.value;

//     await showModalBottomSheet<void>(
//       context: context,
//       isScrollControlled: true,
//       backgroundColor: Colors.white,
//       shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
//       builder: (context) {
//         Widget dropdown({
//           required String label,
//           required String value,
//           required List<String> items,
//           required ValueChanged<String> onChanged,
//         }) {
//           return Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Text(label,
//                   style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: blackColor)),
//               const SizedBox(height: 8),
//               DropdownButtonFormField<String>(
//                 value: value,
//                 items: items.map((e) => DropdownMenuItem<String>(value: e, child: Text(e))).toList(),
//                 onChanged: (v) {
//                   if (v != null) onChanged(v);
//                 },
//                 decoration: InputDecoration(
//                   filled: true,
//                   fillColor: bgColor,
//                   border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
//                   contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
//                 ),
//               ),
//             ],
//           );
//         }

//         return SafeArea(
//           top: false,
//           child: Padding(
//             padding: EdgeInsets.fromLTRB(18, 14, 18, 18 + MediaQuery.of(context).viewInsets.bottom),
//             child: StatefulBuilder(
//               builder: (context, setModal) {
//                 return Column(
//                   mainAxisSize: MainAxisSize.min,
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Center(
//                       child: Container(
//                         width: 42,
//                         height: 5,
//                         decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(20)),
//                       ),
//                     ),
//                     const SizedBox(height: 18),
//                     const Text('Filter Earnings',
//                         style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: blackColor)),
//                     const SizedBox(height: 16),
//                     dropdown(label: 'Booking Type', value: bt, items: bookingTypes, onChanged: (v) => setModal(() => bt = v)),
//                     const SizedBox(height: 12),
//                     dropdown(label: 'Payment Mode', value: pm, items: paymentModes, onChanged: (v) => setModal(() => pm = v)),
//                     const SizedBox(height: 12),
//                     dropdown(label: 'Status', value: st, items: statuses, onChanged: (v) => setModal(() => st = v)),
//                     const SizedBox(height: 12),
//                     dropdown(label: 'Transaction Type', value: tt, items: transactionTypes, onChanged: (v) => setModal(() => tt = v)),
//                     const SizedBox(height: 18),
//                     Row(
//                       children: [
//                         Expanded(
//                           child: OutlinedButton(
//                             onPressed: () => Navigator.pop(context),
//                             style: OutlinedButton.styleFrom(
//                               padding: const EdgeInsets.symmetric(vertical: 14),
//                               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//                             ),
//                             child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w900)),
//                           ),
//                         ),
//                         const SizedBox(width: 12),
//                         Expanded(
//                           child: ElevatedButton(
//                             onPressed: () async {
//                               Navigator.pop(context);

//                               selectedTab.value = bt == 'Ride'
//                                   ? 1
//                                   : bt == 'Package'
//                                       ? 2
//                                       : 0;

//                               await c.applyFilters(
//                                 bookingTypeValue: bt,
//                                 paymentModeValue: pm,
//                                 statusValue: st,
//                                 transactionTypeValue: tt,
//                               );
//                             },
//                             style: ElevatedButton.styleFrom(
//                               backgroundColor: blueColor,
//                               foregroundColor: Colors.white,
//                               padding: const EdgeInsets.symmetric(vertical: 14),
//                               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//                             ),
//                             child: const Text('Apply', style: TextStyle(fontWeight: FontWeight.w900)),
//                           ),
//                         ),
//                       ],
//                     ),
//                   ],
//                 );
//               },
//             ),
//           ),
//         );
//       },
//     );
//   }

//   Widget _earningItemTile(int index) {
//     final it = c.items[index];
//     final bookingId = it.booking.bookingId.trim().isEmpty ? '-' : it.booking.bookingId;
//     final when = _formatDateTime(it.createdAtIso);
//     final status = it.status.trim().isEmpty ? it.ridePaymentStatus : it.status;
//     final statusColor = _statusColor(status);
//     final customerName = it.customer.name.trim().isEmpty ? 'Customer' : it.customer.name.trim();

//     return Container(
//       margin: const EdgeInsets.only(bottom: 13),
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(24),
//         border: Border.all(color: cardBorder),
//         boxShadow: const [
//           BoxShadow(
//             color: cardShadow,
//             blurRadius: 22,
//             offset: Offset(0, 9),
//           ),
//         ],
//       ),
//       child: Row(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Container(
//             width: 42,
//             height: 42,
//             decoration: BoxDecoration(
//               gradient: const LinearGradient(colors: [blackColor, blueColor]),
//               borderRadius: BorderRadius.circular(16),
//             ),
//             child: const Icon(Icons.call_made_rounded, color: Colors.white, size: 20),
//           ),
//           const SizedBox(width: 13),
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Row(
//                   children: [
//                     Expanded(
//                       child: Text(
//                         it.title.isNotEmpty ? it.title : 'Earning',
//                         maxLines: 1,
//                         overflow: TextOverflow.ellipsis,
//                         style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: blackColor),
//                       ),
//                     ),
//                     const SizedBox(width: 8),
//                     Text(
//                       _rupee(it.amount),
//                       style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: blueColor),
//                     ),
//                   ],
//                 ),
//                 const SizedBox(height: 5),
//                 Row(
//                   children: [
//                     Expanded(
//                       child: Text(
//                         '#$bookingId • ${it.booking.bookingType.isNotEmpty ? it.booking.bookingType : it.type}',
//                         maxLines: 1,
//                         overflow: TextOverflow.ellipsis,
//                         style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: textGrey),
//                       ),
//                     ),
//                     if (status.trim().isNotEmpty)
//                       Container(
//                         padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
//                         decoration: BoxDecoration(
//                           color: statusColor.withValues(alpha: 0.12),
//                           borderRadius: BorderRadius.circular(99),
//                         ),
//                         child: Text(
//                           status.toUpperCase(),
//                           style: TextStyle(
//                             fontSize: 11,
//                             fontWeight: FontWeight.w900,
//                             color: statusColor,
//                             letterSpacing: 0.2,
//                           ),
//                         ),
//                       ),
//                   ],
//                 ),
//                 if (when.isNotEmpty) ...[
//                   const SizedBox(height: 6),
//                   Text(
//                     when,
//                     maxLines: 1,
//                     overflow: TextOverflow.ellipsis,
//                     style: TextStyle(
//                       fontSize: 12,
//                       fontWeight: FontWeight.w700,
//                       color: textGrey.withValues(alpha: 0.95),
//                     ),
//                   ),
//                 ],
//                 const SizedBox(height: 10),
//                 Row(
//                   children: [
//                     const Icon(Icons.person_rounded, size: 16, color: textGrey),
//                     const SizedBox(width: 6),
//                     Expanded(
//                       child: Text(
//                         customerName,
//                         maxLines: 1,
//                         overflow: TextOverflow.ellipsis,
//                         style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: textGrey),
//                       ),
//                     ),
//                   ],
//                 ),
//                 const SizedBox(height: 10),
//                 Row(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Container(
//                       width: 8,
//                       height: 8,
//                       margin: const EdgeInsets.only(top: 4),
//                       decoration: const BoxDecoration(color: Color(0xFF16A34A), shape: BoxShape.circle),
//                     ),
//                     const SizedBox(width: 8),
//                     Expanded(
//                       child: Text(
//                         it.booking.pickupAddress.isNotEmpty ? it.booking.pickupAddress : 'Pickup address',
//                         maxLines: 2,
//                         overflow: TextOverflow.ellipsis,
//                         style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: textGrey),
//                       ),
//                     ),
//                   ],
//                 ),
//                 const SizedBox(height: 8),
//                 Row(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Container(
//                       width: 8,
//                       height: 8,
//                       margin: const EdgeInsets.only(top: 4),
//                       decoration: const BoxDecoration(color: Color(0xFFEF4444), shape: BoxShape.circle),
//                     ),
//                     const SizedBox(width: 8),
//                     Expanded(
//                       child: Text(
//                         it.booking.dropAddress.isNotEmpty ? it.booking.dropAddress : 'Drop address',
//                         maxLines: 2,
//                         overflow: TextOverflow.ellipsis,
//                         style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: textGrey),
//                       ),
//                     ),
//                   ],
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _emptyView() {
//     return Padding(
//       padding: const EdgeInsets.only(top: 60, bottom: 40),
//       child: Center(
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             Container(
//               width: 66,
//               height: 66,
//               decoration: BoxDecoration(
//                 color: const Color(0xFF111827).withValues(alpha: 0.06),
//                 borderRadius: BorderRadius.circular(22),
//               ),
//               child: const Icon(
//                 Icons.receipt_long_rounded,
//                 size: 30,
//                 color: Color(0xFF111827),
//               ),
//             ),
//             const SizedBox(height: 12),
//             const Text(
//               'No earnings found',
//               style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: blackColor),
//             ),
//             const SizedBox(height: 6),
//             Text(
//               'Try changing the filters or date range.',
//               style: TextStyle(fontWeight: FontWeight.w800, color: textGrey.withValues(alpha: 0.9)),
//             ),
//             const SizedBox(height: 14),
//             OutlinedButton.icon(
//               onPressed: () async {
//                 selectedTab.value = 0;
//                 await c.refreshList();
//               },
//               style: OutlinedButton.styleFrom(
//                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
//               ),
//               icon: const Icon(Icons.refresh_rounded),
//               label: const Text('Reset', style: TextStyle(fontWeight: FontWeight.w900)),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: bgColor,
//       appBar: AppBar(
//         backgroundColor: bgColor,
//         elevation: 0,
//         centerTitle: false,
//         actions: [
//           IconButton(
//             tooltip: 'Filters',
//             onPressed: _openFilters,
//             icon: const Icon(Icons.tune_rounded, color: blackColor),
//           ),
//           const SizedBox(width: 4),
//         ],
//         title: const Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(
//               'Driver Wallet',
//               style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: textGrey),
//             ),
//             SizedBox(height: 2),
//             Text(
//               'Earnings',
//               style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: blackColor),
//             ),
//           ],
//         ),
//       ),
//       body: Obx(() {
//         if (c.isLoading.value && c.items.isEmpty) {
//           return const Center(child: HopprCircularLoader());
//         }

//         if (c.errorText.value.isNotEmpty && c.items.isEmpty) {
//           return Center(
//             child: Padding(
//               padding: const EdgeInsets.all(18),
//               child: Text(
//                 c.errorText.value,
//                 textAlign: TextAlign.center,
//                 style: const TextStyle(fontWeight: FontWeight.w800),
//               ),
//             ),
//           );
//         }

//         final s = c.summary.value;

//         return RefreshIndicator(
//           onRefresh: () => c.refreshList(),
//           child: ListView(
//             controller: _scroll,
//             padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
//             children: [
//               if (s != null) ...[
//                 _balanceCard(s),
//                 const SizedBox(height: 18),
//               ],
//               _filterTabs(),
//               const SizedBox(height: 14),
//               _dateAndFilterRow(),
//               const SizedBox(height: 24),
//               const Text(
//                 'Recent Activity',
//                 style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: blackColor),
//               ),
//               const SizedBox(height: 14),
//               if (c.items.isEmpty && !c.isLoading.value)
//                 _emptyView()
//               else
//                 ...List.generate(c.items.length, _earningItemTile),
//               if (c.isLoadingMore.value)
//                 const Padding(
//                   padding: EdgeInsets.symmetric(vertical: 12),
//                   child: Center(child: HopprCircularLoader()),
//                 ),
//             ],
//           ),
//         );
//       }),
//     );
//   }
// }

// class _StatusPill extends StatelessWidget {
//   const _StatusPill();

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
//       decoration: BoxDecoration(
//         color: Colors.white24,
//         borderRadius: BorderRadius.circular(30),
//       ),
//       child: const Text(
//         'Active',
//         style: TextStyle(
//           color: Colors.white,
//           fontSize: 11,
//           fontWeight: FontWeight.w900,
//         ),
//       ),
//     );
//   }
// }



 
