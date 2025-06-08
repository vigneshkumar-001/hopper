import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../Core/Utility/images.dart';
import 'GetStarted_Screens.dart';
import '../../OnBoarding/controller/chooseservice_controller.dart';
import 'package:get/get.dart';

class LandingScreens extends StatefulWidget {
  const LandingScreens({super.key});

  @override
  State<LandingScreens> createState() => _LandingScreensState();
}

class _LandingScreensState extends State<LandingScreens> {
  final ChooseServiceController controller = Get.find();
  Future<void> loadAndNavigate() async {
    await controller.getUserDetails();
    controller.handleLandingPageNavigation(Get.context!);
  }

  Future<void> getUserDetail() async {
    await controller.getUserDetails();
    controller.getUserDetails();
  }

  @override
  void initState() {
    super.initState();
    getUserDetail();
    //loadAndNavigate();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black.withOpacity(0.5),
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
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Top content (welcome text)
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          RichText(
                            textAlign: TextAlign.center,
                            text: TextSpan(
                              style: TextStyle(
                                fontSize: 28,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                              children: [
                                TextSpan(text: "Welcome to\n"),
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
                          SizedBox(height: 20),
                          Text(
                            "Drive on your terms. Earn with Nigeria's\ntrusted ride-hailing app.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Bottom buttons
                  Column(
                    children: [
                      SizedBox(
                        height: 50,
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => GetStartedScreens(),
                              ),
                            );
                          },
                          child: const Text(
                            "Create an account",
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                      const SizedBox(height: 15),
                      SizedBox(
                        height: 50,
                        width: double.infinity,
                        child: OutlinedButton(
                          style: ElevatedButton.styleFrom(
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          onPressed: () {},
                          child: const Text(
                            "Login",
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                      const SizedBox(height: 30), // padding from bottom
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    return Scaffold(
      backgroundColor: Colors.black.withOpacity(0.5),
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
                    RichText(
                      textAlign: TextAlign.center,
                      text: const TextSpan(
                        style: TextStyle(
                          fontSize: 28,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                        children: [
                          TextSpan(text: "Welcome to\n"),
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
                    const SizedBox(height: 20),

                    const Text(
                      "Drive on your terms. Earn with Nigeria's\ntrusted ride-hailing app.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),

                    SizedBox(
                      height: 50,
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,

                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => GetStartedScreens(),
                            ),
                          );
                        },

                        child: const Text("Create an account"),
                      ),
                    ),
                    SizedBox(height: 15),
                    SizedBox(
                      height: 50,
                      width: double.infinity,
                      child: OutlinedButton(
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.white,

                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        onPressed: () {},

                        child: const Text("Login"),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),

      // bottomNavigationBar: BottomAppBar(
      //   color: Colors.black.withOpacity(0.5),
      //   height: 120.h,
      //   child: Column(
      //     children: [
      //       SizedBox(
      //         height: 50,
      //         width: double.infinity,
      //         child: ElevatedButton(
      //           style: ElevatedButton.styleFrom(
      //             backgroundColor: Colors.white,
      //             foregroundColor: Colors.black,
      //
      //             shape: RoundedRectangleBorder(
      //               borderRadius: BorderRadius.circular(30),
      //             ),
      //           ),
      //           onPressed: () {
      //             Navigator.push(
      //               context,
      //               MaterialPageRoute(
      //                 builder: (context) => GetStartedScreens(),
      //               ),
      //             );
      //           },
      //
      //           child: const Text("Create an account"),
      //         ),
      //       ),
      //       SizedBox(height: 15),
      //       SizedBox(
      //         height: 50,
      //         width: double.infinity,
      //         child: OutlinedButton(
      //           style: ElevatedButton.styleFrom(
      //             foregroundColor: Colors.white,
      //
      //             shape: RoundedRectangleBorder(
      //               borderRadius: BorderRadius.circular(30),
      //             ),
      //           ),
      //           onPressed: () {},
      //
      //           child: const Text("Login"),
      //         ),
      //       ),
      //     ],
      //   ),
      // ),
    );
  }
}
