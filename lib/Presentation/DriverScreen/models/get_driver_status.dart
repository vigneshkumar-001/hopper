class GetDriverStatus {
  final int status;
  final OnlineStatusData data;

  GetDriverStatus({required this.status, required this.data});

  factory GetDriverStatus.fromJson(Map<String, dynamic> json) {
    return GetDriverStatus(
      status: json['status'],
      data: OnlineStatusData.fromJson(json['data']),
    );
  }

  Map<String, dynamic> toJson() {
    return {'status': status, 'data': data.toJson()};
  }
}

class OnlineStatusData {
  final bool onlineStatus;
  final String serviceType;
  final bool sharedBooking;

  OnlineStatusData({
    required this.onlineStatus,
    required this.serviceType,
    required this.sharedBooking,
  });

  factory OnlineStatusData.fromJson(Map<String, dynamic> json) {
    bool asBool(dynamic v) {
      if (v is bool) return v;
      if (v is num) return v != 0;
      final s = (v ?? '').toString().trim().toLowerCase();
      if (s == 'true' || s == '1' || s == 'yes') return true;
      if (s == 'false' || s == '0' || s == 'no') return false;
      return false;
    }

    return OnlineStatusData(
      onlineStatus: json['onlineStatus'],
      serviceType: json['serviceType'] ?? '',
      sharedBooking: asBool(json['sharedBooking']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'onlineStatus': onlineStatus,
      'serviceType': serviceType,
      'sharedBooking': sharedBooking,
    };
  }
}
