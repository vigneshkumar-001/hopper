import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hopper/Core/Constants/texts.dart';
import 'package:hopper/Core/Utility/images.dart';
import 'package:hopper/Presentation/OnBoarding/controller/chooseservice_controller.dart';
import 'package:hopper/Presentation/OnBoarding/screens/basicInfo.dart';
import 'package:hopper/Presentation/OnBoarding/screens/carOwnerShip.dart';
import 'package:hopper/Presentation/OnBoarding/screens/driverAddress.dart';
import 'package:hopper/Presentation/OnBoarding/screens/driverLicense.dart';
import 'package:hopper/Presentation/OnBoarding/screens/interiorUploadPhotos.dart';
import 'package:hopper/Presentation/OnBoarding/screens/ninScreens.dart';
import 'package:hopper/Presentation/OnBoarding/screens/takePictureScreen.dart';
import 'package:hopper/Presentation/OnBoarding/screens/uploadExteriorPhotos.dart';
import 'package:hopper/Presentation/OnBoarding/screens/vehicleDetails.dart';
import 'package:hopper/Presentation/OnBoarding/widgets/linearProgress.dart';
import 'package:get/get.dart';

//
// class CompletedScreens extends StatefulWidget {
//   const CompletedScreens({super.key});
//
//   @override
//   State<CompletedScreens> createState() => _CompletedScreensState();
// }
//
// class _CompletedScreensState extends State<CompletedScreens> {
//   final ChooseServiceController controller = Get.find();
//
//   // late List<Map<String, dynamic>> rowData;
//   // List<Map<String, dynamic>> carSteps = [];
//   // List<Map<String, dynamic>> bikeSteps = [];
//   // //0 incomplete , 1.Completed 2.Verified 3.Rejected
//   // @override
//   // void initState() {
//   //   super.initState();
//   //   controller.getUserDetails();
//   //   initOverviewData();
//   // }
//   //
//   // Future<void> initOverviewData() async {
//   //   final user = controller.userProfile.value;
//   //   final serviceType = user?.serviceType;
//   //
//   //   carSteps = [
//   //     {'title': 'Basic Info', 'status': user?.basicInfoStatus?.status ?? 0},
//   //     {
//   //       'title': 'Driver Address Details',
//   //       'status': user?.driverAddressStatus?.status ?? 0,
//   //     },
//   //     {
//   //       'title': 'Profile Photo',
//   //       'status': user?.profilePhotoStatus?.status ?? 0,
//   //     },
//   //     {
//   //       'title': 'Identify Verification',
//   //       'status': user?.ninVerificationStatus?.status ?? 0,
//   //     },
//   //     {
//   //       'title': 'Driver License',
//   //       'status': user?.driversLicenseStatus?.status ?? 0,
//   //     },
//   //     {
//   //       'title': 'Car Ownership Details',
//   //       'status': user?.carOwnershipStatus?.status ?? 0,
//   //     },
//   //     {
//   //       'title': 'Vehicle Details',
//   //       'status': user?.carDetailsStatus?.status ?? 0,
//   //     },
//   //     {
//   //       'title': 'Exterior Photos',
//   //       'status': user?.carExteriorPhotosStatus?.status ?? 0,
//   //     },
//   //     {
//   //       'title': 'Interior Photos',
//   //       'status': user?.carInteriorPhotosStatus?.status ?? 0,
//   //     },
//   //   ];
//   //
//   //   bikeSteps = [
//   //     {'title': 'Basic Info', 'status': user?.basicInfoStatus?.status ?? 0},
//   //     {
//   //       'title': 'Driver Address Details',
//   //       'status': user?.driverAddressStatus?.status ?? 0,
//   //     },
//   //     {
//   //       'title': 'Profile Photo',
//   //       'status': user?.profilePhotoStatus?.status ?? 0,
//   //     },
//   //     {
//   //       'title': 'Identify Verification',
//   //       'status': user?.ninVerificationStatus?.status ?? 0,
//   //     },
//   //     {
//   //       'title': 'Driver License',
//   //       'status': user?.driversLicenseStatus?.status ?? 0,
//   //     },
//   //     {
//   //       'title': 'Bike Ownership Details',
//   //       'status': user?.bikeOwnershipStatus?.status ?? 0,
//   //     },
//   //     {'title': 'Bike Details', 'status': user?.bikeDetailsStatus?.status ?? 0},
//   //     {'title': 'Bike Photos', 'status': user?.bikePhotosStatus?.status ?? 0},
//   //   ];
//   //
//   //   if (serviceType == 'Bike') {
//   //     rowData = bikeSteps;
//   //   } else {
//   //     rowData = carSteps;
//   //   }
//   //
//   //   setState(() {});
//   // }
//   //
//   // IconData getIcon(int? status) {
//   //   if (status == 1) {
//   //     return Icons.lock;
//   //   } else if (status == 2) {
//   //     return Icons.info;
//   //   } else if (status == 3) {
//   //     return Icons.verified_user;
//   //   } else {
//   //     return Icons.close;
//   //   }
//   // }
//   //
//   // Color getIconColor(int status) {
//   //   switch (status) {
//   //     case 1:
//   //       return Color(0xff333333);
//   //     case 2:
//   //       return Color(0xffEA4335);
//   //     case 3:
//   //       return Color(0xff009721);
//   //     default:
//   //       return Colors.transparent;
//   //   }
//   // }
//   List<Map<String, dynamic>> getSteps() {
//     final user = controller.userProfile.value;
//     final serviceType = user?.serviceType;
//
//     if (serviceType == 'Bike') {
//       return [
//         {'title': 'Basic Info', 'status': user?.basicInfoStatus?.status ?? 0},
//         {
//           'title': 'Driver Address Details',
//           'status': user?.driverAddressStatus?.status ?? 0,
//         },
//         {
//           'title': 'Profile Photo',
//           'status': user?.profilePhotoStatus?.status ?? 0,
//         },
//         {
//           'title': 'Identify Verification',
//           'status': user?.ninVerificationStatus?.status ?? 0,
//         },
//         {
//           'title': 'Driver License',
//           'status': user?.driversLicenseStatus?.status ?? 0,
//         },
//         {
//           'title': 'Bike Ownership Details',
//           'status': user?.bikeOwnershipStatus?.status ?? 0,
//         },
//         {
//           'title': 'Bike Details',
//           'status': user?.bikeDetailsStatus?.status ?? 0,
//         },
//         {'title': 'Bike Photos', 'status': user?.bikePhotosStatus?.status ?? 0},
//       ];
//     } else {
//       return [
//         {'title': 'Basic Info', 'status': user?.basicInfoStatus?.status ?? 0},
//         {
//           'title': 'Driver Address Details',
//           'status': user?.driverAddressStatus?.status ?? 0,
//         },
//         {
//           'title': 'Profile Photo',
//           'status': user?.profilePhotoStatus?.status ?? 0,
//         },
//         {
//           'title': 'Identify Verification',
//           'status': user?.ninVerificationStatus?.status ?? 0,
//         },
//         {
//           'title': 'Driver License',
//           'status': user?.driversLicenseStatus?.status ?? 0,
//         },
//         {
//           'title': 'Car Ownership Details',
//           'status': user?.carOwnershipStatus?.status ?? 0,
//         },
//         {
//           'title': 'Vehicle Details',
//           'status': user?.carDetailsStatus?.status ?? 0,
//         },
//         {
//           'title': 'Exterior Photos',
//           'status': user?.carExteriorPhotosStatus?.status ?? 0,
//         },
//         {
//           'title': 'Interior Photos',
//           'status': user?.carInteriorPhotosStatus?.status ?? 0,
//         },
//       ];
//     }
//   }
//
//   IconData getIcon(int? status) {
//     if (status == 1) return Icons.lock;
//     if (status == 2) return Icons.info;
//     if (status == 3) return Icons.verified_user;
//     return Icons.close;
//   }
//
//   Color getIconColor(int status) {
//     switch (status) {
//       case 1:
//         return Color(0xff333333);
//       case 2:
//         return Color(0xffEA4335);
//       case 3:
//         return Color(0xff009721);
//       default:
//         return Colors.transparent;
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     controller.getUserDetails();
//
//     return Scaffold(
//       body: Obx(() {
//         final user = controller.userProfile.value;
//         final steps = getSteps();
//
//         return SingleChildScrollView(
//           child: SafeArea(
//             child: Padding(
//               padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
//               child: Column(
//                 children: [
//                   Center(child: Image.asset(AppImages.waitingReview)),
//                   SizedBox(height: 24),
//                   Text(
//                     AppTexts.awaitingReview,
//                     style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
//                   ),
//                   SizedBox(height: 24),
//                   Text(AppTexts.awaitingContent, textAlign: TextAlign.center),
//                   SizedBox(height: 24),
//                   ClipOval(
//                     child: Image.network(
//                       user?.profilePic ?? '',
//                       width: 130,
//                       height: 130,
//                       fit: BoxFit.cover,
//                       errorBuilder:
//                           (context, error, stackTrace) => Icon(Icons.error),
//                     ),
//                   ),
//                   SizedBox(height: 10),
//                   Container(
//                     width: MediaQuery.of(context).size.width * 0.5,
//                     child: CustomLinearProgress.linearProgressIndicator(
//                       value: (user?.completed ?? 0).toDouble(),
//                       progressColor: Color(0xff009721),
//                       minHeight: 4,
//                     ),
//                   ),
//                   SizedBox(height: 10),
//                   Text('${user?.completed ?? 0}% profile completed'),
//                   SizedBox(height: 24),
//
//                   // Settings & FAQ Row
//                   Row(
//                     children: [
//                       Expanded(
//                         child: settingBox(
//                           title: 'Settings',
//                           icon: Icons.settings,
//                         ),
//                       ),
//                       SizedBox(width: 15),
//                       Expanded(
//                         child: settingBox(
//                           title: 'FAQ',
//                           icon: Icons.help_outline,
//                         ),
//                       ),
//                     ],
//                   ),
//
//                   SizedBox(height: 24),
//
//                   // Step List
//                   Container(
//                     decoration: BoxDecoration(
//                       color: Color(0xffF5F5F7),
//                       borderRadius: BorderRadius.circular(4),
//                       border: Border.all(color: Color(0xffD9D9D9)),
//                     ),
//                     child: Padding(
//                       padding: const EdgeInsets.symmetric(
//                         vertical: 16.0,
//                         horizontal: 16,
//                       ),
//                       child: ListView.separated(
//                         shrinkWrap: true,
//                         physics: NeverScrollableScrollPhysics(),
//                         itemCount: steps.length,
//                         separatorBuilder: (_, __) => Divider(),
//                         itemBuilder: (context, index) {
//                           final data = steps[index];
//                           final status = data['status'] ?? 0;
//
//                           return GestureDetector(
//                             onTap: () {
//                               if (status == 2) {
//                                 navigateToStep(index);
//                               }
//                             },
//                             child: Row(
//                               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                               children: [
//                                 Text(
//                                   data['title'],
//                                   style: TextStyle(
//                                     fontSize: 14,
//                                     fontWeight: FontWeight.w500,
//                                   ),
//                                 ),
//                                 Icon(
//                                   getIcon(status),
//                                   color: getIconColor(status),
//                                   size: 19,
//                                 ),
//                               ],
//                             ),
//                           );
//                         },
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         );
//       }),
//     );
//   }
//
//   void navigateToStep(int index) {
//     switch (index) {
//       case 0:
//         Get.to(() => BasicInfo(fromCompleteScreens: true));
//         break;
//       case 1:
//         Get.to(() => DriverAddress(fromCompleteScreens: true));
//         break;
//       case 2:
//         Get.to(() => TakePicture(fromCompleteScreens: true));
//         break;
//       case 3:
//         Get.to(() => NinScreens());
//         break;
//       case 4:
//         Get.to(() => DriverLicense());
//         break;
//       case 5:
//         Get.to(() => CarOwnership());
//         break;
//       case 6:
//         Get.to(() => VehicleDetails());
//         break;
//       case 7:
//         Get.to(() => UploadExteriorPhotos());
//         break;
//       case 8:
//         Get.to(() => InteriorUploadPhotos());
//         break;
//       default:
//         Get.snackbar('Oops', 'No screen found for this step.');
//     }
//   }
//
//   Widget settingBox({required String title, required IconData icon}) {
//     return Container(
//       decoration: BoxDecoration(
//         color: Color(0xffF5F5F7),
//         borderRadius: BorderRadius.circular(4),
//         border: Border.all(color: Color(0xffD9D9D9)),
//       ),
//       child: Padding(
//         padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
//         child: Row(
//           mainAxisAlignment: MainAxisAlignment.spaceBetween,
//           children: [
//             Text(
//               title,
//               style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
//             ),
//             Icon(icon),
//           ],
//         ),
//       ),
//     );
//   }
//
//   // @override
//   // Widget build(BuildContext context) {
//   //   return Scaffold(
//   //     body: SingleChildScrollView(
//   //       child: SafeArea(
//   //         child: Padding(
//   //           padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
//   //           child: Column(
//   //             children: [
//   //               Center(child: Image.asset(AppImages.waitingReview)),
//   //               SizedBox(height: 24),
//   //               Text(
//   //                 AppTexts.awaitingReview,
//   //                 style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
//   //               ),
//   //               SizedBox(height: 24),
//   //               Text(textAlign: TextAlign.center, AppTexts.awaitingContent),
//   //               SizedBox(height: 24),
//   //               ClipOval(
//   //                 child: Image.network(
//   //                   controller.userProfile.value?.profilePic.toString() ?? '',
//   //                   width: 130,
//   //                   height: 130,
//   //
//   //                   fit: BoxFit.cover,
//   //                   errorBuilder:
//   //                       (context, error, stackTrace) => Icon(Icons.error),
//   //                 ),
//   //               ),
//   //
//   //               SizedBox(height: 10),
//   //               Container(
//   //                 width: MediaQuery.of(context).size.width * 0.5,
//   //                 child: CustomLinearProgress.linearProgressIndicator(
//   //                   value: 10,
//   //                   progressColor: Color(0xff009721),
//   //                   minHeight: 4,
//   //                 ),
//   //               ),
//   //               SizedBox(height: 10),
//   //               // Text('100% profile completed'),
//   //               Text(
//   //                 '${controller.userProfile.value?.completed.toString() ?? ''}% profile completed',
//   //               ),
//   //               SizedBox(height: 24),
//   //               Row(
//   //                 children: [
//   //                   Expanded(
//   //                     child: Container(
//   //                       decoration: BoxDecoration(
//   //                         color: Color(0xffF5F5F7),
//   //                         borderRadius: BorderRadius.circular(4),
//   //                         border: Border.all(color: Color(0xffD9D9D9)),
//   //                       ),
//   //                       child: Padding(
//   //                         padding: const EdgeInsets.symmetric(
//   //                           horizontal: 16,
//   //                           vertical: 10,
//   //                         ),
//   //                         child: Row(
//   //                           mainAxisAlignment: MainAxisAlignment.spaceBetween,
//   //                           children: [
//   //                             Text(
//   //                               'Settings',
//   //                               style: TextStyle(
//   //                                 fontSize: 14,
//   //                                 fontWeight: FontWeight.w500,
//   //                               ),
//   //                             ),
//   //
//   //                             Icon(Icons.settings),
//   //                           ],
//   //                         ),
//   //                       ),
//   //                     ),
//   //                   ),
//   //                   SizedBox(width: 15),
//   //                   Expanded(
//   //                     child: Container(
//   //                       decoration: BoxDecoration(
//   //                         color: Color(0xffF5F5F7),
//   //                         borderRadius: BorderRadius.circular(4),
//   //                         border: Border.all(color: Color(0xffD9D9D9)),
//   //                       ),
//   //                       child: Padding(
//   //                         padding: const EdgeInsets.symmetric(
//   //                           horizontal: 16,
//   //                           vertical: 10,
//   //                         ),
//   //                         child: Row(
//   //                           mainAxisAlignment: MainAxisAlignment.spaceBetween,
//   //                           children: [
//   //                             Text(
//   //                               'FAQ',
//   //                               style: TextStyle(
//   //                                 fontSize: 14,
//   //                                 fontWeight: FontWeight.w500,
//   //                               ),
//   //                             ),
//   //
//   //                             Icon(Icons.settings),
//   //                           ],
//   //                         ),
//   //                       ),
//   //                     ),
//   //                   ),
//   //                 ],
//   //               ),
//   //               SizedBox(height: 24),
//   //               Container(
//   //                 decoration: BoxDecoration(
//   //                   color: Color(0xffF5F5F7),
//   //                   borderRadius: BorderRadius.circular(4),
//   //                   border: Border.all(color: Color(0xffD9D9D9)),
//   //                 ),
//   //                 child: Padding(
//   //                   padding: const EdgeInsets.symmetric(
//   //                     vertical: 16.0,
//   //                     horizontal: 16,
//   //                   ),
//   //                   child: Column(
//   //                     spacing: 10,
//   //                     children: [
//   //                       ListView.builder(
//   //                         shrinkWrap: true,
//   //                         physics: NeverScrollableScrollPhysics(),
//   //                         itemCount: rowData.length,
//   //                         itemBuilder: (context, index) {
//   //                           final data = rowData[index];
//   //                           final status = data['status'] ?? 0;
//   //                           return Column(
//   //                             children: [
//   //                               GestureDetector(
//   //                                 onTap: () {
//   //                                   int status = rowData[index]['status'] ?? 0;
//   //                                   CommonLogger.log.i('Selected $index');
//   //                                   CommonLogger.log.i(rowData[index]);
//   //
//   //                                   if (status == 2) {
//   //                                     switch (index) {
//   //                                       case 0:
//   //                                         Get.to(
//   //                                           () => BasicInfo(
//   //                                             fromCompleteScreens: true,
//   //                                           ),
//   //                                         );
//   //                                         break;
//   //                                       case 1:
//   //                                         Get.to(
//   //                                           () => DriverAddress(
//   //                                             fromCompleteScreens: true,
//   //                                           ),
//   //                                         );
//   //                                         break;
//   //                                       case 2:
//   //                                         Get.to(
//   //                                           () => TakePicture(
//   //                                             fromCompleteScreens: true,
//   //                                           ),
//   //                                         );
//   //                                         break;
//   //                                       case 3:
//   //                                         Get.to(() => NinScreens());
//   //                                         break;
//   //                                       case 4:
//   //                                         Get.to(() => DriverLicense());
//   //                                         break;
//   //                                       case 5:
//   //                                         Get.to(() => CarOwnership());
//   //                                         break;
//   //                                       case 6:
//   //                                         Get.to(() => VehicleDetails());
//   //                                         break;
//   //                                       case 7:
//   //                                         Get.to(() => UploadExteriorPhotos());
//   //                                         break;
//   //                                       case 8:
//   //                                         Get.to(() => InteriorUploadPhotos());
//   //                                         break;
//   //
//   //                                       default:
//   //                                         Get.snackbar(
//   //                                           'Oops',
//   //                                           'No screen found for this step.',
//   //                                         );
//   //                                         break;
//   //                                     }
//   //                                   }
//   //                                 },
//   //                                 child: Container(
//   //                                   width:
//   //                                       double
//   //                                           .infinity, // Makes entire row tappable
//   //                                   child: Padding(
//   //                                     padding: EdgeInsets.symmetric(
//   //                                       vertical: 5,
//   //                                     ), // Optional for spacing
//   //                                     child: Row(
//   //                                       mainAxisAlignment:
//   //                                           MainAxisAlignment.spaceBetween,
//   //                                       children: [
//   //                                         Text(
//   //                                           data['title'],
//   //                                           style: TextStyle(
//   //                                             fontSize: 14,
//   //                                             fontWeight: FontWeight.w500,
//   //                                           ),
//   //                                         ),
//   //                                         Icon(
//   //                                           size: 19,
//   //                                           getIcon(status),
//   //                                           color: getIconColor(status),
//   //                                         ),
//   //                                       ],
//   //                                     ),
//   //                                   ),
//   //                                 ),
//   //                               ),
//   //
//   //                               Divider(),
//   //                             ],
//   //                           );
//   //                         },
//   //                       ),
//   //                     ],
//   //                   ),
//   //                 ),
//   //               ),
//   //             ],
//   //           ),
//   //         ),
//   //       ),
//   //     ),
//   //   );
//   // }
// }
class CompletedScreens extends StatefulWidget {
  const CompletedScreens({super.key});

