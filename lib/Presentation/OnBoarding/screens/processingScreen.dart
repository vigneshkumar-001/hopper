import 'package:flutter/material.dart';
import 'package:hopper/Core/Constants/Colors.dart';
import 'package:hopper/Core/Constants/log.dart';
import 'package:hopper/Core/Constants/texts.dart';
import 'package:hopper/Core/Utility/Buttons.dart';
import 'package:hopper/Presentation/OnBoarding/controller/chooseservice_controller.dart';
import 'package:hopper/Presentation/OnBoarding/screens/basicInfo.dart';
import 'package:hopper/Presentation/OnBoarding/screens/chooseService.dart';
import 'package:get/get.dart';
class ProcessingScreen extends StatefulWidget {
  final String? selectedFlag;
  const ProcessingScreen({super.key, this.selectedFlag});

  @override
  State<ProcessingScreen> createState() => _ProcessingScreenState();
}

class _ProcessingScreenState extends State<ProcessingScreen> {
  late List<Map<String, dynamic>> rowData;

  final List<Map<String, dynamic>> carSteps = [
    {'title': 'Basic Info', 'icon': Icons.visibility_outlined},
    {'title': 'Driver Address Details', 'icon': Icons.visibility_outlined},
    {'title': 'Profile Photo', 'icon': Icons.visibility_outlined},
    {'title': 'Identify Verification', 'icon': Icons.visibility_outlined},
    {'title': 'Driver License', 'icon': Icons.visibility_outlined},
    {'title': 'Car Ownership Details', 'icon': Icons.visibility_outlined},
    {'title': 'Vehicle Details', 'icon': Icons.visibility_outlined},
    {'title': 'Exterior Photos', 'icon': Icons.visibility_outlined},
    {'title': 'Interior Photos', 'icon': Icons.visibility_outlined},
  ];

  final List<Map<String, dynamic>> bikeSteps = [
    {'title': 'Basic Info', 'icon': Icons.visibility_outlined},
    {'title': 'Driver Address Details', 'icon': Icons.visibility_outlined},
    {'title': 'Profile Photo', 'icon': Icons.visibility_outlined},
    {'title': 'Identify Verification', 'icon': Icons.visibility_outlined},
    {'title': 'Driver License', 'icon': Icons.visibility_outlined},
    {'title': 'Bike Ownership Details', 'icon': Icons.visibility_outlined},
    {'title': 'Bike Details', 'icon': Icons.visibility_outlined},
    {'title': 'Bike Photos', 'icon': Icons.visibility_outlined},
  ];
  final profile = Get.find<ChooseServiceController>().userProfile.value;
  @override
  void initState() {
    super.initState();

    final isCar = profile?.serviceType == 'Car'; // or add a .toLowerCase() check if needed
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
                          return GestureDetector(
                            onTap: () {
                              CommonLogger.log.i(rowData[index]);
                            },
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      rowData[index]['title'],
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Icon(rowData[index]['icon']),
                                  ],
                                ),

                                Divider(),
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
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => BasicInfo( fromCompleteScreens: false,)),
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
