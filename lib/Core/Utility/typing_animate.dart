import 'package:flutter/material.dart';

/// Smooth 3-dot typing indicator
class SmoothTypingIndicator extends StatefulWidget {
  /// dot size, color, spacing and animation speed are configurable
  final double dotSize;
  final Color dotColor;
  final double spacing;
  final Duration duration;

  const SmoothTypingIndicator({
    Key? key,
    this.dotSize = 10.0,
    this.dotColor = Colors.grey,
    this.spacing = 6.0,
    this.duration = const Duration(milliseconds: 1200),
  }) : super(key: key);

  @override
  State<SmoothTypingIndicator> createState() => _SmoothTypingIndicatorState();
}

class _SmoothTypingIndicatorState extends State<SmoothTypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<Animation<double>> _dotScales;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..repeat();

    // Staggered intervals for smooth wave effect
    _dotScales = List.generate(3, (i) {
      final start = i * 0.15;
      final end = start + 0.6;
      return CurvedAnimation(
        parent: _controller,
        curve: Interval(
          start.clamp(0.0, 1.0),
          end.clamp(0.0, 1.0),
          curve: Curves.easeInOut,
        ),
      ).drive(Tween<double>(begin: 0.6, end: 1.0));
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildDot(Animation<double> scaleAnim) {
    return ScaleTransition(
      scale: scaleAnim,
      child: Container(
        width: widget.dotSize,
        height: widget.dotSize,
        decoration: BoxDecoration(
          color: widget.dotColor,
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildDot(_dotScales[0]),
        SizedBox(width: widget.spacing),
        _buildDot(_dotScales[1]),
        SizedBox(width: widget.spacing),
        _buildDot(_dotScales[2]),
      ],
    );
  }
}
