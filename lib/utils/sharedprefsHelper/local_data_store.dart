class JoinedBookingData {
  static final JoinedBookingData _instance = JoinedBookingData._internal();

  factory JoinedBookingData() => _instance;

  JoinedBookingData._internal();

  Map<String, dynamic>? bookingData;

  void setData(Map<String, dynamic> data) {
    bookingData = data;
  }

  Map<String, dynamic>? getData() => bookingData;
}
