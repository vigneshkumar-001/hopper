import 'package:flutter/material.dart';
import '../../Authentication/controller/otp_controller.dart';
import '../../Authentication/screens/Otp_Screens.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:flutter/services.dart';
import '../../../Core/Constants/Colors.dart';
import '../../../Core/Constants/texts.dart';
import '../../../Core/Utility/Buttons.dart';
import '../../../Core/Utility/ModelBottomSheet.dart';
import '../../../Core/Utility/images.dart';
import '../controller/basicInfo_controller.dart';
import '../controller/chooseservice_controller.dart';
import 'chooseService.dart';
import 'completedScreens.dart';
import 'driverAddress.dart';
import '../../Authentication/widgets/textFields.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../widgets/bottomNavigation.dart';
import '../widgets/linearProgress.dart';
import 'package:get/get.dart';
import 'package:country_picker/country_picker.dart';

import '../../Authentication/controller/authController.dart';

class BasicInfo extends StatefulWidget {
  final String? type;
  final bool? fromCompleteScreens;

  const BasicInfo({super.key, this.fromCompleteScreens = false, this.type});

  @override
  State<BasicInfo> createState() => _BasicInfoState();
}

class _BasicInfoState extends State<BasicInfo> {
  TextEditingController dobController = TextEditingController();
  final AuthController authController = Get.put(AuthController());
  final OtpController otpController = Get.put(OtpController(), permanent: true);

  final ChooseServiceController userController = Get.find();
  final BasicInfoController controller = Get.put(BasicInfoController());
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  String flag = '';
  void showCountrySelector(BuildContext) {
    showCountryPicker(
      context: context,
      showPhoneCode: true,
      searchAutofocus: true,
      onSelect: (Country country) {
        authController.setSelectedCountry(country);
      },
    );
  }

  @override
  void initState() {
    super.initState();
    otpController.clearState();
    userController.getUserDetails();
    controller.fetchAndSetUserData();
    authController.selectedCountryCode.value = '+234';
    authController.countryCodeController.text = '+234';
  }

