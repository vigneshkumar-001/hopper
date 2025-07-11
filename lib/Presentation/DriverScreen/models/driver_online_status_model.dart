class DriverOnlineStatusModel {
  final int status;
  final DriverStatusData data;
  final String message;

  DriverOnlineStatusModel({
    required this.status,
    required this.data,
    required this.message,
  });

  factory DriverOnlineStatusModel.fromJson(Map<String, dynamic> json) {
    return DriverOnlineStatusModel(
      status: json['status'] ,
      data: DriverStatusData.fromJson(json['data']),
      message: json['message'],
    );
  }

  Map<String, dynamic> toJson() {
    return {'status': status, 'data': data.toJson(), 'message': message};
  }
}

class DriverStatusData {
  final String id;
  final String driverId;
  final int v;
  final bool booked;
  final DateTime createdAt;
  final double currentLatitude;
  final double currentLongitude;
  final bool onlineStatus;
  final bool sharedBooking;
  final DateTime updatedAt;
  final DateTime requestDateAndTime;
  final String requestStatus;
  final String rideId;
  final DateTime lastOnlineAt;

  DriverStatusData({
    required this.id,
    required this.driverId,
    required this.v,
    required this.booked,
    required this.createdAt,
    required this.currentLatitude,
    required this.currentLongitude,
    required this.onlineStatus,
    required this.sharedBooking,
    required this.updatedAt,
    required this.requestDateAndTime,
    required this.requestStatus,
    required this.rideId,
    required this.lastOnlineAt,
  });

  factory DriverStatusData.fromJson(Map<String, dynamic> json) {
    return DriverStatusData(
      id: json['_id'],
      driverId: json['driverId'],
      v: json['__v'],
      booked: json['booked'],
      createdAt: DateTime.parse(json['createdAt']),
      currentLatitude: (json['currentLatitude'] as num).toDouble(),
      currentLongitude: (json['currentLongitude'] as num).toDouble(),
      onlineStatus: json['onlineStatus'],
      sharedBooking: json['sharedBooking'],
      updatedAt: DateTime.parse(json['updatedAt']),
      requestDateAndTime: DateTime.parse(json['requestDateAndTime']),
      requestStatus: json['requestStatus'],
      rideId: json['rideId'],
      lastOnlineAt: DateTime.parse(json['lastOnlineAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'driverId': driverId,
      '__v': v,
      'booked': booked,
      'createdAt': createdAt.toIso8601String(),
      'currentLatitude': currentLatitude,
      'currentLongitude': currentLongitude,
      'onlineStatus': onlineStatus,
      'sharedBooking': sharedBooking,
      'updatedAt': updatedAt.toIso8601String(),
      'requestDateAndTime': requestDateAndTime.toIso8601String(),
      'requestStatus': requestStatus,
      'rideId': rideId,
      'lastOnlineAt': lastOnlineAt.toIso8601String(),
    };
  }
}
