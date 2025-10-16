import 'package:flutter/material.dart';
import 'package:hopper/Core/Constants/Colors.dart';
import 'package:hopper/Core/Utility/Buttons.dart';

import 'package:hopper/Core/Utility/images.dart';
import 'package:hopper/Presentation/Authentication/widgets/textfields.dart';

import 'package:get/get.dart';

import '../../../Core/Utility/app_loader.dart';
import '../controller/ride_history_controller.dart';

class AddMoneyScreen extends StatefulWidget {
  final int? minimumWalletAddBalance;
  final String? customerWalletBalance;
  const AddMoneyScreen({
    super.key,
    this.minimumWalletAddBalance,
    this.customerWalletBalance = '0',
  });

  @override
  State<AddMoneyScreen> createState() => _AddMoneyScreenState();
}

class _AddMoneyScreenState extends State<AddMoneyScreen> {
  final TextEditingController _amountController = TextEditingController();
  final RideHistoryController walletController = Get.put(
    RideHistoryController(),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Row(
                  children: [
                    const Text(
                      "Add Money",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    InkWell(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: const Icon(Icons.close, size: 18),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20),

              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "Add Money to Hoppr Wallet",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          CustomTextfield.textWithStylesSmall(
                            fontWeight: FontWeight.w400,
                            colors: AppColors.commonBlack,
                            'Current balance : ',
                            fontSize: 14,
                          ),
                          CustomTextfield.textWithImage(
                            colors: AppColors.commonBlack,
                            fontWeight: FontWeight.w400,
                            fontSize: 14,
                            text:
                                widget.customerWalletBalance.toString() ?? '0',
                            imagePath: AppImages.bCurrency,
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "Hoppr wallet can only be used to pay for Rides and Packages on Hoppr",
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ),

                      const SizedBox(height: 50),

                      Center(
                        child: TextField(
                          autofocus: true,
                          controller: _amountController,
                          textAlign: TextAlign.center,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                          ),
                          decoration: const InputDecoration(
                            hintText: "0",
                            border: InputBorder.none,
                          ),
                        ),
                      ),

                      const SizedBox(height: 10),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CustomTextfield.textWithStylesSmall(
                            fontWeight: FontWeight.w400,
                            colors: AppColors.commonBlack,
                            'Minimum balance : ',
                            fontSize: 14,
                          ),
                          CustomTextfield.textWithImage(
                            colors: AppColors.commonBlack,
                            fontWeight: FontWeight.w400,
                            fontSize: 14,
                            text:
                                widget.minimumWalletAddBalance.toString() ??
                                '0',
                            imagePath: AppImages.bCurrency,
                          ),
                        ],
                      ),

                      const SizedBox(height: 15),

                      // Quick add buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _quickAddButton(100),
                          const SizedBox(width: 10),
                          _quickAddButton(200),
                          const SizedBox(width: 10),
                          _quickAddButton(500),
                        ],
                      ),

                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ),
              SafeArea(
                child: Obx(() {
                  final data = walletController.walletData.value;
                  if (walletController.isLoading.value) {
                    return AppLoader.appLoader();
                  }
                  return Buttons.button(
                    buttonColor: AppColors.commonBlack,
                    onTap:
                        walletController.isLoading.value
                            ? null
                            : () async {
                              final text = _amountController.text.trim();

                              if (text.isEmpty) {
                                Get.snackbar("Error", "Please enter an amount");
                                return;
                              }

                              final double? amount = double.tryParse(text);
                              if (amount == null) {
                                Get.snackbar("Error", "Invalid amount entered");
                                return;
                              }

                              walletController.addWallet(
                                amount: amount,
                                method: 'STRIPE',
                              );
                            },

                    text: Text('Add Money'),
                  );
                }),
              ),

              const SizedBox(height: 15),
            ],
          ),
        ),
      ),
    );
  }

  Widget _quickAddButton(int amount) {
    return OutlinedButton(
      onPressed: () {
        _amountController.text = amount.toString();
      },
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
        side: const BorderSide(color: Colors.transparent),
        backgroundColor: AppColors.addMoney,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      child: Row(
        children: [
          Icon(Icons.add, color: AppColors.changeButtonColor),
          Text(
            "  $amount",
            style: TextStyle(color: AppColors.changeButtonColor),
          ),
        ],
      ),
    );
  }
}
