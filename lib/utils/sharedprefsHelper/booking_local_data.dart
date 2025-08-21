class BookingDataService {
  static final BookingDataService _instance = BookingDataService._internal();
  factory BookingDataService() => _instance;
  BookingDataService._internal();

  Map<String, dynamic>? bookingRequestData;

  void setBookingData(Map<String, dynamic> data) {
    bookingRequestData = data;
  }

  Map<String, dynamic>? getBookingData() {
    return bookingRequestData;
  }
}
