import 'dart:math' as math;

class MapMotionProfile {
  static const double minSpeedMs = 1.0;
  static const double stationaryDriftM = 8.0;

  static double targetZoomFromSpeed(double speedMs) {
    final kmh = speedMs * 3.6;
    // Keep the road + next turn clearly visible (avoid aggressive zoom-out).
    // Tuned for ride apps (Ola/Uber-like follow camera).
    //
    // Updated: slightly more zoom-in so the vehicle + road are clearer.
    if (kmh >= 70) return 15.2;
    if (kmh >= 45) return 15.7;
    if (kmh >= 25) return 16.2;
    if (kmh >= 12) return 16.6;
    return 17.0;
  }

  static double smoothZoom(double currentZoom, double targetZoom) {
    // Slow smoothing to prevent zoom "pumping" on GPS speed jitter.
    return (currentZoom * 0.90) + (targetZoom * 0.10);
  }

  static bool shouldFreezeTurn({
    required double speedMs,
    required double movedMeters,
    double? accuracyM,
  }) {
    final adaptiveDrift = math.max(
      stationaryDriftM,
      ((accuracyM ?? 0) * 0.8).clamp(0.0, 20.0),
    );
    return speedMs < minSpeedMs && movedMeters < adaptiveDrift;
  }

  static double smoothBearing({
    required double current,
    required double target,
    required double speedMs,
  }) {
    final delta = ((target - current + 540) % 360) - 180;

    final gain =
        speedMs >= 8
            ? 0.65
            : speedMs >= 4
            ? 0.55
            : 0.42;

    return normalizeAngle(current + (delta * gain));
  }

  static double normalizeAngle(double angle) {
    angle %= 360;
    if (angle < 0) angle += 360;
    return angle;
  }

  static double shortestAngle(double from, double to) {
    double diff = (to - from) % 360;
    if (diff > 180) diff -= 360;
    return from + diff;
  }

  static double angleDelta(double a, double b) {
    double d = (b - a) % 360;
    if (d > 180) d -= 360;
    if (d < -180) d += 360;
    return d.abs();
  }

  static double haversineMeters({
    required double lat1,
    required double lng1,
    required double lat2,
    required double lng2,
  }) {
    const earthRadius = 6371000.0;

    final dLat = _degToRad(lat2 - lat1);
    final dLng = _degToRad(lng2 - lng1);
    final radLat1 = _degToRad(lat1);
    final radLat2 = _degToRad(lat2);

    final h =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(radLat1) *
            math.cos(radLat2) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);

    return 2 * earthRadius * math.asin(math.sqrt(h));
  }

  static double _degToRad(double deg) => deg * (math.pi / 180.0);
}

