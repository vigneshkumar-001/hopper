import 'dart:io';

import 'package:flutter/material.dart';

import 'package:hopper/Core/Constants/Colors.dart';
import 'package:hopper/Core/Constants/texts.dart';
import 'package:hopper/Core/Utility/Buttons.dart';
import 'package:hopper/Core/Utility/ModelBottomSheet.dart';

import 'package:hopper/Core/Utility/images.dart';
import 'package:hopper/Core/Utility/snackbar.dart';

import 'package:hopper/Presentation/Authentication/widgets/textFields.dart';
import 'package:hopper/Presentation/OnBoarding/controller/chooseservice_controller.dart';
import 'package:hopper/Presentation/OnBoarding/controller/stateList_Controller.dart';
import 'package:hopper/Presentation/OnBoarding/controller/vehicledetails_controller.dart';
import 'package:hopper/Presentation/OnBoarding/screens/ConsentForms.dart';
import 'package:hopper/Presentation/OnBoarding/screens/chooseService.dart';
import 'package:hopper/Presentation/OnBoarding/screens/uploadExteriorPhotos.dart';

import 'package:hopper/Presentation/OnBoarding/widgets/bottomNavigation.dart';
import 'package:hopper/Presentation/OnBoarding/widgets/linearProgress.dart';
import 'package:hopper/utils/imagePath/imagePath.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:get/get.dart';

class VehicleDetails extends StatefulWidget {
  const VehicleDetails({super.key});

  @override
  State<VehicleDetails> createState() => _VehicleDetailsState();
}

class _VehicleDetailsState extends State<VehicleDetails> {
  String frontImage = '';
  String backImage = '';
  String serviceType = '';
  final VehicleDetailsController controller = Get.find();
  final StateListController stateController = Get.find();
  final ChooseServiceController getUserDetails = Get.find();

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  @override
  void initState() {
    super.initState();
    stateController.brands;
    stateController.getBrandList();
    controller.fetchAndSetUserData();
  }

