import 'package:flutter/material.dart';
import 'package:hopper/Core/Constants/Colors.dart';
import 'package:hopper/Core/Utility/images.dart';
import 'package:hopper/Presentation/Authentication/widgets/textFields.dart';
import 'package:get/get.dart';

import '../../../Core/Utility/app_loader.dart';
import '../controller/ride_history_controller.dart';
import '../model/wallet_history_response.dart';
import 'add_money_screens.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final RideHistoryController walletController = Get.put(
    RideHistoryController(),
  );

  int selectedTab = 0;
  bool _isAmountVisible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      walletController.customerWalletHistory();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.containerColor1,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: RefreshIndicator(
            onRefresh: () async {
              return await walletController.customerWalletHistory();
            },
            child: SingleChildScrollView(
              physics: BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 30),
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
                            Image.asset(
                              AppImages.wallet,
                              height: 24,
                              color: AppColors.commonWhite,
                            ),
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
                            fontSize: 25,
                            colors: AppColors.commonWhite,
                            imageColors: AppColors.commonWhite,
                            imageSize: 20,
                          ),
                          child: Obx(
                            () => CustomTextfield.textWithImage(
                              text: walletController.balance.value.toString()
                           ,
                              imagePath: AppImages.bCurrency,
                              fontWeight: FontWeight.w700,
                              fontSize: 20,
                              colors: AppColors.commonWhite,
                              imageColors: AppColors.commonWhite,
                              imageSize: 20,
                            ),
                          ),
                        ),

                        const SizedBox(height: 10),

                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () {
                                  final current =
                                      walletController.balance.value;
                                  Get.to(
                                    () => AddMoneyScreen(
                                      customerWalletBalance: current,
                                      minimumWalletAddBalance: 800,
                                    ),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  elevation: 0,
                                  backgroundColor: AppColors.commonWhite
                                      .withOpacity(0.10),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: CustomTextfield.textWithStyles600(
                                  "Add Money",
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            const SizedBox(width: 15),
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
                                child: CustomTextfield.textWithStyles600(
                                  "Withdraw",
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "Recent Transactions",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  _buildTabs(),
                  const SizedBox(height: 16),
                  Obx(() {
                    if (walletController.isLoading.value) {
                      return Center(child: AppLoader.circularLoader());
                    }

                    List<Transaction> filteredTransactions = [];

                    if (selectedTab == 0) {
                      // All
                      filteredTransactions = walletController.traction;
                    } else if (selectedTab == 1) {
                      // Money In → green color transactions
                      filteredTransactions =
                          walletController.traction
                              .where((tx) => tx.color?.toLowerCase() == "green")
                              .toList();
                    } else if (selectedTab == 2) {
                      // Money Out → red color transactions
                      filteredTransactions =
                          walletController.traction
                              .where((tx) => tx.color?.toLowerCase() == "red")
                              .toList();
                    }

                    if (filteredTransactions.isEmpty) {
                      return Center(child: Text("No transactions found."));
                    }

                    return ListView.builder(
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      itemCount: filteredTransactions.length,
                      itemBuilder: (context, index) {
                        final tx = filteredTransactions[index];

                        return buildTransaction(
                          subtitle2: tx.createdAt.toString() ?? '',
                          image: _getImageByType(tx.imageType.toString() ?? ''),
                          title: tx.displayText.toString() ?? '',
                          subtitle: _getSubtitle(tx),
                          amount:
                              "₦ ${tx.amount}", // no + or -
                          amountColor:
                              tx.color?.toLowerCase() == "green"
                                  ? Colors.green
                                  : Colors.red, // use color field
                        );
                      },
                    );
                  }),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        // GestureDetector(
        //   onTap: () => Navigator.pop(context),
        //   child: Image.asset(AppImages.backButton, height: 19, width: 19),
        // ),
        const Spacer(),
        CustomTextfield.textWithStyles700('Wallet', fontSize: 20),
        const Spacer(),
      ],
    );
  }

  Widget _buildTabs() {
    return Row(
      children: [
        buildTab("All", 0),
        const SizedBox(width: 8),
        buildTab("Money In", 1),
        const SizedBox(width: 8),
        buildTab("Money Out", 2),
      ],
    );
  }

  String _getSubtitle(Transaction tx) {
    if (tx.booking != null) {
      return "${tx.booking!.pickupAddress} → ${tx.booking!.dropAddress}";
    }
    return "Wallet Transaction";
  }

  String _getImageByType(String imageType) {
    switch (imageType) {
      case "Refund":
        return AppImages.refund;
      case "Bike":
        return AppImages.tripPayment;

      default:
        return AppImages.wallet_top;
    }
  }

  Widget buildTab(String text, int index) {
    bool isSelected = selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => selectedTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(
            text,
            style: TextStyle(
              color: isSelected ? Colors.black : Colors.black54,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget buildTransaction({
    required String image,
    required String title,
    required String subtitle,
    required String subtitle2,
    required String amount,
    required Color amountColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.commonWhite,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.circularClr,
            child: Image.asset(image, height: 35),
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
                Text(
                  subtitle2,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                amount,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: amountColor,
                  fontSize: 14,
                ),
              ),
              const Text(
                'wallet',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// class _WalletScreenState extends State<WalletScreen> {
//   int selectedTab = 0; // 0 = All, 1 = Money In, 2 = Money Out
//   bool _isAmountVisible = false; // toggle variable
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: AppColors.containerColor1,
//
//       body: SafeArea(
//         child: Padding(
//           padding: const EdgeInsets.all(16.0),
//           child: SingleChildScrollView(
//             physics: BouncingScrollPhysics(),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Row(
//                   children: [
//                     GestureDetector(
//                       onTap: () => Navigator.pop(context),
//                       child: Image.asset(
//                         AppImages.backButton,
//                         height: 19,
//                         width: 19,
//                       ),
//                     ),
//                     const Spacer(),
//                     CustomTextfield.textWithStyles700('Wallet', fontSize: 20),
//                     const Spacer(),
//                   ],
//                 ),
//                 SizedBox(height: 30),
//                 Container(
//                   padding: const EdgeInsets.all(16),
//                   decoration: BoxDecoration(
//                     gradient: const LinearGradient(
//                       colors: [Color(0xFF7B61FF), Color(0xFF5B8EFF)],
//                       begin: Alignment.topLeft,
//                       end: Alignment.bottomRight,
//                     ),
//                     borderRadius: BorderRadius.circular(16),
//                   ),
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Row(
//                         children: [
//                           Image.asset(AppImages.wallet, height: 24),
//                           SizedBox(width: 8),
//                           CustomTextfield.textWithStylesSmall(
//                             'Wallet Balance',
//                             fontSize: 15,
//                             colors: AppColors.commonWhite,
//                             fontWeight: FontWeight.w500,
//                           ),
//                           Spacer(),
//                           IconButton(
//                             onPressed: () {
//                               setState(() {
//                                 _isAmountVisible = !_isAmountVisible;
//                               });
//                             },
//                             icon: Icon(
//                               _isAmountVisible
//                                   ? Icons.visibility
//                                   : Icons.visibility_off,
//                               color: Colors.white,
//                             ),
//                           ),
//                         ],
//                       ),
//                       const SizedBox(height: 10),
//                       Visibility(
//                         visible: _isAmountVisible,
//                         replacement: CustomTextfield.textWithImage(
//                           text: '****',
//                           imagePath: AppImages.bCurrency,
//                           fontWeight: FontWeight.w700,
//                           fontSize: 20,
//                           colors: AppColors.commonWhite,
//                           imageColors: AppColors.commonWhite,
//                           imageSize: 20,
//                         ),
//                         child: CustomTextfield.textWithImage(
//                           text: '12.50',
//                           imagePath: AppImages.bCurrency,
//                           fontWeight: FontWeight.w700,
//                           fontSize: 20,
//                           colors: AppColors.commonWhite,
//                           imageColors: AppColors.commonWhite,
//                           imageSize: 20,
//                         ),
//                       ),
//                       const SizedBox(height: 4),
//                       Visibility(
//                         visible: _isAmountVisible,
//                         replacement: CustomTextfield.textWithImage(
//                           text: '**** Pending',
//                           imagePath: AppImages.bCurrency,
//                           fontWeight: FontWeight.w700,
//                           fontSize: 12,
//                           colors: AppColors.walletText,
//                           imageColors: AppColors.walletText,
//                           imageSize: 12,
//                         ),
//                         child: CustomTextfield.textWithImage(
//                           text: '12.50 Pending',
//                           imagePath: AppImages.bCurrency,
//                           fontWeight: FontWeight.w700,
//                           fontSize: 12,
//                           colors: AppColors.walletText,
//                           imageColors: AppColors.walletText,
//                           imageSize: 12,
//                         ),
//                       ),
//                       const SizedBox(height: 16),
//
//                       Row(
//                         children: [
//                           Expanded(
//                             child: ElevatedButton(
//                               onPressed: () {
//                                 Get.to(() => AddMoneyScreen());
//                               },
//                               style: ElevatedButton.styleFrom(
//                                 elevation: 0,
//                                 backgroundColor: AppColors.commonWhite
//                                     .withOpacity(0.10),
//                                 foregroundColor: Colors.white,
//                                 shape: RoundedRectangleBorder(
//                                   borderRadius: BorderRadius.circular(8),
//                                 ),
//                               ),
//                               child: CustomTextfield.textWithStyles600(
//                                 "Add Money",
//                                 fontSize: 16,
//                               ),
//                             ),
//                           ),
//                           const SizedBox(width: 15),
//                           Expanded(
//                             child: ElevatedButton(
//                               onPressed: () {},
//                               style: ElevatedButton.styleFrom(
//                                 elevation: 0,
//                                 backgroundColor: AppColors.commonWhite
//                                     .withOpacity(0.10),
//                                 foregroundColor: Colors.white,
//                                 shape: RoundedRectangleBorder(
//                                   borderRadius: BorderRadius.circular(8),
//                                 ),
//                               ),
//                               child: CustomTextfield.textWithStyles600(
//                                 "Withdraw",
//                                 fontSize: 16,
//                               ),
//                             ),
//                           ),
//                         ],
//                       ),
//                     ],
//                   ),
//                 ),
//
//                 const SizedBox(height: 20),
//
//                 /// Recent Transactions
//                 const Text(
//                   "Recent Transaction",
//                   style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
//                 ),
//
//                 const SizedBox(height: 12),
//
//                 /// Tabs
//                 Row(
//                   children: [
//                     buildTab("All", 0),
//                     const SizedBox(width: 8),
//                     buildTab("Money In", 1),
//                     const SizedBox(width: 8),
//                     buildTab("Money Out", 2),
//                   ],
//                 ),
//
//                 const SizedBox(height: 16),
//
//                 ListView(
//                   shrinkWrap: true,
//                   physics: NeverScrollableScrollPhysics(),
//                   children: [
//                     buildTransaction(
//                       subtitle2: 'Today 7:28 PM',
//                       image: AppImages.tripPayment,
//                       title: "Trip Payment",
//                       subtitle: "Brigade Road to Koramangala",
//                       amount: "- ₦ 143.00",
//                       amountColor: Colors.red,
//                     ),
//                     buildTransaction(
//                       subtitle2: 'Today 7:28 PM',
//                       image: AppImages.wallet_top,
//                       title: "Wallet Top-up",
//                       subtitle: "Added via Credit Card ***4567",
//                       amount: "+ ₦ 20.50",
//                       amountColor: Colors.green,
//                     ),
//                     buildTransaction(
//                       subtitle2: 'Today 7:28 PM',
//                       image: AppImages.packageDelivery,
//                       title: "Package Delivery",
//                       subtitle: "Electronics from Koramangala",
//                       amount: "- ₦ 79.75",
//                       amountColor: Colors.red,
//                     ),
//                     buildTransaction(
//                       subtitle2: 'Today 7:28 PM',
//                       image: AppImages.refund,
//                       title: "Refund Processed",
//                       subtitle: "Cancelled trip refund",
//                       amount: "+ ₦ 17.50",
//                       amountColor: Colors.green,
//                     ),
//                   ],
//                 ),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }
//
//   Widget buildTab(String text, int index) {
//     bool isSelected = selectedTab == index;
//     return Expanded(
//       child: GestureDetector(
//         onTap: () {
//           setState(() {
//             selectedTab = index;
//           });
//         },
//         child: Container(
//           padding: const EdgeInsets.symmetric(vertical: 8),
//           decoration: BoxDecoration(
//             color: isSelected ? Colors.white : Colors.transparent,
//             borderRadius: BorderRadius.circular(8),
//           ),
//           alignment: Alignment.center,
//           child: Text(
//             text,
//             style: TextStyle(
//               color: isSelected ? Colors.black : Colors.black,
//               fontWeight: FontWeight.w500,
//             ),
//           ),
//         ),
//       ),
//     );
//   }
//
//   Widget buildTransaction({
//     required String image,
//     required String title,
//     required String subtitle,
//     required String subtitle2,
//     required String amount,
//     required Color amountColor,
//   }) {
//     return Container(
//       margin: const EdgeInsets.only(bottom: 12),
//       padding: const EdgeInsets.all(12),
//       decoration: BoxDecoration(
//         color: AppColors.commonWhite,
//         borderRadius: BorderRadius.circular(12),
//       ),
//       child: Row(
//         children: [
//           CircleAvatar(
//             backgroundColor: AppColors.circularClr,
//             child: Image.asset(image, height: 35),
//           ),
//           const SizedBox(width: 12),
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   title,
//                   style: const TextStyle(
//                     fontWeight: FontWeight.w600,
//                     fontSize: 14,
//                   ),
//                 ),
//                 Text(
//                   subtitle,
//                   style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
//                 ),
//                 Text(
//                   subtitle2,
//                   style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
//                 ),
//               ],
//             ),
//           ),
//           Column(
//             crossAxisAlignment: CrossAxisAlignment.end,
//             children: [
//               Text(
//                 amount,
//                 style: TextStyle(
//                   fontWeight: FontWeight.w600,
//                   color: amountColor,
//                   fontSize: 14,
//                 ),
//               ),
//               Text(
//                 'wallet',
//                 style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
//               ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }
// }
