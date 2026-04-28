import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:hopper/utils/map/shared_map.dart';

extension _ColorOpacity on Color {
  Color o(double opacity) => withValues(alpha: opacity.clamp(0.0, 1.0));
}

enum DemandOpportunityCategory { delivery, service, jobs, errands }

class _Palette {
  const _Palette({
    required this.isDark,
    required this.bgGradient,
    required this.cardBg,
    required this.cardBorder,
    required this.shadowColor,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.iconColor,
  });

  final bool isDark;
  final List<Color> bgGradient;
  final Color cardBg;
  final Color cardBorder;
  final Color shadowColor;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color iconColor;

  static _Palette light() => _Palette(
        isDark: false,
        bgGradient: const [
          Color(0xFFF6F8FF),
          Color(0xFFEFF3FF),
          Color(0xFFEAF0FF),
        ],
        cardBg: Colors.white,
        cardBorder: const Color(0xFFE2E8F0),
        shadowColor: const Color(0xFF0B1220).o(0.08),
        textPrimary: const Color(0xFF0B1220),
        textSecondary: const Color(0xFF334155),
        textTertiary: const Color(0xFF64748B),
        iconColor: const Color(0xFF0B1220),
      );

  static _Palette dark() => _Palette(
        isDark: true,
        bgGradient: const [
          Color(0xFF0B1220),
          Color(0xFF0B1220),
          Color(0xFF060A12),
        ],
        cardBg: const Color(0xFF0F172A),
        cardBorder: Colors.white.o(0.12),
        shadowColor: Colors.black.o(0.35),
        textPrimary: Colors.white,
        textSecondary: Colors.white70,
        textTertiary: Colors.white54,
        iconColor: Colors.white,
      );
}

class DemandOpportunity {
  const DemandOpportunity({
    required this.id,
    required this.title,
    required this.location,
    required this.distanceKm,
    required this.earningsLabel,
    required this.category,
  });

  final String id;
  final String title;
  final LatLng location;
  final double distanceKm;
  final String earningsLabel;
  final DemandOpportunityCategory category;
}

class DemandOpportunityHomeScreen extends StatefulWidget {
  const DemandOpportunityHomeScreen({
    super.key,
    this.userName = 'Aarav',
    this.forceDarkUi,
  });

  final String userName;
  final bool? forceDarkUi;

  @override
  State<DemandOpportunityHomeScreen> createState() =>
      _DemandOpportunityHomeScreenState();
}

