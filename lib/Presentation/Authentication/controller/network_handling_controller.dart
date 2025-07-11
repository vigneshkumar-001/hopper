// controllers/network_controller.dart

import 'dart:async';
import 'package:get/get.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class NetworkController extends GetxController {
  var isConnected = true.obs;
  final Connectivity _connectivity = Connectivity();
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;

  @override
  void onInit() {
    super.onInit();
    _initConnectivity();
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      _updateConnectionStatus,
    );
  }

  /// Initialize connectivity once on startup
  Future<void> _initConnectivity() async {
    final result = await _connectivity.checkConnectivity();
    _updateConnectionStatus(result);
  }

  /// Called whenever connection changes
  void _updateConnectionStatus(List<ConnectivityResult> result) {
    // If any of the connection types is not "none", we're connected
    isConnected.value = result.any(
      (type) =>
          type == ConnectivityResult.mobile ||
          type == ConnectivityResult.wifi ||
          type == ConnectivityResult.ethernet,
    );
  }

  Future<void> checkConnectionNow() async {
    final result = await _connectivity.checkConnectivity();
    _updateConnectionStatus(result);
  }

  @override
  void onClose() {
    _connectivitySubscription.cancel();
    super.onClose();
  }
}
