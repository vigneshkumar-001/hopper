import 'package:flutter/material.dart';
import 'package:hopper/Core/Constants/Colors.dart';
import 'package:hopper/Core/Utility/images.dart';
import 'package:hopper/Presentation/Authentication/widgets/textFields.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  int selectedTab = 0; // 0 = All, 1 = Money In, 2 = Money Out
  bool _isAmountVisible = false; // toggle variable
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // appBar: AppBar(
      //   title: const Text("Wallet"),
      //   leading: IconButton(
      //     icon: const Icon(Icons.arrow_back),
      //     onPressed: () {},
      //   ),
      //
      //   elevation: 0,
      //   centerTitle: true,
      //   titleTextStyle: const TextStyle(
      //     color: Colors.black,
      //     fontSize: 18,
      //     fontWeight: FontWeight.w600,
      //   ),
      //   iconTheme: const IconThemeData(color: Colors.black),
      // ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Image.asset(
                      AppImages.backButton,
                      height: 19,
                      width: 19,
                    ),
                  ),
                  const Spacer(),
                  CustomTextfield.textWithStyles700(
                    'Ride Activity',
                    fontSize: 20,
                  ),
                  const Spacer(),
                ],
              ),
              SizedBox(height: 30),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7B61FF), Color(0xFF5B8EFF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.wallet, color: Colors.white),
                        SizedBox(width: 8),
                        CustomTextfield.textWithStylesSmall(
                          'Wallet Balance',
                          fontSize: 15,
                          colors: AppColors.commonWhite,
                          fontWeight: FontWeight.w500,
                        ),
                        Spacer(),
                        IconButton(
                          onPressed: () {
                            setState(() {
                              _isAmountVisible = !_isAmountVisible;
                            });
                          },
                          icon: Icon(
                            _isAmountVisible
                                ? Icons.visibility
                                : Icons.visibility_off,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Visibility(
                      visible: _isAmountVisible,
                      replacement: CustomTextfield.textWithImage(
                        text: '****',
                        imagePath: AppImages.bCurrency,
                        fontWeight: FontWeight.w700,
                        fontSize: 20,
                        colors: AppColors.commonWhite,
                        imageColors: AppColors.commonWhite,
                        imageSize: 20,
                      ),
                      child: CustomTextfield.textWithImage(
                        text: '12.50',
                        imagePath: AppImages.bCurrency,
                        fontWeight: FontWeight.w700,
                        fontSize: 20,
                        colors: AppColors.commonWhite,
                        imageColors: AppColors.commonWhite,
                        imageSize: 20,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Visibility(
                      visible: _isAmountVisible,
                      replacement: CustomTextfield.textWithImage(
                        text: '**** Pending',
                        imagePath: AppImages.bCurrency,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        colors: AppColors.walletText,
                        imageColors: AppColors.walletText,
                        imageSize: 12,
                      ),
                      child: CustomTextfield.textWithImage(
                        text: '12.50 Pending',
                        imagePath: AppImages.bCurrency,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        colors: AppColors.walletText,
                        imageColors: AppColors.walletText,
                        imageSize: 12,
                      ),
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {},
                            style: ElevatedButton.styleFrom(
                              elevation: 0,
                              backgroundColor: AppColors.commonWhite
                                  .withOpacity(0.10),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Text("Add Money"),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {},
                            style: ElevatedButton.styleFrom(
                              elevation: 0,
                              backgroundColor: AppColors.commonWhite
                                  .withOpacity(0.10),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Text("Withdraw"),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              /// Recent Transactions
              const Text(
                "Recent Transaction",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),

              const SizedBox(height: 12),

              /// Tabs
              Row(
                children: [
                  buildTab("All", 0),
                  const SizedBox(width: 8),
                  buildTab("Money In", 1),
                  const SizedBox(width: 8),
                  buildTab("Money Out", 2),
                ],
              ),

              const SizedBox(height: 16),

              /// Transaction List
              Expanded(
                child: ListView(
                  children: [
                    buildTransaction(
                      icon: Icons.directions_car,
                      title: "Trip Payment",
                      subtitle: "Brigade Road to Koramangala",
                      amount: "- ₦ 143.00",
                      amountColor: Colors.red,
                    ),
                    buildTransaction(
                      icon: Icons.account_balance,
                      title: "Wallet Top-up",
                      subtitle: "Added via Credit Card ***4567",
                      amount: "+ ₦ 20.50",
                      amountColor: Colors.green,
                    ),
                    buildTransaction(
                      icon: Icons.local_shipping,
                      title: "Package Delivery",
                      subtitle: "Electronics from Koramangala",
                      amount: "- ₦ 79.75",
                      amountColor: Colors.red,
                    ),
                    buildTransaction(
                      icon: Icons.refresh,
                      title: "Refund Processed",
                      subtitle: "Cancelled trip refund",
                      amount: "+ ₦ 17.50",
                      amountColor: Colors.green,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Reusable Tab Widget
  Widget buildTab(String text, int index) {
    bool isSelected = selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            selectedTab = index;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? Colors.black : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(
            text,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.black,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  /// Transaction Item
  Widget buildTransaction({
    required IconData icon,
    required String title,
    required String subtitle,
    required String amount,
    required Color amountColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.white,
            child: Icon(icon, color: Colors.black),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            amount,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: amountColor,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
