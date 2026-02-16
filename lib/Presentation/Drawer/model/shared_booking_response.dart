

class SharedBookingEnabledResponse {
  final String message;
  final SharedBookingStatus status;

  const SharedBookingEnabledResponse({
    required this.message,
    required this.status,
  });

  factory SharedBookingEnabledResponse.fromJson(Map<String, dynamic> json) {
    return SharedBookingEnabledResponse(
      message: (json['message'] ?? '').toString(),
      status: SharedBookingStatus.fromJson(
        (json['status'] as Map<String, dynamic>? ?? const {}),
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'message': message,
    'status': status.toJson(),
  };
}

class SharedBookingStatus {
  final String driverId;
  final bool isEnabled;

  /// Mongo fields
  final String id; // _id
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int? v; // __v

  const SharedBookingStatus({
    required this.driverId,
    required this.isEnabled,
    required this.id,
    this.createdAt,
    this.updatedAt,
    this.v,
  });

  factory SharedBookingStatus.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      return DateTime.tryParse(v.toString());
    }

    return SharedBookingStatus(
      driverId: (json['driverId'] ?? '').toString(),
      isEnabled: json['isEnabled'] == true,
      id: (json['_id'] ?? '').toString(),
      createdAt: parseDate(json['createdAt']),
      updatedAt: parseDate(json['updatedAt']),
      v: (json['__v'] is int) ? json['__v'] as int : int.tryParse('${json['__v']}'),
    );
  }

  Map<String, dynamic> toJson() => {
    'driverId': driverId,
    'isEnabled': isEnabled,
    '_id': id,
    'createdAt': createdAt?.toUtc().toIso8601String(),
    'updatedAt': updatedAt?.toUtc().toIso8601String(),
    '__v': v,
  };
}
