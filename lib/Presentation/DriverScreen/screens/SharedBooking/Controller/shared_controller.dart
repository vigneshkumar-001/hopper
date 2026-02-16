// lib/Presentation/DriverScreen/screens/SharedBooking/Controller/shared_controller.dart

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';

import 'package:hopper/Core/Constants/log.dart';
import 'package:hopper/Core/Utility/snackbar.dart';
import 'package:hopper/Presentation/DriverScreen/models/booking_accept_model.dart';
import 'package:hopper/Presentation/DriverScreen/screens/SharedBooking/Controller/shared_ride_controller.dart';
import 'package:hopper/Presentation/DriverScreen/screens/SharedBooking/Screens/picking_shared_screens.dart';
import 'package:hopper/Presentation/DriverScreen/screens/cash_collected_screen.dart';
import 'package:hopper/Presentation/DriverScreen/screens/driver_main_screen.dart';
import 'package:hopper/Presentation/DriverScreen/screens/verify_rider_screen.dart';
import 'package:hopper/api/dataSource/apiDataSource.dart';
import 'package:hopper/utils/websocket/socket_io_client.dart';

class SharedController extends GetxController {
  var isOnline = false.obs;
  RxBool isLoading = false.obs;
  var serviceType = ''.obs;
  RxBool arrivedIsLoading = false.obs;
  final socketService = SocketService();

  ApiDataSource apiDataSource = ApiDataSource();
  final tripDistanceInMeters = 0.0.obs;
  final tripDurationInMin = 0.0.obs;
  final RxString paymentType = ''.obs;
  final RxString paymentStatus = ''.obs;
  final pickupDurationInMin = 0.0.obs;
  final pickupDistanceInMeters = 0.0.obs;
  var dropDurationInMin = 0.0.obs;
  var dropDistanceInMeters = 0.0.obs;

  late final SharedRideController sharedRideController;

  @override
  void onInit() {
    super.onInit();

    // Ensure SharedRideController is global & shared
    if (Get.isRegistered<SharedRideController>()) {
      sharedRideController = Get.find<SharedRideController>();
    } else {
      sharedRideController = Get.put(
        SharedRideController(),
        permanent: true,
      );
    }

    _listenDriverLocation();
    _listenJoinedBooking(); // 🔥 handle joined-booking in common place
  }

  // ───────────────── LISTENERS ─────────────────

  void _listenDriverLocation() {
    CommonLogger.log.i('🔗 [STATUS] attach driver-location listener');

    socketService.on('driver-location', (data) {
      CommonLogger.log.i('🚗 [STATUS] driver-location: $data');

      if (data == null) return;

      // Try to get active shared ride target (if any)
      SharedRideController? sharedRide;
      if (Get.isRegistered<SharedRideController>()) {
        sharedRide = Get.find<SharedRideController>();
      }

      final String? eventBookingId = data['bookingId']?.toString();
      final String? activeBookingId =
          sharedRide?.activeTarget.value?.bookingId;

      // If we already have an active target, ignore updates for other bookings
      if (activeBookingId != null &&
          eventBookingId != null &&
          eventBookingId != activeBookingId) {
        CommonLogger.log.i(
          '⏭ Ignoring ETA for booking $eventBookingId (active: $activeBookingId)',
        );
        return;
      }

      // Trip totals
      final tripMeters = data['tripDistanceInMeters'];
      if (tripMeters != null) {
        tripDistanceInMeters.value = (tripMeters as num).toDouble();
      }

      final tripMinutes = data['tripDurationInMin'];
      if (tripMinutes != null) {
        tripDurationInMin.value = (tripMinutes as num).toDouble();
      }

      // Pickup ETA
      final pickupMeters = data['pickupDistanceInMeters'];
      if (pickupMeters != null) {
        pickupDistanceInMeters.value = (pickupMeters as num).toDouble();
      }

      final pickupMinutes = data['pickupDurationInMin'];
      if (pickupMinutes != null) {
        pickupDurationInMin.value = (pickupMinutes as num).toDouble();
      }

      // Drop ETA
      final dropMeters = data['dropDistanceInMeters'];
      if (dropMeters != null) {
        dropDistanceInMeters.value = (dropMeters as num).toDouble();
      }

      final dropMinutes = data['dropDurationInMin'];
      if (dropMinutes != null) {
        dropDurationInMin.value = (dropMinutes as num).toDouble();
      }
    });
  }

