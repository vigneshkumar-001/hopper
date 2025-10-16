import 'package:intl/intl.dart';

class DateAndTimeConvert {
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
