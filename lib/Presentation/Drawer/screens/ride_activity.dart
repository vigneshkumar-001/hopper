import 'package:flutter/material.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:dotted_line/dotted_line.dart';
import 'package:hopper/Core/Utility/app_loader.dart';
import 'package:hopper/Core/Utility/date_time_converter.dart';
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
  // bool isExpanded = false; // Track dropdown state
  List<bool> expandedList = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (controller.rideHistoryData.isEmpty) {
        controller.rideHistory();
      }
    });
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
                if (controller.isLoading.value) {
                  return Center(child: AppLoader.circularLoader());
                } else if (data.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: () async {
                      return await controller.rideHistory();
                    },
                    child: ListView(
                      physics: AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.7,
                          child: Center(
                            child: CustomTextfield.textWithStyles600(
                              'No History Found',
                              color: AppColors.commonBlack,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }
                if (expandedList.length != data.length) {
                  expandedList = List.generate(data.length, (index) => false);
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    return await controller.rideHistory();
                  },
                  child: ListView.builder(
                    physics: AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
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
                                Expanded(
                                  child: CustomTextfield.textWithStyles700(
                                    fontSize: 14,
                                    historyData.rideType == 'Bike'
                                        ? '#PD${historyData.bookingId}'
                                        : '#RD${historyData.bookingId}',
                                  ),
                                ),

                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Color(
                                      int.parse(
                                        "0xFF${historyData.ridehistoryColor}",
                                      ),
                                    ).withOpacity(0.10),
                                    // color:  historyData.ridehistoryColor == "red"
                                    //     ? Colors.red.withOpacity(0.10)
                                    //     :  Colors.green.withOpacity(0.10),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    historyData.status,
                                    style: TextStyle(
                                      color: Color(
                                        int.parse(
                                          "0xFF${historyData.ridehistoryColor}",
                                        ),
                                      ),
                                      // color:
                                      //     historyData.ridehistoryColor == "red
                                      //         ? Colors.red
                                      //         : Colors.green,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                                SizedBox(width: 10),
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
                                          historyData.amount.toString() ?? '',
                                          color: AppColors.changeButtonColor,
                                        ),
                                      ],
                                    ),
                                    CustomTextfield.textWithStylesSmall(
                                      DateAndTimeConvert.longMonthDate(
                                        historyData.createdAt,
                                      ),
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
                                      historyData.customer.name,
                                      fontSize: 14,
                                    ),
                                    Row(
                                      children: [
                                        ...List.generate(5, (index) {
                                          double rating =
                                              historyData.customer.rating ?? 0;
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
                                          (historyData.customer.rating ?? 0)
                                              .toString(),
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
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                  Spacer(),
                                                  CustomTextfield.textWithStylesSmall(
                                                    historyData.pickup.time,
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                historyData.pickup.address,
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
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                  Spacer(),
                                                  CustomTextfield.textWithStylesSmall(
                                                    historyData.dropoff.time
                                                            .toString() ??
                                                        '',
                                                  ),
                                                ],
                                              ),

                                              const SizedBox(height: 4),
                                              Text(
                                                historyData.dropoff.address,
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
                                  top: 20,
                                  left: 5,
                                  child: DottedLine(
                                    direction: Axis.vertical,
                                    lineLength: 50,
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
                                    historyData.rideDurationFormatted
                                            .toString() ??
                                        '0',
                                  ),
                                ),

                                Expanded(
                                  flex: 2,
                                  child: CustomTextfield.textWithStylesSmall(
                                    historyData.distance,
                                  ),
                                ),

                                Expanded(
                                  flex: 0,
                                  child: CustomTextfield.textWithStylesSmall(
                                    '${historyData.customer.rating ?? '0'}/5',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            InkWell(
                              onTap: () {
                                setState(() {
                                  expandedList[index] = !expandedList[index];
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
                                    turns: expandedList[index] ? 0.5 : 0,
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
                                  expandedList[index]
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
                                                    historyData
                                                        .paymentDetails
                                                        .method,
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
                                                    historyData
                                                        .paymentDetails
                                                        .status,
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
                                              borderRadius:
                                                  BorderRadius.circular(8),
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
                                                      text:
                                                          historyData
                                                              .fareBreakdown
                                                              .baseFare
                                                              .toString() ??
                                                          '',
                                                      fontWeight:
                                                          FontWeight.w500,
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
                                                      text:
                                                          historyData
                                                              .fareBreakdown
                                                              .distanceFare
                                                              .toString() ??
                                                          '',
                                                      fontWeight:
                                                          FontWeight.w500,
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

                                                Row(
                                                  children: [
                                                    CustomTextfield.textWithStylesSmall(
                                                      'Time',
                                                    ),
                                                    const Spacer(),
                                                    CustomTextfield.textWithImage(
                                                      text:
                                                          historyData
                                                              .fareBreakdown
                                                              .timeFare
                                                              .toString() ??
                                                          '',
                                                      fontWeight:
                                                          FontWeight.w500,
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
                                                      'SurgeFare',
                                                    ),
                                                    const Spacer(),
                                                    CustomTextfield.textWithImage(
                                                      text:
                                                          historyData
                                                              .fareBreakdown
                                                              .surgeFare
                                                              .toString() ??
                                                          '',
                                                      fontWeight:
                                                          FontWeight.w500,
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

                                                const SizedBox(height: 5),

                                                /// Total
                                                Row(
                                                  children: [
                                                    CustomTextfield.textWithStyles600(
                                                      color: AppColors.red,
                                                      'Commission',
                                                    ),
                                                    const Spacer(),
                                                    CustomTextfield.textWithImage(
                                                      text:
                                                          '-${historyData.fareBreakdown.commission.toString() ?? '0'}',
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      fontSize: 15,
                                                      sizedBox: false,
                                                      imageSize: 15,
                                                      imageColors:
                                                          AppColors.red,
                                                      colors: AppColors.red,
                                                      imagePath:
                                                          AppImages.bCurrency,
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 10),
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
                                                const SizedBox(height: 5),

                                                Row(
                                                  children: [
                                                    CustomTextfield.textWithStyles600(
                                                      'Total',
                                                    ),
                                                    const Spacer(),
                                                    CustomTextfield.textWithImage(
                                                      text:
                                                          historyData
                                                              .fareBreakdown
                                                              .total
                                                              .toString() ??
                                                          '',
                                                      fontWeight:
                                                          FontWeight.w800,
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
                          ],
                        ),
                      );
                    },
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}
