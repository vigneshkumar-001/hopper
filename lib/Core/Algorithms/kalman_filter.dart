import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Lightweight Kalman filter for GPS smoothing.
///
/// This is intentionally simple and fast for mobile UI tracking.
/// It reduces "zig-zag" and small jumps from noisy GPS.
class KalmanLatLngFilter {
  double _lat = 0.0;
  double _lng = 0.0;
  double _variance = -1.0; // -1 = uninitialized
  int _lastTsMs = 0;

  static const double _minAccuracyM = 1.0;
  static const double _processNoiseMetersPerSecond = 3.0;

  bool get isInitialized => _variance >= 0;

  void reset() {
    _variance = -1.0;
    _lastTsMs = 0;
  }

  LatLng process({
    required double lat,
    required double lng,
    required double accuracyMeters,
    required int timestampMs,
  }) {
    var acc = accuracyMeters.isFinite ? accuracyMeters : 9999.0;
    if (acc < _minAccuracyM) acc = _minAccuracyM;

    if (_variance < 0) {
      _lat = lat;
      _lng = lng;
      _variance = acc * acc;
      _lastTsMs = timestampMs;
      return LatLng(_lat, _lng);
    }

    final dtMs = timestampMs - _lastTsMs;
    if (dtMs > 0) {
      // Increase uncertainty over time (motion model).
      final dt = dtMs / 1000.0;
      final q = _processNoiseMetersPerSecond * _processNoiseMetersPerSecond;
      _variance += dt * q;
      _lastTsMs = timestampMs;
    }

    final r = acc * acc;
    final k = _variance / (_variance + r);

    _lat = _lat + k * (lat - _lat);
    _lng = _lng + k * (lng - _lng);
    _variance = (1 - k) * _variance;

    return LatLng(_lat, _lng);
  }
}

