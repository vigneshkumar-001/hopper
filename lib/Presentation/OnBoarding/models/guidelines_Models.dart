// class GuideLinesResponse {
//   final int status;
//   final String message;
//   final GuideLineData data;
//
//   GuideLinesResponse({
//     required this.status,
//     required this.message,
//     required this.data,
//   });
//
//   factory GuideLinesResponse.fromJson(Map<String, dynamic> json) {
//     return GuideLinesResponse(
//       status: json['status'] as int? ?? 0,
//       message: json['message'] as String? ?? '',
//       data: GuideLineData.fromJson(json['data'] as Map<String, dynamic>),
//     );
//   }
//
//   Map<String, dynamic> toJson() => {
//     'status': status,
//     'message': message,
//     'data': data.toJson(),
//   };
// }
//
// class GuideLineData {
//   final String id;
//   final String title;
//   final String image; // ✅ New field added
//   final List<String> requirements;
//   final List<String> thingsToAvoid;
//   final List<Retake> retake;
//
//   GuideLineData({
//     required this.id,
//     required this.title,
//     required this.image,
//     required this.requirements,
//     required this.thingsToAvoid,
//     required this.retake,
//   });
//
//   factory GuideLineData.fromJson(Map<String, dynamic> json) {
//     return GuideLineData(
//       id: json['_id'] as String? ?? '',
//       title: json['title'] as String? ?? '',
//       image: json['image'] as String? ?? '', // ✅ Safely handle image
//       requirements: List<String>.from(json['requirements'] ?? const []),
//       thingsToAvoid: List<String>.from(json['thingstoavoid'] ?? const []),
//       retake: (json['retake'] as List? ?? [])
//           .map((e) => Retake.fromJson(e as Map<String, dynamic>))
//           .toList(),
//     );
//   }
//
//   Map<String, dynamic> toJson() => {
//     '_id': id,
//     'title': title,
//     'image': image, // ✅ Include in toJson
//     'requirements': requirements,
//     'thingstoavoid': thingsToAvoid,
//     'retake': retake.map((e) => e.toJson()).toList(),
//   };
// }
//
// class Retake {
//   final String id;
//   final String description;
//
//   Retake({required this.id, required this.description});
//
//   factory Retake.fromJson(Map<String, dynamic> json) {
//     return Retake(
//       id: json['_id'] as String? ?? '',
//       description: json['description'] as String? ?? '',
//     );
//   }
//
//   Map<String, dynamic> toJson() => {
//     '_id': id,
//     'description': description,
//   };
// }
import 'package:flutter/material.dart';

class GuideLinesResponse {
  final int status;
  final String message;
  final GuideLineData data;

  GuideLinesResponse({
    required this.status,
    required this.message,
    required this.data,
  });

  factory GuideLinesResponse.fromJson(Map<String, dynamic> json) {
    return GuideLinesResponse(
      status: json['status'] as int? ?? 0,
      message: json['message'] as String? ?? '',
      data: GuideLineData.fromJson(json['data'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() => {
    'status': status,
    'message': message,
    'data': data.toJson(),
  };
}

class GuideLineData {
  final String id;
  final String title;
  final String image;
  final List<String> requirements;
  final List<String> thingsToAvoid;
  final List<Retake> retake;

  GuideLineData({
    required this.id,
    required this.title,
    required this.image,
    required this.requirements,
    required this.thingsToAvoid,
    required this.retake,
  });

  factory GuideLineData.fromJson(Map<String, dynamic> json) {
    return GuideLineData(
      id: json['_id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      image: json['image'] as String? ?? '',
      requirements: List<String>.from(json['requirements'] ?? const []),
      thingsToAvoid: List<String>.from(json['thingstoavoid'] ?? const []),
      retake: (json['retake'] as List? ?? [])
          .map((e) {
        if (e is String) {

          return Retake(
            id: UniqueKey().toString(),
            description: e,
          );
        } else if (e is Map<String, dynamic>) {
          return Retake.fromJson(e);
        } else {
          return Retake(id: '', description: '');
        }
      })
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    '_id': id,
    'title': title,
    'image': image,
    'requirements': requirements,
    'thingstoavoid': thingsToAvoid,
    'retake': retake.map((e) => e.toJson()).toList(),
  };
}

class Retake {
  final String id;
  final String description;

  Retake({required this.id, required this.description});

  factory Retake.fromJson(Map<String, dynamic> json) {
    return Retake(
      id: json['_id'] as String? ?? '',
      description: json['description'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    '_id': id,
    'description': description,
  };
}
