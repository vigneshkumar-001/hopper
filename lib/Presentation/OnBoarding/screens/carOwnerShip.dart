import 'dart:io';

import 'package:flutter/material.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:hopper/Core/Constants/Colors.dart';
import 'package:hopper/Core/Constants/texts.dart';
import 'package:hopper/Core/Utility/images.dart';
import 'package:hopper/Presentation/Authentication/widgets/textFields.dart';
import 'package:hopper/Presentation/OnBoarding/screens/carOwnerDocGuidelines.dart';
import 'package:hopper/Presentation/OnBoarding/screens/vehicleDetails.dart';
import 'package:hopper/Presentation/OnBoarding/widgets/bottomNavigation.dart';
import 'package:hopper/Presentation/OnBoarding/widgets/linearProgress.dart';
import 'package:hopper/utils/imagePath/imagePath.dart';

import 'chooseService.dart';

class CarOwnership extends StatefulWidget {
  const CarOwnership({super.key});

  @override
  State<CarOwnership> createState() => _CarOwnershipState();
}

class _CarOwnershipState extends State<CarOwnership> {
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 25),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CustomLinearProgress.linearProgressIndicator(value: 0.6),
                SizedBox(height: 24),
                Image.asset(
                  selectedService == 'Car'
                      ? AppImages.carOwnerShip
                      : AppImages.bikeOwner,
                ),
                SizedBox(height: 24),
                Text(
                  selectedService == 'Car'
                      ? AppTexts.carOwnershipDetails
                      : AppTexts.bikeOwnershipDetails,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
                ),

                SizedBox(height: 24),
                CustomTextfield.dropDown(
                  title:
                      selectedService == 'Car'
                          ? 'Car Ownership'
                          : 'Bike Ownership',
                  hintText: 'Select Ownership',
                  onTap: () {},
                  suffixIcon: Icon(Icons.arrow_drop_down),
                ),
                SizedBox(height: 24),
                CustomTextfield.textField(
                  tittle: 'Owner Name',
                  hintText: 'Enter your Owner Name',
                ),
                SizedBox(height: 24),
                CustomTextfield.textField(
                  tittle:
                      selectedService == 'Car'
                          ? 'Car Plate Number'
                          : 'Bike Plate Number',
                  hintText: 'Enter your Plate Number',
                ),
                SizedBox(height: 24),
                CustomTextfield.dropDown(
                  title: 'Year',
                  hintText: 'Select Year',
                  onTap: () {},
                  suffixIcon: Icon(Icons.arrow_drop_down),
                ),
                SizedBox(height: 24),
                CustomTextfield.textField(
                  tittle: 'Registration Number',
                  hintText: 'Enter your Registration Number',
                ),
                SizedBox(height: 24),
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
                        if (backImage.isEmpty) {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => CarOwnerDocGuideLines(),
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
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: CustomBottomNavigation.bottomNavigation(
        title: "Save & Next",
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => VehicleDetails()),
          );
        },
      ),
    );
  }
}
