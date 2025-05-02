import 'package:flutter/material.dart';
import 'package:hopper/Core/Constants/Colors.dart';
import 'package:hopper/Core/Constants/texts.dart';
import 'package:hopper/Core/Utility/Buttons.dart';
import 'package:hopper/Core/Utility/images.dart';
import 'package:hopper/Presentation/OnBoarding/screens/driverAddress.dart';
import 'package:hopper/Presentation/Authentication/widgets/textFields.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hopper/Presentation/OnBoarding/widgets/bottomNavigation.dart';
import 'package:hopper/Presentation/OnBoarding/widgets/linearProgress.dart';

class BasicInfo extends StatefulWidget {
  const BasicInfo({super.key});

  @override
  State<BasicInfo> createState() => _BasicInfoState();
}

class _BasicInfoState extends State<BasicInfo> {
  TextEditingController dobController = TextEditingController();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: AppColors.commonWhite),
      body: SingleChildScrollView(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 25),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CustomLinearProgress.linearProgressIndicator(value: 0.1),
                Image.asset(AppImages.basicInfo),
                SizedBox(height: 24),
                Text(
                  AppTexts.BasicInfo,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
                ),
                SizedBox(height: 24),
                CustomTextfield.textField(
                  tittle: 'Your Name',
                  hintText: 'Your Date of Birth',
                ),
                SizedBox(height: 24),
                CustomTextfield.datePickerField(
                  context: context,
                  title: 'Date of Birth',
                  hintText: 'Select your DOB',
                  controller: dobController,
                ),
                SizedBox(height: 24),
                CustomTextfield.dropDown(
                  title: 'Gender',
                  hintText: 'Select gender',
                  onTap: () {},
                  suffixIcon: Icon(Icons.arrow_drop_down),
                ),
                SizedBox(height: 24),
                CustomTextfield.textField(
                  tittle: 'Your email',
                  hintText: 'enter your email id',
                ),
                SizedBox(height: 24),
                CustomTextfield.mobileNumber(
                  title: 'Mobile Number',
                  suffixIcon: Icon(Icons.arrow_drop_down),
                  onTap: () {},
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: CustomBottomNavigation.bottomNavigation(
        title: "Save & Next",
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => DriverAddress()),
          );
        },
      ),
    );
  }
}
