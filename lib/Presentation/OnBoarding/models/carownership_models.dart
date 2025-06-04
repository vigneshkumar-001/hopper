class CarOwnershipModels {
  int? status;
  String? message;
  String? userId;
  int? landingPage;

  CarOwnershipModels({
    this.status,
    this.message,
    this.userId,
    this.landingPage,
  });

  factory CarOwnershipModels.fromJson(Map<String, dynamic> json) {
    return CarOwnershipModels(
      status:
          json['status'] is int
              ? json['status']
              : int.tryParse(json['status'].toString()),
      message: json['message']?.toString(),
      userId: json['userId']?.toString(),
      landingPage:
          json['landingPage'] is int
              ? json['landingPage']
              : int.tryParse(json['landingPage'].toString()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'status': status,
      'message': message,
      'userId': userId,
      'landingPage': landingPage,
    };
  }
}
