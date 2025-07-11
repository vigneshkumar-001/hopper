import 'package:flutter/material.dart';
import 'package:hopper/Core/Constants/Colors.dart';
import 'package:hopper/Core/Utility/Buttons.dart';
import 'package:hopper/Core/Utility/images.dart';
import 'package:hopper/Presentation/Authentication/widgets/textFields.dart';

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
                    onTap: () {},
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
}
