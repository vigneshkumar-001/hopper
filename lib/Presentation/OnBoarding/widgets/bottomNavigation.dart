import 'package:flutter/material.dart';
import '../../../Core/Constants/Colors.dart';
import '../../../Core/Utility/Buttons.dart';

class CustomBottomNavigation {
  static bottomNavigation({
    required Widget title,


    Color buttonColor = Colors.black,
    Color foreGroundColor = Colors.black,
    required VoidCallback? onTap,
  }) {
    return BottomAppBar(
      color: AppColors.commonWhite,
      child: Column(
        children: [
          Buttons.button(foreGroundColor:foreGroundColor ,
            buttonColor: buttonColor,
            onTap: onTap,
            text: title,
          ),
        ],
      ),
    );
  }
}
