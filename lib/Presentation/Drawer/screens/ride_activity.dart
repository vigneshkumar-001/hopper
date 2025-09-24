import 'package:flutter/material.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:dotted_line/dotted_line.dart';
import 'package:hopper/Core/Utility/app_loader.dart';
import 'package:hopper/Presentation/Authentication/widgets/textfields.dart';

import 'package:get/get.dart';
import 'package:hopper/Presentation/Drawer/controller/ride_history_controller.dart';

import '../../../Core/Constants/Colors.dart';
import '../../../Core/Utility/images.dart';

class RideAndPackageHistoryScreen extends StatefulWidget {
  const RideAndPackageHistoryScreen({Key? key}) : super(key: key);

  @override
  State<RideAndPackageHistoryScreen> createState() =>
      _RideAndPackageHistoryScreenState();
}

class _RideAndPackageHistoryScreenState
    extends State<RideAndPackageHistoryScreen> {
  final RideHistoryController controller = Get.put(RideHistoryController());
  bool isExpanded = false; // Track dropdown state
  @override
  void initState() {
    super.initState();
    controller.rideHistory();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 20),
              child: Row(
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
            ),
            Expanded(
              child: Obx(() {
                final data = controller.rideHistoryData;
                if (data.isEmpty) {
                  return Center(
                    child: CustomTextfield.textWithStyles600(
                      'No History Found',
                      color: AppColors.commonBlack,
                    ),
                  );
                }
                return ListView.builder(
                  physics: BouncingScrollPhysics(),

                  itemCount: data.length,
                  itemBuilder: (context, index) {
                    final historyData = data[index];
                    return Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 15,
                        vertical: 8,
                      ),
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(
                          color: AppColors.rideShareContainerColor,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 5,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CustomTextfield.textWithStyles700(
                                '#R${historyData.bookingId}',
                                fontSize: 14,
                              ),
                              SizedBox(width: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.10),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  "Completed",
                                  style: TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              Spacer(),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Row(
                                    children: [
                                      Image.asset(
                                        AppImages.bCurrency,
                                        height: 15,
                                        color: AppColors.changeButtonColor,
                                      ),
                                      CustomTextfield.textWithStyles600(
                                        '1000',
                                        color: AppColors.changeButtonColor,
                                      ),
                                    ],
                                  ),
                                  CustomTextfield.textWithStylesSmall(
                                    'May 15, 2025',
                                    fontSize: 10,
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),

                          Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(40),
                                child: Image.network(
                                  '',
                                  height: 35,
                                  width: 35,
                                  errorBuilder:
                                      (context, error, stackTrace) =>
                                          const Icon(Icons.person, size: 35),
                                ),
                              ),
                              const SizedBox(width: 5),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CustomTextfield.textWithStyles600(
                                    "Sarah Johnson",
                                    fontSize: 14,
                                  ),
                                  Row(
                                    children: [
                                      ...List.generate(5, (index) {
                                        double rating =
                                            4.5; // Replace with your dynamic data
                                        if (index < rating.floor()) {
                                          return Icon(
                                            Icons.star,
                                            color: AppColors.starColor,
                                            size: 16,
                                          );
                                        } else if (index < rating) {
                                          return Icon(
                                            Icons.star_half,
                                            color: AppColors.starColor,
                                            size: 16,
                                          );
                                        } else {
                                          return Icon(
                                            Icons.star_border,
                                            color: AppColors.starColor,
                                            size: 16,
                                          );
                                        }
                                      }),
                                      SizedBox(width: 5),
                                      Text(
                                        "4.5", // Or your dynamic rating text
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          Stack(
                            children: [
                              Column(
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Padding(
                                        padding: EdgeInsets.only(top: 2),
                                        child: Icon(
                                          Icons.circle,
                                          color: Colors.green,
                                          size: 12,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Text(
                                                  'Pickup Address',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                                Spacer(),
                                                CustomTextfield.textWithStylesSmall(
                                                  '7:02 PM',
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              "125860",
                                              style: const TextStyle(
                                                color: Colors.black54,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Padding(
                                        padding: EdgeInsets.only(top: 5),
                                        child: Icon(
                                          Icons.circle,
                                          color: Colors.orange,
                                          size: 12,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Text(
                                                  'Delivery Address',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                                Spacer(),
                                                CustomTextfield.textWithStylesSmall(
                                                  '7:22 PM',
                                                ),
                                              ],
                                            ),

                                            const SizedBox(height: 4),
                                            Text(
                                              "123456",
                                              style: const TextStyle(
                                                color: Colors.black54,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              Positioned(
                                top: 15,
                                left: 5,
                                child: DottedLine(
                                  direction: Axis.vertical,
                                  lineLength: 40,
                                  dashLength: 3,
                                  dashColor: AppColors.dotLineColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,

                            children: [
                              Expanded(
                                flex: 5,
                                child: CustomTextfield.textWithStylesSmall(
                                  '10:30 Am - 11:05 AM * 35 min',
                                ),
                              ),

                              Expanded(
                                flex: 2,
                                child: CustomTextfield.textWithStylesSmall(
                                  '4.2 miles',
                                ),
                              ),
                              Expanded(
                                flex: 0,
                                child: CustomTextfield.textWithStylesSmall(
                                  '5/5',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          InkWell(
                            onTap: () {
                              setState(() {
                                isExpanded = !isExpanded;
                              });
                            },
                            child: Row(
                              children: [
                                CustomTextfield.textWithStylesSmall(
                                  'View Details',
                                  colors: AppColors.changeButtonColor,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                                const SizedBox(width: 10),
                                AnimatedRotation(
                                  turns:
                                      isExpanded
                                          ? 0.5
                                          : 0, // rotate 180° when expanded
                                  duration: const Duration(milliseconds: 300),
                                  child: Image.asset(
                                    AppImages.dropDown,
                                    height: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            switchInCurve: Curves.easeInOut,
                            switchOutCurve: Curves.easeInOut,
                            transitionBuilder: (child, animation) {
                              return SizeTransition(
                                sizeFactor: animation,
                                axisAlignment: -1, // expand downwards
                                child: FadeTransition(
                                  opacity: animation,
                                  child: child,
                                ),
                              );
                            },
                            child:
                                isExpanded
                                    ? Column(
                                      key: const ValueKey("expanded"),
                                      children: [
                                        const SizedBox(height: 10),

                                        Row(
                                          children: [
                                            Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                CustomTextfield.textWithStylesSmall(
                                                  'Payment Method',
                                                  fontSize: 12,
                                                ),
                                                CustomTextfield.textWithStyles600(
                                                  'Credit Card',
                                                  fontSize: 12,
                                                ),
                                              ],
                                            ),
                                            const Spacer(),
                                            Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.end,
                                              children: [
                                                CustomTextfield.textWithStylesSmall(
                                                  'Payment Status',
                                                  fontSize: 12,
                                                ),
                                                CustomTextfield.textWithStyles600(
                                                  'Paid',
                                                  fontSize: 12,
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 10),

                                        /// Fare breakdown
                                        Container(
                                          margin: const EdgeInsets.only(
                                            top: 10,
                                          ),
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            border: Border.all(
                                              color: AppColors.commonBlack
                                                  .withOpacity(0.1),
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              const Text(
                                                "Fare Breakdown",
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              const SizedBox(height: 5),

                                              /// Base fare
                                              Row(
                                                children: [
                                                  CustomTextfield.textWithStylesSmall(
                                                    'Base Fare',
                                                  ),
                                                  const Spacer(),
                                                  CustomTextfield.textWithImage(
                                                    text: '8.50',
                                                    fontWeight: FontWeight.w500,
                                                    fontSize: 12,
                                                    sizedBox: false,
                                                    imageSize: 12,
                                                    colors:
                                                        AppColors.commonBlack,
                                                    imagePath:
                                                        AppImages.bCurrency,
                                                  ),
                                                ],
                                              ),

                                              /// Distance
                                              Row(
                                                children: [
                                                  CustomTextfield.textWithStylesSmall(
                                                    'Distance',
                                                  ),
                                                  const Spacer(),
                                                  CustomTextfield.textWithImage(
                                                    text: '8.50',
                                                    fontWeight: FontWeight.w500,
                                                    fontSize: 12,
                                                    sizedBox: false,
                                                    imageSize: 12,
                                                    colors:
                                                        AppColors.commonBlack,
                                                    imagePath:
                                                        AppImages.bCurrency,
                                                  ),
                                                ],
                                              ),

                                              /// Tips
                                              Row(
                                                children: [
                                                  CustomTextfield.textWithStylesSmall(
                                                    'Tips',
                                                  ),
                                                  const Spacer(),
                                                  CustomTextfield.textWithImage(
                                                    text: '8.50',
                                                    fontWeight: FontWeight.w500,
                                                    fontSize: 12,
                                                    sizedBox: false,
                                                    imageSize: 12,
                                                    colors:
                                                        AppColors.commonBlack,
                                                    imagePath:
                                                        AppImages.bCurrency,
                                                  ),
                                                ],
                                              ),

                                              const SizedBox(height: 10),

                                              /// Divider
                                              SizedBox(
                                                height: 2,
                                                child: DottedLine(
                                                  direction: Axis.horizontal,
                                                  lineLength: double.infinity,
                                                  lineThickness: 1.6,
                                                  dashLength: 6.0,
                                                  dashColor: Colors.black
                                                      .withOpacity(0.1),
                                                ),
                                              ),
                                              const SizedBox(height: 10),

                                              /// Total
                                              Row(
                                                children: [
                                                  CustomTextfield.textWithStyles600(
                                                    'Total',
                                                  ),
                                                  const Spacer(),
                                                  CustomTextfield.textWithImage(
                                                    text: '30.50',
                                                    fontWeight: FontWeight.w800,
                                                    fontSize: 15,
                                                    sizedBox: false,
                                                    imageSize: 15,
                                                    colors:
                                                        AppColors.commonBlack,
                                                    imagePath:
                                                        AppImages.bCurrency,
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    )
                                    : const SizedBox.shrink(
                                      key: ValueKey("collapsed"),
                                    ),
                          ),

                          /*          InkWell(
                      onTap: () {
                        setState(() {
                          isExpanded = !isExpanded;
                        });
                      },
                      child: Row(
                        children: [
                          CustomTextfield.textWithStylesSmall(
                            'View Details',
                            colors: AppColors.changeButtonColor,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                          SizedBox(width: 10),
                          AnimatedRotation(
                            turns:
                                isExpanded
                                    ? 0.5
                                    : 0, // 180° rotation when expanded
                            duration: const Duration(milliseconds: 300),
                            child: Image.asset(AppImages.dropDown, height: 16),
                          ),
                        ],
                      ),
                    ),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      child:
                          isExpanded
                              ? Column(
                                children: [
                                  SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          CustomTextfield.textWithStylesSmall(
                                            'Payment Method',
                                            fontSize: 12,
                                          ),
                                          CustomTextfield.textWithStyles600(
                                            'Credit Card',
                                            fontSize: 12,
                                          ),
                                        ],
                                      ),
                                      Spacer(),

                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          CustomTextfield.textWithStylesSmall(
                                            'Payment Status',
                                            fontSize: 12,
                                          ),
                                          CustomTextfield.textWithStyles600(
                                            'Paid',
                                            fontSize: 12,
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 10),
                                  Container(
                                    margin: const EdgeInsets.only(top: 10),
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: AppColors.commonBlack.withOpacity(
                                          0.1,
                                        ),
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "Fare Breakdown",
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        SizedBox(height: 5),
                                        Row(
                                          children: [
                                            CustomTextfield.textWithStylesSmall(
                                              'Base Fare',
                                            ),
                                            Spacer(),
                                            CustomTextfield.textWithImage(
                                              fontWeight: FontWeight.w500,
                                              text: '8.50',
                                              fontSize: 12,
                                              sizedBox: false,
                                              imageSize: 12,
                                              colors: AppColors.commonBlack,
                                              imagePath: AppImages.bCurrency,
                                            ),
                                          ],
                                        ),
                                        Row(
                                          children: [
                                            CustomTextfield.textWithStylesSmall(
                                              'Distance',
                                            ),
                                            Spacer(),
                                            CustomTextfield.textWithImage(
                                              fontWeight: FontWeight.w500,
                                              text: '8.50',
                                              fontSize: 12,
                                              sizedBox: false,
                                              imageSize: 12,
                                              colors: AppColors.commonBlack,
                                              imagePath: AppImages.bCurrency,
                                            ),
                                          ],
                                        ),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            CustomTextfield.textWithStylesSmall(
                                              'Tips',
                                            ),
                                            Spacer(),
                                            CustomTextfield.textWithImage(
                                              fontWeight: FontWeight.w500,
                                              text: '8.50',
                                              fontSize: 12,
                                              sizedBox: false,
                                              imageSize: 12,
                                              colors: AppColors.commonBlack,
                                              imagePath: AppImages.bCurrency,
                                            ),
                                          ],
                                        ),
                                        SizedBox(height: 10),
                                        SizedBox(
                                          height: 2,
                                          child: DottedLine(
                                            direction: Axis.horizontal,
                                            lineLength: double.infinity,
                                            lineThickness: 1.6,
                                            dashLength: 6.0,
                                            dashColor: Colors.black.withOpacity(
                                              0.1,
                                            ),
                                          ),
                                        ),
                                        SizedBox(height: 10),
                                        Row(

                                          children: [
                                            CustomTextfield. textWithStyles600(
                                              'Total',
                                            ) ,
                                            Spacer(),
                                            CustomTextfield.textWithImage(
                                              fontWeight: FontWeight.w800,
                                              text: '30.50',
                                              fontSize: 15,
                                              sizedBox: false,
                                              imageSize: 15,
                                              colors: AppColors.commonBlack,
                                              imagePath: AppImages.bCurrency,
                                            ),

                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              )
                              : SizedBox.shrink(),
                    ),
                    */
                        ],
                      ),
                    );
                  },
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}
