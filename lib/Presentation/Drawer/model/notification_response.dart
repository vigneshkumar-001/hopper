class NotificationResponse {
  bool success;
  int count;
  List<NotificationData> data;

  NotificationResponse({
    required this.success,
    required this.count,
    required this.data,
  });

  factory NotificationResponse.fromJson(Map<String, dynamic> json) {
    return NotificationResponse(
      success: json['success'] ?? false,
      count: json['count'] ?? 0,
      data: (json['data'] as List<dynamic>?)
          ?.map((e) => NotificationData.fromJson(e))
          .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'count': count,
      'data': data.map((e) => e.toJson()).toList(),
    };
  }
}

class NotificationData {
  String id;
  String userType;
  String? customerId;
  String? driverId;
  String bookingId;
  String type;
  String title;
  String message;
  NotificationDataDetail dataDetail;
  String status;
  String createdAt;
  String updatedAt;
  int v;
  String imageType;
  String bookingType;
  bool sharedBooking;

  NotificationData({
    required this.id,
    required this.userType,
    this.customerId,
    this.driverId,
    required this.bookingId,
    required this.type,
    required this.title,
    required this.message,
    required this.dataDetail,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.v,
    required this.imageType,
    required this.bookingType,
    required this.sharedBooking,
  });

  factory NotificationData.fromJson(Map<String, dynamic> json) {
    return NotificationData(
      id: json['_id'] ?? '',
      userType: json['userType'] ?? '',
      customerId: json['customerId'],
      driverId: json['driverId'],
      bookingId: json['bookingId'] ?? '',
      type: json['type'] ?? '',
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      dataDetail: NotificationDataDetail.fromJson(json['data'] ?? {}),
      status: json['status'] ?? '',
      createdAt: json['createdAt'] ?? '',
      updatedAt: json['updatedAt'] ?? '',
      v: json['__v'] ?? 0,
      imageType: json['imageType'] ?? '',
      bookingType: json['bookingType'] ?? '',
      sharedBooking: json['sharedBooking'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'userType': userType,
      'customerId': customerId,
      'driverId': driverId,
      'bookingId': bookingId,
      'type': type,
      'title': title,
      'message': message,
      'data': dataDetail.toJson(),
      'status': status,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      '__v': v,
      'imageType': imageType,
      'bookingType': bookingType,
      'sharedBooking': sharedBooking,
    };
  }
}

class NotificationDataDetail {
  double? amount;
  String? transactionId;
  String? paymentMethod;
  String? time;
  String? bookingId;
  String? paymentId;

  NotificationDataDetail({
    this.amount,
    this.transactionId,
    this.paymentMethod,
    this.time,
    this.bookingId,
    this.paymentId,
  });

  factory NotificationDataDetail.fromJson(Map<String, dynamic> json) {
    return NotificationDataDetail(
      amount: json['amount'] != null
          ? (json['amount'] is int
          ? (json['amount'] as int).toDouble()
          : json['amount'] as double?)
          : null,
      transactionId: json['transactionId'],
      paymentMethod: json['paymentMethod'],
      time: json['time'],
      bookingId: json['bookingId'],
      paymentId: json['paymentId'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'amount': amount,
      'transactionId': transactionId,
      'paymentMethod': paymentMethod,
      'time': time,
      'bookingId': bookingId,
      'paymentId': paymentId,
    };
  }
}
