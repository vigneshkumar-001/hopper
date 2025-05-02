import 'dart:async';

import 'package:flutter/material.dart';

import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hopper/Core/Constants/Colors.dart';
import 'package:hopper/Core/Utility/Buttons.dart';
import 'package:hopper/Core/Utility/images.dart';
import 'package:hopper/Presentation/Authentication/screens/Terms_Screen.dart';
import 'package:hopper/Presentation/Authentication/widgets/bottomNavigation.dart';
import 'package:pin_code_fields/pin_code_fields.dart';

class OtpScreens extends StatefulWidget {
  const OtpScreens({super.key});

  @override
  State<OtpScreens> createState() => _OtpScreensState();
}

class _OtpScreensState extends State<OtpScreens> {
  TextEditingController otp = TextEditingController();
  String verifyCode = '';
  final formKey = GlobalKey<FormState>();
  StreamController<ErrorAnimationType>? errorController;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Column(
            spacing: 32,
            children: [
              Image.asset(AppImages.chat),

              Text(
                textAlign: TextAlign.center,
                'Enter the 4 digit code sent to you at ********54.',
                style: TextStyle(
                  color: AppColors.commonBlack,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),

              Form(
                key: formKey,
                child: PinCodeTextField(
                  appContext: context,
                  // pastedTextStyle: TextStyle(
                  //   color: Colors.green.shade600,
                  //   fontWeight: FontWeight.bold,
                  // ),
                  length: 4,

                  // obscureText: true,
                  // obscuringCharacter: '*',
                  // obscuringWidget: const FlutterLogo(size: 24,),
                  blinkWhenObscuring: true,
                  mainAxisAlignment: MainAxisAlignment.center,

                  animationType: AnimationType.fade,
                  validator: (v) {},
                  pinTheme: PinTheme(
                    shape: PinCodeFieldShape.box,
                    borderRadius: BorderRadius.circular(4.sp),
                    fieldHeight: 48.sp,
                    fieldWidth: 48.sp,
                    selectedColor: AppColors.commonBlack,
                    activeColor: AppColors.containerColor,
                    activeFillColor: AppColors.containerColor,
                    inactiveColor: AppColors.containerColor,
                    selectedFillColor: AppColors.containerColor,
                    fieldOuterPadding: EdgeInsets.symmetric(horizontal: 8),
                    inactiveFillColor: AppColors.containerColor,
                  ),
                  cursorColor: Colors.black,
                  animationDuration: const Duration(milliseconds: 300),
                  enableActiveFill: true,
                  errorAnimationController: errorController,
                  controller: otp,
                  keyboardType: TextInputType.number,
                  boxShadows: const [
                    BoxShadow(
                      offset: Offset(0, 1),
                      color: Colors.black12,
                      blurRadius: 5,
                    ),
                  ],
                  onCompleted: (v) {},
                  onChanged: (value) {
                    debugPrint(value);
                    setState(() {
                      verifyCode = value;
                    });
                  },
                  beforeTextPaste: (text) {
                    debugPrint("Allowing to paste $text");
                    return true;
                  },
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  backgroundColor: AppColors.containerColor,
                  foregroundColor: Colors.black,
                  textStyle: TextStyle(fontWeight: FontWeight.bold),

                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                onPressed: () {},
                child: Text('Resend code via SMS'),
              ),
              TextButton(
                style: TextButton.styleFrom(foregroundColor: Colors.black),
                onPressed: () {},
                child: const Text(
                  'Change Mobile Number?',
                  style: TextStyle(decoration: TextDecoration.underline),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: CommonBottomNavigationBar(
        onBackPressed: () => Navigator.pop(context),
        onNextPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => TermsScreen()),
          );
        },

        backgroundColor: Colors.white,
        buttonColor: Colors.black,
        containerColor: Colors.grey.shade300,
        backButtonImage: AppImages.backButton,
        rightButtonImage: AppImages.rightButton,
      ),
    );
  }
}

// Padding(
// padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
// child: BottomAppBar(
// color: Colors.white,
// child: Row(
// mainAxisAlignment: MainAxisAlignment.spaceBetween,
// children: [
// InkWell(
// onTap: () {
// Navigator.pop(context);
// },
// child: Container(
// height: 52,
// width: 52,
// decoration: BoxDecoration(
// color: AppColors.containerColor,
// borderRadius: BorderRadius.circular(30),
// ),
// child: Image.asset(AppImages.backButton),
// ),
// ),
// SizedBox(
// width: 112,
// height: 52,
// child: ElevatedButton(
// style: ElevatedButton.styleFrom(
// elevation: 0,
// foregroundColor: AppColors.commonWhite,
// backgroundColor: AppColors.commonBlack,
// ),
// onPressed: () {
// Navigator.push(context, MaterialPageRoute(builder: (context)=>TermsScreen()));
// },
// child: Row(
// children: [
// Text('Next', style: TextStyle(fontSize: 14)),
// Spacer(),
// Image.asset(AppImages.rightButton, height: 30, width: 30),
// ],
// ),
// ),
// ),
// ],
// ),
// ),
// ),
