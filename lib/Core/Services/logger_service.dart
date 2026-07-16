import 'dart:io';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:device_info_plus/device_info_plus.dart';

class LoggerService {
  static const String _redacted = '[REDACTED]';
  static const Set<String> _sensitiveLogKeys = {
    'authorization',
    'password',
    'token',
    'accesstoken',
    'refreshtoken',
    'fcmtoken',
    'deviceid',
    'secret',
  };

  static final Logger logger = Logger(
    printer: PrettyPrinter(
      methodCount: 2,
      errorMethodCount: 8,
      lineLength: 120,
      colors: true,
      printEmojis: true,
    ),
  );

  static final LoggerService _instance = LoggerService._internal();

  factory LoggerService() {
    return _instance;
  }

  LoggerService._internal();

  dynamic _sanitizeForLog(dynamic value, {String? key}) {
    final normalizedKey =
        key?.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    if (normalizedKey != null &&
        (_sensitiveLogKeys.contains(normalizedKey) ||
            normalizedKey.endsWith('token') ||
            normalizedKey.endsWith('password') ||
            normalizedKey.endsWith('secret'))) {
      return _redacted;
    }
    if (value is Map) {
      return value.map(
        (entryKey, entryValue) => MapEntry(
          entryKey,
          _sanitizeForLog(entryValue, key: entryKey.toString()),
        ),
      );
    }
    if (value is Iterable) {
      return value.map((entry) => _sanitizeForLog(entry)).toList();
    }
    if (value is String &&
        value.trimLeft().toLowerCase().startsWith('bearer ')) {
      return 'Bearer $_redacted';
    }
    return value;
  }

  Future<String> get _logFilePath async {
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/hopper_dev_logs.txt';
  }

  Future<void> log(String message, {String level = 'INFO'}) async {
    final timestamp = DateFormat('yyyy-MM-dd HH:mm:ss.SSS').format(DateTime.now());
    final logMessage = '[$timestamp] [$level] $message';

    logger.i(message);
    await _writeToFile(logMessage);
  }

  Future<void> logError(String message, dynamic error, StackTrace? stackTrace) async {
    final timestamp = DateFormat('yyyy-MM-dd HH:mm:ss.SSS').format(DateTime.now());
    final logMessage = '''[$timestamp] [ERROR] $message
Error: $error
Stack: ${stackTrace ?? 'N/A'}''';

    logger.e(message, error: error, stackTrace: stackTrace);
    await _writeToFile(logMessage);
  }

  Future<void> logApiRequest({
    required String url,
    required String method,
    required Map<String, dynamic> headers,
    dynamic body,
  }) async {
    final timestamp = DateFormat('yyyy-MM-dd HH:mm:ss.SSS').format(DateTime.now());
    final safeHeaders = _sanitizeForLog(headers);
    final safeBody = _sanitizeForLog(body);
    final logMessage = '''
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
[$timestamp] 📤 API REQUEST
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
URL: $url
METHOD: $method
HEADERS: $safeHeaders
BODY: $safeBody
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
''';

    logger.i('API REQUEST - $method $url');
    await _writeToFile(logMessage);
  }

  Future<void> logApiResponse({
    required String url,
    required int statusCode,
    dynamic body,
    int? durationMs,
  }) async {
    final timestamp = DateFormat('yyyy-MM-dd HH:mm:ss.SSS').format(DateTime.now());
    final safeBody = _sanitizeForLog(body);
    final logMessage = '''
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
[$timestamp] 📥 API RESPONSE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
URL: $url
STATUS: $statusCode
DURATION: ${durationMs}ms
BODY: $safeBody
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
''';

    logger.i('API RESPONSE - $statusCode from $url (${durationMs}ms)');
    await _writeToFile(logMessage);
  }

  Future<void> logApiError({
    required String url,
    required String error,
    dynamic errorBody,
  }) async {
    final timestamp = DateFormat('yyyy-MM-dd HH:mm:ss.SSS').format(DateTime.now());
    final safeErrorBody = _sanitizeForLog(errorBody);
    final logMessage = '''
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
[$timestamp] ❌ API ERROR
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
URL: $url
ERROR: $error
ERROR BODY: $safeErrorBody
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
''';

    logger.e('API ERROR - $error from $url');
    await _writeToFile(logMessage);
  }