class _DemandOpportunityHomeScreenState extends State<DemandOpportunityHomeScreen>
    with SingleTickerProviderStateMixin {
  static const _primaryGlow = Color(0xFF00C2FF); // electric blue (clean)
  static const _accentGlow = Color(0xFF22C55E); // subtle green

  final _searchController = TextEditingController();
  Timer? _searchDebounce;

  GoogleMapController? _mapController;

  DemandOpportunity? _selected;

  final _sheetController = DraggableScrollableController();
  DemandOpportunityCategory? _categoryFilter; // null = all

  final List<DemandOpportunity> _opportunities = const [
    DemandOpportunity(
      id: 'op_1',
      title: 'Express Delivery • Groceries',
      location: LatLng(12.9716, 77.5946),
      distanceKm: 2.3,
      earningsLabel: '₹320',
      category: DemandOpportunityCategory.delivery,
    ),
    DemandOpportunity(
      id: 'op_2',
      title: 'AC Repair • Quick Service',
      location: LatLng(12.9782, 77.6070),
      distanceKm: 3.8,
      earningsLabel: '₹750',
      category: DemandOpportunityCategory.service,
    ),
    DemandOpportunity(
      id: 'op_3',
      title: 'Part-time Shift • 2 hours',
      location: LatLng(12.9650, 77.5865),
      distanceKm: 1.6,
      earningsLabel: '₹500',
      category: DemandOpportunityCategory.jobs,
    ),
    DemandOpportunity(
      id: 'op_4',
      title: 'Errand • Documents Pickup',
      location: LatLng(12.9620, 77.6008),
      distanceKm: 4.1,
      earningsLabel: '₹280',
      category: DemandOpportunityCategory.errands,
    ),
  ];

  final Map<DemandOpportunityCategory, BitmapDescriptor> _markerIcons = {};
  final Map<DemandOpportunityCategory, BitmapDescriptor> _markerIconsSelected =
      {};

  @override
  void initState() {
    super.initState();
    _selected = _opportunities.first;
    _searchController.addListener(_onSearchChanged);
    unawaited(_prebuildMarkerIcons());
  }

  @override
  void didUpdateWidget(covariant DemandOpportunityHomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    try {
      _mapController?.dispose();
    } catch (_) {}
    _sheetController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 220), () {
      if (!mounted) return;
      setState(() {});
    });
  }

  Future<void> _prebuildMarkerIcons() async {
    for (final category in DemandOpportunityCategory.values) {
      final baseColor = _categoryColor(category);
      _markerIcons[category] = await _buildPinMarker(
        category: category,
        coreColor: baseColor,
        glowColor: baseColor.o(0.38),
        size: 92,
        selected: false,
      );
      _markerIconsSelected[category] = await _buildPinMarker(
        category: category,
        coreColor: baseColor,
        glowColor: _accentGlow.o(0.55),
        size: 112,
        selected: true,
      );
      if (!mounted) return;
      setState(() {});
    }
  }

  Future<BitmapDescriptor> _buildPinMarker({
    required DemandOpportunityCategory category,
    required Color coreColor,
    required Color glowColor,
    required int size,
    required bool selected,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final s = size.toDouble();
    final center = Offset(s / 2, s / 2);

    final glowPaint = Paint()
      ..color = glowColor
      ..maskFilter = ui.MaskFilter.blur(
        ui.BlurStyle.normal,
        selected ? 22 : 16,
      );

    final shadowPaint = Paint()
      ..color = Colors.black.o(selected ? 0.55 : 0.45)
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 14);

    final pinW = s * 0.48;
    final pinH = s * 0.60;
    final topY = center.dy - (pinH * 0.32);
    final bottomY = center.dy + (pinH * 0.38);

    final pinPath = Path()
      ..moveTo(center.dx, bottomY)
      ..quadraticBezierTo(
        center.dx - pinW * 0.48,
        center.dy + pinH * 0.10,
        center.dx - pinW * 0.40,
        center.dy - pinH * 0.05,
      )
      ..cubicTo(
        center.dx - pinW * 0.36,
        topY,
        center.dx + pinW * 0.36,
        topY,
        center.dx + pinW * 0.40,
        center.dy - pinH * 0.05,
      )
      ..quadraticBezierTo(
        center.dx + pinW * 0.48,
        center.dy + pinH * 0.10,
        center.dx,
        bottomY,
      )
      ..close();

    canvas.drawPath(pinPath.shift(const Offset(0, 4)), shadowPaint);
    canvas.drawPath(pinPath, glowPaint);

    // Solid highlight (no gradients).
    final pinFill = Paint()..color = Colors.white.o(selected ? 0.18 : 0.12);
    canvas.drawPath(pinPath, pinFill);

    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.018
      ..color = Colors.white.o(selected ? 0.34 : 0.24);
    canvas.drawPath(pinPath, borderPaint);

    final corePaint = Paint()..color = coreColor;
    final bubbleCenter = center.translate(0, -s * 0.06);
    canvas.drawCircle(
      bubbleCenter,
      s * (selected ? 0.112 : 0.102),
      corePaint,
    );

    final bubbleBorder = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.018
      ..color = Colors.white.o(selected ? 0.55 : 0.42);
    canvas.drawCircle(
      bubbleCenter,
      s * (selected ? 0.112 : 0.102),
      bubbleBorder,
    );

    final icon = _categoryIcon(category);
    final iconPainter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          fontSize: s * (selected ? 0.14 : 0.13),
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    iconPainter.paint(
      canvas,
      bubbleCenter - Offset(iconPainter.width / 2, iconPainter.height / 2),
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(size, size);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(bytes!.buffer.asUint8List());
  }

  Color _categoryColor(DemandOpportunityCategory category) {
    switch (category) {
      case DemandOpportunityCategory.delivery:
        return _primaryGlow;
      case DemandOpportunityCategory.service:
        return const Color(0xFFB46BFF);
      case DemandOpportunityCategory.jobs:
        return _accentGlow;
      case DemandOpportunityCategory.errands:
        return const Color(0xFFFFC857);
    }
  }

  List<DemandOpportunity> _filteredOps() {
    final q = _searchController.text.toLowerCase().trim();

    Iterable<DemandOpportunity> list =
        _categoryFilter == null
            ? _opportunities
            : _opportunities.where((o) => o.category == _categoryFilter);

    if (q.isNotEmpty) {
      list = list.where((o) => o.title.toLowerCase().contains(q));
    }

    final out = list.toList()
      ..sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
    return out;
  }

  Set<Marker> _buildMarkers() {
    final selectedId = _selected?.id;
    final filtered = _filteredOps();

    return filtered.map((op) {
      final isSelected = op.id == selectedId;
      final icon = (isSelected
              ? _markerIconsSelected[op.category]
              : _markerIcons[op.category]) ??
          BitmapDescriptor.defaultMarkerWithHue(
            isSelected ? BitmapDescriptor.hueAzure : BitmapDescriptor.hueViolet,
          );

      return Marker(
        markerId: MarkerId(op.id),
        position: op.location,
        icon: icon,
        zIndexInt: isSelected ? 10 : 1,
        anchor: const Offset(0.5, 0.5),
        onTap: () => _selectOpportunity(op),
      );
    }).toSet();
  }

  Set<Circle> _buildDemandZones() {
    final selected = _selected;
    if (selected == null) return const <Circle>{};
    final inFilter = _filteredOps().any((o) => o.id == selected.id);
    if (!inFilter) return const <Circle>{};

    final base = _categoryColor(selected.category);
    final prefix = selected.id;

    return {
      Circle(
        circleId: CircleId('${prefix}_z2'),
        center: selected.location,
        radius: 520,
        fillColor: base.o(0.06),
        strokeColor: base.o(0.14),
        strokeWidth: 1,
        zIndex: 1,
      ),
      Circle(
        circleId: CircleId('${prefix}_z1'),
        center: selected.location,
        radius: 260,
        fillColor: base.o(0.10),
        strokeColor: base.o(0.20),
        strokeWidth: 2,
        zIndex: 2,
      ),
    };
  }

  void _selectOpportunity(DemandOpportunity op) {
    setState(() => _selected = op);
    unawaited(_animateTo(op.location));
    unawaited(_expandSheet());
    HapticFeedback.selectionClick();
  }

  Future<void> _expandSheet() async {
    try {
      await _sheetController.animateTo(
        0.40,
        duration: const Duration(milliseconds: 520),
        curve: Curves.easeOutCubic,
      );
    } catch (_) {}
  }

  Future<void> _collapseSheet() async {
    try {
      await _sheetController.animateTo(
        0.22,
        duration: const Duration(milliseconds: 520),
        curve: Curves.easeOutCubic,
      );
    } catch (_) {}
  }

  Future<void> _animateTo(LatLng target) async {
    final controller = _mapController;
    if (controller == null) return;
    await controller.animateCamera(CameraUpdate.newLatLng(target));
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    final greeting = _greetingFor(DateTime.now());
    final palette = (widget.forceDarkUi ?? false) ? _Palette.dark() : _Palette.light();
    final filtered = _filteredOps();

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor:
          palette.isDark ? const Color(0xFF0B1220) : const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          Positioned.fill(
            child: SharedMap(
              initialPosition: const LatLng(12.9716, 77.5946),
              initialZoom: 12.8,
              fitToBounds: false,
              myLocationEnabled: false,
              compassEnabled: false,
              markers: _buildMarkers(),
              circles: _buildDemandZones(),
              onMapCreated: (c) {
                _mapController = c;
              },
              onTap: (_) {
                unawaited(_collapseSheet());
                HapticFeedback.lightImpact();
              },
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _GlassCard(
                    palette: palette,
                    borderRadius: 26,
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    greeting,
                                    style: TextStyle(
                                      color: palette.textSecondary.o(0.90),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    widget.userName,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    filtered.isEmpty
                                        ? 'No opportunities nearby'
                                        : 'Demand Opportunities (${filtered.length})',
                                    style: TextStyle(
                                      color: palette.textTertiary.o(0.95),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            _StatusPill(
                              palette: palette,
                              label: 'Live',
                              color: _accentGlow,
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        _SearchBar(
                          palette: palette,
                          controller: _searchController,
                          onFilterTap: () => HapticFeedback.selectionClick(),
                        ),
                        const SizedBox(height: 12),
                        _CategorySegmentedControl(
                          palette: palette,
                          selected: _categoryFilter,
                          onChanged: (v) => setState(() => _categoryFilter = v),
                        ),
                      ],
                    ),
                  ),

                  const Spacer(),
                ],
              ),
            ),
          ),

          _OpportunityBottomSheet(
            controller: _sheetController,
            opportunities: filtered,
            selected: selected,
            categoryColor: selected == null ? _primaryGlow : _categoryColor(selected.category),
            palette: palette,
            onSelect: _selectOpportunity,
            onAccept: () => HapticFeedback.mediumImpact(),
            onDetails: () => HapticFeedback.selectionClick(),
          ),
        ],
      ),
    );
  }

  String _greetingFor(DateTime now) {
    final hour = now.hour;
    if (hour < 12) return 'Good morning,';
    if (hour < 17) return 'Good afternoon,';
    return 'Good evening,';
  }
}

