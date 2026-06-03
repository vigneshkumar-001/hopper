class BookingAcceptModel {
  final int status;
  final String message;
  final BookingAcceptedData? data;

  BookingAcceptModel({required this.status, required this.message, this.data});

  factory BookingAcceptModel.fromJson(Map<String, dynamic> json) {
    return BookingAcceptModel(
      status: json['status'] ?? 0,
      message: json['message'] ?? '',
      data:
          json['data'] != null
              ? BookingAcceptedData.fromJson(json['data'])
              : null,
      // data: BookingAcceptedData.fromJson(json['data']),
    );
  }
}

class BookingAcceptedData {
  final String bookingId;
  final String driverId;
  final String status;
  final String nextDriverId;

  BookingAcceptedData({
    required this.bookingId,
    required this.driverId,
    required this.status,
    required this.nextDriverId,
  });

  factory BookingAcceptedData.fromJson(Map<String, dynamic> json) {
    return BookingAcceptedData(
      bookingId: (json['bookingId'] ?? '').toString(),
      driverId: (json['driverId'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      nextDriverId: (json['nextDriverId'] ?? '').toString(),
    );
  }
}
