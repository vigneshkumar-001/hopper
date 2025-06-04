class BasicInfoResponse {
  final int status;
  final String message;
  final String userId;
  final int pageNo;

  BasicInfoResponse({
    required this.status,
    required this.message,
    required this.userId,
    required this.pageNo,
  });

  factory BasicInfoResponse.fromJson(Map<String, dynamic> json) {
    return BasicInfoResponse(
      status: json['status'] ?? 0,
      message: json['message'] ?? '',
      userId: json['userId'] ?? '',
      pageNo: json['pageNo'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'status': status,
      'message': message,
      'userId': userId,
      'pageNo': pageNo,
    };
  }
}
