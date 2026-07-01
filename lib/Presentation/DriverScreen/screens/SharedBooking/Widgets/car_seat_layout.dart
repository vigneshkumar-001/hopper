import 'package:flutter/material.dart';

/// Visual state of a single seat in the shared-ride car layout.
enum SeatState { driver, available, selected, booked }

/// One seat in the car (seat 1 = driver, 2..4 = passengers).
class CarSeatData {
  final int seatNumber;
  final SeatState state;

  /// Optional caption under the seat (e.g. passenger first name on driver side).
  final String? caption;

  /// Optional initials shown inside a booked seat (driver side).
  final String? initials;

  const CarSeatData({
    required this.seatNumber,
    required this.state,
    this.caption,
    this.initials,
  });
}

/// A clean top-view car interior with real seat shapes and seat numbers.
///
/// Fixed 4-seat layout: row 1 = driver (seat 1) + front passenger (seat 2),
/// row 2 = rear passengers (seats 3 & 4). On the DRIVER app this is the
/// read-only occupancy view: booked seats show passenger initials + name,
/// empty seats are dashed teal. Colours match the customer app exactly.
class CarSeatLayout extends StatelessWidget {
  final List<CarSeatData> seats;

  /// Tapped seat number; null => read-only (driver occupancy view).
  final void Function(int seatNumber)? onSeatTap;

  /// Show the colour legend under the car.
  final bool showLegend;

  const CarSeatLayout({
    super.key,
    required this.seats,
    this.onSeatTap,
    this.showLegend = true,
  });

  static const _tealFill = Color(0xFF1D9E75);
  static const _tealDark = Color(0xFF0F6E56);
  static const _tealLight = Color(0xFFE1F5EE);
  static const _blueFill = Color(0xFF185FA5);
  static const _blueDark = Color(0xFF0C447C);
  static const _neutralFill = Color(0xFFF1EFE8);
  static const _neutralBorder = Color(0xFFB4B2A9);
  static const _neutralText = Color(0xFF5F5E5A);

  CarSeatData _seatByNumber(int n) {
    return seats.firstWhere(
      (s) => s.seatNumber == n,
      orElse: () => CarSeatData(seatNumber: n, state: SeatState.available),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 26),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.black.withOpacity(0.08)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 70,
                height: 10,
                decoration: const BoxDecoration(
                  color: _neutralBorder,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _seat(_seatByNumber(1)),
                  _seat(_seatByNumber(2)),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _seat(_seatByNumber(3)),
                  _seat(_seatByNumber(4)),
                ],
              ),
            ],
          ),
        ),
        if (showLegend) ...[
          const SizedBox(height: 14),
          _legend(),
        ],
      ],
    );
  }

  Widget _seat(CarSeatData s) {
    Color fill;
    Color border;
    double borderWidth;
    Widget center;
    String caption;
    Color captionColor;
    bool tappable = false;

    switch (s.state) {
      case SeatState.driver:
        fill = _neutralFill;
        border = _neutralBorder;
        borderWidth = 0.5;
        center = const Icon(Icons.airline_seat_recline_normal,
            size: 24, color: _neutralText);
        caption = s.caption ?? 'Driver';
        captionColor = _neutralText;
        break;
      case SeatState.available:
        fill = _tealLight;
        border = _tealFill;
        borderWidth = 2;
        center = Text('${s.seatNumber}',
            style: const TextStyle(
                fontSize: 20, fontWeight: FontWeight.w600, color: _tealDark));
        caption = s.caption ?? 'Empty';
        captionColor = _tealDark;
        tappable = onSeatTap != null;
        break;
      case SeatState.selected:
        fill = _tealFill;
        border = _tealDark;
        borderWidth = 2;
        center = Stack(
          alignment: Alignment.center,
          children: [
            Text('${s.seatNumber}',
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.white)),
            const Positioned(
                top: 5,
                right: 6,
                child: Icon(Icons.check, size: 13, color: Colors.white)),
          ],
        );
        caption = s.caption ?? 'Your seat';
        captionColor = _tealDark;
        tappable = onSeatTap != null;
        break;
      case SeatState.booked:
        fill = _blueFill;
        border = _blueDark;
        borderWidth = 2;
        center = s.initials != null && s.initials!.isNotEmpty
            ? Text(s.initials!,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white))
            : const Icon(Icons.person, size: 22, color: Colors.white);
        caption = s.caption ?? 'Seat ${s.seatNumber}';
        captionColor = _blueDark;
        break;
    }

    final seatWidget = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 32,
          height: 7,
          decoration: BoxDecoration(
            color: border,
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        const SizedBox(height: 3),
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 62,
          height: 58,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: border, width: borderWidth),
          ),
          child: center,
        ),
        const SizedBox(height: 5),
        SizedBox(
          width: 72,
          child: Text(
            caption,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, color: captionColor),
          ),
        ),
      ],
    );

    if (!tappable) return seatWidget;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onSeatTap?.call(s.seatNumber),
      child: seatWidget,
    );
  }

  Widget _legend() {
    Widget chip(Color c, String label, {Color? border}) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: c,
              borderRadius: BorderRadius.circular(4),
              border: border != null ? Border.all(color: border, width: 2) : null,
            ),
          ),
          const SizedBox(width: 6),
          Text(label,
              style: const TextStyle(fontSize: 12, color: _neutralText)),
        ],
      );
    }

    return Wrap(
      spacing: 14,
      runSpacing: 8,
      children: [
        chip(_blueFill, 'Booked'),
        chip(_tealLight, 'Empty', border: _tealFill),
        chip(_neutralFill, 'You', border: _neutralBorder),
      ],
    );
  }
}
