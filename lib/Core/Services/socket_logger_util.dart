import 'package:socket_io_client/socket_io_client.dart' as io;
import 'logger_service.dart';

class SocketLoggerUtil {
  static final LoggerService _loggerService = LoggerService();

  static void setupSocketLogging(io.Socket socket) {
    socket.onConnect((_) {
      _loggerService.logSocketEvent(
        eventName: 'SOCKET_CONNECTED',
        data: 'Socket connected successfully',
      );
    });

    socket.onConnectError((data) {
      _loggerService.logSocketEvent(
        eventName: 'SOCKET_CONNECT_ERROR',
        data: data,
      );
    });

    socket.onDisconnect((_) {
      _loggerService.logSocketEvent(
        eventName: 'SOCKET_DISCONNECTED',
        data: 'Socket disconnected',
      );
    });

    socket.onError((data) {
      _loggerService.logSocketEvent(
        eventName: 'SOCKET_ERROR',
        data: data,
      );
    });

    socket.onAny((event, data) {
      _loggerService.logSocketEvent(
        eventName: event,
        data: data,
      );
    });
  }

  static Future<void> emitWithLogging(
    io.Socket socket,
    String event,
    dynamic data,
  ) async {
    _loggerService.logSocketEvent(
      eventName: '🔌 EMIT: $event',
      data: data,
    );
    socket.emit(event, data);
  }
}
