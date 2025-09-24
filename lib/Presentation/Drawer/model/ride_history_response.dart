class  RideActivityHistoryResponse  {
  final bool success;
  final List<RideActivityHistoryData> remappedBookings;

  RideActivityHistoryResponse({
    required this.success,
    required this.remappedBookings,
  });

  factory RideActivityHistoryResponse.fromJson(Map<String, dynamic> json) {
    return RideActivityHistoryResponse(
      success: json['success'],
      remappedBookings: (json['remappedBookings'] as List)
          .map((e) => RideActivityHistoryData.fromJson(e))
          .toList(),
    );
  }
}

class RideActivityHistoryData {
  final String bookingId;
  final String status;
  final String bookingType;
  final String rideType;
  final double amount;
  final int distance;
  final int duration;
  final String carType;
  final double? rating;
  final String createdAt;
  final Pickup pickup;
  final Dropoff dropoff;
  final FareBreakdown fareBreakdown;
  final String rideDurationFormatted;
  final List<RideActivityStatusHistory> rideStatusHistory;
  final Driver driver;
  final Customer customer;
  final dynamic paymentDetails;

  RideActivityHistoryData({
    required this.bookingId,
    required this.status,
    required this.bookingType,
    required this.rideType,
    required this.amount,
    required this.distance,
    required this.duration,
    required this.carType,
    this.rating,
    required this.createdAt,
    required this.pickup,
    required this.dropoff,
    required this.fareBreakdown,
    required this.rideDurationFormatted,
    required this.rideStatusHistory,
    required this.driver,
    required this.customer,
    this.paymentDetails,
  });

  factory RideActivityHistoryData.fromJson(Map<String, dynamic> json) {
    return RideActivityHistoryData(
      bookingId: json['bookingId'],
      status: json['status'],
      bookingType: json['bookingType'],
      rideType: json['rideType'],
      amount: (json['amount'] as num).toDouble(),
      distance: json['distance'],
      duration: json['duration'],
      carType: json['carType'],
      rating: json['rating'] != null ? (json['rating'] as num).toDouble() : null,
      createdAt: json['createdAt'],
      pickup: Pickup.fromJson(json['pickup']),
      dropoff: Dropoff.fromJson(json['dropoff']),
      fareBreakdown: FareBreakdown.fromJson(json['fareBreakdown']),
      rideDurationFormatted: json['rideDurationFormatted'],
      rideStatusHistory: (json['rideStatusHistory'] as List)
          .map((e) => RideActivityStatusHistory.fromJson(e))
          .toList(),
      driver: Driver.fromJson(json['driver']),
      customer: Customer.fromJson(json['customer']),
      paymentDetails: json['paymentDetails'],
    );
  }
}

class Pickup {
  final String address;
  final String time;

  Pickup({
    required this.address,
    required this.time,
  });

  factory Pickup.fromJson(Map<String, dynamic> json) {
    return Pickup(
      address: json['address'],
      time: json['time']?? '',
    );
  }
}

class Dropoff {
  final String address;
  final String time;

  Dropoff({
    required this.address,
    required this.time,
  });

  factory Dropoff.fromJson(Map<String, dynamic> json) {
    return Dropoff(
      address: json['address'],
      time: json['time'],
    );
  }
}

class FareBreakdown {
  final double baseFare;
  final double distanceFare;
  final double timeFare;
  final double tips;
  final double total;

  FareBreakdown({
    required this.baseFare,
    required this.distanceFare,
    required this.timeFare,
    required this.tips,
    required this.total,
  });

  factory FareBreakdown.fromJson(Map<String, dynamic> json) {
    return FareBreakdown(
      baseFare: (json['baseFare'] as num).toDouble(),
      distanceFare: (json['distanceFare'] as num).toDouble(),
      timeFare: (json['timeFare'] as num).toDouble(),
      tips: (json['tips'] as num).toDouble(),
      total: (json['total'] as num).toDouble(),
    );
  }
}

class RideActivityStatusHistory {
  final String status;
  final String timestamp;

  RideActivityStatusHistory({
    required this.status,
    required this.timestamp,
  });

  factory RideActivityStatusHistory.fromJson(Map<String, dynamic> json) {
    return RideActivityStatusHistory(
      status: json['status'],
      timestamp: json['timestamp'],
    );
  }
}

class Driver {
  final String name;
  final double? rating;
  final String profilePic;

  Driver({
    required this.name,
    this.rating,
    required this.profilePic,
  });

  factory Driver.fromJson(Map<String, dynamic> json) {
    return Driver(
      name: json['name'],
      rating: json['rating'] != null ? (json['rating'] as num).toDouble() : null,
      profilePic: json['profilePic'],
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
      name: json['name'],
      email: json['email'],
      phone: json['phone'],
      rating: json['rating'] != null ? (json['rating'] as num).toDouble() : null,
      profilePic: json['profilePic'],
    );
  }
}
