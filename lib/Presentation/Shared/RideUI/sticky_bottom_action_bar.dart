// Shared Ride UI — sticky bottom action bar.
//
// Wraps a primary action (button, swipe slider, whatever the caller passes)
// with safe-area-aware bottom padding and a fade so content scrolling
// behind it never looks abruptly clipped.

import 'package:flutter/material.dart';
import 'ride_ui_theme.dart';

class StickyBottomActionBar extends StatelessWidget {
  final Widget child;
  final Color fadeColor;

  const StickyBottomActionBar({
    super.key,
    required this.child,
    this.fadeColor = RideUI.pageBackground,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        14,
        12,
        14,
        12 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [fadeColor.withOpacity(0), fadeColor.withOpacity(0.94)],
          stops: const [0, 0.22],
        ),
      ),
      child: child,
    );
  }
}
