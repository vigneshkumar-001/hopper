import 'dart:ui';
import 'package:country_picker/country_picker.dart';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:flutter/material.dart';
import '../../../Core/Constants/Colors.dart';
import '../../../Core/Constants/log.dart';
import '../../../Core/Utility/Buttons.dart';
import '../../../Core/Utility/images.dart';
import '../controller/authController.dart';


import 'package:google_sign_in/google_sign_in.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class GetStartedScreens extends StatefulWidget {
  const GetStartedScreens({super.key});

  @override
  State<GetStartedScreens> createState() => _GetStartedScreensState();
}

class _GetStartedScreensState extends State<GetStartedScreens> {
  final AuthController controller = Get.find<AuthController>();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  String flag = '';
  void showCountrySelector(BuildContext) {
    showCountryPicker(
      context: context,
      showPhoneCode: true,
      searchAutofocus: true,
      onSelect: (Country country) {
        controller.setSelectedCountry(country);
      },
    );
  }

  @override
  void initState() {
    super.initState();
    controller.selectedCountryCode.value = '+234';
    controller.countryCodeController.text = '+234';
  }

  List<String> scopes = <String>[
    'email',
    'https://www.googleapis.com/auth/contacts.readonly',
  ];

  // GoogleSignIn _googleSignIn = GoogleSignIn(
  //   // Optional clientId
  //   // clientId: 'your-client_id.apps.googleusercontent.com',
  //   scopes: scopes,
  // );
  void initializeGoogleAuth() {
    signInWithGoogle();
  }

  Future<UserCredential?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        print("User canceled sign in");
        return null;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      CommonLogger.log.i('AccessToken: ${googleAuth.accessToken}');
      CommonLogger.log.i('IdToken: ${googleAuth.idToken}');

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await FirebaseAuth.instance
          .signInWithCredential(credential);

      final user = userCredential.user;

      if (user != null) {
        final String uid = user.uid;
        final String? email = user.email;

        CommonLogger.log.i('✅ UID: $uid');
        CommonLogger.log.i('✅ Email: $email');

        // Call your controller to handle insertion
        controller.googleSignInWithFirebase(context, email!, uid);
      }

