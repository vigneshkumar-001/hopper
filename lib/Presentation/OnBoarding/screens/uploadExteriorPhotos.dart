// import 'dart:io';
//
// import 'package:flutter/material.dart';
// import 'package:hopper/Core/Constants/Colors.dart';
// import 'package:hopper/Core/Constants/log.dart';
// import 'package:hopper/Core/Constants/texts.dart';
// import 'package:hopper/Core/Utility/images.dart';
// import 'package:hopper/Core/Utility/snackbar.dart';
// import 'package:hopper/Presentation/Authentication/widgets/textFields.dart';
// import 'package:hopper/Presentation/OnBoarding/controller/exteriorImage_controller.dart';
// import 'package:hopper/Presentation/OnBoarding/screens/ConsentForms.dart';
// import 'package:hopper/Presentation/OnBoarding/screens/chooseService.dart';
// import 'package:hopper/Presentation/OnBoarding/screens/exteriorDocGuidelines.dart';
// import 'package:hopper/Presentation/OnBoarding/screens/interiorDocGuidelines.dart';
// import 'package:hopper/Presentation/OnBoarding/screens/interiorUploadPhotos.dart';
// import 'package:hopper/Presentation/OnBoarding/widgets/bottomNavigation.dart';
// import 'package:hopper/Presentation/OnBoarding/widgets/linearProgress.dart';
// import 'package:hopper/utils/imagePath/imagePath.dart';
// import 'package:image_picker/image_picker.dart';
// import 'package:dotted_border/dotted_border.dart';
// import 'package:get/get.dart';
//
// class UploadExteriorPhotos extends StatefulWidget {
//   const UploadExteriorPhotos({super.key});
//
//   @override
//   State<UploadExteriorPhotos> createState() => _UploadExteriorPhotosState();
// }
//
// class _UploadExteriorPhotosState extends State<UploadExteriorPhotos> {
//   List<String?> _selectedImages = List.generate(6, (index) => null);
//   final ExteriorImageController controller = Get.find();
//   final ImagePicker _picker = ImagePicker();
//
//   // Future<void> pickImage(int index) async {
//   //   final XFile? image = await _picker.pickImage(source: ImageSource.camera);
//   //   if (image != null) {
//   //     if (image.path.endsWith('.png') || image.path.endsWith('.jpg')
//   //     // image.path.endsWith('.jpeg')
//   //     ) {
//   //       setState(() {
//   //         _selectedImages[index] = File(image.path);
//   //       });
//   //     } else {
//   //       ScaffoldMessenger.of(context).showSnackBar(
//   //         SnackBar(content: Text('Only PNG and JPG formats are supported')),
//   //       );
//   //     }
//   //   }
//   // }
//   @override
//   void initState() {
//     super.initState();
//     controller.fetchAndSetUserData();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(backgroundColor: AppColors.commonWhite),
//       body: Obx(
//         () =>
//             controller.isLoading.value
//                 ? Center(child: CircularProgressIndicator())
//                 : SingleChildScrollView(
//                   child: SafeArea(
//                     child: Padding(
//                       padding: const EdgeInsets.symmetric(
//                         horizontal: 16,
//                         vertical: 15,
//                       ),
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           CustomLinearProgress.linearProgressIndicator(
//                             value: 0.8,
//                           ),
//                           SizedBox(height: 24),
//                           Image.asset(
//                             selectedService == "Car"
//                                 ? AppImages.carOwnerShip
//                                 : AppImages.bikeOwner,
//                           ),
//                           SizedBox(height: 25),
//                           Text(
//                             selectedService == "Car"
//                                 ? AppTexts.uploadExteriorPhotos
//                                 : AppTexts.bikePhotos,
//                             style: TextStyle(
//                               fontSize: 24,
//                               fontWeight: FontWeight.bold,
//                             ),
//                           ),
//                           SizedBox(height: 10),
//                           Text(AppTexts.uploadExteriorContent),
//
//                           SizedBox(height: 30),
//
//                           Obx(
//                             () => GridView.count(
//                               crossAxisCount: 3,
//                               mainAxisSpacing: 30,
//                               shrinkWrap: true,
//                               physics: NeverScrollableScrollPhysics(),
//                               children: List.generate(6, (index) {
//                                 final imagePath =
//                                     controller.selectedImages[index];
//
//                                 return Stack(
//                                   clipBehavior: Clip.none,
//                                   children: [
//                                     GestureDetector(
//                                       onTap: () async {
//                                         final path = await ImageUtils.pickImage(
//                                           context,
//                                         );
//                                         if (path.isNotEmpty) {
//                                           controller.selectedImages[index] =
//                                               path;
//                                         }
//                                       },
//                                       child: DottedBorder(
//                                         color: Colors.grey.withOpacity(0.5),
//                                         strokeWidth: 1.5,
//                                         dashPattern: [6, 4],
//                                         borderType: BorderType.RRect,
//                                         radius: Radius.circular(10),
//                                         child: Container(
//                                           height: 130,
//                                           width: 97,
//                                           decoration: BoxDecoration(
//                                             color: const Color(0xffF8F7F7),
//                                             borderRadius: BorderRadius.circular(
//                                               10,
//                                             ),
//                                             image:
//                                                 imagePath != null
//                                                     ? DecorationImage(
//                                                       image:
//                                                           imagePath.startsWith(
//                                                                 "http",
//                                                               )
//                                                               ? NetworkImage(
//                                                                 imagePath,
//                                                               )
//                                                               : FileImage(
//                                                                     File(
//                                                                       imagePath,
//                                                                     ),
//                                                                   )
//                                                                   as ImageProvider,
//                                                       fit: BoxFit.cover,
//                                                     )
//                                                     : null,
//                                           ),
//                                           child:
//                                               imagePath == null
//                                                   ? Center(
//                                                     child: Icon(
//                                                       Icons.image,
//                                                       color: Colors.grey,
//                                                       size: 30,
//                                                     ),
//                                                   )
//                                                   : null,
//                                         ),
//                                       ),
//                                     ),
//                                     Positioned(
//                                       bottom: -5,
//                                       right: 15,
//                                       child: GestureDetector(
//                                         onTap: () {
//                                           controller.selectedImages[index] =
//                                               null;
//                                         },
//                                         child: Container(
//                                           decoration: BoxDecoration(
//                                             color: Colors.black,
//                                             shape: BoxShape.circle,
//                                           ),
//                                           padding: EdgeInsets.all(4),
//                                           child: Icon(
//                                             controller.selectedImages[index] !=
//                                                     null
//                                                 ? Icons.close
//                                                 : Icons.add,
//                                             size: 15,
//                                             color: Colors.white,
//                                           ),
//                                         ),
//                                       ),
//                                     ),
//                                   ],
//                                 );
//                               }),
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//                   ),
//                 ),
//       ),
//       bottomNavigationBar: CustomBottomNavigation.bottomNavigation(
//         onTap: () async {
//           final selectedImages = _selectedImages;
//
//           // Ensure that the selected images are not null or empty
//           if (selectedImages.any((image) => image == null || image.isEmpty)) {
//             CustomSnackBar.showError("Please upload all required images.");
//             return;
//           }
//
//           await controller.exteriorImageUpload(
//             selectedImages: selectedImages,
//             context: context,
//           );
//
//           // After upload, navigate to the next screen based on selectedService
//           // if (selectedService == "Car") {
//           //   Navigator.push(
//           //     context,
//           //     MaterialPageRoute(builder: (context) => InteriorUploadPhotos()),
//           //   );
//           // } else {
//           //   Navigator.push(
//           //     context,
//           //     MaterialPageRoute(builder: (context) => ConsentForms()),
//           //   );
//           // }
//         },
//         title: 'Save & Next',
//       ),
//     );
//   }
// }

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hopper/Core/Constants/Colors.dart';
import 'package:hopper/Core/Constants/texts.dart';
import 'package:hopper/Core/Utility/images.dart';
import 'package:hopper/Core/Utility/snackbar.dart';
import 'package:hopper/Presentation/OnBoarding/controller/chooseservice_controller.dart';
import 'package:hopper/Presentation/OnBoarding/controller/exteriorImage_controller.dart';
import 'package:hopper/Presentation/OnBoarding/widgets/bottomNavigation.dart';
import 'package:hopper/Presentation/OnBoarding/widgets/linearProgress.dart';
import 'package:hopper/utils/imagePath/imagePath.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:get/get.dart';

class UploadExteriorPhotos extends StatefulWidget {
  const UploadExteriorPhotos({super.key});

  @override
  State<UploadExteriorPhotos> createState() => _UploadExteriorPhotosState();
}

class _UploadExteriorPhotosState extends State<UploadExteriorPhotos> {
  final ExteriorImageController controller = Get.find();
  final ChooseServiceController getUserDetails = Get.find();
  String serviceType = '';
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
    serviceType = getUserDetails.serviceType.toString() ?? 'Car';

    return Scaffold(
      appBar: AppBar(backgroundColor: AppColors.commonWhite),
      body: Obx(
        () =>
            controller.isLoading.value
                ? const Center(child: CircularProgressIndicator())
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
                                        final path = await ImageUtils.pickImage(
                                          context,
                                        );
                                        if (path.isNotEmpty) {
                                          controller.selectedImages[index] =
                                              path;
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
                                        onTap: () {
                                          controller.selectedImages[index] =
                                              null;
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
      bottomNavigationBar: CustomBottomNavigation.bottomNavigation(
        onTap: () async {
          final selectedImages = controller.selectedImages;

          final allSelected = selectedImages.every(
            (img) => img != null && img.isNotEmpty,
          );
          if (!allSelected) {
            CustomSnackBar.showError("Please upload all required images.");
            return;
          }

          await controller.exteriorImageUpload(
            serviceType: serviceType,
            selectedImages: selectedImages,
            context: context,
          );
          // Navigator.push(
          //   context,
          //   MaterialPageRoute(builder: (context) => InteriorUploadPhotos()),
          // );
        },
        title: 'Save & Next',
      ),
    );
  }
}
