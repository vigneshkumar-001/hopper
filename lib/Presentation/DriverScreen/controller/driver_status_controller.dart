import 'package:flutter/material.dart';
import 'dart:async';

import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:hopper/Core/Constants/log.dart';
import 'package:hopper/Presentation/DriverScreen/controller/driver_main_controller.dart';
import 'package:hopper/Presentation/DriverScreen/models/today_parcel_activity_response.dart';
import 'package:hopper/Presentation/DriverScreen/models/weekly_challenge_models.dart';
import 'package:hopper/api/dataSource/apiDataSource.dart';
import 'package:hopper/api/repository/api_config_controller.dart';
import 'package:hopper/Presentation/Drawer/controller/notification_controller.dart';
import 'package:hopper/utils/websocket/socket_io_client.dart';
import 'package:hopper/utils/map/navigation_assist.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../Core/Utility/snackbar.dart';
import 'package:hopper/Presentation/DriverScreen/models/booking_accept_model.dart';
import 'package:hopper/Presentation/DriverScreen/models/get_todays_activity_models.dart';
import '../screens/SharedBooking/Screens/picking_shared_screens.dart';
import '../screens/driver_main_screen.dart';
import '../screens/picking_customer_screen.dart';

class DriverStatusController extends GetxController {
  var isOnline = false.obs;
  RxBool isLoading = false.obs;
  final RxBool isToggleLoading = false.obs;
  // ---- Server-authoritative online status ----
  // True while a tap is awaiting the server's confirmation (push or ack).
  final RxBool isTogglePending = false.obs;
  // 'inactivity-auto-offline' when the server auto-flips us offline, so the UI
  // can explain why the toggle changed. Cleared once back online.
  final RxString autoOfflineReason = ''.obs;
  Timer? _toggleConfirmTimer;
  String? _statusDriverId;
  final RxBool isBookingAcceptLoading = false.obs;
  final RxBool isBookingRejectLoading = false.obs;
  var serviceType = ''.obs;
  final RxBool isStopNewRequests = false.obs;
  final RxString arrivedLoadingBookingId = ''.obs;
  final socketService = SocketService();
  Rxn<TodayActivityData> todayStatusData = Rxn<TodayActivityData>();
  Rxn<WeeklyActivityData> weeklyStatusData = Rxn<WeeklyActivityData>();
  Rxn<ParcelBookingData> parcelBookingData = Rxn<ParcelBookingData>();
  ApiDataSource apiDataSource = ApiDataSource();
  final ApiConfigController cfg =
      Get.isRegistered<ApiConfigController>()
          ? Get.find<ApiConfigController>()
          : Get.put(ApiConfigController(), permanent: true);

  final tripDistanceInMeters = 0.0.obs;
  final tripDurationInMin = 0.obs;

  final RxString paymentType = ''.obs;
  final RxString paymentStatus = ''.obs;

  final pickupDurationInMin = 0.0.obs;
  final pickupDistanceInMeters = 0.0.obs;
  var dropDurationInMin = 0.0.obs;
  var dropDistanceInMeters = 0.0.obs;

  // Last time we received a `driver-location` socket update (for UI "Updated at").
  final Rxn<DateTime> lastDriverLocationAt = Rxn<DateTime>();

  static const String _kServiceTypePrefKey = 'driver_service_type';

  void setLastDriverLocationAtFrom(dynamic raw) {
    if (raw == null) return;
    DateTime? parsed;
    try {
      if (raw is DateTime) {
        parsed = raw;
      } else if (raw is int) {
        // Epoch ms is most common; fall back to seconds if too small.
        parsed =
            raw > 100000000000
                ? DateTime.fromMillisecondsSinceEpoch(raw)
                : DateTime.fromMillisecondsSinceEpoch(raw * 1000);
      } else if (raw is num) {
        final v = raw.toInt();
        parsed =
            v > 100000000000
                ? DateTime.fromMillisecondsSinceEpoch(v)
                : DateTime.fromMillisecondsSinceEpoch(v * 1000);
      } else {
        parsed = DateTime.tryParse(raw.toString());
      }
    } catch (_) {
      parsed = null;
    }

    if (parsed == null) return;
    final next = parsed.toLocal();
    final prev = lastDriverLocationAt.value;
    if (prev == null || next.isAfter(prev)) {
      lastDriverLocationAt.value = next;
    }
  }

