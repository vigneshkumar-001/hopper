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
      status: (json['status'] as num?)?.toInt() ?? 0,
      data: DriverStatusData.fromJson(
        (json['data'] as Map<String, dynamic>?) ?? const <String, dynamic>{},
      ),
      message: json['message']?.toString() ?? '',
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
  final DateTime? createdAt;
  final double currentLatitude;
  final double currentLongitude;
  final bool onlineStatus;
  final bool sharedBooking;
  final DateTime? updatedAt;
  final DateTime? requestDateAndTime;
  final String requestStatus;
  final String rideId;
  final DateTime? lastOnlineAt;

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
      id: json['_id']?.toString() ?? '',
      driverId: json['driverId']?.toString() ?? '',
      v: (json['__v'] as num?)?.toInt() ?? 0,
      booked: json['booked'] as bool? ?? false,
      createdAt: _parseDate(json['createdAt']),
      currentLatitude: (json['currentLatitude'] as num?)?.toDouble() ?? 0,
      currentLongitude: (json['currentLongitude'] as num?)?.toDouble() ?? 0,
      onlineStatus: json['onlineStatus'] as bool? ?? false,
      sharedBooking: json['sharedBooking'] as bool? ?? false,
      updatedAt: _parseDate(json['updatedAt']),
      requestDateAndTime: _parseDate(json['requestDateAndTime']),
      requestStatus: json['requestStatus']?.toString() ?? '',
      rideId: json['rideId']?.toString() ?? '',
      lastOnlineAt: _parseDate(json['lastOnlineAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'driverId': driverId,
      '__v': v,
      'booked': booked,
      'createdAt': createdAt?.toIso8601String(),
      'currentLatitude': currentLatitude,
      'currentLongitude': currentLongitude,
      'onlineStatus': onlineStatus,
      'sharedBooking': sharedBooking,
      'updatedAt': updatedAt?.toIso8601String(),
      'requestDateAndTime': requestDateAndTime?.toIso8601String(),
      'requestStatus': requestStatus,
      'rideId': rideId,
      'lastOnlineAt': lastOnlineAt?.toIso8601String(),
    };
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) {
      return null;
    }
    final raw = value.toString();
    if (raw.isEmpty) {
      return null;
    }
    return DateTime.tryParse(raw);
  }
}
