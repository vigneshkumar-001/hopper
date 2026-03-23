class DriverActiveBookingResponse {
  final bool success;
  final bool hasBooking;
  final Map<String, dynamic>? data;

  DriverActiveBookingResponse({
    required this.success,
    required this.hasBooking,
    this.data,
  });

  static bool _asBool(dynamic v) {
    if (v == true) return true;
    final s = v?.toString().toLowerCase().trim();
    return s == 'true' || s == '1' || s == 'yes';
  }

  static bool _asSuccess(dynamic v) {
    if (v == true) return true;
    if (v is int) return v == 200;
    final s = v?.toString().trim();
    return s == '200';
  }

  factory DriverActiveBookingResponse.fromJson(Map<String, dynamic> json) {
    final success =
        _asBool(json['success']) || _asSuccess(json['status']) || _asSuccess(json['code']);

    final hasBooking =
        _asBool(json['hasBooking']) ||
        _asBool(json['hasActiveBooking']) ||
        _asBool(json['hasActiveRide']) ||
        _asBool(json['hasRide']);

    Map<String, dynamic>? data;
    final rawData = json['data'] ?? json['booking'] ?? json['activeBooking'];
    if (rawData is Map<String, dynamic>) {
      data = rawData;
    }

    return DriverActiveBookingResponse(
      success: success,
      hasBooking: hasBooking,
      data: data,
    );
  }
}
