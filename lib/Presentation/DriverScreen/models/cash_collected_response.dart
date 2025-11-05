class  CashCollectedResponse  {
  final int status;
  final String message;
  final String bookingStatus;
  final String paidAmount;
  final String paymentId;

  CashCollectedResponse({
    required this.status,
    required this.message,
    required this.bookingStatus,
    required this.paidAmount,
    required this.paymentId,
  });

  factory CashCollectedResponse.fromJson(Map<String, dynamic> json) {
    return CashCollectedResponse(
      status: json['status'] ?? 0,
      message: json['message'] ?? '',
      bookingStatus: json['bookingStatus'] ?? '',
      paidAmount: json['paidAmount'] ?? '',
      paymentId: json['paymentId'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'status': status,
      'message': message,
      'bookingStatus': bookingStatus,
      'paidAmount': paidAmount,
      'paymentId': paymentId,
    };
  }
}
