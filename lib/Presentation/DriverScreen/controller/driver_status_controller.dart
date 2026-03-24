import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:hopper/Core/Constants/log.dart';
import 'package:hopper/Presentation/DriverScreen/models/today_parcel_activity_response.dart';
import 'package:hopper/Presentation/DriverScreen/models/weekly_challenge_models.dart';
import 'package:hopper/Presentation/DriverScreen/screens/cash_collected_screen.dart';
import 'package:hopper/Presentation/OnBoarding/screens/completedScreens.dart';
import 'package:hopper/api/dataSource/apiDataSource.dart';
import 'package:hopper/utils/websocket/socket_io_client.dart';
import 'package:hopper/utils/map/navigation_assist.dart';
import '../../../Core/Utility/snackbar.dart';
import 'package:hopper/Presentation/DriverScreen/models/booking_accept_model.dart';
import 'package:hopper/Presentation/DriverScreen/models/get_todays_activity_models.dart';
import '../screens/SharedBooking/Screens/picking_shared_screens.dart';
import '../screens/driver_main_screen.dart';
import '../screens/picking_customer_screen.dart';
import '../screens/ride_stats_screen.dart';
import '../screens/verify_rider_screen.dart';

class DriverStatusController extends GetxController {
  var isOnline = false.obs;
  RxBool isLoading = false.obs;
  var serviceType = ''.obs;
  final RxBool isStopNewRequests = false.obs;
  final RxString arrivedLoadingBookingId = ''.obs;
  final socketService = SocketService();
  Rxn<TodayActivityData> todayStatusData = Rxn<TodayActivityData>();
  Rxn<WeeklyActivityData> weeklyStatusData = Rxn<WeeklyActivityData>();
  Rxn<ParcelBookingData> parcelBookingData = Rxn<ParcelBookingData>();
  ApiDataSource apiDataSource = ApiDataSource();

  final tripDistanceInMeters = 0.0.obs;
  final tripDurationInMin = 0.obs;

  final RxString paymentType = ''.obs;
  final RxString paymentStatus = ''.obs;

  final pickupDurationInMin = 0.0.obs;
  final pickupDistanceInMeters = 0.0.obs;
  var dropDurationInMin = 0.0.obs;
  var dropDistanceInMeters = 0.0.obs;

  @override
  void onInit() {
    super.onInit();
    todayActivity();
    weeklyChallenges();
    todayPackageActivity();
  }

  String get normalizedServiceType => serviceType.value.trim();
  bool get isCar => normalizedServiceType.toLowerCase() == 'car';
  bool get isBike => normalizedServiceType.toLowerCase() == 'bike';

  String _normalizeServiceType(dynamic raw) {
    final v = (raw ?? '').toString().trim();
    if (v.isEmpty) return '';
    final lower = v.toLowerCase();
    if (lower == 'car') return 'Car';
    if (lower == 'bike') return 'Bike';
    return v;
  }


  void setServiceTypeFrom(dynamic raw) {
    final next = _normalizeServiceType(raw);
    if (next.isEmpty) return;
    if (serviceType.value == next) return;
    serviceType.value = next;
  }
  void toggleStatus() {
    isOnline.value = !isOnline.value;
  }