  String get lastDriverLocationLabel {
    final dt = lastDriverLocationAt.value;
    if (dt == null) return '';
    String two(int n) => n.toString().padLeft(2, '0');
    final h = two(dt.hour);
    final m = two(dt.minute);
    return 'Updated $h:$m';
  }

  @override
  void onInit() {
    super.onInit();
    // Seed serviceType early so UI doesn't briefly show the wrong vehicle icon
    // before the first server `getDriverStatus` response arrives.
    unawaited(_loadPersistedServiceType());
    todayActivity();
    weeklyChallenges();
    todayPackageActivity();
  }

  String get normalizedServiceType => serviceType.value.trim();
  bool get hasServiceType => normalizedServiceType.isNotEmpty;
  bool get isCar => normalizedServiceType.toLowerCase() == 'car';
  bool get isBike => normalizedServiceType.toLowerCase() == 'bike';

  String _normalizeServiceType(dynamic raw) {
    final v = (raw ?? '').toString().trim();
    if (v.isEmpty) return '';
    final lower = v.toLowerCase();
    if (lower == 'car') return 'Car';
    if (lower == 'bike') return 'Bike';
    return v;
  }

  void setServiceTypeFrom(dynamic raw) {
    final next = _normalizeServiceType(raw);
    if (next.isEmpty) return;
    serviceType.value = next;
    // Force notify even if value is the same (helps after logout/login where
    // widgets/controllers can be rebuilt but serviceType remains unchanged).
    serviceType.refresh();
    unawaited(_persistServiceType(next));
  }

