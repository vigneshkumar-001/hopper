import 'package:get/get.dart';
import 'package:hopper/Core/Constants/log.dart';
import 'package:hopper/utils/websocket/socket_io_client.dart';

import '../../utils/sharedprefsHelper/sharedprefs_handler.dart';

class ApiConfigController extends GetxController {
  // Shared ON -> shared backend, Shared OFF -> single backend
  static const String sharedBase = String.fromEnvironment(
    'HOPPR_SHARED_BASE_URL',
    defaultValue: 'https://hoppr-share-ride-85bbca49cbeb.herokuapp.com/api',
        // defaultValue: 'https://q29l3cr9-6000.inc1.devtunnels.ms/api',
  );
  static const String singleBase = String.fromEnvironment(
    'HOPPR_SINGLE_BASE_URL',
    defaultValue: 'https://hoppr-face-two-dbe557472d7f.herokuapp.com/api',
  );

  static const String sharedSocket = String.fromEnvironment(
    'HOPPR_SHARED_SOCKET_URL',

    defaultValue: 'https://hoppr-share-ride-85bbca49cbeb.herokuapp.com',
    // defaultValue: 'https://q29l3cr9-6000.inc1.devtunnels.ms',
  );
  static const String singleSocket = String.fromEnvironment(
    'HOPPR_SINGLE_SOCKET_URL',
    defaultValue: 'https://hoppr-face-two-dbe557472d7f.herokuapp.com',
  );

  final RxBool isSharedEnabled = false.obs;

  String get baseUrl => isSharedEnabled.value ? sharedBase : singleBase;
  String get socketUrl => isSharedEnabled.value ? sharedSocket : singleSocket;

  @override
  void onInit() {
    super.onInit();
    _load();
  }

  Future<void> _load() async {
    final v = await SharedPrefHelper.instance.getSharedBookingEnabled();
    isSharedEnabled.value = v;
    CommonLogger.log.i("BaseUrl loaded => $baseUrl");
    CommonLogger.log.i("SocketUrl loaded => $socketUrl");
  }

  Future<void> setSharedEnabled(bool value) async {
    isSharedEnabled.value = value;
    await SharedPrefHelper.instance.setSharedBookingEnabled(value);
    CommonLogger.log.i("BaseUrl switched => $baseUrl");
    CommonLogger.log.i("SocketUrl switched => $socketUrl");

    // Ensure the socket singleton actually switches to the new URL immediately.
    // Without this, background timers (heartbeat/updateLocation) may continue
    // emitting to the old backend until some screen re-initializes the socket.
    try {
      SocketService().initSocket(socketUrl);
    } catch (_) {}
    update();
  }
}
