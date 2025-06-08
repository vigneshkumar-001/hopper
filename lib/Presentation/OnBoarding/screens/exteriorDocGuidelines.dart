import 'dart:io';
import 'package:flutter/material.dart';
import '../../../Core/Constants/Colors.dart';
import '../../../Core/Constants/texts.dart';
import '../../../Core/Utility/Buttons.dart';
import '../../../Core/Utility/images.dart';
import '../../Authentication/widgets/textFields.dart';
import '../controller/guidelines_Controller.dart';
import '../widgets/bottomNavigation.dart';
import 'package:get/get.dart';

class ExteriorDocGuideLines extends StatefulWidget {
  final String photoLabel;
  const ExteriorDocGuideLines({super.key, required this.photoLabel});

  @override
  State<ExteriorDocGuideLines> createState() => _ExteriorDocGuideLinesState();
}

class _ExteriorDocGuideLinesState extends State<ExteriorDocGuideLines> {
  final GuidelinesController controller = Get.put(GuidelinesController());

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.guideLines(widget.photoLabel);
    });
  }

  @override
  Widget build(BuildContext context) {
    controller.guideLines(widget.photoLabel);
    return Scaffold(
      body: Obx(() {
        if (controller.isLoading.value) {
          return Center(child: Image.asset(AppImages.animation));
        }

        if (controller.guidelinesList.isEmpty) {
          return Center(child: Text("No guidelines available"));
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
                  const SizedBox(height: 25),

                  /// ✅ Title
                  Text(
                    guideline.data.title,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 24),

                  /// ✅ Image
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
                  const Divider(),

                  /// ✅ Requirements
                  Row(
                    children: [
                      Image.asset(AppImages.tick, height: 30, width: 30),
                      const SizedBox(width: 10),
                      Text(
                        AppTexts.requirements,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  for (var item in guideline.data.requirements)
                    CustomTextfield.concatenateText(title: item),

                  const SizedBox(height: 24),
                  const Divider(),

                  /// ✅ Things to Avoid
                  Row(
                    children: [
                      Image.asset(AppImages.close, height: 30, width: 30),
                      const SizedBox(width: 10),
                      Text(
                        AppTexts.thinksToAvoid,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  for (var item in guideline.data.thingsToAvoid)
                    CustomTextfield.concatenateText(title: item),
                ],
              ),
            ),
          ),
        );
      }),

      /// ✅ Bottom Button
      bottomNavigationBar: CustomBottomNavigation.bottomNavigation(
        onTap: () {
          Navigator.pop(context);
        },
        title: 'Take a Photo',
      ),
    );
  }
}
