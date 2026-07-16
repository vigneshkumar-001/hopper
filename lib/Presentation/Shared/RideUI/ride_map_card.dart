// Shared Ride UI — map hero frame.
//
// A thin decorative wrapper around whatever map widget the caller already
// has (CustomerRideMapView, RideMapView, ...) — rounded corners, a subtle
// top scrim for header legibility, and slots for a floating status header
// and floating action buttons (recenter, SOS). Deliberately does NOT own
// any map/marker/polyline logic itself — "reuse existing map controller,
// do not redraw unnecessarily" per the design brief.

import 'package:flutter/material.dart';

class RideMapCard extends StatelessWidget {
  final Widget map;
  final Widget? floatingHeader;
  final List<Widget>? floatingActions;
  final double height;
  final BorderRadius borderRadius;

  const RideMapCard({
    super.key,
    required this.map,
    this.floatingHeader,
    this.floatingActions,
    required this.height,
    this.borderRadius = const BorderRadius.vertical(
      bottom: Radius.circular(28),
    ),
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: ClipRRect(
        borderRadius: borderRadius,
        child: Stack(
          fit: StackFit.expand,
          children: [
            map,
            IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.28),
                      Colors.black.withOpacity(0.0),
                    ],
                    stops: const [0, 0.35],
                  ),
                ),
              ),
            ),
            if (floatingHeader != null)
              Positioned(top: 12, left: 12, right: 12, child: floatingHeader!),
            if (floatingActions != null && floatingActions!.isNotEmpty)
              Positioned(
                right: 12,
                bottom: 16,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < floatingActions!.length; i++) ...[
                      if (i != 0) const SizedBox(height: 10),
                      floatingActions![i],
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
