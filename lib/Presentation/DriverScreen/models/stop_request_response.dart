class StopRequestResponse {
  final String message;
  final bool success;
  final bool stop;

  StopRequestResponse({
    required this.message,
    required this.success,
    required this.stop,
  });

  factory StopRequestResponse.fromJson(Map<String, dynamic> json) {
    return StopRequestResponse(
      message: json['message'] ?? '',
      success: json['success'] ?? false,
      stop: json['stop'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'message': message,
      'success': success,
      'stop': stop,
    };
  }
}