      return userCredential;
    } catch (e) {
      print('Exception during sign-in: $e');
      return null;
    }
  }

  Future<void> signInWithApple() async {
    if (!Platform.isIOS) {
      CommonLogger.log.i("❌ Apple Sign-In not supported on this platform.");
      return;
    }

    try {
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final oauthCredential = OAuthProvider("apple.com").credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );

      await FirebaseAuth.instance.signInWithCredential(oauthCredential);

      CommonLogger.log.i("✅ Apple Sign-In Success!");
    } catch (e) {
      CommonLogger.log.i("❌ Apple Sign-In Error: $e");
    }
  }

  Future<bool> signOutFromGoogle() async {
    try {
      await FirebaseAuth.instance.signOut();
      return true;
    } on Exception catch (_) {
      return false;
    }
  }

  int get maxPhoneLength {
    String code = controller.selectedCountryCode.value;
    if (code == '+91') return 10;
    if (code == '+234') return 10;
    return 15;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          SingleChildScrollView(
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 20,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      Center(
                        child: Image.asset(
                          AppImages.roundCar,
                          height: 80,
                          width: 80,
                        ),
                      ),
                      SizedBox(height: 20),
                      Text(
                        'Get Started with Hoppr',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 24,
                        ),
                      ),
                      SizedBox(height: 30),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Mobile number'),
                      ),
                      SizedBox(height: 5),

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
                                        selectedCountryFlag.isEmpty
                                            ? '🇳🇬'
                                            : selectedCountryFlag,
                                        style: const TextStyle(fontSize: 18),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        controller
                                                .selectedCountryCode
                                                .value
                                                .isEmpty
                                            ? '+--'
                                            : controller
                                                .selectedCountryCode
                                                .value,
                                        style: const TextStyle(fontSize: 16),
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
                            child: TextField(
                              controller: controller.mobileNumber,
                              keyboardType: TextInputType.phone,
                              inputFormatters: [
                                LengthLimitingTextInputFormatter(10),
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              decoration: InputDecoration(
                                hintText: 'Enter mobile number',
                                filled: true,
                                fillColor: const Color(0xffF1F1F1),
                                border: OutlineInputBorder(
                                  borderSide: BorderSide.none,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              onChanged: (value) {
                                final code =
                                    controller.selectedCountryCode.value;
                                if (value.isEmpty) {
                                  controller.errorText.value =
                                      'Please enter your Mobile Number';
                                } else if (code == '+91' &&
                                    value.length != 10) {
                                  controller.errorText.value =
                                      'Indian numbers must be exactly 10 digits';
                                } else if (code == '+234' &&
                                    value.length != 10) {
                                  controller.errorText.value =
                                      'Nigerian numbers must be exactly 10 digits';
                                } else {
                                  controller.errorText.value = '';
                                }
                              },
                            ),
                          ),
                        ],
                      ),

                      Obx(
                        () =>
                            controller.errorText.value.isNotEmpty
                                ? Align(
                                  alignment: Alignment.centerRight,
                                  child: Text(
                                    controller.errorText.value,
                                    style: const TextStyle(
                                      color: Colors.red,
                                      fontSize: 10,
                                    ),
                                  ),
                                )
                                : const SizedBox(),
                      ),

                      /*     Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xffF1F1F1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: IntlPhoneField(
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                ),
                                initialCountryCode: 'NG',
                                onCountryChanged: (country) {
                                  selectedCountryFlag = country.flag;
                                  flag = country.dialCode;
                                  controller.selectedCountryCode.value =
                                      '+${country.dialCode}';
                                  controller.countryCodeController.text =
                                      '+${country.dialCode}';
                                  print(
                                    'Selected Country Code: +${country.dialCode}',
                                  );
                                  print('Selected flag ${flag}');
                                },
                                onChanged: (phone) {
                                  controller.selectedCountryCode.value =
                                      '+${phone.countryCode}';
                                  controller.mobileNumber.text = phone.number;
                                  print('Full Number: ${phone.completeNumber}');
                                  print('Country Code: ${phone.countryCode}');
                                },

                                disableLengthCheck: true,
                                showDropdownIcon: true,
                                showCountryFlag: true,
                                dropdownIconPosition: IconPosition.trailing,
                              ),
                            ),
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            flex: 4,
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xffF1F1F1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                              ),
                              alignment: Alignment.centerLeft,
                              child: TextFormField(
                                // maxLength: 10,

                                // validator: (value) {
                                //   String code = controller.selectedCountryCode.value;
                                //   if (value == null || value.isEmpty) {
                                //     return 'Please enter your Mobile Number';
                                //   }
                                //   if (code == '+91' && value.length != 10) {
                                //     return 'Indian numbers must be exactly 10 digits';
                                //   } else if (code == '+234' && value.length != 11) {
                                //     return 'Nigerian numbers must be exactly 11 digits';
                                //   }
                                //
                                //   return null;
                                //   // else if (value.length != 11) {
                                //   //   return 'NIN must be exactly 11 digits';
                                //   // }
                                //   return null;
                                // },
                                controller: controller.mobileNumber,
                                onChanged: (value) {
                                  String code =
                                      controller.selectedCountryCode.value;
                                  if (value.isEmpty) {
                                    controller.errorText.value =
                                        'Please enter your Mobile Number';
                                  } else if (code == '+91' &&
                                      value.length != 10) {
                                    controller.errorText.value =
                                        'Indian numbers must be exactly 10 digits';
                                  } else if (code == '+234' &&
                                      value.length != 10) {
                                    controller.errorText.value =
                                        'Nigerian numbers must be exactly 10 digits';
                                  } else {
                                    controller.errorText.value = '';
                                  }
                                  _formKey.currentState?.validate();
                                },
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  LengthLimitingTextInputFormatter(
                                    maxPhoneLength,
                                  ),
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                decoration: InputDecoration(
                                  hintText: '0000 000 000',

                                  border: InputBorder.none,
                                ),
                                style: TextStyle(color: Colors.black),
                              ),
                            ),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Obx(
                            () =>
                                controller.errorText.value.isNotEmpty
                                    ? Text(
                                      controller.errorText.value,
                                      style: const TextStyle(
                                        color: Colors.red,
                                        fontSize: 12,
                                      ),
                                    )
                                    : const SizedBox(),
                          ),
                        ],
                      ),*/
                      SizedBox(height: 30),
                      Obx(() {
                        return controller.isLoading.value
                            ? const Center(child: CircularProgressIndicator())
                            : Buttons.button(
                              buttonColor: Colors.black,
                              onTap: () async {
                                if (_formKey.currentState!.validate()) {
                                  await controller.login(context);
                                  // Navigator.push(
                                  //   context,
                                  //   MaterialPageRoute(
                                  //     builder:
                                  //         (context) => OtpScreens(
                                  //           mobileNumber:
                                  //               controller.mobileNumber.text.trim(),
                                  //         ),
                                  //   ),
                                  // );
                                }
                              },
                              text: 'Continue',
                            );
                      }),
                      SizedBox(height: 30),
                      // ElevatedButton(
                      //   onPressed: () async {
                      //     Navigator.push(
                      //       context,
                      //       MaterialPageRoute(
                      //         builder: (context) => VehicleDetails(),
                      //       ),
                      //     );
                      //   },
                      //   child: Text('LOG OUT'),
                      // ),
                      // SizedBox(height: 30),
                      Row(
                        children: [
                          Expanded(
                            child: Divider(
                              endIndent: 5,
                              color: AppColors.dividerColor,
                            ),
                          ),
                          Text(
                            'or',
                            style: TextStyle(color: AppColors.dividerColor),
                          ),
                          Expanded(
                            child: Divider(
                              indent: 5,
                              color: AppColors.dividerColor,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 30),
                      Buttons.button(
                        imagePath: AppImages.apple,
                        buttonColor: AppColors.containerColor,
                        textColor: AppColors.commonBlack,

                        onTap: () {
                          signInWithApple();
                        },
                        text: 'Continue with Apple',
                      ),
                      SizedBox(height: 20),
                      Buttons.button(
                        imagePath: AppImages.google,
                        buttonColor: AppColors.containerColor,
                        textColor: AppColors.commonBlack,

                        onTap: () {
                          initializeGoogleAuth();
                        },
                        text: 'Continue with Google',
                      ),

                      // SizedBox(height: 20),
                      // Buttons.button(
                      //   imagePath: AppImages.mail,
                      //   buttonColor: AppColors.containerColor,
                      //   textColor: AppColors.commonBlack,
                      //
                      //   onTap: () {},
                      //   text: 'Continue with Mail',
                      // ),
                      SizedBox(height: 40),
                      Text(
                        'By proceeding, you consent to get calls, WhatsApp or SMS/RCS messages, including by automated dialler, from Hoppr and its affiliates to the number provided. Text "STOP" to 23453 to opt out.',
                        style: TextStyle(
                          color: AppColors.textColor,
                          fontSize: 12,
                        ),
                      ),
                      SizedBox(height: 30),

                      RichText(
                        text: const TextSpan(
                          style: TextStyle(color: Colors.black, fontSize: 12),
                          children: [
                            TextSpan(
                              text:
                                  "This site is protected by reCAPTCHA and the Google ",
                            ),
                            TextSpan(
                              text: "Privacy Policy ",
                              style: TextStyle(
                                color: Color(0xff686868),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            TextSpan(text: " and "),
                            TextSpan(
                              text: "Terms of Service",
                              style: TextStyle(
                                color: Color(0xff686868),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            TextSpan(text: " apply"),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          Obx(() {
            return controller.isGoogleLoading.value
                ? Positioned.fill(
                  child: Container(
                    color: Colors.black.withOpacity(0.2),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: const Center(
                        child: SpinKitCircle(color: Colors.black45, size: 50.0),
                      ),
                    ),
                  ),
                )
                : const SizedBox.shrink();
          }),
        ],
      ),
    );
  }
}
