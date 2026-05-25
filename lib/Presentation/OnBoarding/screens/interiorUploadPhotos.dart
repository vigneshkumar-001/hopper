import 'dart:io';

import 'package:flutter/material.dart';
import '../../../Core/Constants/Colors.dart';
import '../../../Core/Constants/texts.dart';
import '../../../Core/Utility/Buttons.dart';
import '../../../Core/Utility/images.dart';
import '../../../Core/Utility/snackbar.dart';
import '../../Authentication/widgets/textFields.dart';
import '../controller/interiorimage_controller.dart';
import 'ConsentForms.dart';
import 'chooseService.dart';
import 'exteriorDocGuidelines.dart';
import 'interiorDocGuidelines.dart';
import '../widgets/bottomNavigation.dart';
import '../widgets/linearProgress.dart';
import '../../../utils/imagePath/imagePath.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:get/get.dart';
import 'package:hopper/utils/netWorkHandling/network_action_guard.dart';
import 'package:hopper/utils/widgets/hoppr_circular_loader.dart';

class InteriorUploadPhotos extends StatefulWidget {
  final bool fromCompleteScreens;
  const InteriorUploadPhotos({super.key, this.fromCompleteScreens = false});

  @override
  State<InteriorUploadPhotos> createState() => _InteriorUploadPhotosState();
}

class _InteriorUploadPhotosState extends State<InteriorUploadPhotos> {
  // final List<String?> _selectedImages = List.generate(6, (index) => null);

  final InteriorImageController controller = Get.put(InteriorImageController());
  final List<String> photoLabels = [
    "interior-photos-i",
    "interior-photos-ii",
    "interior-photos-iii",
    "interior-photos-iv",
    "interior-photos-v",
    "interior-photos-vi",
  ];
  @override
  void initState() {
    super.initState();
    controller.fetchAndSetUserData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // appBar: AppBar(backgroundColor: AppColors.commonWhite),
      body: SafeArea(
        child: Obx(
          () =>
              controller.isLoading.value
                  ? Center(child: Image.asset(AppImages.animation, height: 100,
                width: 100,))
                  : SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 15,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Buttons.backButton(context: context),
                          SizedBox(height: 24),
                          CustomLinearProgress.linearProgressIndicator(
                            value: 0.9,
                          ),
                          SizedBox(height: 24),
                          Image.asset(AppImages.carOwnerShip),
                          SizedBox(height: 25),
                          Text(
                            AppTexts.uploadInteriorPhotos,
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 10),
                          Text(AppTexts.limitPhotos),

                          SizedBox(height: 30),
                          Obx(
                            () => GridView.count(
                              crossAxisCount: 3,
                              mainAxisSpacing: 30,
                              shrinkWrap: true,
                              physics: NeverScrollableScrollPhysics(),
                              children: List.generate(6, (index) {
                                final imagePath =
                                    controller.selectedImages[index];

                                return Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    GestureDetector(
                                      onTap: () async {
                                        if (imagePath == null) {
                                          await Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder:
                                                  (context) =>
                                                      InteriorDocGuideLines(
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
                                          }
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
                                        onTap: () async {
                                          if (imagePath != null) {
                                            controller.selectedImages[index] =
                                                null;
                                          } else {
                                            await Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder:
                                                    (
                                                      context,
                                                    ) => InteriorDocGuideLines(
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
                                            }
                                          }
                                        },
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: Colors.black,
                                            shape: BoxShape.circle,
                                          ),
                                          padding: EdgeInsets.all(4),
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
      bottomNavigationBar: Obx(() {
        final selectedImages = controller.selectedImages;
        final allSelected = selectedImages.every(
          (img) => img != null && img.isNotEmpty,
        );
        final submitting = controller.isSubmitting.value;
        final enabled = allSelected && !submitting;

        return CustomBottomNavigation.bottomNavigation(
          buttonColor:
              enabled ? AppColors.commonBlack : AppColors.containerColor,
          onTap:
              enabled
                  ? () async {
                    final ok = await NetworkActionGuard.ensureOnline(
                      context: context,
                      title: 'Internet required',
                      message:
                          'Please connect to the internet to continue onboarding.',
                    );
                    if (!ok) return;

                    await controller.interiorImageUpload(
                      selectedImages: selectedImages,
                      context: context,
                      fromCompleteScreen: widget.fromCompleteScreens,
                    );
                  }
                  : () {
                    if (!allSelected) {
                      CustomSnackBar.showError(
                        "Please upload all required images.",
                      );
                    }
                  },
          title:
              submitting
                  ? const HopprCircularLoader(
                    radius: 10,
                    size: 22,
                    color: Colors.white,
                  )
                  : const Text('Save & Next'),
        );
      }),
    );
  }
}
