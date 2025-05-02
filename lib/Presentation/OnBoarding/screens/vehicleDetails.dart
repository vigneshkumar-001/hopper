import 'package:flutter/material.dart';

import 'package:hopper/Core/Constants/Colors.dart';
import 'package:hopper/Core/Constants/texts.dart';

import 'package:hopper/Core/Utility/images.dart';

import 'package:hopper/Presentation/Authentication/widgets/textFields.dart';
import 'package:hopper/Presentation/OnBoarding/screens/chooseService.dart';
import 'package:hopper/Presentation/OnBoarding/screens/uploadExteriorPhotos.dart';

import 'package:hopper/Presentation/OnBoarding/widgets/bottomNavigation.dart';
import 'package:hopper/Presentation/OnBoarding/widgets/linearProgress.dart';

class VehicleDetails extends StatefulWidget {
  const VehicleDetails({super.key});

  @override
  State<VehicleDetails> createState() => _VehicleDetailsState();
}

class _VehicleDetailsState extends State<VehicleDetails> {
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
                CustomLinearProgress.linearProgressIndicator(value: 0.7),
                SizedBox(height: 24),
                Image.asset(AppImages.docUpload),
                SizedBox(height: 24),
                Text(
                  AppTexts.vehicleDetails,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
                ),
                SizedBox(height: 24),
                CustomTextfield.dropDown(
                  title: selectedService == "Car" ? 'Car Brand' : 'Bike Brand',
                  hintText: 'Select Brand',
                  onTap: () {},
                  suffixIcon: Icon(Icons.arrow_drop_down),
                ),

                SizedBox(height: 24),
                CustomTextfield.dropDown(
                  title: selectedService == "Car" ? 'Car Model' : 'Bike Model',
                  hintText: 'Select Car Model',
                  onTap: () {},
                  suffixIcon: Icon(Icons.arrow_drop_down),
                ),
                SizedBox(height: 24),
                CustomTextfield.dropDown(
                  title: 'Year',
                  hintText: 'Select Car Year',
                  onTap: () {},
                  suffixIcon: Icon(Icons.arrow_drop_down),
                ),
                SizedBox(height: 24),
                CustomTextfield.dropDown(
                  title: 'Car Color',
                  hintText: 'Select Car Color',
                  onTap: () {},
                  suffixIcon: Icon(Icons.arrow_drop_down),
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
            MaterialPageRoute(builder: (context) => UploadExteriorPhotos()),
          );
        },
      ),
    );
  }
}
