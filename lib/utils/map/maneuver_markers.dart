import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:geolocator/geolocator.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Builds lightweight arrow/turn markers along a polyline.
///
/// Google Maps polylines cannot render arrows/turn icons directly, so we use
/// markers with small maneuver icons.
class ManeuverMarkers {
  static final ManeuverMarkerIconCache _icons = ManeuverMarkerIconCache();

  /// Creates a small set of markers:
  /// - Direction arrows at an interval along the route
  /// - Turn markers at sharp bearing changes
  static Future<List<Marker>> build({
    required List<LatLng> polyline,
    required String idPrefix,
    LatLng? travelOrigin,
    List<LatLng> avoidPositions = const <LatLng>[],
    double avoidRadiusMeters = 80,
    List<Map<String, dynamic>>? maneuverPoints,
    double arrowIntervalMeters = 1400,
    int maxArrows = 4,
    int maxTurns = 6,
    double turnThresholdDeg = 45,
  }) async {
    if (polyline.length < 2) return const <Marker>[];

    await _icons.ensureLoaded();

    final pts = _ensureTravelDirection(polyline, travelOrigin);
    final out = <Marker>[];

    bool isTooCloseToAvoid(LatLng p) {
      for (final a in avoidPositions) {
        final d = Geolocator.distanceBetween(
          p.latitude,
          p.longitude,
          a.latitude,
          a.longitude,
        );
        if (d <= avoidRadiusMeters) return true;
      }
      return false;
    }

    final turnPositions = <LatLng>[];

    // 0) Preferred: use Directions maneuver points (correct left/right mapping)
    if (maneuverPoints != null && maneuverPoints.isNotEmpty) {
      int turnCount = 0;
      int lastAddedAtM = -999999;

      for (final mp in maneuverPoints) {
        if (turnCount >= maxTurns) break;
        if (mp is! Map) continue;
        final lat = mp['lat'];
        final lng = mp['lng'];
        if (lat is! num || lng is! num) continue;
        final pos = LatLng(lat.toDouble(), lng.toDouble());

        final raw = (mp['maneuver'] ?? '').toString().trim().toLowerCase();
        final type = _maneuverType(raw);
        final icon = _iconFor(type);
        if (icon == null) continue;

        final d = mp['distanceFromStartMeters'];
        final distFromStart = d is int ? d : int.tryParse('$d') ?? 0;

        // Keep it minimal + avoid overlapping pickup/drop pins.
        if (distFromStart < 120) continue;
        if (distFromStart - lastAddedAtM < 350) continue;
        if (isTooCloseToAvoid(pos)) continue;

        final bearing = _bearingAtPosition(pts, pos);

        out.add(
          Marker(
            markerId: MarkerId('${idPrefix}_m_${turnCount}_$distFromStart'),
            position: pos,
            icon: icon,
            rotation: bearing,
            anchor: const Offset(0.5, 0.5),
            flat: true,
            zIndexInt: 6,
          ),
        );
        turnPositions.add(pos);
        lastAddedAtM = distFromStart;
        turnCount++;
      }
    }

    // 1) arrows along the route
    double acc = 0.0;
    int arrowCount = 0;
    for (int i = 1; i < pts.length && arrowCount < maxArrows; i++) {
      final a = pts[i - 1];
      final b = pts[i];
      final d = Geolocator.distanceBetween(
        a.latitude,
        a.longitude,
        b.latitude,
        b.longitude,
      );
      acc += d;
      if (acc < arrowIntervalMeters) continue;
      acc = 0.0;

      if (isTooCloseToAvoid(b)) continue;
      if (_isTooCloseToAny(b, turnPositions, 220)) continue;

      final bearing = _bearingDeg(a, b);
      out.add(
        Marker(
          markerId: MarkerId('${idPrefix}_arrow_$i'),
          position: b,
          icon: _icons.straight!,
          rotation: bearing,
          anchor: const Offset(0.5, 0.5),
          flat: true,
          zIndexInt: 5,
        ),
      );
      arrowCount++;
    }

    // 2) Fallback: turn markers at sharp direction changes (when no step data)
    if (turnPositions.isNotEmpty) return out;

    int turnCount = 0;
    double lastTurnAtMeters = 0.0;
    double walked = 0.0;

    for (int i = 1; i < pts.length - 1 && turnCount < maxTurns; i++) {
      final prev = pts[i - 1];
      final cur = pts[i];
      final next = pts[i + 1];

      walked += Geolocator.distanceBetween(
        prev.latitude,
        prev.longitude,
        cur.latitude,
        cur.longitude,
      );

      // avoid clustering
      if (walked - lastTurnAtMeters < 250) continue;

      final b1 = _bearingDeg(prev, cur);
      final b2 = _bearingDeg(cur, next);
      final delta = _normalizeDelta(b2 - b1);

      if (delta.abs() < turnThresholdDeg) continue;
      if (isTooCloseToAvoid(cur)) continue;

      final icon = delta > 0 ? _icons.right : _icons.left;
      if (icon == null) continue;

      out.add(
        Marker(
          markerId: MarkerId('${idPrefix}_turn_$i'),
          position: cur,
          icon: icon,
          rotation: b1,
          anchor: const Offset(0.5, 0.5),
          flat: true,
          zIndexInt: 6,
        ),
      );
      turnCount++;
      lastTurnAtMeters = walked;
    }

    return out;
  }

