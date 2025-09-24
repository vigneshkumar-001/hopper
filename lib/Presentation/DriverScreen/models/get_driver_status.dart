class  GetDriverStatus  {
  final int status;
  final OnlineStatusData data;

  GetDriverStatus({
    required this.status,
    required this.data,
  });

  factory GetDriverStatus.fromJson(Map<String, dynamic> json) {
    return GetDriverStatus(
      status: json['status'],
      data: OnlineStatusData.fromJson(json['data']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'status': status,
      'data': data.toJson(),
    };
  }
}

class OnlineStatusData {
  final bool onlineStatus;
  final String  serviceType;

  OnlineStatusData({
    required this.onlineStatus,
    required this.serviceType,
  });

  factory OnlineStatusData.fromJson(Map<String, dynamic> json) {
    return OnlineStatusData(
      onlineStatus: json['onlineStatus'],
      serviceType: json['serviceType'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'onlineStatus': onlineStatus,
      'serviceType': serviceType,
    };
  }
}
