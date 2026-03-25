import 'package:hopper/Core/Utility/date_time_converter.dart';

class TodayParcelActivityResponse {
  final int status;
  final ParcelBookingData data;

  TodayParcelActivityResponse({required this.status, required this.data});

  factory TodayParcelActivityResponse.fromJson(Map<String, dynamic> json) {
    return TodayParcelActivityResponse(
      status: json['status'],
      data: ParcelBookingData.fromJson(json['data']),
    );
  }

  Map<String, dynamic> toJson() => {"status": status, "data": data.toJson()};
}

class ParcelBookingData {
  final double earning;
  final int completed;
  final int rating;
  final String successRate;
  final List<RecentBooking> recentBookings;
  final WeeklyProgress weeklyProgress; // Added

  ParcelBookingData({
    required this.earning,
    required this.completed,
    required this.rating,
    required this.successRate,
    required this.recentBookings,
    required this.weeklyProgress, // Added
  });

  factory ParcelBookingData.fromJson(Map<String, dynamic> json) {
    return ParcelBookingData(
      earning: (json['earning'] as num?)?.toDouble() ?? 0.0,
      completed: (json['completed'] as num?)?.toInt() ?? 0,
      rating: (json['rating'] as num?)?.toInt() ?? 0,
      successRate: (json['successRate'] ?? '').toString(),
      recentBookings: ((json['recentBookings'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => RecentBooking.fromJson(e.cast<String, dynamic>()))
          .toList(),
      weeklyProgress: WeeklyProgress.fromJson(
        json['weeklyProgress'] ?? {},
      ), // Added
    );
  }

  Map<String, dynamic> toJson() => {
    "earning": earning,
    "completed": completed,
    "rating": rating,
    "successRate": successRate,
    "recentBookings": recentBookings.map((e) => e.toJson()).toList(),
    "weeklyProgress": weeklyProgress.toJson(), // Added
  };
}

class RecentBooking {
  final String customerName;
  final double amount;
  final String status;
  final String statusTime;

  RecentBooking({
    required this.customerName,
    required this.amount,
    required this.status,
    required this.statusTime,
  });

  factory RecentBooking.fromJson(Map<String, dynamic> json) {
    return RecentBooking(
      customerName: (json['customerName'] ?? '').toString(),
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      status: (json['status'] ?? '').toString(),
      statusTime: (json['statusTime'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    "customerName": customerName,
    "amount": amount,
    "status": status,
    "statusTime": statusTime,
  };
}

class WeeklyProgress {
  final int goal;
  final int reward;
  final int totalTrips;
  final double progressPercent;
  final DateTime endsOn;

  WeeklyProgress({
    required this.goal,
    required this.reward,
    required this.totalTrips,
    required this.progressPercent,
    required this.endsOn,
  });

  factory WeeklyProgress.fromJson(Map<String, dynamic> json) {
    return WeeklyProgress(
      goal: (json['goal'] as num?)?.toInt() ?? 0,
      reward: (json['reward'] as num?)?.toInt() ?? 0,
      totalTrips: (json['totalTrips'] as num?)?.toInt() ?? 0,
      progressPercent: (json['progressPercent'] as num?)?.toDouble() ?? 0.0,
      endsOn:
          DateAndTimeConvert.tryParseFlexible((json['endsOn'] ?? '').toString()) ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "goal": goal,
      "reward": reward,
      "totalTrips": totalTrips,
      "progressPercent": progressPercent,
      "endsOn": endsOn.toIso8601String(),
    };
  }
}
