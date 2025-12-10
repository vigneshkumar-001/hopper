import 'dart:async';
import 'package:get/get.dart';

class BookingRequestController extends GetxController {
  // null => no popup
  final Rxn<Map<String, dynamic>> bookingRequestData =
      Rxn<Map<String, dynamic>>();

  final RxInt remainingSeconds = 0.obs;
  Timer? _timer;

  void showRequest({
    required Map<String, dynamic> rawData,
    required String pickupAddress,
    required String dropAddress,
  }) {
    final data = Map<String, dynamic>.from(rawData);
    data['pickupAddress'] = pickupAddress;
    data['dropAddress'] = dropAddress;

    bookingRequestData.value = data;
    _startTimer(15);
  }

  void _startTimer(int seconds) {
    _timer?.cancel();
    remainingSeconds.value = seconds;

    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (remainingSeconds.value > 0) {
        remainingSeconds.value--;
      } else {
        t.cancel();
        clear();
      }
    });
  }

  void clear() {
    bookingRequestData.value = null;

    remainingSeconds.value = 0;
    _timer?.cancel();
    _timer = null;
  }

  String formatCountdown() {
    final s = remainingSeconds.value;
    if (s <= 0) return '00';
    if (s < 10) return '0$s';
    return '$s';
  }

  @override
  void onClose() {
    _timer?.cancel();
    super.onClose();
  }
}
