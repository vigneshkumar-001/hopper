import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

enum LogType {
  api,
  socket,
  rider,
  location,
  error,
  warning,
  info,
}

class LogEntry {
  final DateTime timestamp;
  final LogType type;
  final String event;
  final dynamic data;
  final String? bookingId;
  final String? error;

  LogEntry({
    required this.timestamp,
    required this.type,
    required this.event,
    this.data,
    this.bookingId,
    this.error,
  });

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'type': type.toString().split('.').last,
    'event': event,
    'data': data?.toString() ?? 'null',
    'bookingId': bookingId,
    'error': error,
  };

  @override
  String toString() =>
      '[${DateFormat('HH:mm:ss.SSS').format(timestamp)}] ${type.toString().split('.').last.toUpperCase()}: $event${bookingId != null ? ' (Booking: $bookingId)' : ''}';
}

class LogManager {
  static final LogManager _instance = LogManager._internal();

  factory LogManager() => _instance;

  LogManager._internal();

  final List<LogEntry> _logs = [];
  final int maxLogs = 5000; // Keep last 5000 logs in memory
  File? _logFile;

  // ─── LOGGING ───────────────────────────────────────────────────────────────

  void log({
    required LogType type,
    required String event,
    dynamic data,
    String? bookingId,
    String? error,
  }) {
    final entry = LogEntry(
      timestamp: DateTime.now(),
      type: type,
      event: event,
      data: data,
      bookingId: bookingId,
      error: error,
    );

    _logs.add(entry);

    // Keep memory footprint bounded
    if (_logs.length > maxLogs) {
      _logs.removeRange(0, _logs.length - maxLogs);
    }

    // Write to file asynchronously
    _writeToFile(entry);

    // Console logging for debugging
    print(entry);
  }

  // ─── CONVENIENCE METHODS ───────────────────────────────────────────────────

  void logApi({
    required String method,
    required String endpoint,
    dynamic request,
    dynamic response,
    int? statusCode,
    String? error,
    String? bookingId,
  }) {
    log(
      type: LogType.api,
      event: '$method $endpoint',
      data: {
        'method': method,
        'endpoint': endpoint,
        'request': request,
        'response': response,
        'statusCode': statusCode,
      },
      bookingId: bookingId,
      error: error,
    );
  }

  void logSocket({
    required String event,
    dynamic data,
    String? bookingId,
    String? error,
  }) {
    log(
      type: LogType.socket,
      event: event,
      data: data,
      bookingId: bookingId,
      error: error,
    );
  }

  void logRider({
    required String action,
    required String bookingId,
    dynamic riderData,
    String? error,
  }) {
    log(
      type: LogType.rider,
      event: action,
      data: riderData,
      bookingId: bookingId,
      error: error,
    );
  }

  void logLocation({
    required double latitude,
    required double longitude,
    String? source,
    String? bookingId,
  }) {
    log(
      type: LogType.location,
      event: 'Location updated${source != null ? ' (source: $source)' : ''}',
      data: {'latitude': latitude, 'longitude': longitude},
      bookingId: bookingId,
    );
  }

  void logError(String message, {String? bookingId, dynamic stackTrace}) {
    log(
      type: LogType.error,
      event: message,
      bookingId: bookingId,
      error: stackTrace?.toString(),
    );
  }

  // ─── FILE OPERATIONS ───────────────────────────────────────────────────────

  Future<void> _writeToFile(LogEntry entry) async {
    try {
      _logFile ??= await _getLogFile();
      await _logFile!.writeAsString(
        '${entry.toJson()}\n',
        mode: FileMode.append,
      );
    } catch (e) {
      print('Error writing log: $e');
    }
  }

  Future<File> _getLogFile() async {
    final dir = await getApplicationDocumentsDirectory();
    final logDir = Directory('${dir.path}/hopper_logs');
    if (!await logDir.exists()) {
      await logDir.create(recursive: true);
    }
    final fileName =
        'hopper_${DateFormat('yyyy-MM-dd').format(DateTime.now())}.log';
    return File('${logDir.path}/$fileName');
  }

  // ─── RETRIEVAL ───────────────────────────────────────────────────────────

