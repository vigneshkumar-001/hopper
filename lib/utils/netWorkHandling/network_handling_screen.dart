// widgets/no_internet_overlay.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hopper/Core/Constants/Colors.dart';
import 'package:hopper/Core/Utility/images.dart';
import '../../Presentation/Authentication/controller/network_handling_controller.dart';

class NoInternetOverlay extends StatelessWidget {
  final Widget child;
  const NoInternetOverlay({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final netController = Get.find<NetworkController>();

    return WillPopScope(
      onWillPop: () async {
        return netController.isConnected.value;
      },
      child: Scaffold(
        body: Stack(
          children: [
            child,
            Obx(() {
              return netController.isConnected.value
                  ? const SizedBox()
                  : Positioned.fill(
                    child: Container(
                      color: Colors.white,
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Image.asset(AppImages.no_internet, width: 250),
                          const SizedBox(height: 30),
                          const Text(
                            "Oops! Can’t move forward!",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            "It seems your internet is slow or not working!",
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.black54,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 30),
                          ElevatedButton(
                            onPressed: () async {
                              // Re-check internet
                              await netController.checkConnectionNow();

                              if (netController.isConnected.value) {
                                // Internet back: optionally show success
                                Get.snackbar(
                                  "Online",
                                  "You're back online!",
                                  snackPosition: SnackPosition.TOP,
                                  backgroundColor: Colors.green,
                                  colorText: Colors.white,
                                );
                              } else {
                                // Still offline
                                Get.snackbar(
                                  "Still offline",
                                  "Please check your internet connection.",
                                  snackPosition: SnackPosition.TOP,
                                  backgroundColor: Colors.red,
                                  colorText: Colors.white,
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 30,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text(
                              'Try Again',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
            }),
          ],
        ),
      ),
    );
  }
}
