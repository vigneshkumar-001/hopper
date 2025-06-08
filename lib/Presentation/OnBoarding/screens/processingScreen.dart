import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../Core/Constants/Colors.dart';
import '../../../Core/Constants/log.dart';
import '../../../Core/Constants/texts.dart';
import '../../../Core/Utility/Buttons.dart';
import '../../../Core/Utility/images.dart';
import '../controller/chooseservice_controller.dart';
import 'basicInfo.dart';

class ProcessingScreen extends StatefulWidget {
  final String? type;
  final String? selectedFlag;
  const ProcessingScreen({super.key, this.selectedFlag, this.type});

  @override
  State<ProcessingScreen> createState() => _ProcessingScreenState();
}

class _ProcessingScreenState extends State<ProcessingScreen> {
  late List<Map<String, dynamic>> rowData;

  final List<Map<String, dynamic>> carSteps = [
    {'title': 'Basic Info', 'image': AppImages.lock},
    {'title': 'Driver Address Details','image': AppImages.lock},
    {'title': 'Profile Photo', 'image': AppImages.lock},
    {'title': 'Identify Verification', 'image': AppImages.lock},
    {'title': 'Driver License', 'image': AppImages.lock},
    {'title': 'Car Ownership Details', 'image': AppImages.lock},
    {'title': 'Vehicle Details', 'image': AppImages.lock},
    {'title': 'Exterior Photos', 'image': AppImages.lock},
    {'title': 'Interior Photos', 'image': AppImages.lock},
  ];

  final List<Map<String, dynamic>> bikeSteps = [
    {'title': 'Basic Info', 'image': AppImages.lock},
    {'title': 'Driver Address Details', 'image': AppImages.lock},
    {'title': 'Profile Photo', 'image': AppImages.lock},
    {'title': 'Identify Verification', 'image': AppImages.lock},
    {'title': 'Driver License', 'image': AppImages.lock},
    {'title': 'Bike Ownership Details', 'image': AppImages.lock},
    {'title': 'Bike Details', 'image': AppImages.lock},
    {'title': 'Bike Photos', 'image': AppImages.lock},
  ];
  final profile = Get.find<ChooseServiceController>().userProfile.value;
  @override
  void initState() {
    super.initState();

    final isCar =
        profile?.serviceType ==
        'Car'; // or add a .toLowerCase() check if needed
    final serviceType = isCar ? 'Car' : 'Bike';

    if (serviceType == 'Bike') {
      rowData = bikeSteps;
    } else {
      rowData = carSteps;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppTexts.processText,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 25),
              ),

              SizedBox(height: 15),
              Text(
                AppTexts.processContent,
                style: TextStyle(color: AppColors.textColor),
              ),
              SizedBox(height: 32),
              Container(
                decoration: BoxDecoration(
                  color: Color(0xffF5F5F7),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Color(0xffD9D9D9)),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 16.0,
                    horizontal: 16,
                  ),
                  child: Column(
                    spacing: 10,
                    children: [
                      ListView.builder(
                        shrinkWrap: true,
                        physics: NeverScrollableScrollPhysics(),
                        itemCount: rowData.length,
                        itemBuilder: (context, index) {
                          final item = rowData[index];
                          final isBasicInfo = item['title'] == 'Basic Info';

                          return GestureDetector(
                            onTap: () {
                              CommonLogger.log.i(item);
                            },
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      item['title'],
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    if (!isBasicInfo)
                                      Image.asset(
                                        item['image']?? '',
                                        height: 20,
                                        width: 20,
                                      ),
                                  ],
                                ),
                                if (index != rowData.length - 1) Divider(),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              Spacer(),

              Buttons.button(
                buttonColor: AppColors.commonBlack,

                onTap: () {
                  final nextPage =
                      widget.type == 'googleSignIn'
                          ? BasicInfo(
                            fromCompleteScreens: false,
                            type: 'googleSignIn',
                          )
                          : BasicInfo(fromCompleteScreens: false);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => nextPage),
                  );
                },
                text: "Start Application",
              ),
            ],
          ),
        ),
      ),
    );
  }
}
