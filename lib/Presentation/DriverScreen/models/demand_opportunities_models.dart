class DemandOpportunitiesResponse {
  final bool success;
  final DemandOpportunitiesData? data;
  final String? message;

  DemandOpportunitiesResponse({required this.success, this.data, this.message});

  factory DemandOpportunitiesResponse.fromJson(Map<String, dynamic> json) {
    return DemandOpportunitiesResponse(
      success: json['success'] == true,
      message:
          (json['message'] ?? '').toString().trim().isEmpty
              ? null
              : (json['message'] ?? '').toString(),
      data:
          json['data'] is Map<String, dynamic>
              ? DemandOpportunitiesData.fromJson(
                (json['data'] as Map<String, dynamic>),
              )
              : null,
    );
  }
}

class DemandOpportunitiesData {
  final bool eligible;
  final String driverStatus;
  final String serviceType;
  final DateTime? generatedAt;
  final List<DemandOpportunity> opportunities;
  final DemandOpportunitiesSummary? summary;

  DemandOpportunitiesData({
    required this.eligible,
    required this.driverStatus,
    required this.serviceType,
    required this.generatedAt,
    required this.opportunities,
    required this.summary,
  });

  factory DemandOpportunitiesData.fromJson(Map<String, dynamic> json) {
    final list = <DemandOpportunity>[];
    final rawList = json['opportunities'];
    if (rawList is List) {
      for (final e in rawList) {
        if (e is Map<String, dynamic>) {
          list.add(DemandOpportunity.fromJson(e));
        } else if (e is Map) {
          list.add(DemandOpportunity.fromJson(Map<String, dynamic>.from(e)));
        }
      }
    }

    DateTime? generatedAt;
    final genRaw = json['generatedAt'];
    if (genRaw != null) {
      generatedAt = DateTime.tryParse(genRaw.toString());
    }

    return DemandOpportunitiesData(
      eligible: json['eligible'] == true,
      driverStatus: (json['driverStatus'] ?? '').toString(),
      serviceType: (json['serviceType'] ?? '').toString(),
      generatedAt: generatedAt,
      opportunities: list,
      summary:
          json['summary'] is Map<String, dynamic>
              ? DemandOpportunitiesSummary.fromJson(
                (json['summary'] as Map<String, dynamic>),
              )
              : (json['summary'] is Map
                  ? DemandOpportunitiesSummary.fromJson(
                    Map<String, dynamic>.from(json['summary'] as Map),
                  )
                  : null),
    );
  }
}

class DemandOpportunitiesSummary {
  final int totalNearbyZones;
  final double recommendedRadiusKm;

  DemandOpportunitiesSummary({
    required this.totalNearbyZones,
    required this.recommendedRadiusKm,
  });

  factory DemandOpportunitiesSummary.fromJson(Map<String, dynamic> json) {
    final total = json['totalNearbyZones'];
    final radius = json['recommendedRadiusKm'];

    return DemandOpportunitiesSummary(
      totalNearbyZones: total is int ? total : int.tryParse('$total') ?? 0,
      recommendedRadiusKm:
          radius is num ? radius.toDouble() : double.tryParse('$radius') ?? 0.0,
    );
  }
}

class DemandOpportunity {
  final Map<String, dynamic> raw;

  DemandOpportunity(this.raw);

  factory DemandOpportunity.fromJson(Map<String, dynamic> json) =>
      DemandOpportunity(json);

  String get id =>
      (raw['id'] ?? raw['_id'] ?? raw['opportunityId'] ?? raw['zoneId'] ?? '')
          .toString();

  String get title =>
      (raw['title'] ?? raw['name'] ?? 'Demand Opportunity').toString().trim();

  String get message =>
      (raw['message'] ?? raw['description'] ?? raw['subtitle'] ?? '')
          .toString()
          .trim();

  String get serviceType =>
      (raw['serviceType'] ?? raw['rideType'] ?? '').toString().trim();

  String get bookingType => (raw['bookingType'] ?? '').toString().trim();

  String get demandLevel => (raw['demandLevel'] ?? '').toString().trim();

  String get hint => (raw['hint'] ?? '').toString().trim();

  String get cta => (raw['cta'] ?? '').toString().trim();

  String get source => (raw['source'] ?? '').toString().trim();

  DateTime? get validUntil {
    final v = raw['validUntil'];
    if (v == null) return null;
    return DateTime.tryParse(v.toString());
  }

  double? get distanceKm {
    final km = raw['distanceFromDriverKm'] ?? raw['distanceKm'];
    if (km is num) return km.toDouble();
    final parsed = double.tryParse(km?.toString() ?? '');
    if (parsed != null) return parsed;

    final m = distanceMeters;
    if (m == null) return null;
    return m / 1000.0;
  }

  double? get distanceMeters {
    final km = raw['distanceFromDriverKm'] ?? raw['distanceKm'];
    if (km is num) return km.toDouble() * 1000.0;
    final parsedKm = double.tryParse(km?.toString() ?? '');
    if (parsedKm != null) return parsedKm * 1000.0;

    final d =
        raw['distanceInMeters'] ?? raw['distanceMeters'] ?? raw['distance'];
    if (d == null) return null;
    if (d is num) return d.toDouble();
    return double.tryParse(d.toString());
  }

  double? get latitude {
    final v = raw['latitude'] ?? raw['lat'];
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '');
  }

  double? get longitude {
    final v = raw['longitude'] ?? raw['lng'];
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '');
  }
}