  static List<LatLng> _ensureTravelDirection(
    List<LatLng> polyline,
    LatLng? travelOrigin,
  ) {
    if (travelOrigin == null || polyline.length < 2) return polyline;

    final first = polyline.first;
    final last = polyline.last;
    final dFirst = Geolocator.distanceBetween(
      travelOrigin.latitude,
      travelOrigin.longitude,
      first.latitude,
      first.longitude,
    );
    final dLast = Geolocator.distanceBetween(
      travelOrigin.latitude,
      travelOrigin.longitude,
      last.latitude,
      last.longitude,
    );

    if (dLast + 5 < dFirst) {
      return polyline.reversed.toList(growable: false);
    }
    return polyline;
  }

  static bool _isTooCloseToAny(LatLng p, List<LatLng> others, double meters) {
    for (final o in others) {
      final d = Geolocator.distanceBetween(
        p.latitude,
        p.longitude,
        o.latitude,
        o.longitude,
      );
      if (d <= meters) return true;
    }
    return false;
  }

  static double _bearingAtPosition(List<LatLng> polyline, LatLng pos) {
    if (polyline.length < 2) return 0.0;

    double best = double.infinity;
    int bestIdx = 0;
    for (int i = 0; i < polyline.length; i++) {
      final p = polyline[i];
      final d = Geolocator.distanceBetween(
        pos.latitude,
        pos.longitude,
        p.latitude,
        p.longitude,
      );
      if (d < best) {
        best = d;
        bestIdx = i;
      }
    }

    if (bestIdx > 0) {
      return _bearingDeg(polyline[bestIdx - 1], polyline[bestIdx]);
    }
    return _bearingDeg(polyline[0], polyline[1]);
  }

  static _ManeuverType _maneuverType(String normalized) {
    final m = normalized.trim().toLowerCase();
    if (m.contains('turn-slight-right') ||
        m.contains('fork-slight-right') ||
        m.contains('ramp-slight-right') ||
        m.contains('merge-right') ||
        m.contains('keep-right')) {
      return _ManeuverType.slightRight;
    }
    if (m.contains('turn-slight-left') ||
        m.contains('fork-slight-left') ||
        m.contains('ramp-slight-left') ||
        m.contains('merge-left') ||
        m.contains('keep-left')) {
      return _ManeuverType.slightLeft;
    }

    if (m.contains('uturn') && m.contains('right')) return _ManeuverType.right;
    if (m.contains('uturn') && m.contains('left')) return _ManeuverType.left;
    if (m.contains('roundabout') && m.contains('left')) return _ManeuverType.left;
    if (m.contains('roundabout') && m.contains('right')) return _ManeuverType.right;
    if (m.contains('left')) return _ManeuverType.left;
    if (m.contains('right')) return _ManeuverType.right;
    if (m.contains('arrive')) return _ManeuverType.arrive;
    return _ManeuverType.straight;
  }