  void _listenJoinedBooking() {
    CommonLogger.log.i('🔗 [STATUS] attach joined-booking listener');

    socketService.onAck('joined-booking', (data, ack) async {
      CommonLogger.log.i('📦 [STATUS] joined-booking: $data');

      if (ack != null) {
        ack({
          "status": true,
          "message": "Driver received joined-booking in SharedController",
        });
      }

      if (data == null) return;

      final customerLoc = data['customerLocation'];
      if (customerLoc == null) {
        CommonLogger.log.w('⚠️ joined-booking without customerLocation');
        return;
      }

      final fromLat = (customerLoc['fromLatitude'] as num).toDouble();
      final fromLng = (customerLoc['fromLongitude'] as num).toDouble();
      final toLat = (customerLoc['toLatitude'] as num).toDouble();
      final toLng = (customerLoc['toLongitude'] as num).toDouble();

      final pickupAddr = await _getAddressFromLatLng(fromLat, fromLng);
      final dropoffAddr = await _getAddressFromLatLng(toLat, toLng);

      final normalized = Map<String, dynamic>.from(data);
      normalized['pickupAddress'] = pickupAddr;
      normalized['dropoffAddress'] = dropoffAddr;

      if (!Get.isRegistered<SharedRideController>()) {
        CommonLogger.log.w('⚠️ SharedRideController not registered (yet)');
        return;
      }

      final sharedRide = Get.find<SharedRideController>();
      sharedRide.upsertFromSocket(normalized);
      CommonLogger.log.i('✅ Rider upserted into SharedRideController');
    });
  }

  // ───────────────── HELPERS ─────────────────

  Future<String> _getAddressFromLatLng(double lat, double lng) async {
    try {
      final list = await placemarkFromCoordinates(lat, lng);
      final p = list.first;
      return "${p.name}, ${p.locality}, ${p.administrativeArea}";
    } catch (_) {
      return "Location not available";
    }
  }

  // ───────────────── API ACTIONS ─────────────────

  Future<String?> bookingAccept(
      BuildContext context, {
        required String bookingId,
        required String status,
        required String pickupLocationAddress,
        required String dropLocationAddress,
        required LatLng pickupLocation,
        required LatLng driverLocation,
      }) async {
    isLoading.value = true;
    try {
      final results = await apiDataSource.bookingAccept(
        bookingId: bookingId,
        status: status,
      );
      results.fold(
            (failure) {
          CustomSnackBar.showError(failure.message);
          isLoading.value = false;
          return '';
        },
            (response) {
          final bookingData = {
            'bookingId': response.data?.bookingId,
            'userId': response.data?.driverId,
            'userType': 'driver',
          };

          CommonLogger.log.i("📤 Join booking data: $bookingData");

          if (socketService.connected) {
            socketService.emit('join-booking', bookingData);
            CommonLogger.log.i(
              "✅ Socket already connected, emitted join-booking",
            );
          } else {
            socketService.onConnect(() {
              CommonLogger.log.i("✅ Socket connected, emitting join-booking");
              socketService.emit('join-booking', bookingData);
            });
          }

          CommonLogger.log.i(response.data);

          Get.to(
                () => PickingCustomerSharedScreen(
              pickupLocation: pickupLocation,
              driverLocation: driverLocation,
              bookingId: bookingId,
              pickupLocationAddress: pickupLocationAddress,
              dropLocationAddress: dropLocationAddress,
            ),
          );

          isLoading.value = false;
          return ' ';
        },
      );
    } catch (e) {
      isLoading.value = false;
      return ' ';
    }
    isLoading.value = false;
    return '';
  }

