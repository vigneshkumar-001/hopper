import 'package:intl/intl.dart';

class DateAndTimeConvert {
  static DateTime? tryParseFlexible(String value) {
    final raw = value.trim();
    if (raw.isEmpty) return null;

    final direct = DateTime.tryParse(raw);
    if (direct != null) return direct;

    // Some backend values come as: "2026-03-29 23:59:59 PM"
    // 24-hour clock + AM/PM is invalid for strict parsers. If hour >= 13 and
    // AM/PM is present, strip AM/PM and parse as 24-hour time.
    final hasMeridiem = RegExp(r'\b(AM|PM)\b', caseSensitive: false).hasMatch(raw);
    String normalized = raw;
    if (hasMeridiem) {
      final match = RegExp(r'\b(\d{1,2}):(\d{2}):(\d{2})\b').firstMatch(raw);
      final hour = int.tryParse(match?.group(1) ?? '');
      if (hour != null && hour >= 13) {
        normalized = raw.replaceAll(
          RegExp(r'\s*\b(AM|PM)\b', caseSensitive: false),
          '',
        );
      }
    }

    final patterns = <String>[
      'yyyy-MM-dd HH:mm:ss',
      'yyyy-MM-dd H:mm:ss',
      'yyyy-MM-dd hh:mm:ss a',
      'yyyy-MM-dd h:mm:ss a',
      'yyyy-MM-dd',
    ];

    for (final pattern in patterns) {
      try {
        return DateFormat(pattern).parseLoose(normalized);
      } catch (_) {}
    }

    return null;
  }

  static String formatDateTime(
    String dateTimeString, {
    bool showDate = true,
    bool showTime = true,
  }) {
    DateTime dateTime = DateTime.parse(dateTimeString).toLocal();

    String datePart = showDate ? DateFormat('dd-MM-yyyy').format(dateTime) : '';
    String timePart = showTime ? DateFormat('hh:mm a').format(dateTime) : '';

    if (showDate && showTime) {
      return "$datePart $timePart"; // Both
    } else if (showDate) {
      return datePart; // Only Date
    } else if (showTime) {
      return timePart; // Only Time
    }
    return '';
  }

  /// ✅ "08:59 AM  18-Jul-2025"
  static String timeWithShortDate(String dateTimeStr) {
    if (dateTimeStr.isEmpty) return '';

    final dateTime = DateTime.tryParse(dateTimeStr);
    if (dateTime == null) return '';

    final time = DateFormat('hh:mm a').format(dateTime);
    final date = DateFormat('dd.MMM.yyyy').format(dateTime);

    return "$time  $date";
  }

  /// ✅ "12 Jul 25"
  static String shortDate(String dateTimeStr) {
    if (dateTimeStr.isEmpty) return '';

    final dateTime = DateTime.tryParse(dateTimeStr);
    if (dateTime == null) return '';

    return DateFormat('dd MMM yy').format(dateTime);
  }

  /// ✅ "May 15, 2025"
  static String longMonthDate(String dateTimeStr) {
    if (dateTimeStr.isEmpty) return '';

    final dateTime = DateTime.tryParse(dateTimeStr);
    if (dateTime == null) return '';

    return DateFormat('MMM dd, yyyy').format(dateTime);
  }
}
