import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hopper/Core/Constants/Colors.dart';
import 'package:hopper/Core/Constants/texts.dart';
import 'package:hopper/Core/Utility/images.dart';
import 'package:hopper/Presentation/Authentication/widgets/textFields.dart';
import 'package:hopper/Presentation/OnBoarding/controller/chooseservice_controller.dart';
import 'package:hopper/Presentation/OnBoarding/screens/ConsentForms.dart';
import 'package:hopper/Presentation/OnBoarding/screens/chooseService.dart';
import 'package:hopper/Presentation/OnBoarding/screens/interiorUploadPhotos.dart';
import 'package:hopper/Presentation/OnBoarding/widgets/bottomNavigation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:get/get.dart';

class ExteriorDocGuideLines extends StatefulWidget {
  const ExteriorDocGuideLines({super.key});

  @override
  State<ExteriorDocGuideLines> createState() => _CarDocGuideLinesState();
}

class _CarDocGuideLinesState extends State<ExteriorDocGuideLines> {
  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.camera);
    if (image != null) {
      if (image.path.endsWith('.png') || image.path.endsWith('.jpg')
      // image.path.endsWith('.jpeg')
      ) {
        setState(() {
          _selectedImage = File(image.path);
        });

        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Only PNG and JPG formats are supported')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = Get.find<ChooseServiceController>().userProfile.value;
    final isCar = profile?.serviceType == 'Car';
    final serviceType = isCar ? 'Car' : 'Bike';

    return Scaffold(
      appBar: AppBar(backgroundColor: AppColors.commonWhite),
      body: SingleChildScrollView(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  serviceType == "Car"
                      ? AppTexts.carImageUploadGuidelines
                      : AppTexts.bikeImageUploadGuidelines,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 24),
                Image.asset(
                  serviceType == "Car"
                      ? AppImages.carDoc
                      : AppImages.bikeExterior,
                ),
                SizedBox(height: 10),
                Center(
                  child: Text(
                    AppTexts.sampleDocument,
                    style: TextStyle(color: AppColors.sampleDocText),
                  ),
                ),
                SizedBox(height: 24),
                Row(
                  children: [
                    Image.asset(AppImages.tick),
                    SizedBox(width: 10),
                    Text(
                      AppTexts.requirements,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 24),
                CustomTextfield.concatenateText(
                  title: AppTexts.carExteriorContent1,
                ),
                CustomTextfield.concatenateText(
                  title: AppTexts.carExteriorContent2,
                ),
                CustomTextfield.concatenateText(
                  title: AppTexts.carExteriorContent3,
                ),
                CustomTextfield.concatenateText(
                  title: AppTexts.carExteriorContent4,
                ),

                SizedBox(height: 24),
                Divider(),
                SizedBox(height: 24),
                Row(
                  children: [
                    Image.asset(AppImages.close),
                    SizedBox(width: 10),
                    Text(
                      AppTexts.thinksToAvoid,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 24),
                CustomTextfield.concatenateText(
                  title: AppTexts.carExteriorThinkToAvoidContent1,
                ),
                CustomTextfield.concatenateText(
                  title: AppTexts.carExteriorThinkToAvoidContent2,
                ),
                CustomTextfield.concatenateText(
                  title: AppTexts.carExteriorThinkToAvoidContent3,
                ),
                CustomTextfield.concatenateText(
                  title: AppTexts.carExteriorThinkToAvoidContent4,
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: CustomBottomNavigation.bottomNavigation(
        onTap: () async {
          if (serviceType == "Car") {
              Navigator. pop(context);
            // await Navigator.push(
            //   context,
            //   MaterialPageRoute(builder: (context) => InteriorUploadPhotos()),
            // );
          } else {
            Navigator. pop(context);
            // Navigator.push(
            //   context,
            //   MaterialPageRoute(builder: (context) => ConsentForms()),
            // );
          }
        },
        title: 'Take a Photo',
      ),
    );
  }
}
