import 'dart:io';

import 'package:flutter/material.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/services.dart';
import '../../../Core/Constants/Colors.dart';
import '../../../Core/Constants/log.dart';
import '../../../Core/Constants/texts.dart';
import '../../../Core/Utility/Buttons.dart';
import '../../../Core/Utility/images.dart';
import '../../Authentication/widgets/textFields.dart';
import '../controller/guidelines_Controller.dart';
import '../controller/nin_controller.dart';
import 'driverLicense.dart';
import 'ninGuidelines.dart';
import '../widgets/linearProgress.dart';
import '../../../utils/imagePath/imagePath.dart';
import '../../../utils/init_Controller.dart';
import 'package:image_picker/image_picker.dart';
import 'package:get/get.dart';

class NinScreens extends StatefulWidget {
  const NinScreens({super.key, this.fromCompleteScreens = false});

  final bool fromCompleteScreens;

  @override
  State<NinScreens> createState() => _NinScreensState();
}

class _NinScreensState extends State<NinScreens> {
  String backImage = '';
  final NinController controller = Get.put(NinController());
  String frontImage = '';
  final GuidelinesController guidelinesController = Get.put(
    GuidelinesController(),
  );

  final TextEditingController ninController = TextEditingController();

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _isButtonDisabled = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();

    controller.fetchAndSetUserData();
    guidelinesController.guideLines('nin-verification');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Obx(
        () =>
            controller.isLoading.value
                ? Center(child: Image.asset(AppImages.animation))
                : SingleChildScrollView(
                  child: SafeArea(
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
                              value: 0.4,
                            ),
                            SizedBox(height: 24),
                            Image.asset(AppImages.docUpload),
                            SizedBox(height: 24),
                            Text(
                              AppTexts.idNumber,
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                fontSize: 24,
                              ),
                            ),
                            // SizedBox(height: 32),
                            // CustomTextfield.textField(
                            //   tittle: 'Bank Verification Number',
                            //   hintText: 'Enter your bank verification number',
                            // ),
                            SizedBox(height: 32),
                            CustomTextfield.textField(
                              type: TextInputType.number,
                              formKey: _formKey,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                FilteringTextInputFormatter.deny(
                                  RegExp(r'\s'),
                                ), // deny spaces
                              ],
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your BVN';
                                } else if (!RegExp(r'^\d+$').hasMatch(value)) {
                                  return 'You must follow the proper format. Eg: 22345678901';
                                }
                                return null;
                              },

                              controller: controller.bankNumberController,
                              tittle: 'Bank Verification Number',
                              hintText: 'Enter your Bank Verification Number',
                            ),
                            SizedBox(height: 25),
                            CustomTextfield.textField(
                              type: TextInputType.number,
                              formKey: _formKey,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(11),
                              ],
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your NIN';
                                } else if (value.length != 11) {
                                  return 'Must be exactly 11 digits';
                                }
                                return null;
                              },
                              controller: controller.ninNumberController,
                              tittle: 'National Identification Number',
                              hintText: 'Enter your 11-digit NIN',
                            ),
                            SizedBox(height: 25),
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
                                          builder: (context) => NinGuideLines(),
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
                                     options: RoundedRectDottedBorderOptions(  color: const Color(
                                      0xff666666,
                                    ).withOpacity(0.3),
                                    radius: const Radius.circular(10),
                                    dashPattern: const [7, 4],
                                    strokeWidth: 1.5,),
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
                                          builder: (context) => NinGuideLines(),
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
                                    options: RoundedRectDottedBorderOptions(  color: const Color(
                                      0xff666666,
                                    ).withOpacity(0.3),
                                    radius: const Radius.circular(10),
                                    dashPattern: const [7, 4],
                                    strokeWidth: 1.5,),
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
      bottomNavigationBar: BottomAppBar(
        color: AppColors.commonWhite,
        child: Column(
          children: [
            Buttons.button(
              buttonColor: AppColors.commonBlack,
              onTap: () async {
                if (_isButtonDisabled) return; // ignore clicks when disabled

                setState(() {
                  _isButtonDisabled = true; // disable the button immediately
                });
                if (_formKey.currentState!.validate()) {
                  await controller.ninScreen(
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
              text: "Save & Next",
            ),
          ],
        ),
      ),
    );
  }
}
