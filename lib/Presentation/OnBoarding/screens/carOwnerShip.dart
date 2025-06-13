import 'dart:io';
import 'package:flutter/material.dart';
import 'package:dotted_border/dotted_border.dart';
import '../../../Core/Constants/Colors.dart';
import '../../../Core/Constants/texts.dart';
import '../../../Core/Utility/Buttons.dart';
import '../../../Core/Utility/ModelBottomSheet.dart';
import '../../../Core/Utility/images.dart';
import '../controller/caronwership_controller.dart';
import '../controller/chooseservice_controller.dart';
import 'ConsentForms.dart';
import 'carOwnerDocGuidelines.dart';
import 'vehicleDetails.dart';
import '../widgets/bottomNavigation.dart';
import '../widgets/linearProgress.dart';
import '../../../utils/imagePath/imagePath.dart';
import '../../Authentication/widgets/textFields.dart';
import 'chooseService.dart';
import 'package:get/get.dart';

class CarOwnership extends StatefulWidget {
  final bool fromCompleteScreens;
  const CarOwnership({super.key, this.fromCompleteScreens = false});

  @override
  State<CarOwnership> createState() => _CarOwnershipState();
}

class _CarOwnershipState extends State<CarOwnership> {
  final CarOwnerShipController controller = Get.put(CarOwnerShipController());
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final ChooseServiceController getUserDetails = Get.put(
    ChooseServiceController(),
  );
  String defaultPlateNumber = '';

  String selectedService = '';
  String frontImage = '';
  String backImage = '';
  @override
  void initState() {
    super.initState();
    // WidgetsBinding.instance.addPostFrameCallback((_) {
    //   getUserDetails.getUserDetails();
    // });
    controller.fetchAndSetUserData();
    defaultPlateNumber =
        controller.countryCode == '+234' ? 'LND-458-XA' : 'TN 59 AA 0001';
  }

  File? _selectedImage;
  @override
  Widget build(BuildContext context) {
    selectedService = controller.serviceType.toString() ?? 'Car';
    // selectedService = getUserDetails.serviceType.toString() ?? 'Car';

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
    return Scaffold(
      // appBar: AppBar(backgroundColor: AppColors.commonWhite),
      body:
      // if (controller.isLoading.value) {
      //   return Center(child: CircularProgressIndicator());
      // }
      // final profile = Get.find<ChooseServiceController>().userProfile.value;
      SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 25),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Buttons.backButton(context: context),
                  SizedBox(height: 24),
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
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please Select your OwnerShip';
                      } /*else if (value.length != 11) {
                        return 'Must be exactly 11 digits';
                      }*/
                      return null;
                    },

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
                    formKey: _formKey,
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
                    formKey: _formKey,
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
                    hintText: 'Enter your plate Name',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),

      bottomNavigationBar: Obx(
        () => CustomBottomNavigation.bottomNavigation(
          foreGroundColor:
              controller.isLoading.value ? Colors.black : Colors.white,
          buttonColor: controller.isLoading.value ? Colors.white : Colors.black,

          title:
              controller.isLoading.value
                  ? Image.asset(AppImages.animation)
                  : Text(
                    "Save & Next",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),

          onTap: () async {
            // Get.to(() => ConsentForms());
            if (_formKey.currentState!.validate()) {
              await controller.carOwnerShip(
                context,
                selectedService,
                fromCompleteScreen: widget.fromCompleteScreens,
              );
            }
          },
        ),
      ),
    );
  }
}
