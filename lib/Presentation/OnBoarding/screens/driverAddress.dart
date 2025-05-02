import 'package:flutter/material.dart';
import 'package:hopper/Core/Constants/Colors.dart';
import 'package:hopper/Core/Constants/texts.dart';
import 'package:hopper/Core/Utility/Buttons.dart';
import 'package:hopper/Core/Utility/images.dart';
import 'package:hopper/Presentation/OnBoarding/screens/docUploadPic.dart';
import 'package:hopper/Presentation/Authentication/widgets/textFields.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hopper/Presentation/OnBoarding/widgets/bottomNavigation.dart';
import 'package:hopper/Presentation/OnBoarding/widgets/linearProgress.dart';

class DriverAddress extends StatefulWidget {
  const DriverAddress({super.key});

  @override
  State<DriverAddress> createState() => _DriverAddressState();
}

class _DriverAddressState extends State<DriverAddress> {
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
                CustomLinearProgress.linearProgressIndicator(value: 0.2),
                Image.asset(AppImages.basicInfo),
                SizedBox(height: 24),
                Text(
                  AppTexts.driverAddress,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
                ),
                SizedBox(height: 24),
                CustomTextfield.textField(
                  tittle: 'Address',
                  hintText: 'Enter your email id',
                ),
                SizedBox(height: 24),

                CustomTextfield.dropDown(
                  title: 'City',
                  hintText: 'Select City',
                  onTap: () {},
                  suffixIcon: Icon(Icons.arrow_drop_down),
                ),
                SizedBox(height: 24),
                CustomTextfield.dropDown(
                  title: 'State',
                  hintText: 'Select State',
                  onTap: () {},
                  suffixIcon: Icon(Icons.arrow_drop_down),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: CustomBottomNavigation.bottomNavigation(
        title: 'Save & Next',
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => DocUpLoadPic()),
          );
        },
      ),
    );
  }
}
