import 'dart:io';

import 'package:flutter/material.dart';
import '../../../Core/Constants/Colors.dart';
import '../../../Core/Constants/log.dart';
import '../../../Core/Constants/texts.dart';
import '../../../Core/Utility/images.dart';
import '../../../Core/Utility/snackbar.dart';
import '../../Authentication/widgets/textFields.dart';
import '../controller/chooseservice_controller.dart';
import '../controller/exteriorImage_controller.dart';
import 'ConsentForms.dart';
import 'chooseService.dart';
import 'exteriorDocGuidelines.dart';
import 'interiorDocGuidelines.dart';
import 'interiorUploadPhotos.dart';
import '../widgets/bottomNavigation.dart';
import '../widgets/linearProgress.dart';
import '../../../utils/imagePath/imagePath.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:get/get.dart';

class UploadExteriorPhotos extends StatefulWidget {
  final bool fromCompleteScreens;
  const UploadExteriorPhotos({super.key, this.fromCompleteScreens = false});

  @override
  State<UploadExteriorPhotos> createState() => _UploadExteriorPhotosState();
}

class _UploadExteriorPhotosState extends State<UploadExteriorPhotos> {
  final ExteriorImageController controller = Get.put(ExteriorImageController());
  final ChooseServiceController getUserDetails = Get.find();
  String serviceType = '';
  bool isButtonDisabled = false;
  // final List<String> photoLabels = [
  //   "exterior-photos-i",
  //   "exterior-photos-ii",
  //   "exterior-photos-iii",
  //   "exterior-photos-iv",
  //   "exterior-photos-v",
  //   "exterior-photos-vi",
  // ];
  List<String> generatePhotoLabels({
    required String categoryPrefix,
    int count = 6,
  }) {
    const romanNumerals = ['i', 'ii', 'iii', 'iv', 'v', 'vi'];
    return List.generate(count, (index) {
      return '$categoryPrefix-${romanNumerals[index]}';
    });
  }

  @override
  void initState() {
    super.initState();
    controller.fetchAndSetUserData();
  }