  @override
  State<CompletedScreens> createState() => _CompletedScreensState();
}

class _CompletedScreensState extends State<CompletedScreens> {
  final ChooseServiceController controller = Get.find();
  Timer? _timer;

  @override
  void initState() {
    super.initState();

    // Initial fetch
    controller.getUserDetails();

    // Refresh every 2 seconds
    _timer = Timer.periodic(Duration(seconds: 2), (timer) {
      controller.getUserDetails();
    });
  }

  @override
  void dispose() {
    _timer?.cancel(); // Cancel timer when screen is destroyed
    super.dispose();
  }

  List<Map<String, dynamic>> getSteps() {
    final user = controller.userProfile.value;
    final serviceType = user?.serviceType;

    if (serviceType == 'Bike') {
      return [
        {'title': 'Basic Info', 'status': user?.basicInfoStatus?.status ?? 0},
        {
          'title': 'Driver Address Details',
          'status': user?.driverAddressStatus?.status ?? 0,
        },
        {
          'title': 'Profile Photo',
          'status': user?.profilePhotoStatus?.status ?? 0,
        },
        {
          'title': 'Identify Verification',
          'status': user?.ninVerificationStatus?.status ?? 0,
        },
        {
          'title': 'Driver License',
          'status': user?.driversLicenseStatus?.status ?? 0,
        },
        {
          'title': 'Bike Ownership Details',
          'status': user?.bikeOwnershipStatus?.status ?? 0,
        },
        {
          'title': 'Bike Details',
          'status': user?.bikeDetailsStatus?.status ?? 0,
        },
        {'title': 'Bike Photos', 'status': user?.bikePhotosStatus?.status ?? 0},
      ];
    } else {
      return [
        {'title': 'Basic Info', 'status': user?.basicInfoStatus?.status ?? 0},
        {
          'title': 'Driver Address Details',
          'status': user?.driverAddressStatus?.status ?? 0,
        },
        {
          'title': 'Profile Photo',
          'status': user?.profilePhotoStatus?.status ?? 0,
        },
        {
          'title': 'Identify Verification',
          'status': user?.ninVerificationStatus?.status ?? 0,
        },
        {
          'title': 'Driver License',
          'status': user?.driversLicenseStatus?.status ?? 0,
        },
        {
          'title': 'Car Ownership Details',
          'status': user?.carOwnershipStatus?.status ?? 0,
        },
        {
          'title': 'Vehicle Details',
          'status': user?.carDetailsStatus?.status ?? 0,
        },
        {
          'title': 'Exterior Photos',
          'status': user?.carExteriorPhotosStatus?.status ?? 0,
        },
        {
          'title': 'Interior Photos',
          'status': user?.carInteriorPhotosStatus?.status ?? 0,
        },
      ];
    }
  }

