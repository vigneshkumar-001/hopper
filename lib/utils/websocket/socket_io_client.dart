import 'package:flutter/foundation.dart';
import 'package:hopper/Core/Constants/log.dart';
import 'package:hopper/Core/Services/socket_logger_util.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  IO.Socket? _socket;
  IO.Socket get socket => _socket!;

  String? _socketUrl;
  bool _initialized = false;

  bool get connected => _socket?.connected ?? false;
  String? get currentUrl => _socketUrl;

  /// True after the backend revoked this session (a newer socket for the same
  /// userId took over). While true we suppress auto-reconnect. The foreground
  /// owner reclaims via an intentional connect() — see `_sessionRevoked`.
  bool get sessionRevoked => _sessionRevoked;

  String? _userId;
  String? _driverId;
  String? _bookingId;
  // Stable per-install identifier (the FCM token). Sent on `register` so the
  // backend can tell THIS device's foreground<->background socket handoff apart
  // from a genuine login on a DIFFERENT device. Without it the backend treats
  // our own background isolate's socket as a `new-device-login` and revokes the
  // foreground (the self-revoke seen in the logs).
  String? _deviceId;

  final List<String> _joinedRooms = [];
  final Map<String, Function(dynamic)> _callbacks = {};
  DateTime _lastManualReconnectAt = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastUpdateLocationLogAt = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastHeartbeatLogAt = DateTime.fromMillisecondsSinceEpoch(0);
  final Map<String, DateTime> _lastHighFreqEmitAtByKey = <String, DateTime>{};
  final Map<String, String> _lastHighFreqEmitSigByKey = <String, String>{};
  int _clientLocationSeq = 0;

  // C8: small in-memory buffer of the most recent `updateLocation` payloads that
  // were emitted while the socket was disconnected during an active ride. Flushed
  // (latest-first, capped) AFTER rooms are rejoined on reconnect, so a few seconds
  // of drop no longer silently loses the driver's trail / freezes the customer
  // marker. In-memory only — never persisted. Heartbeat is NOT buffered (it is a
  // keepalive; only the latest matters).
  static const int _MAX_LOCATION_BUFFER = 40;
  static const int _MAX_LOCATION_FLUSH = 10;
  final List<Map<String, dynamic>> _locationBuffer = <Map<String, dynamic>>[];
  bool _flushingBuffer = false;

  // Single-session coordination. The backend enforces ONE active socket per
  // userId: when a newer socket registers (the background-tracking isolate
  // taking over on app-pause, a reconnect that opened a fresh connection, or the
  // same driver on another device), the server emits `session-revoked` to the
  // older socket and disconnects it (reason "server namespace disconnect").
  // Without this guard the revoked socket auto-reconnected and re-registered,
  // which then revoked the OTHER socket — an endless revoke-war that surfaced as
  // the driver socket "randomly disconnecting" until the app was killed and
  // reopened. When revoked we STOP auto-reconnecting; only an intentional
  // (re)connect — app resume, go-online, screen init, URL switch — reclaims the
  // session and clears this flag.
  bool _sessionRevoked = false;

  // Explicit handoff suspension. Set by the foreground controller the moment it
  // begins handing the live session to the background-tracking isolate (driver
  // taps "Navigate" / app pauses). Unlike `_sessionRevoked` — which is only set
  // when the backend's `session-revoked` EVENT is delivered — this is set
  // SYNCHRONOUSLY before the background socket can register, closing the race
  // where the foreground processes its "io server disconnect" (from the backend
  // revoking it for the new background session) BEFORE the buffered
  // `session-revoked` event arrives, and therefore auto-reconnects + re-registers
  // — which then revokes the background socket (revoke-war) and freezes customer
  // tracking while Google Maps is open. Cleared by an intentional reclaim
  // (connect()/initSocket()/switchUrl()) on app resume.
  bool _autoReconnectSuspended = false;

  // Debug-only: log every socket emit (very chatty).
  // Always enabled in debug builds as requested.

  static const int _MAX_ACTIVE_BOOKING_ROOMS = 50;

  List<String> _normalizeRooms(Iterable<String> rooms) {
    final normalized =
        rooms.map((e) => e.trim()).where((e) => e.isNotEmpty).toSet().toList();
    if (normalized.length <= _MAX_ACTIVE_BOOKING_ROOMS) return normalized;
    return normalized.sublist(
      normalized.length - _MAX_ACTIVE_BOOKING_ROOMS,
      normalized.length,
    );
  }

  /// Replaces the currently tracked booking rooms (used for shared rides).
  /// Prevents emitting location/heartbeat to old/completed rooms.
  void setActiveBookingRooms(
    Iterable<String> rooms, {
    String? primaryBookingId,
  }) {
    final normalized = _normalizeRooms(rooms);
    _joinedRooms
      ..clear()
      ..addAll(normalized);
    if (primaryBookingId != null && primaryBookingId.trim().isNotEmpty) {
      _bookingId = primaryBookingId.trim();
    }
  }

  void clearAllBookingRooms() {
    _bookingId = null;
    _joinedRooms.clear();
    _lastHighFreqEmitAtByKey.clear();
    _lastHighFreqEmitSigByKey.clear();
    _locationBuffer.clear(); // C8: ride ended — drop any buffered trail
  }

  void setSingleActiveBookingRoom(String bookingId) {
    final id = bookingId.trim();
    if (id.isEmpty) {
      clearAllBookingRooms();
      return;
    }
    _bookingId = id;
    _joinedRooms
      ..clear()
      ..add(id);
  }

  void _ensureConnecting() {
    if (!_initialized) return;
    if (_sessionRevoked) return; // revoked: wait for an intentional reclaim
    final s = _socket;
    if (s == null) return;
    if (s.disconnected) {
      try {
        _safeManualReconnect();
      } catch (_) {}
    }
  }

  void _recreateSocket({required String reason}) {
    final url = _socketUrl;
    if (!_initialized || url == null || url.trim().isEmpty) return;

    CommonLogger.log.w("♻️ [SOCKET] Recreate socket url=$url reason=$reason");

    try {
      // Remove ALL listeners (not just onAny) BEFORE disconnecting/disposing.
      // `offAny()` leaves the named `onDisconnect` handler bound, so the dying
      // socket's "forced close" would re-enter `_safeManualReconnect` → recreate
      // → a fresh socket → which dies → a self-sustaining reconnect storm (the
      // ~2s loop seen on return from Google Maps). Clearing listeners first makes
      // teardown silent so only an intentional reclaim brings the socket back.
      _socket?.clearListeners();
      _socket?.disconnect();
      _socket?.dispose();
    } catch (_) {}

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

    _bindCoreEvents();
    SocketLoggerUtil.setupSocketLogging(_socket!);
    _socket!.connect();
  }

  /// Tracks a booking room locally (used for shared rides) without emitting any
  /// socket event or changing the active booking context.
  void rememberBookingRoom(String bookingId) {
    final id = bookingId.trim();
    if (id.isEmpty) return;
    if (!_joinedRooms.contains(id)) _joinedRooms.add(id);
    if (_joinedRooms.length > _MAX_ACTIVE_BOOKING_ROOMS) {
      _joinedRooms.removeRange(
        0,
        _joinedRooms.length - _MAX_ACTIVE_BOOKING_ROOMS,
      );
    }
  }

  void clearBookingContext({String? bookingId}) {
    final id = bookingId ?? _bookingId;
    if (id != null && id.trim().isNotEmpty) {
      _joinedRooms.removeWhere((r) => r == id);
      _lastHighFreqEmitAtByKey.remove('updateLocation|$id');
      _lastHighFreqEmitAtByKey.remove('driver-heartbeat|$id');
      _lastHighFreqEmitSigByKey.remove('updateLocation|$id');
      _lastHighFreqEmitSigByKey.remove('driver-heartbeat|$id');
    }
    if (bookingId == null || bookingId == _bookingId) {
      _bookingId = null;
    }
  }

  int nextClientLocationSeq() {
    // Monotonic across ISOLATES. The driver emits location from two separate
    // isolates with independent memory: this foreground SocketService and the
    // background location service (background_service.dart). A per-instance
    // counter restarts at 0 in each isolate, so when the driver opens Google
    // Maps (foreground -> background handoff) the background stream carries low
    // seq numbers that the customer's seq-gate (`seq <= lastSeq` -> drop)
    // rejects wholesale -> the customer marker freezes for the entire
    // navigation. Deriving seq from the device wall clock (shared by both
    // isolates) makes it one strictly-increasing space across the handoff.
    final int nowMs = DateTime.now().millisecondsSinceEpoch;
    _clientLocationSeq =
        nowMs > _clientLocationSeq ? nowMs : _clientLocationSeq + 1;
    return _clientLocationSeq;
  }

  // ---------------------------------------------------------
  // ✅ INIT socket (create once per URL)
  // ---------------------------------------------------------
  void initSocket(String url) {
    // Any explicit init is an intentional session (re)claim.
    _sessionRevoked = false;
    // same url already initialized -> just connect if needed
    if (_initialized && _socketUrl == url) {
      if (_socket != null && _socket!.disconnected) _socket!.connect();
      return;
    }

    // url changed -> switch
    if (_initialized && _socketUrl != url) {
      switchUrl(url);
      return;
    }

    _socketUrl = url;
    _initialized = true;

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

    _bindCoreEvents();
    SocketLoggerUtil.setupSocketLogging(_socket!);
    _socket!.connect();
  }

  // ---------------------------------------------------------
  // ✅ SWITCH URL (Shared <-> Single)
  // ---------------------------------------------------------
  void switchUrl(String newUrl) {
    // Switching URL is an intentional session (re)claim on the new endpoint.
    _sessionRevoked = false;
    if (_socketUrl == newUrl && _initialized) {
      if (_socket != null && _socket!.disconnected) _socket!.connect();
      return;
    }

    CommonLogger.log.i("🔁 Switching socket URL: $_socketUrl -> $newUrl");

    // dispose old socket but keep state (ids, rooms, callbacks)
    try {
      // Clear ALL listeners first (see _recreateSocket): `offAny()` alone leaves
      // the named onDisconnect bound, so the old socket's teardown "forced close"
      // could trigger a reconnect on the controller and fight the new URL's
      // socket — a revoke/reconnect war. Silent teardown avoids that.
      _socket?.clearListeners();
      _socket?.disconnect();
      _socket?.dispose();
    } catch (_) {}

    _socketUrl = newUrl;

    _socket = IO.io(
      newUrl,
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

    _bindCoreEvents();
    _socket!.connect();
  }

  // ---------------------------------------------------------
  // ✅ Bind core events
  // ---------------------------------------------------------
  void _bindCoreEvents() {
    final s = _socket;
    if (s == null) return;

    s.onConnect((_) {
      CommonLogger.log.i("✅ Connected: $_socketUrl | id: ${s.id}");

      // after connect -> restore everything
      _restoreRegistration();
      _restoreJoinedRooms();
      _restoreEventListeners();
      // C8: rooms are rejoined above — now flush any locations buffered while down.
      _flushLocationBuffer();
      // H8: single stored external connect callback (never stacked).
      _externalConnectCb?.call();
    });

    s.onDisconnect((reason) {
      final r = reason?.toString() ?? '';
      final rl = r.toLowerCase();

      // `io client disconnect` happens when we explicitly call `disconnect()` or
      // `dispose()` (e.g., background handoff or URL switching). This is expected
      // and should not look like a production failure.
      if (rl.contains('io client disconnect')) {
        CommonLogger.log.i(
          "ℹ️ Disconnected (client): $_socketUrl | reason: $reason",
        );
        return;
      }

      // Single-session revoke: a newer socket for this userId took over. Do NOT
      // auto-reconnect (that would revoke the newer socket -> revoke-war). Wait
      // for an intentional reclaim (resume / online / screen init).
      if (rl.contains('server namespace disconnect')) {
        _sessionRevoked = true;
        CommonLogger.log.w(
          "🚫 Session revoked (namespace disconnect): $_socketUrl — staying down until an intentional reconnect",
        );
        return;
      }

      CommonLogger.log.e("❌ Disconnected: $_socketUrl | reason: $reason");

      // If server explicitly disconnected us, socket.io may not auto-reconnect.
      // Attempt a safe manual reconnect (debounced).
      final isServerDisconnect =
          rl.contains('io server disconnect') ||
          rl.contains('server disconnect');
      if (isServerDisconnect) {
        _safeManualReconnect();
        return;
      }

      final shouldNudgeReconnect =
          rl.contains('ping timeout') ||
          rl.contains('transport close') ||
          rl.contains('forced close') ||
          rl.contains('timeout');
      if (shouldNudgeReconnect) {
        _safeManualReconnect();
      }
    });

    s.onReconnect((_) {
      CommonLogger.log.i("🔄 Reconnected: $_socketUrl");

      // safety restore (socket.io should keep listeners, but we do safe)
      _restoreRegistration();
      _restoreJoinedRooms();
      _restoreEventListeners();
      // C8: flush buffered locations after rooms are rejoined on reconnect.
      _flushLocationBuffer();
      // H8: single stored external reconnect callback (never stacked).
      _externalReconnectCb?.call();
    });

    s.onConnectError((err) {
      CommonLogger.log.e("⚠️ Connect error: $err | $_socketUrl");
      _safeManualReconnect();
    });

    s.onError((err) {
      CommonLogger.log.e("⚠️ Socket error: $err");
      _safeManualReconnect();
    });

    s.onReconnectAttempt((attempt) {
      CommonLogger.log.i("🔁 Reconnect attempt: $attempt | url=$_socketUrl");
    });
    s.onReconnectError((err) {
      CommonLogger.log.e("⚠️ Reconnect error: $err | url=$_socketUrl");
    });
    s.onReconnectFailed((_) {
      CommonLogger.log.e("❌ Reconnect failed | url=$_socketUrl");
    });

    // Explicit single-session signal from the backend (sent to the OLDER socket
    // right before it is disconnected). Suppress auto-reconnect so this socket
    // stops fighting the newer session for the same userId.
    s.on('session-revoked', (_) {
      _sessionRevoked = true;
      CommonLogger.log.w(
        "🚫 [SOCKET] session-revoked received url=$_socketUrl — another session "
        "took over; suppressing auto-reconnect until an intentional reclaim",
      );
    });

    if (kDebugMode) {
      s.onAny((event, data) {
        CommonLogger.log.i("Url: $_socketUrl\n📦 [onAny] $event → $data");
      });
    }
  }

  // ---------------------------------------------------------
  // ✅ Manual connect
  // ---------------------------------------------------------
  void connect() {
    // Intentional (re)claim of the session: clear any prior revoke / handoff
    // suspension so this socket is allowed to reconnect and become the active
    // session again (app resume reclaims the foreground after Maps).
    _sessionRevoked = false;
    _autoReconnectSuspended = false;
    if (_initialized && _socket != null && _socket!.disconnected) {
      _socket!.connect();
    }
  }

  /// Suspend ALL auto-reconnect for this (foreground) socket while the live
  /// session is handed off to the background-tracking isolate. Call this BEFORE
  /// starting the background service so a backend revoke of this socket can never
  /// race the `session-revoked` event into an auto-reconnect → revoke-war that
  /// kills the background socket and freezes customer tracking. Reversed by the
  /// intentional reclaim in connect() on app resume.
  void suspendAutoReconnect() {
    _autoReconnectSuspended = true;
  }

  void disconnect() {
    try {
      _socket?.disconnect();
    } catch (_) {}
  }

  void _safeManualReconnect() {
    // Session was revoked by a newer socket for this userId, OR we are mid-handoff
    // to the background isolate. Reconnecting here would re-register and revoke
    // that newer/background socket -> revoke-war (the Google-Maps freeze). Stay
    // down until an intentional reclaim (connect()/initSocket()/switchUrl()).
    if (_sessionRevoked || _autoReconnectSuspended) {
      CommonLogger.log.w(
        "🚫 [SOCKET] Reconnect suppressed (revoked=$_sessionRevoked handoff=$_autoReconnectSuspended) url=$_socketUrl",
      );
      return;
    }
    final now = DateTime.now();
    if (now.difference(_lastManualReconnectAt) < const Duration(seconds: 2)) {
      return;
    }
    _lastManualReconnectAt = now;

    final s = _socket;
    if (!_initialized || s == null) return;

    // Avoid spamming connect() while a connect is already in progress.
    String? readyState;
    try {
      readyState = s.io.readyState.toString();
      final rs = readyState.toLowerCase();

      if (rs == 'closed' || rs == 'closing') {
        _recreateSocket(reason: 'readyState=$readyState');
        return;
      }
      if (rs == 'opening') {
        CommonLogger.log.w(
          "⏳ [SOCKET] Reconnect skipped (already opening) url=$_socketUrl connected=$connected readyState=$readyState",
        );
        return;
      }
    } catch (_) {}

    CommonLogger.log.w(
      "🔌 [SOCKET] Reconnect nudge url=$_socketUrl connected=$connected readyState=${readyState ?? 'unknown'}",
    );
    connect();
  }

  // ---------------------------------------------------------
  // ✅ BACKWARD COMPATIBILITY (so your old code won't error)
  // ---------------------------------------------------------
  // H8: external connect/reconnect callbacks are STORED (single slot each) and
  // fanned out from the internal handlers in _bindCoreEvents — never re-registered
  // on the raw socket. This stops connect/reconnect handlers from STACKING on
  // controller recreate / reconnect / app resume (the raw `_socket.onConnect`
  // added a new listener on every call). `on()` already dedupes per event.
  Function()? _externalConnectCb;
  Function()? _externalReconnectCb;

  void onConnect(Function() callback) => _externalConnectCb = callback;
  void onReconnect(Function() callback) => _externalReconnectCb = callback;

  // ---------------------------------------------------------
  // ✅ Register customer
  // ---------------------------------------------------------
  /// Set the stable per-install device id (FCM token) included on every
  /// `register` so the backend can dedupe this device's own foreground/background
  /// sockets instead of revoking them as a `new-device-login`.
  void setDeviceId(String? id) {
    final v = id?.trim();
    if (v != null && v.isNotEmpty) _deviceId = v;
  }

  void registerUser(String userId, {String? bookingId}) {
    _userId = userId;
    _driverId = null;
    _updateBookingId(bookingId);

    final payload = <String, dynamic>{
      "userId": userId,
      "type": "customer",
      if (_deviceId != null) "deviceId": _deviceId,
      if (_bookingId != null) "bookingId": _bookingId,
    };

    if (!connected) {
      _ensureConnecting();
      CommonLogger.log.w(
        "⏳ Customer registration queued (socket disconnected) → $payload via $_socketUrl",
      );
      return;
    }

    emit('register', payload);
    CommonLogger.log.i("🙋 Customer registered → $payload via $_socketUrl");
  }

  // ---------------------------------------------------------
  // ✅ Register driver
  // ---------------------------------------------------------
  void registerDriver(
    String driverId, {
    String? bookingId,
    Function(dynamic)? ack,
  }) {
    _driverId = driverId;
    _userId = null;
    if (bookingId != null) _bookingId = bookingId;

    final payload = <String, dynamic>{
      "userId": driverId,
      "type": "driver",
      if (_deviceId != null) "deviceId": _deviceId,
      if (_bookingId != null) "bookingId": _bookingId,
    };

    if (_socket == null) return;

    if (!connected) {
      _ensureConnecting();
      CommonLogger.log.w(
        "⏳ Driver registration queued (socket disconnected) → $payload via $_socketUrl",
      );
      return;
    }

    if (ack != null) {
      _socket!.emitWithAck('register', payload, ack: ack);
      CommonLogger.log.i("🙋 Driver registered with ACK → $payload");
    } else {
      emit('register', payload);
      CommonLogger.log.i("🙋 Driver registered → $payload");
    }
  }

  // ---------------------------------------------------------
  // ✅ Join booking room
  // ---------------------------------------------------------
  void joinBooking(String bookingId, {String? userId}) {
    _updateBookingId(bookingId);

    final payload = <String, dynamic>{
      "bookingId": bookingId,
      "userId": userId ?? _userId ?? _driverId,
    };

    if (!_joinedRooms.contains(bookingId)) _joinedRooms.add(bookingId);
    if (_joinedRooms.length > _MAX_ACTIVE_BOOKING_ROOMS) {
      _joinedRooms.removeRange(
        0,
        _joinedRooms.length - _MAX_ACTIVE_BOOKING_ROOMS,
      );
    }

    if (!connected) {
      _ensureConnecting();
      CommonLogger.log.w(
        "⏳ Join booking queued (socket disconnected) → $payload via $_socketUrl",
      );
      return;
    }

    emit('join-booking', payload);
    CommonLogger.log.i("📡 Joined booking → $payload");
  }

  // ---------------------------------------------------------
  // ✅ Listen event (normal)
  // ---------------------------------------------------------
  void on(String event, Function(dynamic data) callback) {
    final prev = _callbacks[event];
    _callbacks[event] = callback;

    // IMPORTANT: don't call `off(event)` without a handler — it removes *all*
    // listeners, including core listeners added via `onConnect/onReconnect`.
    if (prev != null) {
      _socket?.off(event, prev);
    }
    _socket?.on(event, callback);
  }

  // ---------------------------------------------------------
  // ✅ Listen event WITH ACK support (client can reply to server)
  //
  // Use:
  // socketService.onAck("booking-request", (data, ack) {
  //   ack?.call({"ok": true});
  // });
  // ---------------------------------------------------------
  void onAck(
    String event,
    void Function(dynamic data, void Function(dynamic response)? ack) callback,
  ) {
    final prev = _callbacks[event];
    _callbacks[event] = (dynamic incoming) {
      void Function(dynamic)? ackFn;

      // Some servers send [payload, ackFn]
      if (incoming is List && incoming.isNotEmpty) {
        final payload = incoming[0];

        if (incoming.length > 1 && incoming[1] is Function) {
          final fn = incoming[1] as Function;
          ackFn = (dynamic res) => fn(res);
        }

        callback(payload, ackFn);
        return;
      }

      // Normal payload without ack
      callback(incoming, null);
    };
    if (prev != null) {
      // Remove only our previously bound handler.
      _socket?.off(event, prev);
    }
    _socket?.on(event, _callbacks[event]!);
  }

  // ---------------------------------------------------------
  // ✅ Emit
  // ---------------------------------------------------------
  void emit(String event, dynamic data) {
    // If we emit while disconnected, socket.io may queue, but ensure we are
    // actively reconnecting (helps after URL switches / background-resume).
    // Skip while session-revoked: a high-frequency updateLocation must not
    // silently re-register and trigger a revoke-war (see _sessionRevoked).
    if (_initialized &&
        _socket != null &&
        _socket!.disconnected &&
        !_sessionRevoked) {
      _socket!.connect();
    }
    final s = _socket;
    if (s == null) return;

    // Location/heartbeat are high-frequency and should not be queued while we are
    // offline/DNS-failing. Drop them until the socket is connected again.
    if (!connected &&
        (event == 'updateLocation' || event == 'driver-heartbeat') &&
        data is Map) {
      // Nudge reconnect so when internet comes back we recover without requiring
      // a manual action/screen re-init.
      _safeManualReconnect();
      // C8: buffer location (NOT heartbeat) so a short disconnect during an active
      // ride doesn't lose the trail — it is flushed after reconnect + room restore.
      if (event == 'updateLocation') {
        _bufferLocation(Map<String, dynamic>.from(data));
      }
      _maybeLogDroppedEmit(
        event: event,
        payload: Map<String, dynamic>.from(data),
        reason: 'socket disconnected',
      );
      return;
    }

    // Shared-ride support: when multiple booking rooms are active, location +
    // heartbeat must be sent to each room so every rider receives live updates.
    if ((event == 'updateLocation' || event == 'driver-heartbeat') &&
        data is Map) {
      final rooms =
          _joinedRooms
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toSet()
              .toList();

    if (rooms.isNotEmpty) {
        final base = Map<String, dynamic>.from(data);
        final booking = (base['bookingId'] ?? '').toString().trim();

        // If we only have 1 room, ensure bookingId is present.
        if (rooms.length == 1 && booking.isEmpty) {
          base['bookingId'] = rooms.first;
          if (!_shouldSkipDuplicateHighFreqEmit(event: event, payload: base)) {
            s.emit(event, base);
          }
        } else if (rooms.length > 1) {
          for (final room in rooms) {
            final payload = Map<String, dynamic>.from(base);
            payload['bookingId'] = room;
            if (_shouldSkipDuplicateHighFreqEmit(
              event: event,
              payload: payload,
            )) {
              continue;
            }
            s.emit(event, payload);
          }
        } else {
          if (!_shouldSkipDuplicateHighFreqEmit(event: event, payload: base)) {
            s.emit(event, base);
          }
        }

        _maybeLogEmit(event: event, payload: base, roomsCount: rooms.length);
        if (kDebugMode) {
          CommonLogger.log.i(
            '[SOCKET_EMIT_ALL] url=$_socketUrl event=$event rooms=${rooms.length} payload=$base',
          );
        }
        return;
      }
    }

    if (data is Map &&
        _shouldSkipDuplicateHighFreqEmit(
          event: event,
          payload: Map<String, dynamic>.from(data),
        )) {
      return;
    }

    s.emit(event, data);

    if (data is Map) {
      _maybeLogEmit(event: event, payload: Map<String, dynamic>.from(data));
      if (kDebugMode) {
        CommonLogger.log.i(
          '[SOCKET_EMIT_ALL] url=$_socketUrl event=$event payload=${Map<String, dynamic>.from(data)}',
        );
      }
    } else {
      if (kDebugMode) {
        CommonLogger.log.i('[SOCKET_EMIT_ALL] url=$_socketUrl event=$event data=$data');
      }
    }
  }

  // C8: append a location fix to the disconnect buffer. Only valid fixes are kept,
  // newest wins when the cap is exceeded (drop the oldest tail).
  void _bufferLocation(Map<String, dynamic> payload) {
    final lat = payload['latitude'];
    final lng = payload['longitude'];
    if (lat is! num || lng is! num || !lat.isFinite || !lng.isFinite) return;
    _locationBuffer.add(payload);
    if (_locationBuffer.length > _MAX_LOCATION_BUFFER) {
      _locationBuffer.removeRange(0, _locationBuffer.length - _MAX_LOCATION_BUFFER);
    }
  }

  // C8: flush buffered locations after reconnect. Call ONLY after rooms are
  // rejoined. Sends at most the latest `_MAX_LOCATION_FLUSH` fixes in chronological
  // order (so the customer's seq-gate accepts them and the marker resumes smoothly)
  // and never spams a long stale trail. Re-entrancy guarded against double flush.
  void _flushLocationBuffer() {
    if (_flushingBuffer || _locationBuffer.isEmpty || !connected) return;
    _flushingBuffer = true;
    try {
      final pending = List<Map<String, dynamic>>.from(_locationBuffer);
      _locationBuffer.clear();
      final start = pending.length > _MAX_LOCATION_FLUSH
          ? pending.length - _MAX_LOCATION_FLUSH
          : 0;
      final toSend = pending.sublist(start); // oldest -> newest of the latest N
      for (final payload in toSend) {
        emit('updateLocation', payload);
      }
      CommonLogger.log.i(
        '🔁 [SOCKET] Flushed ${toSend.length} buffered location(s) after reconnect url=$_socketUrl',
      );
    } finally {
      _flushingBuffer = false;
    }
  }

  bool _shouldSkipDuplicateHighFreqEmit({
    required String event,
    required Map<String, dynamic> payload,
  }) {
    // Safety valve: if multiple timers/isolates accidentally send the same
    // location/heartbeat payload in rapid succession, drop duplicates to avoid
    // server-side "emit spam" and UI jitter.
    if (event != 'updateLocation' && event != 'driver-heartbeat') return false;

    final bookingId = (payload['bookingId'] ?? '').toString().trim();
    final key = '$event|$bookingId';

    final lat = payload['latitude'];
    final lng = payload['longitude'];
    final ts = payload['timestamp'];
    final sig = '$lat,$lng,$ts';

    final now = DateTime.now();
    final lastAt = _lastHighFreqEmitAtByKey[key];
    final lastSig = _lastHighFreqEmitSigByKey[key];

    if (lastAt != null &&
        lastSig == sig &&
        now.difference(lastAt) < const Duration(seconds: 2)) {
      return true;
    }

    _lastHighFreqEmitAtByKey[key] = now;
    _lastHighFreqEmitSigByKey[key] = sig;
    return false;
  }

  void _maybeLogDroppedEmit({
    required String event,
    required Map<String, dynamic> payload,
    required String reason,
  }) {
    if (event != 'updateLocation' && event != 'driver-heartbeat') return;

    // Avoid log spam while offline: log at most once per minute per event in
    // release builds, but keep debug chatty.
    final now = DateTime.now();
    final isDebug = kDebugMode;

    if (!isDebug) {
      final last =
          event == 'updateLocation'
              ? _lastUpdateLocationLogAt
              : _lastHeartbeatLogAt;
      if (now.difference(last) < const Duration(seconds: 60)) return;
      if (event == 'updateLocation') {
        _lastUpdateLocationLogAt = now;
      } else {
        _lastHeartbeatLogAt = now;
      }
    }

    final bookingId = (payload['bookingId'] ?? '').toString();
    final lat = payload['latitude'];
    final lng = payload['longitude'];
    final ts = payload['timestamp'];

    CommonLogger.log.w(
      '🛑 [SOCKET_DROP] $event url=$_socketUrl connected=$connected bookingId=$bookingId lat=$lat lng=$lng ts=$ts reason=$reason',
    );
  }

  void _maybeLogEmit({
    required String event,
    required Map<String, dynamic> payload,
    int? roomsCount,
  }) {
    if (event != 'updateLocation' && event != 'driver-heartbeat') return;

    // In release builds, avoid spamming logs; still log occasionally so we can
    // verify emits in production.
    final now = DateTime.now();
    final isDebug = kDebugMode;

    if (!isDebug) {
      final last =
          event == 'updateLocation'
              ? _lastUpdateLocationLogAt
              : _lastHeartbeatLogAt;
      if (now.difference(last) < const Duration(seconds: 60)) return;
      if (event == 'updateLocation') {
        _lastUpdateLocationLogAt = now;
      } else {
        _lastHeartbeatLogAt = now;
      }
    }

    final id = _socket?.id;
    final bookingId = (payload['bookingId'] ?? '').toString();
    final lat = payload['latitude'];
    final lng = payload['longitude'];
    final ts = payload['timestamp'];
    final rooms = roomsCount == null ? '' : ' rooms=$roomsCount';

    CommonLogger.log.i(
      '📍 [SOCKET_EMIT] $event url=$_socketUrl id=$id connected=$connected$rooms bookingId=$bookingId lat=$lat lng=$lng ts=$ts',
    );
  }

  // ---------------------------------------------------------
  // ✅ Emit with ack (server replies back)
  // ---------------------------------------------------------
  void emitWithAck(String event, dynamic data, Function(dynamic)? ack) {
    if (_initialized && _socket != null && _socket!.disconnected) {
      _socket!.connect();
    }
    _socket?.emitWithAck(event, data, ack: ack);
  }

  // ---------------------------------------------------------
  // ✅ Off
  // ---------------------------------------------------------
  void off(String event) {
    final prev = _callbacks.remove(event);
    if (prev != null) {
      _socket?.off(event, prev);
      return;
    }

    // Fallback: if we don't own the handler reference, do nothing to avoid
    // accidentally removing core listeners.
  }

  // ---------------------------------------------------------
  // ✅ Dispose (full reset)
  // ---------------------------------------------------------
  void dispose() {
    try {
      _socket?.offAny();
      _socket?.disconnect();
      _socket?.dispose();
    } catch (_) {}

    _socket = null;
    _socketUrl = null;
    _initialized = false;

    _userId = null;
    _driverId = null;
    _bookingId = null;
    _joinedRooms.clear();
    _callbacks.clear();
    _locationBuffer.clear(); // C8
  }

  // ---------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------
  void _updateBookingId(String? bookingId) {
    if (bookingId != null) {
      _bookingId = bookingId;
      if (!_joinedRooms.contains(bookingId)) _joinedRooms.add(bookingId);
      if (_joinedRooms.length > _MAX_ACTIVE_BOOKING_ROOMS) {
        _joinedRooms.removeRange(
          0,
          _joinedRooms.length - _MAX_ACTIVE_BOOKING_ROOMS,
        );
      }
    }
  }

  void _restoreRegistration() {
    if (_socket == null) return;

    if (_driverId != null) {
      registerDriver(_driverId!, bookingId: _bookingId);
    } else if (_userId != null) {
      registerUser(_userId!, bookingId: _bookingId);
    }
  }

  void _restoreJoinedRooms() {
    final rooms = _normalizeRooms(_joinedRooms);
    if (rooms.isEmpty) return;

    final who = (_userId ?? _driverId)?.toString().trim();
    final logEach = kDebugMode && rooms.length <= 6;
    if (!logEach) {
      CommonLogger.log.i("🔄 Restoring ${rooms.length} booking room(s)");
    }

    for (final room in rooms) {
      final payload = <String, dynamic>{"bookingId": room, "userId": who};
      emit('join-booking', payload);
      if (logEach) {
        CommonLogger.log.i("🔄 Rejoined booking → $payload via $_socketUrl");
      }
    }
  }

  void _restoreEventListeners() {
    final s = _socket;
    if (s == null) return;

    _callbacks.forEach((event, cb) {
      // Only remove our handler reference. Never call `off(event)` without a
      // handler: it can remove core listeners registered by `_bindCoreEvents()`
      // (e.g., onConnect restore flow).
      s.off(event, cb);
      s.on(event, cb);
    });

    CommonLogger.log.i("🔄 Event listeners rebound");
  }
}

