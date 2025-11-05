import 'dart:ui';
import 'package:country_picker/country_picker.dart';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:flutter/material.dart';
import 'package:hopper/Presentation/Authentication/screens/Otp_Screens.dart';
import 'package:hopper/Presentation/OnBoarding/controller/chooseservice_controller.dart';
import 'package:hopper/Presentation/OnBoarding/screens/ConsentForms.dart';
import 'package:hopper/Presentation/OnBoarding/screens/basicInfo.dart';
import 'package:hopper/Presentation/OnBoarding/screens/carOwnerShip.dart';
import 'package:hopper/Presentation/OnBoarding/screens/driverAddress.dart';
import 'package:hopper/Presentation/OnBoarding/screens/interiorUploadPhotos.dart';
import 'package:hopper/Presentation/OnBoarding/screens/ninScreens.dart';
import 'package:hopper/Presentation/OnBoarding/screens/profilePicAccess.dart';
import 'package:hopper/Presentation/OnBoarding/screens/uploadExteriorPhotos.dart';
import 'package:hopper/Presentation/OnBoarding/screens/vehicleDetails.dart';
import '../../../Core/Constants/Colors.dart';
import '../../../Core/Constants/log.dart';
import '../../../Core/Utility/Buttons.dart';
import '../../../Core/Utility/images.dart';
import '../../OnBoarding/screens/takePictureScreen.dart';
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
  final AuthController controller = Get.put(AuthController());
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final ChooseServiceController chooseServiceController = Get.find();
  String flag = '';

  void showCountrySelector(BuildContext context) {
    showCountryPicker(
      context: context,
      showSearch: true,
      showPhoneCode: true,
      searchAutofocus: true,
      countryListTheme: CountryListThemeData(
        flagSize: 25,
        backgroundColor: Colors.white,
        // textStyle: TextStyle(fontSize: 16, color: Colors.blueGrey),
        bottomSheetHeight: 550, // Optional. Country list modal height
        //Optional. Sets the border radius for the bottomsheet.
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(30.0),
          topRight: Radius.circular(30.0),
        ),
        searchTextStyle: TextStyle(color: Colors.black),
        //Optional. Styles the search field.
        inputDecoration: InputDecoration(
          hintText: 'Search',
          hintStyle: TextStyle(color: Colors.grey),
          prefixIcon: Icon(Icons.search, color: Colors.black),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.black),
            borderRadius: BorderRadius.circular(8),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.black, width: 2),
            borderRadius: BorderRadius.circular(8),
          ),
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),

          border: OutlineInputBorder(
            borderSide: BorderSide(
              color: const Color(0xFF8C98A8).withOpacity(0.2),
            ),
          ),
        ),
      ),
      // countryListTheme: CountryListThemeData(
      //   inputDecoration: InputDecoration(
      //     hintText: 'Search',
      //     hintStyle: TextStyle(color: Colors.grey),
      //     prefixIcon: Icon(Icons.search, color: Colors.black),
      //     enabledBorder: OutlineInputBorder(
      //       borderSide: BorderSide(color: Colors.black),
      //       borderRadius: BorderRadius.circular(8),
      //     ),
      //     focusedBorder: OutlineInputBorder(
      //       borderSide: BorderSide(color: Colors.black, width: 2),
      //       borderRadius: BorderRadius.circular(8),
      //     ),
      //     contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      //   ),
      //
      //   searchTextStyle: TextStyle(color: Colors.black),
      //   // Optional sheet styling
      //   borderRadius: BorderRadius.only(
      //     topLeft: Radius.circular(12),
      //     topRight: Radius.circular(12),
      //   ),
      // ),
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
    return WillPopScope(
      onWillPop: () async {
        return true;
      },
      child: Scaffold(
        body: SafeArea(
          child: Stack(
            children: [
              SingleChildScrollView(
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
                              child: TextFormField(
                                cursorColor: AppColors.commonBlack,
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
                                // validator: (value) {
                                //   final code = controller.selectedCountryCode.value;
                                //
                                //   if (value == null || value.isEmpty) {
                                //     controller.errorText.value = 'Please enter your Mobile Number';
                                //     return ''; // prevents default error message
                                //   } else if (code == '+91' && value.length != 10) {
                                //     controller.errorText.value = 'Indian numbers must be exactly 10 digits';
                                //     return '';
                                //   } else if (code == '+234' && value.length != 10) {
                                //     controller.errorText.value = 'Nigerian numbers must be exactly 10 digits';
                                //     return '';
                                //   }
                                //
                                //   controller.errorText.value = ''; // clear previous error
                                //   return null;
                                // },
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

                        SizedBox(height: 30),
                        Obx(() {
                          return Buttons.button(
                            buttonColor:
                                controller.isLoading.value
                                    ? Colors.white
                                    : Colors.black,
                            onTap: () async {
                              final code = controller.selectedCountryCode.value;
                              final value = controller.mobileNumber.text.trim();

                              // Manual validation
                              if (value.isEmpty) {
                                controller.errorText.value =
                                    'Please enter your Mobile Number';
                                return;
                              } else if (code == '+91' && value.length != 10) {
                                controller.errorText.value =
                                    'Indian numbers must be exactly 10 digits';
                                return;
                              } else if (code == '+234' && value.length != 10) {
                                controller.errorText.value =
                                    'Nigerian numbers must be exactly 10 digits';
                                return;
                              } else {
                                controller.errorText.value = ''; // clear error
                              }

                              // Only call login if validation passes
                              await controller.login(context);
                            },

                            text:
                                controller.isLoading.value
                                    ? Image.asset(AppImages.animation)
                                    : Text('Continue'),
                          );
                        }),

                        // ElevatedButton(
                        //   onPressed: () async {
                        //     Navigator.push(
                        //       context,
                        //       MaterialPageRoute(
                        //         builder: (context) => OtpScreens (mobileNumber: 'mobileNumber'),
                        //       ),
                        //     );
                        //   },
                        //   child: Text('LOG OUT'),
                        // ),
                        SizedBox(height: 30),
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
                          text: Text('Continue with Apple'),
                        ),
                        SizedBox(height: 20),
                        Buttons.button(
                          imgHeight: 18,
                          imgWeight: 18,
                          imagePath: AppImages.google,

                          buttonColor: AppColors.containerColor,
                          textColor: AppColors.commonBlack,

                          onTap: () {
                            initializeGoogleAuth();
                          },
                          text: Text('Continue with Google'),
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

              Obx(() {
                return controller.isGoogleLoading.value
                    ? Positioned.fill(
                      child: Container(
                        color: Colors.black.withOpacity(0.2),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: const Center(
                            child: SpinKitCircle(
                              color: Colors.black45,
                              size: 50.0,
                            ),
                          ),
                        ),
                      ),
                    )
                    : const SizedBox.shrink();
              }),
            ],
          ),
        ),
      ),
    );
  }
}
