class   FcmResponse   {
  final bool success;
  final String message;
  FcmResponse({required this.message, required this.success});

  factory FcmResponse.fromJson(Map<String, dynamic> json) {
    return FcmResponse(
      success: json['success'],
      message: json['message'] ?? '',
    );
  }
  Map<String, dynamic> toJson() => {"message": message, "success": success};
}
