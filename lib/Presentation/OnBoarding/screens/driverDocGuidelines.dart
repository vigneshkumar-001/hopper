import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../Core/Constants/Colors.dart';
import '../../../Core/Constants/texts.dart';
import '../../../Core/Utility/Buttons.dart';
import '../../../Core/Utility/images.dart';
import '../../Authentication/widgets/textFields.dart';
import '../controller/guidelines_Controller.dart';
import '../widgets/bottomNavigation.dart';

class DriverDocGuideLines extends StatefulWidget {
  const DriverDocGuideLines({super.key});

  @override
  State<DriverDocGuideLines> createState() => _DriverDocGuideLinesState();
}

class _DriverDocGuideLinesState extends State<DriverDocGuideLines> {

  final GuidelinesController controller = Get.put(GuidelinesController());
  @override
  void initState() {
    super.initState();
    controller.guideLines('driver-license');
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Obx(() {
        if (controller.guidelinesList.isEmpty) {
          return const Center(child: CircularProgressIndicator());
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
          // Navigator.push(
          //   context,
          //   MaterialPageRoute(builder: (context) => ChooseService()),
          // );
        },
        title: 'Take a Photo',
      ),
    );
  }
}
