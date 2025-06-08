import 'dart:io';
import 'package:flutter/material.dart';
import '../../../Core/Constants/Colors.dart';
import '../../../Core/Constants/texts.dart';
import '../../../Core/Utility/images.dart';
import '../../Authentication/widgets/textFields.dart';
import '../widgets/bottomNavigation.dart';
import 'package:image_picker/image_picker.dart';

class CarOwnerDocGuideLines extends StatefulWidget {
  const CarOwnerDocGuideLines({super.key});

  @override
  State<CarOwnerDocGuideLines> createState() => _CarOwnerDocGuideLinesState();
}

class _CarOwnerDocGuideLinesState extends State<CarOwnerDocGuideLines> {
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
                Image.asset(AppImages.carOwnerDoc),
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
                  title: AppTexts.carOwnerDocContent1,
                ),
                CustomTextfield.concatenateText(
                  title: AppTexts.carOwnerDocContent2,
                ),
                CustomTextfield.concatenateText(
                  title: AppTexts.carOwnerDocContent3,
                ),
                CustomTextfield.concatenateText(
                  title: AppTexts.carOwnerDocContent4,
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
                  title: AppTexts.carOwnerThinksToAvoidContent1,
                ),
                CustomTextfield.concatenateText(
                  title: AppTexts.carOwnerThinksToAvoidContent2,
                ),
                CustomTextfield.concatenateText(
                  title: AppTexts.carOwnerThinksToAvoidContent3,
                ),
                CustomTextfield.concatenateText(
                  title: AppTexts.carOwnerThinksToAvoidContent4,
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: CustomBottomNavigation.bottomNavigation(
        onTap: () {
          // _pickImage();
          Navigator.pop(context);
        },
        title: 'Take a Photo',
      ),
    );
  }
}
