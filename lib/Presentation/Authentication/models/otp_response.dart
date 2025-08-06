// class OtpResponse {
//   final int status;
//   final String message;
//   final String userId;
//   final String userStatus;
//   final String token;
//
//   OtpResponse({
//     required this.status,
//     required this.message,
//     required this.userId,
//     required this.userStatus,
//     required this.token,
//   });
//
//   factory OtpResponse.fromJson(Map<String, dynamic> json) {
//     return OtpResponse(
//       status: json['status'] ?? 0,
//       message: json['message'] ?? '',
//       userId: json['userId'] ?? '',
//       userStatus: json['userStatus'] ?? '',
//       token: json['token'] ?? '',
//     );
//   }
//
//   Map<String, dynamic> toJson() {
//     return {
//       'status': status,
//       'message': message,
//       'userId': userId,
//       'userStatus': userStatus,
//       'token': token,
//     };
//   }
// }
class OtpResponse {
  final int status;
  final String message;
  final OtpVerificationData data;

  OtpResponse({
    required this.status,
    required this.message,
    required this.data,
  });

  factory OtpResponse.fromJson(Map<String, dynamic> json) {
    return OtpResponse(
      status: json['status'] ?? 0,
      message: json['message'] ?? '',
      data: OtpVerificationData.fromJson(json['data'] ?? {}),
    );
  }
}

class OtpVerificationData {
  final String userStatus;
  final String token;
  final String driverId;

  OtpVerificationData({required this.userStatus, required this.token,required this.driverId});

  factory OtpVerificationData.fromJson(Map<String, dynamic> json) {
    return OtpVerificationData(
      userStatus: json['userStatus'] ?? '',
      token: json['token'] ?? '',
      driverId: json['driverId'] ?? '',
    );
  }
  Map<String, dynamic> toJson() {
    return {'userStatus': userStatus, 'token': token,'driverId': driverId};
  }
}
