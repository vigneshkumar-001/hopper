class WithdrawRequestResponse {
  final bool success;
  final String message;
  final WithdrawRequestData? data;

  const WithdrawRequestResponse({
    required this.success,
    required this.message,
    required this.data,
  });

  factory WithdrawRequestResponse.fromJson(Map<String, dynamic> json) {
    return WithdrawRequestResponse(
      success: json['success'] == true,
      message: (json['message'] ?? '').toString(),
      data:
          json['data'] is Map
              ? WithdrawRequestData.fromJson(
                Map<String, dynamic>.from(json['data'] as Map),
              )
              : null,
    );
  }
}

class WithdrawRequestData {
  final num amount;

  const WithdrawRequestData({required this.amount});

  factory WithdrawRequestData.fromJson(Map<String, dynamic> json) {
    final a = json['amount'];
    if (a is num) return WithdrawRequestData(amount: a);
    return WithdrawRequestData(amount: num.tryParse((a ?? '').toString()) ?? 0);
  }
}