  // ðŸ”¹ booking accept
  Future<String?> bookingAccept(
    BuildContext context, {
    required String bookingId,
    required String status,
    required String pickupLocationAddress,
    required String dropLocationAddress,
    required LatLng pickupLocation,
    required LatLng driverLocation,
    bool navigateToPickup = true,
  }) async {
    isLoading.value = true;
    try {
      final results = await apiDataSource.bookingAccept(
        bookingId: bookingId,
        status: status,
      );

      return results.fold(
        (failure) {
          CustomSnackBar.showError(failure.message);
          isLoading.value = false;
          return '';
        },
        (response) {
          Get.find<DriverAnalyticsController>().trackAccept();
          final serverBookingId = response.data?.bookingId;
          final resolvedBookingId =
              serverBookingId != null &&
                      serverBookingId.trim().isNotEmpty &&
                      serverBookingId.trim().toLowerCase() != 'null'
                  ? serverBookingId
                  : bookingId;
          final bookingData = {
            'bookingId': resolvedBookingId,
            'userId': response.data?.driverId,
            'userType': 'driver',
          };

          CommonLogger.log.i("ðŸ“¤ Join booking data: $bookingData");

          if (socketService.connected) {
            socketService.emit('join-booking', bookingData);
            CommonLogger.log.i(
              "âœ… Socket already connected, emitted join-booking",
            );
          } else {
            socketService.onConnect(() {
              CommonLogger.log.i("âœ… Socket connected, emitting join-booking");
              socketService.emit('join-booking', bookingData);
            });
          }

          CommonLogger.log.i(response.data);

          if (navigateToPickup) {
            if (resolvedBookingId.trim().isEmpty ||
                resolvedBookingId.trim().toLowerCase() == 'null') {
              CustomSnackBar.showError('Booking id missing. Please retry.');
              isLoading.value = false;
              return '';
            }
            Get.to(
              () => PickingCustomerScreen(
                pickupLocation: pickupLocation,
                driverLocation: driverLocation,
                bookingId: resolvedBookingId,
                pickupLocationAddress: pickupLocationAddress,
                dropLocationAddress: dropLocationAddress,
              ),
            );
            // Get.to(
            //   () => PickingCustomerSharedScreen(
            //     pickupLocation: pickupLocation,
            //     driverLocation: driverLocation,
            //     bookingId: bookingId,
            //     pickupLocationAddress: pickupLocationAddress,
            //     dropLocationAddress: dropLocationAddress,
            //   ),
            // );
          } else {
            CommonLogger.log.i(
              "ðŸš— [SHARED] bookingAccept called with navigateToPickup = false â†’ staying on current screen",
            );
          }

          isLoading.value = false;
          return ' ';
        },
      );
    } catch (e) {
      isLoading.value = false;
      return ' ';
    }
  }

