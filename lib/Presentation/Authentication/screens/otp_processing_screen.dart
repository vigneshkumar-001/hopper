import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hopper/Core/Utility/images.dart';
import 'package:hopper/Presentation/Authentication/controller/otp_controller.dart';

class OtpProcessingScreen extends StatefulWidget {
  final String otp;
  final String? type;

  const OtpProcessingScreen({super.key, required this.otp, this.type});

  @override
  State<OtpProcessingScreen> createState() => _OtpProcessingScreenState();
}

class _OtpProcessingScreenState extends State<OtpProcessingScreen> {
  late final OtpController _controller;
  bool _handled = false;

  @override
  void initState() {
    super.initState();
    _controller = Get.find<OtpController>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startVerification();
    });
  }

  Future<void> _startVerification() async {
    if (_handled || !mounted) return;
    _handled = true;

    final result = await _controller.verifyOtp(
      context,
      widget.otp,
      type: widget.type,
    );

    if (!mounted) return;
    final hasError = result != null && result.isNotEmpty;
    if (hasError && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(AppImages.animation, height: 100, width: 100),
              const SizedBox(height: 16),
              const Text(
                'Verifying OTP...',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
