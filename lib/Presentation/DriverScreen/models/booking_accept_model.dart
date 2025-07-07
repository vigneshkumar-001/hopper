class  BookingAcceptModel  {
  final int status;
  final String message;
  final BookingAcceptedData data;

  BookingAcceptModel({
    required this.status,
    required this.message,
    required this.data,
  });

  factory BookingAcceptModel.fromJson(Map<String, dynamic> json) {
    return BookingAcceptModel(
      status: json['status'],
      message: json['message'],
      data: BookingAcceptedData.fromJson(json['data']),
    );
  }
}

class BookingAcceptedData {
  final String bookingId;
  final String driverId;
  final String status;

  BookingAcceptedData({
    required this.bookingId,
    required this.driverId,
    required this.status,
  });

  factory BookingAcceptedData.fromJson(Map<String, dynamic> json) {
    return BookingAcceptedData(
      bookingId: json['bookingId'],
      driverId: json['driverId'],
      status: json['status'],
    );
  }
}
