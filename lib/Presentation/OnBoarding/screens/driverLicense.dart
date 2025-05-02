import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hopper/Core/Constants/Colors.dart';
import 'package:hopper/Core/Constants/texts.dart';
import 'package:hopper/Core/Utility/images.dart';
import 'package:hopper/Presentation/Authentication/widgets/textFields.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:hopper/Presentation/OnBoarding/screens/carOwnerShip.dart';
import 'package:hopper/Presentation/OnBoarding/screens/driverDocGuidelines.dart';
import 'package:hopper/Presentation/OnBoarding/screens/ninGuidelines.dart';
import 'package:hopper/Presentation/OnBoarding/widgets/bottomNavigation.dart';
import 'package:hopper/Presentation/OnBoarding/widgets/linearProgress.dart';
import 'package:hopper/utils/imagePath/imagePath.dart';

class DriverLicense extends StatefulWidget {
  const DriverLicense({super.key});

  @override
  State<DriverLicense> createState() => _DriverLicenseState();
}

class _DriverLicenseState extends State<DriverLicense> {
  String frontImage = '';
  String backImage = '';

  File? _selectedImage;
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
              children: [
               CustomLinearProgress.linearProgressIndicator(value: 0.5),
                SizedBox(height: 24),
                Image.asset(AppImages.docUpload),
                SizedBox(height: 24),
                Text(
                  AppTexts.driverLicense,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 30),
                CustomTextfield.textField(
                  tittle: "Driver's License Number",
                  hintText: 'Enter your driving license number',
                ),
                SizedBox(height: 30),
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
                              builder: (context) => DriverDocGuideLines(),
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
                SizedBox(height: 30),
                Row(
                  children: [
                    Column(
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

                    GestureDetector(
                      onTap: () async {
                        if (backImage.isEmpty) {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => DriverDocGuideLines(),
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
      bottomNavigationBar: CustomBottomNavigation.bottomNavigation(
        title: 'Save & Next',
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => CarOwnership()),
          );
        },
      ),
    );
  }
}
