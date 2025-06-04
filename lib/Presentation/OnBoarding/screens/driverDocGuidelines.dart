import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hopper/Core/Constants/Colors.dart';
import 'package:hopper/Core/Constants/texts.dart';
import 'package:hopper/Core/Utility/Buttons.dart';
import 'package:hopper/Core/Utility/images.dart';
import 'package:hopper/Presentation/Authentication/widgets/textFields.dart';
import 'package:hopper/Presentation/OnBoarding/controller/guidelines_Controller.dart';
import 'package:hopper/Presentation/OnBoarding/widgets/bottomNavigation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:get/get.dart';

class DriverDocGuideLines extends StatefulWidget {
  const DriverDocGuideLines({super.key});

  @override
  State<DriverDocGuideLines> createState() => _DriverDocGuideLinesState();
}

class _DriverDocGuideLinesState extends State<DriverDocGuideLines> {
  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();
  final GuidelinesController controller = Get.find();
  @override
  void initState() {
    controller.guideLines();
  } // Future<void> _pickImage() async {
  //   final XFile? image = await _picker.pickImage(source: ImageSource.camera);
  //   if (image != null) {
  //     if (image.path.endsWith('.png') || image.path.endsWith('.jpg')
  //     // image.path.endsWith('.jpeg')
  //     ) {
  //       setState(() {
  //         _selectedImage = File(image.path);
  //       });
  //
  //       Navigator.pop(context, true);
  //     } else {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(content: Text('Only PNG and JPG formats are supported')),
  //       );
  //     }
  //   }
  // }

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

                  /// ✅ Requirements Title
                  Row(
                    children: [
                      Image.asset(AppImages.tick),
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
                      Image.asset(AppImages.close),
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
