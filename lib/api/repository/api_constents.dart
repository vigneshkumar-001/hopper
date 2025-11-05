class ApiConstents {
  static String baseUrl2 =
      'https://hoppr-backend-3d2b7f783917.herokuapp.com/api';
  // static String googleMapApiKey = 'AIzaSyA5wtbZ30XrpN1WE9-ZM1CYbY0g31NlT_A';
  static String googleMapApiKey = 'AIzaSyCvU6g43_aujUMDTTHpCtg1wkHszDhdC28';
  static String baseUrl =
      'https://hoppr-face-two-dbe557472d7f.herokuapp.com/api';

  static String baseUrl1 = 'https://4wsg7ghz-3000.inc1.devtunnels.ms/api';
  static String chatHistory = '$baseUrl/customer/chat-history';
  static String notification = '$baseUrl/users/notifications';
  static String loginApi = '$baseUrl/users/signUp';
  static String driverWalletHistory = '$baseUrl/users/driver-wallet-history';
  static String verifyOtp = '$baseUrl/users/verify-otp';
  static String verifyOtpProtect = '$baseUrl/users/verify-otp-protect';
  static String resendOTP = '$baseUrl/users/resendOTP';
  static String updateUserDetails = '$baseUrl/users/updateUserDetails';
  static String getUserDetailsById = '$baseUrl/users/getUserDetailsById';
  static String states = '$baseUrl/users/states';
  static String driverResponse = '$baseUrl/users/driver-response';
  static String getUserDetails = '$baseUrl/users/getUserDetailsById';
  static String generateOtp = '$baseUrl/users/generate-otp';
  static String rideVerifyOtp = '$baseUrl/users/ride-verify-otp';
  static String todayParcel = '$baseUrl/users/today-parcel';
  static String rideHistory = '$baseUrl/users/ride-history';
  static String addToWallet = '$baseUrl/users/add-to-wallet';
  static String fcmToken = '$baseUrl/users/update-fcm-token';
  static String checkPaymentType = '$baseUrl/users/check-payment-type';
  static String cashCollectedStatus = '$baseUrl/cashonhand/byuser/orders';
  static String addToWalletResponse = '$baseUrl/users/add-to-wallet-reponse';
  // static String driverOnlineStatus =
  //     '$baseUrl2/users/toggle-status/683fed0a00aa693559289fbc';

  static String driverStatus = '$baseUrl/users/status';
  static String userImageUpload =
      'https://next.fenizotechnologies.com/Adrox/api/image-save';
  static String driverOnlineStatus({required String driverId}) {
    return '$baseUrl/users/toggle-status';
  }

  static String driverRating({required String bookingId}) {
    return '$baseUrl/users/rate-customer/$bookingId';
  }

  static String cancelBooking({required String bookingId}) {
    return '$baseUrl/users/cancel-booking/$bookingId';
  }

  static String todayStatus() {
    return '$baseUrl/users/today';
  }

  static String weeklyChallenge() {
    return '$baseUrl/users/weekly-challenge';
  }

  static String completeRide({required String booking}) {
    return '$baseUrl/users/ride-complete/$booking';
  }

  static String driverArrived({required String booking}) {
    return '$baseUrl/users/driver-arrived/$booking';
  }

  // https://hoppr-backend-3d2b7f783917.herokuapp.com/api/users/districts?state=$state
}
