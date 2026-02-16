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

    s.onDisconnect((_) {
      CommonLogger.log.e("❌ Disconnected: $_socketUrl");
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
    });

    s.onError((err) {
      CommonLogger.log.e("⚠️ Socket error: $err");
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
    _callbacks[event] = callback;
    _socket?.off(event);
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

    _socket?.off(event);
    _socket?.on(event, _callbacks[event]!);
  }

  // ---------------------------------------------------------
  // ✅ Emit
  // ---------------------------------------------------------
  void emit(String event, dynamic data) {
    _socket?.emit(event, data);
  }

  // ---------------------------------------------------------
  // ✅ Emit with ack (server replies back)
  // ---------------------------------------------------------
  void emitWithAck(String event, dynamic data, Function(dynamic)? ack) {
    _socket?.emitWithAck(event, data, ack: ack);
  }

  // ---------------------------------------------------------
  // ✅ Off
  // ---------------------------------------------------------
  void off(String event) {
    _callbacks.remove(event);
    _socket?.off(event);
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