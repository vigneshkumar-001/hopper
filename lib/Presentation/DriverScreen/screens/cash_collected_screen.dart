import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hopper/Core/Constants/Colors.dart';
import 'package:hopper/Core/Constants/log.dart';
import 'package:hopper/Core/Utility/Buttons.dart';
import 'package:hopper/Core/Utility/images.dart';
import 'package:hopper/Presentation/Authentication/widgets/textFields.dart';
import 'package:hopper/Presentation/DriverScreen/controller/driver_status_controller.dart';
import 'package:hopper/Presentation/DriverScreen/screens/driver_main_screen.dart';
import '../../../utils/netWorkHandling/network_handling_screen.dart';
import '../../../utils/sharedprefsHelper/booking_local_data.dart';
import '../../OnBoarding/controller/chooseservice_controller.dart';

class CashCollectedScreen extends StatefulWidget {
  final dynamic Amount;
  final String? bookingId;
  const CashCollectedScreen({super.key, this.Amount, this.bookingId});

  @override
  State<CashCollectedScreen> createState() => _CashCollectedScreenState();
}

class _CashCollectedScreenState extends State<CashCollectedScreen> {
  final ChooseServiceController getDetails = Get.put(ChooseServiceController());
  final DriverStatusController driverStatusController = Get.put(
    DriverStatusController(),
  );
  Timer? _timer;

