import 'package:flutter/material.dart';
import 'package:hopper/Core/Constants/Colors.dart';
import 'package:hopper/Core/Utility/Buttons.dart';
import 'package:hopper/Core/Utility/images.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hopper/Presentation/Authentication/screens/Otp_Screens.dart';

class GetStartedScreens extends StatefulWidget {
  const GetStartedScreens({super.key});

  @override
  State<GetStartedScreens> createState() => _GetStartedScreensState();
}

class _GetStartedScreensState extends State<GetStartedScreens> {
  final List<Map<String, String>> filterOptions = [
    {'name': 'Nigeria', 'flag': 'assets/images/Flag.png'},
  ];
  Map<String, String>? selectedValue;

  @override
  void initState() {
    super.initState();
    selectedValue = filterOptions[0];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Column(
              children: [
                Center(child: Image.asset(AppImages.roundCar)),
                SizedBox(height: 20),
                Text(
                  'Get Started with Hoppr',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
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
                      flex: 1,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Color(0xffF1F1F1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 10.w),
                            child: DropdownButton<Map<String, String>>(
                              value: selectedValue,

                              items:
                                  filterOptions.map((country) {
                                    return DropdownMenuItem<
                                      Map<String, String>
                                    >(
                                      value: country,
                                      child: Row(
                                        children: [
                                          Image.asset(
                                            country['flag']!,
                                            width: 24,
                                            height: 24,
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                              onChanged: (newValue) {
                                if (newValue == null) return;

                                setState(() {
                                  selectedValue = newValue;
                                });
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      flex: 4,
                      child: Container(
                        decoration: BoxDecoration(color: Color(0xffF1F1F1)),
                        child: TextField(
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: Colors.black,
                                width: 1.5,
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            hintText: '0000 0000 0000',
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 20,
                            ),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 30),
                Buttons.button(
                  buttonColor: Colors.black,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => OtpScreens()),
                    );
                  },
                  text: 'Continue',
                ),
                SizedBox(height: 30),
                Row(
                  children: [
                    Expanded(
                      child: Divider(
                        endIndent: 5,
                        color: AppColors.dividerColor,
                      ),
                    ),
                    Text('or', style: TextStyle(color: AppColors.dividerColor)),
                    Expanded(
                      child: Divider(indent: 5, color: AppColors.dividerColor),
                    ),
                  ],
                ),
                SizedBox(height: 30),
                Buttons.button(
                  imagePath: AppImages.apple,
                  buttonColor: AppColors.containerColor,
                  textColor: AppColors.commonBlack,

                  onTap: () {},
                  text: 'Continue with Apple',
                ),
                SizedBox(height: 20),
                Buttons.button(
                  imagePath: AppImages.google,
                  buttonColor: AppColors.containerColor,
                  textColor: AppColors.commonBlack,

                  onTap: () {},
                  text: 'Continue with Google',
                ),
                SizedBox(height: 20),
                Buttons.button(
                  imagePath: AppImages.mail,
                  buttonColor: AppColors.containerColor,
                  textColor: AppColors.commonBlack,

                  onTap: () {},
                  text: 'Continue with Mail',
                ),
                SizedBox(height: 30),
                Text(
                  'By proceeding, you consent to get calls, WhatsApp or SMS/RCS messages, including by automated dialler, from Hoppr and its affiliates to the number provided. Text "STOP" to 23453 to opt out.',
                  style: TextStyle(color: AppColors.textColor, fontSize: 12),
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
    );
  }
}
