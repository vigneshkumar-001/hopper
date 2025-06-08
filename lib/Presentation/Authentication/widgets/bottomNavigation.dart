import 'package:flutter/material.dart';
import '../../../Core/Constants/Colors.dart';
import '../../../Core/Utility/images.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class CommonBottomNavigationBar extends StatelessWidget {
  final VoidCallback onBackPressed;
  final VoidCallback onNextPressed;
  final String nextButtonText;
  final Color backgroundColor;
  final Color buttonColor;
  final Color containerColor;
  final String backButtonImage;
  final String rightButtonImage;
  final String? termsAndConditionsText;

  final bool isChecked;
  final ValueChanged<bool?>? onCheckboxChanged;
  final double? height; // Customizable height
  const CommonBottomNavigationBar({
    Key? key,
    required this.onBackPressed,
    required this.onNextPressed,
    this.nextButtonText = 'Next',
    required this.backgroundColor,
    required this.buttonColor,
    required this.containerColor,
    required this.backButtonImage,
    required this.rightButtonImage,
    this.termsAndConditionsText,
    this.height,
    this.isChecked = false,
    this.onCheckboxChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      height: height,
      color: backgroundColor,
      child: Column(
        children: [
          if (termsAndConditionsText != null) ...[
            const Divider(color: AppColors.dividerColor1, thickness: 1),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: TextStyle(
                        color: AppColors.commonBlack,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                      children: [
                        TextSpan(text: "I Agree on Hoppr "),
                        TextSpan(
                          text: termsAndConditionsText!,
                          style: TextStyle(
                            color: Colors.blue,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                CheckboxTheme(
                  data: CheckboxThemeData(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                    side: BorderSide(color: AppColors.checkBox, width: 2),
                  ),
                  child: Checkbox(
                    value: isChecked,
                    onChanged: onCheckboxChanged,
                    activeColor: Colors.blue,
                    checkColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              InkWell(
                onTap: () {
                  Navigator.pop(context);
                },
                child: Container(
                  height: 52,
                  width: 52,
                  decoration: BoxDecoration(
                    color: AppColors.containerColor,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8.0,
                      vertical: 8,
                    ),
                    child: Image.asset(backButtonImage),
                  ),
                ),
              ),
              SizedBox(
                width: 112,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    foregroundColor: AppColors.commonWhite,
                    backgroundColor: buttonColor,
                  ),
                  onPressed: onNextPressed,
                  child: Row(
                    children: [
                      Text(nextButtonText),
                      const Spacer(),
                      Image.asset(rightButtonImage, height: 32, width: 32),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
