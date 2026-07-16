class PendingBookingRequestResponse {
  final bool success;
  final bool hasPendingBookingRequest;
  final Map<String, dynamic>? data;
  final String message;

  PendingBookingRequestResponse({
    required this.success,
    required this.hasPendingBookingRequest,
    required this.data,
    required this.message,
  });

  static bool _asBool(dynamic value) {
    if (value == true) return true;
    if (value is num) return value != 0;
    final normalized = value?.toString().trim().toLowerCase();
    return normalized == 'true' ||
        normalized == '1' ||
        normalized == 'yes' ||
        normalized == 'success';
  }

  static bool _asSuccess(dynamic value) {
    if (_asBool(value)) return true;
    if (value is num) return value == 200;
    final normalized = value?.toString().trim();
    return normalized == '200';
  }

  factory PendingBookingRequestResponse.fromJson(Map<String, dynamic> json) {
    final success =
        _asBool(json['success']) ||
        _asSuccess(json['status']) ||
        _asSuccess(json['code']);

    final hasPending =
        _asBool(json['hasPendingBookingRequest']) ||
        _asBool(json['hasPendingRequest']) ||
        _asBool(json['hasBookingRequest']);

    final rawData =
        json['data'] ?? json['booking'] ?? json['pendingBookingRequest'];
    final data =
        rawData is Map
            ? Map<String, dynamic>.from(rawData as Map)
            : rawData is List && rawData.isNotEmpty && rawData.first is Map
                ? Map<String, dynamic>.from(rawData.first as Map)
                : null;

    return PendingBookingRequestResponse(
      success: success,
      hasPendingBookingRequest: hasPending,
      data: data,
      message: (json['message'] ?? '').toString(),
    );
  }
}
