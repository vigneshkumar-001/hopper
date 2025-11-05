// lib/Presentation/OnBoarding/models/chat_history_response.dart
class ChatHistoryResponse {
  final bool success;
  final ChatData? data;

  ChatHistoryResponse({required this.success, this.data});

  factory ChatHistoryResponse.fromJson(Map<String, dynamic> json) {
    return ChatHistoryResponse(
      success: json['success'] ?? false,
      data: json['data'] != null ? ChatData.fromJson(json['data']) : null,
    );
  }
}

class ChatData {
  final String bookingId;
  final String senderId;
  final String senderType;
  final String timestamp;
  final List<ChatHistoryMessage> contents;
  final String pickup;
  final String drop;
  final String carType;
  final String bookingType;
  final String weight;
  final Driver? driver;
  final Customer? customer;

  ChatData({
    required this.bookingId,
    required this.senderId,
    required this.senderType,
    required this.timestamp,
    required this.contents,
    required this.pickup,
    required this.drop,
    required this.carType,
    required this.bookingType,
    required this.weight,
    this.driver,
    this.customer,
  });

  factory ChatData.fromJson(Map<String, dynamic> json) {
    return ChatData(
      bookingId: json['bookingId'] ?? '',
      senderId: json['senderId'] ?? '',
      senderType: json['senderType'] ?? '',
      timestamp: json['timestamp'] ?? '',
      contents: (json['contents'] as List? ?? [])
          .map((e) => ChatHistoryMessage.fromJson(e))
          .toList(),
      pickup: json['pickup'] ?? '',
      drop: json['drop'] ?? '',
      carType: json['carType'] ?? '',
      bookingType: json['bookingType'] ?? '',
      weight: json['weight'] ?? '',
      driver: json['driver'] != null ? Driver.fromJson(json['driver']) : null,
      customer: json['customer'] != null ? Customer.fromJson(json['customer']) : null,
    );
  }
}

class ChatHistoryMessage {
  final String id;
  final String bookingId;
  final String senderId;
  final String senderType;
  final List<ChatContent> contents;
  final String timestamp;
  final String side;
  final String senderName;
  final String senderImage;

  ChatHistoryMessage({
    required this.id,
    required this.bookingId,
    required this.senderId,
    required this.senderType,
    required this.contents,
    required this.timestamp,
    required this.side,
    required this.senderName,
    required this.senderImage,
  });

  factory ChatHistoryMessage.fromJson(Map<String, dynamic> json) {
    return ChatHistoryMessage(
      id: json['_id'] ?? '',
      bookingId: json['bookingId'] ?? '',
      senderId: json['senderId'] ?? '',
      senderType: json['senderType'] ?? '',
      contents: (json['contents'] as List? ?? [])
          .map((e) => ChatContent.fromJson(e))
          .toList(),
      timestamp: json['timestamp'] ?? '',
      side: json['side'] ?? 'left',
      senderName: json['senderName'] ?? '',
      senderImage: json['senderImage'] ?? '',
    );
  }
}

class ChatContent {
  final String type;
  final String value;

  ChatContent({required this.type, required this.value});

  factory ChatContent.fromJson(Map<String, dynamic> json) {
    return ChatContent(
      type: json['type'] ?? '',
      value: json['value'] ?? '',
    );
  }
}

class Driver {
  final String id;
  final String firstName;
  final String profilePic;
  final bool online;
  final String? currentLatitude;
  final String? currentLongitude;

  Driver({
    required this.id,
    required this.firstName,
    required this.profilePic,
    required this.online,
    this.currentLatitude,
    this.currentLongitude,
  });

  factory Driver.fromJson(Map<String, dynamic> json) {
    return Driver(
      id: json['_id'] ?? '',
      firstName: json['firstName'] ?? '',
      profilePic: json['profilePic'] ?? '',
      online: json['online'] ?? false,
      currentLatitude: json['currentLatitude'],
      currentLongitude: json['currentLongitude'],
    );
  }
}

class Customer {
  final String id;
  final String firstName;
  final String profileImage;
  final bool online;

  Customer({
    required this.id,
    required this.firstName,
    required this.profileImage,
    required this.online,
  });

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      id: json['_id'] ?? '',
      firstName: json['firstName'] ?? '',
      profileImage: json['profileImage'] ?? '',
      online: json['online'] ?? false,
    );
  }
}