  @override
  Widget build(BuildContext context) {
    final profile = Get.find<ChooseServiceController>().userProfile.value;
    // final isCar = profile?.serviceType == 'Car';
    // final serviceType = isCar ? 'Car' : 'Bike';
    serviceType = controller.vehicleType.toString() ?? 'Car';

    return Scaffold(
      body: Obx(
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
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 15,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CustomLinearProgress.linearProgressIndicator(
                            value: 0.8,
                          ),
                          const SizedBox(height: 24),
                          Image.asset(
                            serviceType == "Car"
                                ? AppImages.carOwnerShip
                                : AppImages.bikeOwner,
                          ),
                          const SizedBox(height: 25),
                          Text(
                            serviceType == "Car"
                                ? AppTexts.uploadExteriorPhotos
                                : AppTexts.bikePhotos,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(AppTexts.uploadExteriorContent),
                          const SizedBox(height: 30),

                          /// Grid to show images
                          Obx(
                            () => GridView.count(
                              crossAxisCount: 3,
                              mainAxisSpacing: 30,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              children: List.generate(6, (index) {
                                final imagePath =
                                    controller.selectedImages[index];

                                return Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    GestureDetector(
                                      onTap: () async {
                                        if (imagePath == null) {
                                          final String vehicleTypePrefix =
                                              serviceType == 'Car'
                                                  ? 'exterior-photos'
                                                  : 'bike-photos';

                                          final photoLabels =
                                              generatePhotoLabels(
                                                categoryPrefix:
                                                    vehicleTypePrefix,
                                              );

                                          CommonLogger.log.i(
                                            'Selected label: ${photoLabels[index]}',
                                          );

                                          await Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder:
                                                  (context) =>
                                                      ExteriorDocGuideLines(
                                                        photoLabel:
                                                            photoLabels[index],
                                                      ),
                                            ),
                                          );
                                          final path =
                                              await ImageUtils.pickImage(
                                                context,
                                              );
                                          if (path.isNotEmpty) {
                                            controller.selectedImages[index] =
                                                path;
                                            setState(() {
                                              isButtonDisabled = false;
                                            });
                                          }
                                        }
                                      },
                                      child: DottedBorder(
                                        options: RoundedRectDottedBorderOptions(
                                          color: const Color(
                                            0xff666666,
                                          ).withOpacity(0.3),
                                          radius: const Radius.circular(10),
                                          dashPattern: const [6, 4],
                                          strokeWidth: 1.5,
                                        ),
                                        child: Container(
                                          height: 130,
                                          width: 97,
                                          decoration: BoxDecoration(
                                            color: const Color(0xffF8F7F7),
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            image:
                                                imagePath != null
                                                    ? DecorationImage(
                                                      image:
                                                          imagePath.startsWith(
                                                                "http",
                                                              )
                                                              ? NetworkImage(
                                                                imagePath,
                                                              )
                                                              : FileImage(
                                                                    File(
                                                                      imagePath,
                                                                    ),
                                                                  )
                                                                  as ImageProvider,
                                                      fit: BoxFit.cover,
                                                    )
                                                    : null,
                                          ),
                                          child:
                                              imagePath == null
                                                  ? const Center(
                                                    child: Icon(
                                                      Icons.image,
                                                      color: Colors.grey,
                                                      size: 30,
                                                    ),
                                                  )
                                                  : null,
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      bottom: -5,
                                      right: 15,
                                      child: GestureDetector(
                                        onTap: () {
                                          controller.selectedImages[index] =
                                              null;
                                          setState(() {
                                            isButtonDisabled =
                                                false; // re-enable button
                                          });
                                        },
                                        child: Container(
                                          decoration: const BoxDecoration(
                                            color: Colors.black,
                                            shape: BoxShape.circle,
                                          ),
                                          padding: const EdgeInsets.all(4),
                                          child: Icon(
                                            imagePath != null
                                                ? Icons.close
                                                : Icons.add,
                                            size: 15,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              }),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
      ),
      // bottomNavigationBar: CustomBottomNavigation.bottomNavigation(
      //   onTap: () async {
      //     final selectedImages = controller.selectedImages;
      //
      //     final allSelected = selectedImages.every(
      //       (img) => img != null && img!.isNotEmpty,
      //     );
      //     if (!allSelected) {
      //       CustomSnackBar.showError("Please upload all required images.");
      //       return;
      //     }
      //
      //     await controller.exteriorImageUpload(
      //       serviceType: serviceType,
      //       selectedImages: selectedImages,
      //       context: context,
      //       fromCompleteScreen: widget.fromCompleteScreens,
      //     );
      //     // Navigator.push(
      //     //   context,
      //     //   MaterialPageRoute(builder: (context) => InteriorUploadPhotos()),
      //     // );
      //   },
      //   title: 'Save & Next',
      // ),
      bottomNavigationBar:
          controller.isLoading.value
              ? null
              : CustomBottomNavigation.bottomNavigation(
                buttonColor:
                    isButtonDisabled
                        ? Colors.grey
                        : controller.selectedImages.every(
                          (img) => img != null && img.isNotEmpty,
                        )
                        ? AppColors.commonBlack
                        : AppColors.containerColor,
                onTap:
                    isButtonDisabled
                        ? null
                        : () async {
                          final selectedImages = controller.selectedImages;
                          final allSelected = selectedImages.every(
                            (img) => img != null && img.isNotEmpty,
                          );

                          if (!allSelected) {
                            CustomSnackBar.showError(
                              "Please upload all required images.",
                            );
                            return;
                          }

                          setState(() {
                            isButtonDisabled = true;
                          });

                          await controller.exteriorImageUpload(
                            serviceType: serviceType,
                            selectedImages: selectedImages,
                            context: context,
                            fromCompleteScreen: widget.fromCompleteScreens,
                          );

                          // You can re-enable it if needed:
                          // setState(() => isButtonDisabled = false);
                        },
                title: Text('Save & Next'),
              ),
    );
  }
}