  List<LogEntry> getAllLogs() => List.from(_logs);

  List<LogEntry> getLogsByType(LogType type) =>
      _logs.where((e) => e.type == type).toList();

  List<LogEntry> getLogsByBooking(String bookingId) =>
      _logs.where((e) => e.bookingId == bookingId).toList();

  List<LogEntry> getRecentLogs({int count = 100}) =>
      _logs.length > count ? _logs.sublist(_logs.length - count) : _logs;

  List<LogEntry> getErrorLogs() =>
      _logs.where((e) => e.type == LogType.error || e.error != null).toList();

  // ─── EXPORT ─────────────────────────────────────────────────────────────

  Future<String> exportAsJson() async {
    final json = _logs.map((e) => e.toJson()).toList();
    return jsonStringify(json);
  }

  Future<String> exportAsCsv() async {
    final buffer = StringBuffer();
    buffer.writeln(
        'Timestamp,Type,Event,BookingId,Data,Error');

    for (final log in _logs) {
      buffer.writeln(
        '"${log.timestamp.toIso8601String()}","${log.type.toString().split('.').last}","${log.event}","${log.bookingId}","${log.data}","${log.error}"',
      );
    }
    return buffer.toString();
  }

  Future<String> exportAsText() async {
    final buffer = StringBuffer();
    for (final log in _logs) {
      buffer.writeln(log.toString());
      if (log.data != null) buffer.writeln('  Data: ${log.data}');
      if (log.error != null) buffer.writeln('  Error: ${log.error}');
      buffer.writeln('');
    }
    return buffer.toString();
  }

  /// Export logs to a file (saved to Documents)
  /// Returns the file path
  Future<String> exportLogsToFile(String format) async {
    try {
      String content;
      String fileName;

      switch (format.toLowerCase()) {
        case 'json':
          content = await exportAsJson();
          fileName = 'hopper_logs_${_timestamp()}.json';
          break;
        case 'csv':
          content = await exportAsCsv();
          fileName = 'hopper_logs_${_timestamp()}.csv';
          break;
        default:
          content = await exportAsText();
          fileName = 'hopper_logs_${_timestamp()}.txt';
      }

      final dir = await getApplicationDocumentsDirectory();
      final logsDir = Directory('${dir.path}/hopper_logs');
      if (!await logsDir.exists()) {
        await logsDir.create(recursive: true);
      }

      final file = File('${logsDir.path}/$fileName');
      await file.writeAsString(content);

      print('✅ Logs exported to: ${file.path}');
      return file.path;
    } catch (e) {
      print('❌ Error exporting logs: $e');
      return '';
    }
  }

  // ─── CLEANUP ─────────────────────────────────────────────────────────────

  void clearMemoryLogs() => _logs.clear();

  Future<void> clearOldLogFiles({int daysToKeep = 7}) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final logDir = Directory('${dir.path}/hopper_logs');

      if (!await logDir.exists()) return;

      final now = DateTime.now();
      final cutoffDate = now.subtract(Duration(days: daysToKeep));

      await for (final file in logDir.list()) {
        if (file is File) {
          final stat = await file.stat();
          if (stat.modified.isBefore(cutoffDate)) {
            await file.delete();
          }
        }
      }
    } catch (e) {
      print('Error clearing old logs: $e');
    }
  }

  // ─── STATISTICS ─────────────────────────────────────────────────────────

  Map<String, int> getLogStats() {
    final stats = <String, int>{};
    for (final log in _logs) {
      final typeStr = log.type.toString().split('.').last;
      stats[typeStr] = (stats[typeStr] ?? 0) + 1;
    }
    return stats;
  }

  int getErrorCount() => _logs.where((e) => e.type == LogType.error).length;

  int getApiCallCount() => _logs.where((e) => e.type == LogType.api).length;

  int getSocketEventCount() => _logs.where((e) => e.type == LogType.socket).length;

  // ─── HELPERS ─────────────────────────────────────────────────────────────

  String _timestamp() => DateFormat('yyyy-MM-dd_HH-mm-ss').format(DateTime.now());

  String jsonStringify(dynamic json) {
    // Simple JSON stringification
    return json.toString();
  }
}

final logManager = LogManager();
