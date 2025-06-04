class ChooseServiceModel {
  final int status;
  final String message;
  final String serviceType;
  final int landingPage;

  ChooseServiceModel({
    required this.status,
    required this.message,
    required this.serviceType,
    required this.landingPage,
  });

  factory ChooseServiceModel.fromJson(Map<String, dynamic> json) {
    return ChooseServiceModel(
      status: json['status'] ?? 0,
      message: json['message'] ?? '',
      serviceType: json['serviceType'] ?? '',
      landingPage: json['landingPage'] ?? 0,
    );
  }
}
