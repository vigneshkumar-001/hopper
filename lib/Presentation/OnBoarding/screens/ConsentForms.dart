import 'package:flutter/material.dart';
import 'package:hopper/Core/Constants/Colors.dart';
import 'package:hopper/Core/Constants/texts.dart';
import 'package:hopper/Core/Utility/images.dart';
import 'package:hopper/Core/Utility/snackbar.dart';
import 'package:hopper/Presentation/Authentication/widgets/textFields.dart';
import 'package:hopper/Presentation/OnBoarding/controller/stateList_Controller.dart';
import 'package:hopper/Presentation/OnBoarding/screens/completedScreens.dart';
import 'package:hopper/Presentation/OnBoarding/widgets/bottomNavigation.dart';
import 'package:get/get.dart';

class ConsentForms extends StatefulWidget {
  const ConsentForms({super.key});

  @override
  State<ConsentForms> createState() => _ConsentFormsState();
}

class _ConsentFormsState extends State<ConsentForms> {
  final StateListController controller = Get.find();
  @override
  void initState() {
    super.initState();
  }

  bool isChecked = false;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: AppColors.commonWhite),
      body: SingleChildScrollView(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Image.asset(AppImages.consent),
                SizedBox(height: 24),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  decoration: BoxDecoration(
                    color: Color(0xff3B82F4).withOpacity(0.1),
                    border: Border.all(color: Color(0xff3B82F4)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Image.asset(
                        AppImages.exclamationCircle,
                        width: 20,
                        height: 20,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Check your document'),
                            Text(
                              'Ensure all submitted documents are valid and current.',
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xff546E7A),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 24),
                Divider(),
                SizedBox(height: 24),
                Text(
                  'Consent',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 20),
                Text(AppTexts.consentContent),
                SizedBox(height: 15),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.containerColor1,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Required Documents Verification:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        SizedBox(height: 15),
                        CustomTextfield.concatenateText(
                          title: AppTexts.consentContent1,
                        ),
                        CustomTextfield.concatenateText(
                          title: AppTexts.consentContent2,
                        ),
                        CustomTextfield.concatenateText(
                          title: AppTexts.consentContent3,
                        ),
                        CustomTextfield.concatenateText(
                          title: AppTexts.consentContent4,
                        ),
                        CustomTextfield.concatenateText(
                          title: AppTexts.consentContent5,
                        ),
                        CustomTextfield.concatenateText(
                          title: AppTexts.consentContent6,
                        ),
                        CustomTextfield.concatenateText(
                          title: AppTexts.consentContent7,
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 24),
                Text(
                  AppTexts.iHereByConfirmAndAgree,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                SizedBox(height: 15),
                CustomTextfield.concatenateText(
                  title: AppTexts.consentAgreeContent1,
                ),
                CustomTextfield.concatenateText(
                  title: AppTexts.consentAgreeContent2,
                ),
                CustomTextfield.concatenateText(
                  title: AppTexts.consentAgreeContent3,
                ),
                CustomTextfield.concatenateText(
                  title: AppTexts.consentAgreeContent4,
                ),
                CustomTextfield.concatenateText(
                  title: AppTexts.consentAgreeContent5,
                ),
                SizedBox(height: 15),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  decoration: BoxDecoration(
                    color: Color(0xffEA4335).withOpacity(0.1),
                    border: Border.all(color: Color(0xffEA4335)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Image.asset(
                        AppImages.exclamationCircle,
                        width: 20,
                        height: 20,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(AppTexts.importantNotice),
                            Text(
                              AppTexts.consentAgreement,
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xff546E7A),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 15),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CheckboxTheme(
                      data: CheckboxThemeData(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        side: BorderSide(color: AppColors.checkBox, width: 2),
                      ),
                      child: Checkbox(
                        value: isChecked,
                        onChanged: (bool? value) {
                          setState(() {
                            isChecked = value ?? false;
                          });
                        },
                        activeColor: Colors.blue,
                        checkColor: Colors.white,
                      ),
                    ),

                    Expanded(
                      child: Text(
                        AppTexts.consentCheckBoxContent,
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
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
                  title: "Send for Verification",
                  onTap: () {
                    if (!isChecked) {
                      CustomSnackBar.showInfo('Please agree to the terms to proceed.');
                      // ScaffoldMessenger.of(context).showSnackBar(
                      //   SnackBar(
                      //     content: Text("Please agree to the terms to proceed."),
                      //     backgroundColor: Colors.red,
                      //   ),
                      // );
                      return;
                    }
                    controller.sendVerification(context);
                  },
                ),
      ),
    );
  }
}
