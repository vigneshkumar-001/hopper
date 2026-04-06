import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hopper/Core/Constants/Colors.dart';
import 'package:hopper/Core/Utility/images.dart';
import 'package:hopper/Presentation/Authentication/widgets/textFields.dart';
import 'package:hopper/utils/widgets/hoppr_circular_loader.dart';
import 'package:get/get.dart';
import 'package:hopper/Presentation/Drawer/screens/drawer_screens.dart';

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
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _withdrawAmountController =
      TextEditingController();

  int selectedTab = 0;
  bool _isAmountVisible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      walletController.customerWalletHistory(isRefresh: true);

      _scrollController.addListener(() {
        final trigger = _scrollController.position.maxScrollExtent - 200;
        if (_scrollController.position.pixels > trigger) {
          if (!walletController.isMoreLoading.value &&
              walletController.hasMore.value) {
            walletController.customerWalletHistory();
          }
        }
      });
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _withdrawAmountController.dispose();
    super.dispose();
  }

  void _openWithdrawSheet() {
    _withdrawAmountController.text = '';

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        final balance =
            double.tryParse(walletController.balance.value.toString().trim()) ??
            0.0;
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 14,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 18,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Withdraw',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                'Available balance: ₦ ${balance.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _withdrawAmountController,
                textInputAction: TextInputAction.done,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                decoration: InputDecoration(
                  labelText: 'Amount',
                  hintText: 'Enter amount (e.g. 100.0)',
                  filled: true,
                  fillColor: const Color(0xFFF6F7F9),
                  prefixIcon: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Image.asset(
                      AppImages.bCurrency,
                      width: 18,
                      height: 18,
                      color: AppColors.drkGreen,
                    ),
                  ),
                  prefixIconConstraints: const BoxConstraints(
                    minWidth: 44,
                    minHeight: 44,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: AppColors.drkGreen.withOpacity(0.35),
                      width: 1.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Obx(() {
                final loading = walletController.isWithdrawLoading.value;
                return SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed:
                        loading
                            ? null
                            : () async {
                              final raw = _withdrawAmountController.text.trim();
                              final amt = double.tryParse(raw);
                              if (amt == null || amt <= 0) {
                                Get.snackbar(
                                  'Invalid amount',
                                  'Please enter a valid amount',
                                  backgroundColor: Colors.black87,
                                  colorText: Colors.white,
                                );
                                return;
                              }

                              final bal =
                                  double.tryParse(
                                    walletController.balance.value
                                        .toString()
                                        .trim(),
                                  ) ??
                                  0.0;
                              if (bal > 0 && amt > bal) {
                                Get.snackbar(
                                  'Insufficient balance',
                                  'Amount should be less than or equal to wallet balance',
                                  backgroundColor: Colors.black87,
                                  colorText: Colors.white,
                                );
                                return;
                              }

                              await walletController.requestWithdraw(
                                amount: amt,
                              );
                              if (!mounted) return;
                              if (!walletController.isWithdrawLoading.value) {
                                Navigator.pop(ctx);
                              }
                            },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child:
                        loading
                            ? const HopprCircularLoader(
                              radius: 14,
                              color: Colors.white,
                            )
                            : const Text(
                              'Submit Request',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                  ),
                );
              }),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.containerColor1,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await walletController.customerWalletHistory(isRefresh: true);
          },
          child: CustomScrollView(
            physics: BouncingScrollPhysics(),
            controller: _scrollController,
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: _buildHeader(),
                ),
              ),

              SliverToBoxAdapter(
                child: AnimatedBuilder(
                  animation: walletController,
                  builder: (_, __) => _walletBalanceCard(),
                ),
              ),

              SliverToBoxAdapter(child: SizedBox(height: 10)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: const Text(
                    "Recent Transactions",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),

              SliverToBoxAdapter(child: SizedBox(height: 12)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildTabs(),
                ),
              ),

              SliverToBoxAdapter(child: SizedBox(height: 12)),

              Obx(() {
                if (walletController.isLoading.value &&
                    walletController.traction.isEmpty) {
                  return SliverToBoxAdapter(
                    child: const Center(child: HopprCircularLoader(radius: 14)),
                  );
                }

                List<Transaction> filtered = _filterTransactions();

                if (filtered.isEmpty) {
                  return const SliverToBoxAdapter(
                    child: Center(child: Text("No transactions found")),
                  );
                }

                return SliverList.builder(
                  itemCount: filtered.length + 1,
                  itemBuilder: (context, index) {
                    if (index == filtered.length) {
                      return walletController.isMoreLoading.value
                          ? Padding(
                            padding: const EdgeInsets.all(16),
                            child: const Center(
                              child: HopprCircularLoader(radius: 14),
                            ),
                          )
                          : const SizedBox();
                    }

                    final tx = filtered[index];

                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: buildTransaction(
                        image: _getImageByType(tx.imageType ?? ''),
                        title: tx.displayText ?? '',
                        subtitle: tx.walletDescription ?? '',
                        subtitle2: tx.createdAt.toString(),
                        amount: "₦ ${tx.amount}",
                        amountColor:
                            (tx.color?.toLowerCase() == "green")
                                ? Colors.green
                                : Colors.red,
                      ),
                    );
                  },
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        GestureDetector(
          onTap:
              () => Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => DrawerScreen()),
                (route) => false,
              ),
          child: Image.asset(AppImages.backButton, height: 19, width: 19),
        ),
        const Spacer(),
        CustomTextfield.textWithStyles700('Wallet', fontSize: 20),
        const Spacer(),
      ],
    );
  }

  Widget _walletBalanceCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
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
                Image.asset(AppImages.wallet, height: 24, color: Colors.white),
                const SizedBox(width: 8),
                CustomTextfield.textWithStylesSmall(
                  'Wallet Balance',
                  fontSize: 15,
                  colors: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
                const Spacer(),
                IconButton(
                  onPressed: () {
                    setState(() => _isAmountVisible = !_isAmountVisible);
                  },
                  icon: Icon(
                    _isAmountVisible ? Icons.visibility : Icons.visibility_off,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            _isAmountVisible
                ? Obx(
                  () => CustomTextfield.textWithImage(
                    text: walletController.balance.value.toString(),
                    imagePath: AppImages.bCurrency,
                    fontWeight: FontWeight.w700,
                    fontSize: 22,
                    colors: Colors.white,
                    imageColors: Colors.white,
                    imageSize: 22,
                  ),
                )
                : CustomTextfield.textWithImage(
                  text: "****",
                  imagePath: AppImages.bCurrency,
                  fontWeight: FontWeight.w700,
                  fontSize: 22,
                  colors: Colors.white,
                  imageColors: Colors.white,
                  imageSize: 20,
                ),

            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Get.to(
                        () => AddMoneyScreen(
                          customerWalletBalance: walletController.balance.value,
                          minimumWalletAddBalance: 800,
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.10),
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
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _openWithdrawSheet,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.10),
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

  List<Transaction> _filterTransactions() {
    if (selectedTab == 1) {
      return walletController.traction
          .where((e) => e.color?.toLowerCase() == "green")
          .toList();
    } else if (selectedTab == 2) {
      return walletController.traction
          .where((e) => e.color?.toLowerCase() == "red")
          .toList();
    }
    return walletController.traction;
  }

  String _getImageByType(String type) {
    switch (type) {
      case "Refund":
        return AppImages.refund;
      case "Bike":
        return AppImages.tripPayment;
      default:
        return AppImages.wallet_top;
    }
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.commonWhite,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.circularClr,
            child: Image.asset(image, height: 30),
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
                  color: amountColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const Text(
                "wallet",
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// import 'package:flutter/material.dart';
// import 'package:hopper/Core/Constants/Colors.dart';
// import 'package:hopper/Core/Utility/images.dart';
// import 'package:hopper/Presentation/Authentication/widgets/textFields.dart';
// import 'package:get/get.dart';
// import 'package:hopper/Presentation/Drawer/screens/drawer_screens.dart';
//
// import '../../../Core/Utility/app_loader.dart';
// import '../controller/ride_history_controller.dart';
// import '../model/wallet_history_response.dart';
// import 'add_money_screens.dart';
//
// class WalletScreen extends StatefulWidget {
//   const WalletScreen({super.key});
//
//   @override
//   State<WalletScreen> createState() => _WalletScreenState();
// }
//
// class _WalletScreenState extends State<WalletScreen> {
//   final RideHistoryController walletController = Get.put(
//     RideHistoryController(),
//   );
//
//   int selectedTab = 0;
//   bool _isAmountVisible = false;
//   final ScrollController scrollController = ScrollController();
//
//   @override
//   void initState() {
//     super.initState();
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       walletController.customerWalletHistory();
//       scrollController.addListener(() {
//         if (scrollController.position.pixels >=
//             scrollController.position.maxScrollExtent - 200) {
//           if (!walletController.isMoreLoading.value &&
//               walletController.hasMore.value) {
//             walletController.customerWalletHistory();
//           }
//         }
//       });
//     });
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: AppColors.containerColor1,
//       body: SafeArea(
//         child: Padding(
//           padding: const EdgeInsets.all(16.0),
//           child: RefreshIndicator(
//             onRefresh: () async {
//               return await walletController.customerWalletHistory();
//             },
//             child: SingleChildScrollView(
//               physics: BouncingScrollPhysics(),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   _buildHeader(),
//                   const SizedBox(height: 30),
//                   Container(
//                     padding: const EdgeInsets.all(16),
//                     decoration: BoxDecoration(
//                       gradient: const LinearGradient(
//                         colors: [Color(0xFF7B61FF), Color(0xFF5B8EFF)],
//                         begin: Alignment.topLeft,
//                         end: Alignment.bottomRight,
//                       ),
//                       borderRadius: BorderRadius.circular(16),
//                     ),
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Row(
//                           children: [
//                             Image.asset(
//                               AppImages.wallet,
//                               height: 24,
//                               color: AppColors.commonWhite,
//                             ),
//                             SizedBox(width: 8),
//                             CustomTextfield.textWithStylesSmall(
//                               'Wallet Balance',
//                               fontSize: 15,
//                               colors: AppColors.commonWhite,
//                               fontWeight: FontWeight.w500,
//                             ),
//                             Spacer(),
//                             IconButton(
//                               onPressed: () {
//                                 setState(() {
//                                   _isAmountVisible = !_isAmountVisible;
//                                 });
//                               },
//                               icon: Icon(
//                                 _isAmountVisible
//                                     ? Icons.visibility
//                                     : Icons.visibility_off,
//                                 color: Colors.white,
//                               ),
//                             ),
//                           ],
//                         ),
//                         const SizedBox(height: 10),
//                         Visibility(
//                           visible: _isAmountVisible,
//                           replacement: CustomTextfield.textWithImage(
//                             text: '****',
//                             imagePath: AppImages.bCurrency,
//                             fontWeight: FontWeight.w700,
//                             fontSize: 25,
//                             colors: AppColors.commonWhite,
//                             imageColors: AppColors.commonWhite,
//                             imageSize: 20,
//                           ),
//                           child: Obx(
//                             () => CustomTextfield.textWithImage(
//                               text: walletController.balance.value.toString(),
//                               imagePath: AppImages.bCurrency,
//                               fontWeight: FontWeight.w700,
//                               fontSize: 20,
//                               colors: AppColors.commonWhite,
//                               imageColors: AppColors.commonWhite,
//                               imageSize: 20,
//                             ),
//                           ),
//                         ),
//
//                         const SizedBox(height: 10),
//
//                         Row(
//                           children: [
//                             Expanded(
//                               child: ElevatedButton(
//                                 onPressed: () {
//                                   final current =
//                                       walletController.balance.value;
//                                   Get.to(
//                                     () => AddMoneyScreen(
//                                       customerWalletBalance: current,
//                                       minimumWalletAddBalance: 800,
//                                     ),
//                                   );
//                                 },
//                                 style: ElevatedButton.styleFrom(
//                                   elevation: 0,
//                                   backgroundColor: AppColors.commonWhite
//                                       .withOpacity(0.10),
//                                   foregroundColor: Colors.white,
//                                   shape: RoundedRectangleBorder(
//                                     borderRadius: BorderRadius.circular(8),
//                                   ),
//                                 ),
//                                 child: CustomTextfield.textWithStyles600(
//                                   "Add Money",
//                                   fontSize: 16,
//                                 ),
//                               ),
//                             ),
//                             const SizedBox(width: 15),
//                             Expanded(
//                               child: ElevatedButton(
//                                 onPressed: () {},
//                                 style: ElevatedButton.styleFrom(
//                                   elevation: 0,
//                                   backgroundColor: AppColors.commonWhite
//                                       .withOpacity(0.10),
//                                   foregroundColor: Colors.white,
//                                   shape: RoundedRectangleBorder(
//                                     borderRadius: BorderRadius.circular(8),
//                                   ),
//                                 ),
//                                 child: CustomTextfield.textWithStyles600(
//                                   "Withdraw",
//                                   fontSize: 16,
//                                 ),
//                               ),
//                             ),
//                           ],
//                         ),
//                       ],
//                     ),
//                   ),
//                   const SizedBox(height: 20),
//                   const Text(
//                     "Recent Transactions",
//                     style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
//                   ),
//                   const SizedBox(height: 12),
//                   _buildTabs(),
//                   const SizedBox(height: 16),
//                   Obx(() {
//                     if (walletController.isLoading.value) {
//                       return Center(child: AppLoader.circularLoader());
//                     }
//
//                     List<Transaction> filteredTransactions = [];
//
//                     if (selectedTab == 0) {
//                       filteredTransactions = walletController.traction;
//                     } else if (selectedTab == 1) {
//                       filteredTransactions =
//                           walletController.traction
//                               .where((tx) => tx.color?.toLowerCase() == "green")
//                               .toList();
//                     } else if (selectedTab == 2) {
//                       filteredTransactions =
//                           walletController.traction
//                               .where((tx) => tx.color?.toLowerCase() == "red")
//                               .toList();
//                     }
//
//                     if (filteredTransactions.isEmpty) {
//                       return Center(child: Text("No transactions found."));
//                     }
//
//                     return ListView.builder(
//                       shrinkWrap: true,
//                       physics: NeverScrollableScrollPhysics(),
//                       itemCount: filteredTransactions.length,
//                       itemBuilder: (context, index) {
//                         final tx = filteredTransactions[index];
//
//                         return buildTransaction(
//                           subtitle2: tx.createdAt.toString(),
//                           image: _getImageByType(tx.imageType ?? ''),
//                           title: tx.displayText ?? '',
//                           subtitle: tx.walletDescription ?? '',
//                           amount: "₦ ${tx.amount}",
//                           amountColor:
//                               (tx.color?.toLowerCase() == "green")
//                                   ? Colors.green
//                                   : Colors.red,
//                         );
//                       },
//                     );
//                   }),
//
//                   // Obx(() {
//                   //   if (walletController.isLoading.value) {
//                   //     return Center(child: AppLoader.circularLoader());
//                   //   }
//                   //
//                   //   List<Transaction> filteredTransactions = [];
//                   //
//                   //   if (selectedTab == 0) {
//                   //     // All
//                   //     filteredTransactions = walletController.traction;
//                   //   } else if (selectedTab == 1) {
//                   //     // Money In → green color transactions
//                   //     filteredTransactions =
//                   //         walletController.traction
//                   //             .where((tx) => tx.color?.toLowerCase() == "green")
//                   //             .toList();
//                   //   } else if (selectedTab == 2) {
//                   //     // Money Out → red color transactions
//                   //     filteredTransactions =
//                   //         walletController.traction
//                   //             .where((tx) => tx.color?.toLowerCase() == "red")
//                   //             .toList();
//                   //   }
//                   //
//                   //   if (filteredTransactions.isEmpty) {
//                   //     return Center(child: Text("No transactions found."));
//                   //   }
//                   //
//                   //   return ListView.builder(
//                   //     shrinkWrap: true,
//                   //     physics: NeverScrollableScrollPhysics(),
//                   //     itemCount: filteredTransactions.length,
//                   //     itemBuilder: (context, index) {
//                   //       final tx = filteredTransactions[index];
//                   //
//                   //       return buildTransaction(
//                   //         subtitle2: tx.createdAt.toString() ?? '',
//                   //         image: _getImageByType(tx.imageType.toString() ?? ''),
//                   //         title: tx.displayText.toString() ?? '',
//                   //         subtitle: tx.walletDescription.toString() ?? '',
//                   //         amount: "₦ ${tx.amount}", // no + or -
//                   //         amountColor:
//                   //             tx.color?.toLowerCase() == "green"
//                   //                 ? Colors.green
//                   //                 : Colors.red, // use color field
//                   //       );
//                   //     },
//                   //   );
//                   // }),
//                 ],
//               ),
//             ),
//           ),
//         ),
//       ),
//     );
//   }
//
//   Widget _buildHeader() {
//     return Row(
//       children: [
//         GestureDetector(
//           onTap:
//               () => Navigator.pushAndRemoveUntil(
//                 context,
//                 MaterialPageRoute(builder: (context) => DrawerScreen()),
//                 (route) => false,
//               ),
//           child: Image.asset(AppImages.backButton, height: 19, width: 19),
//         ),
//         const Spacer(),
//         CustomTextfield.textWithStyles700('Wallet', fontSize: 20),
//         const Spacer(),
//       ],
//     );
//   }
//
//   Widget _buildTabs() {
//     return Row(
//       children: [
//         buildTab("All", 0),
//         const SizedBox(width: 8),
//         buildTab("Money In", 1),
//         const SizedBox(width: 8),
//         buildTab("Money Out", 2),
//       ],
//     );
//   }
//
//   String _getImageByType(String imageType) {
//     switch (imageType) {
//       case "Refund":
//         return AppImages.refund;
//       case "Bike":
//         return AppImages.tripPayment;
//
//       default:
//         return AppImages.wallet_top;
//     }
//   }
//
//   Widget buildTab(String text, int index) {
//     bool isSelected = selectedTab == index;
//     return Expanded(
//       child: GestureDetector(
//         onTap: () => setState(() => selectedTab = index),
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
//               color: isSelected ? Colors.black : Colors.black54,
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
//               const Text(
//                 'wallet',
//                 style: TextStyle(color: Colors.grey, fontSize: 12),
//               ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }
// }
