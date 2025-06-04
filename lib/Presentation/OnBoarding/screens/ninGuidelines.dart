import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hopper/Core/Constants/Colors.dart';
import 'package:hopper/Core/Constants/texts.dart';
import 'package:hopper/Core/Utility/images.dart';
import 'package:hopper/Presentation/Authentication/widgets/textFields.dart';
import 'package:hopper/Presentation/OnBoarding/widgets/bottomNavigation.dart';
import 'package:image_picker/image_picker.dart';

class NinGuideLines extends StatefulWidget {
  const NinGuideLines({super.key});

  @override
  State<NinGuideLines> createState() => _NinGuideLinesState();
}

class _NinGuideLinesState extends State<NinGuideLines> {
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
                  AppTexts.documentsUpload,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 24),
                Image.asset(AppImages.ninDoc),
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
                CustomTextfield.concatenateText(title: AppTexts.ninDocContent1),
                CustomTextfield.concatenateText(title: AppTexts.ninDocContent2),
                CustomTextfield.concatenateText(title: AppTexts.ninDocContent3),
                CustomTextfield.concatenateText(title: AppTexts.ninDocContent4),
                CustomTextfield.concatenateText(title: AppTexts.ninDocContent5),
                CustomTextfield.concatenateText(title: AppTexts.ninDocContent6),
                CustomTextfield.concatenateText(title: AppTexts.ninDocContent7),
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
                  title: AppTexts.ninThinksToAvoidContent1,
                ),
                CustomTextfield.concatenateText(
                  title: AppTexts.ninThinksToAvoidContent2,
                ),
                CustomTextfield.concatenateText(
                  title: AppTexts.ninThinksToAvoidContent3,
                ),
                CustomTextfield.concatenateText(
                  title: AppTexts.ninThinksToAvoidContent4,
                ),
                CustomTextfield.concatenateText(
                  title: AppTexts.ninThinksToAvoidContent5,
                ),
                CustomTextfield.concatenateText(
                  title: AppTexts.ninThinksToAvoidContent6,
                ),
                CustomTextfield.concatenateText(
                  title: AppTexts.ninThinksToAvoidContent7,
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: CustomBottomNavigation.bottomNavigation(
        onTap: () {
          Navigator.pop(context, true);
        },
        title: 'Take a Photo',
      ),
    );
  }
}
