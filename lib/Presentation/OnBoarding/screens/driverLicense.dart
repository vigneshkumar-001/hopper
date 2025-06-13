import 'dart:io';

import 'package:flutter/material.dart';
import '../../../Core/Constants/Colors.dart';
import '../../../Core/Constants/texts.dart';
import '../../../Core/Utility/Buttons.dart';
import '../../../Core/Utility/images.dart';
import '../../../Core/Utility/snackbar.dart';
import '../../Authentication/widgets/textFields.dart';
import 'package:dotted_border/dotted_border.dart';
import '../controller/driverLicense_controller.dart';
import '../controller/guidelines_Controller.dart';
import 'carOwnerShip.dart';
import 'chooseService.dart';
import 'driverDocGuidelines.dart';
import 'ninGuidelines.dart';
import '../widgets/bottomNavigation.dart';
import '../widgets/linearProgress.dart';
import '../../../utils/imagePath/imagePath.dart';
import 'package:get/get.dart';

class DriverLicense extends StatefulWidget {
  final bool fromCompleteScreens;
  const DriverLicense({super.key, this.fromCompleteScreens = false});

  @override
  State<DriverLicense> createState() => _DriverLicenseState();
}

class _DriverLicenseState extends State<DriverLicense> {
  String frontImage = '';
  String backImage = '';
  final DriverLicenseController controller = Get.put(DriverLicenseController());
  final TextEditingController driverLicense = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _isButtonDisabled = false;
  final GuidelinesController guidelinesController = Get.put(
    GuidelinesController(),
  );

  @override
  void initState() {
    super.initState();

    controller.fetchAndSetUserData();
    guidelinesController.guideLines('driver-license');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Obx(
          () =>
              controller.isLoading.value
                  ? Center(
                    child: Image.asset(
                      AppImages.animation,
                      height: 100,
                      width: 100,
                    ),
                  )
                  : SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 24,
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Buttons.backButton(context: context),
                            SizedBox(height: 24),
                            CustomLinearProgress.linearProgressIndicator(
                              value: 0.5,
                            ),
                            SizedBox(height: 24),
                            Image.asset(AppImages.docUpload),
                            SizedBox(height: 24),
                            Text(
                              AppTexts.driverLicense,
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 30),
                            CustomTextfield.textField(
                              formKey: _formKey,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your License Number';
                                } /* else if (!RegExp(r'^[A-Z]{3}-\d{5}[A-Z]{2}\d{2}$').hasMatch(value)) {
                                  return 'You must follow the proper format. Eg: ABC-12345AA00';
                                }*/
                                return null;
                              },

                              controller: controller.driverLicenseController,
                              tittle: "Driver's License Number",
                              hintText: 'Enter your driving license number',
                            ),
                            SizedBox(height: 30),
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: const [
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
                                          builder:
                                              (context) =>
                                                  DriverDocGuideLines(),
                                        ),
                                      );
                                    }

                                    final path = await ImageUtils.pickImage(
                                      context,
                                    );
                                    if (path.isNotEmpty) {
                                      setState(() {
                                        frontImage = path;
                                      });
                                    }
                                  },
                                  child: DottedBorder(
                                    options: RoundedRectDottedBorderOptions(
                                      color: const Color(
                                        0xff666666,
                                      ).withOpacity(0.3),
                                      radius: const Radius.circular(10),
                                      dashPattern: const [7, 4],
                                      strokeWidth: 1.5,
                                    ),

                                    child: Container(
                                      height: 120,
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: const Color(0xffF8F7F7),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Obx(() {
                                        final hasLocalImage =
                                            frontImage.isNotEmpty;
                                        final hasApiImage =
                                            controller
                                                .frontImageUrl
                                                .value
                                                .isNotEmpty;

                                        if (!hasLocalImage && !hasApiImage) {
                                          return Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
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
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            child:
                                                hasLocalImage
                                                    ? Image.file(
                                                      File(frontImage),
                                                      height: 100,
                                                      width: 100,
                                                      fit: BoxFit.cover,
                                                    )
                                                    : Image.network(
                                                      controller
                                                          .frontImageUrl
                                                          .value,
                                                      height: 100,
                                                      width: 100,
                                                      fit: BoxFit.cover,
                                                      errorBuilder:
                                                          (
                                                            _,
                                                            __,
                                                            ___,
                                                          ) => const Icon(
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

                            SizedBox(height: 25),
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                          builder:
                                              (context) =>
                                                  DriverDocGuideLines(),
                                        ),
                                      );
                                    }

                                    final path = await ImageUtils.pickImage(
                                      context,
                                    );
                                    if (path.isNotEmpty) {
                                      setState(() {
                                        backImage = path;
                                      });
                                    }
                                  },
                                  child: DottedBorder(
                                    options: RoundedRectDottedBorderOptions(
                                      color: const Color(
                                        0xff666666,
                                      ).withOpacity(0.3),
                                      radius: const Radius.circular(10),
                                      dashPattern: const [7, 4],
                                      strokeWidth: 1.5,
                                    ),
                                    child: Container(
                                      height: 120,
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: const Color(0xffF8F7F7),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Obx(() {
                                        final hasLocalImage =
                                            backImage.isNotEmpty;
                                        final hasApiImage =
                                            controller
                                                .backImageUrl
                                                .value
                                                .isNotEmpty;

                                        if (!hasLocalImage && !hasApiImage) {
                                          return Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
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
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            child:
                                                hasLocalImage
                                                    ? Image.file(
                                                      File(backImage),
                                                      height: 100,
                                                      width: 100,
                                                      fit: BoxFit.cover,
                                                    )
                                                    : Image.network(
                                                      controller
                                                          .backImageUrl
                                                          .value,
                                                      height: 100,
                                                      width: 100,
                                                      fit: BoxFit.cover,
                                                      errorBuilder:
                                                          (
                                                            _,
                                                            __,
                                                            ___,
                                                          ) => const Icon(
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
        ),
      ),

      bottomNavigationBar:
          controller.isLoading.value
              ? null
              : BottomAppBar(
                color: AppColors.commonWhite,
                child: Column(
                  children: [
                    Buttons.button(
                      buttonColor: AppColors.commonBlack,
                      onTap: () async {
                        if (_isButtonDisabled) return;

                        setState(() {
                          _isButtonDisabled = true;
                        });
                        if (_formKey.currentState!.validate()) {
                          await controller.driverLicense(
                            fromCompleteScreen: widget.fromCompleteScreens,
                            context,
                            frontImage.isNotEmpty ? File(frontImage) : null,
                            backImage.isNotEmpty ? File(backImage) : null,
                          );
                        }
                        // Navigator.push(
                        //   context,
                        //   MaterialPageRoute(builder: (_) => DriverLicense()),
                        // );

                        setState(() {
                          _isButtonDisabled = false;
                        });
                      },

                      text: Text('Save & Next'),
                    ),
                  ],
                ),
              ),
    );
  }
}
