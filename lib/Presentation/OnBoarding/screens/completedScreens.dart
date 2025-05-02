import 'package:hopper/Core/Constants/log.dart';
import 'package:flutter/material.dart';
import 'package:hopper/Core/Constants/texts.dart';
import 'package:hopper/Core/Utility/images.dart';
import 'package:hopper/Presentation/OnBoarding/screens/chooseService.dart';
import 'package:hopper/Presentation/OnBoarding/widgets/linearProgress.dart';

class CompletedScreens extends StatefulWidget {
  const CompletedScreens({super.key});

  @override
  State<CompletedScreens> createState() => _CompletedScreensState();
}

class _CompletedScreensState extends State<CompletedScreens> {
  late List<Map<String, dynamic>> rowData;
  final List<Map<String, dynamic>> carSteps = [
    {'title': 'Basic Info', 'icon': Icons.lock},
    {'title': 'Driver Address Details', 'icon': Icons.lock},
    {'title': 'Profile Photo', 'icon': Icons.lock},
    {'title': 'Identify Verification', 'icon': Icons.lock},
    {'title': 'Driver License', 'icon': Icons.lock},
    {'title': 'Car Ownership Details', 'icon': Icons.lock},
    {'title': 'Vehicle Details', 'icon': Icons.lock},
    {'title': 'Exterior Photos', 'icon': Icons.lock},
    {'title': 'Interior Photos', 'icon': Icons.lock},
  ];

  final List<Map<String, dynamic>> bikeSteps = [
    {'title': 'Basic Info', 'icon': Icons.lock},
    {'title': 'Driver Address Details', 'icon': Icons.lock},
    {'title': 'Profile Photo', 'icon': Icons.lock},
    {'title': 'Identify Verification', 'icon': Icons.lock},
    {'title': 'Driver License', 'icon': Icons.lock},
    {'title': 'Bike Ownership Details', 'icon': Icons.lock},
    {'title': 'Bike Details', 'icon': Icons.lock},
    {'title': 'Bike Photos', 'icon': Icons.lock},
  ];

  @override
  void initState() {
    super.initState();

    if (selectedService == 'Bike') {
      rowData = bikeSteps;
    } else {
      rowData = carSteps;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
            child: Column(
              children: [
                Center(child: Image.asset(AppImages.waitingReview)),
                SizedBox(height: 24),
                Text(
                  AppTexts.awaitingReview,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
                ),
                SizedBox(height: 24),
                Text(textAlign: TextAlign.center, AppTexts.awaitingContent),
                SizedBox(height: 24),
                Image.asset(AppImages.dummyProfile),
                SizedBox(height: 10),
                Container(
                  width: MediaQuery.of(context).size.width * 0.5,
                  child: CustomLinearProgress.linearProgressIndicator(
                    value: 10,
                    progressColor: Color(0xff009721),
                    minHeight: 4,
                  ),
                ),
                SizedBox(height: 10),
                Text('100% profile completed'),
                SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Color(0xffF5F5F7),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Color(0xffD9D9D9)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Settings',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),

                              Icon(Icons.settings),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 15),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Color(0xffF5F5F7),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Color(0xffD9D9D9)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'FAQ',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),

                              Icon(Icons.settings),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 24),
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
