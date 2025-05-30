import 'dart:io';

import 'package:flutter/material.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:hopper/Core/Constants/Colors.dart';
import 'package:hopper/Core/Constants/log.dart';
import 'package:hopper/Core/Constants/texts.dart';
import 'package:hopper/Core/Utility/Buttons.dart';
import 'package:hopper/Core/Utility/images.dart';
import 'package:hopper/Presentation/Authentication/widgets/textFields.dart';
import 'package:hopper/Presentation/OnBoarding/screens/driverLicense.dart';
import 'package:hopper/Presentation/OnBoarding/screens/ninGuidelines.dart';
import 'package:hopper/Presentation/OnBoarding/widgets/linearProgress.dart';
import 'package:hopper/utils/imagePath/imagePath.dart';
import 'package:image_picker/image_picker.dart';

class NinScreens extends StatefulWidget {
  const NinScreens({super.key});

  @override
  State<NinScreens> createState() => _NinScreensState();
}

class _NinScreensState extends State<NinScreens> {
  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();
  String frontImage = '';
  String backImage = '';

  // Future<String> pickImage() async {
  //   final XFile? image = await _picker.pickImage(source: ImageSource.camera);
  //   if (image != null) {
  //     if (image.path.endsWith('.png') || image.path.endsWith('.jpg')
  //     // image.path.endsWith('.jpeg')
  //     ) {
  //       return image.path;
  //       // _selectedImage = File(image.path);
  //     } else {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(content: Text('Only PNG and JPG formats are supported')),
  //       );
  //       return '';
  //     }
  //   } else {
  //     return '';
  //   }
  // }

  void _removeImage() {
    setState(() {
      _selectedImage = null;
    });
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: AppColors.commonWhite),
      body: SingleChildScrollView(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [  CustomLinearProgress.linearProgressIndicator(value: 0.4),
                SizedBox(height: 24),
                Image.asset(AppImages.docUpload),
                SizedBox(height: 24),
                Text(
                  AppTexts.idNumber,
                  style: TextStyle(fontWeight: FontWeight.w500, fontSize: 24),
                ),
                SizedBox(height: 32),
                CustomTextfield.textField(
                  tittle: 'Bank Verification Number',
                  hintText: 'Enter your bank verification number',
                ),
                SizedBox(height: 32),
                CustomTextfield.textField(
                  tittle: 'National Identification Number',
                  hintText: 'Enter your 11-digit NIN',
                ),
                SizedBox(height: 25),

                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Front of ID card*',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Please ensure there is a clear photo',
                            maxLines: 2,
                          ),
                        ],
                      ),
                    ),

                    GestureDetector(
                      onTap: () async {
                        if (frontImage.isEmpty) {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => NinGuideLines(),
                            ),
                          );
                        }

                        final path = await ImageUtils.pickImage(context);
                        if (path.isNotEmpty) {
                          setState(() {
                            frontImage = path;
                          });
                        }
                      },
                      child: DottedBorder(
                        color: Color(0xff666666).withOpacity(0.3),
                        borderType: BorderType.RRect,

                        radius: const Radius.circular(10),
                        dashPattern: const [7, 4],
                        strokeWidth: 1.5,
                        child: Container(
                          height: 120,

                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Color(0xffF8F7F7),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child:
                              frontImage.isEmpty
                                  ? Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.add, size: 30),
                                      const SizedBox(height: 10),
                                      Text(
                                        "Upload Photo",
                                        style: TextStyle(fontSize: 14),
                                      ),
                                    ],
                                  )
                                  : Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: Image.file(
                                          File(frontImage),
                                          height: 100,
                                          width: 100,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ],
                                  ),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 25),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Back of ID card*',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Please ensure there is a clear photo',
                            maxLines: 2,
                          ),
                        ],
                      ),
                    ),

                    GestureDetector(
                      onTap: () async {
                        if (backImage.isEmpty) {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => NinGuideLines(),
                            ),
                          );
                        }

                        final path = await ImageUtils.pickImage(context);
                        if (path.isNotEmpty) {
                          setState(() {
                            backImage = path;
                          });
                        }
                      },
                      child: DottedBorder(
                        color: Color(0xff666666).withOpacity(0.3),
                        borderType: BorderType.RRect,

                        radius: const Radius.circular(10),
                        dashPattern: const [7, 4],
                        strokeWidth: 1.5,
                        child: Container(
                          height: 120,

                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Color(0xffF8F7F7),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child:
                              backImage.isEmpty
                                  ? Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.add, size: 30),
                                      const SizedBox(height: 10),
                                      Text(
                                        "Upload Photo",
                                        style: TextStyle(fontSize: 14),
                                      ),
                                    ],
                                  )
                                  : Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: Image.file(
                                          File(backImage),
                                          height: 100,
                                          width: 100,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ],
                                  ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        color: AppColors.commonWhite,
        child: Column(
          children: [
            Buttons.button(
              buttonColor: AppColors.commonBlack,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => DriverLicense()),
                );
              },
              text: "Save & Next",
            ),
          ],
        ),
      ),
    );
  }
}
