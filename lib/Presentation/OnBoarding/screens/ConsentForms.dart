import 'package:flutter/material.dart';
import '../../../Core/Constants/Colors.dart';
import '../../../Core/Constants/texts.dart';
import '../../../Core/Utility/Buttons.dart';
import '../../../Core/Utility/images.dart';
import '../../../Core/Utility/snackbar.dart';
import '../../Authentication/widgets/textFields.dart';
import '../controller/stateList_Controller.dart';
import 'completedScreens.dart';
import '../widgets/bottomNavigation.dart';
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
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Buttons.backButton(context: context),
                SizedBox(height: 24),
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
                        AppImages.redExclamation,
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
      bottomNavigationBar: Obx(() {
        final isLoading = controller.isLoading.value;
        final buttonEnabled = isChecked && !isLoading;

        final buttonColor =
            isLoading
                ? Colors.white
                : isChecked
                ? AppColors.commonBlack
                : AppColors.containerColor;
        return CustomBottomNavigation.bottomNavigation(
          foreGroundColor:
              controller.isLoading.value ? Colors.black : Colors.white,

          title:
              controller.isLoading.value
                  ? Image.asset(AppImages.animation)
                  : Text("Send for Verification"),
          buttonColor: buttonColor,
          onTap: () {
            if (!isChecked) {
              CustomSnackBar.showInfo('Please agree to the terms to proceed.');
              return;
            }
            controller.sendVerification(context);
          },
        );
      }),
    );
  }
}
