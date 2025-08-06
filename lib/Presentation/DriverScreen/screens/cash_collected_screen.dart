import 'package:flutter/material.dart';
import 'package:hopper/Core/Constants/Colors.dart';
import 'package:hopper/Core/Constants/log.dart';
import 'package:hopper/Core/Utility/Buttons.dart';
import 'package:hopper/Core/Utility/images.dart';
import 'package:hopper/Presentation/Authentication/widgets/textFields.dart';
import 'package:hopper/Presentation/DriverScreen/screens/driver_main_screen.dart';

import '../../../utils/netWorkHandling/network_handling_screen.dart';

class CashCollectedScreen extends StatefulWidget {
  const CashCollectedScreen({super.key});

  @override
  State<CashCollectedScreen> createState() => _CashCollectedScreenState();
}

class _CashCollectedScreenState extends State<CashCollectedScreen> {
  @override
  Widget build(BuildContext context) {
    return NoInternetOverlay(
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.0, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                  },
                  child: Image.asset(
                    AppImages.backButton,
                    height: 25,
                    width: 25,
                  ),
                ),
                const Spacer(), // pushes content to center vertically
                Center(
                  child: Image.asset(AppImages.dummyImg, height: 80, width: 80),
                ),
                SizedBox(height: 10),
                Center(
                  child: Column(
                    children: [
                      CustomTextfield.textWithStylesSmall(
                        'Collect cash from Rebecca',
                        colors: AppColors.grey,
                        fontSize: 14,
                      ),
                      SizedBox(height: 20),
                      CustomTextfield.textWithImage(
                        fontSize: 40,
                        fontWeight: FontWeight.w700,
                        colors: AppColors.commonBlack,
                        text: '73.5',
                        imagePath: AppImages.bCurrency,
                        imageSize: 44,
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.directionColor.withOpacity(0.1),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Image.asset(
                        color: AppColors.directionColor,
                        AppImages.exclamationCircle,
                        width: 20,
                        height: 20,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CustomTextfield.textWithStylesSmall(
                              fontWeight: FontWeight.w400,
                              colors: AppColors.commonBlack,
                              'If rider don’t have change, ask them to pay in wholesums, extra amount paid will be credited to riders account',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 30),
                SafeArea(
                  child: Buttons.button(
                    borderRadius: 7,
                    buttonColor: AppColors.commonBlack,
                    onTap: () {
                      _showRatingBottomSheet(context);
                    },
                    text: Text('Cash Collected'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showRatingBottomSheet(BuildContext context) {
    int selectedRating = 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      // shape: const RoundedRectangleBorder(
      //   borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      // ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  Center(
                    child: Container(
                      width: 60,
                      height: 5,

                      decoration: BoxDecoration(
                        color: Colors.grey[400],
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 50),
                    child: Column(
                      children: [
                        Image.asset(AppImages.dummyImg, height: 65, width: 65),
                        const SizedBox(height: 20),
                        CustomTextfield.textWithStyles600(
                          textAlign: TextAlign.center,
                          fontSize: 20,
                          'Rate your Experience with Rebecca?',
                        ),
                        const SizedBox(height: 25),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 40),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: List.generate(5, (index) {
                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    selectedRating = index + 1;
                                  });
                                  CommonLogger.log.i(selectedRating);
                                },
                                child: Image.asset(
                                  index < selectedRating
                                      ? AppImages.starFill
                                      : AppImages.star,
                                  height: 48,
                                  width: 48,
                                  color:
                                      index < selectedRating
                                          ? AppColors.commonBlack
                                          : AppColors.buttonBorder,
                                ),
                              );
                              return IconButton(
                                icon: Icon(
                                  Icons.star,
                                  size: 45,
                                  color:
                                      index < selectedRating
                                          ? AppColors.commonBlack
                                          : AppColors.containerColor,
                                ),
                                onPressed: () {
                                  setState(() {
                                    selectedRating = index + 1;
                                  });
                                },
                              );
                            }),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Row(
                            children: [
                              Expanded(
                                child: Buttons.button(
                                  borderRadius: 8,
                                  textColor: AppColors.commonBlack,
                                  borderColor: AppColors.buttonBorder,
                                  buttonColor: AppColors.commonWhite,
                                  onTap: () {
                                    Navigator.pop(context);
                                  },
                                  text: Text('Close'),
                                ),
                              ),
                              SizedBox(width: 10),
                              Expanded(
                                child: Buttons.button(
                                  borderRadius: 8,
                                  buttonColor: AppColors.commonBlack,
                                  onTap: () {
                                    selectedRating;
                                    CommonLogger.log.i(selectedRating);
                                    Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(
                                        builder:
                                            (context) => DriverMainScreen(),
                                      ),
                                    );
                                  },
                                  text: Text('Rate Ride'),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
