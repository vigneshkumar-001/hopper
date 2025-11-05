class PaymentStatusModel {
  final bool success;
  final PaymentData data;

  PaymentStatusModel({
    required this.success,
    required this.data,
  });

  factory PaymentStatusModel.fromJson(Map<String, dynamic> json) {
    return PaymentStatusModel(
      success: json['success'] ?? false,
      data: PaymentData.fromJson(json['data'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() => {
    'success': success,
    'data': data.toJson(),
  };
}

class PaymentData {
  final String paymentType;
  final String paymentStatus;

  PaymentData({
    required this.paymentType,
    required this.paymentStatus,
  });

  factory PaymentData.fromJson(Map<String, dynamic> json) {
    return PaymentData(
      paymentType: json['paymentType'] ?? '',
      paymentStatus: json['paymentStatus'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'paymentType': paymentType,
    'paymentStatus': paymentStatus,
  };
}
