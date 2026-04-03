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

