import 'package:flutter/material.dart';
import '../../../Core/Constants/Colors.dart';
import '../../../Core/Constants/log.dart';
import '../../../Core/Constants/texts.dart';
import '../../../Core/Utility/Buttons.dart';
import '../../../Core/Utility/images.dart';
import '../../../Core/Utility/snackbar.dart';
import '../controller/chooseservice_controller.dart';
import 'carOwnerShip.dart';
import 'processingScreen.dart';
import '../widgets/bottomNavigation.dart';
import '../../../utils/init_Controller.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../Authentication/widgets/customContainer.dart';

import 'package:get/get.dart';

String selectedService = '';

class ChooseService extends StatefulWidget {
  const ChooseService({super.key});

  @override
  State<ChooseService> createState() => _ChooseServiceState();
}

class _ChooseServiceState extends State<ChooseService> {
  int selectedIndex = -1;
  final ChooseServiceController controller = Get.find();
  @override
  void initState() {
    super.initState();
    controller.getUserDetails();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 25),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Choose your service',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 25),
                ),

                // Obx(
                //   () => Text(
                //     controller.userProfile.value?.mobileNumber ??
                //         'No mobile number available',
                //     style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                //   ),
                // ),
                SizedBox(height: 16),
                Text(
                  'Select one service to begin your onboarding',
                  style: TextStyle(color: AppColors.textColor),
                ),
                SizedBox(height: 32),

                CustomContainer.container(
                  isSelected: selectedIndex == 0,
                  onSelectionChanged: (bool value) {
                    setState(() {
                      selectedIndex = value ? 0 : -1;
                      selectedService = value ? 'Car' : '';
                    });

                    print('Selected service: $selectedService');
                  },
                  onTap: () {},
                  serviceType: 'Car',
                  serviceTypeImage: AppImages.car,
                  serviceText: 'Ride Passenger',
                  content: AppTexts.carText,
                ),
                SizedBox(height: 32),
                CustomContainer.container(
                  isSelected: selectedIndex == 1,
                  onSelectionChanged: (bool value) {
                    setState(() {
                      selectedIndex = value ? 1 : -1;
                      selectedService = value ? 'Bike' : '';
                    });

                    print('Selected service: $selectedService');
                  },
                  onTap: () {},
                  serviceType: 'Bike',
                  serviceTypeImage: AppImages.bike,
                  serviceText: 'Package Delivery',
                  content: AppTexts.bikeText,
                ),
                SizedBox(height: 32),
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: "Note: ",
                        style: TextStyle(
                          color: AppColors.commonBlack,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      TextSpan(
                        text: AppTexts.noteText,
                        style: TextStyle(
                          color: AppColors.textColor,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),

                // Buttons.button(
                //   buttonColor: AppColors.commonBlack,
                //   textColor: AppColors.commonWhite,
                //   onTap: () async {
                //     if (selectedService.isEmpty) {
                //       CommonLogger.log.e('Not Choosing Any');
                //       CustomSnackBar.showInfo('Choose your Service');
                //     } else {
                //       await controller.chooseServiceType();
                //       Navigator.push(
                //         context,
                //         MaterialPageRoute(builder: (context) => CarOwnership()),
                //       );
                //     }
                //   },
                //   text: 'Continue',
                // ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: Obx(
        () => CustomBottomNavigation.bottomNavigation(
          foreGroundColor:
              controller.isLoading.value ? Colors.black : Colors.white,

          title:
              controller.isLoading.value
                  ? Image.asset(AppImages.animation)
                  : const Text('Continue'),

          buttonColor:
              controller.isLoading.value
                  ? Colors.white
                  : selectedService.isNotEmpty
                  ? AppColors.commonBlack
                  : Colors.grey.shade400,

          onTap: () async {
            if (selectedService.isEmpty) {
              CommonLogger.log.e('Not Choosing Any');
              Get.closeAllSnackbars();
              CustomSnackBar.showInfo('Choose your Service');
            } else {
              controller.isLoading.value = true; // Start loading
              try {
                await controller.chooseServiceType(selectedService);
                await controller.getUserDetails();
              } catch (e) {
                CommonLogger.log.e('Error: $e');

                CustomSnackBar.showError('Something went wrong');
              } finally {
                controller.isLoading.value = false; // Stop loading
              }
            }
          },
        ),
      ),
    );
  }
}