  IconData getIcon(int? status) {
    if (status == 1) return Icons.lock;
    if (status == 2) return Icons.info;
    if (status == 3) return Icons.verified_user;
    return Icons.close;
  }

  Color getIconColor(int status) {
    switch (status) {
      case 1:
        return Color(0xff333333);
      case 2:
        return Color(0xffEA4335);
      case 3:
        return Color(0xff009721);
      default:
        return Colors.transparent;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Obx(() {
        final user = controller.userProfile.value;
        final steps = getSteps();

        return user == null
            ? Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 15,
                  ),
                  child: Column(
                    children: [
                      Center(child: Image.asset(AppImages.waitingReview)),
                      SizedBox(height: 24),
                      Text(
                        AppTexts.awaitingReview,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 24,
                        ),
                      ),
                      SizedBox(height: 24),
                      Text(
                        AppTexts.awaitingContent,
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 24),
                      ClipOval(
                        child: Image.network(
                          user.profilePic ?? '',
                          width: 130,
                          height: 130,
                          fit: BoxFit.cover,
                          errorBuilder:
                              (context, error, stackTrace) => Icon(Icons.error),
                        ),
                      ),
                      SizedBox(height: 10),
                      SizedBox(
                        width: MediaQuery.of(context).size.width * 0.5,
                        child: CustomLinearProgress.linearProgressIndicator(
                          value: (user.completed ?? 0).toDouble(),
                          progressColor: Color(0xff009721),
                          minHeight: 4,
                        ),
                      ),
                      SizedBox(height: 10),
                      Text('${user.completed ?? 0}% profile completed'),
                      SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: settingBox(
                              title: 'Settings',
                              icon: Icons.settings,
                            ),
                          ),
                          SizedBox(width: 15),
                          Expanded(
                            child: settingBox(
                              title: 'FAQ',
                              icon: Icons.help_outline,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 24),
                      Container(
                        decoration: BoxDecoration(
                          color: Color(0xffF5F5F7),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Color(0xffD9D9D9)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 16.0,
                            horizontal: 16,
                          ),
                          child: ListView.separated(
                            shrinkWrap: true,
                            physics: NeverScrollableScrollPhysics(),
                            itemCount: steps.length,
                            separatorBuilder: (_, __) => Divider(),
                            itemBuilder: (context, index) {
                              final data = steps[index];
                              final status = data['status'] ?? 0;

                              return GestureDetector(
                                onTap: () {
                                  if (status == 2) navigateToStep(index);
                                },
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      data['title'],
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Icon(
                                      getIcon(status),
                                      color: getIconColor(status),
                                      size: 19,
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
      }),
    );
  }

  void navigateToStep(int index) {
    switch (index) {
      case 0:
        Get.to(() => BasicInfo(fromCompleteScreens: true));
        break;
      case 1:
        Get.to(() => DriverAddress(fromCompleteScreens: true));
        break;
      case 2:
        Get.to(() => TakePicture(fromCompleteScreens: true));
        break;
      case 3:
        Get.to(() => NinScreens());
        break;
      case 4:
        Get.to(() => DriverLicense());
        break;
      case 5:
        Get.to(() => CarOwnership());
        break;
      case 6:
        Get.to(() => VehicleDetails());
        break;
      case 7:
        Get.to(() => UploadExteriorPhotos());
        break;
      case 8:
        Get.to(() => InteriorUploadPhotos());
        break;
    }
  }

  Widget settingBox({required String title, required IconData icon}) {
    return Container(
      decoration: BoxDecoration(
        color: Color(0xffF5F5F7),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Color(0xffD9D9D9)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            Icon(icon),
          ],
        ),
      ),
    );
  }
}
