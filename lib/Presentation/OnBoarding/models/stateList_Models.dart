class StateListModels {
  final int status;
  final List<String> data;

  StateListModels({required this.status, required this.data});

  factory StateListModels.fromJson(Map<String, dynamic> json) {
    return StateListModels(
      status: json['status'] ?? 0,
      data: List<String>.from(json['data'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {'status': status, 'data': data};
  }
}



