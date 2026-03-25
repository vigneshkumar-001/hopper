import 'package:get/get.dart';
import 'package:hopper/Presentation/DriverScreen/controller/driver_main_controller.dart';
import 'package:hopper/Presentation/DriverScreen/screens/background_service.dart'
    as bg;
import 'package:hopper/utils/sharedprefsHelper/booking_local_data.dart';
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

  // DriverMainController is `permanent: true` in `DriverMainScreen`, so we must
  // explicitly delete it on logout to avoid reusing old car/bike + socket state.
  try {
    if (Get.isRegistered<DriverMainController>()) {
      Get.delete<DriverMainController>(force: true);
    }
  } catch (_) {}
}
