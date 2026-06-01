import 'package:flutter/material.dart';

class MapControlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color iconColor;
  final Color backgroundColor;
  final double size;
  final double radius;

  const MapControlButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.iconColor = const Color(0xFF111827),
    this.backgroundColor = Colors.white,
    this.size = 44,
    this.radius = 14,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(radius),
        onTap: onTap,
        child: Ink(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: const Color(0xFFE5E7EB)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1F000000),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Icon(icon, size: 20, color: iconColor),
        ),
      ),
    );
  }
}

class NavigateToDestinationButton extends StatelessWidget {
  final VoidCallback onTap;
  final String label; // 'To Pickup' or 'To Drop'

  const NavigateToDestinationButton({
    super.key,
    required this.onTap,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: Color(0xFF1A73E8),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.navigation_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Navigate',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A73E8),
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF5F6368),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class MapFocusToggleButton extends StatelessWidget {
  final bool isDriverFocused;
  final VoidCallback onFocusDriver;
  final VoidCallback onFitBounds;
  final ValueChanged<bool> onDriverFocusedChanged;
  final Color accentColor;

  const MapFocusToggleButton({
    super.key,
    required this.isDriverFocused,
    required this.onFocusDriver,
    required this.onFitBounds,
    required this.onDriverFocusedChanged,
    this.accentColor = const Color(0xFF00A85E),
  });

  @override
  Widget build(BuildContext context) {
    return MapControlButton(
      icon:
          isDriverFocused ? Icons.fit_screen_rounded : Icons.my_location_rounded,
      iconColor: accentColor,
      onTap: () {
        if (isDriverFocused) {
          onFitBounds();
          onDriverFocusedChanged(false);
          return;
        }

        onFocusDriver();
        onDriverFocusedChanged(true);
      },
    );
  }
}

