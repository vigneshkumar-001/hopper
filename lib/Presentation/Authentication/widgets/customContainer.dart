import 'package:flutter/material.dart';
import '../../../Core/Constants/Colors.dart';

class CustomContainer {
  static final CustomContainer _singleton = CustomContainer._internal();

  CustomContainer._internal();

  static CustomContainer get instance => _singleton;

  static container({
    required GestureTapCallback? onTap,

    required String serviceType,
    required String serviceTypeImage,
    required String serviceText,
    required String content,
    required bool isSelected,
    required ValueChanged<bool> onSelectionChanged,

    Color? buttonColor,

    bool? isLoading,
    bool hasBorder = false,
  }) {
    return GestureDetector(
      onTap: () {
        print('iam seelcted $isSelected');
        onSelectionChanged(!isSelected);
      },
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.containerColor1,
          border:
              isSelected
                  ? Border.all(color: AppColors.containerBorder)
                  : Border.all(color: AppColors.containerColor1),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            children: [
              Row(
                children: [
                  Image.asset(serviceTypeImage, height: 32, width: 32),
                  SizedBox(width: 10),
                  Text(
                    serviceType,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                  ),
                  Spacer(),
                  Container(
                    decoration: BoxDecoration(
                      color: Color(0xffC0E3FF),
                      borderRadius: BorderRadius.circular(40),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8.0,
                        vertical: 4,
                      ),
                      child: Text(
                        serviceText,
                        style: TextStyle(color: Color(0xff2295F2)),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 15),
              Text(content, style: TextStyle(color: AppColors.textColor)),
            ],
          ),
        ),
      ),
    );
  }
}
