import 'package:flutter/material.dart';
import '../../../Core/Constants/texts.dart';
import '../../../Core/Utility/Buttons.dart';
import '../../../Core/Utility/ModelBottomSheet.dart';
import '../../../Core/Utility/images.dart';
import '../../../Core/Utility/snackbar.dart';
import '../controller/driveraddress_controller.dart';
import '../controller/guidelines_Controller.dart';
import '../controller/stateList_Controller.dart';
import '../../Authentication/widgets/textFields.dart';
import '../widgets/bottomNavigation.dart';
import '../widgets/linearProgress.dart';
import 'package:get/get.dart';

class DriverAddress extends StatefulWidget {
  final bool fromCompleteScreens;
  const DriverAddress({Key? key, this.fromCompleteScreens = false})
    : super(key: key);

  @override
  State<DriverAddress> createState() => _DriverAddressState();
}

class _DriverAddressState extends State<DriverAddress> {
  final StateListController stateController = Get.put(StateListController());
  final DriverAddressController controller = Get.put(DriverAddressController());
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final GuidelinesController guidelinesController = Get.put(
    GuidelinesController(),
  );

  @override
  void initState() {
    super.initState();
    stateController.getStateList();
    controller.fetchAndSetUserData();
    guidelinesController.guideLines('profile-pic');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 25),
            child: Form(
              key: _formKey,
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
                    formKey: _formKey,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your Address';
                      } /*else if (value.length != 11) {
                        return 'Must be exactly 11 digits';
                      }*/
                      return null;
                    },
                    controller: controller.addressController,
                    tittle: 'Address',
                    hintText: 'Enter your Address',
                  ),
                  SizedBox(height: 24),

                  CustomTextfield.dropDown(
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please Select your States';
                      } /*else if (value.length != 11) {
                        return 'Must be exactly 11 digits';
                      }*/
                      return null;
                    },
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
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please Select your City';
                      } /*else if (value.length != 11) {
                        return 'Must be exactly 11 digits';
                      }*/
                      return null;
                    },
                    controller: controller.cityController,
                    title: 'City',
                    hintText: 'Select City',
                    onTap: () async {
                      final selectedState = controller.stateController.text;
                      if (selectedState.isEmpty) {
                        CustomSnackBar.showError("Please select a state first");
                        return;
                      }

                      Get.dialog(
                        Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        barrierDismissible: false,
                      );

                      await stateController.getCityList(selectedState);
                      Get.back();
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
                    formKey: _formKey,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your PostCode';
                      } /*else if (value.length != 11) {
                        return 'Must be exactly 11 digits';
                      }*/
                      return null;
                    },
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
                  onTap: () async {
                    if (_formKey.currentState!.validate()) {
                      await controller.driverDetails(
                        context,
                        fromCompleteScreen: widget.fromCompleteScreens,
                      );
                      // Navigator.push(
                      //   context,
                      //   MaterialPageRoute(builder: (context) => DriverDocGuideLines()),
                      // );
                    }
                  },
                ),
      ),
    );
  }
}
