import 'package:get/get.dart';
import 'package:hopper/Presentation/DriverScreen/controller/driver_main_controller.dart';
import 'package:hopper/Presentation/DriverScreen/controller/driver_status_controller.dart';
import 'package:hopper/Presentation/DriverScreen/screens/background_service.dart'
    as bg;
import 'package:hopper/api/repository/api_config_controller.dart';
import 'package:hopper/Presentation/DriverScreen/screens/SharedBooking/Controller/booking_request_controller.dart';
import 'package:hopper/Presentation/DriverScreen/screens/SharedBooking/Controller/shared_ride_controller.dart';
import 'package:hopper/utils/sharedprefsHelper/booking_local_data.dart';
import 'package:hopper/utils/sharedprefsHelper/sharedprefs_handler.dart';
import 'package:hopper/utils/websocket/socket_io_client.dart';

Future<void> performLogoutCleanup() async {
  // Stop background tracking first (can continue running after logout otherwise).
  try {
    await bg.stopDriverTrackingService();
  } catch (_) {}

  // Clear any in-memory booking cache (prevents stale ride UI after re-login).
  try {
    BookingDataService().clear();
  } catch (_) {}

  // Fully reset socket singleton so next login always re-registers cleanly.
  try {
    SocketService().dispose();
  } catch (_) {}

  // Reset base URL selection (shared vs single) without re-connecting sockets.
  try {
    await SharedPrefHelper.instance.setSharedBookingEnabled(false);
  } catch (_) {}
  try {
    if (Get.isRegistered<ApiConfigController>()) {
      await Get.find<ApiConfigController>().setSharedEnabledSilently(false);
    }
  } catch (_) {}

  // Clear any visible booking request popup state.
  try {
    if (Get.isRegistered<BookingRequestController>()) {
      Get.find<BookingRequestController>().clear();
    }
  } catch (_) {}

  // Clear shared ride state (if any) so re-login starts clean.
  try {
    if (Get.isRegistered<SharedRideController>()) {
      final s = Get.find<SharedRideController>();
      s.riders.clear();
      s.activeTarget.value = null;
      s.driverLocation.value = null;
      s.canArriveAtActivePickup.value = false;
      s.canCompleteActiveDrop.value = false;
    }
  } catch (_) {}

  // Reset status controller (permanent) so UI doesn't keep stale Car/Bike.
  try {
    if (Get.isRegistered<DriverStatusController>()) {
      Get.find<DriverStatusController>().resetForLogout();
    }
  } catch (_) {}

  // DriverMainController is `permanent: true` in `DriverMainScreen`, so we must
  // explicitly delete it on logout to avoid reusing old car/bike + socket state.
  try {
    if (Get.isRegistered<DriverMainController>()) {
      Get.delete<DriverMainController>(force: true);
    }
  } catch (_) {}
}
