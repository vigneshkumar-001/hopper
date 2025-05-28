import 'package:flutter/material.dart';
import 'package:hopper/Core/Constants/Colors.dart';
import 'package:hopper/Core/Constants/log.dart';
import 'package:hopper/Core/Utility/images.dart';
import 'package:hopper/Core/Utility/snackbar.dart';
import 'package:hopper/Presentation/Authentication/screens/processingScreen.dart';
import 'package:hopper/Presentation/OnBoarding/controller/chooseservice_controller.dart';
import 'package:hopper/Presentation/OnBoarding/screens/basicInfo.dart';
import 'package:hopper/Presentation/OnBoarding/screens/chooseService.dart';
import 'package:hopper/Presentation/Authentication/widgets/bottomNavigation.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hopper/Presentation/OnBoarding/screens/processingScreen.dart';
import 'package:get/get.dart';

class TermsScreen extends StatefulWidget {
  const TermsScreen({super.key});

  @override
  State<TermsScreen> createState() => _TermsScreenState();
}

class _TermsScreenState extends State<TermsScreen> {
  final ChooseServiceController controller = Get.find();

  Future<void> getUserDetail() async {
    await controller.getUserDetails();
    controller.getUserDetails();
  }

  @override
  void initState() {
    super.initState();
    getUserDetail();
    // loadAndNavigate();
  }

  bool isChecked = false;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Column(
              spacing: 32,
              children: [
                Center(child: Image.asset(AppImages.terms)),
                Text(
                  textAlign: TextAlign.center,
                  'Accept Hoppr’s Terms & Review Privacy Notice',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                RichText(
                  textAlign: TextAlign.center,
                  text: const TextSpan(
                    style: TextStyle(color: AppColors.textColor, fontSize: 14),
                    children: [
                      TextSpan(text: "By selecting"),
                      TextSpan(
                        text: ' "I Agree" ',
                        style: TextStyle(
                          color: AppColors.commonBlack,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextSpan(
                        text:
                            "below, you indicate that you have reviewed and are in agreement with our terms of use of the platform. You also affirm that you are 18 years of age or older.",
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: CommonBottomNavigationBar(
        height: 120.h,
        onBackPressed: () => Navigator.pop(context),
        onNextPressed: () {
          if (isChecked == false) {
            CustomSnackBar.showInfo('Please Accept terms and condition');
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => ProcessingScreen()),
            );
          }
        },

        backgroundColor: Colors.white,
        buttonColor: Colors.black,
        containerColor: Colors.grey.shade300,
        backButtonImage: AppImages.backButton,
        rightButtonImage: AppImages.rightButton,
        termsAndConditionsText: 'Terms & Conditions',
        isChecked: isChecked,
        onCheckboxChanged: (value) {
          setState(() {
            isChecked = value ?? false;
          });
        },
      ),
    );
  }
}
