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
      return event.level.index >= Level.warning.index;
    }
    return true;
  }
}
