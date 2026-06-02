import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hopper/Core/Constants/log.dart';
import 'package:hopper/Core/Utility/images.dart';
import 'package:hopper/Presentation/Authentication/screens/GetStarted_Screens.dart';
import 'package:hopper/Presentation/OnBoarding/controller/chooseservice_controller.dart';

class PostOtpRoutingScreen extends StatefulWidget {
  const PostOtpRoutingScreen({super.key});

  @override
  State<PostOtpRoutingScreen> createState() => _PostOtpRoutingScreenState();
}

class _PostOtpRoutingScreenState extends State<PostOtpRoutingScreen> {
  late final ChooseServiceController _chooseCtrl;
  bool _isRetrying = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _chooseCtrl = Get.put(ChooseServiceController(), permanent: true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _resolveNextScreen();
    });
  }

  Future<void> _resolveNextScreen() async {
    if (!mounted) return;
    setState(() {
      _isRetrying = true;
      _errorText = null;
    });

    try {
      final details = await _chooseCtrl.getUserDetails();
      if (!mounted) return;

      if (details == null) {
        setState(() {
          _errorText = 'Unable to load your profile. Please try again.';
          _isRetrying = false;
        });
        return;
      }

      _chooseCtrl.handleLandingPageNavigation(clearStack: true);
    } catch (e) {
      CommonLogger.log.e('Post OTP routing failed: $e');
      if (!mounted) return;
      setState(() {
        _errorText = 'Something went wrong. Please try again.';
        _isRetrying = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(AppImages.animation, height: 100, width: 100),
                const SizedBox(height: 20),
                const Text(
                  'Signing you in...',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),
                Text(
                  _errorText ??
                      'Please wait a moment while we prepare your account.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: _errorText == null ? Colors.black54 : Colors.red,
                  ),
                ),
                if (_errorText != null) ...[
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _isRetrying ? null : _resolveNextScreen,
                    child: const Text('Try again'),
                  ),
                  TextButton(
                    onPressed:
                        () => Get.offAll(() => const GetStartedScreens()),
                    child: const Text('Back to login'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
