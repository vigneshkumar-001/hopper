import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

img.Image _loadPng(String path) {
  final bytes = File(path).readAsBytesSync();
  final decoded = img.decodePng(bytes);
  if (decoded == null) {
    throw StateError('Failed to decode PNG: $path');
  }
  return decoded;
}

void _drawThickLine(
  img.Image canvas,
  img.Point a,
  img.Point b, {
  required img.Color color,
  int thickness = 8,
}) {
  final half = thickness ~/ 2;
  for (var dx = -half; dx <= half; dx++) {
    for (var dy = -half; dy <= half; dy++) {
      img.drawLine(
        canvas,
        x1: a.x.toInt() + dx,
        y1: a.y.toInt() + dy,
        x2: b.x.toInt() + dx,
        y2: b.y.toInt() + dy,
        color: color,
      );
    }
  }
}

double _bearingRad(img.Point a, img.Point b) {
  final dx = (b.x - a.x).toDouble();
  final dy = (b.y - a.y).toDouble(); // screen coords (+y down)
  return math.atan2(dy, dx);
}

void _drawMarker({
  required img.Image canvas,
  required int cx,
  required int cy,
  required img.Image icon,
  int size = 56,
}) {
  final r = size ~/ 2;
  img.fillCircle(
    canvas,
    x: cx + 2,
    y: cy + 3,
    radius: r,
    color: img.ColorRgba8(0, 0, 0, 55),
  );
  img.fillCircle(
    canvas,
    x: cx,
    y: cy,
    radius: r,
    color: img.ColorRgba8(255, 255, 255, 240),
  );
  img.drawCircle(
    canvas,
    x: cx,
    y: cy,
    radius: r,
    color: img.ColorRgba8(0, 0, 0, 40),
  );

  final maxIcon = (size * 0.62).round();
  final resized = img.copyResize(icon, width: maxIcon, height: maxIcon);
  img.compositeImage(
    canvas,
    resized,
    dstX: cx - (resized.width ~/ 2),
    dstY: cy - (resized.height ~/ 2),
  );
}

void _drawPin({
  required img.Image canvas,
  required int x,
  required int y,
  required img.Color color,
  required String label,
}) {
  img.fillCircle(
    canvas,
    x: x + 2,
    y: y + 3,
    radius: 18,
    color: img.ColorRgba8(0, 0, 0, 55),
  );
  img.fillCircle(
    canvas,
    x: x,
    y: y,
    radius: 18,
    color: img.ColorRgba8(255, 255, 255, 245),
  );
  img.fillCircle(canvas, x: x, y: y, radius: 12, color: color);
  img.drawString(
    canvas,
    label,
    font: img.arial14,
    x: x - 10,
    y: y - 40,
    color: img.ColorRgba8(40, 40, 40, 220),
  );
}

void main() {
  final root = Directory.current.path;
  final straightPng = '$root/assets/images/straight.png';
  final leftPng = '$root/assets/images/left-turn.png';
  final rightPng = '$root/assets/images/right-turn.png';

  final straight = _loadPng(straightPng);
  final left = _loadPng(leftPng);
  final right = _loadPng(rightPng);

  // Fake "map" background.
  const w = 1080;
  const h = 1920;
  final canvas = img.Image(width: w, height: h);
  img.fill(canvas, color: img.ColorRgba8(242, 244, 247, 255));

  // Subtle grid / roads.
  for (var y = 0; y < h; y += 60) {
    img.drawLine(
      canvas,
      x1: 0,
      y1: y,
      x2: w,
      y2: y,
      color: img.ColorRgba8(220, 224, 230, 140),
    );
  }
  for (var x = 0; x < w; x += 60) {
    img.drawLine(
      canvas,
      x1: x,
      y1: 0,
      x2: x,
      y2: h,
      color: img.ColorRgba8(220, 224, 230, 140),
    );
  }
  for (var i = 0; i < 10; i++) {
    final y = 200 + i * 140;
    _drawThickLine(
      canvas,
      img.Point(80, y),
      img.Point(w - 80, y + (i.isEven ? 20 : -20)),
      color: img.ColorRgba8(206, 210, 218, 255),
      thickness: 12,
    );
  }

  // Example route polyline.
  final route = <img.Point>[
    img.Point(210, 1520),
    img.Point(320, 1390),
    img.Point(480, 1240),
    img.Point(650, 1120),
    img.Point(760, 950), // right-ish turn
    img.Point(700, 760),
    img.Point(540, 650), // left-ish turn
    img.Point(420, 520),
    img.Point(520, 360),
    img.Point(720, 260),
  ];

  // Outline + main route color (Google Maps-ish).
  for (var i = 0; i < route.length - 1; i++) {
    _drawThickLine(
      canvas,
      route[i],
      route[i + 1],
      color: img.ColorRgba8(18, 79, 170, 220),
      thickness: 18,
    );
    _drawThickLine(
      canvas,
      route[i],
      route[i + 1],
      color: img.ColorRgba8(30, 136, 229, 255),
      thickness: 12,
    );
  }

  // Pins: you / pickup / drop.
  _drawPin(
    canvas: canvas,
    x: route.first.x.toInt(),
    y: route.first.y.toInt(),
    color: img.ColorRgba8(76, 175, 80, 255),
    label: 'You',
  );
  _drawPin(
    canvas: canvas,
    x: route[3].x.toInt(),
    y: route[3].y.toInt(),
    color: img.ColorRgba8(255, 193, 7, 255),
    label: 'Pickup',
  );
  _drawPin(
    canvas: canvas,
    x: route.last.x.toInt(),
    y: route.last.y.toInt(),
    color: img.ColorRgba8(244, 67, 54, 255),
    label: 'Drop',
  );

  // Straight-arrow markers at a few segments (rotated to match bearing).
  final arrowIndices = [1, 2, 4, 6, 8];
  for (final idx in arrowIndices) {
    if (idx <= 0 || idx >= route.length) continue;
    final a = route[idx - 1];
    final b = route[idx];
    final rad = _bearingRad(a, b);
    final deg = rad * 180 / math.pi;
    final rotated = img.copyRotate(straight, angle: deg);
    _drawMarker(
      canvas: canvas,
      cx: b.x.toInt(),
      cy: b.y.toInt(),
      icon: rotated,
      size: 54,
    );
  }

  // Turn markers near obvious bends.
  _drawMarker(
    canvas: canvas,
    cx: route[4].x.toInt(),
    cy: route[4].y.toInt(),
    icon: right,
    size: 58,
  );
  _drawMarker(
    canvas: canvas,
    cx: route[6].x.toInt(),
    cy: route[6].y.toInt(),
    icon: left,
    size: 58,
  );

  // Small legend at top.
  img.fillRect(
    canvas,
    x1: 40,
    y1: 40,
    x2: w - 40,
    y2: 140,
    color: img.ColorRgba8(255, 255, 255, 235),
  );
  img.drawRect(
    canvas,
    x1: 40,
    y1: 40,
    x2: w - 40,
    y2: 140,
    color: img.ColorRgba8(0, 0, 0, 35),
  );
  img.drawString(
    canvas,
    'Polyline + maneuver markers (straight / left / right)',
    font: img.arial24,
    x: 70,
    y: 70,
    color: img.ColorRgba8(30, 30, 30, 230),
  );

  final outPath = '$root/assets/mockups/maneuver_markers_preview.png';
  File(outPath).writeAsBytesSync(img.encodePng(canvas, level: 6));
  stdout.writeln('Wrote: $outPath');
}