  Future<String?> otpRequest(
      BuildContext context, {
        required String bookingId,
        required String custName,
        required String pickupAddress,
        required String dropAddress,
      }) async {
    isLoading.value = true;
    try {
      final results = await apiDataSource.otpRequest(bookingId: bookingId);

      String? resultMessage;

      results.fold(
            (failure) {
          isLoading.value = false;
          CustomSnackBar.showError(failure.message);
          resultMessage = null;
        },
            (response) {
          isLoading.value = false;
          CustomSnackBar.showSuccess(response.message);
          CommonLogger.log.i(response.message);

          resultMessage = response.message;

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => VerifyRiderScreen(
                pickupAddress: pickupAddress,
                dropAddress: dropAddress,
                bookingId: bookingId,
                custName: custName,
              ),
            ),
          );
        },
      );

      return resultMessage;
    } catch (e) {
      isLoading.value = false;
      return 'Something went wrong';
    }
  }

  Future<String?> completeRideRequest(
      BuildContext context, {
        required String bookingId,
        required dynamic Amount,
      }) async {
    isLoading.value = true;
    try {
      final results = await apiDataSource.completeRideRequest(
        bookingId: bookingId,
      );

      String? resultMessage;

      results.fold(
            (failure) {
          isLoading.value = false;
          CustomSnackBar.showError(failure.message);
          resultMessage = null;
        },
            (response) {
          isLoading.value = false;
          CommonLogger.log.i(response.message);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  CashCollectedScreen(Amount: Amount, bookingId: bookingId),
            ),
          );

          resultMessage = response.message;
        },
      );

      return resultMessage;
    } catch (e) {
      isLoading.value = false;
      return 'Something went wrong';
    }
  }

  Future<String?> otpInsert(
      BuildContext context, {
        required String bookingId,
        required String otp,
      }) async {
    isLoading.value = true;

    try {
      final results = await apiDataSource.otpInsert(
        bookingId: bookingId,
        enteredOtp: otp,
      );

      return results.fold(
            (failure) {
          isLoading.value = false;
          CustomSnackBar.showError(failure.message);
          return null;
        },
            (response) {
          return response.message;
        },
      );
    } catch (e) {
      isLoading.value = false;
      return null;
    }
  }

  Future<BookingAcceptModel?> driverArrived(
      BuildContext context, {
        required String bookingId,
      }) async {
    arrivedIsLoading.value = true;

    try {
      final results = await apiDataSource.driverArrived(bookingId: bookingId);

      return results.fold(
            (failure) {
          arrivedIsLoading.value = false;
          return null;
        },
            (response) {
          arrivedIsLoading.value = false;
          return response;
        },
      );
    } catch (e) {
      arrivedIsLoading.value = false;
      return null;
    }
  }

  Future<String?> onlineAcceptStatus(
      BuildContext context, {
        required bool status,
        required double latitude,
        required double longitude,
      }) async {
    isLoading.value = true;
    try {
      final results = await apiDataSource.driverOnlineStatus(
        latitude: latitude,
        longitude: longitude,
        onlineStatus: status,
      );
      results.fold(
            (failure) {
          isLoading.value = false;
          return '';
        },
            (response) {
          CommonLogger.log.i(response.data);
          isLoading.value = false;
          return ' ';
        },
      );
    } catch (e) {
      isLoading.value = false;
      return ' ';
    }
    isLoading.value = false;
    return '';
  }

  Future<String?> cancelBooking(
      BuildContext context, {
        required String reason,
        required String bookingId,
      }) async {
    try {
      final results = await apiDataSource.cancelBooking(
        reason: reason,
        bookingId: bookingId,
      );

      results.fold(
            (failure) {
          Get.offAll(DriverMainScreen());
          CommonLogger.log.e("failure: ${failure.message}");
          return '';
        },
            (response) {
          Get.offAll(DriverMainScreen());
          CommonLogger.log.i("Response: ${response.message}");
          CustomSnackBar.showSuccess(response.message);
          return '';
        },
      );
    } catch (e) {
      return ' ';
    }

    return '';
  }

  Future<void> getDriverStatus() async {
    try {
      final results = await apiDataSource.getDriverStatus();

      results.fold(
            (failure) {
          CommonLogger.log.e("failure: ${failure.message}");
          return '';
        },
            (response) {
          CommonLogger.log.i("Response: ${response.data}");
          isOnline.value = response.data.onlineStatus;
          serviceType.value = response.data.serviceType;
          CommonLogger.log.i(isOnline.value);
        },
      );
    } catch (e) {
      CommonLogger.log.i(e);
    }
  }

  Future<void> getAmountStatus({required String bookingId}) async {
    try {
      final results = await apiDataSource.getAmountStatus(bookingId: bookingId);

      results.fold(
            (failure) {
          CommonLogger.log.e("failure: ${failure.message}");
        },
            (response) {
          CommonLogger.log.i("Response: ${response.data}");
          paymentType.value = response.data.paymentType;
          paymentStatus.value = response.data.paymentStatus;
        },
      );
    } catch (e) {
      CommonLogger.log.i(e);
    }
  }

  Future<void> amountCollectedStatus({
    required String booking,
    VoidCallback? onSuccess,
  }) async {
    isLoading.value = true;
    try {
      final results = await apiDataSource.amountCollectedStatus(
        bookingId: booking,
      );

      results.fold(
            (failure) {
          isLoading.value = false;
          CommonLogger.log.e("failure: ${failure.message}");
        },
            (response) {
          isLoading.value = false;
          CommonLogger.log.i(response.toJson());

          if (response.status == 200) {
            if (onSuccess != null) onSuccess();
          }
        },
      );
    } catch (e) {
      isLoading.value = false;
      CommonLogger.log.i(e);
    }
  }

  Future<void> driverRatingToCustomer({
    required String bookingId,
    required int rating,
    required BuildContext context,
  }) async {
    isLoading.value = true;
    try {
      final results = await apiDataSource.driverRating(
        bookingId: bookingId,
        rating: rating,
      );

      results.fold(
            (failure) {
          isLoading.value = false;
          CommonLogger.log.e("failure: ${failure.message}");
          return '';
        },
            (response) {
          isLoading.value = false;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => DriverMainScreen()),
          );
          CommonLogger.log.i(response.toJson());
        },
      );
    } catch (e) {
      isLoading.value = false;
      CommonLogger.log.i(e);
    }
  }
}


