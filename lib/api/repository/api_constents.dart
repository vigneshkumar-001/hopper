import 'package:get/get.dart';

import 'api_config_controller.dart';

class ApiConstents {
  // static String baseUrl2 =
  //     'https://hoppr-backend-3d2b7f783917.herokuapp.com/api';
  // // static String singleRideSocket = 'https://q29l3cr9-4000.inc1.devtunnels.ms';
  // static String singleRideSocket =
  //     'https://hoppr-backend-3d2b7f783917.herokuapp.com/api';

  static String sharedRideSocket = const String.fromEnvironment(
    'HOPPR_SHARED_SOCKET_URL',
    defaultValue: 'https://hoppr-share-ride-85bbca49cbeb.herokuapp.com/api',
    // defaultValue: 'https://q29l3cr9-6000.inc1.devtunnels.ms',
  );
  static String googleMapApiKey = const String.fromEnvironment(
    'GOOGLE_MAPS_API_KEY',
    defaultValue: 'AIzaSyCvU6g43_aujUMDTTHpCtg1wkHszDhdC28',
  );
  // static String baseUrl12 =
  //     'https://hoppr-face-two-dbe557472d7f.herokuapp.com/api';

  /// ✅ dynamic base url from GetX
  static String get baseUrl {
    // Avoid runtime crash if controller wasn't registered yet (can happen on cold start
    // when some controllers call APIs from `onInit()` before `initController()` runs).
    final ApiConfigController cfg =
        Get.isRegistered<ApiConfigController>()
            ? Get.find<ApiConfigController>()
            : Get.put(ApiConfigController(), permanent: true);
    return cfg.baseUrl;
  }

  /// ✅ helper
  static String _u(String path) => '$baseUrl$path';

  /// ✅ helper for non-`/api` endpoints
  static String get rootBaseUrl {
    // Our `baseUrl` is like `https://host.tld/api`. Some endpoints live outside `/api`.
    return baseUrl.replaceFirst(RegExp(r'/api/?$'), '');
  }

  // ✅ Now keep same variable names but convert to getters
  static String get chatHistory => _u('/customer/chat-history');
  static String get notification => _u('/users/notifications');
  static String get sharedBookingStatus =>
      _u('/shared/customer/shared-booking/status');
  static String get loginApi => _u('/users/signUp');
  static String get driverWalletHistory => _u('/users/driver-wallet-history');
  static String get verifyOtp => _u('/users/verify-otp');
  static String get verifyOtpProtect => _u('/users/verify-otp-protect');
  static String get resendOTP => _u('/users/resendOTP');
  static String get updateUserDetails => _u('/users/updateUserDetails');
  static String get getUserDetailsById => _u('/users/getUserDetailsById');
  static String get logout => _u('/users/logout');
  static String get states => _u('/users/states');
  static String get driverResponse => _u('/users/driver-response');
  static String get getUserDetails => _u('/users/getUserDetailsById');
  static String get generateOtp => _u('/users/generate-otp');
  static String get rideVerifyOtp => _u('/users/ride-verify-otp');
  static String get todayParcel => _u('/users/today-parcel');
  static String get rideHistory => _u('/users/ride-history');
  static String get addToWallet => _u('/users/add-to-wallet');
  static String get withdrawRequest => _u('/users/withdraw/request');
  static String get fcmToken => _u('/users/update-fcm-token');
  static String get checkPaymentType => _u('/users/check-payment-type');
  static String get cashCollectedStatus => _u('/cashonhand/byuser/orders');
  static String get addToWalletResponse => _u('/users/add-to-wallet-reponse');
  static String get driverAccept => _u('/users/driver-response');
  static String get stopNewRequests => _u('/users/stopNewRequests');
  static String get driverStatus => _u('/users/status');
  static String get driverActiveBooking => _u('/users/active-booking');
  static String get sharedDriverActiveBooking => _u('/users/active-booking');
  // static String get sharedDriverActiveBooking => _u('/shared/driver/active-booking');

  static String userImageUpload =
     _u('/upload/image');

  // Support
  static String get supportCustomerTickets => _u('/support/driver/tickets');
  static String get supportCommonDetails => _u('/support/common-details');
  static String get supportMyTickets => _u('/support/my/tickets');

  // ✅ These already functions - just use _u()
  static String driverOnlineStatus({required String driverId}) {
    return _u('/users/toggle-status');
  }

  static String driverRating({required String bookingId}) {
    return _u('/users/rate-customer/$bookingId');
  }

  static String cancelBooking({required String bookingId}) {
    return _u('/users/cancel-booking/$bookingId');
  }

  static String todayStatus() => _u('/users/today');

  static String weeklyChallenge() => _u('/users/weekly-challenge');

  static String completeRide({required String booking}) {
    return _u('/users/ride-complete/$booking');
  }

  static String driverArrived({required String booking}) {
    return _u('/users/driver-arrived/$booking');
  }

