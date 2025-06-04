import 'package:flutter/material.dart';
import 'package:hopper/Core/Constants/texts.dart';
import 'package:hopper/Core/Utility/Buttons.dart';
import 'package:hopper/Core/Utility/ModelBottomSheet.dart';
import 'package:hopper/Core/Utility/images.dart';
import 'package:hopper/Core/Utility/snackbar.dart';
import 'package:hopper/Presentation/OnBoarding/controller/driveraddress_controller.dart';
import 'package:hopper/Presentation/OnBoarding/controller/stateList_Controller.dart';
import 'package:hopper/Presentation/Authentication/widgets/textFields.dart';
import 'package:hopper/Presentation/OnBoarding/widgets/bottomNavigation.dart';
import 'package:hopper/Presentation/OnBoarding/widgets/linearProgress.dart';
import 'package:get/get.dart';

class DriverAddress extends StatefulWidget {
  final bool fromCompleteScreens;
  const DriverAddress({super.key, this.fromCompleteScreens = false});

  @override
  State<DriverAddress> createState() => _DriverAddressState();
}

class _DriverAddressState extends State<DriverAddress> {
  final StateListController stateController = Get.find();
  final DriverAddressController controller = Get.find();

  @override
  void initState() {
    super.initState();
    stateController.getStateList();
    controller.fetchAndSetUserData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 25),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Buttons.backButton(context: context),
                SizedBox(height: 24),
                CustomLinearProgress.linearProgressIndicator(value: 0.2),
                Image.asset(AppImages.basicInfo),
                SizedBox(height: 24),
                Text(
                  AppTexts.driverAddress,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
                ),
                SizedBox(height: 24),
                CustomTextfield.textField(
                  controller: controller.addressController,
                  tittle: 'Address',
                  hintText: 'Enter your Address',
                ),
                SizedBox(height: 24),

                CustomTextfield.dropDown(
                  controller: controller.stateController,
                  title: 'States',
                  hintText: 'Select States',
                  onTap: () {
                    // Directly show the bottom sheet (no delay!)
                    CustomBottomSheet.showOptionsBottomSheet(
                      title: 'States',
                      options: stateController.states,
                      context: context,
                      controller: controller.stateController,
                    );
                  },
                  suffixIcon: Icon(Icons.arrow_drop_down),
                ),

                SizedBox(height: 24),
                CustomTextfield.dropDown(
                  controller: controller.cityController,
                  title: 'City',
                  hintText: 'Select City',
                  onTap: () async {
                    final selectedState = controller.stateController.text;
                    if (selectedState.isEmpty) {
                      CustomSnackBar.showError("Please select a state first");
                      return;
                    }

                    await stateController.getCityList(selectedState);
                    CustomBottomSheet.showOptionsBottomSheet(
                      title: 'Select City',
                      options: stateController.cities,
                      context: context,
                      controller: controller.cityController,
                    );
                  },
                  suffixIcon: Icon(Icons.arrow_drop_down),
                ),

                SizedBox(height: 24),
                CustomTextfield.textField(
                  type: TextInputType.number,

                  controller: controller.postController,
                  tittle: 'Post Code',
                  hintText: 'Enter your PostCode',
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: Obx(
        () =>
            controller.isLoading.value
                ? Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: SizedBox(
                    height: 48,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                )
                : CustomBottomNavigation.bottomNavigation(
                  title: 'Save & Next',
                  onTap: () {
                    controller.driverDetails(
                      context,
                      fromCompleteScreen: widget.fromCompleteScreens,
                    );
                    // Navigator.push(
                    //   context,
                    //   MaterialPageRoute(builder: (context) => DriverDocGuideLines()),
                    // );
                  },
                ),
      ),
      // bottomNavigationBar: CustomBottomNavigation.bottomNavigation(
      //   title: 'Save & Next',
      //   onTap: () {
      //     controller.driverDetails(
      //       context,
      //       fromCompleteScreen: widget.fromCompleteScreens,
      //     );
      //     // Navigator.push(
      //     //   context,
      //     //   MaterialPageRoute(builder: (context) => DriverDocGuideLines()),
      //     // );
      //   },
      // ),
    );
  }
}
