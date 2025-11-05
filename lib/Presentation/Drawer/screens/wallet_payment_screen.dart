import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:hopper/Core/Constants/log.dart';
import 'package:hopper/Core/Utility/Buttons.dart';
import 'package:hopper/Presentation/Drawer/controller/ride_history_controller.dart';
import 'package:hopper/Presentation/Drawer/screens/wallet_screen.dart';
import 'package:hopper/api/repository/api_constents.dart';

import 'package:url_launcher/url_launcher.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:hopper/Core/Utility/app_loader.dart';
import 'package:hopper/Presentation/Authentication/widgets/textfields.dart';

import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:get/get.dart';

import '../../../Core/Constants/Colors.dart';
import '../../../Core/Utility/images.dart';
import '../../../Core/Utility/snackbar.dart';
import '../../../payment_web_view.dart';

class WalletPaymentScreens extends StatefulWidget {
  final int? amount;

  const WalletPaymentScreens({super.key, this.amount});

  @override
  State<WalletPaymentScreens> createState() => _WalletPaymentScreensState();
}

class _WalletPaymentScreensState extends State<WalletPaymentScreens> {
  final RideHistoryController Controller = Get.put(RideHistoryController());

  bool _isLoading = false;
  bool payStackLoading = false;
  bool flutterWaveLoading = false;
  bool payPalLoading = false;

  Map<String, dynamic>? paymentIntentData;

  Future<void> payPall() async {
    // Navigator.push(
    //   context,
    //   MaterialPageRoute(
    //     builder:
    //         (context) => PaypalWebviewPage(
    //           amount: widget.amount.toString() ?? '',
    //           bookingId: widget.bookingId ?? '',
    //         ),
    //   ),
    // );
  }

  Future<void> makePayment() async {
    try {
      // 1️⃣ Create Payment Intent
      paymentIntentData = await createPaymentIntent(widget.amount) ?? {};

      final publishableKey = paymentIntentData!['publishableKey'];
      final clientSecret = paymentIntentData!['clientSecret'];

      if (publishableKey == null || clientSecret == null) {
        CommonLogger.log.e("❌ Missing publishableKey or clientSecret");
        return;
      }

      // 2️⃣ Set the publishable key
      Stripe.publishableKey = publishableKey;
      await Stripe.instance.applySettings();

      // 3️⃣ Initialize the payment sheet
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: 'Hoppr',
          style: ThemeMode.light,
          allowsDelayedPaymentMethods: false,
        ),
      );

      CommonLogger.log.i("✅ Payment sheet initialized successfully");

      // 4️⃣ Present the payment sheet (only once!)
      await Stripe.instance.presentPaymentSheet();
      CommonLogger.log.i("✅ Payment sheet presented successfully");

