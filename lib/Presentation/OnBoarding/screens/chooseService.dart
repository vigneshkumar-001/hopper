import 'package:flutter/material.dart';
import 'package:hopper/Core/Constants/Colors.dart';
import 'package:hopper/Core/Constants/log.dart';
import 'package:hopper/Core/Constants/texts.dart';
import 'package:hopper/Core/Utility/Buttons.dart';
import 'package:hopper/Core/Utility/images.dart';
import 'package:hopper/Presentation/OnBoarding/screens/processingScreen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hopper/Presentation/Authentication/widgets/customContainer.dart';
String selectedService = '';
class ChooseService extends StatefulWidget {
  const ChooseService({super.key});

  @override
  State<ChooseService> createState() => _ChooseServiceState();
}

class _ChooseServiceState extends State<ChooseService> {
  int selectedIndex = -1;

  // Future<void> saveSelectedService(String service) async {
  //   final prefs = await SharedPreferences.getInstance();
  //   await prefs.setString('selected_service', service);
  // }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 25),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Choose your service',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 25),
              ),
              SizedBox(height: 16),
              Text(
                'Select one service to begin your onboarding',
                style: TextStyle(color: AppColors.textColor),
              ),
              SizedBox(height: 32),

              CustomContainer.container(
                isSelected: selectedIndex == 0,
                onSelectionChanged: (bool value) {
                  setState(() {
                    selectedIndex = value ? 0 : -1;
                    selectedService = value ? 'Car' : '';
                  });

                  print('Selected service: $selectedService');
                },
                onTap: () {},
                serviceType: 'Car',
                serviceTypeImage: AppImages.car,
                serviceText: 'Ride Passenger',
                content: AppTexts.carText,
              ),
              SizedBox(height: 32),
              CustomContainer.container(
                isSelected: selectedIndex == 1,
                onSelectionChanged: (bool value) {
                  setState(() {
                    selectedIndex = value ? 1 : -1;
                    selectedService = value ? 'Bike' : '';
                  });

                  print('Selected service: $selectedService');
                },
                onTap: () {},
                serviceType: 'Bike',
                serviceTypeImage: AppImages.bike,
                serviceText: 'Package Delivery',
                content: AppTexts.bikeText,
              ),
              SizedBox(height: 32),
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: "Note: ",
                      style: TextStyle(
                        color: AppColors.commonBlack,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    TextSpan(
                      text: AppTexts.noteText,
                      style: TextStyle(
                        color: AppColors.textColor,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              Spacer(),
              Buttons.button(
                buttonColor: AppColors.commonBlack,
                textColor: AppColors.commonWhite,
                onTap: () {
                  if (selectedService.isEmpty) {
                    CommonLogger.log.e('Not Choosing Any');
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (context) =>
                                ProcessingScreen(selectedFlag: selectedService),
                      ),
                    );
                  }
                },
                text: 'Continue',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
