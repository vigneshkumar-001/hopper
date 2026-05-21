import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

class CommonLogger {
  static final Logger log = Logger(
    filter: _CommonLogFilter(),
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 8,
      lineLength: 140,
      colors: !kReleaseMode,
      printEmojis: false,
      noBoxingByDefault: true,
    ),
  );
}

class _CommonLogFilter extends LogFilter {
  @override
  bool shouldLog(LogEvent event) {
    if (kReleaseMode) {
      // Release build: log only errors (no info/warn/debug) to avoid leaking
      // URLs/payloads/responses and to keep logs minimal.
      return event.level.index >= Level.error.index;
    }
    return true;
  }
}