      // 5️⃣ Confirm payment on backend
      await confirmPaymentBackend();
    } catch (e, s) {
      CommonLogger.log.e('❌ Stripe makePayment error: $e');
      CommonLogger.log.e('Stack trace: $s');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Payment failed: $e")));
    }
  }

  // ✅ Backend confirmation only — no presentPaymentSheet here
  Future<void> confirmPaymentBackend() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) {
      CommonLogger.log.e('⚠️ Token not found');
      return;
    }

    try {
      final transactionId = paymentIntentData?['transactionId'];
      final clientSecret = paymentIntentData?['clientSecret'];
      final paymentIntentId = clientSecret?.split('_secret').first;

      if (transactionId == null || paymentIntentId == null) {
        CommonLogger.log.e('❌ Missing transactionId or paymentIntentId');
        return;
      }

      final body = jsonEncode({
        "transactionId": transactionId,
        "paymentIntentId": paymentIntentId,
      });

      final response = await http.post(
        Uri.parse(ApiConstents.addToWalletResponse),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: body,
      );

      CommonLogger.log.i('Confirm Payment Response: ${response.body}');

      if (response.statusCode == 200) {
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => WalletScreen()),
            (route) => false,
          );
          await Controller.customerWalletHistory();

          CommonLogger.log.i("✅ Payment successful");

          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text("Payment Successful")));
        });
      } else {
        CommonLogger.log.e('❌ Failed to confirm payment: ${response.body}');
      }
    } catch (e, s) {
      CommonLogger.log.e('❌ Error confirming payment: $e');
      CommonLogger.log.e('Stack: $s');
    }
  }

  Future<Map<String, dynamic>?> createPaymentIntent(int? amount) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) {
        CommonLogger.log.e('⚠️ Token not found');
        return null;
      }

      final response = await http.post(
        Uri.parse(ApiConstents.addToWallet),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'amount': amount, 'method': "STRIPE"}),
      );

      CommonLogger.log.i('Status code: ${response.statusCode}');
      CommonLogger.log.i('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        CommonLogger.log.i('Decoded payment intent response: $decoded');
        return decoded;
      } else {
        throw Exception('Failed to create payment intent');
      }
    } catch (err) {
      CommonLogger.log.e('err charging user: $err');
      return null;
    }
  }

  Future<void> payWithFlutterWave() async {
    final prefs = await SharedPreferences.getInstance();

    String? email = prefs.getString('flutterwave_email');
    String? name = prefs.getString('flutterwave_name');
    String? phone = prefs.getString('flutterwave_phone');

    // If any field is empty, show bottom sheet to enter info
    if (email == null ||
        email.isNotEmpty ||
        name == null ||
        name.isEmpty ||
        phone == null ||
        phone.isEmpty) {
      final result = await _showUserInfoBottomSheet(
        context,
        email,
        name,
        phone,
      );

      // If user canceled bottom sheet, stop
      if (result != true) return;

      // After saving, read values again
      email = prefs.getString('flutterwave_email');
      name = prefs.getString('flutterwave_name');
      phone = prefs.getString('flutterwave_phone');
    }

    setState(() => flutterWaveLoading = true);

    try {
      String? token = prefs.getString('token');
      final response = await http.post(
        Uri.parse(
          'https://hoppr-face-two-dbe557472d7f.herokuapp.com/api/users/flutterwave/wallet/initialize',
        ),
        headers: {
          "Content-Type": "application/json",
          if (token != null)
            "Authorization": "Bearer $token", // ✅ Add Bearer token
        },
        body: jsonEncode({
          "amount": widget.amount.toString(),
          "email": email,
          "name": name,
          "phone": phone,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final paymentLink = data['paymentLink'];

        if (paymentLink != null) {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PaymentWebView(url: paymentLink, page: 'wallet'),
            ),
          );

          if (result != null && result["status"] == "success") {
            await Controller.customerWalletHistory();
            CustomSnackBar.showSuccess('Payment Successful');
            CommonLogger.log.i(
              "Payment Successful: ${result["transactionId"]}",
            );

            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => WalletScreen()),
              (route) => false,
            );
          } else {
            CustomSnackBar.showError("Payment failed or cancelled");
          }
        } else {
          final errorMsg = data['message'] ?? "Failed to initialize payment";
          CustomSnackBar.showError(errorMsg);
        }
      } else {
        final errorMsg = data['message'] ?? "Failed to initialize payment";
        CustomSnackBar.showError(errorMsg);
        CommonLogger.log.e(
          'Failed to initialize Flutterwave payment: ${response.body}',
        );
      }
    } catch (e) {
      CustomSnackBar.showError(e.toString());
      CommonLogger.log.e("Error during Flutterwave payment: $e");
    } finally {
      setState(() => flutterWaveLoading = false);
    }
  }

  Future<bool?> _showUserInfoBottomSheet(
    BuildContext context,
    String? email,
    String? name,
    String? phone,
  ) {
    final _emailController = TextEditingController(text: email);
    final _nameController = TextEditingController(text: name);
    final _phoneController = TextEditingController(text: phone);

    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent, // Transparent to get rounded corners
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 10,
                  offset: Offset(0, -4),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 50,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                SizedBox(height: 15),
                Text(
                  "Enter Payment Info",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 25),
                _buildTextField(
                  _emailController,
                  "Email",
                  Icons.email,
                  TextInputType.emailAddress,
                ),
                SizedBox(height: 15),
                _buildTextField(
                  _nameController,
                  "Name",
                  Icons.person,
                  TextInputType.name,
                ),
                SizedBox(height: 15),
                _buildTextField(
                  _phoneController,
                  "Phone",
                  Icons.phone,
                  TextInputType.phone,
                ),
                SizedBox(height: 25),
                Buttons.button(
                  buttonColor: AppColors.commonBlack,
                  onTap: () async {
                    if (_emailController.text.isEmpty ||
                        _nameController.text.isEmpty ||
                        _phoneController.text.isEmpty) {
                      CustomSnackBar.showError("All fields are required");
                      return;
                    }

                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setString(
                      'flutterwave_email',
                      _emailController.text,
                    );
                    await prefs.setString(
                      'flutterwave_name',
                      _nameController.text,
                    );
                    await prefs.setString(
                      'flutterwave_phone',
                      _phoneController.text,
                    );

                    Navigator.pop(context, true);
                  },
                  text: Text('Save & Continue'),
                ),

                SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon,
    TextInputType type,
  ) {
    return TextField(
      controller: controller,
      keyboardType: type,
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: AppColors.commonBlack),
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey[700]),
        filled: true,
        fillColor: Colors.grey[100],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide.none,
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      ),
    );
  }

  Future<void> payWithPayStack() async {
    final prefs = await SharedPreferences.getInstance();

    String? email = prefs.getString('flutterwave_email');
    String? name = prefs.getString('flutterwave_name');
    String? phone = prefs.getString('flutterwave_phone');

    if (email == null ||
        email.isNotEmpty ||
        name == null ||
        name.isEmpty ||
        phone == null ||
        phone.isEmpty) {
      final result = await _showUserInfoBottomSheet(
        context,
        email,
        name,
        phone,
      );

      if (result != true) return;

      email = prefs.getString('flutterwave_email');
      name = prefs.getString('flutterwave_name');
      phone = prefs.getString('flutterwave_phone');
    }

    setState(() => payStackLoading = true);

    try {
      String? token = prefs.getString('token');
      final response = await http.post(
        Uri.parse(
          'https://hoppr-face-two-dbe557472d7f.herokuapp.com/api/users/paystack/wallet/initialize',
        ),
        headers: {
          "Content-Type": "application/json",
          if (token != null) "Authorization": "Bearer $token",
        },
        body: jsonEncode({"amount": widget.amount, "email": email}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final paymentLink = data['paymentLink'];

        if (paymentLink != null) {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => PaymentWebView(url: paymentLink)),
          );

          if (result != null && result["status"] == "success") {
            WidgetsBinding.instance.addPostFrameCallback((_) async {
              // await Controller.getWalletBalance();

              CommonLogger.log.i("✅ Payment successful");
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text("Payment Successful")));
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => WalletScreen()),
                (route) => false,
              );
            });
          } else {
            CustomSnackBar.showError("Payment failed or cancelled");
          }
        } else {
          final errorMsg = data['message'] ?? "Failed to initialize payment";
          CustomSnackBar.showError(errorMsg);
        }
      } else {
        final errorMsg = data['message'] ?? "Failed to initialize payment";
        CustomSnackBar.showError(errorMsg);
        CommonLogger.log.e(
          'Failed to initialize Flutterwave payment: ${response.body}',
        );
      }
    } catch (e) {
      CustomSnackBar.showError(e.toString());
      CommonLogger.log.e("Error during Flutterwave payment: $e");
    } finally {
      setState(() => payStackLoading = false);
    }
  }

  @override
  void initState() {
    super.initState();
  }

  String? selectedPaymentMethod;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Container(
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFFFFFFD), Color(0xFFF6F7FF)],
            ),
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 25,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                        },
                        child: Image.asset(
                          AppImages.backButton,
                          height: 20,
                          width: 20,
                        ),
                      ),
                      SizedBox(width: 20),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CustomTextfield.textWithStyles700(
                            'Hoppr',
                            fontSize: 20,
                          ),
                          CustomTextfield.textWithStylesSmall(
                            'Trusted Businnes',
                          ),
                        ],
                      ),

                      Spacer(),
                      // Image.asset(AppImages.history, height: 20, width: 20),
                    ],
                  ),

                  const SizedBox(height: 30),

                  CustomTextfield.textWithStyles700(
                    'Recommended',
                    fontSize: 17,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      InkWell(
                        onTap:
                            payPalLoading
                                ? null
                                : () async {
                                  setState(() {
                                    payPalLoading = true;
                                  });

                                  await payPall();

                                  setState(() {
                                    payPalLoading = false;
                                  });
                                },
                        child: Container(
                          height: 50,
                          width: 170,
                          padding: EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.commonWhite,
                            border: Border.all(color: AppColors.containerColor),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child:
                              payPalLoading
                                  ? Center(child: AppLoader.circularLoader())
                                  : Row(
                                    children: [
                                      Image.asset(
                                        AppImages.payPall,
                                        height: 24,
                                        width: 24,
                                      ),
                                      SizedBox(width: 10),

                                      CustomTextfield.textWithStylesSmall(
                                        'PayPal',
                                        fontWeight: FontWeight.w500,
                                        fontSize: 16,
                                        colors: AppColors.commonBlack,
                                      ),
                                    ],
                                  ),
                        ),
                      ),

                      InkWell(
                        onTap:
                            flutterWaveLoading
                                ? null
                                : () async {
                                  setState(() {
                                    flutterWaveLoading = true;
                                  });

                                  await payWithFlutterWave();

                                  setState(() {
                                    flutterWaveLoading = false;
                                  });
                                },
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          height: 50,
                          width: 170,
                          padding: EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.commonWhite,
                            border: Border.all(color: AppColors.containerColor),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child:
                                flutterWaveLoading
                                    ? const SizedBox(
                                      height: 24,
                                      width: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color:
                                            Colors
                                                .black, // you can change to AppColors.commonBlack
                                      ),
                                    )
                                    : Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Image.asset(
                                          AppImages.flutter_wave,
                                          height: 24,
                                          width: 40,
                                        ),
                                        const SizedBox(width: 10),
                                        CustomTextfield.textWithStylesSmall(
                                          'Flutter wave',
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                          colors: AppColors.commonBlack,
                                        ),
                                      ],
                                    ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 15),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      InkWell(
                        borderRadius: BorderRadius.circular(30),
                        onTap:
                            _isLoading
                                ? null
                                : () async {
                                  setState(() {
                                    selectedPaymentMethod = "Stripe";
                                    _isLoading = true;
                                  });

                                  await makePayment();

                                  setState(() {
                                    _isLoading = false;
                                  });
                                },
                        child: Container(
                          height: 50,
                          width: 170,
                          padding: EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.commonWhite,
                            border: Border.all(color: AppColors.containerColor),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child:
                              _isLoading
                                  ? Center(child: AppLoader.circularLoader())
                                  : Row(
                                    children: [
                                      Image.asset(AppImages.stripe),
                                      SizedBox(width: 10),
                                      CustomTextfield.textWithStylesSmall(
                                        'Stripe',
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                        colors: AppColors.commonBlack,
                                      ),
                                    ],
                                  ),
                        ),
                      ),
                      InkWell(
                        borderRadius: BorderRadius.circular(30),
                        onTap:
                            payStackLoading
                                ? null
                                : () async {
                                  setState(() {
                                    payStackLoading = true;
                                    // selectedIndex = 4;
                                  });
                                  await payWithPayStack();
                                  setState(() {
                                    payStackLoading = false;
                                  });
                                },
                        child: Container(
                          height: 50,
                          width: 170,
                          padding: EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.commonWhite,
                            border: Border.all(color: AppColors.containerColor),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child:
                              payStackLoading
                                  ? Center(child: AppLoader.circularLoader())
                                  : Row(
                                    children: [
                                      Image.asset(AppImages.payStack),
                                      SizedBox(width: 10),
                                      CustomTextfield.textWithStylesSmall(
                                        'paystack',
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                        colors: AppColors.commonBlack,
                                      ),
                                    ],
                                  ),
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 15),

                  CustomTextfield.textWithStyles700('Card', fontSize: 16),
                  SizedBox(height: 15),
                  customWalletContainer(
                    onTap: () {},
                    title: 'Add a new card',
                    textColor: AppColors.resendBlue,
                    fontWeight: FontWeight.w400,
                    leadingImagePath: AppImages.borderAdd,
                    trailing: Image.asset(
                      AppImages.rightArrow,
                      color: AppColors.commonBlack,
                      width: 16,
                      height: 16,
                    ),
                  ),
                  // SizedBox(height: 15),
                  //
                  // CustomTextfield.textWithStyles700('Wallets', fontSize: 16),
                  // SizedBox(height: 15),
                  // customWalletContainer(
                  //   onTap: () {},
                  //   title: 'Hoppr Wallet',
                  //
                  //   leadingImagePath: AppImages.wallet,
                  //   trailing: CustomTextfield.textWithImage(
                  //     fontWeight: FontWeight.w600,
                  //     text: '0.0',
                  //     colors: AppColors.walletCurrencyColor,
                  //     imagePath: AppImages.bCurrency,
                  //     imageColors: AppColors.walletCurrencyColor,
                  //   ),
                  // ),
                  SizedBox(height: 15),
                  customWalletContainer(
                    onTap: () {},
                    title: 'Crypto',
                    leadingImagePath: AppImages.wallet,
                    trailing: Image.asset(
                      AppImages.rightArrow,
                      width: 16,
                      height: 16,
                    ),
                  ),

                  SizedBox(height: 15),
                  Center(
                    child: CustomTextfield.textWithStylesSmall(
                      'Secured by (Payment Getway) Account & Terms',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: SizedBox(
          height: 100,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 5),
                    CustomTextfield.textWithImage(
                      text: widget.amount.toString() ?? '280',
                      fontSize: 25,
                      colors: AppColors.commonBlack,
                      fontWeight: FontWeight.w700,
                      imageSize: 23,
                      imagePath: AppImages.bCurrency,
                    ),

                    // Row(
                    //   children: [
                    //     GestureDetector(
                    //       onTap: () {
                    //         // Handle view details tap here
                    //       },
                    //       child: CustomTextFields.textWithStylesSmall(
                    //         'View Details',
                    //       ),
                    //     ),
                    //     Icon(Icons.keyboard_arrow_down_outlined, size: 20),
                    //   ],
                    // ),
                  ],
                ),
                const SizedBox(width: 40),
                Expanded(
                  child: Buttons.button(
                    buttonColor: AppColors.commonBlack,
                    onTap: () {
                      if (selectedPaymentMethod == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text("Please select a payment method"),
                          ),
                        );
                        return;
                      }
                    },
                    text: Text('Continue'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static customWalletContainer({
    required VoidCallback onTap,
    required String title,
    FontWeight? fontWeight = FontWeight.w600,
    required String leadingImagePath,
    Widget? trailing,
    Color containerColor = Colors.white,
    Color borderColor = const Color(0xFFE0E0E0),
    Color textColor = Colors.black,
    Color arrowColor = Colors.black,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: borderColor, width: 1),
          color: containerColor,
          borderRadius: BorderRadius.circular(10),
        ),
        padding: const EdgeInsets.symmetric(vertical: 15.0, horizontal: 15),
        child: Row(
          children: [
            Image.asset(
              leadingImagePath,
              height: 26,
              width: 26,
              color: AppColors.commonBlack,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: textColor,
                  fontSize: 15,
                  fontWeight: fontWeight,
                ),
              ),
            ),
            if (trailing != null) trailing,
          ],
        ),
      ),
    );
  }
}
