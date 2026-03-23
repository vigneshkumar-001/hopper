import 'dart:io';

import 'package:get/get.dart';
import 'package:hopper/Core/Constants/log.dart';
import 'package:hopper/api/dataSource/apiDataSource.dart';
import 'package:hopper/Presentation/CustomerSupport/models/customer_support_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CustomerSupportController extends GetxController {
  final ApiDataSource api = ApiDataSource();

  final RxList<CustomerSupportTicket> tickets = <CustomerSupportTicket>[].obs;
  final RxBool isLoading = false.obs;
  final RxString error = ''.obs;
  final RxString lastCreateMessage = ''.obs;

  final Rxn<CustomerSupportCommonDetails> commonDetails =
      Rxn<CustomerSupportCommonDetails>();
  final RxBool isCommonLoading = false.obs;
  final RxString commonError = ''.obs;

  Future<void> loadCommonDetails() async {
    if (isCommonLoading.value) return;
    isCommonLoading.value = true;
    commonError.value = '';
    try {
      final res = await api.getSupportCommonDetails();
      res.fold((failure) {
        commonError.value = failure.message;
        commonDetails.value = null;
      }, (data) {
        commonDetails.value = CustomerSupportCommonDetails.fromJson(data);
      });
    } catch (e, st) {
      CommonLogger.log.e('loadCommonDetails error: $e\n$st');
      commonError.value = e.toString();
      commonDetails.value = null;
    } finally {
      isCommonLoading.value = false;
    }
  }

  Future<void> refreshTickets() async {
    isLoading.value = true;
    error.value = '';
    try {
      final res = await api.getSupportTickets();
      res.fold((failure) {
        error.value = failure.message;
      }, (list) {
        final mapped = list.map(_ticketFromApi).toList(growable: false);
        tickets.assignAll(mapped);
      });
    } catch (e, st) {
      CommonLogger.log.e('refreshTickets error: $e\n$st');
      error.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  CustomerSupportTicket? ticketById(String id) {
    try {
      return tickets.firstWhere((t) => t.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<String?> uploadAttachment(File file) async {
    final res = await api.userProfileUpload(imageFile: file);
    return res.fold((_) => null, (ok) => ok.message);
  }

  Future<CustomerSupportTicket?> createTicket({
    required String subject,
    required String description,
    required String categoryId,
    required String subcategoryId,
    required String priority,
    String? bookingId,
    List<String> attachments = const <String>[],
  }) async {
    isLoading.value = true;
    error.value = '';
    lastCreateMessage.value = '';

    try {
      final res = await api.createSupportTicket(
        categoryId: categoryId,
        subcategoryId: subcategoryId,
        priority: priority,
        subject: subject.trim(),
        detailedDescription: description.trim(),
        attachments: attachments,
      );

      return res.fold((failure) {
        error.value = failure.message;
        return null;
      }, (ticketJson) {
        lastCreateMessage.value =
            (ticketJson['_apiMessage'] ?? '').toString().trim();
        final created = _ticketFromApi(ticketJson);
        final merged = CustomerSupportTicket(
          id: created.id,
          subject: created.subject,
          description: created.description,
          createdAt: created.createdAt,
          status: created.status,
          bookingId:
              (bookingId ?? '').trim().isEmpty ? created.bookingId : bookingId,
          attachments: created.attachments,
          messages: created.messages,
        );
        tickets.insert(0, merged);
        tickets.refresh();
        return merged;
      });
    } catch (e, st) {
      CommonLogger.log.e('createTicket error: $e\n$st');
      error.value = e.toString();
      return null;
    } finally {
      isLoading.value = false;
    }
  }

  void closeTicketLocal(String ticketId) {
    final t = ticketById(ticketId);
    if (t == null) return;
    t.status = CustomerSupportTicketStatus.closed;
    tickets.refresh();
  }

  void sendMessageLocal({
    required String ticketId,
    required String text,
    bool fromCustomer = true,
    String? imageUrl,
  }) {
    final t = ticketById(ticketId);
    if (t == null) return;
    t.messages.add(
      CustomerSupportMessage(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        text: text.trim(),
        createdAt: DateTime.now(),
        fromCustomer: fromCustomer,
        imageUrl: imageUrl,
      ),
    );
    tickets.refresh();
  }

  Future<String> currentCustomerId() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getString('customer_Id') ?? '').trim();
  }

  CustomerSupportTicket _ticketFromApi(Map<String, dynamic> json) {
    final id =
        (json['ticketId'] ?? json['_id'] ?? json['id'] ?? '').toString().trim();
    final subject =
        (json['ticketSubject'] ?? json['subject'] ?? '').toString().trim();
    final desc =
        (json['detailedDescription'] ?? json['description'] ?? '')
            .toString()
            .trim();
    final createdStr = (json['createdAt'] ?? '').toString();
    final createdAt = DateTime.tryParse(createdStr) ?? DateTime.now();

    final statusStr = (json['status'] ?? '').toString().toLowerCase().trim();
    final status =
        statusStr == 'open' || statusStr == 'opened'
            ? CustomerSupportTicketStatus.opened
            : statusStr == 'pending'
                ? CustomerSupportTicketStatus.pending
                : statusStr == 'solved' || statusStr == 'resolved'
                    ? CustomerSupportTicketStatus.solved
                    : statusStr == 'closed'
                        ? CustomerSupportTicketStatus.closed
                        : CustomerSupportTicketStatus.opened;

    final attachmentsRaw = json['attachments'];
    final attachments = (attachmentsRaw is List)
        ? attachmentsRaw.map((e) => e.toString()).toList()
        : <String>[];

    return CustomerSupportTicket(
      id: id.isEmpty ? DateTime.now().millisecondsSinceEpoch.toString() : id,
      subject: subject.isEmpty ? 'Support ticket' : subject,
      description: desc,
      createdAt: createdAt,
      status: status,
      bookingId: (json['bookingId'] ?? '').toString().trim().isEmpty
          ? null
          : (json['bookingId'] ?? '').toString().trim(),
      attachments: attachments,
      messages: <CustomerSupportMessage>[
        if (desc.isNotEmpty)
          CustomerSupportMessage(
            id: 'init',
            text: desc,
            createdAt: createdAt,
            fromCustomer: true,
            imageUrl: attachments.isEmpty ? null : attachments.first,
          ),
      ],
    );
  }
}