// import 'package:flutter/material.dart';
// import 'package:flutter/scheduler.dart';
// import 'package:get/get.dart';
// import 'package:google_maps_flutter/google_maps_flutter.dart';
// import 'package:hopper/Core/Constants/log.dart';
// import 'package:hopper/Core/Utility/snackbar.dart';
// import 'package:hopper/Presentation/DriverScreen/models/booking_accept_model.dart';
// import 'package:hopper/Presentation/DriverScreen/screens/SharedBooking/Controller/shared_ride_controller.dart';
// import 'package:hopper/Presentation/DriverScreen/screens/SharedBooking/Screens/picking_shared_screens.dart';
// import 'package:hopper/Presentation/DriverScreen/screens/cash_collected_screen.dart';
// import 'package:hopper/Presentation/DriverScreen/screens/driver_main_screen.dart';
// import 'package:hopper/Presentation/DriverScreen/screens/verify_rider_screen.dart';
// import 'package:hopper/api/dataSource/apiDataSource.dart';
// import 'package:hopper/utils/websocket/socket_io_client.dart';
//
// class SharedController extends GetxController {
//   var isOnline = false.obs;
//   RxBool isLoading = false.obs;
//   var serviceType = ''.obs;
//   RxBool arrivedIsLoading = false.obs;
//   final socketService = SocketService();
//
//   ApiDataSource apiDataSource = ApiDataSource();
//   final tripDistanceInMeters = 0.0.obs;
//   final tripDurationInMin = 0.0.obs;
//   final RxString paymentType = ''.obs;
//   final RxString paymentStatus = ''.obs;
//   final pickupDurationInMin = 0.0.obs;
//   final pickupDistanceInMeters = 0.0.obs;
//
//   var dropDurationInMin = 0.0.obs;
//   var dropDistanceInMeters = 0.0.obs;
//
//   late final SharedRideController sharedRideController;
//
//   @override
//   void onInit() {
//     super.onInit();
//
//     _listenDriverLocation();
//   }
//
//   void _listenDriverLocation() {
//     CommonLogger.log.i('🔗 [STATUS] attach driver-location listener');
//
//     socketService.on('driver-location', (data) {
//       CommonLogger.log.i('🚗 [STATUS] driver-location: $data');
//
//       if (data == null) return;
//
//
//       SharedRideController? sharedRideController;
//       if (Get.isRegistered<SharedRideController>()) {
//         sharedRideController = Get.find<SharedRideController>();
//       }
//
//
//       final String? eventBookingId = data['bookingId']?.toString();
//
//       // active target bookingId (only if shared ride screen is alive)
//       final String? activeBookingId =
//           sharedRideController?.activeTarget.value?.bookingId;
//
//       // If we already have an active target, ignore updates for other bookings
//       if (activeBookingId != null &&
//           eventBookingId != null &&
//           eventBookingId != activeBookingId) {
//         CommonLogger.log.i(
//           '⏭ Ignoring ETA for booking $eventBookingId (active: $activeBookingId)',
//         );
//         return;
//       }
//
//       // --- 2️⃣ Trip totals (optional) ---
//       final tripMeters = data['tripDistanceInMeters'];
//       if (tripMeters != null) {
//         tripDistanceInMeters.value = (tripMeters as num).toDouble();
//       }
//
//       final tripMinutes = data['tripDurationInMin'];
//       if (tripMinutes != null) {
//         tripDurationInMin.value = (tripMinutes as num).toDouble();
//       }
//
//       // --- 3️⃣ Pickup ETA ---
//       final pickupMeters = data['pickupDistanceInMeters'];
//       if (pickupMeters != null) {
//         pickupDistanceInMeters.value = (pickupMeters as num).toDouble();
//       }
//
//       final pickupMinutes = data['pickupDurationInMin'];
//       if (pickupMinutes != null) {
//         pickupDurationInMin.value = (pickupMinutes as num).toDouble();
//       }
//
//       // --- 4️⃣ Drop ETA ---
//       final dropMeters = data['dropDistanceInMeters'];
//       if (dropMeters != null) {
//         dropDistanceInMeters.value = (dropMeters as num).toDouble();
//       }
//
//       final dropMinutes = data['dropDurationInMin'];
//       if (dropMinutes != null) {
//         dropDurationInMin.value = (dropMinutes as num).toDouble();
//       }
//     });
//   }
//
//   Future<String?> bookingAccept(
//     BuildContext context, {
//     required String bookingId,
//     required String status,
//     required String pickupLocationAddress,
//     required String dropLocationAddress,
//     required LatLng pickupLocation,
//     required LatLng driverLocation,
//   }) async {
//     isLoading.value = true;
//     try {
//       final results = await apiDataSource.bookingAccept(
//         bookingId: bookingId,
//         status: status,
//       );
//       results.fold(
//         (failure) {
//           CustomSnackBar.showError(failure.message);
//           isLoading.value = false;
//
//           return '';
//         },
//         (response) {
//           // CustomSnackBar.showSuccess(response.message.toString());
//           final bookingData = {
//             'bookingId': response.data?.bookingId,
//             'userId': response.data?.driverId,
//             'userType': 'driver',
//           };
//
//           // Log the data
//           CommonLogger.log.i("📤 Join booking data: $bookingData");
//
//           if (socketService.connected) {
//             socketService.emit('join-booking', bookingData);
//             CommonLogger.log.i(
//               "✅ Socket already connected, emitted join-booking",
//             );
//           } else {
//             socketService.onConnect(() {
//               CommonLogger.log.i("✅ Socket connected, emitting join-booking");
//               socketService.emit('join-booking', bookingData);
//             });
//           }
//
//           CommonLogger.log.i(response.data);
//
//           // Get.to(
//           //   PickingCustomerScreen(
//           //     bookingId: bookingId,
//           //     pickupLocationAddress: pickupLocationAddress,
//           //     dropLocationAddress: dropLocationAddress,
//           //     pickupLocation: pickupLocation,
//           //     driverLocation: driverLocation,
//           //   ),
//           // );
//
//           Get.to(
//             () => PickingCustomerSharedScreen(
//               pickupLocation: pickupLocation,
//               driverLocation: driverLocation,
//               bookingId: bookingId,
//               pickupLocationAddress: pickupLocationAddress,
//               dropLocationAddress: dropLocationAddress,
//             ),
//           );
//
//           isLoading.value = false;
//
//           return ' ';
//         },
//       );
//     } catch (e) {
//       isLoading.value = false;
//       return ' ';
//     }
//     isLoading.value = false;
//     return '';
//   }
//
//   Future<String?> otpRequest(
//     BuildContext context, {
//     required String bookingId,
//     required String custName,
//     required String pickupAddress,
//     required String dropAddress,
//   }) async {
//     isLoading.value = true;
//     try {
//       final results = await apiDataSource.otpRequest(bookingId: bookingId);
//
//       String? resultMessage;
//
//       results.fold(
//         (failure) {
//           isLoading.value = false;
//           CustomSnackBar.showError(failure.message);
//           resultMessage = null;
//         },
//         (response) {
//           isLoading.value = false;
//           CustomSnackBar.showSuccess(response.message);
//           CommonLogger.log.i(response.message);
//
//           resultMessage = response.message;
//
//           Navigator.push(
//             context,
//             MaterialPageRoute(
//               builder:
//                   (context) => VerifyRiderScreen(
//                     pickupAddress: pickupAddress,
//                     dropAddress: dropAddress,
//                     bookingId: bookingId,
//                     custName: custName,
//                   ),
//             ),
//           );
//         },
//       );
//
//       return resultMessage;
//     } catch (e) {
//       isLoading.value = false;
//       return 'Something went wrong';
//     }
//   }
//
//   Future<String?> completeRideRequest(
//     BuildContext context, {
//     required String bookingId,
//     required dynamic Amount,
//   }) async {
//     isLoading.value = true;
//     try {
//       final results = await apiDataSource.completeRideRequest(
//         bookingId: bookingId,
//       );
//
//       String? resultMessage;
//
//       results.fold(
//         (failure) {
//           isLoading.value = false;
//           CustomSnackBar.showError(failure.message);
//           resultMessage = null;
//         },
//         (response) {
//           isLoading.value = false;
//           // CustomSnackBar.showSuccess(response.data?. status  ??"" );
//           CommonLogger.log.i(response.message);
//           Navigator.push(
//             context,
//             MaterialPageRoute(
//               builder:
//                   (context) =>
//                       CashCollectedScreen(Amount: Amount, bookingId: bookingId),
//             ),
//           );
//
//           resultMessage = response.message;
//         },
//       );
//
//       return resultMessage;
//     } catch (e) {
//       isLoading.value = false;
//       return 'Something went wrong';
//     }
//   }
//
//   Future<String?> otpInsert(
//     BuildContext context, {
//     required String bookingId,
//     required String otp,
//   }) async {
//     isLoading.value = true;
//
//     try {
//       final results = await apiDataSource.otpInsert(
//         bookingId: bookingId,
//         enteredOtp: otp,
//       );
//
//       return results.fold(
//         (failure) {
//           isLoading.value = false;
//           CustomSnackBar.showError(failure.message);
//           return null;
//         },
//         (response) {
//           // isLoading.value = false;
//
//           return response.message; // ✅ just return message
//         },
//       );
//     } catch (e) {
//       isLoading.value = false;
//       return null;
//     }
//   }
//
//   Future<BookingAcceptModel?> driverArrived(
//     BuildContext context, {
//     required String bookingId,
//   }) async {
//     arrivedIsLoading.value = true;
//
//     try {
//       final results = await apiDataSource.driverArrived(bookingId: bookingId);
//
//       return results.fold(
//         (failure) {
//           arrivedIsLoading.value = false;
//           return null;
//         },
//         (response) {
//           arrivedIsLoading.value = false;
//           return response;
//         },
//       );
//     } catch (e) {
//       arrivedIsLoading.value = false;
//       return null;
//     }
//   }
//
//   Future<String?> onlineAcceptStatus(
//     BuildContext context, {
//
//     required bool status,
//     required double latitude,
//     required double longitude,
//   }) async {
//     isLoading.value = true;
//     try {
//       final results = await apiDataSource.driverOnlineStatus(
//         latitude: latitude,
//         longitude: longitude,
//         onlineStatus: status,
//       );
//       results.fold(
//         (failure) {
//           //  CustomSnackBar.showError(failure.message);
//           isLoading.value = false;
//
//           return '';
//         },
//         (response) {
//           // CustomSnackBar.showSuccess(response.message.toString());
//           CommonLogger.log.i(response.data);
//           // Get.to(PickingCustomerScreen());
//
//           isLoading.value = false;
//
//           return ' ';
//         },
//       );
//     } catch (e) {
//       isLoading.value = false;
//       return ' ';
//     }
//     isLoading.value = false;
//     return '';
//   }
//
//   Future<String?> cancelBooking(
//     BuildContext context, {
//     required String reason,
//     required String bookingId,
//   }) async {
//     try {
//       final results = await apiDataSource.cancelBooking(
//         reason: reason,
//         bookingId: bookingId,
//       );
//
//       results.fold(
//         (failure) {
//           Get.offAll(DriverMainScreen());
//           // CustomSnackBar.showError(failure.message);
//           CommonLogger.log.e("failure: ${failure.message}");
//           return '';
//         },
//         (response) {
//           Get.offAll(DriverMainScreen());
//           CommonLogger.log.i("Response: ${response.message}");
//           CustomSnackBar.showSuccess(response.message);
//           CommonLogger.log.i("Assigned to todayStatusData:");
//
//           return '';
//         },
//       );
//     } catch (e) {
//       return ' ';
//     }
//
//     return '';
//   }
//
//   Future<void> getDriverStatus() async {
//     try {
//       final results = await apiDataSource.getDriverStatus();
//
//       results.fold(
//         (failure) {
//           // CustomSnackBar.showError(failure.message);
//           CommonLogger.log.e("failure: ${failure.message}");
//
//           return '';
//         },
//         (response) {
//           CommonLogger.log.i("Response: ${response.data}");
//
//           isOnline.value = response.data.onlineStatus;
//           serviceType.value = response.data.serviceType;
//           CommonLogger.log.i(isOnline.value);
//         },
//       );
//     } catch (e) {
//       CommonLogger.log.i(e);
//     }
//   }
//
//   Future<void> getAmountStatus({required String bookingId}) async {
//     try {
//       final results = await apiDataSource.getAmountStatus(bookingId: bookingId);
//
//       results.fold(
//         (failure) {
//           CommonLogger.log.e("failure: ${failure.message}");
//         },
//         (response) {
//           CommonLogger.log.i("Response: ${response.data}");
//           paymentType.value = response.data.paymentType;
//           paymentStatus.value = response.data.paymentStatus;
//         },
//       );
//     } catch (e) {
//       CommonLogger.log.i(e);
//     }
//   }
//
//   Future<void> amountCollectedStatus({
//     required String booking,
//     VoidCallback? onSuccess, // callback for UI
//   }) async {
//     isLoading.value = true;
//     try {
//       final results = await apiDataSource.amountCollectedStatus(
//         bookingId: booking,
//       );
//
//       results.fold(
//         (failure) {
//           isLoading.value = false;
//           CommonLogger.log.e("failure: ${failure.message}");
//         },
//         (response) {
//           isLoading.value = false;
//           CommonLogger.log.i(response.toJson());
//
//           // ✅ Trigger callback if success
//           if (response.status == 200) {
//             if (onSuccess != null) onSuccess();
//           }
//         },
//       );
//     } catch (e) {
//       isLoading.value = false;
//       CommonLogger.log.i(e);
//     }
//   }
//
//   Future<void> driverRatingToCustomer({
//     required String bookingId,
//     required int rating,
//     required BuildContext context,
//   }) async {
//     isLoading.value = true;
//     try {
//       final results = await apiDataSource.driverRating(
//         bookingId: bookingId,
//         rating: rating,
//       );
//
//       results.fold(
//         (failure) {
//           isLoading.value = false;
//           // CustomSnackBar.showError(failure.message);
//           CommonLogger.log.e("failure: ${failure.message}");
//
//           return '';
//         },
//         (response) {
//           isLoading.value = false;
//           Navigator.pushReplacement(
//             context,
//             MaterialPageRoute(builder: (_) => DriverMainScreen()),
//           );
//           CommonLogger.log.i(response.toJson());
//         },
//       );
//     } catch (e) {
//       isLoading.value = false;
//       CommonLogger.log.i(e);
//     }
//   }
// }
