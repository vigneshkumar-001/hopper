import 'package:get/get.dart';
import 'package:hopper/Core/Constants/log.dart';

import '../../utils/sharedprefsHelper/sharedprefs_handler.dart';

class ApiConfigController extends GetxController {
  // Shared ON -> 3000, Shared OFF -> 4000
  static const String sharedBase =
      'https://q29l3cr9-3000.inc1.devtunnels.ms/api';
  static const String singleBase =
      'https://hoppr-face-two-dbe557472d7f.herokuapp.com/api';
  // 'https://q29l3cr9-4000.inc1.devtunnels.ms/api';
  static const String sharedSocket = 'https://q29l3cr9-3000.inc1.devtunnels.ms';
  static const String singleSocket = 'https://hoppr-face-two-dbe557472d7f.herokuapp.com';
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
    CommonLogger.log.i("🌐 BaseUrl loaded => $baseUrl");
    CommonLogger.log.i("🔌 SocketUrl loaded => $socketUrl");
  }

  Future<void> setSharedEnabled(bool value) async {
    isSharedEnabled.value = value;
    await SharedPrefHelper.instance.setSharedBookingEnabled(value);
    CommonLogger.log.i("🌐 switched => $baseUrl");
    CommonLogger.log.i("🔌 switched => $socketUrl");
    update(); // notify listeners if needed
  }
}
