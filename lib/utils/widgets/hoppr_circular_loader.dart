import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class HopprCircularLoader extends StatelessWidget {
  final double radius;
  final double? size;
  final Color? color;

  const HopprCircularLoader({
    super.key,
    this.radius = 14,
    this.size,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.primary;
    final Widget indicator = CupertinoTheme(
      data: CupertinoTheme.of(context).copyWith(primaryColor: c),
      child: CupertinoActivityIndicator(radius: radius),
    );

    if (size == null) return indicator;
    return SizedBox(width: size, height: size, child: Center(child: indicator));
  }
}
