import 'dart:async';
import 'package:get/get.dart';
import 'package:hopper/utils/map/navigation_assist.dart';

class BookingRequestController extends GetxController {
  static const int requestPopupSeconds = 25;
  // null => no popup
  final Rxn<Map<String, dynamic>> bookingRequestData =
  Rxn<Map<String, dynamic>>();

  final RxInt remainingSeconds = 0.obs;
  Timer? _timer;

  // 🆕 keep track of last handled booking (accepted/declined/expired)
  final RxnString lastHandledBookingId = RxnString();

  // Prevent double-popups from quick duplicate socket events.
  String? _lastShownBookingId;
  DateTime _lastShownAt = DateTime.fromMillisecondsSinceEpoch(0);
  static const Duration _duplicateShowWindow = Duration(seconds: 2);

  void showRequest({
    required Map<String, dynamic> rawData,
    required String pickupAddress,
    required String dropAddress,
    int? remainingSeconds,
  }) {
    final data = Map<String, dynamic>.from(rawData);
    data['pickupAddress'] = pickupAddress;
    data['dropAddress'] = dropAddress;

    final incomingId = data['bookingId']?.toString();

    // 🛑 ignore if this booking was already handled
    if (incomingId != null && incomingId == lastHandledBookingId.value) {
      return;
    }

    final now = DateTime.now();
    if (incomingId != null &&
        incomingId == _lastShownBookingId &&
        now.difference(_lastShownAt) < _duplicateShowWindow) {
      return;
    }

    bookingRequestData.value = data;
    _lastShownBookingId = incomingId;
    _lastShownAt = now;
    Get.find<DriverAnalyticsController>().trackOffer();
    _startTimer(_normalizedCountdown(remainingSeconds));
  }

  int _normalizedCountdown(int? seconds) {
    final value = seconds ?? requestPopupSeconds;
    if (value <= 0) return requestPopupSeconds;
    return value > requestPopupSeconds ? requestPopupSeconds : value;
  }

  void _startTimer(int seconds) {
    _timer?.cancel();
    remainingSeconds.value = seconds;

    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (remainingSeconds.value > 0) {
        remainingSeconds.value--;
      } else {
        t.cancel();
        // On expiry, just close the popup.
        // Do NOT mark as handled; backend may re-dispatch the same bookingId.
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

  // 🆕 call this when user ACCEPTS or DECLINES
  void markHandled(String bookingId) {
    lastHandledBookingId.value = bookingId;
    clear();
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


// import 'dart:async';
// import 'package:get/get.dart';
//
// class BookingRequestController extends GetxController {
//   // null => no popup
//   final Rxn<Map<String, dynamic>> bookingRequestData =
//       Rxn<Map<String, dynamic>>();
//
//   final RxInt remainingSeconds = 0.obs;
//   Timer? _timer;
//   final RxnString lastHandledBookingId = RxnString();
//   void showRequest({
//     required Map<String, dynamic> rawData,
//     required String pickupAddress,
//     required String dropAddress,
//   }) {
//     final data = Map<String, dynamic>.from(rawData);
//     data['pickupAddress'] = pickupAddress;
//     data['dropAddress'] = dropAddress;
//
//     bookingRequestData.value = data;
//     _startTimer(15);
//   }
//
//   void _startTimer(int seconds) {
//     _timer?.cancel();
//     remainingSeconds.value = seconds;
//
//     _timer = Timer.periodic(const Duration(seconds: 1), (t) {
//       if (remainingSeconds.value > 0) {
//         remainingSeconds.value--;
//       } else {
//         t.cancel();
//         clear();
//       }
//     });
//   }
//
//   void clear() {
//     bookingRequestData.value = null;
//
//     remainingSeconds.value = 0;
//     _timer?.cancel();
//     _timer = null;
//   }
//   void markHandled(String bookingId) {
//     lastHandledBookingId.value = bookingId;
//     clear();
//   }
//
//   String formatCountdown() {
//     final s = remainingSeconds.value;
//     if (s <= 0) return '00';
//     if (s < 10) return '0$s';
//     return '$s';
//   }
//
//   @override
//   void onClose() {
//     _timer?.cancel();
//     super.onClose();
//   }
// }