  // ðŸ”¹ booking accept
  Future<String?> bookingAcceptForSharedRide(
    BuildContext context, {
    required String bookingId,
    required String status,
    required String pickupLocationAddress,
    required String dropLocationAddress,
    required LatLng pickupLocation,
    required LatLng driverLocation,
    bool navigateToPickup = true,
  }) async {
    isLoading.value = true;
    try {
      final results = await apiDataSource.bookingAccept(
        bookingId: bookingId,
        status: status,
      );

      return results.fold(
        (failure) {
          CustomSnackBar.showError(failure.message);
          isLoading.value = false;
          return '';
        },
        (response) {
          Get.find<DriverAnalyticsController>().trackAccept();
          final serverBookingId = response.data?.bookingId;
          final resolvedBookingId =
              serverBookingId != null &&
                      serverBookingId.trim().isNotEmpty &&
                      serverBookingId.trim().toLowerCase() != 'null'
                  ? serverBookingId
                  : bookingId;
          final bookingData = {
            'bookingId': resolvedBookingId,
            'userId': response.data?.driverId,
            'userType': 'driver',
          };

          CommonLogger.log.i("ðŸ“¤ Join booking data: $bookingData");

          if (socketService.connected) {
            socketService.emit('join-booking', bookingData);
            CommonLogger.log.i(
              "âœ… Socket already connected, emitted join-booking",
            );
          } else {
            socketService.onConnect(() {
              CommonLogger.log.i("âœ… Socket connected, emitting join-booking");
              socketService.emit('join-booking', bookingData);
            });
          }

          CommonLogger.log.i(response.data);

          if (navigateToPickup) {
            if (resolvedBookingId.trim().isEmpty ||
                resolvedBookingId.trim().toLowerCase() == 'null') {
              CustomSnackBar.showError('Booking id missing. Please retry.');
              isLoading.value = false;
              return '';
            }
            Get.to(
              () => PickingCustomerSharedScreen(
                pickupLocation: pickupLocation,
                driverLocation: driverLocation,
                bookingId: resolvedBookingId,
                pickupLocationAddress: pickupLocationAddress,
                dropLocationAddress: dropLocationAddress,
              ),
            );
          } else {
            CommonLogger.log.i(
              "ðŸš— [SHARED] bookingAccept called with navigateToPickup = false â†’ staying on current screen",
            );
          }

          isLoading.value = false;
          return ' ';
        },
      );
    } catch (e) {
      isLoading.value = false;
      return ' ';
    }
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

      return results.fold(
        (failure) {
          isLoading.value = false;
          CustomSnackBar.showError(failure.message);
          return null;
        },
        (response) {
          isLoading.value = false;
          CustomSnackBar.showSuccess(response.message);
          CommonLogger.log.i(response.message);
          return response.message;
        },
      );
    } catch (e) {
      isLoading.value = false;
      return null;
    }
  }

  // ðŸ”¹ complete ride â€“ used for single ride & shared
  /*
  Future<String?> completeRideRequest(
      BuildContext context, {
        required String bookingId,
        required dynamic Amount,
        bool navigateToCashScreen = true,
        bool isSharedRide = false,
      }) async
  {
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

          if (navigateToCashScreen) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CashCollectedScreen(
                  Amount: Amount,
                  bookingId: bookingId,
                  isSharedRide: isSharedRide,
                ),
              ),
            );
          }

          resultMessage = response.message;
        },
      );

      return resultMessage;
    } catch (e) {
      isLoading.value = false;
      return 'Something went wrong';
    }
  }
*/

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
          CommonLogger.log.i(response.message);
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
    arrivedLoadingBookingId.value = bookingId;

    try {
      final results = await apiDataSource.driverArrived(bookingId: bookingId);

      return results.fold(
        (failure) {
          arrivedLoadingBookingId.value = '';
          return null;
        },
        (response) {
          arrivedLoadingBookingId.value = '';
          final onTime = pickupDurationInMin.value <= 2.0;
          Get.find<DriverAnalyticsController>().trackPickup(onTime: onTime);
          return response;
        },
      );
    } catch (e) {
      arrivedLoadingBookingId.value = '';
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
      return results.fold(
        (failure) {
          isLoading.value = false;
          CustomSnackBar.showError(failure.message);
          return '';
        },
        (response) {
          CommonLogger.log.i(response.data);
          isLoading.value = false;
          CustomSnackBar.showDriverStatus(
            isOnline: status,
            message: response.message,
          );
          return ' ';
        },
      );
    } catch (e) {
      isLoading.value = false;
      return ' ';
    }
  }

  Future<String?> todayActivity() async {
    try {
      final results = await apiDataSource.todayActivity();
      CommonLogger.log.i("API called. Awaiting result...");

      return results.fold(
        (failure) {
          return null;
        },
        (response) {
          CommonLogger.log.i("Success block entered");
          CommonLogger.log.i("Response: ${response.toJson()}");

          todayStatusData.value = response.data;
          CommonLogger.log.i("Assigned to todayStatusData:");
          CommonLogger.log.i(todayStatusData.value.toString());
          return response.toString();
        },
      );
    } catch (e) {
      return ' ';
    }
  }

  Future<void> weeklyChallenges() async {
    try {
      final results = await apiDataSource.weeklyChallenge();
      CommonLogger.log.i("API called. Awaiting result...");

      results.fold(
        (failure) {
          CommonLogger.log.e(" weekly Data : ${failure.message}");
          return null;
        },
        (response) {
          CommonLogger.log.i("Response: ${response.toJson()}");

          weeklyStatusData.value = response.data;
          CommonLogger.log.i("Assigned to weekly status:");
          CommonLogger.log.i(weeklyStatusData.value.toString());
          return response;
        },
      );
    } catch (e) {
      return;
    }
  }

  Future<String?> todayPackageActivity() async {
    try {
      final results = await apiDataSource.todayPackageActivity();
      CommonLogger.log.i("API called. Awaiting result...");

      results.fold(
        (failure) {
          CommonLogger.log.e(" weekly Data : ${failure.message}");
          return null;
        },
        (response) {
          CommonLogger.log.i("Response: ${response.toJson()}");

          parcelBookingData.value = response.data;
          CommonLogger.log.i("Assigned to weekly status:");
          CommonLogger.log.i(weeklyStatusData.value.toString());
          return response;
        },
      );
    } catch (e) {
      return ' ';
    }

    return '';
  }

  Future<String?> cancelBooking(
    BuildContext context, {
    required String reason,
    required String bookingId,
    bool silent = true,
    bool navigate = true,
  }) async {
    String? msg;

    try {
      isLoading.value = true;

      final results = await apiDataSource.cancelBooking(
        reason: reason,
        bookingId: bookingId,
      );

      results.fold(
        (failure) {
          msg = failure.message;
          CommonLogger.log.e("cancelBooking failure: ${failure.message}");
        },
        (response) {
          msg = response.message;
          CommonLogger.log.i("cancelBooking success: ${response.message}");
          Get.find<DriverAnalyticsController>().trackCancel(
            bookingId: bookingId,
          );
        },
      );
    } catch (e) {
      CommonLogger.log.e("cancelBooking exception: $e");
      msg = "Something went wrong";
    } finally {
      isLoading.value = false;
    }

    // show snackbar only if needed
    if (!silent && (msg ?? '').isNotEmpty) {
      CustomSnackBar.showSuccess(msg!);
    }

    if (navigate) {
      try {
        if (Get.isBottomSheetOpen == true) {
          Get.back();
        } else if (Get.isDialogOpen == true) {
          Get.back();
        }
      } catch (_) {}

      Future.delayed(const Duration(milliseconds: 80), () {
        Get.offAll(() => const DriverMainScreen());
      });
    }

    return msg;
  }

  /*
  Future<String?> cancelBooking(
    BuildContext context, {
    required String reason,
    required String bookingId,
    bool silent = true, // âœ… default true (avoid ticker crash)
    bool navigate = true, // âœ… default true
  }) async
  {
    try {
      isLoading.value = true;

      final results = await apiDataSource.cancelBooking(
        reason: reason,
        bookingId: bookingId,
      );

      String? msg;

      results.fold(
        (failure) {
          msg = failure.message;
          CommonLogger.log.e("failure: ${failure.message}");
        },
        (response) {
          msg = response.message;
          CommonLogger.log.i("Response: ${response.message}");
        },
      );

      isLoading.value = false;

      // âœ… show snackbar only if NOT navigating away
      if (!silent && !navigate && (msg ?? '').isNotEmpty) {
        CustomSnackBar.showSuccess(msg!);
      }

      if (navigate) {
        // âœ… close overlays safely
        try {
          Get.closeAllSnackbars();
        } catch (e) {
          CommonLogger.log.w(e);
        }
        try {
          if (Get.isBottomSheetOpen == true) Get.back();
        } catch (e) {CommonLogger.log.w(e);}
        try {
          if (Get.isDialogOpen == true) Get.back();
        } catch (e) {
          CommonLogger.log.w(e);
        }

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (Get.currentRoute == '/DriverMainScreen') return;
          Get.offAll(() => const DriverMainScreen());
        });
      }

      return msg;
    } catch (e) {
      isLoading.value = false;
      return '';
    }
  }
*/

  Future<String?> stopNewRideRequest({
    required bool stop,
    required BuildContext context,
  }) async {
    try {
      isLoading.value = true;

      final results = await apiDataSource.stopNewRideRequest(stop: stop);

      return results.fold(
        (failure) {
          isLoading.value = false;
          CustomSnackBar.showError(failure.message);
          CommonLogger.log.e("failure: ${failure.message}");
          return '';
        },
        (response) {
          CommonLogger.log.i("Response: ${response.message}");
          CustomSnackBar.showSuccess(response.message);

          if (response.stop == true) {
            isStopNewRequests.value = true;
          }

          CommonLogger.log.i("stop flag: ${response.stop}");
          isLoading.value = false;
          return '';
        },
      );
    } catch (e) {
      isLoading.value = false;
      return '';
    }
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
          serviceType.value = _normalizeServiceType(response.data.serviceType);
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
          CustomSnackBar.showError(failure.message);
          isLoading.value = false;
          CommonLogger.log.e("failure: ${failure.message}");
        },
        (response) {
          isLoading.value = false;
          CommonLogger.log.i(response.toJson());
          paymentStatus.value = 'PAID';

          if (onSuccess != null) onSuccess();
        },
      );
    } catch (e) {
      isLoading.value = false;
      CommonLogger.log.i(e);
    }
  }

  Future<String?> completeRideRequest(
    BuildContext context, {
    required String bookingId,
    required dynamic Amount,
    bool navigateToCashScreen = true,
    bool isSharedRide = false,
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
          resultMessage = response.message;
          Get.find<DriverAnalyticsController>().trackEarning(Amount ?? 0);
          Get.find<DriverAnalyticsController>().trackComplete();

          // âœ… Shared ride -> DON'T navigate from controller
          if (isSharedRide) return;

          // âœ… Single ride -> go to cash screen if needed
          // if (navigateToCashScreen) {
          //   Navigator.push(
          //     context,
          //     MaterialPageRoute(
          //       builder:
          //           (_) => CashCollectedScreen(
          //             Amount: Amount,
          //             bookingId: bookingId,
          //             isSharedRide: false,
          //           ),
          //     ),
          //   );
          // }
        },
      );

      return resultMessage;
    } catch (e) {
      isLoading.value = false;
      return 'Something went wrong';
    }
  }

  Future<void> driverRatingToCustomer({
    required String bookingId,
    required int rating,
    required BuildContext context,
    bool goToMainOnSuccess = true,
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
        },
        (response) {
          isLoading.value = false;

          if (goToMainOnSuccess) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => DriverMainScreen()),
            );
          }

          CommonLogger.log.i(response.toJson());
        },
      );
    } catch (e) {
      isLoading.value = false;
      CommonLogger.log.i(e);
    }
  }
}






