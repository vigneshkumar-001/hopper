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

class WalletPaymentScreens extends StatefulWidget {
  final String? clientSecret;
  final String? transactionId;
  final String? publishableKey;
  final int? amount;

  const WalletPaymentScreens({
    super.key,

    this.amount,
    required this.publishableKey,
    required this.transactionId,
    required this.clientSecret,
  });

  @override
  State<WalletPaymentScreens> createState() => _WalletPaymentScreensState();
}

class _WalletPaymentScreensState extends State<WalletPaymentScreens> {
  final RideHistoryController Controller = Get.put(RideHistoryController());

  bool _isLoading = false;
  bool payPalLoading = false;
  void _showRatingBottomSheet(BuildContext context) {
    int selectedRating = 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      // shape: const RoundedRectangleBorder(
      //   borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      // ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  Center(
                    child: Container(
                      width: 60,
                      height: 5,

                      decoration: BoxDecoration(
                        color: Colors.grey[400],
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 50),
                    child: Column(
                      children: [
                        Image.asset(AppImages.dummy, height: 65, width: 65),
                        const SizedBox(height: 20),
                        CustomTextfield.textWithStyles600(
                          textAlign: TextAlign.center,
                          fontSize: 20,
                          'Rate your Experience with Rebecca?',
                        ),
                        const SizedBox(height: 25),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 40),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: List.generate(5, (index) {
                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    selectedRating = index + 1;
                                  });
                                  CommonLogger.log.i(selectedRating);
                                },
                                child: Image.asset(
                                  index < selectedRating
                                      ? AppImages.starFill
                                      : AppImages.star1,
                                  height: 48,
                                  width: 48,
                                  color:
                                      index < selectedRating
                                          ? AppColors.commonBlack
                                          : AppColors.buttonBorder,
                                ),
                              );
                              return IconButton(
                                icon: Icon(
                                  Icons.star,
                                  size: 45,
                                  color:
                                      index < selectedRating
                                          ? AppColors.commonBlack
                                          : AppColors.containerColor,
                                ),
                                onPressed: () {
                                  setState(() {
                                    selectedRating = index + 1;
                                  });
                                },
                              );
                            }),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Row(
                            children: [
                              Expanded(
                                child: Buttons.button1(
                                  borderRadius: 8,
                                  textColor: AppColors.commonBlack,
                                  borderColor: AppColors.buttonBorder,
                                  buttonColor: AppColors.commonWhite,
                                  onTap: () {
                                    Navigator.pop(context);
                                  },
                                  text: Text('Close'),
                                ),
                              ),
                              SizedBox(width: 10),
                              Expanded(
                                child: Buttons.button1(
                                  borderRadius: 8,
                                  buttonColor: AppColors.commonBlack,
                                  onTap: () {
                                    // final String bookingId =
                                    //     widget.bookingId ?? '';
                                    // selectedRating;
                                    // AppLogger.log.i(selectedRating);
                                    // driverSearchController.rateDriver(
                                    //   bookingId: bookingId,
                                    //   rating: selectedRating.toString(),
                                    //   context: context,
                                    // );
                                  },
                                  text: Text('Rate Ride'),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Map<String, dynamic>? paymentIntentData;

  /*Future<void> makePayment() async {
    try {
      paymentIntentData = await createPaymentIntent('1000') ?? {};

      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: paymentIntentData!['clientSecret'],
          style: ThemeMode.light,
          customFlow: false,

          merchantDisplayName: 'Hoppr',
        ),
      );

      displayPaymentSheet();
    } catch (e) {
      AppLogger.log.i('Exception: $e');
    }
  }*/

  Future<void> initStripe() async {
     Stripe.publishableKey = widget.publishableKey ?? "";

     // Initialize payment sheet
     await Stripe.instance.initPaymentSheet(
       paymentSheetParameters: SetupPaymentSheetParameters(
         paymentIntentClientSecret: widget.clientSecret!, // ✅ Direct from API
         merchantDisplayName: "Hoppr",
         style: ThemeMode.light,
       ),
     );
  }

  Future<void> makePayment() async {
  try {
    await Stripe.instance.presentPaymentSheet();

    // confirm payment to your backend
    await confirmPayment(widget.transactionId ?? "");

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Controller.customerWalletHistory();

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
  } catch (e) {
    CommonLogger.log.e("❌ Stripe error: $e");
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text("Payment Failed")));
  }
  }

  Future<void> confirmPayment(String transactionId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final String url = ApiConstents.addToWalletResponse;

      // Extract the PaymentIntent ID (remove the _secret part)
      final clientSecret = widget.clientSecret ?? "";
      final paymentIntentId =
          clientSecret.contains("_secret")
              ? clientSecret.split("_secret").first
              : clientSecret;

      final response = await http.post(
        Uri.parse(url),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode({
          "transactionId": transactionId,
          "paymentIntentId": paymentIntentId,
        }),
      );

      CommonLogger.log.i(
        "📩 Confirm Payment API response: ${response.statusCode}",
      );
      CommonLogger.log.i("📩 Response body: ${response.body}");
    } catch (e) {
      CommonLogger.log.e("❌ Error in confirmPayment: $e");
    }
  }

  /*  Future<void> makePayment() async {
    try {
      final result = await createPaymentIntent('1500000');

      if (result == null || !result.containsKey('clientSecret')) {
        AppLogger.log.e("❌ Payment Intent is null or missing 'clientSecret'");
        return;
      }

      paymentIntentData = result;

      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: paymentIntentData!['clientSecret'],
          style: ThemeMode.light,
          customFlow: false,
          merchantDisplayName: 'Hoppr',
        ),
      );

      displayPaymentSheet();
    } catch (e) {
      AppLogger.log.e('💡 Exception in makePayment: $e');
    }
  }*/

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

  // displayPaymentSheet() async {
  //   try {
  //     await Stripe.instance.presentPaymentSheet();
  //
  //     ScaffoldMessenger.of(
  //       context,
  //     ).showSnackBar(SnackBar(content: Text("Payment successful")));
  //   } catch (e) {
  //     AppLogger.log.i('Error: $e');
  //   }
  // }
  /*  displayPaymentSheet() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');

    if (token == null) {
      AppLogger.log.i('⚠️ Token not found in shared preferences');
      return;
    }

    try {
      final String transactionId = widget.transactionId ?? '';
      await Stripe.instance.presentPaymentSheet();

      String? clientSecret = paymentIntentData?['clientSecret'];

      // if (clientSecret != null && clientSecret.contains('_secret')) {
      //   transactionId = clientSecret.split('_secret').first;
      // }

      if (transactionId != null) {
        final String url =  ApiConsents.addToWalletResponse;
        final response = await http.post(
          Uri.parse(
            url,
          ),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            "transactionId": transactionId,
            "paymentIntentId": transactionId,
          }),
        );

        AppLogger.log.i('Confirm Payment Response: ${response.body}');
        if (response.statusCode == 200) {
          _showRatingBottomSheet(context);
          AppLogger.log.i('✅ Payment response confirmed successfully');
        } else {
          AppLogger.log.i('❌ Failed to confirm payment response');
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Payment successful\nTransaction ID: $transactionId"),
        ),
      );

      AppLogger.log.i('✅ Payment successful. Transaction ID: $transactionId');
    } catch (e) {
      AppLogger.log.i('❌ Error during payment sheet presentation: $e');
    }
  }*/

  /*  createPaymentIntent(String amount) async {
    try {
      final String transactionId = widget.transactionId ?? '';
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');

      String url = ApiConsents.addToWalletResponse;

      final response = await http.post(
        Uri.parse(url),

        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'transactionId': transactionId,
          'paymentIntentId': widget.clientSecret,
        }),
      );

      AppLogger.log.i('Status code: ${response.statusCode}');
      AppLogger.log.i('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        AppLogger.log.i('Decoded payment intent response: $decoded');
        return decoded;
      } else {
        throw Exception('Failed to create payment intent');
      }
    } catch (err) {
      AppLogger.log.i('err charging user: $err');
    }
  }*/
  @override
  void initState() {
    super.initState();
    initStripe();
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

                      Container(
                        height: 50,
                        width: 170,
                        padding: EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.containerColor1,
                          border: Border.all(color: AppColors.containerColor),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Image.asset(
                              AppImages.applePay,
                              height: 24,
                              width: 40,
                            ),
                            SizedBox(width: 10),
                            CustomTextfield.textWithStylesSmall(
                              'Apple Pay',
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              colors: AppColors.commonBlack,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 15),
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
