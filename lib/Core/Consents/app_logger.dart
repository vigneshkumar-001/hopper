import 'package:logger/logger.dart';
import 'package:flutter/foundation.dart';

class AppLogger {
  static final Logger log = Logger(
    filter: kDebugMode ? DevelopmentFilter() : ProductionFilter(),
    printer: _BluePrinter(
      PrettyPrinter(
        methodCount: 0,
        errorMethodCount: 5,
        lineLength: 120,
        colors: true,
        printEmojis: false,

      ),
    ),
  );
}

class _BluePrinter extends LogPrinter {
  _BluePrinter(this._inner);

  final LogPrinter _inner;

  static const String _blue = '\x1B[34m';
  static const String _reset = '\x1B[0m';

  @override
  List<String> log(LogEvent event) {
    final lines = _inner.log(event);
    if (!kDebugMode) return lines;
    return lines.map((l) => '$_blue$l$_reset').toList(growable: false);
  }
}
