import 'dart:async';

import 'package:geolocator/geolocator.dart';

/// Single shared foreground GPS stream for the driver app's MAP / DISPLAY
/// screens (pickup navigation, drop navigation, ride stats, shared-ride pickup,
/// and the turn-by-turn route helper).
///
/// Why: each of those screens used to open its OWN
/// `Geolocator.getPositionStream` with `LocationAccuracy.bestForNavigation`.
/// During a ride two or three of them ran at the same time, duplicating
/// Dart-side GPS callbacks (and the per-screen marker/zoom/route work they
/// trigger) on the driver device. They now share ONE underlying OS stream via
/// this bus, so there is a single foreground display subscription regardless of
/// how many map screens are mounted.
///
/// IMPORTANT — display only. The authoritative location EMITTER that feeds the
/// customer (`DriverMainController.startEmitLoop`) deliberately keeps its own,
/// separately-tuned stream (idle vs active-trip distanceFilter, token-guarded
/// rebuilds, payload construction). Re-sourcing that emitter is high risk for
/// zero customer-tracking benefit, so it is intentionally NOT routed through
/// this bus. The bus and the emitter both request `bestForNavigation`, which
/// the Android fused provider serves from a single hardware session, so this
/// does not double GPS power draw.
class DriverLocationBus {
  DriverLocationBus._();
  static final DriverLocationBus instance = DriverLocationBus._();

  // distanceFilter 0 so the OS never withholds fixes at low speed (the most
  // aggressive setting any display consumer used). Every consumer still applies
  // its own move/accuracy gate downstream, so this can never over-spam them.
  static const LocationSettings _settings = LocationSettings(
    accuracy: LocationAccuracy.bestForNavigation,
    distanceFilter: 0,
  );

  StreamController<Position>? _controller;
  StreamSubscription<Position>? _upstream;
  Position? _last;

  /// Latest fix the bus has seen (null until the first one), for screens that
  /// want to seed their marker immediately instead of waiting for the next fix.
  Position? get last => _last;

  /// Broadcast stream of foreground GPS fixes. The underlying OS stream is
  /// started lazily on the first listener and stopped when the last listener
  /// cancels, so it consumes nothing while no map screen is mounted.
  Stream<Position> get stream {
    _controller ??= StreamController<Position>.broadcast(
      onListen: _start,
      onCancel: _stopIfIdle,
    );
    return _controller!.stream;
  }

  void _start() {
    if (_upstream != null) return;
    _upstream = Geolocator.getPositionStream(locationSettings: _settings).listen(
      (pos) {
        _last = pos;
        _controller?.add(pos);
      },
      // Swallow transient platform stream errors so the shared bus stays alive
      // (matches the previous per-screen behaviour, which had no error handler).
      onError: (_) {},
      cancelOnError: false,
    );
  }

  void _stopIfIdle() {
    if (_controller?.hasListener ?? false) return;
    _upstream?.cancel();
    _upstream = null;
  }
}
