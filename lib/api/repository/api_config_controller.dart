import 'package:get/get.dart';
import 'package:hopper/Core/Constants/log.dart';
import 'package:hopper/utils/websocket/socket_io_client.dart';

import '../../utils/sharedprefsHelper/sharedprefs_handler.dart';

class ApiConfigController extends GetxController {
  // Shared ON -> shared backend, Shared OFF -> single backend
  static const String sharedBase = String.fromEnvironment(
    'HOPPR_SHARED_BASE_URL',
    defaultValue: 'https://bck.myhoppr.com/api',
    // defaultValue: 'https://hoppr-share-ride-85bbca49cbeb.herokuapp.com/api',
    // defaultValue: 'https://q29l3cr9-6000.inc1.devtunnels.ms/api',
  );
  static const String singleBase = String.fromEnvironment(
    'HOPPR_SINGLE_BASE_URL',
    defaultValue: 'https://bk.myhoppr.com/api',
    // defaultValue: 'https://hoppr-face-two-dbe557472d7f.herokuapp.com/api',
  );

  static const String sharedSocket = String.fromEnvironment(
    'HOPPR_SHARED_SOCKET_URL',
    defaultValue: 'https://bck.myhoppr.com',
    // defaultValue: 'https://hoppr-share-ride-85bbca49cbeb.herokuapp.com',
    // defaultValue: 'https://q29l3cr9-6000.inc1.devtunnels.ms',
  );
  static const String singleSocket = String.fromEnvironment(
    'HOPPR_SINGLE_SOCKET_URL',
    defaultValue: 'https://bk.myhoppr.com',
    // defaultValue: 'https://hoppr-face-two-dbe557472d7f.herokuapp.com',
  );

  // User PREFERENCE — driven by the "Shared Booking" side-menu toggle. Decides
  // which backend the driver is on while IDLE and which dispatch pools they join.
  final RxBool isSharedEnabled = false.obs;

  // DUAL-CONNECT active-ride backend OVERRIDE. While Shared Booking is ON the
  // driver listens for requests on BOTH backends (shared primary + a single-ride
  // dispatch socket). The moment they ACCEPT a request, that ride's whole
  // lifecycle (accept→arrive→OTP→start→complete) must be bound to the backend
  // that owns the booking, regardless of the toggle. We do that WITHOUT touching
  // the user's `isSharedEnabled` preference (so the toggle UI stays put) by
  // setting this override for the duration of the ride:
  //   null  -> no active ride; use the preference (default — IDENTICAL to old behavior)
  //   true  -> active SHARED ride  -> shared backend
  //   false -> active SINGLE ride  -> single backend
  final Rxn<bool> activeRideBackendShared = Rxn<bool>();

  bool get effectiveShared =>
      activeRideBackendShared.value ?? isSharedEnabled.value;

  String get baseUrl => effectiveShared ? sharedBase : singleBase;
  String get socketUrl => effectiveShared ? sharedSocket : singleSocket;

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

  /// DUAL-CONNECT: bind the active ride to a specific backend for its lifetime.
  /// [shared] true = the accepted ride is a shared ride (stay on bck);
  /// false = a single/"Ride Only" ride accepted via the dual-connect dispatch
  /// socket (switch the PRIMARY socket + all API calls to bk for this ride).
  /// Re-inits the primary socket only when the effective backend actually flips.
  Future<void> bindActiveRideBackend(bool shared) async {
    final wasShared = effectiveShared;
    activeRideBackendShared.value = shared;
    CommonLogger.log.i(
      "[dual-connect] bindActiveRideBackend(shared=$shared) => baseUrl=$baseUrl",
    );
    if (effectiveShared != wasShared) {
      try {
        SocketService().initSocket(socketUrl);
      } catch (_) {}
    }
    update();
  }

  /// DUAL-CONNECT: clear the active-ride binding when the ride ends
  /// (complete / cancel / no-show). Restores the IDLE backend from the user's
  /// `isSharedEnabled` preference and re-points the primary socket if it changed.
  Future<void> clearActiveRideBackend() async {
    if (activeRideBackendShared.value == null) return;
    final wasShared = effectiveShared;
    activeRideBackendShared.value = null;
    CommonLogger.log.i(
      "[dual-connect] clearActiveRideBackend => baseUrl=$baseUrl",
    );
    if (effectiveShared != wasShared) {
      try {
        SocketService().initSocket(socketUrl);
      } catch (_) {}
    }
    update();
  }

  /// Like [setSharedEnabled] but does not touch the socket layer.
  /// Use this during logout / app reset flows.
  Future<void> setSharedEnabledSilently(bool value) async {
    isSharedEnabled.value = value;
    await SharedPrefHelper.instance.setSharedBookingEnabled(value);
    CommonLogger.log.i("BaseUrl switched (silent) => $baseUrl");
    CommonLogger.log.i("SocketUrl switched (silent) => $socketUrl");
    update();
  }
}
