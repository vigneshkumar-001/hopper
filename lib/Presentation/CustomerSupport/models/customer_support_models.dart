import 'package:flutter/material.dart';

enum CustomerSupportTicketStatus { opened, pending, solved, closed }

extension CustomerSupportTicketStatusX on CustomerSupportTicketStatus {
  String get label {
    switch (this) {
      case CustomerSupportTicketStatus.opened:
        return 'Opened';
      case CustomerSupportTicketStatus.pending:
        return 'Pending';
      case CustomerSupportTicketStatus.solved:
        return 'Solved';
      case CustomerSupportTicketStatus.closed:
        return 'Closed';
    }
  }

  Color get accent {
    switch (this) {
      case CustomerSupportTicketStatus.opened:
        return const Color(0xFF2F80ED);
      case CustomerSupportTicketStatus.pending:
        return const Color(0xFFF2994A);
      case CustomerSupportTicketStatus.solved:
        return const Color(0xFF27AE60);
      case CustomerSupportTicketStatus.closed:
        return const Color(0xFF667085);
    }
  }

  IconData get icon {
    switch (this) {
      case CustomerSupportTicketStatus.opened:
        return Icons.hourglass_bottom_rounded;
      case CustomerSupportTicketStatus.pending:
        return Icons.access_time_rounded;
      case CustomerSupportTicketStatus.solved:
        return Icons.check_circle_rounded;
      case CustomerSupportTicketStatus.closed:
        return Icons.cancel_rounded;
    }
  }
}

class CustomerSupportMessage {
  final String id;
  final String text;
  final DateTime createdAt;
  final bool fromCustomer;
  final List<String> attachments;
  final List<String> localFilePaths;
  final bool pending;
  final bool failed;

  CustomerSupportMessage({
    required this.id,
    required this.text,
    required this.createdAt,
    required this.fromCustomer,
    this.attachments = const <String>[],
    this.localFilePaths = const <String>[],
    this.pending = false,
    this.failed = false,
  });

  String? get imageUrl => attachments.isEmpty ? null : attachments.first;
}

class CustomerSupportTicket {
  final String id;
  final String subject;
  final String description;
  final DateTime createdAt;
  CustomerSupportTicketStatus status;
  final String? bookingId;
  final List<CustomerSupportMessage> messages;
  final List<String> attachments;

  CustomerSupportTicket({
    required this.id,
    required this.subject,
    required this.description,
    required this.createdAt,
    required this.status,
    this.bookingId,
    this.attachments = const <String>[],
    List<CustomerSupportMessage>? messages,
  }) : messages = messages ?? <CustomerSupportMessage>[];
}

class CustomerSupportSubcategory {
  const CustomerSupportSubcategory({required this.id, required this.label});

  final String id;
  final String label;

  factory CustomerSupportSubcategory.fromJson(Map<String, dynamic> json) {
    return CustomerSupportSubcategory(
      id: (json['id'] ?? '').toString().trim(),
      label: (json['label'] ?? '').toString().trim(),
    );
  }
}

class CustomerSupportCategory {
  const CustomerSupportCategory({
    required this.id,
    required this.label,
    required this.subcategories,
  });

  final String id;
  final String label;
  final List<CustomerSupportSubcategory> subcategories;

  factory CustomerSupportCategory.fromJson(Map<String, dynamic> json) {
    final rawSubs = json['subcategories'];
    final subs =
        (rawSubs is List)
            ? rawSubs
                .whereType<Map>()
                .map(
                  (e) => CustomerSupportSubcategory.fromJson(
                    Map<String, dynamic>.from(e as Map),
                  ),
                )
                .toList(growable: false)
            : <CustomerSupportSubcategory>[];

    return CustomerSupportCategory(
      id: (json['id'] ?? '').toString().trim(),
      label: (json['label'] ?? '').toString().trim(),
      subcategories: subs,
    );
  }
}

class CustomerSupportPriority {
  const CustomerSupportPriority({required this.id, required this.label});

  final String id;
  final String label;

  factory CustomerSupportPriority.fromJson(Map<String, dynamic> json) {
    return CustomerSupportPriority(
      id: (json['id'] ?? '').toString().trim(),
      label: (json['label'] ?? '').toString().trim(),
    );
  }
}

class CustomerSupportCommonDetails {
  const CustomerSupportCommonDetails({
    required this.categories,
    required this.priorities,
  });

  final List<CustomerSupportCategory> categories;
  final List<CustomerSupportPriority> priorities;

  factory CustomerSupportCommonDetails.fromJson(Map<String, dynamic> json) {
    final rawCats = json['categories'];
    final cats =
        (rawCats is List)
            ? rawCats
                .whereType<Map>()
                .map(
                  (e) => CustomerSupportCategory.fromJson(
                    Map<String, dynamic>.from(e as Map),
                  ),
                )
                .toList(growable: false)
            : <CustomerSupportCategory>[];

    final rawPri = json['priorities'];
    final pris =
        (rawPri is List)
            ? rawPri
                .whereType<Map>()
                .map(
                  (e) => CustomerSupportPriority.fromJson(
                    Map<String, dynamic>.from(e as Map),
                  ),
                )
                .toList(growable: false)
            : <CustomerSupportPriority>[];

    return CustomerSupportCommonDetails(categories: cats, priorities: pris);
  }
}
