import 'package:get/get.dart';
import 'package:hopper/Core/Services/log_manager.dart';

/// Monitors socket connection health and logs disconnections
class SocketMonitor {
  static final SocketMonitor _instance = SocketMonitor._internal();

  factory SocketMonitor() => _instance;

  SocketMonitor._internal();

  final RxBool isConnected = false.obs;
  final RxInt disconnectionCount = 0.obs;
  final RxString lastDisconnectionReason = ''.obs;
  final RxInt riderCountAtDisconnection = 0.obs;

  // ─── Connection Tracking ───────────────────────────────────────────────────

  void onConnect() {
    isConnected.value = true;

    logManager.logSocket(
      event: 'SOCKET_CONNECTED',
      data: {
        'timestamp': DateTime.now().toIso8601String(),
        'previousDisconnections': disconnectionCount.value,
      },
    );
  }

  void onDisconnect(String reason, {int riderCount = 0}) {
    isConnected.value = false;
    disconnectionCount.value++;
    lastDisconnectionReason.value = reason;
    riderCountAtDisconnection.value = riderCount;

    logManager.logSocket(
      event: 'SOCKET_DISCONNECTED',
      data: {
        'reason': reason,
        'disconnectionNumber': disconnectionCount.value,
        'riderCountLost': riderCount,
        'timestamp': DateTime.now().toIso8601String(),
      },
      error: reason,
    );

    print(
        '❌ Socket disconnected #${disconnectionCount.value}: $reason (Lost $riderCount riders)');
  }

  void onError(String error, {String? code}) {
    logManager.logSocket(
      event: 'SOCKET_ERROR',
      data: {
        'error': error,
        'code': code,
        'isConnected': isConnected.value,
      },
      error: error,
    );

    print('⚠️ Socket error: $error${code != null ? ' ($code)' : ''}');
  }

  void onReconnect() {
    logManager.logSocket(
      event: 'SOCKET_RECONNECTING',
      data: {
        'previousDisconnections': disconnectionCount.value,
        'lastReason': lastDisconnectionReason.value,
      },
    );

    print('🔄 Socket attempting to reconnect...');
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────

  Map<String, dynamic> getStatus() => {
        'isConnected': isConnected.value,
        'disconnectionCount': disconnectionCount.value,
        'lastDisconnectionReason': lastDisconnectionReason.value,
        'riderCountAtLastDisconnection': riderCountAtDisconnection.value,
      };

  void reset() {
    disconnectionCount.value = 0;
    lastDisconnectionReason.value = '';
    riderCountAtDisconnection.value = 0;
  }
}

final socketMonitor = SocketMonitor();