  @override
  void initState() {
    super.initState();

    // ✅ Poll API every 2 seconds
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      final bookingId = widget.bookingId?.toString() ?? '';
      if (bookingId.isNotEmpty) {
        driverStatusController.getAmountStatus(bookingId: bookingId); // ✅ named argument
      }
    });
  }



  @override
  void dispose() {
    _timer?.cancel(); // ✅ stop polling
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bookingData = BookingDataService().getBookingData();

    return NoInternetOverlay(
      child: WillPopScope(
        onWillPop: () async {
          return await false;
        },
        child: Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 20.0,
                vertical: 20,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Image.asset(
                      AppImages.backButton,
                      height: 25,
                      width: 25,
                    ),
                  ),
                  const Spacer(),

                  // ✅ User Profile
                  Obx(() {
                    final profilePic =
                        getDetails.userProfile.value?.profilePic ?? '';
                    final firstName =
                        getDetails.userProfile.value?.firstName ?? 'Customer';

                    return Column(
                      children: [
                        Center(
                          child:
                              profilePic.isNotEmpty
                                  ? CachedNetworkImage(
                                    imageUrl: profilePic,
                                    height: 80,
                                    width: 80,
                                    imageBuilder:
                                        (context, imageProvider) => Container(
                                          height: 80,
                                          width: 80,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            image: DecorationImage(
                                              image: imageProvider,
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                        ),
                                    placeholder:
                                        (context, url) =>
                                            const CircularProgressIndicator(),
                                    errorWidget:
                                        (context, url, error) => const Icon(
                                          Icons.person,
                                          size: 80,
                                          color: Colors.grey,
                                        ),
                                  )
                                  : const Icon(
                                    Icons.person,
                                    size: 80,
                                    color: Colors.grey,
                                  ),
                        ),
                        const SizedBox(height: 10),
                        CustomTextfield.textWithStylesSmall(
                          'Collect cash from $firstName',
                          colors: AppColors.grey,
                          fontSize: 14,
                        ),
                        const SizedBox(height: 10),
                        CustomTextfield.textWithStyles600(
                          widget.Amount.toString(),
                        ),
                        const SizedBox(height: 15),

                        Obx(
                          () => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.commonWhite,
                              border: Border.all(
                                color: AppColors.containerColor1,
                                width: 1,
                              ),
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withOpacity(0.1),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Payment Type
                                RichText(
                                  text: TextSpan(
                                    text: "Payment Type: ",
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.black87,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    children: [
                                      TextSpan(
                                        text:
                                            driverStatusController
                                                .paymentType
                                                .value,
                                        style: const TextStyle(
                                          color:
                                              Colors
                                                  .blue, // ✅ Different color for value
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 6),

                                // Payment Status
                                RichText(
                                  text: TextSpan(
                                    text: "Payment Status: ",
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.black87,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    children: [
                                      TextSpan(
                                        text:
                                            driverStatusController
                                                .paymentStatus
                                                .value,
                                        style: TextStyle(
                                          color:
                                              driverStatusController
                                                          .paymentStatus
                                                          .value
                                                          .toUpperCase() ==
                                                      "PAID"
                                                  ? Colors.green
                                                  : Colors.redAccent,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  }),

                  const Spacer(),

                  // ✅ Info Box
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.directionColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Image.asset(
                          color: AppColors.directionColor,
                          AppImages.exclamationCircle,
                          width: 20,
                          height: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: CustomTextfield.textWithStylesSmall(
                            fontWeight: FontWeight.w400,
                            colors: AppColors.commonBlack,
                            'If rider doesn’t have change, ask them to pay in wholesums. Extra amount paid will be credited to rider’s account.',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),

                  // ✅ Manual trigger (optional)
                  SafeArea(
                    child: Obx(
                      () => Buttons.button(
                        borderRadius: 7,
                        buttonColor: AppColors.commonBlack,
                        onTap:
                            driverStatusController.isLoading.value
                                ? null
                                : () {
                                  driverStatusController.amountCollectedStatus(
                                    booking: widget.bookingId.toString(),
                                    onSuccess: () {
                                      // ✅ Pop up the rating sheet automatically
                                      _showRatingBottomSheet(context);
                                    },
                                  );
                                },
                        text:
                            driverStatusController.isLoading.value
                                ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                                : const Text('Cash Collected'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ✅ Bottom Sheet for Rating
  void _showRatingBottomSheet(BuildContext context) {
    int selectedRating = 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.white,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            final profilePic = getDetails.userProfile.value?.profilePic ?? '';
            final firstName =
                getDetails.userProfile.value?.firstName ?? 'Customer';

            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 50),
              child: Column(
                children: [
                  Center(
                    child:
                        profilePic.isNotEmpty
                            ? CachedNetworkImage(
                              imageUrl: profilePic,
                              height: 65,
                              width: 65,
                              imageBuilder:
                                  (context, imageProvider) => Container(
                                    height: 65,
                                    width: 65,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      image: DecorationImage(
                                        image: imageProvider,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                              placeholder:
                                  (context, url) =>
                                      const CircularProgressIndicator(),
                              errorWidget:
                                  (context, url, error) => const Icon(
                                    Icons.person,
                                    size: 65,
                                    color: Colors.grey,
                                  ),
                            )
                            : const Icon(
                              Icons.person,
                              size: 65,
                              color: Colors.grey,
                            ),
                  ),
                  const SizedBox(height: 20),
                  CustomTextfield.textWithStyles600(
                    textAlign: TextAlign.center,
                    fontSize: 20,
                    'Rate your Experience with $firstName?',
                  ),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: List.generate(5, (index) {
                        return GestureDetector(
                          onTap:
                              () => setState(() => selectedRating = index + 1),
                          child: Image.asset(
                            index < selectedRating
                                ? AppImages.starFill
                                : AppImages.star,
                            height: 48,
                            width: 48,
                            color:
                                index < selectedRating
                                    ? AppColors.commonBlack
                                    : AppColors.buttonBorder,
                          ),
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
                          child: Buttons.button(
                            borderRadius: 8,
                            textColor: AppColors.commonBlack,
                            borderColor: AppColors.buttonBorder,
                            buttonColor: AppColors.commonWhite,
                            onTap: () => Navigator.pop(context),
                            text: const Text('Close'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Obx(
                            () => Buttons.button(
                              borderRadius: 8,
                              buttonColor: AppColors.commonBlack,
                              onTap:
                                  driverStatusController.isLoading.value
                                      ? null
                                      : () {
                                    _timer?.cancel();
                                        driverStatusController
                                            .driverRatingToCustomer(
                                              context: context,
                                              rating: selectedRating,
                                              bookingId:
                                                  widget.bookingId.toString(),
                                            );
                                        CommonLogger.log.i(
                                          "Selected Rating: $selectedRating",
                                        );
                                      },
                              text:
                                  driverStatusController.isLoading.value
                                      ? SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          color: AppColors.commonBlack,
                                          strokeWidth: 2,
                                        ),
                                      )
                                      : const Text('Rate Ride'),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// import 'dart:async';
//
// import 'package:cached_network_image/cached_network_image.dart';
// import 'package:flutter/material.dart';
// import 'package:hopper/Core/Constants/Colors.dart';
// import 'package:hopper/Core/Constants/log.dart';
// import 'package:hopper/Core/Utility/Buttons.dart';
// import 'package:hopper/Core/Utility/images.dart';
// import 'package:hopper/Presentation/Authentication/widgets/textFields.dart';
// import 'package:hopper/Presentation/DriverScreen/controller/driver_status_controller.dart';
// import 'package:hopper/Presentation/DriverScreen/screens/driver_main_screen.dart';
//
// import '../../../utils/netWorkHandling/network_handling_screen.dart';
// import '../../../utils/sharedprefsHelper/booking_local_data.dart';
// import '../../OnBoarding/controller/chooseservice_controller.dart';
// import 'package:get/get.dart';
//
// class CashCollectedScreen extends StatefulWidget {
//   final dynamic Amount;
//   const CashCollectedScreen({super.key, this.Amount});
//
//   @override
//   State<CashCollectedScreen> createState() => _CashCollectedScreenState();
// }
//
// class _CashCollectedScreenState extends State<CashCollectedScreen> {
//   final ChooseServiceController getDetails = Get.put(ChooseServiceController());
//   final DriverStatusController driverStatusController = Get.put(
//     DriverStatusController(),
//   );
//   Timer? _timer;
//   @override
//   void initState() {
//     // TODO: implement initState
//     super.initState();
//     _timer = Timer.periodic(const Duration(seconds: 2), (timer) {
//       driverStatusController.getAmountStatus();
//     });
//   }
//   @override
//   void dispose() {
//     // ✅ Always cancel timer to avoid memory leaks
//     _timer?.cancel();
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final bookingData = BookingDataService().getBookingData();
//     print(bookingData?['estimatedPrice']);
//
//     return NoInternetOverlay(
//       child: Scaffold(
//         body: SafeArea(
//           child: Padding(
//             padding: EdgeInsets.symmetric(horizontal: 20.0, vertical: 20),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//
//               children: [
//                 GestureDetector(
//                   onTap: () {
//                     Navigator.pop(context);
//                   },
//                   child: Image.asset(
//                     AppImages.backButton,
//                     height: 25,
//                     width: 25,
//                   ),
//                 ),
//                 const Spacer(), // pushes content to center vertically
//                 Obx(() {
//                   final profilePic =
//                       getDetails.userProfile.value?.profilePic ?? '';
//                   final firstName =
//                       getDetails.userProfile.value?.firstName ?? 'Customer';
//
//                   return Column(
//                     children: [
//                       Center(
//                         child:
//                             profilePic.isNotEmpty
//                                 ? CachedNetworkImage(
//                                   imageUrl: profilePic,
//                                   height: 80,
//                                   width: 80,
//                                   imageBuilder:
//                                       (context, imageProvider) => Container(
//                                         height: 80,
//                                         width: 80,
//                                         decoration: BoxDecoration(
//                                           shape: BoxShape.circle,
//                                           image: DecorationImage(
//                                             image: imageProvider,
//                                             fit: BoxFit.cover,
//                                           ),
//                                         ),
//                                       ),
//                                   placeholder:
//                                       (context, url) =>
//                                           const CircularProgressIndicator(),
//                                   errorWidget:
//                                       (context, url, error) => const Icon(
//                                         Icons.person,
//                                         size: 80,
//                                         color: Colors.grey,
//                                       ),
//                                 )
//                                 : const Icon(
//                                   Icons.person,
//                                   size: 80,
//                                   color: Colors.grey,
//                                 ),
//                       ),
//                       const SizedBox(height: 10),
//                       CustomTextfield.textWithStylesSmall(
//                         'Collect cash from $firstName',
//                         colors: AppColors.grey,
//                         fontSize: 14,
//                       ),
//
//                       const SizedBox(height: 10),
//                       CustomTextfield.textWithStyles600(
//                         widget.Amount.toString() ?? '',
//                       ),
//                     ],
//                   );
//                 }),
//
//                 const Spacer(),
//                 Container(
//                   padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
//                   decoration: BoxDecoration(
//                     color: AppColors.directionColor.withOpacity(0.1),
//                   ),
//                   child: Row(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Image.asset(
//                         color: AppColors.directionColor,
//                         AppImages.exclamationCircle,
//                         width: 20,
//                         height: 20,
//                       ),
//                       SizedBox(width: 8),
//                       Expanded(
//                         child: Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             CustomTextfield.textWithStylesSmall(
//                               fontWeight: FontWeight.w400,
//                               colors: AppColors.commonBlack,
//                               'If rider don’t have change, ask them to pay in wholesums, extra amount paid will be credited to riders account',
//                             ),
//                           ],
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//                 SizedBox(height: 30),
//                 SafeArea(
//                   child: Buttons.button(
//                     borderRadius: 7,
//                     buttonColor: AppColors.commonBlack,
//                     onTap: () {
//                       _showRatingBottomSheet(context);
//                     },
//                     text: Text('Cash Collected'),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }
//
//   void _showRatingBottomSheet(BuildContext context) {
//     int selectedRating = 0;
//
//     showModalBottomSheet(
//       context: context,
//       isScrollControlled: true,
//       backgroundColor: Colors.white,
//       // shape: const RoundedRectangleBorder(
//       //   borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
//       // ),
//       builder: (context) {
//         return StatefulBuilder(
//           builder: (context, setState) {
//             return SingleChildScrollView(
//               child: Column(
//                 children: [
//                   const SizedBox(height: 20),
//                   Center(
//                     child: Container(
//                       width: 60,
//                       height: 5,
//
//                       decoration: BoxDecoration(
//                         color: Colors.grey[400],
//                         borderRadius: BorderRadius.circular(10),
//                       ),
//                     ),
//                   ),
//                   /*Padding(
//                     padding: const EdgeInsets.symmetric(vertical: 50),
//                     child: Column(
//                       children: [
//                         Image.asset(AppImages.dummyImg, height: 65, width: 65),
//                         CachedNetworkImage(
//                           imageUrl:
//                               getDetails.userProfile.value?.profilePic ?? '',
//                           height: 65,
//                           width: 65,
//                           placeholder:
//                               (context, url) =>
//                                   const CircularProgressIndicator(),
//                           errorWidget:
//                               (context, url, error) => const Icon(
//                                 Icons.person, // Default person icon
//                                 size: 65,
//                                 color: Colors.grey,
//                               ),
//                           fit: BoxFit.cover,
//                         ),
//
//                         const SizedBox(height: 20),
//                         CustomTextfield.textWithStyles600(
//                           textAlign: TextAlign.center,
//                           fontSize: 20,
//                           'Rate your Experience with ${getDetails.userProfile.value?.firstName ?? ''}?',
//                         ),
//                         const SizedBox(height: 25),
//                         Padding(
//                           padding: const EdgeInsets.symmetric(horizontal: 40),
//                           child: Row(
//                             mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//                             children: List.generate(5, (index) {
//                               return GestureDetector(
//                                 onTap: () {
//                                   setState(() {
//                                     selectedRating = index + 1;
//                                   });
//                                   CommonLogger.log.i(selectedRating);
//                                 },
//                                 child: Image.asset(
//                                   index < selectedRating
//                                       ? AppImages.starFill
//                                       : AppImages.star,
//                                   height: 48,
//                                   width: 48,
//                                   color:
//                                       index < selectedRating
//                                           ? AppColors.commonBlack
//                                           : AppColors.buttonBorder,
//                                 ),
//                               );
//                               return IconButton(
//                                 icon: Icon(
//                                   Icons.star,
//                                   size: 45,
//                                   color:
//                                       index < selectedRating
//                                           ? AppColors.commonBlack
//                                           : AppColors.containerColor,
//                                 ),
//                                 onPressed: () {
//                                   setState(() {
//                                     selectedRating = index + 1;
//                                   });
//                                 },
//                               );
//                             }),
//                           ),
//                         ),
//                         const SizedBox(height: 20),
//                         Padding(
//                           padding: const EdgeInsets.symmetric(horizontal: 10),
//                           child: Row(
//                             children: [
//                               Expanded(
//                                 child: Buttons.button(
//                                   borderRadius: 8,
//                                   textColor: AppColors.commonBlack,
//                                   borderColor: AppColors.buttonBorder,
//                                   buttonColor: AppColors.commonWhite,
//                                   onTap: () {
//                                     Navigator.pop(context);
//                                   },
//                                   text: Text('Close'),
//                                 ),
//                               ),
//                               SizedBox(width: 10),
//                               Expanded(
//                                 child: Buttons.button(
//                                   borderRadius: 8,
//                                   buttonColor: AppColors.commonBlack,
//                                   onTap: () {
//                                     selectedRating;
//                                     CommonLogger.log.i(selectedRating);
//                                     Navigator.pushReplacement(
//                                       context,
//                                       MaterialPageRoute(
//                                         builder:
//                                             (context) => DriverMainScreen(),
//                                       ),
//                                     );
//                                   },
//                                   text: Text('Rate Ride'),
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ),
//                         const SizedBox(height: 20),
//                       ],
//                     ),
//                   ),*/
//                   Padding(
//                     padding: const EdgeInsets.symmetric(vertical: 50),
//                     child: Obx(() {
//                       final profilePic =
//                           getDetails.userProfile.value?.profilePic ?? '';
//                       final firstName =
//                           getDetails.userProfile.value?.firstName ?? 'Customer';
//
//                       return Column(
//                         children: [
//                           profilePic.isNotEmpty
//                               ? CachedNetworkImage(
//                                 imageUrl: profilePic,
//                                 height: 65,
//                                 width: 65,
//                                 imageBuilder:
//                                     (context, imageProvider) => Container(
//                                       height: 65,
//                                       width: 65,
//                                       decoration: BoxDecoration(
//                                         shape: BoxShape.circle,
//                                         image: DecorationImage(
//                                           image: imageProvider,
//                                           fit: BoxFit.cover,
//                                         ),
//                                       ),
//                                     ),
//                                 placeholder:
//                                     (context, url) =>
//                                         const CircularProgressIndicator(),
//                                 errorWidget:
//                                     (context, url, error) => const Icon(
//                                       Icons.person,
//                                       size: 65,
//                                       color: Colors.grey,
//                                     ),
//                               )
//                               : const Icon(
//                                 Icons.person,
//                                 size: 65,
//                                 color: Colors.grey,
//                               ),
//                           const SizedBox(height: 20),
//                           CustomTextfield.textWithStyles600(
//                             textAlign: TextAlign.center,
//                             fontSize: 20,
//                             'Rate your Experience with $firstName?',
//                           ),
//                           SizedBox(height: 20),
//                           Padding(
//                             padding: const EdgeInsets.symmetric(horizontal: 40),
//                             child: Row(
//                               mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//                               children: List.generate(5, (index) {
//                                 return GestureDetector(
//                                   onTap: () {
//                                     setState(() {
//                                       selectedRating = index + 1;
//                                     });
//                                     CommonLogger.log.i(selectedRating);
//                                   },
//                                   child: Image.asset(
//                                     index < selectedRating
//                                         ? AppImages.starFill
//                                         : AppImages.star,
//                                     height: 48,
//                                     width: 48,
//                                     color:
//                                         index < selectedRating
//                                             ? AppColors.commonBlack
//                                             : AppColors.buttonBorder,
//                                   ),
//                                 );
//                                 return IconButton(
//                                   icon: Icon(
//                                     Icons.star,
//                                     size: 45,
//                                     color:
//                                         index < selectedRating
//                                             ? AppColors.commonBlack
//                                             : AppColors.containerColor,
//                                   ),
//                                   onPressed: () {
//                                     setState(() {
//                                       selectedRating = index + 1;
//                                     });
//                                   },
//                                 );
//                               }),
//                             ),
//                           ),
//                           SizedBox(height: 20),
//                           Padding(
//                             padding: const EdgeInsets.symmetric(horizontal: 10),
//                             child: Row(
//                               children: [
//                                 Expanded(
//                                   child: Buttons.button(
//                                     borderRadius: 8,
//                                     textColor: AppColors.commonBlack,
//                                     borderColor: AppColors.buttonBorder,
//                                     buttonColor: AppColors.commonWhite,
//                                     onTap: () {
//                                       Navigator.pop(context);
//                                     },
//                                     text: Text('Close'),
//                                   ),
//                                 ),
//                                 SizedBox(width: 10),
//                                 Expanded(
//                                   child: Buttons.button(
//                                     borderRadius: 8,
//                                     buttonColor: AppColors.commonBlack,
//                                     onTap: () {
//                                       selectedRating;
//                                       CommonLogger.log.i(selectedRating);
//                                       Navigator.pushReplacement(
//                                         context,
//                                         MaterialPageRoute(
//                                           builder:
//                                               (context) => DriverMainScreen(),
//                                         ),
//                                       );
//                                     },
//                                     text: Text('Rate Ride'),
//                                   ),
//                                 ),
//                               ],
//                             ),
//                           ),
//                           SizedBox(height: 10),
//                         ],
//                       );
//                     }),
//                   ),
//                 ],
//               ),
//             );
//           },
//         );
//       },
//     );
//   }
// }
