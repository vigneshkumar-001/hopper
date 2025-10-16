import 'package:flutter/material.dart';
import 'package:hopper/Core/Constants/Colors.dart';
import 'package:hopper/Core/Utility/app_loader.dart';
import 'package:hopper/Core/Utility/images.dart';

import '../../Authentication/widgets/textFields.dart';
import '../controller/notification_controller.dart';
import 'package:get/get.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final NotificationController notificationController = Get.put(
    NotificationController(),
  );

  @override
  void initState() {
    super.initState();
    if (notificationController.notificationData.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        notificationController.getNotification();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Image.asset(
                      AppImages.backButton,
                      height: 19,
                      width: 19,
                    ),
                  ),
                  const Spacer(),
                  CustomTextfield.textWithStyles700(
                    'Notification',
                    fontSize: 20,
                  ),
                  const Spacer(),
                ],
              ),
            ),

            Expanded(
              child: Obx(() {
                if (notificationController.isLoading.value) {
                  return Center(child: AppLoader.circularLoader());
                } else if (notificationController.notificationData.isEmpty) {
                  return const Center(child: Text("No Notification found."));
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    return await notificationController.getNotification();
                  },
                  child: ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    itemCount: notificationController.notificationData.length,
                    itemBuilder: (context, index) {
                      final data =
                          notificationController.notificationData[index];
                      final Map<String, String> typeIcons = {
                        "Wallet": AppImages.wallet,
                        "Bike": AppImages.bike,
                        "Car": AppImages.nCar,
                        "Parcel_arrived": AppImages.nPackage,
                        "Cancelled": AppImages.nClose,
                      };

                      final Map<String, Color> typeColors = {
                        "Wallet": AppColors.drkGreen,
                        "Bike": Colors.blue.shade100,
                        "Car": AppColors.circularClr,
                        "Parcel_arrived": AppColors.nPackageColor,
                        "Cancelled": AppColors.timerBorderColor,
                      };

                      final iconPath =
                          typeIcons[data.imageType] ?? AppImages.nCar;
                      final bgColor =
                          typeColors[data.imageType] ??
                          AppColors.rideShareContainerColor;

                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: AppColors.rideShareContainerColor,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: CircleAvatar(
                                      backgroundColor: bgColor.withOpacity(0.1),
                                      child: Image.asset(
                                        iconPath,
                                        height: 16,
                                        color: bgColor,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          data.title,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                          ),
                                        ),
                                        Text(
                                          data.message,
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 5),
                              CustomTextfield.textWithImage(
                                text: data.createdAt,
                                imagePath: AppImages.clock,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}
