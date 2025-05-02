import 'package:flutter/material.dart';
import 'package:hopper/Core/Constants/Colors.dart';
import 'package:hopper/Core/Utility/Buttons.dart';

class CustomBottomNavigation {
  static bottomNavigation({
    required String title,
    required VoidCallback onTap,
  }) {
    return BottomAppBar(
      color: AppColors.commonWhite,
      child: Column(
        children: [
          Buttons.button(
            buttonColor: AppColors.commonBlack,
            onTap: onTap,
            text: title,
          ),
        ],
      ),
    );
  }
}