class _OpportunityBottomSheet extends StatelessWidget {
  const _OpportunityBottomSheet({
    required this.controller,
    required this.opportunities,
    required this.selected,
    required this.categoryColor,
    required this.palette,
    required this.onSelect,
    required this.onAccept,
    required this.onDetails,
  });

  final DraggableScrollableController controller;
  final List<DemandOpportunity> opportunities;
  final DemandOpportunity? selected;
  final Color categoryColor;
  final _Palette palette;
  final ValueChanged<DemandOpportunity> onSelect;
  final VoidCallback onAccept;
  final VoidCallback onDetails;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final bottomPadding = mq.padding.bottom;
    final list = opportunities;
    final sel = selected;
    final selId = sel?.id;
    final hasSelection = selId != null && list.any((e) => e.id == selId);

    return DraggableScrollableSheet(
      controller: controller,
      minChildSize: 0.22,
      initialChildSize: 0.30,
      maxChildSize: 0.55,
      snap: true,
      snapSizes: const [0.22, 0.30, 0.55],
      builder: (context, scrollController) {
        return Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 12 + bottomPadding),
          child: _GlassCard(
            palette: palette,
            borderRadius: 28,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
            child: Column(
              children: [
                Center(
                  child: Container(
                    width: 48,
                    height: 5,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color:
                          palette.isDark
                              ? Colors.white.o(0.16)
                              : Colors.black.o(0.10),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Opportunities',
                        style: TextStyle(
                          color: palette.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                    _StatusPill(
                      palette: palette,
                      label: '${list.length}',
                      color: categoryColor,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: list.isEmpty
                      ? Center(
                          child: Text(
                            'No results. Try changing filters.',
                            style: TextStyle(
                              color: palette.textTertiary.o(0.95),
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        )
                      : ListView.separated(
                          controller: scrollController,
                          physics: const BouncingScrollPhysics(),
                          itemCount: list.length,
                          separatorBuilder: (_, __) =>
                              Divider(color: palette.cardBorder),
                          itemBuilder: (context, i) {
                            final op = list[i];
                            final isSel = op.id == selId;
                            Color c;
                            switch (op.category) {
                              case DemandOpportunityCategory.delivery:
                                c = const Color(0xFF00C2FF);
                                break;
                              case DemandOpportunityCategory.service:
                                c = const Color(0xFFB46BFF);
                                break;
                              case DemandOpportunityCategory.jobs:
                                c = const Color(0xFF22C55E);
                                break;
                              case DemandOpportunityCategory.errands:
                                c = const Color(0xFFFFC857);
                                break;
                            }
                            return Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () => onSelect(op),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 10,
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 36,
                                        height: 36,
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          color:
                                              palette.isDark
                                                  ? c.o(0.20)
                                                  : c.o(0.12),
                                          border: Border.all(
                                            color:
                                                isSel
                                                    ? c.o(0.55)
                                                    : palette.cardBorder,
                                          ),
                                        ),
                                        child: Icon(
                                          _categoryIcon(op.category),
                                          size: 18,
                                          color:
                                              palette.isDark
                                                  ? Colors.white
                                                  : c,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              op.title,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: palette.textPrimary,
                                                fontSize: 13.5,
                                                fontWeight: FontWeight.w800,
                                                height: 1.2,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '${op.distanceKm.toStringAsFixed(1)} km • ${_categoryLabel(op.category)}',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: palette.textTertiary
                                                    .o(0.95),
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        op.earningsLabel,
                                        style: TextStyle(
                                          color: palette.textPrimary,
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
                const SizedBox(height: 10),
                if (hasSelection) ...[
                  Row(
                    children: [
                      Expanded(
                        child: _PrimaryButton(
                          label: 'Accept',
                          glowColor: const Color(0xFF22C55E),
                          onTap: onAccept,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _SecondaryButton(
                          label: 'View Details',
                          accent: categoryColor,
                          onTap: onDetails,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

String _categoryLabel(DemandOpportunityCategory category) {
  switch (category) {
    case DemandOpportunityCategory.delivery:
      return 'Delivery';
    case DemandOpportunityCategory.service:
      return 'Service';
    case DemandOpportunityCategory.jobs:
      return 'Jobs';
    case DemandOpportunityCategory.errands:
      return 'Errands';
  }
}

IconData _categoryIcon(DemandOpportunityCategory category) {
  switch (category) {
    case DemandOpportunityCategory.delivery:
      return Icons.local_shipping_rounded;
    case DemandOpportunityCategory.service:
      return Icons.handyman_rounded;
    case DemandOpportunityCategory.jobs:
      return Icons.work_rounded;
    case DemandOpportunityCategory.errands:
      return Icons.receipt_long_rounded;
  }
}

class _CategorySegmentedControl extends StatelessWidget {
  const _CategorySegmentedControl({
    required this.palette,
    required this.selected,
    required this.onChanged,
  });

  final _Palette palette;
  final DemandOpportunityCategory? selected;
  final ValueChanged<DemandOpportunityCategory?> onChanged;

  @override
  Widget build(BuildContext context) {
    final items = <_SegItem>[
      const _SegItem('All', null),
      const _SegItem('Delivery', DemandOpportunityCategory.delivery),
      const _SegItem('Service', DemandOpportunityCategory.service),
      const _SegItem('Jobs', DemandOpportunityCategory.jobs),
      const _SegItem('Errands', DemandOpportunityCategory.errands),
    ];

    final selectedIndex = items.indexWhere((e) => e.value == selected);
    final safeIndex = selectedIndex == -1 ? 0 : selectedIndex;

    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final pillW = (w - 8) / items.length;

        return SizedBox(
          height: 42,
          child: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  color: palette.isDark ? Colors.white.o(0.06) : Colors.white.o(0.78),
                  border: Border.all(color: palette.cardBorder),
                ),
              ),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                left: 4 + (pillW * safeIndex),
                top: 4,
                bottom: 4,
                width: pillW,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: const Color(0xFF00C2FF).o(
                      palette.isDark ? 0.18 : 0.12,
                    ),
                    border: Border.all(
                      color: const Color(0xFF00C2FF).o(
                        palette.isDark ? 0.22 : 0.16,
                      ),
                    ),
                  ),
                ),
              ),
              Row(
                children: items.map((e) {
                  final isSelected = e.value == selected;
                  return Expanded(
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => onChanged(e.value),
                        child: Center(
                          child: Text(
                            e.label,
                            style: TextStyle(
                              color: palette.isDark
                                  ? Colors.white.o(isSelected ? 0.96 : 0.70)
                                  : palette.textSecondary.o(isSelected ? 0.98 : 0.78),
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.12,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SegItem {
  const _SegItem(this.label, this.value);
  final String label;
  final DemandOpportunityCategory? value;
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.palette,
    required this.label,
    required this.color,
  });

  final _Palette palette;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: palette.isDark ? Colors.white.o(0.07) : Colors.white.o(0.85),
        border: Border.all(color: palette.cardBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.o(0.95),
              boxShadow: [BoxShadow(color: color.o(0.25), blurRadius: 16)],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: palette.isDark
                  ? Colors.white.o(0.88)
                  : palette.textSecondary.o(0.95),
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.15,
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.palette,
    required this.controller,
    required this.onFilterTap,
  });

  final _Palette palette;
  final TextEditingController controller;
  final VoidCallback onFilterTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: palette.isDark ? Colors.white.o(0.06) : Colors.white.o(0.86),
        border: Border.all(color: palette.cardBorder),
      ),
      child: Row(
        children: [
          Icon(
            Icons.search_rounded,
            color: palette.isDark ? Colors.white.o(0.70) : palette.textTertiary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: 'Find opportunities near you',
                hintStyle: TextStyle(
                  color: palette.isDark
                      ? Colors.white.o(0.45)
                      : palette.textTertiary.o(0.92),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => HapticFeedback.selectionClick(),
            ),
          ),
          const SizedBox(width: 6),
          _SoftIconButton(
            icon: Icons.tune_rounded,
            onTap: onFilterTap,
            background: palette.isDark ? Colors.white.o(0.08) : Colors.black.o(0.04),
            border: palette.cardBorder,
            foreground: palette.isDark ? Colors.white.o(0.85) : palette.textSecondary,
          ),
        ],
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.glowColor,
    required this.onTap,
  });

  final String label;
  final Color glowColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Ink(
          height: 46,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: glowColor.o(0.92),
            border: Border.all(color: glowColor.o(0.35)),
          ),
          child: Center(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({
    required this.label,
    required this.accent,
    required this.onTap,
  });

  final String label;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Ink(
          height: 46,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: Colors.white.o(0.06),
            border: Border.all(color: accent.o(0.30)),
          ),
          child: Center(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SoftIconButton extends StatelessWidget {
  const _SoftIconButton({
    required this.icon,
    required this.onTap,
    this.background,
    this.border,
    this.foreground,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color? background;
  final Color? border;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: background ?? Colors.white.o(0.08),
            border: Border.all(color: border ?? Colors.white.o(0.14)),
          ),
          child: Icon(icon, color: foreground ?? Colors.white.o(0.85)),
        ),
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({
    required this.palette,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.borderRadius = 20,
  });

  final _Palette palette;
  final Widget child;
  final EdgeInsets padding;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: palette.cardBg,
      elevation: palette.isDark ? 0.0 : 3.0,
      shadowColor: palette.shadowColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius),
        side: BorderSide(color: palette.cardBorder),
      ),
      child: Padding(
        padding: padding,
        child: DefaultTextStyle.merge(
          style: TextStyle(color: palette.textPrimary),
          child: IconTheme.merge(
            data: IconThemeData(color: palette.iconColor),
            child: child,
          ),
        ),
      ),
    );
  }
}