  @override
  Widget build(BuildContext context) {
    final isFromGoogleSignIn = widget.type == 'googleSignIn';
    return Scaffold(
      // appBar: AppBar(backgroundColor: AppColors.commonWhite),
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

                  CustomLinearProgress.linearProgressIndicator(value: 0.1),
                  Image.asset(AppImages.basicInfo),
                  SizedBox(height: 24),
                  Text(
                    AppTexts.BasicInfo,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
                  ),
                  SizedBox(height: 24),
                  CustomTextfield.textField(
                    formKey: _formKey,

                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z]')),
                      LengthLimitingTextInputFormatter(20),
                    ],
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your First Name';
                      } /*else if (value.length != 11) {
                          return 'Must be exactly 11 digits';
                        }*/
                      return null;
                    },
                    controller: controller.name,
                    tittle: 'First Name',
                    hintText: 'Enter First Name',
                  ),
                  SizedBox(height: 24),
                  CustomTextfield.textField(
                    formKey: _formKey,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z]')),
                      LengthLimitingTextInputFormatter(20),
                    ],
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your Last Name';
                      } /*else if (value.length != 11) {
                          return 'Must be exactly 11 digits';
                        }*/
                      return null;
                    },
                    controller: controller.lastName,
                    tittle: 'Last Name',
                    hintText: 'Enter Your Name',
                  ),

                  SizedBox(height: 24),
                  CustomTextfield.datePickerField(
                    formKey: _formKey,
                    onChanged: (value) {
                      _formKey.currentState?.validate();
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please select your DOB';
                      }
                      return null;
                    },
                    context: context,
                    title: 'Date of Birth',
                    hintText: 'Select your DOB',
                    controller: controller.dobController,
                  ),

                  SizedBox(height: 24),
                  CustomTextfield.dropDown(
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please select gender';
                      }
                      return null;
                    },
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
                  Row(
                    children: [
                      Expanded(
                        flex: 4,
                        child: CustomTextfield.textField(
                          readOnly: isFromGoogleSignIn,
                          formKey: _formKey,
                          controller: controller.emailController,
                          tittle: 'Your email',
                          hintText: 'Enter your email id',
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your email Id';
                            }
                            final emailRegex = RegExp(
                              r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                            );
                            if (!emailRegex.hasMatch(value)) {
                              return 'Please enter a valid email address';
                            }
                            return null;
                          },
                        ),
                      ),

                      // if (!isFromGoogleSignIn)
                      //   Expanded(
                      //     child: Padding(
                      //       padding: const EdgeInsets.only(top: 20.0),
                      //       child: Obx(() {
                      //         if (otpController.isVerified.value) {
                      //           return const Center(
                      //             child: Icon(
                      //               Icons.check_circle,
                      //               color: Colors.green,
                      //               size: 32,
                      //             ),
                      //           );
                      //         } else {
                      //           return Container(
                      //             margin: const EdgeInsets.only(
                      //               top: 10,
                      //               left: 5,
                      //               bottom: 1,
                      //               right: 5,
                      //             ),
                      //             decoration: BoxDecoration(
                      //               borderRadius: BorderRadius.circular(5),
                      //               color: AppColors.commonBlack,
                      //             ),
                      //             child: Obx(
                      //               () => TextButton(
                      //                 onPressed:
                      //                     otpController.isVerified.value
                      //                         ? null
                      //                         : () async {
                      //                           await authController
                      //                               .emailLoginOtp(
                      //                                 context,
                      //                                 controller
                      //                                     .emailController
                      //                                     .text,
                      //                                 type: 'basicInfo',
                      //                               );
                      //                         },
                      //
                      //                 child:
                      //                     authController.isLoading.value
                      //                         ? const SizedBox(
                      //                           width: 20,
                      //                           height: 20,
                      //                           child:
                      //                               CircularProgressIndicator(
                      //                                 strokeWidth: 2,
                      //                                 color: Colors.white,
                      //                               ),
                      //                         )
                      //                         : otpController
                      //                             .isEmailVerified
                      //                             .value
                      //                         ? const Icon(
                      //                           Icons.check_circle,
                      //                           color: Colors.green,
                      //                         )
                      //                         : const Text(
                      //                           'Verify',
                      //                           style: TextStyle(
                      //                             color: AppColors.commonWhite,
                      //                           ),
                      //                         ),
                      //               ),
                      //             ),
                      //             /*  TextButton(
                      //               onPressed: () async {
                      //                 final email =
                      //                     controller.emailController.text
                      //                         .trim();
                      //                 if (email.isNotEmpty) {
                      //                   await authController.emailLoginOtp(
                      //                     context,
                      //                     email,
                      //                     type: 'basicInfo',
                      //                   );
                      //                 } else {}
                      //               },
                      //               child:
                      //                   authController.isLoading.value
                      //                       ? const SizedBox(
                      //                         width: 20,
                      //                         height: 20,
                      //                         child: CircularProgressIndicator(
                      //                           strokeWidth: 2,
                      //                           color: Colors.white,
                      //                         ),
                      //                       )
                      //                    : otpController
                      //                 .isEmailVerified
                      //                 .value
                      //             ? const Icon(
                      //             Icons.check_circle,
                      //               color: Colors.green,
                      //             )
                      //                 : const Text(
                      //             'Verify',
                      //             style: TextStyle(color: AppColors.commonWhite),
                      //           ),
                      //             ),*/
                      //           );
                      //         }
                      //       }),
                      //     ),
                      //   ),
                      if (!isFromGoogleSignIn)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 20.0),
                            child: Obx(() {
                              if (otpController.isVerified.value) {
                                // If verified, remove the container completely
                                return const SizedBox.shrink();
                              } else {
                                // Show the verify button container
                                return Container(
                                  margin: const EdgeInsets.only(
                                    top: 10,
                                    left: 5,
                                    bottom: 1,
                                    right: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(5),
                                    color: AppColors.commonBlack,
                                  ),
                                  child: Obx(
                                    () => TextButton(
                                      onPressed:
                                          otpController.isVerified.value
                                              ? null
                                              : () async {
                                                await authController
                                                    .emailLoginOtp(
                                                      context,
                                                      controller
                                                          .emailController
                                                          .text,
                                                      type: 'basicInfo',
                                                    );
                                              },
                                      child:
                                          authController.isLoading.value
                                              ? const SizedBox(
                                                width: 20,
                                                height: 20,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      color: Colors.white,
                                                    ),
                                              )
                                              : otpController
                                                  .isEmailVerified
                                                  .value
                                              ? const Icon(
                                                Icons.check_circle,
                                                color: Colors.green,
                                              )
                                              : const Text(
                                                'Verify',
                                                style: TextStyle(
                                                  color: AppColors.commonWhite,
                                                ),
                                              ),
                                    ),
                                  ),
                                );
                              }
                            }),
                          ),
                        ),
                    ],
                  ),

                  SizedBox(height: 24),

                  Obx(() {
                    final profile = userController.userProfile.value;

                    if (isFromGoogleSignIn == false) {
                      return CustomTextfield.mobileNumber(
                        readOnly: true,
                        title: 'Mobile Number',
                        initialValue: profile?.mobileNumber ?? '',
                        onTap: () {},
                        prefixIcon: Container(
                          alignment: Alignment.center,
                          child: Text(
                            profile?.countryCode ?? '',
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                      );
                    } else {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Mobile Number',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: GestureDetector(
                                  onTap: () => showCountrySelector(context),
                                  child: Obx(
                                    () => Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 15,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xffF1F1F1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Row(
                                        children: [
                                          Text(
                                            // selectedCountryFlag.isEmpty
                                            //     ? '🇳🇬'
                                            //     :
                                            selectedCountryFlag,
                                            style: const TextStyle(
                                              fontSize: 18,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            authController
                                                    .selectedCountryCode
                                                    .value
                                                    .isEmpty
                                                ? '+--'
                                                : authController
                                                    .selectedCountryCode
                                                    .value,
                                            style: const TextStyle(
                                              fontSize: 16,
                                            ),
                                          ),
                                          const Icon(Icons.arrow_drop_down),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 5),
                              Expanded(
                                flex: 4,
                                child: Obx(() {
                                  return TextField(
                                    controller: authController.mobileNumber,
                                    keyboardType: TextInputType.phone,
                                    inputFormatters: [
                                      LengthLimitingTextInputFormatter(10),
                                      FilteringTextInputFormatter.digitsOnly,
                                    ],
                                    decoration: InputDecoration(
                                      hintText: 'Enter mobile number',
                                      errorText: authController.errorText.value.isEmpty
                                          ? null
                                          : authController.errorText.value,
                                      filled: true,
                                      fillColor: const Color(0xffF1F1F1),
                                      border: OutlineInputBorder(
                                        borderSide: BorderSide.none,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      suffixIcon: Obx(() {
                                        if (authController.isLoading.value) {
                                          return const Padding(
                                            padding: EdgeInsets.all(12),
                                            child: SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.black,
                                              ),
                                            ),
                                          );
                                        } else if (otpController.isVerified.value) {
                                          return const Icon(Icons.check_circle, color: Colors.green);
                                        } else {
                                          return TextButton(
                                            onPressed: () async {
                                              await authController.login(context, type: 'basicInfo');
                                            },
                                            child: const Text(
                                              'Verify',
                                              style: TextStyle(fontSize: 12),
                                            ),
                                          );
                                        }
                                      }),
                                    ),
                                    onChanged: (value) {
                                      final code = authController.selectedCountryCode.value;
                                      if (value.isEmpty) {
                                        authController.errorText.value = 'Please enter your Mobile Number';
                                      } else if (code == '+91' && value.length != 10) {
                                        authController.errorText.value = 'Indian numbers must be exactly 10 digits';
                                      } else if (code == '+234' && value.length != 10) {
                                        authController.errorText.value = 'Nigerian numbers must be exactly 10 digits';
                                      } else {
                                        authController.errorText.value = '';
                                      }
                                    },
                                  );
                                }),
                              ),


                            ],
                          ),
                        ],
                      );
                    }
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
                  onTap: () async {
                    if (isFromGoogleSignIn == true) {
                      final countryCode =
                          authController.countryCodeController.text ?? '';
                      final mobileNumber =
                          authController.mobileNumber.text ?? '';
                      if (_formKey.currentState!.validate()) {
                        await controller.basicInfo(
                          context,
                          countryCode,
                          mobileNumber,
                          fromCompleteScreen: widget.fromCompleteScreens!,
                        );
                      }
                    } else {
                      final countryCode =
                          userController.userProfile.value?.countryCode ?? '';
                      final mobileNumber =
                          userController.userProfile.value?.mobileNumber ?? '';
                      if (_formKey.currentState!.validate()) {
                        await controller.basicInfo(
                          context,
                          countryCode,
                          mobileNumber,
                          fromCompleteScreen: widget.fromCompleteScreens!,
                        );
                      }
                    }

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
