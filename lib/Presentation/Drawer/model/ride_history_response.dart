import 'package:intl/intl.dart';

num? _numOrNull(dynamic v) {
  if (v == null) return null;
  if (v is num) return v;
  if (v is String) {
    final s = v.trim();
    if (s.isEmpty) return null;
    return num.tryParse(s);
  }
  return null;
}

double _doubleOr(dynamic v, [double fallback = 0]) {
  final n = _numOrNull(v);
  return (n ?? fallback).toDouble();
}

int _intOr(dynamic v, [int fallback = 0]) {
  final n = _numOrNull(v);
  if (n == null) return fallback;
  // if API is giving durations like "120" or "120.0", round it
  return n is int ? n : n.round();
}

String _stringOr(dynamic v, [String fallback = '']) {
  if (v == null) return fallback;
  return v.toString();
}

class RideActivityHistoryResponse {
  final bool success;
  final List<RideActivityHistoryData> remappedBookings;

  RideActivityHistoryResponse({
    required this.success,
    required this.remappedBookings,
  });

  factory RideActivityHistoryResponse.fromJson(Map<String, dynamic> json) {
    return RideActivityHistoryResponse(
      success: json['success'] ?? false,
      remappedBookings:
          (json['remappedBookings'] as List? ?? [])
              .map(
                (e) =>
                    RideActivityHistoryData.fromJson(e as Map<String, dynamic>),
              )
              .toList(),
    );
  }
}

class RideActivityHistoryData {
  final String ridehistoryColor;
  final String bookingId;
  final String status;
  final String bookingType;
  final String rideType;
  final double amount;
  final dynamic distance; // keep raw; can be String or number
  final int duration;
  final String? carType;
  final String?
  rating; // keeping as String per your original (UI may expect string)
  final String createdAt;
  final Pickup pickup;
  final Dropoff dropoff;
  final FareBreakdown fareBreakdown;
  final String rideDurationFormatted;
  final List<RideActivityStatusHistory> rideStatusHistory;
  final Driver driver;
  final Customer customer;
  final PaymentDetails paymentDetails;

  RideActivityHistoryData({
    required this.bookingId,
    required this.ridehistoryColor,
    required this.status,
    required this.bookingType,
    required this.rideType,
    required this.amount,
    required this.distance,
    required this.duration,
    this.carType,
    this.rating,
    required this.createdAt,
    required this.pickup,
    required this.dropoff,
    required this.fareBreakdown,
    required this.rideDurationFormatted,
    required this.rideStatusHistory,
    required this.driver,
    required this.customer,
    required this.paymentDetails,
  });

  factory RideActivityHistoryData.fromJson(Map<String, dynamic> json) {
    return RideActivityHistoryData(
      bookingId: _stringOr(json['bookingId']),
      ridehistoryColor: _stringOr(json['ridehistoryColor']),
      status: _stringOr(json['status']),
      bookingType: _stringOr(json['bookingType']),
      rideType: _stringOr(json['rideType']),
      amount: _doubleOr(json['amount']), // <- safe for "12.3" or 12.3 or null
      distance: json['distance'], // keep dynamic; parse later if needed
      duration: _intOr(json['duration']),
      carType: json['carType'] != null ? _stringOr(json['carType']) : null,
      rating: json['rating'] != null ? _stringOr(json['rating']) : '0',
      createdAt: _stringOr(json['createdAt']),
      pickup: Pickup.fromJson((json['pickup'] ?? {}) as Map<String, dynamic>),
      dropoff: Dropoff.fromJson(
        (json['dropoff'] ?? {}) as Map<String, dynamic>,
      ),
      fareBreakdown: FareBreakdown.fromJson(
        (json['fareBreakdown'] ?? {}) as Map<String, dynamic>,
      ),
      rideDurationFormatted: _stringOr(json['rideDurationFormatted']),
      rideStatusHistory:
          (json['rideStatusHistory'] as List? ?? [])
              .map(
                (e) => RideActivityStatusHistory.fromJson(
                  e as Map<String, dynamic>,
                ),
              )
              .toList(),
      driver: Driver.fromJson((json['driver'] ?? {}) as Map<String, dynamic>),
      customer: Customer.fromJson(
        (json['customer'] ?? {}) as Map<String, dynamic>,
      ),
      paymentDetails:
          json['paymentDetails'] != null
              ? PaymentDetails.fromJson(
                json['paymentDetails'] as Map<String, dynamic>,
              )
              : PaymentDetails(
                amount: 0,
                status: '',
                method: '',
                paymentId: '',
              ),
    );
  }

