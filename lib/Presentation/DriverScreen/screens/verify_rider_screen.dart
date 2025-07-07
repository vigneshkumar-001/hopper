import 'dart:async';

import 'package:flutter/material.dart';

import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hopper/Presentation/DriverScreen/screens/ride_stats_screen.dart';
import '../../../Core/Constants/Colors.dart';
import '../../../Core/Constants/log.dart';
import '../../../Core/Utility/Buttons.dart';
import '../../../Core/Utility/images.dart';
import '../../Authentication/widgets/bottomNavigation.dart';

import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:get/get.dart';

class VerifyRiderScreen extends StatefulWidget {
  const VerifyRiderScreen({super.key});

  @override
  State<VerifyRiderScreen> createState() => _VerifyRiderScreenState();
}

class _VerifyRiderScreenState extends State<VerifyRiderScreen> {
  TextEditingController otp = TextEditingController(text: "");
  String verifyCode = '';
  final formKey = GlobalKey<FormState>();
  FocusNode otpFocusNode = FocusNode();

  String? otpError;
  bool isButtonDisabled = false;
  String email = '';
  Color enableColor = AppColors.containerColor1;
  StreamController<ErrorAnimationType>? errorController;
  @override
  void dispose() {
    otp.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 20),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.manual,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 32,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.commonBlack.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Image.asset(
                            AppImages.backButton,
                            height: 25,
                            width: 25,
                          ),
                        ),
                      ),

                      Text(
                        textAlign: TextAlign.center,
                        'Enter the Rebecca’s Verification Code ',
                        style: TextStyle(
                          color: AppColors.commonBlack,
                          fontSize: 25,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      Form(
                        key: formKey,
                        child: PinCodeTextField(
                          autoFocus: true,
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
                          autoDisposeControllers: false,
                          animationType: AnimationType.fade,

                          // validator: (v) {
                          //   if (v == null || v.length != 4)
                          //     return 'Enter valid 4-digit OTP';
                          //   return null;
                          // },
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
                            fieldOuterPadding: EdgeInsets.symmetric(
                              horizontal: 8,
                            ),
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
                          // validator: (value) {
                          //   if (value == null || value.length != 4) {
                          //     return 'Please enter a valid 4-digit OTP';
                          //   }
                          //   return null;
                          // },
                          onCompleted: (value) {},

                          onChanged: (value) {
                            debugPrint(value);
                            setState(() {
                              if (value.length == 4) {
                                enableColor = Colors.black;
                                isButtonDisabled = false;
                              } else {
                                enableColor = AppColors.containerColor1;
                                isButtonDisabled = true;
                              }
                            });
                            verifyCode = value;
                          },
                          beforeTextPaste: (text) {
                            debugPrint("Allowing to paste $text");
                            return true;
                          },
                        ),
                      ),
                      if (otpError != null)
                        Center(
                          child: Text(
                            otpError!,
                            style: TextStyle(color: Colors.red, fontSize: 14),
                            textAlign: TextAlign.center,
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 0),
                child: Buttons.button(
                  borderRadius: 7,
                  buttonColor: enableColor,
                  onTap:
                      isButtonDisabled
                          ? null // disable button tap
                          : () {
                            if (otp.text.length != 4) {
                              errorController?.add(ErrorAnimationType.shake);
                              setState(() {
                                otpError = 'Please enter a valid 4-digit OTP';
                                isButtonDisabled = false;
                              });
                              return;
                            }

                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => RideStatsScreen(),
                              ),
                            );
                          },
                  text: Text('Verify Rebecca'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
