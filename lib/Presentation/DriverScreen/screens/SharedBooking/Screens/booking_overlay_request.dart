import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

import 'package:hopper/Core/Constants/Colors.dart';
import 'package:hopper/Core/Utility/app_loader.dart';
import 'package:hopper/Core/Utility/images.dart';
import 'package:hopper/Core/Utility/Buttons.dart';
import 'package:hopper/Core/Constants/log.dart';
import 'package:hopper/Presentation/Authentication/widgets/textFields.dart';
import 'package:hopper/Presentation/DriverScreen/controller/driver_status_controller.dart';
import 'package:hopper/Presentation/DriverScreen/screens/SharedBooking/Controller/booking_request_controller.dart';

class BookingOverlayRequest extends StatefulWidget {
  /// isSharedFlow = true ⇒ used inside ShareRideStartScreen
  ///   → Accept should NOT navigate, only join & update shared list
  const BookingOverlayRequest({super.key, this.isSharedFlow = false});

  final bool isSharedFlow;

  @override
  State<BookingOverlayRequest> createState() => _BookingOverlayRequestState();
}

class _BookingOverlayRequestState extends State<BookingOverlayRequest> {
  bool _isAccepting = false; // 👈 local loader only for this popup

  int safeToInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.round();
    return int.tryParse(v.toString()) ?? 0;
  }

  double safeToDouble(dynamic v) {
    if (v == null) return 0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  String formatDuration(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h > 0) return '$h hr $m min';
    return '$m min';
  }

  String formatDistance(double meters) {
    final km = meters / 1000.0;
    return '${km.toStringAsFixed(1)} Km';
  }

  @override
  Widget build(BuildContext context) {
    final bookingController = Get.find<BookingRequestController>();
    final statusController = Get.find<DriverStatusController>();

    return Obx(() {
      final data = bookingController.bookingRequestData.value;
      if (data == null) {
        return const SizedBox.shrink(); // nothing to show
      }

      // final secondsText = bookingController.formatCountdown(); // if you want timer later

      return Positioned(
        left: 0,
        right: 0,
        bottom: 100,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Material(
            color: Colors.transparent,
            child: Column(
              children: [
                const SizedBox(height: 10),

                Card(
                  elevation: 3,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.commonWhite,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: [
                        // HEADER
                        Container(
                          width: double.infinity,
                          height: 65,
                          decoration: BoxDecoration(
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(10),
                              topRight: Radius.circular(10),
                            ),
                            color: AppColors.nBlue,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 15),
                            child: Row(
                              children: [
                                Image.asset(
                                  AppImages.notification,
                                  height: 25,
                                  width: 25,
                                ),
                                const SizedBox(width: 10),
                                CustomTextfield.textWithStyles600(
                                  data['rideType'] == 'Bike'
                                      ? 'New Package Request'
                                      : 'New Ride Request',
                                  color: AppColors.commonWhite,
                                ),
                                const Spacer(),
                                CustomTextfield.textWithImage(
                                  imageColors: AppColors.commonWhite,
                                  text: '${data['estimatedPrice']}',
                                  imagePath: AppImages.bCurrency,
                                  colors: AppColors.commonWhite,
                                  fontWeight: FontWeight.w700,
                                ),
                              ],
                            ),
                          ),
                        ),

                        // ADDRESSES
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.circle,
                                    color: Colors.green,
                                    size: 12,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      data['pickupAddress'] ?? '',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.circle,
                                    color: Colors.red,
                                    size: 12,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      data['dropAddress'] ?? '',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 15),
                          child: Divider(
                            color: AppColors.commonBlack.withOpacity(0.1),
                          ),
                        ),

                        // DURATION + DISTANCE
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 30),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              Row(
                                children: [
                                  Image.asset(
                                    AppImages.time,
                                    height: 20,
                                    width: 20,
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    formatDuration(
                                      safeToInt(data['estimateDuration']),
                                    ),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(
                                height: 40,
                                child: VerticalDivider(
                                  color: AppColors.commonBlack.withOpacity(0.1),
                                ),
                              ),
                              Row(
                                children: [
                                  Image.asset(
                                    AppImages.distance,
                                    height: 20,
                                    width: 20,
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    formatDistance(
                                      safeToDouble(data['estimatedDistance']),
                                    ),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 15),
                          child: Divider(
                            color: AppColors.commonBlack.withOpacity(0.1),
                          ),
                        ),

                        // BUTTONS
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8.0,
                            vertical: 10,
                          ),
                          child: Row(
                            children: [
                              // ❌ DECLINE
                              Expanded(
                                child: Buttons.button(
                                  borderRadius: 10,
                                  buttonColor: AppColors.red,
                                  onTap: () {
                                    final id = data['bookingId']?.toString();
                                    if (id != null) {
                                      bookingController.markHandled(id);
                                    } else {
                                      bookingController.clear();
                                    }
                                  },
                                  text: const Text('Decline'),
                                ),
                              ),
                              const SizedBox(width: 20),

                              // ✅ ACCEPT
                              Expanded(
                                child: Buttons.button(
                                  borderRadius: 10,
                                  buttonColor: AppColors.drkGreen,
                                  onTap: () async {
                                    if (_isAccepting) {
                                      // prevent double taps
                                      return;
                                    }
                                    setState(() => _isAccepting = true);

                                    try {
                                      final bookingId =
                                          data['bookingId'].toString();

                                      final pickupAddress =
                                          data['pickupAddress'] ?? '';
                                      final dropAddress =
                                          data['dropAddress'] ?? '';

                                      final pickup = LatLng(
                                        data['pickupLocation']['latitude'],
                                        data['pickupLocation']['longitude'],
                                      );

                                      final position =
                                          await Geolocator.getCurrentPosition(
                                            desiredAccuracy:
                                                LocationAccuracy.high,
                                          );

                                      final driverLocation = LatLng(
                                        position.latitude,
                                        position.longitude,
                                      );

                                      await statusController.bookingAccept(
                                        context,
                                        bookingId: bookingId,
                                        status: 'ACCEPT',
                                        pickupLocationAddress: pickupAddress,
                                        dropLocationAddress: dropAddress,
                                        pickupLocation: pickup,
                                        driverLocation: driverLocation,

                                        // 🔑 MAIN POINT:
                                        // shared screen → no navigation to picking screen
                                        navigateToPickup: !widget.isSharedFlow,
                                      );

                                      // hide popup for this id
                                      bookingController.markHandled(bookingId);
                                    } catch (e) {
                                      CommonLogger.log.e(
                                        "Booking accept failed: $e",
                                      );
                                    } finally {
                                      if (mounted) {
                                        setState(() => _isAccepting = false);
                                      }
                                    }
                                  },
                                  text:
                                      _isAccepting
                                          ? SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: AppLoader.circularLoader(),
                                          )
                                          : const Text('Accept'),
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
            ),
          ),
        ),
      );
    });
  }
}

// import 'package:flutter/material.dart';
// import 'package:get/get.dart';
// import 'package:google_maps_flutter/google_maps_flutter.dart';
// import 'package:geolocator/geolocator.dart';
//
// import 'package:hopper/Core/Constants/Colors.dart';
// import 'package:hopper/Core/Utility/app_loader.dart';
// import 'package:hopper/Core/Utility/images.dart';
// import 'package:hopper/Core/Utility/Buttons.dart';
// import 'package:hopper/Core/Constants/log.dart';
// import 'package:hopper/Presentation/Authentication/widgets/textFields.dart';
// import 'package:hopper/Presentation/DriverScreen/controller/driver_status_controller.dart';
// import 'package:hopper/Presentation/DriverScreen/screens/SharedBooking/Controller/booking_request_controller.dart';
//
// class BookingOverlayRequest extends StatelessWidget {
//   const BookingOverlayRequest({super.key});
//
//   int safeToInt(dynamic v) {
//     if (v == null) return 0;
//     if (v is int) return v;
//     if (v is double) return v.round();
//     return int.tryParse(v.toString()) ?? 0;
//   }
//
//   double safeToDouble(dynamic v) {
//     if (v == null) return 0;
//     if (v is double) return v;
//     if (v is int) return v.toDouble();
//     return double.tryParse(v.toString()) ?? 0;
//   }
//
//   String formatDuration(int minutes) {
//     final h = minutes ~/ 60;
//     final m = minutes % 60;
//     if (h > 0) return '$h hr $m min';
//     return '$m min';
//   }
//
//   String formatDistance(double meters) {
//     final km = meters / 1000.0;
//     return '${km.toStringAsFixed(1)} Km';
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final bookingController = Get.find<BookingRequestController>();
//     final statusController = Get.find<DriverStatusController>();
//
//     return Obx(() {
//       final data = bookingController.bookingRequestData.value;
//       if (data == null) {
//         return const SizedBox.shrink(); // nothing to show
//       }
//
//       final secondsText = bookingController.formatCountdown();
//
//       return Positioned(
//         left: 0,
//         right: 0,
//         bottom: 100,
//         child: Padding(
//           padding: const EdgeInsets.symmetric(horizontal: 10),
//           child: Material(
//             color: Colors.transparent,
//             child: Column(
//               children: [
//                 // Row(
//                 //   mainAxisAlignment: MainAxisAlignment.center,
//                 //   children: [
//                 //     Container(
//                 //       padding: const EdgeInsets.symmetric(
//                 //         horizontal: 10,
//                 //         vertical: 5,
//                 //       ),
//                 //       decoration: BoxDecoration(
//                 //         color: AppColors.red,
//                 //         borderRadius: BorderRadius.circular(5),
//                 //       ),
//                 //       child: CustomTextfield.textWithStyles600(
//                 //         color: AppColors.commonWhite,
//                 //         '${secondsText}s',
//                 //       ),
//                 //     ),
//                 //     const SizedBox(width: 15),
//                 //     const Text(
//                 //       "Respond within 15 seconds",
//                 //       style: TextStyle(fontWeight: FontWeight.w700),
//                 //     ),
//                 //   ],
//                 // ),
//                 const SizedBox(height: 10),
//
//                 Card(
//                   elevation: 3,
//                   child: Container(
//                     decoration: BoxDecoration(
//                       color: AppColors.commonWhite,
//                       borderRadius: BorderRadius.circular(10),
//                     ),
//                     child: Column(
//                       children: [
//                         Container(
//                           width: double.infinity,
//                           height: 65,
//                           decoration: BoxDecoration(
//                             borderRadius: BorderRadius.only(
//                               topLeft: Radius.circular(10),
//                               topRight: Radius.circular(10),
//                             ),
//                             color: AppColors.nBlue,
//                           ),
//                           child: Padding(
//                             padding: const EdgeInsets.symmetric(horizontal: 15),
//                             child: Row(
//                               children: [
//                                 Image.asset(
//                                   AppImages.notification,
//                                   height: 25,
//                                   width: 25,
//                                 ),
//                                 const SizedBox(width: 10),
//                                 CustomTextfield.textWithStyles600(
//                                   data['rideType'] == 'Bike'
//                                       ? 'New Package Request'
//                                       : 'New Ride Request',
//                                   color: AppColors.commonWhite,
//                                 ),
//                                 const Spacer(),
//                                 CustomTextfield.textWithImage(
//                                   imageColors: AppColors.commonWhite,
//                                   text: '${data['estimatedPrice']}',
//                                   imagePath: AppImages.bCurrency,
//                                   colors: AppColors.commonWhite,
//                                   fontWeight: FontWeight.w700,
//                                 ),
//                               ],
//                             ),
//                           ),
//                         ),
//
//                         // addresses
//                         Padding(
//                           padding: const EdgeInsets.all(8.0),
//                           child: Column(
//                             children: [
//                               Row(
//                                 children: [
//                                   const Icon(
//                                     Icons.circle,
//                                     color: Colors.green,
//                                     size: 12,
//                                   ),
//                                   const SizedBox(width: 8),
//                                   Expanded(
//                                     child: Text(
//                                       data['pickupAddress'] ?? '',
//                                       maxLines: 2,
//                                       overflow: TextOverflow.ellipsis,
//                                     ),
//                                   ),
//                                 ],
//                               ),
//                               const SizedBox(height: 8),
//                               Row(
//                                 children: [
//                                   const Icon(
//                                     Icons.circle,
//                                     color: Colors.red,
//                                     size: 12,
//                                   ),
//                                   const SizedBox(width: 8),
//                                   Expanded(
//                                     child: Text(
//                                       data['dropAddress'] ?? '',
//                                       maxLines: 2,
//                                       overflow: TextOverflow.ellipsis,
//                                     ),
//                                   ),
//                                 ],
//                               ),
//                             ],
//                           ),
//                         ),
//
//                         Padding(
//                           padding: const EdgeInsets.symmetric(horizontal: 15),
//                           child: Divider(
//                             color: AppColors.commonBlack.withOpacity(0.1),
//                           ),
//                         ),
//
//                         // duration + distance
//                         Padding(
//                           padding: const EdgeInsets.symmetric(horizontal: 30),
//                           child: Row(
//                             mainAxisAlignment: MainAxisAlignment.spaceAround,
//                             children: [
//                               Row(
//                                 children: [
//                                   Image.asset(
//                                     AppImages.time,
//                                     height: 20,
//                                     width: 20,
//                                   ),
//                                   const SizedBox(width: 10),
//                                   Text(
//                                     formatDuration(
//                                       safeToInt(data['estimateDuration']),
//                                     ),
//                                     style: const TextStyle(
//                                       fontWeight: FontWeight.w500,
//                                     ),
//                                   ),
//                                 ],
//                               ),
//                               SizedBox(
//                                 height: 40,
//                                 child: VerticalDivider(
//                                   color: AppColors.commonBlack.withOpacity(0.1),
//                                 ),
//                               ),
//                               Row(
//                                 children: [
//                                   Image.asset(
//                                     AppImages.distance,
//                                     height: 20,
//                                     width: 20,
//                                   ),
//                                   const SizedBox(width: 10),
//                                   Text(
//                                     formatDistance(
//                                       safeToDouble(data['estimatedDistance']),
//                                     ),
//                                     style: const TextStyle(
//                                       fontWeight: FontWeight.w500,
//                                     ),
//                                   ),
//                                 ],
//                               ),
//                             ],
//                           ),
//                         ),
//
//                         Padding(
//                           padding: const EdgeInsets.symmetric(horizontal: 15),
//                           child: Divider(
//                             color: AppColors.commonBlack.withOpacity(0.1),
//                           ),
//                         ),
//
//                         // buttons
//                         Padding(
//                           padding: const EdgeInsets.symmetric(
//                             horizontal: 8.0,
//                             vertical: 10,
//                           ),
//                           child: Row(
//                             children: [
//                               // DECLINE
//                               Expanded(
//                                 child: Buttons.button(
//                                   borderRadius: 10,
//                                   buttonColor: AppColors.red,
//                                   onTap:
//                                       statusController.isLoading.value
//                                           ? null
//                                           : () {
//                                         final id = data['bookingId']?.toString();
//                                         if (id != null) {
//                                           bookingController.markHandled(id);   // ✅ no more popup for this id
//                                         } else {
//                                           bookingController.clear();
//                                         }
//
//                                         // Just hide popup (you can also call API for REJECT here)
//                                         //     bookingController.clear();
//                                           },
//                                   text: const Text('Decline'),
//                                 ),
//                               ),
//                               const SizedBox(width: 20),
//
//                               // ACCEPT
//                               Obx(() {
//                                 return Expanded(
//                                   child: Buttons.button(
//                                     borderRadius: 10,
//                                     buttonColor: AppColors.drkGreen,
//                                     onTap:
//                                         statusController.isLoading.value
//                                             ? null
//                                             : () async {
//                                               try {
//                                                 final bookingId =
//                                                     data['bookingId'];
//                                                 final pickupAddress =
//                                                     data['pickupAddress'] ?? '';
//                                                 final dropAddress =
//                                                     data['dropAddress'] ?? '';
//
//                                                 final pickup = LatLng(
//                                                   data['pickupLocation']['latitude'],
//                                                   data['pickupLocation']['longitude'],
//                                                 );
//
//                                                 final position =
//                                                     await Geolocator.getCurrentPosition(
//                                                       desiredAccuracy:
//                                                           LocationAccuracy.high,
//                                                     );
//
//                                                 final driverLocation = LatLng(
//                                                   position.latitude,
//                                                   position.longitude,
//                                                 );
//
//                                                 await statusController
//                                                     .bookingAccept(
//                                                       pickupLocationAddress:
//                                                           pickupAddress,
//                                                       dropLocationAddress:
//                                                           dropAddress,
//                                                       context,
//                                                       bookingId: bookingId,
//                                                       status: 'ACCEPT',
//                                                       pickupLocation: pickup,
//                                                       driverLocation:
//                                                           driverLocation,
//                                                     );
//
//                                                 bookingController.markHandled(bookingId.toString());
//
//                                               } catch (e) {
//                                                 CommonLogger.log.e(
//                                                   "Booking accept failed: $e",
//                                                 );
//                                               }
//                                             },
//                                     text:
//                                         statusController.isLoading.value
//                                             ? SizedBox(
//                                               height: 20,
//                                               width: 20,
//                                               child: AppLoader.circularLoader(),
//                                             )
//                                             : const Text('Accept'),
//                                   ),
//                                 );
//                               }),
//                             ],
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ),
//       );
//     });
//   }
// }
