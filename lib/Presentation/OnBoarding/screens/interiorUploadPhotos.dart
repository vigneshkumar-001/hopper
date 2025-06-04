import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hopper/Core/Constants/Colors.dart';
import 'package:hopper/Core/Constants/texts.dart';
import 'package:hopper/Core/Utility/images.dart';
import 'package:hopper/Core/Utility/snackbar.dart';
import 'package:hopper/Presentation/Authentication/widgets/textFields.dart';
import 'package:hopper/Presentation/OnBoarding/controller/interiorimage_controller.dart';
import 'package:hopper/Presentation/OnBoarding/screens/ConsentForms.dart';
import 'package:hopper/Presentation/OnBoarding/screens/chooseService.dart';
import 'package:hopper/Presentation/OnBoarding/screens/exteriorDocGuidelines.dart';
import 'package:hopper/Presentation/OnBoarding/screens/interiorDocGuidelines.dart';
import 'package:hopper/Presentation/OnBoarding/widgets/bottomNavigation.dart';
import 'package:hopper/Presentation/OnBoarding/widgets/linearProgress.dart';
import 'package:hopper/utils/imagePath/imagePath.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:get/get.dart';

class InteriorUploadPhotos extends StatefulWidget {
  const InteriorUploadPhotos({super.key});

  @override
  State<InteriorUploadPhotos> createState() => _InteriorUploadPhotosState();
}

class _InteriorUploadPhotosState extends State<InteriorUploadPhotos> {
  // final List<String?> _selectedImages = List.generate(6, (index) => null);

  final InteriorImageController controller = Get.find();

  final ImagePicker _picker = ImagePicker();

  // Future<void> pickImage(int index) async {
  //   final XFile? image = await _picker.pickImage(source: ImageSource.camera);
  //   if (image != null) {
  //     if (image.path.endsWith('.png') || image.path.endsWith('.jpg')
  //     // image.path.endsWith('.jpeg')
  //     ) {
  //       setState(() {
  //         _selectedImages[index] = File(image.path);
  //       });
  //     } else {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(content: Text('Only PNG and JPG formats are supported')),
  //       );
  //     }
  //   }
  // }
  @override
  void initState() {
    super.initState();
    controller.fetchAndSetUserData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: AppColors.commonWhite),
      body: Obx(
        () =>
            controller.isLoading.value
                ? Center(child: CircularProgressIndicator())
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
                          // GestureDetector(
                          //   onTap: () {
                          //     // Navigator.push(
                          //     //   context,
                          //     //   MaterialPageRoute(
                          //     //     builder: (context) => NinGuideLines(),
                          //     //   ),
                          //     // );
                          //   },
                          //   child: DottedBorder(
                          //     color: Color(0xff666666).withOpacity(0.3),
                          //     borderType: BorderType.RRect,
                          //
                          //     radius: const Radius.circular(10),
                          //     dashPattern: const [7, 4],
                          //     strokeWidth: 1.5,
                          //     child: Container(
                          //       height: 120,
                          //
                          //       padding: const EdgeInsets.all(10),
                          //       decoration: BoxDecoration(
                          //         color: Color(0xffF8F7F7),
                          //         borderRadius: BorderRadius.circular(10),
                          //       ),
                          //       child:
                          //           _selectedImage == null
                          //               ? Column(
                          //                 mainAxisAlignment: MainAxisAlignment.center,
                          //                 children: [
                          //                   Icon(Icons.add, size: 30),
                          //                   const SizedBox(height: 10),
                          //                   Text(
                          //                     "Upload Photo",
                          //                     style: TextStyle(fontSize: 14),
                          //                   ),
                          //                 ],
                          //               )
                          //               : Expanded(
                          //                 child: Column(
                          //                   mainAxisAlignment: MainAxisAlignment.center,
                          //                   children: [
                          //                     ClipRRect(
                          //                       borderRadius: BorderRadius.circular(10),
                          //                       child: Image.file(
                          //                         _selectedImage!,
                          //                         height: 100,
                          //                         width: 100,
                          //                         fit: BoxFit.cover,
                          //                       ),
                          //                     ),
                          //                   ],
                          //                 ),
                          //               ),
                          //     ),
                          //   ),
                          // ),
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
                                                      InteriorDocGuideLines(),
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
                                        color: Colors.grey.withOpacity(0.5),
                                        strokeWidth: 1.5,
                                        dashPattern: [6, 4],
                                        borderType: BorderType.RRect,
                                        radius: const Radius.circular(10),
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
                                                    (context) =>
                                                        InteriorDocGuideLines(),
                                              ),
                                            );
                                            final path =
                                                await ImageUtils.pickImage(
                                                  context,
                                                );
                                            if (path.isNotEmpty) {
                                              controller.selectedImages[index] =
                                                  null;
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
      bottomNavigationBar: CustomBottomNavigation.bottomNavigation(
        onTap: () async {
           final selectedImages = controller.selectedImages;

           // Ensure that the selected images are not null or empty
           if (selectedImages.any((image) => image == null || image.isEmpty)) {
             CustomSnackBar.showError("Please upload all required images.");
             return;
           }

           // Call the image upload method
           await controller.interiorImageUpload(
             selectedImages: selectedImages,
             context: context,
           );

           // Navigator.push(
           //   context,
           //   MaterialPageRoute(builder: (context) => ConsentForms()),
           // );
        },
        title: 'Save & Next',
      ),
    );
  }
}
