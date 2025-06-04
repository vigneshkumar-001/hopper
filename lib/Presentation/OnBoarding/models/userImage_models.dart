
class UserImageModels {
  final bool status;
  final String message;

  UserImageModels({
    required this.status,
    required this.message,
  });

  factory UserImageModels.fromJson(Map<String, dynamic> json) {
    return UserImageModels(
      status: json['status'] ?? false,
      message: json['message'] ?? '',
    );
  }
}
