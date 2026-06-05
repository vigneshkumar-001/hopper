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
  final double reward;
  final int totalTrips;
  final double progressPercent;
  final String endsOn;
  final String challengeStatus;
  final String headline;
  final String subtext;
  final String badgeText;
  final String highlightTone;
  final String progressText;
  final int remainingTrips;
  final bool rewardCredited;
  final String rewardCreditedAt;
  final double rewardCreditedAmount;
  final String rewardReference;
  final bool challengeActive;
  final bool challengeCompleted;
  final String rewardDisplayAmount;
  final String weekStart;

  WeeklyActivityData({
    required this.goal,
    required this.reward,
    required this.totalTrips,
    required this.progressPercent,
    required this.endsOn,
    required this.challengeStatus,
    required this.headline,
    required this.subtext,
    required this.badgeText,
    required this.highlightTone,
    required this.progressText,
    required this.remainingTrips,
    required this.rewardCredited,
    required this.rewardCreditedAt,
    required this.rewardCreditedAmount,
    required this.rewardReference,
    required this.challengeActive,
    required this.challengeCompleted,
    required this.rewardDisplayAmount,
    required this.weekStart,
  });

  factory WeeklyActivityData.fromJson(Map<String, dynamic> json) {
    return WeeklyActivityData(
      goal: (json['goal'] as num?)?.toInt() ?? 0,
      reward: (json['reward'] as num?)?.toDouble() ?? 0.0,
      totalTrips: (json['totalTrips'] as num?)?.toInt() ?? 0,
      progressPercent: (json['progressPercent'] as num?)?.toDouble() ?? 0.0,
      endsOn: (json['endsOn'] ?? '').toString(),
      challengeStatus: (json['status'] ?? '').toString(),
      headline: (json['headline'] ?? '').toString(),
      subtext: (json['subtext'] ?? '').toString(),
      badgeText: (json['badgeText'] ?? '').toString(),
      highlightTone: (json['highlightTone'] ?? '').toString(),
      progressText: (json['progressText'] ?? '').toString(),
      remainingTrips: (json['remainingTrips'] as num?)?.toInt() ?? 0,
      rewardCredited: json['rewardCredited'] == true,
      rewardCreditedAt: (json['rewardCreditedAt'] ?? '').toString(),
      rewardCreditedAmount:
          (json['rewardCreditedAmount'] as num?)?.toDouble() ?? 0.0,
      rewardReference: (json['rewardReference'] ?? '').toString(),
      challengeActive: json['challengeActive'] == true,
      challengeCompleted: json['challengeCompleted'] == true,
      rewardDisplayAmount: (json['rewardDisplayAmount'] ?? '').toString(),
      weekStart: (json['weekStart'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'goal': goal,
    'reward': reward,
    'totalTrips': totalTrips,
    'progressPercent': progressPercent,
    'endsOn': endsOn,
    'status': challengeStatus,
    'headline': headline,
    'subtext': subtext,
    'badgeText': badgeText,
    'highlightTone': highlightTone,
    'progressText': progressText,
    'remainingTrips': remainingTrips,
    'rewardCredited': rewardCredited,
    'rewardCreditedAt': rewardCreditedAt,
    'rewardCreditedAmount': rewardCreditedAmount,
    'rewardReference': rewardReference,
    'challengeActive': challengeActive,
    'challengeCompleted': challengeCompleted,
    'rewardDisplayAmount': rewardDisplayAmount,
    'weekStart': weekStart,
  };
}
