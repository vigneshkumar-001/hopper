import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hopper/Presentation/DriverScreen/screens/SharedBooking/Controller/shared_ride_controller.dart';
import 'package:hopper/Presentation/DriverScreen/screens/SharedBooking/Widgets/car_seat_layout.dart';

/// Collapsible "Seats (n/3)" card for the driver's active shared-ride screen.
///
/// Compact by default (just the count + a free-seats pill) so it never crowds
/// the map; tap to expand the full car-seat layout with each passenger's
/// initials + first name on their seat. Fixed 4-seat car: seat 1 = driver,
/// seats 2-4 = passengers, filled in rider order (cancelled riders free a seat).
class DriverSeatsCard extends StatefulWidget {
  final SharedRideController controller;
  const DriverSeatsCard({super.key, required this.controller});

  @override
  State<DriverSeatsCard> createState() => _DriverSeatsCardState();
}

class _DriverSeatsCardState extends State<DriverSeatsCard> {
  bool _expanded = false;

  static const int _passengerSeats = 3; // fixed: 1 driver + 3 passengers

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      // Active (not cancelled) riders occupy passenger seats. A single rider can
      // book multiple seats, so we sum each rider's seatCount — NOT the rider
      // count — to get how many seats are actually filled.
      // Active occupied seats = passengers still in the trip. A DROPPED/completed
      // passenger (and a cancelled one) frees their seat, so they must NOT count
      // toward "Seats n/3" / "Full".
      final active = widget.controller.riders
          .where((r) =>
              !r.cancelledByCustomer && r.stage != SharedRiderStage.dropped)
          .toList();

      // Map each occupied passenger seat number (2..4) -> its rider, using the
      // EXACT seat numbers the customer picked so the driver sees the same seats.
      final Map<int, SharedRiderItem> seatOwner = <int, SharedRiderItem>{};
      final List<SharedRiderItem> needFallback = <SharedRiderItem>[];
      for (final r in active) {
        if (r.seatNumbers.isNotEmpty) {
          for (final n in r.seatNumbers) {
            if (n >= 2 && n <= _passengerSeats + 1 && !seatOwner.containsKey(n)) {
              seatOwner[n] = r;
            }
          }
        } else {
          needFallback.add(r);
        }
      }
      // Riders whose seat numbers we don't know yet fill the next free seats.
      for (final r in needFallback) {
        final count = r.seatCount <= 0 ? 1 : r.seatCount;
        for (int k = 0; k < count; k++) {
          int n = 2;
          while (n <= _passengerSeats + 1 && seatOwner.containsKey(n)) n++;
          if (n > _passengerSeats + 1) break;
          seatOwner[n] = r;
        }
      }

      final filled = seatOwner.length > _passengerSeats
          ? _passengerSeats
          : seatOwner.length;
      final free = _passengerSeats - filled;

      final seats = <CarSeatData>[
        const CarSeatData(seatNumber: 1, state: SeatState.driver, caption: 'You'),
      ];
      for (int i = 0; i < _passengerSeats; i++) {
        final seatNumber = i + 2; // seats 2,3,4
        final owner = seatOwner[seatNumber];
        if (owner != null) {
          seats.add(CarSeatData(
            seatNumber: seatNumber,
            state: SeatState.booked,
            initials: _initials(owner.name),
            caption: '${owner.firstName} · $seatNumber',
          ));
        } else {
          seats.add(CarSeatData(seatNumber: seatNumber, state: SeatState.available));
        }
      }

      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.black.withOpacity(0.08)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    const Icon(Icons.event_seat, size: 20, color: Color(0xFF185FA5)),
                    const SizedBox(width: 10),
                    Text(
                      'Seats  $filled/$_passengerSeats',
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: free > 0
                            ? const Color(0xFFE1F5EE)
                            : const Color(0xFFF1EFE8),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        free > 0 ? '$free seat${free == 1 ? '' : 's'} free' : 'Full',
                        style: TextStyle(
                          fontSize: 12,
                          color: free > 0
                              ? const Color(0xFF0F6E56)
                              : const Color(0xFF5F5E5A),
                        ),
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      _expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                      color: const Color(0xFF5F5E5A),
                    ),
                  ],
                ),
              ),
            ),
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 200),
              crossFadeState: _expanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              firstChild: const SizedBox(width: double.infinity),
              secondChild: Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
                child: Center(child: CarSeatLayout(seats: seats)),
              ),
            ),
          ],
        ),
      );
    });
  }
}
