import 'dart:async';

import 'package:flutter/material.dart';

import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../Core/Constants/Colors.dart';
import '../../../Core/Constants/log.dart';
import '../../../Core/Utility/Buttons.dart';
import '../../../Core/Utility/images.dart';
import '../controller/otp_controller.dart';
import 'Terms_Screen.dart';
import '../widgets/bottomNavigation.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:get/get.dart';

class OtpScreens extends StatefulWidget {
  final String mobileNumber;
  final String? type;
  final String? emailVerify;
  final String? email;
  const OtpScreens({
    super.key,
    required this.mobileNumber,
    this.type,
    this.email,
    this.emailVerify,
  });

  @override
  State<OtpScreens> createState() => _OtpScreensState();
}

class _OtpScreensState extends State<OtpScreens> {
  final OtpController controller = Get.find<OtpController>();
  TextEditingController otp = TextEditingController(text: "");
  String verifyCode = '';
  final formKey = GlobalKey<FormState>();
  String? otpError;
  bool isButtonDisabled = false;

  StreamController<ErrorAnimationType>? errorController;
  @override
  void dispose() {
    otp.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Obx(
        () =>
            controller.isLoading.value
                ? Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 20,
                      ),
                      child: Column(
                        spacing: 32,
                        children: [
                          Image.asset(AppImages.chat, height: 80, width: 80),

                          Text(
                            textAlign: TextAlign.center,
                            'Enter the 4 digit code sent to you at ********${widget.mobileNumber.substring(widget.mobileNumber.length - 2)}.',
                            style: TextStyle(
                              color: AppColors.commonBlack,
                              fontSize: 24,
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
                              animationDuration: const Duration(
                                milliseconds: 300,
                              ),
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
                              // onCompleted: (value) async {},
                              onChanged: (value) {
                                debugPrint(value);

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
                                style: TextStyle(
                                  color: Colors.red,
                                  fontSize: 14,
                                ),
                                textAlign: TextAlign.center,
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
                            onPressed: () {
                              controller.resendOtp(widget.mobileNumber);
                            },
                            child: Text('Resend code via SMS'),
                          ),
                          TextButton(
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.black,
                            ),
                            onPressed: () {
                              Navigator.pop(context);
                            },
                            child:
                                widget.type == "basicInfo"
                                    ? Text(
                                      'Change Email?',
                                      style: TextStyle(
                                        decoration: TextDecoration.underline,
                                      ),
                                    )
                                    : Text(
                                      'Change Mobile Number?',
                                      style: TextStyle(
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
      ),
      bottomNavigationBar: CommonBottomNavigationBar(
        onBackPressed: () => Navigator.pop(context),
        // onNextPressed: () async {
        //   if (formKey.currentState!.validate()) {
        //     await controller.verifyOtp(context, verifyCode);
        //   } else {
        //     errorController?.add(ErrorAnimationType.shake);
        //   }
        // },
        onNextPressed: () async {
          if (isButtonDisabled) return;

          setState(() {
            otpError = null;
            isButtonDisabled = true;
          });

          if (otp.text.length != 4) {
            errorController?.add(ErrorAnimationType.shake);
            setState(() {
              otpError = 'Please enter a valid 4-digit OTP';
              isButtonDisabled = false;
            });
            return;
          }

          try {
            if (widget.type == "basicInfo" && widget.emailVerify == "Email") {
              await controller.emailVerifyOtp(
                email: widget.email ?? '',
                context,
                verifyCode,
                type: widget.type ?? '',
              );
            } else {
              await controller.verifyOtp(
                context,
                verifyCode,
                type: widget.type ?? '',
              );
            }
          } finally {
            setState(() {
              isButtonDisabled = false;
            });
          }
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