  Future<void> logSocketEvent({
    required String eventName,
    dynamic data,
  }) async {
    final timestamp = DateFormat('yyyy-MM-dd HH:mm:ss.SSS').format(DateTime.now());
    final safeData = _sanitizeForLog(data);
    final logMessage = '''[$timestamp] 🔌 SOCKET EVENT: $eventName
DATA: $safeData''';

    logger.i('SOCKET EVENT - $eventName');
    await _writeToFile(logMessage);
  }

  Future<void> logNavigation(String screenName) async {
    final timestamp = DateFormat('yyyy-MM-dd HH:mm:ss.SSS').format(DateTime.now());
    final logMessage = '[$timestamp] 📱 NAVIGATION: $screenName';

    logger.i('Navigated to: $screenName');
    await _writeToFile(logMessage);
  }

  Future<void> logDeviceInfo() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;

      final timestamp = DateFormat('yyyy-MM-dd HH:mm:ss.SSS').format(DateTime.now());
      final logMessage = '''
[$timestamp] 📱 DEVICE INFO
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
MODEL: ${androidInfo.model}
MANUFACTURER: ${androidInfo.manufacturer}
ANDROID VERSION: ${androidInfo.version.release}
SDK INT: ${androidInfo.version.sdkInt}
DEVICE: ${androidInfo.device}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
''';

      await _writeToFile(logMessage);
    } catch (e) {
      logger.e('Failed to get device info: $e');
    }
  }

  Future<void> logAppCrash(String error, StackTrace stackTrace) async {
    final timestamp = DateFormat('yyyy-MM-dd HH:mm:ss.SSS').format(DateTime.now());
    final logMessage = '''
╔═════════════════════════════════════════════════╗
║ [$timestamp] 💥 APP CRASH                       ║
╚═════════════════════════════════════════════════╝
ERROR: $error
STACK TRACE:
$stackTrace
════════════════════════════════════════════════════════
''';

    logger.e('APP CRASH: $error', error: error, stackTrace: stackTrace);
    await _writeToFile(logMessage);
  }

  Future<void> _writeToFile(String message) async {
    try {
      final filePath = await _logFilePath;
      final file = File(filePath);

      await file.writeAsString(
        '$message\n',
        mode: FileMode.append,
      );
    } catch (e) {
      logger.e('Failed to write to log file: $e');
    }
  }

  Future<File> exportLogs() async {
    final filePath = await _logFilePath;
    final file = File(filePath);

    if (!await file.exists()) {
      await file.create(recursive: true);
      await file.writeAsString('No logs yet.');
    }

    return file;
  }

  Future<String> getLogsContent() async {
    try {
      final file = await exportLogs();
      return await file.readAsString();
    } catch (e) {
      return 'Error reading logs: $e';
    }
  }

  Future<void> clearLogs() async {
    try {
      final filePath = await _logFilePath;
      final file = File(filePath);

      if (await file.exists()) {
        await file.delete();
      }

      final timestamp = DateFormat('yyyy-MM-dd HH:mm:ss.SSS').format(DateTime.now());
      await _writeToFile('[$timestamp] 🗑️ LOGS CLEARED');

      logger.i('Logs cleared');
    } catch (e) {
      logger.e('Failed to clear logs: $e');
    }
  }

  Future<String> getLogSize() async {
    try {
      final file = await exportLogs();
      if (await file.exists()) {
        final size = await file.length();
        return _formatFileSize(size);
      }
      return '0 B';
    } catch (e) {
      return 'N/A';
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB'];
    var i = (bytes.toString().length / 3).floor();
    return '${(bytes / pow(1024, i).toInt()).toStringAsFixed(2)} ${suffixes[i]}';
  }
}

num pow(num x, num exponent) {
  return x * (exponent - 1) > 0 ? x * pow(x, exponent - 1) : 1;
}
