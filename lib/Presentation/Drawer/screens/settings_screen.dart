import 'package:flutter/material.dart';
import 'package:hopper/Core/Utility/images.dart';

import '../../../Core/Constants/Colors.dart';
import '../../Authentication/widgets/textfields.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          physics: BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                color: AppColors.settingsClr,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 15,
                    vertical: 25,
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Image.asset(
                              AppImages.backButton,
                              height: 19,
                              width: 19,
                            ),
                          ),
                          const Spacer(),
                          CustomTextfield.textWithStyles700(
                            'Settings',
                            fontSize: 20,
                          ),
                          const Spacer(),
                        ],
                      ),
                      SizedBox(height: 40),
                      Row(
                        children: [
                          Expanded(
                            flex: 4,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CustomTextfield.textWithStyles700(
                                  'Michael Francis',
                                ),
                                SizedBox(height: 5),
                                Row(
                                  children: [
                                    CustomTextfield.textWithStyles700(
                                      'View Profile',
                                      fontSize: 12,
                                    ),
                                    SizedBox(width: 10),
                                    Image.asset(
                                      AppImages.rightArrow,
                                      height: 20,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          Expanded(
                            flex: 1,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                CircleAvatar(
                                  radius: 33,
                                  backgroundColor: Colors.white,
                                  child: ClipOval(
                                    child: Image.asset(
                                      AppImages.dummy,
                                      height: 60,
                                      width: 60,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                SizedBox(height: 2),
                                Container(
                                  decoration: BoxDecoration(
                                    color: AppColors.commonWhite,
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 5,
                                    ),
                                    child: CustomTextfield.textWithImage(
                                      fontWeight: FontWeight.w700,
                                      colors: AppColors.commonBlack,
                                      imageColors: AppColors.drkGreen,
                                      text: '4.5',
                                      imagePath: AppImages.starFill,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 5),
              settingsList(image: AppImages.doc, title: 'Documents'),
              settingsList(image: AppImages.sCar, title: 'Vehicles'),
              settingsList(image: AppImages.currencyRound, title: 'Payments'),
              settingsList(image: AppImages.loc, title: 'Saved Places'),
              settingsList(
                image: AppImages.filter,
                title: 'Driver Preferences',
              ),
              settingsList(image: AppImages.call, title: 'Emergency Contacts'),
              settingsList(image: AppImages.help, title: 'Help & Support'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Icon(Icons.logout, color: AppColors.red),
                    SizedBox(width: 10),
                    CustomTextfield.textWithStyles600(
                      'Logout',
                      color: AppColors.red,
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget settingsList({required String title, required String image}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
      child: Column(
        children: [
          Row(
            children: [
              Image.asset(image, height: 20),
              SizedBox(width: 10),
              CustomTextfield.textWithStyles600(title),
              Spacer(),
              Image.asset(AppImages.rightArrow, height: 20),
            ],
          ),
          SizedBox(height: 20),
          Divider(color: AppColors.containerColor1),
        ],
      ),
    );
  }
}
