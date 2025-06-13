import 'package:flutter/material.dart';
import '../../../Core/Constants/Colors.dart';

import '../../../Core/Utility/images.dart';
import '../../../Core/Utility/snackbar.dart';

import '../../OnBoarding/controller/chooseservice_controller.dart';

import '../widgets/bottomNavigation.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../OnBoarding/screens/chooseService.dart';
import '../../OnBoarding/screens/processingScreen.dart';
import 'package:get/get.dart';

class TermsScreen extends StatefulWidget {
  final String? type;
  const TermsScreen({super.key, this.type});

  @override
  State<TermsScreen> createState() => _TermsScreenState();
}

class _TermsScreenState extends State<TermsScreen> {
  final ChooseServiceController controller = Get.find();

  Future<void> getUserDetail() async {
    await controller.getUserDetails();
    controller.getUserDetails();
  }

  Future<void> loadAndNavigate() async {
    await controller.getUserDetails();
    controller.handleLandingPageNavigation(Get.context!);
  }

  @override
  void initState() {
    super.initState();
    getUserDetail();
    //loadAndNavigate();
  }

  bool isChecked = false;
  bool isNextClicked = false;
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
                Center(
                  child: Image.asset(AppImages.terms, height: 80, width: 80),
                ),
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

        // onNextPressed: () {
        //   if (isChecked == false) {
        //     CustomSnackBar.showInfo('Please Accept terms and condition');
        //   } else {
        //     Navigator.push(
        //       context,
        //       MaterialPageRoute(builder: (context) => ChooseService()),
        //     );
        //   }
        // },
        onNextPressed: () {
          if (isChecked && !isNextClicked) {
            setState(() {
              isNextClicked = true;
            });
            final nextPage =
                widget.type == 'googleSignIn'
                    ? ProcessingScreen(type: 'googleSignIn')
                    : ProcessingScreen();
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => nextPage),
            ).then((_) {
              setState(() {
                isNextClicked = false;
              });
            });
          } else if (!isChecked) {
            CustomSnackBar.showInfo('Please Accept terms and condition');
          }
          // else (isNextClicked true) do nothing to disable repeated clicks
        },
        backgroundColor: Colors.white,
        buttonColor:
            isChecked ? AppColors.commonBlack : AppColors.containerColor,

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