  Future<void> _loadPersistedServiceType() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final v = prefs.getString(_kServiceTypePrefKey) ?? '';
      if (v.trim().isNotEmpty && serviceType.value.trim().isEmpty) {
        setServiceTypeFrom(v);
      }
    } catch (_) {
      // ignore
    }
  }

  Future<void> _persistServiceType(String next) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kServiceTypePrefKey, next);
    } catch (_) {
      // ignore
    }
  }

  /// Clears user-scoped state so UI doesn't show stale Car/Bike after logout.
  void resetForLogout() {
    unbindOnlineStatusListener();
    isOnline.value = false;
    isToggleLoading.value = false;
    isLoading.value = false;
    isBookingAcceptLoading.value = false;
    isBookingRejectLoading.value = false;
    isStopNewRequests.value = false;
    arrivedLoadingBookingId.value = '';

    serviceType.value = '';
    serviceType.refresh();
    unawaited(
      SharedPreferences.getInstance().then(
        (p) => p.remove(_kServiceTypePrefKey),
      ),
    );
  }

  void toggleStatus() {
    isOnline.value = !isOnline.value;
  }

  // ---- Server-authoritative online status -----------------------------------
  // The backend is the source of truth. A push event `driver-online-status`
  // fires whenever the server changes our status (toggle from another device,
  // inactivity auto-offline, admin disable); `get-online-status` pulls it on
  // connect / resume / reconnect. Both funnel through [applyServerOnlineStatus].

  /// Register the push listener ONCE. SocketService keeps a single handler per
  /// event, so calling this on every (re)connect / rebind never duplicates.
  void bindOnlineStatusListener() {
    socketService.on('driver-online-status', (data) {
      final map = _coerceStatusMap(data);
      if (map == null) return;
      final online = _readBoolFlexible(map['onlineStatus']);
      if (online == null) return;
      applyServerOnlineStatus(online, reason: map['reason']?.toString());
    });
  }

  /// Stop listening + clear pending (call on logout).
  void unbindOnlineStatusListener() {
    _toggleConfirmTimer?.cancel();
    isTogglePending.value = false;
    autoOfflineReason.value = '';
    try {
      socketService.off('driver-online-status');
    } catch (_) {}
  }

  /// Pull the authoritative status. The server replies via ack AND re-emits
  /// `driver-online-status`; both apply idempotently.
  void requestOnlineStatus({String? driverId}) {
    if (driverId != null && driverId.trim().isNotEmpty) {
      _statusDriverId = driverId.trim();
    }
    final did = _statusDriverId;
    socketService.emitWithAck('get-online-status', {
      if (did != null) 'driverId': did,
    }, (resp) {
      final map = _coerceStatusMap(resp);
      if (map == null) return;
      // Missing `success` is treated as success (some servers omit it on ack).
      final ok = map['success'] == null || map['success'] == true;
      if (!ok) return;
      final online = _readBoolFlexible(map['onlineStatus']);
      if (online != null) applyServerOnlineStatus(online);
    });
  }

  /// THE source of truth — apply the server's status to the UI, clear any
  /// pending tap, and surface the inactivity reason for a banner.
  void applyServerOnlineStatus(bool online, {String? reason}) {
    _toggleConfirmTimer?.cancel();
    isTogglePending.value = false;
    isOnline.value = online;
    final r = (reason ?? '').trim().toLowerCase();
    autoOfflineReason.value =
        (!online && r == 'inactivity-auto-offline')
            ? 'inactivity-auto-offline'
            : '';
  }

  /// Mark the user's tap as pending until the server confirms (push or ack).
  /// If nothing confirms in time, reconcile with the server's truth.
  void markTogglePending() {
    isTogglePending.value = true;
    _toggleConfirmTimer?.cancel();
    _toggleConfirmTimer = Timer(const Duration(seconds: 7), () {
      isTogglePending.value = false;
      requestOnlineStatus();
    });
  }

  bool? _readBoolFlexible(dynamic v) {
    if (v is bool) return v;
    if (v is num) return v != 0;
    final s = v?.toString().trim().toLowerCase();
    if (s == 'true' || s == '1') return true;
    if (s == 'false' || s == '0') return false;
    return null;
  }

  Map<String, dynamic>? _coerceStatusMap(dynamic data) {
    if (data is Map) return Map<String, dynamic>.from(data);
    if (data is List && data.isNotEmpty && data.first is Map) {
      return Map<String, dynamic>.from(data.first as Map);
    }
    return null;
  }

  // ðŸ”¹ booking accept
  Future<String?> bookingAccept(
    BuildContext context, {
    required String bookingId,
    required String status,
    required String pickupLocationAddress,
    required String dropLocationAddress,
    required LatLng pickupLocation,
    required LatLng driverLocation,
    bool navigateToPickup = true,
  }) async {
    isBookingAcceptLoading.value = true;
    try {
      final results = await apiDataSource.bookingAccept(
        bookingId: bookingId,
        status: status,
      );

      return results.fold(
        (failure) {
          CustomSnackBar.showError(failure.message);
          isBookingAcceptLoading.value = false;
          return '';
        },
        (response) {
          Get.find<DriverAnalyticsController>().trackAccept();
          final serverBookingId = response.data?.bookingId;
          final resolvedBookingId =
              serverBookingId != null &&
                      serverBookingId.trim().isNotEmpty &&
                      serverBookingId.trim().toLowerCase() != 'null'
                  ? serverBookingId
                  : bookingId;
          final bookingData = {
            'bookingId': resolvedBookingId,
            'userId': response.data?.driverId,
            'userType': 'driver',
          };

          CommonLogger.log.i("ðŸ“¤ Join booking data: $bookingData");

          // IMPORTANT: When we navigate to PickingCustomerScreen, its controller
          // (PickingCustomerController) registers the 'joined-booking' listener
          // FIRST and only THEN emits join-booking. If we ALSO emit here, the
          // controller's emit lands inside the backend's 2s duplicate-join window
          // (socket.ts) and is suppressed -> the server sends NO 'joined-booking'
          // reply to the socket whose listener is ready. This premature emit's
          // own reply usually arrives before the (heavy) map screen finishes
          // building its listener, so it is missed too. The net effect was a
          // blank customer (no name/phone -> dead call button) and no pickup
          // distance/ETA. So only join from here when we are NOT navigating to
          // the pickup screen (then no controller exists to join the room).
          if (!navigateToPickup) {
            if (socketService.connected) {
              socketService.emit('join-booking', bookingData);
              CommonLogger.log.i(
                "âœ… Socket already connected, emitted join-booking",
              );
            } else {
              socketService.onConnect(() {
                CommonLogger.log.i("âœ… Socket connected, emitting join-booking");
                socketService.emit('join-booking', bookingData);
              });
            }
          }

          CommonLogger.log.i(response.data);

          if (navigateToPickup) {
            if (resolvedBookingId.trim().isEmpty ||
                resolvedBookingId.trim().toLowerCase() == 'null') {
              CustomSnackBar.showError('Booking id missing. Please retry.');
              isBookingAcceptLoading.value = false;
              return '';
            }
            Get.to(
              () => PickingCustomerScreen(
                pickupLocation: pickupLocation,
                driverLocation: driverLocation,
                bookingId: resolvedBookingId,
                pickupLocationAddress: pickupLocationAddress,
                dropLocationAddress: dropLocationAddress,
              ),
            );
            // Get.to(
            //   () => PickingCustomerSharedScreen(
            //     pickupLocation: pickupLocation,
            //     driverLocation: driverLocation,
            //     bookingId: bookingId,
            //     pickupLocationAddress: pickupLocationAddress,
            //     dropLocationAddress: dropLocationAddress,
            //   ),
            // );
          } else {
            CommonLogger.log.i(
              "ðŸš— [SHARED] bookingAccept called with navigateToPickup = false â†’ staying on current screen",
            );
          }

          isBookingAcceptLoading.value = false;
          return ' ';
        },
      );
    } catch (e) {
      isBookingAcceptLoading.value = false;
      return ' ';
    }
  }

  // ðŸ”¹ booking accept
  Future<String?> bookingAcceptForSharedRide(
    BuildContext context, {
    required String bookingId,
    required String status,
    required String pickupLocationAddress,
    required String dropLocationAddress,
    required LatLng pickupLocation,
    required LatLng driverLocation,
    bool navigateToPickup = true,
  }) async {
    isBookingAcceptLoading.value = true;
    try {
      final results = await apiDataSource.bookingAccept(
        bookingId: bookingId,
        status: status,
      );

      return results.fold(
        (failure) {
          CustomSnackBar.showError(failure.message);
          isBookingAcceptLoading.value = false;
          return '';
        },
        (response) {
          Get.find<DriverAnalyticsController>().trackAccept();
          final serverBookingId = response.data?.bookingId;
          final resolvedBookingId =
              serverBookingId != null &&
                      serverBookingId.trim().isNotEmpty &&
                      serverBookingId.trim().toLowerCase() != 'null'
                  ? serverBookingId
                  : bookingId;
          final bookingData = {
            'bookingId': resolvedBookingId,
            'userId': response.data?.driverId,
            'userType': 'driver',
          };

          CommonLogger.log.i("ðŸ“¤ Join booking data: $bookingData");

          if (socketService.connected) {
            socketService.emit('join-booking', bookingData);
            CommonLogger.log.i(
              "âœ… Socket already connected, emitted join-booking",
            );
          } else {
            socketService.onConnect(() {
              CommonLogger.log.i("âœ… Socket connected, emitting join-booking");
              socketService.emit('join-booking', bookingData);
            });
          }

          CommonLogger.log.i(response.data);

          if (navigateToPickup) {
            if (resolvedBookingId.trim().isEmpty ||
                resolvedBookingId.trim().toLowerCase() == 'null') {
              CustomSnackBar.showError('Booking id missing. Please retry.');
              isBookingAcceptLoading.value = false;
              return '';
            }
            Get.to(
              () => PickingCustomerSharedScreen(
                pickupLocation: pickupLocation,
                driverLocation: driverLocation,
                bookingId: resolvedBookingId,
                pickupLocationAddress: pickupLocationAddress,
                dropLocationAddress: dropLocationAddress,
              ),
            );
          } else {
            CommonLogger.log.i(
              "ðŸš— [SHARED] bookingAccept called with navigateToPickup = false â†’ staying on current screen",
            );
          }

          isBookingAcceptLoading.value = false;
          return ' ';
        },
      );
    } catch (e) {
      isBookingAcceptLoading.value = false;
      return ' ';
    }
  }

  Future<String?> otpRequest(
    BuildContext context, {
    required String bookingId,
    required String custName,
    required String pickupAddress,
    required String dropAddress,
  }) async {
    isLoading.value = true;
    try {
      final results = await apiDataSource.otpRequest(bookingId: bookingId);

      return results.fold(
        (failure) {
          isLoading.value = false;
          CustomSnackBar.showError(failure.message);
          return null;
        },
        (response) {
          isLoading.value = false;
          CustomSnackBar.showSuccess(response.message);
          CommonLogger.log.i(response.message);
          return response.message;
        },
      );
    } catch (e) {
      isLoading.value = false;
      return null;
    }
  }

  // ðŸ”¹ complete ride â€“ used for single ride & shared
  /*
  Future<String?> completeRideRequest(
      BuildContext context, {
        required String bookingId,
        required dynamic Amount,
        bool navigateToCashScreen = true,
        bool isSharedRide = false,
      }) async
  {
    isLoading.value = true;
    try {
      final results = await apiDataSource.completeRideRequest(
        bookingId: bookingId,
      );

      String? resultMessage;

      results.fold(
            (failure) {
          isLoading.value = false;
          CustomSnackBar.showError(failure.message);
          resultMessage = null;
        },
            (response) {
          isLoading.value = false;
          CommonLogger.log.i(response.message);

          if (navigateToCashScreen) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CashCollectedScreen(
                  Amount: Amount,
                  bookingId: bookingId,
                  isSharedRide: isSharedRide,
                ),
              ),
            );
          }

          resultMessage = response.message;
        },
      );

      return resultMessage;
    } catch (e) {
      isLoading.value = false;
      return 'Something went wrong';
    }
  }
*/

  Future<({bool success, String message})> otpInsert(
    BuildContext context, {
    required String bookingId,
    required String otp,
  }) async {
    isLoading.value = true;

    try {
      final results = await apiDataSource.otpInsert(
        bookingId: bookingId,
        enteredOtp: otp,
      );

      return results.fold(
        (failure) {
          isLoading.value = false;
          return (success: false, message: failure.message);
        },
        (response) {
          isLoading.value = false;
          CommonLogger.log.i(response.message);
          return (success: true, message: response.message);
        },
      );
    } catch (_) {
      isLoading.value = false;
      return (success: false, message: 'Something went wrong');
    }
  }

  /// Driver-initiated "Resend OTP to rider" (Ride/Parcel). Deliberately does NOT
  /// toggle [isLoading] — it's a lightweight button action, not a full-screen
  /// load. Cooldown / max-attempt enforcement is server-side.
  Future<({bool success, String message})> resendRideOtp({
    required String bookingId,
  }) async {
    try {
      final results =
          await apiDataSource.resendRideOtpRequest(bookingId: bookingId);
      return results.fold(
        (failure) => (success: false, message: failure.message),
        (data) => (
          success: true,
          message: (data['message'] ?? 'OTP resent to rider').toString(),
        ),
      );
    } catch (_) {
      return (success: false, message: 'Something went wrong');
    }
  }

  Future<String?> bookingReject({required String bookingId}) async {
    isBookingRejectLoading.value = true;
    try {
      final results = await apiDataSource.bookingAccept(
        bookingId: bookingId,
        status: 'REJECT',
      );

      return results.fold(
        (failure) {
          CustomSnackBar.showError(failure.message);
          isBookingRejectLoading.value = false;
          return '';
        },
        (response) {
          CommonLogger.log.i(
            '🚫 Booking rejected for bookingId=$bookingId response=${response.message}',
          );
          isBookingRejectLoading.value = false;
          return 'success';
        },
      );
    } catch (e) {
      isBookingRejectLoading.value = false;
      CommonLogger.log.e('bookingReject failed: $e');
      return '';
    }
  }

  Future<BookingAcceptModel?> driverArrived(
    BuildContext context, {
    required String bookingId,
  }) async {
    arrivedLoadingBookingId.value = bookingId;

    try {
      final results = await apiDataSource.driverArrived(bookingId: bookingId);

      return results.fold(
        (failure) {
          arrivedLoadingBookingId.value = '';
          return null;
        },
        (response) {
          arrivedLoadingBookingId.value = '';
          final onTime = pickupDurationInMin.value <= 2.0;
          Get.find<DriverAnalyticsController>().trackPickup(onTime: onTime);
          return response;
        },
      );
    } catch (e) {
      arrivedLoadingBookingId.value = '';
      return null;
    }
  }

  Future<String?> onlineAcceptStatus(
    BuildContext context, {
    required bool status,
    required double latitude,
    required double longitude,
  }) async {
    isLoading.value = true;
    try {
      final results = await apiDataSource.driverOnlineStatus(
        latitude: latitude,
        longitude: longitude,
        onlineStatus: status,
      );
      return results.fold(
        (failure) {
          isLoading.value = false;
          CustomSnackBar.showError(failure.message);
          return '';
        },
        (response) {
          CommonLogger.log.i(response.data);
          isLoading.value = false;
          CustomSnackBar.showDriverStatus(
            isOnline: status,
            message: response.message,
          );
          return ' ';
        },
      );
    } catch (e) {
      isLoading.value = false;
      return ' ';
    }
  }

  Future<String?> todayActivity() async {
    try {
      final results = await apiDataSource.todayActivity();
      CommonLogger.log.i("API called. Awaiting result...");

      return results.fold(
        (failure) {
          return null;
        },
        (response) {
          CommonLogger.log.i("Success block entered");
          CommonLogger.log.i("Response: ${response.toJson()}");

          todayStatusData.value = response.data;
          CommonLogger.log.i("Assigned to todayStatusData:");
          CommonLogger.log.i(todayStatusData.value.toString());
          return response.toString();
        },
      );
    } catch (e) {
      return ' ';
    }
  }

  Future<void> weeklyChallenges() async {
    try {
      final results = await apiDataSource.weeklyChallenge();
      CommonLogger.log.i("API called. Awaiting result...");

      results.fold(
        (failure) {
          CommonLogger.log.e(" weekly Data : ${failure.message}");
          return null;
        },
        (response) {
          CommonLogger.log.i("Response: ${response.toJson()}");

          weeklyStatusData.value = response.data;
          CommonLogger.log.i("Assigned to weekly status:");
          CommonLogger.log.i(weeklyStatusData.value.toString());
          return response;
        },
      );
    } catch (e) {
      return;
    }
  }

  Future<String?> todayPackageActivity() async {
    try {
      final results = await apiDataSource.todayPackageActivity();
      CommonLogger.log.i("API called. Awaiting result...");

      results.fold(
        (failure) {
          CommonLogger.log.e(" weekly Data : ${failure.message}");
          return null;
        },
        (response) {
          CommonLogger.log.i("Response: ${response.toJson()}");

          parcelBookingData.value = response.data;
          CommonLogger.log.i("Assigned to weekly status:");
          CommonLogger.log.i(weeklyStatusData.value.toString());
          return response;
        },
      );
    } catch (e) {
      return ' ';
    }

    return '';
  }

  /// Cancel ALL active shared-ride passengers for this driver in one server call.
  /// Returns the success message (non-null) on success, or null on failure so the
  /// caller can decide whether to navigate home.
  Future<String?> cancelAllSharedRides(
    BuildContext context, {
    required String reason,
    String? sharedId,
  }) async {
    String? successMsg;

    try {
      isLoading.value = true;

      final results = await apiDataSource.cancelSharedAll(
        reason: reason,
        sharedId: sharedId,
      );

      results.fold(
        (failure) {
          successMsg = null;
          CommonLogger.log.e(
            "cancelAllSharedRides failure: ${failure.message}",
          );
        },
        (message) {
          successMsg = message;
          CommonLogger.log.i("cancelAllSharedRides success: $message");
          // CLEANUP: clear the active booking id so location stops emitting the
          // stale bookingId after cancel-all (driver continues as idle, no bookingId).
          try {
            if (Get.isRegistered<DriverMainController>()) {
              Get.find<DriverMainController>().clearAfterSharedCancelAll();
            }
          } catch (_) {}
        },
      );
    } catch (e) {
      CommonLogger.log.e("cancelAllSharedRides exception: $e");
      successMsg = null;
    } finally {
      isLoading.value = false;
    }

    return successMsg;
  }

  Future<String?> cancelBooking(
    BuildContext context, {
    required String reason,
    required String bookingId,
    bool silent = true,
    bool navigate = true,
  }) async {
    String? msg;

    try {
      isLoading.value = true;

      final results = await apiDataSource.cancelBooking(
        reason: reason,
        bookingId: bookingId,
      );

      results.fold(
        (failure) {
          msg = failure.message;
          CommonLogger.log.e("cancelBooking failure: ${failure.message}");
        },
        (response) {
          msg = response.message;
          CommonLogger.log.i("cancelBooking success: ${response.message}");
          Get.find<DriverAnalyticsController>().trackCancel(
            bookingId: bookingId,
          );
        },
      );
    } catch (e) {
      CommonLogger.log.e("cancelBooking exception: $e");
      msg = "Something went wrong";
    } finally {
      isLoading.value = false;
    }

    // show snackbar only if needed
    if (!silent && (msg ?? '').isNotEmpty) {
      CustomSnackBar.showSuccess(msg!);
    }

    if (navigate) {
      try {
        if (Get.isBottomSheetOpen == true) {
          Get.back();
        } else if (Get.isDialogOpen == true) {
          Get.back();
        }
      } catch (_) {}

      Future.delayed(const Duration(milliseconds: 80), () {
        Get.offAll(() => const DriverMainScreen());
      });
    }

    return msg;
  }

  bool _sharedCancelInFlight = false;

  /// Shared-ride PER-PASSENGER cancel. Unlike [cancelBooking] this NEVER
  /// navigates — it returns the backend's decision so the SCREEN decides whether
  /// to stay (passengers remain) or go Home (`shouldNavigateHome`). Guards
  /// against double-taps. Single-ride cancellation still uses [cancelBooking].
  Future<({bool success, bool shouldNavigateHome, int remaining, String message})>
      cancelSharedPassenger({
    required String reason,
    required String bookingId,
  }) async {
    if (_sharedCancelInFlight) {
      return (
        success: false,
        shouldNavigateHome: false,
        remaining: -1,
        message: 'Please wait…',
      );
    }
    _sharedCancelInFlight = true;
    isLoading.value = true;
    try {
      final results = await apiDataSource.cancelSharedPassenger(
        reason: reason,
        bookingId: bookingId,
      );
      return results.fold(
        (failure) => (
          success: false,
          shouldNavigateHome: false,
          remaining: -1,
          message: failure.message,
        ),
        (data) {
          try {
            Get.find<DriverAnalyticsController>()
                .trackCancel(bookingId: bookingId);
          } catch (_) {}
          final remaining = (data['remainingActivePassengers'] is num)
              ? (data['remainingActivePassengers'] as num).toInt()
              : 0;
          final goHome = data['shouldNavigateHome'] == true;
          final msg = (data['message'] ?? 'Passenger cancelled').toString();
          return (
            success: true,
            shouldNavigateHome: goHome,
            remaining: remaining,
            message: msg,
          );
        },
      );
    } catch (e) {
      CommonLogger.log.e("cancelSharedPassenger exception: $e");
      return (
        success: false,
        shouldNavigateHome: false,
        remaining: -1,
        message: 'Something went wrong',
      );
    } finally {
      _sharedCancelInFlight = false;
      isLoading.value = false;
    }
  }

  /*
  Future<String?> cancelBooking(
    BuildContext context, {
    required String reason,
    required String bookingId,
    bool silent = true, // âœ… default true (avoid ticker crash)
    bool navigate = true, // âœ… default true
  }) async
  {
    try {
      isLoading.value = true;

      final results = await apiDataSource.cancelBooking(
        reason: reason,
        bookingId: bookingId,
      );

      String? msg;

      results.fold(
        (failure) {
          msg = failure.message;
          CommonLogger.log.e("failure: ${failure.message}");
        },
        (response) {
          msg = response.message;
          CommonLogger.log.i("Response: ${response.message}");
        },
      );

      isLoading.value = false;

      // âœ… show snackbar only if NOT navigating away
      if (!silent && !navigate && (msg ?? '').isNotEmpty) {
        CustomSnackBar.showSuccess(msg!);
      }

      if (navigate) {
        // âœ… close overlays safely
        try {
          Get.closeAllSnackbars();
        } catch (e) {
          CommonLogger.log.w(e);
        }
        try {
          if (Get.isBottomSheetOpen == true) Get.back();
        } catch (e) {CommonLogger.log.w(e);}
        try {
          if (Get.isDialogOpen == true) Get.back();
        } catch (e) {
          CommonLogger.log.w(e);
        }

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (Get.currentRoute == '/DriverMainScreen') return;
          Get.offAll(() => const DriverMainScreen());
        });
      }

      return msg;
    } catch (e) {
      isLoading.value = false;
      return '';
    }
  }
*/

  Future<String?> stopNewRideRequest({
    required bool stop,
    required BuildContext context,
  }) async {
    try {
      isLoading.value = true;

      final results = await apiDataSource.stopNewRideRequest(stop: stop);

      return results.fold(
        (failure) {
          isLoading.value = false;
          CustomSnackBar.showError(failure.message);
          CommonLogger.log.e("failure: ${failure.message}");
          return '';
        },
        (response) {
          CommonLogger.log.i("Response: ${response.message}");
          CustomSnackBar.showSuccess(response.message);

          if (response.stop == true) {
            isStopNewRequests.value = true;
          }

          CommonLogger.log.i("stop flag: ${response.stop}");
          isLoading.value = false;
          return '';
        },
      );
    } catch (e) {
      isLoading.value = false;
      return '';
    }
  }

  Future<void> getDriverStatus() async {
    try {
      final results = await apiDataSource.getDriverStatus();

      results.fold(
        (failure) {
          CommonLogger.log.e("failure: ${failure.message}");
          return '';
        },
        (response) {
          CommonLogger.log.i("Response: ${response.data}");

          isOnline.value = response.data.onlineStatus;
          serviceType.value = _normalizeServiceType(response.data.serviceType);
          // Ensure any listening UIs (marker/header) update even if the server
          // returns the same serviceType value as before.
          serviceType.refresh();
          unawaited(_persistServiceType(serviceType.value));

          // ✅ Server is source of truth for shared booking; switch base+socket.
          final shared = response.data.sharedBooking;
          if (cfg.isSharedEnabled.value != shared) {
            unawaited(cfg.setSharedEnabled(shared));
          }
          if (Get.isRegistered<NotificationController>()) {
            final n = Get.find<NotificationController>();
            if (!n.isSharedToggleLoading.value) {
              n.isSharedEnabled.value = shared;
            }
          }
          CommonLogger.log.i(isOnline.value);
        },
      );
    } catch (e) {
      CommonLogger.log.i(e);
    }
  }

  Future<void> getAmountStatus({required String bookingId}) async {
    try {
      final results = await apiDataSource.getAmountStatus(bookingId: bookingId);

      results.fold(
        (failure) {
          CommonLogger.log.e("failure: ${failure.message}");
        },
        (response) {
          CommonLogger.log.i("Response: ${response.data}");
          paymentType.value = response.data.paymentType;
          paymentStatus.value = response.data.paymentStatus;
        },
      );
    } catch (e) {
      CommonLogger.log.i(e);
    }
  }

  Future<void> amountCollectedStatus({
    required String booking,
    VoidCallback? onSuccess,
  }) async {
    isLoading.value = true;
    try {
      final results = await apiDataSource.amountCollectedStatus(
        bookingId: booking,
      );

      results.fold(
        (failure) {
          CustomSnackBar.showError(failure.message);
          isLoading.value = false;
          CommonLogger.log.e("failure: ${failure.message}");
        },
        (response) {
          isLoading.value = false;
          CommonLogger.log.i(response.toJson());
          paymentStatus.value = 'PAID';

          if (onSuccess != null) onSuccess();
        },
      );
    } catch (e) {
      isLoading.value = false;
      CommonLogger.log.i(e);
    }
  }

  /// Driver picks the next shared-ride stop. API-first: the backend validates +
  /// saves + emits. Returns the success message, or null if the backend rejected
  /// the stop (the reason is surfaced to the driver via a snackbar).
  Future<String?> selectNextStop({
    required String bookingId,
    required String stopType, // 'pickup' | 'drop'
  }) async {
    final res = await apiDataSource.selectSharedNextStop(
      bookingId: bookingId,
      stopType: stopType,
    );
    return res.fold(
      (failure) {
        CustomSnackBar.showError(failure.message);
        return null;
      },
      (msg) => msg,
    );
  }

  Future<String?> completeRideRequest(
    BuildContext context, {
    required String bookingId,
    required dynamic Amount,
    bool navigateToCashScreen = true,
    bool isSharedRide = false,
  }) async {
    isLoading.value = true;
    try {
      final results = await apiDataSource.completeRideRequest(
        bookingId: bookingId,
      );

      String? resultMessage;

      results.fold(
        (failure) {
          isLoading.value = false;
          CustomSnackBar.showError(failure.message);
          resultMessage = null;
        },
        (response) {
          isLoading.value = false;
          resultMessage = response.message;
          Get.find<DriverAnalyticsController>().trackEarning(Amount ?? 0);
          Get.find<DriverAnalyticsController>().trackComplete();

          // âœ… Shared ride -> DON'T navigate from controller
          if (isSharedRide) return;

          // âœ… Single ride -> go to cash screen if needed
          // if (navigateToCashScreen) {
          //   Navigator.push(
          //     context,
          //     MaterialPageRoute(
          //       builder:
          //           (_) => CashCollectedScreen(
          //             Amount: Amount,
          //             bookingId: bookingId,
          //             isSharedRide: false,
          //           ),
          //     ),
          //   );
          // }
        },
      );

      return resultMessage;
    } catch (e) {
      isLoading.value = false;
      return 'Something went wrong';
    }
  }

  Future<void> driverRatingToCustomer({
    required String bookingId,
    required int rating,
    required BuildContext context,
    bool goToMainOnSuccess = true,
  }) async {
    isLoading.value = true;
    try {
      final results = await apiDataSource.driverRating(
        bookingId: bookingId,
        rating: rating,
      );

      results.fold(
        (failure) {
          isLoading.value = false;
          CommonLogger.log.e("failure: ${failure.message}");
        },
        (response) {
          isLoading.value = false;

          if (goToMainOnSuccess) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => DriverMainScreen()),
              (route) => false,
            );
          }

          CommonLogger.log.i(response.toJson());
        },
      );
    } catch (e) {
      isLoading.value = false;
      CommonLogger.log.i(e);
    }
  }
}
