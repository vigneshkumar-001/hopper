import 'package:flutter/material.dart';

import 'package:get/get.dart';
import 'package:hopper/Core/Constants/Colors.dart';
import 'package:hopper/Core/Utility/images.dart';
import 'package:hopper/Presentation/Authentication/widgets/textfields.dart';
import 'package:hopper/Presentation/Drawer/screens/notification_screen.dart';
import 'package:hopper/Presentation/Drawer/screens/ride_activity.dart';
import 'package:hopper/Presentation/Drawer/screens/settings_screen.dart';
import 'package:hopper/Presentation/Drawer/screens/wallet_screen.dart';

import '../../OnBoarding/controller/chooseservice_controller.dart';

class DrawerScreen extends StatefulWidget {
  const DrawerScreen({super.key});

  @override
  State<DrawerScreen> createState() => _DrawerScreenState();
}

class _DrawerScreenState extends State<DrawerScreen> {
  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    getDetails. getUserDetails();
  }
  final ChooseServiceController getDetails = Get.put(ChooseServiceController());
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFFFD), // Top (#FFFFFD)
              Color(0xFFF6F7FF), // Bottom (#F6F7FF)
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Column(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 20,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            InkWell(
                              onTap: () {
                                Get.back();
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.containerColor,
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                child: Image.asset(
                                  AppImages.closeButton,
                                  height: 17,
                                  width: 17,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 40),
                        InkWell(
                          onTap: () {
                            Get.to(() => RideAndPackageHistoryScreen());
                          },
                          child: CustomTextfield.textWithStyles700(
                            'Ride Activity',
                          ),
                        ),
                        const SizedBox(height: 15),
                        Divider(
                          color: AppColors.dividerColor.withOpacity(0.1),
                          thickness: 1.5,
                        ),

                        const SizedBox(height: 30),
                        InkWell(
                          onTap: () {
                            Get.to(() => WalletScreen());
                          },
                          child: CustomTextfield.textWithStyles700('Wallet'),
                        ),
                        const SizedBox(height: 15),
                        Divider(
                          color: AppColors.dividerColor.withOpacity(0.1),
                          thickness: 1.5,
                        ),

                        const SizedBox(height: 30),
                        InkWell(
                          onTap: () {
                            Get.to(() => NotificationScreen());
                          },
                          child: CustomTextfield.textWithStyles700(
                            'Notifications',
                          ),
                        ),
                        const SizedBox(height: 20),
                        Divider(
                          color: AppColors.dividerColor.withOpacity(0.1),
                          thickness: 1.5,
                        ),
                        const SizedBox(height: 30),
                        // CustomTextfield.textWithStyles700('Help'),
                        // const SizedBox(height: 20),
                        // Divider(
                        //   color: AppColors.dividerColor.withOpacity(0.1),
                        //   thickness: 1.5,
                        // ),
                        // const SizedBox(height: 30),
                        // InkWell(
                        //   onTap: () {
                        //     Get.to(() => SettingsScreen());
                        //   },
                        //   child: CustomTextfield.textWithStyles700('Settings'),
                        // ),
                      ],
                    ),
                  ),
                ),
                Divider(color: AppColors.dividerColor1, thickness: 2),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 15,
                    vertical: 5,
                  ),
                  child: Obx(() {
                    final profile = getDetails.userProfile.value;

                    return Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(50),
                          child:
                              profile?.profilePic != null
                                  ? Image.network(
                                    profile?.profilePic.toString() ?? '',
                                    height: 45,
                                    width: 45,
                                    fit: BoxFit.cover,
                                  )
                                  : Icon(Icons.people, size: 20),
                        ),
                        const SizedBox(width: 15),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CustomTextfield.textWithStyles600(
                                  fontSize: 20,
                                  '${profile?.firstName ?? "Guest User"} ',
                                ),
                           const SizedBox(width: 15),
                           Container(
                             padding: const EdgeInsets.symmetric(
                               horizontal: 10,
                               vertical: 2,
                             ),
                             decoration: BoxDecoration(
                               color: AppColors.commonWhite,
                               borderRadius: BorderRadius.circular(10),
                             ),
                             child: Row(
                               children: [
                                 Image.asset(
                                   AppImages.star,
                                   height: 15,
                                   color: AppColors.drkGreen,
                                 ),
                                 const SizedBox(width: 5),
                                 CustomTextfield.textWithStyles600(
                                   fontSize: 15,
                                   profile?.DriverStarRating.toString()?? '0',
                                 ),
                               ],
                             ),
                           ),
                              ],
                            ),
                            CustomTextfield.textWithStylesSmall(
                              '${profile?.countryCode ?? ""} ${profile?.mobileNumber ?? "Loading..."}',
                            ),
                          ],
                        ),
                      ],
                    );
                  }),
                ),

                // Padding(
                //   padding: const EdgeInsets.symmetric(
                //     horizontal: 15,
                //     vertical: 5,
                //   ),
                //   child: Row(
                //     children: [
                //       ClipRRect(
                //         borderRadius: BorderRadius.circular(50),
                //         child: Image.asset(
                //           AppImages.dummy,
                //           height: 45,
                //           width: 45,
                //         ),
                //       ),
                //       const SizedBox(width: 15),
                //       Column(
                //         crossAxisAlignment: CrossAxisAlignment.start,
                //         children: [
                //           Row(
                //             children: [
                //               CustomTextfield.textWithStyles600(
                //                 fontSize: 20,
                //                 'Michael Francis',
                //               ),
                //               const SizedBox(width: 15),
                //               Container(
                //                 padding: const EdgeInsets.symmetric(
                //                   horizontal: 10,
                //                   vertical: 2,
                //                 ),
                //                 decoration: BoxDecoration(
                //                   color: AppColors.commonWhite,
                //                   borderRadius: BorderRadius.circular(10),
                //                 ),
                //                 child: Row(
                //                   children: [
                //                     Image.asset(
                //                       AppImages.star,
                //                       height: 15,
                //                       color: AppColors.drkGreen,
                //                     ),
                //                     const SizedBox(width: 5),
                //                     CustomTextfield.textWithStyles600(
                //                       fontSize: 15,
                //                       '4.5',
                //                     ),
                //                   ],
                //                 ),
                //               ),
                //             ],
                //           ),
                //           CustomTextfield.textWithStylesSmall(
                //             '+234 813 789 4562',
                //           ),
                //         ],
                //       ),
                //     ],
                //   ),
                // ),
                Divider(color: AppColors.dividerColor1, thickness: 2),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
