import 'dart:io';

import 'package:flutter/material.dart';
import '../../../Core/Constants/Colors.dart';
import '../../../Core/Constants/log.dart';
import '../../../Core/Constants/texts.dart';
import '../../../Core/Utility/images.dart';
import '../../Authentication/widgets/textFields.dart';
import '../controller/guidelines_Controller.dart';
import '../widgets/bottomNavigation.dart';
import 'package:image_picker/image_picker.dart';

import '../../../Core/Utility/Buttons.dart';
import 'package:get/get.dart';

class NinGuideLines extends StatefulWidget {
  const NinGuideLines({super.key});

  @override
  State<NinGuideLines> createState() => _NinGuideLinesState();
}

class _NinGuideLinesState extends State<NinGuideLines> {
  final GuidelinesController controller = Get.put(GuidelinesController());
  @override
  void initState() {
    super.initState();
    controller.guideLines('nin-verification');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Obx(() {
        if (controller.guidelinesList.isEmpty) {
          return Center(child: Image.asset(AppImages.animation));
        }

        final guideline = controller.guidelinesList.first;

        return SingleChildScrollView(
          child: SafeArea(
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
          ),
        );
      }),

      bottomNavigationBar: CustomBottomNavigation.bottomNavigation(
        onTap: () {
          Navigator.pop(context);
        },
        title: 'Take a Photo',
      ),
    );
  }
}
