class BookingDataService {
  static final BookingDataService _instance = BookingDataService._internal();
  factory BookingDataService() => _instance;
  BookingDataService._internal();

  Map<String, dynamic>? bookingRequestData;

  Map<String, dynamic>? _coerceToMap(dynamic data) {
    if (data == null) return null;
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    if (data is List && data.isNotEmpty) {
      return _coerceToMap(data.first);
    }
    return null;
  }

  void setBookingData(dynamic data) {
    bookingRequestData = _coerceToMap(data);
  }

  Map<String, dynamic>? getBookingData() {
    return bookingRequestData;
  }

  void clear() {
    bookingRequestData = null;
  }
}
