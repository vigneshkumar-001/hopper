import 'package:logger/logger.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;

  late IO.Socket _socket;
  bool _initialized = false;

  SocketService._internal();

  void initSocket(String url) {
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
          .setReconnectionAttempts(999999) // ✅ Unlimited attempts
          .setReconnectionDelay(1000)
          .build(),
    );

    _socket.connect();

    _socket.onConnect((_) => print("✅ Connected: ${_socket.id}"));
    _socket.onDisconnect((_) => print("❌ Disconnected"));
    _socket.onConnectError((err) => print("⚠️ Connect error: $err"));
    _socket.onError((err) => print("⚠️ General error: $err"));

    _socket.onAny((event, data) => print("📦 [onAny] $event: $data"));
  }

  void registerDriver(String driverId) {
    emit('register-driver', {
      'driverId': driverId,
      'type': 'driver',
    });
  }

  void joinBooking(String bookingId, String userId) {
    emit('join-booking', {
      'bookingId': bookingId,
      'userId': userId,
    });
  }

  void on(String event, Function(dynamic) callback) {
    _socket.on(event, callback);
  }

  void emit(String event, dynamic data) {
    _socket.emit(event, data);
  }

  void dispose() {
    _socket.dispose();
    _initialized = false;
  }
}
