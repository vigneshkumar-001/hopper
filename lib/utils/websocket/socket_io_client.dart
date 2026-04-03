import 'package:flutter/foundation.dart';
import 'package:hopper/Core/Constants/log.dart';
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

  String? _userId;
  String? _driverId;
  String? _bookingId;

  final List<String> _joinedRooms = [];
  final Map<String, Function(dynamic)> _callbacks = {};
  DateTime _lastManualReconnectAt = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastUpdateLocationLogAt = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastHeartbeatLogAt = DateTime.fromMillisecondsSinceEpoch(0);

  /// Tracks a booking room locally (used for shared rides) without emitting any
  /// socket event or changing the active booking context.
  void rememberBookingRoom(String bookingId) {
    final id = bookingId.trim();
    if (id.isEmpty) return;
    if (!_joinedRooms.contains(id)) _joinedRooms.add(id);
  }

  void clearBookingContext({String? bookingId}) {
    final id = bookingId ?? _bookingId;
    if (id != null && id.trim().isNotEmpty) {
      _joinedRooms.removeWhere((r) => r == id);
    }
    if (bookingId == null || bookingId == _bookingId) {
      _bookingId = null;
    }
  }

  // ---------------------------------------------------------
  // ✅ INIT socket (create once per URL)
  // ---------------------------------------------------------
  void initSocket(String url) {
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
    _socket!.connect();
  }

  // ---------------------------------------------------------
  // ✅ SWITCH URL (Shared <-> Single)
  // ---------------------------------------------------------
  void switchUrl(String newUrl) {
    if (_socketUrl == newUrl && _initialized) {
      if (_socket != null && _socket!.disconnected) _socket!.connect();
      return;
    }

    CommonLogger.log.i("🔁 Switching socket URL: $_socketUrl -> $newUrl");

    // dispose old socket but keep state (ids, rooms, callbacks)
    try {
      _socket?.offAny();
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

      CommonLogger.log.e("❌ Disconnected: $_socketUrl | reason: $reason");

      // If server explicitly disconnected us, socket.io may not auto-reconnect.
      // Attempt a safe manual reconnect (debounced).
      final isServerDisconnect =
          rl.contains('io server disconnect') || rl.contains('server disconnect');
      if (isServerDisconnect) {
        _safeManualReconnect();
        return;
      }

      final shouldNudgeReconnect = rl.contains('ping timeout') ||
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
    if (_initialized && _socket != null && _socket!.disconnected) {
      _socket!.connect();
    }
  }

  void disconnect() {
    try {
      _socket?.disconnect();
    } catch (_) {}
  }

  void _safeManualReconnect() {
    final now = DateTime.now();
    if (now.difference(_lastManualReconnectAt) < const Duration(seconds: 2)) {
      return;
    }
    _lastManualReconnectAt = now;

    final s = _socket;
    if (!_initialized || s == null) return;

    // Avoid spamming connect() while a connect is already in progress.
    try {
      final rs = s.io.readyState.toString().toLowerCase();
      if (rs == 'opening') return;
    } catch (_) {}

    connect();
  }

  // ---------------------------------------------------------
  // ✅ BACKWARD COMPATIBILITY (so your old code won't error)
  // ---------------------------------------------------------
  void onConnect(Function() callback) {
    _socket?.onConnect((_) => callback());
  }

  void onReconnect(Function() callback) {
    _socket?.onReconnect((_) => callback());
  }

  // ---------------------------------------------------------
  // ✅ Register customer
  // ---------------------------------------------------------
  void registerUser(String userId, {String? bookingId}) {
    _userId = userId;
    _driverId = null;
    _updateBookingId(bookingId);

    final payload = <String, dynamic>{
      "userId": userId,
      "type": "customer",
      if (_bookingId != null) "bookingId": _bookingId,
    };

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
      if (_bookingId != null) "bookingId": _bookingId,
    };

    if (_socket == null) return;

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
    if (_initialized && _socket != null && _socket!.disconnected) {
      _socket!.connect();
    }
    final s = _socket;
    if (s == null) return;

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
          s.emit(event, base);
        } else if (rooms.length > 1) {
          for (final room in rooms) {
            final payload = Map<String, dynamic>.from(base);
            payload['bookingId'] = room;
            s.emit(event, payload);
          }
        } else {
          s.emit(event, base);
        }

        _maybeLogEmit(
          event: event,
          payload: base,
          roomsCount: rooms.length,
        );
        return;
      }
    }

    s.emit(event, data);

    if (data is Map) {
      _maybeLogEmit(event: event, payload: Map<String, dynamic>.from(data));
    }
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
      final last = event == 'updateLocation' ? _lastUpdateLocationLogAt : _lastHeartbeatLogAt;
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
  }

  // ---------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------
  void _updateBookingId(String? bookingId) {
    if (bookingId != null) {
      _bookingId = bookingId;
      if (!_joinedRooms.contains(bookingId)) _joinedRooms.add(bookingId);
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
    for (final room in _joinedRooms) {
      final payload = <String, dynamic>{
        "bookingId": room,
        "userId": _userId ?? _driverId,
      };
      emit('join-booking', payload);
      CommonLogger.log.i("🔄 Rejoined booking → $payload via $_socketUrl");
    }
  }

  void _restoreEventListeners() {
    final s = _socket;
    if (s == null) return;

    _callbacks.forEach((event, cb) {
      s.off(event);
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
