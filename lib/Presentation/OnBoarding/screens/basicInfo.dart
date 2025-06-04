import 'package:flutter/material.dart';
import 'package:hopper/Core/Constants/texts.dart';
import 'package:hopper/Core/Utility/Buttons.dart';
import 'package:hopper/Core/Utility/ModelBottomSheet.dart';
import 'package:hopper/Core/Utility/images.dart';
import 'package:hopper/Presentation/OnBoarding/controller/basicInfo_controller.dart';
import 'package:hopper/Presentation/OnBoarding/controller/chooseservice_controller.dart';
import 'package:hopper/Presentation/Authentication/widgets/textFields.dart';
import 'package:hopper/Presentation/OnBoarding/widgets/bottomNavigation.dart';
import 'package:hopper/Presentation/OnBoarding/widgets/linearProgress.dart';
import 'package:get/get.dart';

class BasicInfo extends StatefulWidget {
  final bool? fromCompleteScreens;

  const BasicInfo({super.key, this.fromCompleteScreens = false});

  @override
  State<BasicInfo> createState() => _BasicInfoState();
}

class _BasicInfoState extends State<BasicInfo> {
  TextEditingController dobController = TextEditingController();
  final ChooseServiceController userController = Get.find();
  final BasicInfoController controller = Get.find();

  @override
  void initState() {
    super.initState();
    userController.getUserDetails();
    controller.fetchAndSetUserData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // appBar: AppBar(backgroundColor: AppColors.commonWhite),
      body: SingleChildScrollView(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 25),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Buttons.backButton(context: context),
                SizedBox(height: 24),
                CustomLinearProgress.linearProgressIndicator(value: 0.1),
                Image.asset(AppImages.basicInfo),
                SizedBox(height: 24),
                Text(
                  AppTexts.BasicInfo,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
                ),
                SizedBox(height: 24),
                CustomTextfield.textField(
                  controller: controller.name,
                  tittle: 'Your Name',
                  hintText: 'Enter Your Name',
                ),
                CustomTextfield.textField(
                  controller: controller.lastName,
                  tittle: 'Last Name',
                  hintText: 'Enter Your Name',
                ),
                SizedBox(height: 24),
                CustomTextfield.datePickerField(
                  context: context,
                  title: 'Date of Birth',
                  hintText: 'Select your DOB',
                  controller: controller.dobController,
                ),
                SizedBox(height: 24),
                CustomTextfield.dropDown(
                  controller: controller.genderController,
                  title: 'Gender',
                  hintText: 'Select gender',
                  onTap: () {
                    CustomBottomSheet.showOptionsBottomSheet(
                      title: 'Select Gender',
                      options: ['Male', 'Female', 'Other'],
                      context: context,
                      controller: controller.genderController,
                    );
                  },
                  suffixIcon: Icon(Icons.arrow_drop_down),
                ),
                SizedBox(height: 24),
                CustomTextfield.textField(
                  controller: controller.emailController,
                  tittle: 'Your email',
                  hintText: 'Enter your email id',
                ),
                // CustomTextfield.textField(
                //   controller: controller.emailController,
                //   tittle: 'Your email',
                //   hintText: 'Enter your email id',
                // ),
                SizedBox(height: 24),
                Obx(() {
                  final profile = userController.userProfile.value;

                  return CustomTextfield.mobileNumber(
                    title: 'Mobile Number',
                    initialValue: profile?.mobileNumber ?? '',

                    onTap: () {},

                    prefixIcon: Container(
                      alignment: Alignment.center,
                      child: Text(
                        profile?.countryCode ?? '',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  );
                }),

                // CustomTextfield.mobileNumber(
                //
                //   title: 'Mobile Number',
                //
                //   onTap: () {},
                //   prefixIcon: Obx(
                //     () => Container(
                //       alignment: Alignment.center,
                //       child: Text(
                //         userController.userProfile.value?.countryCode ?? '',
                //         style: TextStyle(fontSize: 16),
                //       ),
                //     ),
                //   ),
                // ),
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
                  title: "Save & Next",
                  onTap: () {
                    final countryCode =
                        userController.userProfile.value?.countryCode ?? '';
                    final mobileNumber =
                        userController.userProfile.value?.mobileNumber ?? '';
                    controller.basicInfo(
                      context,
                      countryCode,
                      mobileNumber,
                      fromCompleteScreen: widget.fromCompleteScreens!,
                    );

                    // Navigator.push(
                    //   context,
                    //   MaterialPageRoute(
                    //     builder: (context) => ChooseService(),
                    //   ),
                    // );
                  },
                ),
      ),
    );
  }
}
