import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hopper/Core/Constants/Colors.dart';
import 'package:hopper/Core/Constants/log.dart';
import 'package:hopper/Core/Constants/texts.dart';
import 'package:hopper/Core/Utility/images.dart';
import 'package:hopper/Presentation/Authentication/widgets/textFields.dart';
import 'package:hopper/Presentation/OnBoarding/screens/ConsentForms.dart';
import 'package:hopper/Presentation/OnBoarding/screens/chooseService.dart';
import 'package:hopper/Presentation/OnBoarding/screens/exteriorDocGuidelines.dart';
import 'package:hopper/Presentation/OnBoarding/screens/interiorDocGuidelines.dart';
import 'package:hopper/Presentation/OnBoarding/screens/interiorUploadPhotos.dart';
import 'package:hopper/Presentation/OnBoarding/widgets/bottomNavigation.dart';
import 'package:hopper/Presentation/OnBoarding/widgets/linearProgress.dart';
import 'package:hopper/utils/imagePath/imagePath.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dotted_border/dotted_border.dart';

class UploadExteriorPhotos extends StatefulWidget {
  const UploadExteriorPhotos({super.key});

  @override
  State<UploadExteriorPhotos> createState() => _UploadExteriorPhotosState();
}

class _UploadExteriorPhotosState extends State<UploadExteriorPhotos> {
  List<String?> _selectedImages = List.generate(6, (index) => null);

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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: AppColors.commonWhite),
      body: SingleChildScrollView(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CustomLinearProgress.linearProgressIndicator(value: 0.8),
                SizedBox(height: 24),
                Image.asset(
                  selectedService == "Car"
                      ? AppImages.carOwnerShip
                      : AppImages.bikeOwner,
                ),
                SizedBox(height: 25),
                Text(
                  selectedService == "Car"
                      ? AppTexts.uploadExteriorPhotos
                      : AppTexts.bikePhotos,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 10),
                Text(AppTexts.uploadExteriorContent),
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
                // GridView.count(
                //   crossAxisCount: 3,
                //   mainAxisSpacing: 30,
                //   shrinkWrap: true,
                //   physics: NeverScrollableScrollPhysics(),
                //   children: List.generate(6, (index) {
                //     final image = _selectedImages[index];
                //     return Stack(
                //       clipBehavior: Clip.none,
                //       children: [
                //         GestureDetector(
                //           onTap: () async {
                //             if (_selectedImages[index] == null) {
                //               await Navigator.push(
                //                 context,
                //                 MaterialPageRoute(
                //                   builder: (context) => ExteriorDocGuideLines(),
                //                 ),
                //               );
                //             }
                //
                //             final path = await ImageUtils.pickImage(context);
                //             if (path.isNotEmpty) {
                //               setState(() {
                //                 _selectedImages[index] = path;
                //               });
                //               CommonLogger.log.i(_selectedImages[index]);
                //             }
                //           },
                //           child: DottedBorder(
                //             color: Colors.grey.withOpacity(0.5),
                //             strokeWidth: 1.5,
                //             dashPattern: [6, 4],
                //             borderType: BorderType.RRect,
                //             radius: Radius.circular(10),
                //             child: Container(
                //               height: 130,
                //               width: 97,
                //               decoration: BoxDecoration(
                //                 color: const Color(0xffF8F7F7),
                //                 borderRadius: BorderRadius.circular(10),
                //                 image: image  != null
                //                     ? DecorationImage(
                //                   image: FileImage(File(image)),
                //                   fit: BoxFit.cover,
                //                 )
                //                     : null,
                //               ),
                //               child:
                //                   image == null
                //                       ? Center(
                //                         child: Icon(
                //                           Icons.image,
                //                           color: Colors.grey,
                //                           size: 30,
                //                         ),
                //                       )
                //                       : null,
                //             ),
                //           ),
                //         ),
                //         Positioned(
                //           bottom: -5,
                //           right: 15,
                //           child: GestureDetector(
                //             // onTap: () {
                //             //   setState(() {
                //             //     if (image != null) {
                //             //       _selectedImages[index] = null;
                //             //     } else {
                //             //       pickImage(index);
                //             //     }
                //             //   });
                //             // },
                //             onTap: () async {
                //               if (image  != null) {
                //                 setState(() {
                //                   _selectedImages[index] = null;
                //                 });
                //               } else {
                //                 await Navigator.push(
                //                   context,
                //                   MaterialPageRoute(
                //                     builder: (context) => ExteriorDocGuideLines(),
                //                   ),
                //                 );
                //                 final path = await ImageUtils.pickImage(context);
                //                 if (path.isNotEmpty) {
                //                   setState(() {
                //                     _selectedImages[index] = path;
                //                   });
                //                 }
                //               }
                //             },
                //             child: Container(
                //               decoration: BoxDecoration(
                //                 color: Colors.black,
                //                 shape: BoxShape.circle,
                //               ),
                //               padding: EdgeInsets.all(4),
                //               child: Icon(
                //                 image != null ? Icons.close : Icons.add,
                //                 size: 15,
                //                 color: Colors.white,
                //               ),
                //             ),
                //           ),
                //         ),
                //       ],
                //     );
                //   }),
                // ),
                GridView.count(
                  crossAxisCount: 3,
                  mainAxisSpacing: 30,
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  children: List.generate(6, (index) {
                    final imagePath = _selectedImages[index];
                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        GestureDetector(
                          onTap: () async {
                            if (imagePath == null && selectedService == 'Car') {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ExteriorDocGuideLines(),
                                ),
                              );
                              final path = await ImageUtils.pickImage(context);
                              if (path.isNotEmpty) {
                                setState(() {
                                  _selectedImages[index] = path;
                                });
                              }
                            } else {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ExteriorDocGuideLines(),
                                ),
                              );
                              final path = await ImageUtils.pickImage(context);
                              if (path.isNotEmpty) {
                                setState(() {
                                  _selectedImages[index] = path;
                                });
                              }
                            }
                          },
                          child: DottedBorder(
                            color: Colors.grey.withOpacity(0.5),
                            strokeWidth: 1.5,
                            dashPattern: [6, 4],
                            borderType: BorderType.RRect,
                            radius: Radius.circular(10),
                            child: Container(
                              height: 130,
                              width: 97,
                              decoration: BoxDecoration(
                                color: const Color(0xffF8F7F7),
                                borderRadius: BorderRadius.circular(10),
                                image:
                                    imagePath != null
                                        ? DecorationImage(
                                          image: FileImage(File(imagePath)),
                                          fit: BoxFit.cover,
                                        )
                                        : null,
                              ),
                              child:
                                  imagePath == null
                                      ? Center(
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
                                setState(() {
                                  _selectedImages[index] = null;
                                });
                              } else {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (context) => ExteriorDocGuideLines(),
                                  ),
                                );
                                final path = await ImageUtils.pickImage(
                                  context,
                                );
                                if (path.isNotEmpty) {
                                  setState(() {
                                    _selectedImages[index] = path;
                                  });
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
                                imagePath != null ? Icons.close : Icons.add,
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
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: CustomBottomNavigation.bottomNavigation(
        onTap: () async {
          if (selectedService == "Car") {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => InteriorUploadPhotos()),
            );
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => ConsentForms()),
            );
          }
        },
        title: 'Save & Next',
      ),
    );
  }
}
