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

  final RxBool isTicketDetailLoading = false.obs;
  final RxString ticketDetailError = ''.obs;

  Future<void> loadCommonDetails() async {
    if (isCommonLoading.value) return;
    isCommonLoading.value = true;
    commonError.value = '';
    try {
      final res = await api.getSupportCommonDetails();
      res.fold(
        (failure) {
          commonError.value = failure.message;
          commonDetails.value = null;
        },
        (data) {
          commonDetails.value = CustomerSupportCommonDetails.fromJson(data);
        },
      );
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
      res.fold(
        (failure) {
          error.value = failure.message;
        },
        (list) {
          final mapped = list.map(_ticketFromApi).toList(growable: false);
          tickets.assignAll(mapped);
        },
      );
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

      return res.fold(
        (failure) {
          error.value = failure.message;
          return null;
        },
        (ticketJson) {
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
                (bookingId ?? '').trim().isEmpty
                    ? created.bookingId
                    : bookingId,
            attachments: created.attachments,
            messages: created.messages,
          );
          tickets.insert(0, merged);
          tickets.refresh();
          return merged;
        },
      );
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
    List<String> attachments = const <String>[],
    List<String> localFilePaths = const <String>[],
    bool pending = false,
    bool failed = false,
  }) {
    final t = ticketById(ticketId);
    if (t == null) return;
    t.messages.add(
      CustomerSupportMessage(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        text: text.trim(),
        createdAt: DateTime.now(),
        fromCustomer: fromCustomer,
        attachments: attachments,
        localFilePaths: localFilePaths,
        pending: pending,
        failed: failed,
      ),
    );
    tickets.refresh();
  }

  void _replaceMessageById(
    CustomerSupportTicket t,
    String id,
    CustomerSupportMessage next,
  ) {
    final idx = t.messages.indexWhere((m) => m.id == id);
    if (idx < 0) return;
    t.messages[idx] = next;
  }

  void _removeMessageById(CustomerSupportTicket t, String id) {
    t.messages.removeWhere((m) => m.id == id);
  }

  Future<bool> sendTicketMessage({
    required String ticketId,
    required String message,
    List<File> files = const <File>[],
  }) async {
    final t = ticketById(ticketId);
    if (t == null) return false;

    final trimmed = message.trim();
    if (trimmed.isEmpty && files.isEmpty) return false;

    final optimisticId = 'local_${DateTime.now().microsecondsSinceEpoch}';
    final optimistic = CustomerSupportMessage(
      id: optimisticId,
      text: trimmed,
      createdAt: DateTime.now(),
      fromCustomer: true,
      localFilePaths: files.map((f) => f.path).toList(growable: false),
      pending: true,
    );
    t.messages.add(optimistic);
    tickets.refresh();

    // 1) upload attachments
    final urls = <String>[];
    for (final f in files) {
      try {
        final url = await uploadAttachment(f);
        if (url != null && url.trim().isNotEmpty) urls.add(url.trim());
      } catch (_) {}
    }

    // 2) send message
    final res = await api.sendSupportTicketMessage(
      ticketId: ticketId,
      message: trimmed,
      attachments: urls,
    );

    return res.fold(
      (failure) {
        CommonLogger.log.w('sendTicketMessage failed: ${failure.message}');

        _replaceMessageById(
          t,
          optimisticId,
          CustomerSupportMessage(
            id: optimisticId,
            text: trimmed,
            createdAt: optimistic.createdAt,
            fromCustomer: true,
            localFilePaths: optimistic.localFilePaths,
            pending: false,
            failed: true,
          ),
        );
        tickets.refresh();
        return false;
      },
      (payload) {
        final ticket = payload['ticket'];
        final msg = payload['message'];

        // Update ticket status if server returned it
        if (ticket is Map) {
          final statusStr = (ticket['status'] ?? '').toString().toLowerCase();
          if (statusStr == 'closed') {
            t.status = CustomerSupportTicketStatus.closed;
          } else if (statusStr == 'pending') {
            t.status = CustomerSupportTicketStatus.pending;
          } else if (statusStr == 'solved' || statusStr == 'resolved') {
            t.status = CustomerSupportTicketStatus.solved;
          } else if (statusStr == 'open' || statusStr == 'opened') {
            t.status = CustomerSupportTicketStatus.opened;
          }
        }

        if (msg is Map) {
          final id = (msg['_id'] ?? msg['id'] ?? '').toString().trim();
          final text =
              (msg['ticketMessage'] ?? msg['message'] ?? '').toString();
          final files = msg['ticketFiles'];
          final List<String> atts =
              (files is List)
                  ? files.map((e) => e.toString()).toList(growable: false)
                  : const <String>[];
          final dateStr =
              (msg['date'] ?? msg['createdAt'] ?? msg['timestamp'] ?? '')
                  .toString();
          final createdAt = DateTime.tryParse(dateStr) ?? DateTime.now();

          _removeMessageById(t, optimisticId);
          t.messages.add(
            CustomerSupportMessage(
              id:
                  id.isEmpty
                      ? DateTime.now().microsecondsSinceEpoch.toString()
                      : id,
              text: text.trim().isEmpty ? trimmed : text.trim(),
              createdAt: createdAt,
              fromCustomer: true,
              attachments: atts.isEmpty ? urls : atts,
            ),
          );
        } else {
          // fallback if API didn't return message object
          _removeMessageById(t, optimisticId);
          t.messages.add(
            CustomerSupportMessage(
              id: DateTime.now().microsecondsSinceEpoch.toString(),
              text: trimmed,
              createdAt: DateTime.now(),
              fromCustomer: true,
              attachments: urls,
            ),
          );
        }

        tickets.refresh();
        return true;
      },
    );
  }

  Future<String> currentCustomerId() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getString('customer_Id') ?? '').trim();
  }

  Future<String> _currentUserId() async {
    final prefs = await SharedPreferences.getInstance();
    final a = (prefs.getString('driverId') ?? '').trim();
    if (a.isNotEmpty) return a;
    final b = (prefs.getString('userId') ?? '').trim();
    if (b.isNotEmpty) return b;
    return (prefs.getString('customer_Id') ?? '').trim();
  }

  CustomerSupportTicketStatus _statusFromApi(String raw) {
    final statusStr = raw.toLowerCase().trim();
    if (statusStr == 'open' || statusStr == 'opened') {
      return CustomerSupportTicketStatus.opened;
    }
    if (statusStr == 'pending') return CustomerSupportTicketStatus.pending;
    if (statusStr == 'solved' || statusStr == 'resolved') {
      return CustomerSupportTicketStatus.solved;
    }
    if (statusStr == 'closed') return CustomerSupportTicketStatus.closed;
    return CustomerSupportTicketStatus.opened;
  }

  Future<void> loadTicketDetail(String ticketId) async {
    if (isTicketDetailLoading.value) return;
    isTicketDetailLoading.value = true;
    ticketDetailError.value = '';

    try {
      final myId = await _currentUserId();
      final res = await api.getSupportTicketDetail(ticketId: ticketId);
      res.fold(
        (failure) {
          ticketDetailError.value = failure.message;
        },
        (payload) {
          final rawTicket = payload['ticket'];
          final rawMessages = payload['messages'];

          final Map<String, dynamic> tJson =
              rawTicket is Map<String, dynamic>
                  ? rawTicket
                  : (rawTicket is Map
                      ? Map<String, dynamic>.from(rawTicket)
                      : {});

          final subject =
              (tJson['ticketSubject'] ?? tJson['subject'] ?? '')
                  .toString()
                  .trim();
          final desc =
              (tJson['detailedDescription'] ?? tJson['description'] ?? '')
                  .toString()
                  .trim();
          final status = _statusFromApi((tJson['status'] ?? '').toString());
          final createdAt =
              DateTime.tryParse((tJson['createdAt'] ?? '').toString()) ??
              DateTime.now();

          final List<CustomerSupportMessage> msgs = <CustomerSupportMessage>[];
          if (rawMessages is List) {
            for (final e in rawMessages) {
              final Map<String, dynamic> mJson =
                  e is Map<String, dynamic>
                      ? e
                      : (e is Map ? Map<String, dynamic>.from(e) : {});

              final id = (mJson['_id'] ?? mJson['id'] ?? '').toString().trim();
              final text =
                  (mJson['ticketMessage'] ?? mJson['message'] ?? '')
                      .toString()
                      .trim();
              final files = mJson['ticketFiles'] ?? mJson['attachments'];
              final atts =
                  (files is List)
                      ? files.map((x) => x.toString()).toList(growable: false)
                      : <String>[];
              final dateStr =
                  (mJson['date'] ??
                          mJson['createdAt'] ??
                          mJson['timestamp'] ??
                          '')
                      .toString();
              final dt = DateTime.tryParse(dateStr) ?? DateTime.now();
              final sender = (mJson['userId'] ?? '').toString().trim();
              final isMe =
                  myId.isNotEmpty && sender.isNotEmpty && sender == myId;

              msgs.add(
                CustomerSupportMessage(
                  id:
                      id.isEmpty
                          ? DateTime.now().microsecondsSinceEpoch.toString()
                          : id,
                  text: text,
                  createdAt: dt,
                  fromCustomer: isMe,
                  attachments: atts,
                ),
              );
            }
          } else if (desc.isNotEmpty) {
            // fallback if server didn't include messages array
            msgs.add(
              CustomerSupportMessage(
                id: 'init',
                text: desc,
                createdAt: createdAt,
                fromCustomer: true,
                attachments: const <String>[],
              ),
            );
          }

          final existing = ticketById(ticketId);
          if (existing == null) {
            tickets.insert(
              0,
              CustomerSupportTicket(
                id: ticketId,
                subject: subject.isEmpty ? 'Support ticket' : subject,
                description: desc,
                createdAt: createdAt,
                status: status,
                attachments: const <String>[],
                messages: msgs,
              ),
            );
          } else {
            existing.status = status;
            existing.messages
              ..clear()
              ..addAll(msgs);
          }

          tickets.refresh();
        },
      );
    } catch (e, st) {
      CommonLogger.log.e('loadTicketDetail error: $e\n$st');
      ticketDetailError.value = e.toString();
    } finally {
      isTicketDetailLoading.value = false;
    }
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

    final status = _statusFromApi((json['status'] ?? '').toString());

    final attachmentsRaw = json['attachments'];
    final attachments =
        (attachmentsRaw is List)
            ? attachmentsRaw.map((e) => e.toString()).toList()
            : <String>[];

    return CustomerSupportTicket(
      id: id.isEmpty ? DateTime.now().millisecondsSinceEpoch.toString() : id,
      subject: subject.isEmpty ? 'Support ticket' : subject,
      description: desc,
      createdAt: createdAt,
      status: status,
      bookingId:
          (json['bookingId'] ?? '').toString().trim().isEmpty
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
            attachments: attachments,
          ),
      ],
    );
  }
}
