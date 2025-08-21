import 'dart:async';

import 'package:flutter/material.dart';

import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hopper/Presentation/DriverScreen/controller/driver_status_controller.dart';
import 'package:hopper/Presentation/DriverScreen/screens/driver_main_screen.dart';
import 'package:hopper/Presentation/DriverScreen/screens/ride_stats_screen.dart';
import 'package:hopper/dummy_screen.dart';
import '../../../Core/Constants/Colors.dart';
import '../../../Core/Constants/log.dart';
import '../../../Core/Utility/Buttons.dart';
import '../../../Core/Utility/app_loader.dart';
import '../../../Core/Utility/images.dart';
import '../../Authentication/widgets/bottomNavigation.dart';

import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:get/get.dart';

class VerifyRiderScreen extends StatefulWidget {
  final String bookingId;
  final String custName;
  final String? pickupAddress;
  final String? dropAddress;
  const VerifyRiderScreen({
    super.key,
    required this.bookingId,
    required this.custName,
    this.pickupAddress,
    this.dropAddress,
  });

  @override
  State<VerifyRiderScreen> createState() => _VerifyRiderScreenState();
}

class _VerifyRiderScreenState extends State<VerifyRiderScreen> {
  final TextEditingController otp = TextEditingController(text: "");
  String verifyCode = '';
  final formKey = GlobalKey<FormState>();
  FocusNode otpFocusNode = FocusNode();
  final DriverStatusController driverStatusController =
      DriverStatusController();
  String? otpError;
  bool isButtonDisabled = false;
  String email = '';
  bool otpVerified = false;

  Color enableColor = AppColors.containerColor1;
  late StreamController<ErrorAnimationType> errorController;

  @override
  void initState() {
    super.initState();

    errorController = StreamController<ErrorAnimationType>.broadcast();
  }

  bool _isNavigating = false;

