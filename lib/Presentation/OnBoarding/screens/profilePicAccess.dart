import 'package:flutter/material.dart';
import 'package:hopper/Presentation/OnBoarding/controller/basicInfo_controller.dart';
import 'package:hopper/Presentation/OnBoarding/controller/chooseservice_controller.dart';
import 'package:hopper/Presentation/OnBoarding/screens/takePictureScreen.dart';
import '../../../Core/Constants/Colors.dart';
import '../../../Core/Constants/texts.dart';
import '../../../Core/Utility/Buttons.dart';
import '../../../Core/Utility/images.dart';
import 'package:dotted_border/dotted_border.dart';
import '../../../Core/Utility/snackbar.dart';
import 'ninScreens.dart';

import 'package:hopper/Presentation/OnBoarding/widgets/linearProgress.dart';
import 'package:get/get.dart';

class ProfilePicAccess extends StatefulWidget {
  const ProfilePicAccess({super.key});

  @override
  State<ProfilePicAccess> createState() => _ProfilePicAccessState();
}

class _ProfilePicAccessState extends State<ProfilePicAccess> {
  final ChooseServiceController userController = Get.put(
    ChooseServiceController(),
  );
  final BasicInfoController controller = Get.put(BasicInfoController());
  @override
  void initState() {
    super.initState();

    userController.getUserDetails();
    controller.fetchAndSetUserData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Buttons.backButton(context: context),
              SizedBox(height: 24),
              CustomLinearProgress.linearProgressIndicator(value: 0.3),
              Image.asset(AppImages.basicInfo),
              SizedBox(height: 24),
              Center(
                child: Text(
                  maxLines: 1,
                  softWrap: true,
                  overflow: TextOverflow.ellipsis,
                  'Hello,${controller.name.text}${controller.lastName.text}!',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ),
              SizedBox(height: 16),
              Center(child: Text(AppTexts.hopprtPartnership)),
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
                  child: Center(
                    child: DottedBorder(
                      options: RoundedRectDottedBorderOptions(
                        color: const Color(0xff666666).withOpacity(0.3),
                        radius: const Radius.circular(80),
                        dashPattern: const [7, 4],
                        strokeWidth: 1.5,
                      ),
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
              ),
              Spacer(),
              Buttons.button(
                buttonColor: AppColors.commonBlack,
                onTap: () {
                  CustomSnackBar.showInfo('Please take Selfie');
                  // Navigator.push(
                  //   context,
                  //   MaterialPageRoute(builder: (context) => NinScreens()),
                  // );
                },
                text: Text('Save & Next'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
