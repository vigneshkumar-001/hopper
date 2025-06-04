import 'dart:io';

import 'package:flutter/material.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:hopper/Core/Constants/Colors.dart';
import 'package:hopper/Core/Constants/texts.dart';
import 'package:hopper/Core/Utility/ModelBottomSheet.dart';
import 'package:hopper/Core/Utility/images.dart';
import 'package:hopper/Presentation/Authentication/widgets/textFields.dart';
import 'package:hopper/Presentation/OnBoarding/controller/caronwership_controller.dart';
import 'package:hopper/Presentation/OnBoarding/controller/chooseservice_controller.dart';
import 'package:hopper/Presentation/OnBoarding/screens/ConsentForms.dart';
import 'package:hopper/Presentation/OnBoarding/screens/carOwnerDocGuidelines.dart';
import 'package:hopper/Presentation/OnBoarding/screens/vehicleDetails.dart';
import 'package:hopper/Presentation/OnBoarding/widgets/bottomNavigation.dart';
import 'package:hopper/Presentation/OnBoarding/widgets/linearProgress.dart';
import 'package:hopper/utils/imagePath/imagePath.dart';

import 'chooseService.dart';
import 'package:get/get.dart';

class CarOwnership extends StatefulWidget {
  const CarOwnership({super.key});

  @override
  State<CarOwnership> createState() => _CarOwnershipState();
}

class _CarOwnershipState extends State<CarOwnership> {
  final CarOwnerShipController controller = Get.put(CarOwnerShipController());
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final ChooseServiceController getUserDetails = Get.find();
  // Future<void> getUserDetail() async {
  //   await getUserDetails.getUserDetails();
  // }
  String selectedService = '';
  String frontImage = '';
  String backImage = '';
  @override
  void initState() {
    super.initState();
    // getUserDetail();
    controller.fetchAndSetUserData();
  }

  File? _selectedImage;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: AppColors.commonWhite),
      body: Obx(() {
        if (controller.isLoading.value) {
          return Center(child: CircularProgressIndicator());
        }
        // final profile = Get.find<ChooseServiceController>().userProfile.value;
        selectedService = getUserDetails.serviceType.toString() ?? 'Car';

        final ownershipController =
            selectedService == 'Car'
                ? controller.carOwnershipController
                : controller.bikeOwnershipController;

        final nameController =
            selectedService == 'Car'
                ? controller.carOwnerNameController
                : controller.bikeOwnerNameController;

        final plateController =
            selectedService == 'Car'
                ? controller.carPlateNumberController
                : controller.bikePlateNumberController;

        return SingleChildScrollView(
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 25),
              child: Form(
                key: _formKey,
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
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 24,
                      ),
                    ),
                    SizedBox(height: 24),
                    CustomTextfield.dropDown(
                      controller: ownershipController,
                      title:
                          selectedService == 'Car'
                              ? 'Car Ownership'
                              : 'Bike Ownership',
                      hintText: 'Select Ownership',
                      onTap: () {
                        CustomBottomSheet.showOptionsBottomSheet(
                          title: 'OwnerShip',
                          options: ['Owned', 'Rented'],
                          context: context,
                          controller: ownershipController,
                        );
                      },
                      suffixIcon: Icon(Icons.arrow_drop_down),
                    ),
                    SizedBox(height: 24),
                    CustomTextfield.textField(
                      controller: nameController,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter Owner Name';
                        }
                        return null;
                      },
                      tittle: 'Owner Name',
                      hintText: 'Enter your Owner Name',
                    ),
                    SizedBox(height: 24),
                    CustomTextfield.textField(
                      controller: plateController,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter Plate Number';
                        }
                        return null;
                      },
                      tittle:
                          selectedService == 'Car'
                              ? 'Car Plate Number'
                              : 'Bike Plate Number',
                      hintText: 'Enter your Plate Number',
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }),
      bottomNavigationBar: CustomBottomNavigation.bottomNavigation(
        title: "Save & Next",
        onTap: () async {
          // if (_formKey.currentState!.validate()) {
          //   await controller.carOwnerShip(context, selectedService);
          // }
           Navigator.push(
             context,
             MaterialPageRoute(builder: (context) => ConsentForms()),
           );
        },
      ),
    );
  }
}
