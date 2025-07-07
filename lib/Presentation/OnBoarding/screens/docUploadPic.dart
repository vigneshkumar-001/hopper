import 'package:flutter/material.dart';
import 'package:hopper/Presentation/OnBoarding/controller/basicInfo_controller.dart';
import 'package:hopper/Presentation/OnBoarding/controller/chooseservice_controller.dart';
import '../../../Core/Constants/Colors.dart';
import '../../../Core/Constants/texts.dart';
import '../../../Core/Utility/Buttons.dart';
import '../../../Core/Utility/images.dart';
import 'ninScreens.dart';
import 'package:hopper/Presentation/OnBoarding/screens/profilePicAccess.dart'
    show ProfilePicAccess;
import 'package:hopper/Presentation/Authentication/widgets/textFields.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hopper/Core/Constants/Colors.dart';
import 'package:hopper/Core/Constants/texts.dart';
import 'package:hopper/Core/Utility/Buttons.dart';
import 'package:hopper/Core/Utility/images.dart';
import 'package:hopper/Presentation/Authentication/widgets/textFields.dart';
import 'package:hopper/Presentation/OnBoarding/controller/guidelines_Controller.dart';
import 'package:hopper/Presentation/OnBoarding/screens/chooseService.dart';
import 'package:hopper/Presentation/OnBoarding/screens/profilePicAccess.dart';
import 'package:hopper/Presentation/OnBoarding/screens/takePictureScreen.dart';
import 'package:hopper/Presentation/OnBoarding/widgets/bottomNavigation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:get/get.dart';

class DocUpLoadPic extends StatefulWidget {
  const DocUpLoadPic({super.key});

  @override
  State<DocUpLoadPic> createState() => _DocUpLoadPicState();
}

class _DocUpLoadPicState extends State<DocUpLoadPic> {
  final GuidelinesController controller = Get.put(GuidelinesController());
  final ChooseServiceController userController = Get.put(
    ChooseServiceController(),
  );
  final BasicInfoController basicInfoController = Get.put(
    BasicInfoController(),
  );

  @override
  void initState() {
    super.initState();
    controller.guideLines('profile-pic');
    userController.getUserDetails();
    basicInfoController.fetchAndSetUserData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Obx(() {
          if (controller.guidelinesList.isEmpty) {
            return Center(
              child: Image.asset(AppImages.animation, height: 100, width: 100),
            );
          }

          final guideline = controller.guidelinesList.first;

          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 25),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Buttons.backButton(context: context),
                  SizedBox(height: 25),
                  Text(
                    guideline.data.title,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Image.network(
                    guideline.data.image,
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder:
                        (_, __, ___) => const Icon(Icons.broken_image),
                  ),
                  const SizedBox(height: 10),
                  Center(
                    child: Text(
                      AppTexts.sampleDocument,
                      style: TextStyle(color: AppColors.sampleDocText),
                    ),
                  ),
                  const SizedBox(height: 24),

                  Row(
                    children: [
                      Image.asset(AppImages.tick, height: 30, width: 30),
                      const SizedBox(width: 10),
                      Text(
                        AppTexts.requirements,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  /// ✅ Requirements List
                  for (var item in guideline.data.requirements)
                    CustomTextfield.concatenateText(title: item),

                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 24),

                  /// ✅ Things to Avoid Title
                  Row(
                    children: [
                      Image.asset(AppImages.close, height: 30, width: 30),
                      const SizedBox(width: 10),
                      Text(
                        AppTexts.thinksToAvoid,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  /// ✅ Things to Avoid List
                  for (var item in guideline.data.thingsToAvoid)
                    CustomTextfield.concatenateText(title: item),
                ],
              ),
            ),
          );
        }),
      ),

      bottomNavigationBar: CustomBottomNavigation.bottomNavigation(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => ProfilePicAccess()),
          );
        },
        title: Text('Take a Photo'),
      ),
    );
  }
}
