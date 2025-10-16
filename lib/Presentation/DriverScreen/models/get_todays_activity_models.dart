class GetTodayActivityModels {
  final int status;
  final TodayActivityData data;

  GetTodayActivityModels({required this.status, required this.data});

  factory GetTodayActivityModels.fromJson(Map<String, dynamic> json) {
    return GetTodayActivityModels(
      status: json['status'],
      data: TodayActivityData.fromJson(json['data']),
    );
  }

  Map<String, dynamic> toJson() => {'status': status, 'data': data.toJson()};
}

class TodayActivityData {
  final String earnings;
  final String online;
  final String rides;

  TodayActivityData({
    required this.earnings,
    required this.online,
    required this.rides,
  });

  factory TodayActivityData.fromJson(Map<String, dynamic> json) {
    print("📦 Parsing TodayActivityData: $json");
    return TodayActivityData(
      earnings: json['earnings'] ?? '0',
      online: json['online'] ?? '0',
      rides: json['rides'] ?? "0",
    );
  }

  Map<String, dynamic> toJson() => {
    'earnings': earnings,
    'online': online,
    'rides': rides,
  };
}