  @override
  void dispose() {
    if (!_isNavigating) {
      otp.dispose();
      otpFocusNode.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          child: Obx(() {
            return driverStatusController.isLoading.value
                ? Center(child: AppLoader.appLoader())
                : Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 15,
                    vertical: 20,
                  ),
                  child: Column(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
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
                                'Enter the ${widget.custName}’s Verification Code ',
                                style: TextStyle(
                                  color: AppColors.commonBlack,
                                  fontSize: 25,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),

                              /*   Form(
                                key: formKey,
                                child: PinCodeTextField(
                                  autoFocus: true,
                                  focusNode: otpFocusNode,
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
                                  // onCompleted: (value) {},
                                  // onChanged: (value) {
                                  //   debugPrint(value);
                                  //   setState(() {
                                  //     if (value.length == 4) {
                                  //       enableColor = Colors.black;
                                  //       isButtonDisabled = true;
                                  //     } else {
                                  //       enableColor = AppColors.containerColor1;
                                  //       isButtonDisabled = false;
                                  //     }
                                  //   });
                                  //   verifyCode = value;
                                  // },
                                  onChanged: (value) {
                                    debugPrint(value);
                                    setState(() {
                                      verifyCode = value;

                                      if (value.isEmpty) {
                                        otpError = "Please enter the OTP";
                                        enableColor = AppColors.containerColor1;
                                        isButtonDisabled = true;
                                      } else if (value.length != 4) {
                                        otpError = "OTP must be 4 digits";
                                        enableColor = AppColors.containerColor1;
                                        isButtonDisabled = true;
                                      } else {
                                        otpError = null;
                                        enableColor = Colors.black;
                                        isButtonDisabled = false;
                                      }
                                    });
                                  },

                                  beforeTextPaste: (text) {
                                    debugPrint("Allowing to paste $text");
                                    return true;
                                  },
                                ),
                              ),*/
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Form(
                                    key: formKey,
                                    child: PinCodeTextField(
                                      errorAnimationController: errorController,
                                      autoDisposeControllers: false,
                                      textStyle: TextStyle(
                                        fontSize: 20,
                                        color:
                                            otpError != null
                                                ? AppColors.red
                                                : Colors.black,
                                        fontWeight: FontWeight.bold,
                                      ),

                                      autoFocus: !otpVerified,

                                      autoDismissKeyboard: true,
                                      focusNode: otpFocusNode,
                                      appContext: context,
                                      length: 4,
                                      blinkWhenObscuring: true,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,

                                      animationType: AnimationType.fade,
                                      controller: otp,
                                      keyboardType: TextInputType.number,
                                      enableActiveFill: true,

                                      cursorColor: Colors.black,
                                      animationDuration: const Duration(
                                        milliseconds: 300,
                                      ),
                                      boxShadows: const [
                                        BoxShadow(
                                          offset: Offset(0, 1),
                                          color: Colors.black12,
                                          blurRadius: 5,
                                        ),
                                      ],
                                      pinTheme: PinTheme(
                                        shape: PinCodeFieldShape.box,
                                        borderRadius: BorderRadius.circular(
                                          4.sp,
                                        ),
                                        fieldHeight: 48.sp,
                                        fieldWidth: 48.sp,
                                        selectedColor:
                                            otpError != null
                                                ? AppColors.red
                                                : AppColors.commonBlack,
                                        activeColor:
                                            otpError != null
                                                ? AppColors.red
                                                : AppColors.containerColor,
                                        activeFillColor:
                                            otpError != null
                                                ? Colors.transparent
                                                : AppColors.containerColor,
                                        inactiveColor:
                                            otpError != null
                                                ? AppColors.red
                                                : AppColors.containerColor,
                                        selectedFillColor:
                                            otpError != null
                                                ? Colors.transparent
                                                : AppColors.containerColor,
                                        inactiveFillColor:
                                            otpError != null
                                                ? Colors.transparent
                                                : AppColors.containerColor,
                                        fieldOuterPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 10,
                                            ),
                                      ),
                                      onChanged: (value) {
                                        debugPrint(value);
                                        setState(() {
                                          verifyCode = value;

                                          if (value.isEmpty) {
                                            otpError = "Please enter the OTP";
                                            enableColor =
                                                AppColors.containerColor1;
                                            isButtonDisabled = true;
                                          } else {
                                            otpError = null;
                                            enableColor = Colors.black;
                                            isButtonDisabled = false;
                                          }
                                        });
                                      },
                                      beforeTextPaste: (text) {
                                        debugPrint("Allowing to paste $text");
                                        return true;
                                      },
                                    ),
                                  ),

                                  // 🔴 Show error directly below the OTP field
                                  if (otpError != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Text(
                                        otpError!,
                                        style: TextStyle(
                                          color: AppColors.red,
                                          fontSize: 14,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      //
                      // Padding(
                      //   padding: const EdgeInsets.symmetric(horizontal: 0),
                      //   child: Buttons.button(
                      //     borderRadius: 7,
                      //     buttonColor: enableColor,
                      //     onTap:
                      //         isButtonDisabled
                      //             ? null
                      //             : () async {
                      //               if (otp.text.length != 4) {
                      //                 errorController?.add(
                      //                   ErrorAnimationType.shake,
                      //                 );
                      //                 setState(() {
                      //                   otpError =
                      //                       'Please enter a valid 4-digit OTP';
                      //                   isButtonDisabled = false;
                      //                 });
                      //                 return;
                      //               }
                      //
                      //               final enteredOtp = otp.text;
                      //               await driverStatusController.otpInsert(
                      //                 context,
                      //                 bookingId: '574636',
                      //                 otp: enteredOtp,
                      //               );
                      //             },
                      //     text: Text('Verify Rebecca'),
                      //   ),
                      // ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 0),
                        child: Buttons.button(
                          borderRadius: 7,
                          buttonColor: enableColor,

                          /*                          onTap: () async {
                            final enteredOtp = otp.text.trim();

                            if (enteredOtp.isEmpty || enteredOtp.length != 4) {
                              setState(() {
                                otpError =
                                    enteredOtp.isEmpty
                                        ? "Please enter the OTP"
                                        : "OTP must be 4 digits";
                              });
                              return;
                            }

                            // ✅ 1. Hide keyboard
                            FocusScope.of(context).unfocus();

                            // ✅ 2. Wait for keyboard to close
                            await Future.delayed(Duration(milliseconds: 200));

                            // ✅ 3. Insert OTP
                            final result = await driverStatusController
                                .otpInsert(
                                  context,
                                  bookingId: '574636',
                                  otp: enteredOtp,
                                );

                            if (result != null) {
                              // ✅ 4. Prevent autofocus next time
                              otpVerified = true;

                              // ✅ 5. Wait for UI to settle
                              await Future.delayed(Duration(milliseconds: 100));

                              // ✅ 6. Navigate
                              if (mounted) {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => RideStatsScreen(),
                                  ),
                                );
                              }
                            }
                          },*/
                          onTap: () async {
                            final enteredOtp = otp.text.trim();

                            if (enteredOtp.isEmpty) {
                              setState(() {
                                otpError = "Please enter the OTP";
                              });
                              return;
                            } else if (enteredOtp.length != 4) {
                              setState(() {
                                otpError = "OTP must be 4 digits";
                              });
                              return;
                            }

                            setState(() {
                              otpError = null; // Clear previous error
                            });

                            // await driverStatusController.otpInsert(
                            //   context,
                            //   bookingId: '574636',
                            //   otp: enteredOtp,
                            // );
                            final result = await driverStatusController
                                .otpInsert(
                                  context,
                                  bookingId: widget.bookingId,
                                  otp: enteredOtp,
                                );

                            if (result != null) {
                              // ✅ 4. Prevent autofocus next time
                              otpVerified = true;

                              // ✅ 5. Wait for UI to settle
                              await Future.delayed(Duration(milliseconds: 100));

                              // ✅ 6. Navigate
                              if (mounted) {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (_) => RideStatsScreen(
                                          pickupAddress  : widget.pickupAddress,
                                          dropAddress     : widget.dropAddress,
                                          bookingId: widget.bookingId,
                                        ),
                                  ),
                                );
                              }
                            }
                          },
                          text: Text('Verify ${widget.custName}'),
                        ),
                      ),
                    ],
                  ),
                );
          }),
        ),
      ),
    );
  }
}