  /// Example helper if you later want distance as km (handles "12.3", 12.3, "12.3 km")
  double get distanceKm {
    if (distance == null) return 0;
    if (distance is num) return (distance as num).toDouble();
    if (distance is String) {
      final s = (distance as String).trim().toLowerCase();
      final numeric = RegExp(r'[\d\.\-]+').stringMatch(s);
      return _doubleOr(numeric ?? 0);
    }
    return 0;
  }

  String get formattedCreatedAt {
    if (createdAt.isEmpty) return "";
    try {
      // supports ISO strings; if your API returns epoch ms, adapt here
      final dateTime = DateTime.parse(createdAt).toLocal();
      return DateFormat("MMM dd, yyyy").format(dateTime);
    } catch (_) {
      return createdAt;
    }
  }
}

class Dropoff {
  final String address;
  final String? time;

  Dropoff({required this.address, this.time});

  factory Dropoff.fromJson(Map<String, dynamic> json) {
    return Dropoff(
      address: _stringOr(json['address']),
      time: json['time'] != null ? _stringOr(json['time']) : null,
    );
  }
}

class Driver {
  final String name;
  final double? rating;
  final String? profilePic;

  Driver({required this.name, this.rating, this.profilePic});

  factory Driver.fromJson(Map<String, dynamic> json) {
    return Driver(
      name: _stringOr(json['name']),
      rating: _numOrNull(json['rating'])?.toDouble(),
      profilePic:
          json['profilePic'] != null ? _stringOr(json['profilePic']) : null,
    );
  }
}

class Pickup {
  final String address;
  final String time;

  Pickup({required this.address, required this.time});

  factory Pickup.fromJson(Map<String, dynamic> json) {
    return Pickup(
      address: _stringOr(json['address']),
      time: _stringOr(json['time']),
    );
  }
}

class FareBreakdown {
  final double baseFare;
  final double distanceFare;
  final double timeFare;
  final double tips;
  final String commission;
  final String surgeFare;
  final double total;

  FareBreakdown({
    required this.baseFare,
    required this.distanceFare,
    required this.timeFare,
    required this.tips,
    required this.commission,
    required this.surgeFare,
    required this.total,
  });

  factory FareBreakdown.fromJson(Map<String, dynamic> json) {
    return FareBreakdown(
      baseFare: _doubleOr(json['baseFare']),
      distanceFare: _doubleOr(json['distanceFare']),
      timeFare: _doubleOr(json['timeFare']),
      tips: _doubleOr(json['tips']),
      commission: json['commission'] ?? '',
      surgeFare: json['surgeFare'] ?? '',
      total: _doubleOr(json['total']),
    );
  }
}

class RideActivityStatusHistory {
  final String status;
  final String timestamp;

  RideActivityStatusHistory({required this.status, required this.timestamp});

  factory RideActivityStatusHistory.fromJson(Map<String, dynamic> json) {
    return RideActivityStatusHistory(
      status: _stringOr(json['status']),
      timestamp: _stringOr(json['timestamp']),
    );
  }
}

class Customer {
  final String name;
  final String email;
  final String phone;
  final double? rating;
  final String? profilePic;

  Customer({
    required this.name,
    required this.email,
    required this.phone,
    this.rating,
    this.profilePic,
  });

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      name: _stringOr(json['name']),
      email: _stringOr(json['email']),
      phone: _stringOr(json['phone']),
      rating: _numOrNull(json['rating'])?.toDouble(),
      profilePic:
          json['profilePic'] != null ? _stringOr(json['profilePic']) : null,
    );
  }
}

class PaymentDetails {
  final String method;
  final String status;
  final double amount;
  final String? paymentId;

  PaymentDetails({
    required this.amount,
    required this.status,
    required this.method,
    required this.paymentId,
  });

  factory PaymentDetails.fromJson(Map<String, dynamic> json) {
    return PaymentDetails(
      method: _stringOr(json['method']),
      status: _stringOr(json['status']),
      amount: _doubleOr(json['amount']),
      paymentId:
          json['paymentId'] != null ? _stringOr(json['paymentId']) : null,
    );
  }
}
