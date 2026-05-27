import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'bearing_utils.dart';

class VehiclePose {
  final LatLng position;
  final double bearing;

  const VehiclePose({required this.position, required this.bearing});
}

/// Smooth vehicle movement + rotation without rebuilding the whole screen.
///
/// - Interpolates LatLng and bearing between updates.
/// - Uses distance-based duration for natural motion.
/// - Smooths sharp turns via shortest-angle interpolation.
class VehicleAnimationService {
  VehicleAnimationService({VehiclePose? initial})
      : pose = ValueNotifier<VehiclePose?>(initial);

  final ValueNotifier<VehiclePose?> pose;

  Ticker? _ticker;
  Duration _duration = const Duration(milliseconds: 550);
  Duration _elapsed = Duration.zero;

  LatLng? _from;
  LatLng? _to;
  double _bearingFrom = 0;
  double _bearingTo = 0;

  void dispose() {
    _ticker?.dispose();
    pose.dispose();
  }

  void setImmediate(LatLng position, double bearing) {
    _stop();
    pose.value = VehiclePose(position: position, bearing: BearingUtils.normalize360(bearing));
  }

  void animateTo({
    required LatLng to,
    required double bearingTo,
    double? speedMetersPerSecond,
    // Ola/Uber-like: never too snappy, never too laggy.
    // These defaults can be overridden by callers if needed.
    double minMs = 700,
    double maxMs = 2500,
  }) {
    final current = pose.value;
    final from = current?.position ?? to;
    final bearingFrom = current?.bearing ?? bearingTo;

    _from = from;
    _to = to;
    _bearingFrom = BearingUtils.normalize360(bearingFrom);
    _bearingTo = BearingUtils.normalize360(bearingTo);

    final meters = _distanceMeters(from, to);
    final ms = _durationFor(meters, speedMetersPerSecond, minMs, maxMs);
    _duration = Duration(milliseconds: ms);
    _elapsed = Duration.zero;

    _ticker ??= Ticker(_onTick);
    if (!(_ticker!.isActive)) {
      _ticker!.start();
    }
  }

  void _onTick(Duration delta) {
    if (_from == null || _to == null) return;
    _elapsed += delta;
    final t = (_elapsed.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0);
    // Ease in-out feels most like Uber/Ola turns; avoids "teleport then stop".
    final eased = _easeInOutCubic(t);

    final from = _from!;
    final to = _to!;
    final pos = LatLng(
      _lerp(from.latitude, to.latitude, eased),
      _lerp(from.longitude, to.longitude, eased),
    );
    final bearing = BearingUtils.lerpAngle(_bearingFrom, _bearingTo, eased);
    pose.value = VehiclePose(position: pos, bearing: bearing);

    if (t >= 1.0) {
      _from = _to;
      _elapsed = Duration.zero;
      _stop(); // stop until next update (saves CPU)
    }
  }

  void _stop() {
    _ticker?.stop();
  }

  static double _easeInOutCubic(double t) =>
      t < 0.5 ? 4 * t * t * t : 1 - math.pow(-2 * t + 2, 3).toDouble() / 2;

  static double _lerp(double a, double b, double t) => a + (b - a) * t;

  static int _durationFor(
    double meters,
    double? speed,
    double minMs,
    double maxMs,
  ) {
    double ms;
    if (speed != null && speed.isFinite && speed > 0.5) {
      ms = (meters / speed) * 1000.0;
    } else {
      // fallback: assume 5 m/s
      ms = (meters / 5.0) * 1000.0;
    }
    return ms.round().clamp(minMs.round(), maxMs.round());
  }

  static double _distanceMeters(LatLng a, LatLng b) {
    final dx = (a.latitude - b.latitude) * 111320.0;
    final dy =
        (a.longitude - b.longitude) *
        111320.0 *
        math.cos(a.latitude * math.pi / 180.0);
    return math.sqrt(dx * dx + dy * dy);
  }
}
