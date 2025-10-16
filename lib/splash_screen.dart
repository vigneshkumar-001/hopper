import 'package:flutter/material.dart';
import 'package:hopper/Presentation/Authentication/screens/GetStarted_Screens.dart';
import 'package:hopper/Presentation/OnBoarding/controller/chooseservice_controller.dart';

import 'Core/Utility/images.dart';
import 'Presentation/Authentication/screens/Landing_Screens.dart';
import 'package:get/get.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final ChooseServiceController controller = Get.put(ChooseServiceController());
  Future<void> loadAndNavigate() async {
    await controller.getUserDetails();
    // await Future.delayed(const Duration(seconds: 2));

    // Use mounted check to avoid calling context after dispose
    // if (!mounted) return;
    //
    // controller.handleLandingPageNavigation(context);
  }

  @override
  void initState() {
    super.initState();
    print('Iam Calling');
    //getUserDetail();
    loadAndNavigate();
    Future.delayed(const Duration(seconds: 4), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const GetStartedScreens()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Image.asset(
            AppImages.splashScreen,
            fit: BoxFit.cover,
            height: double.infinity,
            width: double.infinity,
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(AppImages.roundCar, height: 60, width: 60),
                    RichText(
                      textAlign: TextAlign.center,
                      text: const TextSpan(
                        style: TextStyle(
                          fontSize: 28,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                        children: [
                          TextSpan(
                            text: "Hoppr ",
                            style: TextStyle(color: Colors.white),
                          ),
                          TextSpan(
                            text: "Partner",
                            style: TextStyle(color: Colors.amber),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
