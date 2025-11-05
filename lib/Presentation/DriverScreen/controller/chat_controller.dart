import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:hopper/api/dataSource/apiDataSource.dart';
import '../models/chat_history_response.dart';

class ChatController extends GetxController {
  final ApiDataSource apiDataSource = ApiDataSource();
  final RxBool isLoading = false.obs;

  /// full messages from API
  final RxList<ChatHistoryMessage> chatMessages = <ChatHistoryMessage>[].obs;

  /// Header bits for DRIVER app (show the **customer**)
  final RxString customerName = ''.obs;
  final RxString customerImage = ''.obs;
  final RxString driverImage = ''.obs;    // full URL or ''
  Future<void> fetchChatHistory({
    required String bookingId,
    required String pickupLongitude,
    required String pickupLatitude,
    required BuildContext context,
  }) async {
    isLoading.value = true;

    try {
      final results = await apiDataSource.chatHistory(
        bookingId: bookingId,
        pickupLatitude: pickupLatitude,   // pass through
        pickupLongitude: pickupLongitude, // pass through
      );

      results.fold(
            (failure) {
          isLoading.value = false;
          Get.snackbar('Error', failure.message);
        },
            (response) {
          isLoading.value = false;

          final data = response.data;
          if (data == null) {
            chatMessages.clear();
            customerName.value = 'Customer';
            customerImage.value = '';
            return;
          }

          // App bar: show customer in driver app
          customerName.value = data.customer?.firstName ?? 'Customer';
          customerImage.value = data.customer?.profileImage ?? '';
          driverImage.value = (response.data?.driver?.profilePic ?? '').trim();

          // timeline (old -> new)
          final items = data.contents;
          items.sort((a, b) {
            final ta = DateTime.tryParse(a.timestamp) ?? DateTime(1970);
            final tb = DateTime.tryParse(b.timestamp) ?? DateTime(1970);
            return ta.compareTo(tb);
          });

          chatMessages
            ..clear()
            ..addAll(items);
        },
      );
    } catch (_) {
      isLoading.value = false;
      Get.snackbar('Error', 'An unexpected error occurred');
    }
  }
}
