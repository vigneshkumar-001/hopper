import 'package:hopper/Core/Constants/log.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

/// DUAL-CONNECT secondary socket to the SINGLE-ride backend (bk).
///
/// Kept alive ONLY while the driver has "Shared Booking" ON and is IDLE (no
/// active ride). The driver's PRIMARY [SocketService] is on the shared backend
/// (bck) in that state, so without this they would never receive customer
/// "Ride Only" requests (which the single backend dispatches over ITS socket).
///
/// Its sole responsibilities:
///   1. `register` the driver on bk so bk's dispatcher can target them in
///      real time (the single backend delivers a booking request over the
///      driver's socket, FCM push only as a fallback).
///   2. relay incoming `booking-request` events to a callback so the app can
///      show the single-ride request while shared-enabled.
///
/// It deliberately does NOT emit location/heartbeat — both backends share one
/// MongoDB and the shared primary already keeps the (single) DriverLiveTracking
/// row fresh (see backend `updateDriverLocation` writing `lastLocationAt`). It
/// also does NOT manage booking rooms. The instant the driver ACCEPTS any ride,
/// this is torn down and the primary socket is bound to that ride's backend
/// (see ApiConfigController.bindActiveRideBackend), so there is never more than
/// one socket per backend at a time — no same-backend revoke contention.
class SecondaryDispatchSocket {
  static final SecondaryDispatchSocket _instance =
      SecondaryDispatchSocket._internal();
  factory SecondaryDispatchSocket() => _instance;
  SecondaryDispatchSocket._internal();

  IO.Socket? _socket;
  String? _url;
  String? _driverId;
  String? _deviceId;
  // Register-dedupe (mirrors the primary socket): skip an identical register for
  // the same connection fired within 2s (onConnect + onReconnect double-fire).
  String? _lastRegSig;
  DateTime? _lastRegAt;
  void Function(dynamic data)? _onBookingRequest;

  bool get active => _socket != null;
  bool get connected => _socket?.connected ?? false;
  String? get currentUrl => _url;

  /// Start (or refresh) the secondary dispatch listener against [url] (bk).
  /// Idempotent: calling again with the same url just ensures it's connected.
  void start({
    required String url,
    required String driverId,
    String? deviceId,
    required void Function(dynamic data) onBookingRequest,
  }) {
    _onBookingRequest = onBookingRequest;
    _driverId = driverId;
    if (deviceId != null && deviceId.trim().isNotEmpty) {
      _deviceId = deviceId.trim();
    }

    if (_socket != null && _url == url) {
      if (_socket!.disconnected) _socket!.connect();
      return;
    }

    // Different url (or first start): drop any prior socket cleanly.
    stop();
    _url = url;

    _socket = IO.io(
      url,
      IO.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .enableReconnection()
          .enableAutoConnect()
          .setReconnectionAttempts(999999)
          .setReconnectionDelay(1000)
          .setReconnectionDelayMax(8000)
          .setTimeout(15000)
          .build(),
    );

    final s = _socket!;

    s.onConnect((_) {
      CommonLogger.log.i(
        "✅ [dual-connect] secondary(bk) connected url=$_url id=${s.id}",
      );
      _register();
    });

    s.onReconnect((_) {
      CommonLogger.log.i("🔄 [dual-connect] secondary(bk) reconnected url=$_url");
      _register();
    });

    s.onDisconnect((reason) {
      CommonLogger.log.w(
        "ℹ️ [dual-connect] secondary(bk) disconnected url=$_url reason=$reason",
      );
    });

    s.on('booking-request', (data) {
      CommonLogger.log.i("📥 [dual-connect] secondary(bk) booking-request");
      try {
        _onBookingRequest?.call(data);
      } catch (e) {
        CommonLogger.log.e("[dual-connect] secondary booking-request error: $e");
      }
    });

    s.connect();
  }

  void _register() {
    final id = _driverId;
    final s = _socket;
    if (id == null || id.trim().isEmpty || s == null) return;
    // DEDUPE: skip identical register for the same connection within 2s.
    final sig = '${s.id}|$id|driver|${_deviceId ?? ''}';
    final now = DateTime.now();
    if (sig == _lastRegSig &&
        _lastRegAt != null &&
        now.difference(_lastRegAt!) < const Duration(seconds: 2)) {
      return;
    }
    _lastRegSig = sig;
    _lastRegAt = now;
    final payload = <String, dynamic>{
      "userId": id,
      "type": "driver",
      if (_deviceId != null) "deviceId": _deviceId,
    };
    s.emit('register', payload);
    CommonLogger.log.i("🙋 [dual-connect] secondary(bk) registered → $payload");
  }

  /// Tear the secondary socket down completely. Called on accept (any ride),
  /// when Shared Booking is turned off, and on logout.
  void stop() {
    final had = _socket != null;
    try {
      _socket?.offAny();
      _socket?.off('booking-request');
      _socket?.disconnect();
      _socket?.dispose();
    } catch (_) {}
    _socket = null;
    _url = null;
    if (had) {
      CommonLogger.log.i("🛑 [dual-connect] secondary(bk) stopped");
    }
  }
}
