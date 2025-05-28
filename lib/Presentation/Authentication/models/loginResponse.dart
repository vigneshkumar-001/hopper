class LoginResponse {
  String? status;

  String? message;

  String? token;
  dynamic data;

  LoginResponse({this.message, this.status, this.token, this.data});

  LoginResponse.fromJson(Map<String, dynamic> json) {
    message = json['message'];
    status = json['status']?.toString();

    token = json['token'];
    data = json['data'] ?? '';
  }
}