  static String getCityList({required String state}) {
    return _u('/users/districts?state=$state');
  }

  static String getBrandList({required String selectedService}) {
    return _u('/users/brands?type=$selectedService');
  }

  static String getModel({
    required String brand,
    required String selectedService,
  }) {
    return _u('/users/models/$brand?type=$selectedService');
  }

  static String getYear({
    required String brand,
    required String selectedService,
    required String model,
  }) {
    return _u('/users/details/$brand/$model?type=$selectedService');
  }

  static String guideLines({required String type}) {
    return _u('/users/guidelines/$type');
  }
}

// class ApiConstents {
//   static String baseUrl2 =
//       'https://hoppr-backend-3d2b7f783917.herokuapp.com/api';
//   // static String googleMapApiKey = 'AIzaSyA5wtbZ30XrpN1WE9-ZM1CYbY0g31NlT_A';
//   static String googleMapApiKey = 'AIzaSyCvU6g43_aujUMDTTHpCtg1wkHszDhdC28';
//   static String baseUrl12 =
//       'https://hoppr-face-two-dbe557472d7f.herokuapp.com/api';
//
//   static String baseUrl1 = 'https://q29l3cr9-3000.inc1.devtunnels.ms';
//   static String baseUrl = 'https://q29l3cr9-3000.inc1.devtunnels.ms/api';
//   static String chatHistory = '$baseUrl/customer/chat-history';
//   static String notification = '$baseUrl/users/notifications';
//   static String loginApi = '$baseUrl/users/signUp';
//   static String driverWalletHistory = '$baseUrl/users/driver-wallet-history';
//   static String verifyOtp = '$baseUrl/users/verify-otp';
//   static String verifyOtpProtect = '$baseUrl/users/verify-otp-protect';
//   static String resendOTP = '$baseUrl/users/resendOTP';
//   static String updateUserDetails = '$baseUrl/users/updateUserDetails';
//   static String getUserDetailsById = '$baseUrl/users/getUserDetailsById';
//   static String states = '$baseUrl/users/states';
//   static String driverResponse = '$baseUrl/users/driver-response';
//   static String getUserDetails = '$baseUrl/users/getUserDetailsById';
//   static String generateOtp = '$baseUrl/users/generate-otp';
//   static String rideVerifyOtp = '$baseUrl/users/ride-verify-otp';
//   static String todayParcel = '$baseUrl/users/today-parcel';
//   static String rideHistory = '$baseUrl/users/ride-history';
//   static String addToWallet = '$baseUrl/users/add-to-wallet';
//   static String fcmToken = '$baseUrl/users/update-fcm-token';
//   static String checkPaymentType = '$baseUrl/users/check-payment-type';
//   static String cashCollectedStatus = '$baseUrl/cashonhand/byuser/orders';
//   static String addToWalletResponse = '$baseUrl/users/add-to-wallet-reponse';
//   static String driverAccept = '$baseUrl/users/driver-response';
//   static String stopNewRequests = '$baseUrl/users/stopNewRequests';
//   // static String driverOnlineStatus =
//   //     '$baseUrl2/users/toggle-status/683fed0a00aa693559289fbc';
//
//   static String driverStatus = '$baseUrl/users/status';
//   static String userImageUpload =
//       'https://next.fenizotechnologies.com/Adrox/api/image-save';
//   static String driverOnlineStatus({required String driverId}) {
//     return '$baseUrl/users/toggle-status';
//   }
//
//   static String driverRating({required String bookingId}) {
//     return '$baseUrl/users/rate-customer/$bookingId';
//   }
//
//   static String cancelBooking({required String bookingId}) {
//     return '$baseUrl/users/cancel-booking/$bookingId';
//   }
//
//   static String todayStatus() {
//     return '$baseUrl/users/today';
//   }
//
//   static String weeklyChallenge() {
//     return '$baseUrl/users/weekly-challenge';
//   }
//
//   static String completeRide({required String booking}) {
//     return '$baseUrl/users/ride-complete/$booking';
//   }
//
//   static String driverArrived({required String booking}) {
//     return '$baseUrl/users/driver-arrived/$booking';
//   }
//
//   static String getCityList({required String state}) {
//     return '$baseUrl/users/districts?state=$state';
//   }
//
//   static String getBrandList({required String selectedService}) {
//     return '$baseUrl/users/brands?type=$selectedService';
//   }
//
//   static String getModel({
//     required String brand,
//     required String selectedService,
//   }) {
//     return '$baseUrl/users/models/$brand?type=$selectedService';
//   }
//
//   static String getYear({
//     required String brand,
//     required String selectedService,
//     required String model,
//   }) {
//     return '$baseUrl/users/details/$brand/$model?type=$selectedService';
//   }
//
//   static String guideLines({required String type}) {
//     return '$baseUrl/users/guidelines/$type';
//   }
//
//   // https://hoppr-backend-3d2b7f783917.herokuapp.com/api/users/districts?state=$state
// }