  static BitmapDescriptor? _iconFor(_ManeuverType t) {
    switch (t) {
      case _ManeuverType.left:
        return _icons.left;
      case _ManeuverType.right:
        return _icons.right;
      case _ManeuverType.slightLeft:
      case _ManeuverType.slightRight:
      case _ManeuverType.straight:
        return null;
      case _ManeuverType.arrive:
        return null;
    }
  }

  static double _bearingDeg(LatLng start, LatLng end) {
    final lat1 = start.latitude * (math.pi / 180.0);
    final lon1 = start.longitude * (math.pi / 180.0);
    final lat2 = end.latitude * (math.pi / 180.0);
    final lon2 = end.longitude * (math.pi / 180.0);

    final dLon = lon2 - lon1;
    final y = math.sin(dLon) * math.cos(lat2);
    final x =
        math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);

    final brng = math.atan2(y, x);
    return (brng * 180 / math.pi + 360) % 360;
  }

  static double _normalizeDelta(double deg) {
    var d = deg;
    while (d > 180) {
      d -= 360;
    }
    while (d < -180) {
      d += 360;
    }
    return d;
  }
}

enum _ManeuverType { straight, slightLeft, slightRight, left, right, arrive }

class ManeuverMarkerIconCache {
  BitmapDescriptor? straight;
  BitmapDescriptor? left;
  BitmapDescriptor? right;

  bool _loading = false;
  bool get isLoaded => straight != null && left != null && right != null;

  Future<void> ensureLoaded() async {
    if (isLoaded) return;
    if (_loading) return;
    _loading = true;
    try {
      // Uber-like compact markers: a small dark circle with a crisp icon.
      // This avoids the "black square PNG" look from legacy assets.
      straight = await _fromIcon(Icons.navigation, diameterPx: 56);
      left = await _fromIcon(Icons.turn_left, diameterPx: 56);
      right = await _fromIcon(Icons.turn_right, diameterPx: 56);
    } finally {
      _loading = false;
    }
  }

  static Future<BitmapDescriptor> _fromIcon(
    IconData icon, {
    required int diameterPx,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final center = Offset(diameterPx / 2.0, diameterPx / 2.0);
    final r = diameterPx / 2.0;

    // Shadow
    final shadowPaint = Paint()..color = const Color(0x33000000);
    canvas.drawCircle(center.translate(1.5, 2.0), r * 0.92, shadowPaint);

    // Circle background
    final bgPaint = Paint()..color = const Color(0xE6111111);
    canvas.drawCircle(center, r * 0.90, bgPaint);

    // Thin border
    final borderPaint =
        Paint()
          ..color = const Color(0x22FFFFFF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0;
    canvas.drawCircle(center, r * 0.90, borderPaint);

    // Icon (white)
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    final iconSize = diameterPx * 0.56;
    textPainter.text = TextSpan(
      text: String.fromCharCode(icon.codePoint),
      style: TextStyle(
        fontSize: iconSize,
        fontFamily: icon.fontFamily,
        package: icon.fontPackage,
        color: Colors.white,
        height: 1.0,
      ),
    );
    textPainter.layout();
    final offset = Offset(
      center.dx - textPainter.width / 2.0,
      center.dy - textPainter.height / 2.0,
    );
    textPainter.paint(canvas, offset);

    final picture = recorder.endRecording();
    final image = await picture.toImage(diameterPx, diameterPx);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.fromBytes(bytes!.buffer.asUint8List());
  }
}
