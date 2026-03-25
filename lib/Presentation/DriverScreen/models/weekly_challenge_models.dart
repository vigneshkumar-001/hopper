class WeeklyChallengeModels {
  final int status;
  final WeeklyActivityData data;

  WeeklyChallengeModels({required this.status, required this.data});

  factory WeeklyChallengeModels.fromJson(Map<String, dynamic> json) {
    return WeeklyChallengeModels(
      status: json['status'],
      data: WeeklyActivityData.fromJson(json['data']),
    );
  }

  Map<String, dynamic> toJson() => {'status': status, 'data': data.toJson()};
}

class WeeklyActivityData {
  final int goal;
  final int reward;
  final int totalTrips;
  final int progressPercent;
  final String endsOn;

  WeeklyActivityData({
    required this.goal,
    required this.reward,
    required this.totalTrips,
    required this.progressPercent,
    required this.endsOn,
  });

  factory WeeklyActivityData.fromJson(Map<String, dynamic> json) {
    print("📦 Parsing  : $json");
    return WeeklyActivityData(
      goal: (json['goal'] as num?)?.toInt() ?? 0,
      reward: (json['reward'] as num?)?.toInt() ?? 0,
      totalTrips: (json['totalTrips'] as num?)?.toInt() ?? 0,
      progressPercent: (json['progressPercent'] as num?)?.toInt() ?? 0,
      endsOn: (json['endsOn'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'goal': goal,
    'reward': reward,
    'totalTrips': totalTrips,
    'progressPercent': progressPercent,
    'endsOn': endsOn,
  };
}
