import 'dart:async';

import '../../../Core/Constants/log.dart';
import 'package:flutter/material.dart';
import '../../../Core/Constants/texts.dart';
import '../../../Core/Utility/images.dart';
import '../../DriverScreen/screens/driver_main_screen.dart';
import '../controller/chooseservice_controller.dart';
import 'basicInfo.dart';
import 'carOwnerShip.dart';
import 'chooseService.dart';
import 'driverAddress.dart';
import 'driverLicense.dart';
import 'interiorUploadPhotos.dart';
import 'ninScreens.dart';
import 'takePictureScreen.dart';
import 'uploadExteriorPhotos.dart';
import 'vehicleDetails.dart';
import '../widgets/linearProgress.dart';
import 'package:get/get.dart';

class CompletedScreens extends StatefulWidget {
  const CompletedScreens({Key? key}) : super(key: key);

  @override
  State<CompletedScreens> createState() => _CompletedScreensState();
}

class _CompletedScreensState extends State<CompletedScreens> {
  final ChooseServiceController controller = Get.find();
  Timer? _timer;

  // @override
  // void initState() {
  //   super.initState();
  //
  //   controller.getUserDetails();
  //
  //   _timer = Timer.periodic(Duration(seconds: 2), (timer) {
  //     controller.getUserDetails();
  //   });
  // }
  @override
  void initState() {
    super.initState();

    controller.getUserDetails();

    _timer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      final details = await controller.getUserDetails();

      if (details != null && details.formStatus == 3) {
        _timer?.cancel();
        _timer = null;

        if (mounted) {
          Future.microtask(() => Get.offAll(() => DriverMainScreen()));
        }
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
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
      body: SafeArea(
        child: Obx(() {
          final user = controller.userProfile.value;
          final steps = getSteps();

          return user == null
              ? Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 15,
                  ),
                  child: Column(
                    children: [
                      Center(
                        child: Image.asset(
                          AppImages.waitingReview,
                          height: 32,
                          width: 32,
                        ),
                      ),
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
                      Container(
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
                            vertical: 20.0,
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
                                  print('Hi Iam Tapped');
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 5.0,
                                  ),
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
                                ),
                              );
                            },
                          ),
                        ),
                      ),

                      // Container(
                      //   decoration: BoxDecoration(
                      //     color: Color(0xffF5F5F7),
                      //     borderRadius: BorderRadius.circular(4),
                      //     border: Border.all(color: Color(0xffD9D9D9)),
                      //   ),
                      //   child: Padding(
                      //     padding: const EdgeInsets.symmetric(
                      //       vertical: 20.0,
                      //       horizontal: 16,
                      //     ),
                      //     child: ListView.separated(
                      //       shrinkWrap: true,
                      //       physics: NeverScrollableScrollPhysics(),
                      //       itemCount: steps.length,
                      //       separatorBuilder: (_, __) => Divider(),
                      //       itemBuilder: (context, index) {
                      //         final data = steps[index];
                      //         final status = data['status'] ?? 0;
                      //
                      //         return GestureDetector(
                      //           onTap: () {
                      //             if (status == 2) navigateToStep(index);
                      //           },
                      //           child: Column(
                      //             children: [
                      //               Row(
                      //                 mainAxisAlignment:
                      //                     MainAxisAlignment.spaceBetween,
                      //                 children: [
                      //                   Text(
                      //                     data['title'],
                      //                     style: TextStyle(
                      //                       fontSize: 14,
                      //                       fontWeight: FontWeight.w500,
                      //                     ),
                      //                   ),
                      //                   Icon(
                      //                     getIcon(status),
                      //                     color: getIconColor(status),
                      //                     size: 19,
                      //                   ),
                      //                 ],
                      //               ),
                      //               SizedBox(height: 5),
                      //             ],
                      //           ),
                      //         );
                      //       },
                      //     ),
                      //   ),
                      // ),
                    ],
                  ),
                ),
              );
        }),
      ),
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
        // Get.to(() => TakePicture(fromCompleteScreens: true));
        break;
      case 3:
        Get.to(() => NinScreens(fromCompleteScreens: true));
        break;
      case 4:
        Get.to(() => DriverLicense(fromCompleteScreens: true));
        break;
      case 5:
        Get.to(() => CarOwnership(fromCompleteScreens: true));
        break;
      case 6:
        Get.to(() => VehicleDetails(fromCompleteScreens: true));
        break;
      case 7:
        Get.to(() => UploadExteriorPhotos(fromCompleteScreens: true));
        break;
      case 8:
        Get.to(() => InteriorUploadPhotos(fromCompleteScreens: true));
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