  @override
  Widget build(BuildContext context) {
    final profile = Get.find<ChooseServiceController>().userProfile.value;
    serviceType = getUserDetails.serviceType.toString() ?? 'Car';
    return Scaffold(
      body: Obx(() {
        if (controller.isLoading.value) {
          return Center(child: CircularProgressIndicator());
        }

        return SingleChildScrollView(
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 25),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Buttons.backButton(context: context),
                    SizedBox(height: 24),
                    CustomLinearProgress.linearProgressIndicator(value: 0.7),
                    SizedBox(height: 24),
                    Image.asset(AppImages.docUpload),
                    SizedBox(height: 24),
                    Text(
                      AppTexts.vehicleDetails,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 24,
                      ),
                    ),
                    SizedBox(height: 24),
                    // CustomTextfield.dropDown(
                    //   controller: carBrandController,
                    //   title:
                    //       selectedService == "Car"
                    //           ? 'Car Brand'
                    //           : 'Bike Brand',
                    //   hintText: 'Select Brand',
                    //   onTap: () {
                    //     CustomBottomSheet.showOptionsBottomSheet(
                    //       title: 'Select Brand',
                    //       options: ['Suzuki', 'Honda'],
                    //       context: context,
                    //       controller: carBrandController,
                    //     );
                    //   },
                    //   suffixIcon: Icon(Icons.arrow_drop_down),
                    // ),
                    CustomTextfield.dropDown(
                      controller: controller.carBrandController,
                      title: serviceType == "Car" ? 'Car Brand' : 'Bike Brand',
                      hintText: 'Select Brand',
                      onTap: () {
                        // Directly show the bottom sheet (no delay!)
                        CustomBottomSheet.showOptionsBottomSheet(
                          title: 'States',
                          options: stateController.brands,
                          context: context,
                          controller: controller.carBrandController,
                        );
                      },
                      suffixIcon: Icon(Icons.arrow_drop_down),
                    ),

                    SizedBox(height: 24),
                    CustomTextfield.dropDown(
                      controller: controller.carModelController,
                      title: serviceType == "Car" ? 'Car Model' : 'Bike Model',
                      hintText:
                          serviceType == "Car"
                              ? 'Select Car Model'
                              : 'Select Bike Model',
                      onTap: () async {
                        final selectedBrand =
                            controller.carBrandController.text;
                        if (selectedBrand.isEmpty) {
                          CustomSnackBar.showInfo(
                            "Please select a state first",
                          );
                          return;
                        }
                        await stateController.getModel(selectedBrand);
                        CustomBottomSheet.showOptionsBottomSheet(
                          title: 'Modal',
                          options: stateController.models,
                          context: context,
                          controller: controller.carModelController,
                        );
                      },
                      suffixIcon: Icon(Icons.arrow_drop_down),
                    ),
                    SizedBox(height: 24),
                    CustomTextfield.dropDown(
                      controller: controller.carYearController,
                      title: 'Year',

                      hintText:
                          serviceType == "Car"
                              ? 'Select Car Year'
                              : 'Select Bike Year',
                      onTap: () async {
                        final selectedBrand =
                            controller.carBrandController.text;
                        final selectedModel =
                            controller.carModelController.text;
                        await stateController.getYear(
                          selectedBrand,
                          selectedModel,
                        );
                        CustomBottomSheet.showOptionsBottomSheet(
                          title: 'Select year',
                          options: stateController.year,
                          context: context,
                          controller: controller.carYearController,
                        );
                      },
                      suffixIcon: Icon(Icons.arrow_drop_down),
                    ),
                    SizedBox(height: 24),
                    CustomTextfield.dropDown(
                      controller: controller.carColorController,
                      title: serviceType == "Car" ? 'Car Color' : 'Bike Color',

                      hintText:
                          serviceType == "Car"
                              ? 'Select Car Color'
                              : 'Select Bike Color',
                      onTap: () {
                        CustomBottomSheet.showOptionsBottomSheet(
                          title: 'Select Car Color',
                          options: stateController.color,
                          context: context,
                          controller: controller.carColorController,
                        );
                      },
                      suffixIcon: Icon(Icons.arrow_drop_down),
                    ),
                    SizedBox(height: 24),
                    CustomTextfield.textField(
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter Register Number';
                        }
                        // else if (value.length != 11) {
                        //   return 'NIN must be exactly 11 digits';
                        // }
                        return null;
                      },
                      controller: controller.registrationController,
                      tittle: 'Registration Number',
                      hintText: 'Enter Your Registration Number',
                    ),
                    SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Road worthiness\nCertificate',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              SizedBox(height: 16),
                              Text('', maxLines: 2),
                            ],
                          ),
                        ),

                        GestureDetector(
                          onTap: () async {
                            if (frontImage.isEmpty) {
                              // await Navigator.push(
                              //   context,
                              //   MaterialPageRoute(
                              //     builder: (context) => NinGuideLines(),
                              //   ),
                              // );
                            }

                            final path = await ImageUtils.pickImage(context);
                            if (path.isNotEmpty) {
                              setState(() {
                                frontImage = path;
                              });
                            }
                          },
                          child: DottedBorder(
                            color: const Color(0xff666666).withOpacity(0.3),
                            borderType: BorderType.RRect,
                            radius: const Radius.circular(10),
                            dashPattern: const [7, 4],
                            strokeWidth: 1.5,
                            child: Container(
                              height: 120,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xffF8F7F7),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Obx(() {
                                final hasLocalImage = frontImage.isNotEmpty;
                                final hasApiImage =
                                    controller.frontImageUrl.value.isNotEmpty;

                                if (!hasLocalImage && !hasApiImage) {
                                  return Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: const [
                                      Icon(Icons.add, size: 30),
                                      SizedBox(height: 10),
                                      Text(
                                        "Upload Photo",
                                        style: TextStyle(fontSize: 14),
                                      ),
                                    ],
                                  );
                                } else {
                                  return ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child:
                                        hasLocalImage
                                            ? Image.file(
                                              File(frontImage),
                                              height: 100,
                                              width: 100,
                                              fit: BoxFit.cover,
                                            )
                                            : Image.network(
                                              controller.frontImageUrl.value,
                                              height: 100,
                                              width: 100,
                                              fit: BoxFit.cover,
                                              errorBuilder:
                                                  (_, __, ___) => const Icon(
                                                    Icons.broken_image,
                                                  ),
                                            ),
                                  );
                                }
                              }),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Insurance Document',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              SizedBox(height: 16),
                              Text(' ', maxLines: 2),
                            ],
                          ),
                        ),

                        GestureDetector(
                          onTap: () async {
                            if (backImage.isEmpty) {
                              // await Navigator.push(
                              //   context,
                              //   MaterialPageRoute(
                              //     builder: (context) => NinGuideLines(),
                              //   ),
                              // );
                            }

                            final path = await ImageUtils.pickImage(context);
                            if (path.isNotEmpty) {
                              setState(() {
                                backImage = path;
                              });
                            }
                          },
                          child: DottedBorder(
                            color: const Color(0xff666666).withOpacity(0.3),
                            borderType: BorderType.RRect,
                            radius: const Radius.circular(10),
                            dashPattern: const [7, 4],
                            strokeWidth: 1.5,
                            child: Container(
                              height: 120,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xffF8F7F7),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Obx(() {
                                final hasLocalImage = backImage.isNotEmpty;
                                final hasApiImage =
                                    controller.backImageUrl.value.isNotEmpty;

                                if (!hasLocalImage && !hasApiImage) {
                                  return Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: const [
                                      Icon(Icons.add, size: 30),
                                      SizedBox(height: 10),
                                      Text(
                                        "Upload Photo",
                                        style: TextStyle(fontSize: 14),
                                      ),
                                    ],
                                  );
                                } else {
                                  return ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child:
                                        hasLocalImage
                                            ? Image.file(
                                              File(backImage),
                                              height: 100,
                                              width: 100,
                                              fit: BoxFit.cover,
                                            )
                                            : Image.network(
                                              controller.backImageUrl.value,
                                              height: 100,
                                              width: 100,
                                              fit: BoxFit.cover,
                                              errorBuilder:
                                                  (_, __, ___) => const Icon(
                                                    Icons.broken_image,
                                                  ),
                                            ),
                                  );
                                }
                              }),
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
        );
      }),
      bottomNavigationBar: CustomBottomNavigation.bottomNavigation(
        title: "Save & Next",
        onTap: () async {
          if (_formKey.currentState!.validate()) {
            await controller.vehicleDetails(
              frontImageFile: File(frontImage),
              backImageFile: File(backImage),
              context: context,serviceType: serviceType

            );
          }
          // Navigator.push(
          //   context,
          //   MaterialPageRoute(builder: (context) => UploadExteriorPhotos()),
          // );
        },
      ),
    );
  }
}
