import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hopper/Core/Constants/Colors.dart';
import 'package:hopper/Core/Utility/app_loader.dart';
import 'package:hopper/Core/Utility/images.dart';

import '../../Authentication/widgets/textFields.dart';
import '../controller/notification_controller.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final NotificationController notificationController = Get.put(
    NotificationController(),
  );
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollController.addListener(_scrollListener);

      if (notificationController.notificationData.isEmpty) {
        notificationController.getNotification();
      }
    });
  }

  // ------------------ PAGINATION LISTENER ------------------
  void _scrollListener() {
    if (!notificationController.hasMore.value ||
        notificationController.isMoreLoading.value)
      return;

    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      notificationController.getNotification();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // ------------------ HEADER ------------------
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

            // ------------------ LIST ------------------
            Expanded(
              child: Obx(() {
                if (notificationController.isLoading.value) {
                  return Center(child: AppLoader.circularLoader());
                }

                if (notificationController.notificationData.isEmpty) {
                  return const Center(child: Text("No Notification found."));
                }

                return RefreshIndicator(
                  onRefresh:
                      () => notificationController.getNotification(
                        isRefresh: true,
                      ),
                  child: ListView.builder(
                    controller: _scrollController,
                    physics: const BouncingScrollPhysics(),

                    // IMPORTANT: +1 for loader at bottom
                    itemCount:
                        notificationController.notificationData.length +
                        (notificationController.isMoreLoading.value ? 1 : 0),

                    itemBuilder: (context, index) {
                      // SHOW PAGINATION LOADING ROW
                      if (index ==
                          notificationController.notificationData.length) {
                        return Padding(
                          padding: const EdgeInsets.all(16),
                          child: Center(child: AppLoader.circularLoader()),
                        );
                      }

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
                                  CircleAvatar(
                                    backgroundColor: bgColor.withOpacity(0.1),
                                    child: Image.asset(
                                      iconPath,
                                      height: 16,
                                      color: bgColor,
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

// import 'package:flutter/material.dart';
// import 'package:hopper/Core/Constants/Colors.dart';
// import 'package:hopper/Core/Utility/app_loader.dart';
// import 'package:hopper/Core/Utility/images.dart';
//
// import '../../Authentication/widgets/textFields.dart';
// import '../controller/notification_controller.dart';
// import 'package:get/get.dart';
//
// class NotificationScreen extends StatefulWidget {
//   const NotificationScreen({super.key});
//
//   @override
//   State<NotificationScreen> createState() => _NotificationScreenState();
// }
//
// class _NotificationScreenState extends State<NotificationScreen> {
//   final NotificationController notificationController = Get.put(
//     NotificationController(),
//   );
//   final ScrollController _scrollController = ScrollController();
//   @override
//   void initState() {
//     super.initState();
//     if (notificationController.notificationData.isEmpty) {
//       WidgetsBinding.instance.addPostFrameCallback((_) {
//         notificationController.getNotification();
//         _paginationListener();
//       });
//     }
//   }
//
//   void _paginationListener() {
//     final triggerOffset = 200;
//
//     if (!notificationController.isMoreLoading.value &&
//         _scrollController.position.pixels >
//             _scrollController.position.maxScrollExtent - triggerOffset) {
//       notificationController.getNotification();
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: SafeArea(
//         child: Column(
//           children: [
//             Padding(
//               padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
//               child: Row(
//                 children: [
//                   GestureDetector(
//                     onTap: () => Navigator.pop(context),
//                     child: Image.asset(
//                       AppImages.backButton,
//                       height: 19,
//                       width: 19,
//                     ),
//                   ),
//                   const Spacer(),
//                   CustomTextfield.textWithStyles700(
//                     'Notification',
//                     fontSize: 20,
//                   ),
//                   const Spacer(),
//                 ],
//               ),
//             ),
//
//             Expanded(
//               child: Obx(() {
//                 if (notificationController.isLoading.value) {
//                   return Center(child: AppLoader.circularLoader());
//                 } else if (notificationController.notificationData.isEmpty) {
//                   return const Center(child: Text("No Notification found."));
//                 }
//
//                 return RefreshIndicator(
//                   onRefresh: () async {
//                     return await notificationController.getNotification(isRefresh: true);
//                   },
//                   child: ListView.builder(
//                     controller: _scrollController,
//                     physics: const BouncingScrollPhysics(),
//                     itemCount: notificationController.notificationData.length,
//                     itemBuilder: (context, index) {
//                       if (index ==
//                           notificationController.notificationData.length) {
//                         return Obx(
//                           () =>
//                               notificationController.isMoreLoading.value
//                                   ? Padding(
//                                     padding: EdgeInsets.all(16),
//                                     child: Center(
//                                       child: AppLoader.circularLoader(),
//                                     ),
//                                   )
//                                   : const SizedBox(),
//                         );
//                       }
//
//                       final data =
//                           notificationController.notificationData[index];
//                       final Map<String, String> typeIcons = {
//                         "Wallet": AppImages.wallet,
//                         "Bike": AppImages.bike,
//                         "Car": AppImages.nCar,
//                         "Parcel_arrived": AppImages.nPackage,
//                         "Cancelled": AppImages.nClose,
//                       };
//
//                       final Map<String, Color> typeColors = {
//                         "Wallet": AppColors.drkGreen,
//                         "Bike": Colors.blue.shade100,
//                         "Car": AppColors.circularClr,
//                         "Parcel_arrived": AppColors.nPackageColor,
//                         "Cancelled": AppColors.timerBorderColor,
//                       };
//
//                       final iconPath =
//                           typeIcons[data.imageType] ?? AppImages.nCar;
//                       final bgColor =
//                           typeColors[data.imageType] ??
//                           AppColors.rideShareContainerColor;
//
//                       return Padding(
//                         padding: const EdgeInsets.symmetric(
//                           horizontal: 10,
//                           vertical: 5,
//                         ),
//                         child: Container(
//                           padding: const EdgeInsets.all(12),
//                           decoration: BoxDecoration(
//                             border: Border.all(
//                               color: AppColors.rideShareContainerColor,
//                             ),
//                             borderRadius: BorderRadius.circular(12),
//                           ),
//                           child: Column(
//                             crossAxisAlignment: CrossAxisAlignment.start,
//                             children: [
//                               Row(
//                                 children: [
//                                   Padding(
//                                     padding: const EdgeInsets.only(bottom: 12),
//                                     child: CircleAvatar(
//                                       backgroundColor: bgColor.withOpacity(0.1),
//                                       child: Image.asset(
//                                         iconPath,
//                                         height: 16,
//                                         color: bgColor,
//                                       ),
//                                     ),
//                                   ),
//                                   const SizedBox(width: 10),
//                                   Expanded(
//                                     child: Column(
//                                       crossAxisAlignment:
//                                           CrossAxisAlignment.start,
//                                       children: [
//                                         Text(
//                                           data.title,
//                                           style: const TextStyle(
//                                             fontWeight: FontWeight.w600,
//                                             fontSize: 14,
//                                           ),
//                                         ),
//                                         Text(
//                                           data.message,
//                                           style: TextStyle(
//                                             color: Colors.grey.shade600,
//                                             fontSize: 12,
//                                           ),
//                                         ),
//                                       ],
//                                     ),
//                                   ),
//                                 ],
//                               ),
//                               const SizedBox(height: 5),
//                               CustomTextfield.textWithImage(
//                                 text: data.createdAt,
//                                 imagePath: AppImages.clock,
//                               ),
//                             ],
//                           ),
//                         ),
//                       );
//                     },
//                   ),
//                 );
//               }),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
