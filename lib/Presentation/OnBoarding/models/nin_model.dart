class NinVerificationResponse {
  int? status;
  String? message;
  String? type;
  NinVerificationData? data;

  NinVerificationResponse({this.status, this.message, this.type, this.data});

  factory NinVerificationResponse.fromJson(Map<String, dynamic> json) {
    return NinVerificationResponse(
      status:
          json['status'] is int
              ? json['status']
              : int.tryParse(json['status'].toString()),
      message: json['message']?.toString(),
      type: json['type']?.toString(),
      data:
          json['data'] != null
              ? NinVerificationData.fromJson(json['data'])
              : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'status': status,
      'message': message,
      'type': type,
      'data': data?.toJson(),
    };
  }
}

class NinVerificationData {
  String? nationalIdNumber;
  String? frontIdCardNin;
  String? backIdCardNin;

  NinVerificationData({
    this.nationalIdNumber,
    this.frontIdCardNin,
    this.backIdCardNin,
  });

  factory NinVerificationData.fromJson(Map<String, dynamic> json) {
    return NinVerificationData(
      nationalIdNumber: json['nationalIdNumber']?.toString(),
      frontIdCardNin: json['frontIdCardNin']?.toString(),
      backIdCardNin: json['backIdCardNin']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'nationalIdNumber': nationalIdNumber,
      'frontIdCardNin': frontIdCardNin,
      'backIdCardNin': backIdCardNin,
    };
  }
}
