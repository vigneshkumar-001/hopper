import 'package:get/get.dart';
import 'package:hopper/Presentation/DriverScreen/controller/driver_main_controller.dart';
import 'package:hopper/Presentation/DriverScreen/controller/driver_status_controller.dart';
import 'package:hopper/Presentation/DriverScreen/screens/background_service.dart'
    as bg;
import 'package:hopper/api/repository/api_config_controller.dart';
import 'package:hopper/utils/sharedprefsHelper/booking_local_data.dart';
import 'package:hopper/utils/sharedprefsHelper/sharedprefs_handler.dart';
import 'package:hopper/utils/websocket/socket_io_client.dart';

Future<void> performLogoutCleanup() async {
  // Stop background tracking first (can continue running after logout otherwise).
  try {
    await bg.stopDriverTrackingService();
  } catch (_) {}

  // Reset base URL selection (shared vs single) so a re-login doesn't reuse
  // shared backend from the previous session.
  try {
    await SharedPrefHelper.instance.setSharedBookingEnabled(false);
  } catch (_) {}
  try {
    if (Get.isRegistered<ApiConfigController>()) {
      await Get.find<ApiConfigController>().setSharedEnabled(false);
      Get.delete<ApiConfigController>(force: true);
    }
  } catch (_) {}

  // Clear any in-memory booking cache (prevents stale ride UI after re-login).
  try {
    BookingDataService().clear();
  } catch (_) {}

  // Fully reset socket singleton so next login always re-registers cleanly.
  try {
    SocketService().dispose();
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