// import 'package:hopper/Core/Constants/log.dart';
// import 'package:logger/logger.dart';
// import 'package:socket_io_client/socket_io_client.dart' as IO;
//
// class SocketService {
//   static final SocketService _instance = SocketService._internal();
//   factory SocketService() => _instance;
//   late String _socketUrl; // store the URL for logging
//   late IO.Socket _socket;
//   IO.Socket get socket => _socket;
//
//   bool _initialized = false;
//   bool get connected => _socket.connected;
//
//   String? _userId;
//   String? _driverId;
//   String? _bookingId;
//
//   final List<String> _joinedRooms = [];
//   final Map<String, Function(dynamic)> _callbacks = {};
//
//   SocketService._internal();
//
//   // ---------------------------------------------------------
//   // Initialize socket
//   // ---------------------------------------------------------
//   void initSocket(String url) {
//     _socketUrl = url; // store URL for logs
//     if (_initialized) {
//       if (_socket.disconnected) _socket.connect();
//       return;
//     }
//
//     _initialized = true;
//
//     _socket = IO.io(
//       url,
//       IO.OptionBuilder()
//           .setTransports(['websocket', 'polling'])
//           .enableReconnection()
//           .enableAutoConnect()
//           .setReconnectionAttempts(999999)
//           .setReconnectionDelay(1000)
//           .build(),
//     );
//
//     _socket.connect();
//
//     _socket.onConnect((_) {
//       CommonLogger.log.i("✅ Connected: $_socketUrl \n socket id: ${_socket.id}");
//
//       _restoreRegistration();
//       _restoreJoinedRooms();
//       _restoreEventListeners();
//     });
//
//     _socket.onDisconnect(
//       (_) => CommonLogger.log.e("❌ Disconnected to $_socketUrl"),
//     );
//     _socket.onConnectError(
//       (err) => CommonLogger.log.e("⚠️ Connect error: $err - $_socketUrl"),
//     );
//     _socket.onError((err) => CommonLogger.log.e("⚠️ General error: $err"));
//
//     _socket.onAny(
//       (event, data) => CommonLogger.log.i("Url: $_socketUrl\n📦 [onAny] $event → $data"),
//     );
//   }
//
//   void connect() {
//     if (_initialized && _socket.disconnected) {
//       _socket.connect();
//     }
//   }
//
//   // ---------------------------------------------------------
//   // Register user
//   // ---------------------------------------------------------
//   void registerUser(String userId, {String? bookingId}) {
//     _userId = userId;
//     _updateBookingId(bookingId);
//
//     final payload = <String, dynamic>{
//       "userId": userId,
//       "type": "customer",
//       if (_bookingId != null) "bookingId": _bookingId,
//     };
//
//     emit('register', payload);
//     CommonLogger.log.i("🙋 Driver registered → $payload via $_socketUrl");
//   }
//
//   // ---------------------------------------------------------
//   // Register driver
//   // ---------------------------------------------------------
//   void registerDriver(
//     String driverId, {
//     String? bookingId,
//     Function(dynamic)? ack,
//   }) {
//     _driverId = driverId;
//     if (bookingId != null) _bookingId = bookingId;
//
//     final payload = {
//       "userId": driverId,
//       "type": "driver",
//       if (_bookingId != null) "bookingId": _bookingId,
//     };
//
//     if (ack != null) {
//       _socket.emitWithAck('register', payload, ack: ack);
//       CommonLogger.log.i("🙋 Driver registered with ACK → $payload");
//     } else {
//       emit('register', payload);
//       CommonLogger.log.i("🙋 Driver registered → $payload");
//     }
//   }
//
//   // void registerDriver(String driverId, {String? bookingId ,  }) {
//   //   _driverId = driverId;
//   //   _updateBookingId(bookingId);
//   //
//   //   final payload = <String, dynamic>{
//   //     "driverId": driverId,
//   //     "type": "driver",
//   //     if (_bookingId != null) "bookingId": _bookingId,
//   //   };
//   //
//   //   emit('register', payload);
//   //   CommonLogger.log.i("🙋 Driver register → $payload via $_socketUrl and socket id: ${_socket.id}");
//   //
//   // }
//
//   void joinBooking(String bookingId, {String? userId}) {
//     _updateBookingId(bookingId);
//
//     final payload = <String, dynamic>{
//       "bookingId": bookingId,
//       "userId": userId ?? _userId ?? _driverId,
//     };
//
//     if (!_joinedRooms.contains(bookingId)) _joinedRooms.add(bookingId);
//     emit('join-booking', payload);
//     CommonLogger.log.i("📡 Joined booking → $payload");
//   }
//
//   // ---------------------------------------------------------
//   // Event listeners
//   // ---------------------------------------------------------
//   void on(String event, Function(dynamic data) callback) {
//     _callbacks[event] = callback;
//     _socket.on(event, callback);
//   }
//
//   void onAck(String event, Function(dynamic data, Function? ack) callback) {
//     _callbacks[event] = (data) => callback(data, null);
//
//     _socket.on(event, (dynamic incoming) {
//       if (incoming is List && incoming.length == 2 && incoming[1] is Function) {
//         final payload = incoming[0];
//         final ackFn = incoming[1] as Function;
//         callback(payload, ackFn);
//       } else {
//         callback(incoming, null);
//       }
//     });
//   }
//
//   void emitWithAck(String event, dynamic data, Function(dynamic)? ack) {
//     _socket.emitWithAck(event, data, ack: ack);
//   }
//
//   void emit(String event, dynamic data) {
//     _socket.emit(event, data);
//   }
//
//   void off(String event) {
//     _callbacks.remove(event);
//     _socket.off(event);
//   }
//
//   void onConnect(Function() callback) => _socket.onConnect((_) => callback());
//   void onReconnect(Function() callback) =>
//       _socket.onReconnect((_) => callback());
//
//   // ---------------------------------------------------------
//   // Dispose
//   // ---------------------------------------------------------
//   void dispose() {
//     _socket.dispose();
//     _initialized = false;
//     _userId = null;
//     _driverId = null;
//     _bookingId = null;
//     _joinedRooms.clear();
//     _callbacks.clear();
//   }
//
//   // ---------------------------------------------------------
//   // Internal helpers
//   // ---------------------------------------------------------
//   void _updateBookingId(String? bookingId) {
//     if (bookingId != null) {
//       _bookingId = bookingId;
//       if (!_joinedRooms.contains(bookingId)) _joinedRooms.add(bookingId);
//     }
//   }
//
//   void _restoreRegistration() {
//     if (_driverId != null) {
//       registerDriver(_driverId ?? '', bookingId: _bookingId);
//     } else if (_userId != null) {
//       registerUser(_userId ?? "", bookingId: _bookingId);
//     }
//   }
//
//   void _restoreJoinedRooms() {
//     for (final room in _joinedRooms) {
//       final payload = <String, dynamic>{
//         "bookingId": room,
//         "userId": _userId ?? _driverId,
//       };
//       emit('join-booking', payload);
//       CommonLogger.log.i("🔄 Rejoined booking → $payload via $_socketUrl");
//     }
//   }
//
//   void _restoreEventListeners() {
//     _callbacks.forEach((event, cb) {
//       _socket.off(event);
//       _socket.on(event, cb);
//     });
//     CommonLogger.log.i("🔄 Event listeners rebound");
//   }
// }
//
