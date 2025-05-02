import 'package:flutter/material.dart';
import 'package:hopper/Core/Constants/Colors.dart';
import 'package:hopper/Core/Constants/texts.dart';
import 'package:hopper/Core/Utility/Buttons.dart';
import 'package:hopper/Core/Utility/images.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:hopper/Presentation/OnBoarding/screens/ninScreens.dart';
import 'package:hopper/Presentation/OnBoarding/screens/takePictureScreen.dart'
    show TakePicture;
import 'package:hopper/Presentation/OnBoarding/widgets/linearProgress.dart';

class ProfilePicAccess extends StatefulWidget {
  const ProfilePicAccess({super.key});

  @override
  State<ProfilePicAccess> createState() => _ProfilePicAccessState();
}

class _ProfilePicAccessState extends State<ProfilePicAccess> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: AppColors.commonWhite),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24),
          child: Column(
            children: [
              CustomLinearProgress.linearProgressIndicator(value: 0.3),
              Image.asset(AppImages.basicInfo),
              SizedBox(height: 24),
              Text(
                'Hello,Oluwaseun Adebayo!',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              Text(AppTexts.hopprtPartnership),
              SizedBox(height: 16),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => TakePicture()),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 32,
                  ),
                  child: DottedBorder(
                    borderType: BorderType.RRect,

                    radius: const Radius.circular(100),
                    dashPattern: const [7, 4],
                    strokeWidth: 1.5,
                    child: Container(
                      height: 150,
                      width: 150,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Color(0xffF8F7F7),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.camera_alt_outlined, size: 30),
                          const SizedBox(height: 10),
                          Text("Take Selfie", style: TextStyle(fontSize: 14)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Spacer(),
              Buttons.button(
                buttonColor: AppColors.commonBlack,
                onTap: () { Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => NinScreens()),
                );},
                text: 'Save & Next',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
