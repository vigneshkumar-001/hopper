class  YearAndColorModels  {
  final int status;
  final Data data;

  YearAndColorModels({
    required this.status,
    required this.data,
  });

  factory YearAndColorModels.fromJson(Map<String, dynamic> json) {
    return YearAndColorModels(
      status: json['status'],
      data: Data.fromJson(json['data']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'status': status,
      'data': data.toJson(),
    };
  }
}

class Data {
  final List<String> colors;
  final List<int> years;

  Data({
    required this.colors,
    required this.years,
  });

  factory Data.fromJson(Map<String, dynamic> json) {
    return Data(
      colors: List<String>.from(json['colors']),
      years: List<int>.from(json['years']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'colors': colors,
      'years': years,
    };
  }
}