import 'package:hopper/Core/Constants/log.dart';
import 'package:logger/logger.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  late String _socketUrl; // store the URL for logging
  late IO.Socket _socket;
  IO.Socket get socket => _socket;

  bool _initialized = false;
  bool get connected => _socket.connected;

  String? _userId;
  String? _driverId;
  String? _bookingId;

  final List<String> _joinedRooms = [];
  final Map<String, Function(dynamic)> _callbacks = {};

  SocketService._internal();

  // ---------------------------------------------------------
  // Initialize socket
  // ---------------------------------------------------------
  void initSocket(String url) {
    _socketUrl = url; // store URL for logs
    if (_initialized) {
      if (_socket.disconnected) _socket.connect();
      return;
    }

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

    _socket.connect();

    _socket.onConnect((_) {
      CommonLogger.log.i("✅ Connected: $_socketUrl / socket id: ${_socket.id}");

      _restoreRegistration();
      _restoreJoinedRooms();
      _restoreEventListeners();
    });

    _socket.onDisconnect(
      (_) => CommonLogger.log.e("❌ Disconnected to $_socketUrl"),
    );
    _socket.onConnectError(
      (err) => CommonLogger.log.e("⚠️ Connect error: $err - $_socketUrl"),
    );
    _socket.onError((err) => CommonLogger.log.e("⚠️ General error: $err"));

    _socket.onAny(
      (event, data) => CommonLogger.log.i("📦 [onAny] $event → $data"),
    );
  }

  void connect() {
    if (_initialized && _socket.disconnected) {
      _socket.connect();
    }
  }

  // ---------------------------------------------------------
  // Register user
  // ---------------------------------------------------------
  void registerUser(String userId, {String? bookingId}) {
    _userId = userId;
    _updateBookingId(bookingId);

    final payload = <String, dynamic>{
      "userId": userId,
      "type": "customer",
      if (_bookingId != null) "bookingId": _bookingId,
    };

    emit('register', payload);
    CommonLogger.log.i("🙋 Driver registered → $payload via $_socketUrl");
  }

  // ---------------------------------------------------------
  // Register driver
  // ---------------------------------------------------------
  void registerDriver(
    String driverId, {
    String? bookingId,
    Function(dynamic)? ack,
  }) {
    _driverId = driverId;
    if (bookingId != null) _bookingId = bookingId;

    final payload = {
      "userId": driverId,
      "type": "driver",
      if (_bookingId != null) "bookingId": _bookingId,
    };

    if (ack != null) {
      _socket.emitWithAck('register', payload, ack: ack);
      CommonLogger.log.i("🙋 Driver registered with ACK → $payload");
    } else {
      emit('register', payload);
      CommonLogger.log.i("🙋 Driver registered → $payload");
    }
  }

  // void registerDriver(String driverId, {String? bookingId ,  }) {
  //   _driverId = driverId;
  //   _updateBookingId(bookingId);
  //
  //   final payload = <String, dynamic>{
  //     "driverId": driverId,
  //     "type": "driver",
  //     if (_bookingId != null) "bookingId": _bookingId,
  //   };
  //
  //   emit('register', payload);
  //   CommonLogger.log.i("🙋 Driver register → $payload via $_socketUrl and socket id: ${_socket.id}");
  //
  // }

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
  // Event listeners
  // ---------------------------------------------------------
  void on(String event, Function(dynamic data) callback) {
    _callbacks[event] = callback;
    _socket.on(event, callback);
  }

  void onAck(String event, Function(dynamic data, Function? ack) callback) {
    _callbacks[event] = (data) => callback(data, null);

    _socket.on(event, (dynamic incoming) {
      if (incoming is List && incoming.length == 2 && incoming[1] is Function) {
        final payload = incoming[0];
        final ackFn = incoming[1] as Function;
        callback(payload, ackFn);
      } else {
        callback(incoming, null);
      }
    });
  }

  void emitWithAck(String event, dynamic data, Function(dynamic)? ack) {
    _socket.emitWithAck(event, data, ack: ack);
  }

  void emit(String event, dynamic data) {
    _socket.emit(event, data);
  }

  void off(String event) {
    _callbacks.remove(event);
    _socket.off(event);
  }

  void onConnect(Function() callback) => _socket.onConnect((_) => callback());
  void onReconnect(Function() callback) =>
      _socket.onReconnect((_) => callback());

  // ---------------------------------------------------------
  // Dispose
  // ---------------------------------------------------------
  void dispose() {
    _socket.dispose();
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
    if (_driverId != null) {
      registerDriver(_driverId ?? '', bookingId: _bookingId);
    } else if (_userId != null) {
      registerUser(_userId ?? "", bookingId: _bookingId);
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
    _callbacks.forEach((event, cb) {
      _socket.off(event);
      _socket.on(event, cb);
    });
    CommonLogger.log.i("🔄 Event listeners rebound");
  }
}

//
// import 'package:hopper/Core/Constants/log.dart';
// import 'package:logger/logger.dart';
// import 'package:socket_io_client/socket_io_client.dart' as IO;
//
// class SocketService {
//   static final SocketService _instance = SocketService._internal();
//   factory SocketService() => _instance;
//
//   late IO.Socket _socket;
//   IO.Socket get socket => _socket;
//   bool _initialized = false;
//   bool get connected => _socket.connected;
//
//   SocketService._internal();
//
//   void initSocket(String url) {
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
//     _socket.onConnect((_) => print("✅ Connected: ${_socket.id}"));
//     _socket.onDisconnect((_) => print("❌ Disconnected"));
//     _socket.onConnectError((err) => print("⚠️ Connect error: $err"));
//     _socket.onError((err) => print("⚠️ General error: $err"));
//
//     _socket.onAny((event, data) => print("📦 [onAny] $event: $data"));
//   }
//
//   void connect() {
//     if (_initialized && _socket.disconnected) {
//       _socket.connect();
//     }
//   }
//
//   void onConnect(Function() callback) {
//     _socket.onConnect((_) {
//       CommonLogger.log.i("📡 onConnect triggered");
//       callback();
//     });
//   }
//   void registerUser(String userId) {
//     emit('register', {'userId': userId, 'type': 'customer'});
//   }
//
//
//   void onReconnect(Function() callback) {
//     _socket.onReconnect((_) {
//       callback();
//     });
//   }
//
//   void registerDriver(String driverId) {
//     emit('register-driver', {'driverId': driverId, 'type': 'driver'});
//   }
//
//   void joinBooking(String bookingId, String userId) {
//     emit('join-booking', {'bookingId': bookingId, 'userId': userId});
//   }
//
//   void on(String event, Function(dynamic) callback) {
//     _socket.on(event, callback);
//   }
//   void emitWithAck(String event, dynamic data, Function(dynamic)? ack) {
//     _socket.emitWithAck(event, data, ack: ack);
//   }
//
//
//   void emit(String event, dynamic data) {
//     _socket.emit(event, data);
//   }
//
//   void dispose() {
//     _socket.dispose();
//     _initialized = false;
//   }
// }
