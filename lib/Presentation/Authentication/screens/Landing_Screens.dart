import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hopper/Presentation/Authentication/screens/GetStarted_Screens.dart';

class LandingScreens extends StatefulWidget {
  const LandingScreens({super.key});

  @override
  State<LandingScreens> createState() => _LandingScreensState();
}

class _LandingScreensState extends State<LandingScreens> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black.withOpacity(0.5),
      body: SafeArea(
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

                // Subtitle Text
                const Text(
                  "Drive on your terms. Earn with Nigeria's\ntrusted ride-hailing app.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      ),

      bottomNavigationBar: BottomAppBar(
        color: Colors.black.withOpacity(0.5),
        height: 120.h,
        child: Column(
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
    );
  }
}
