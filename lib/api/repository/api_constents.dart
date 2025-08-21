class ApiConstents {
  static String baseUrl2 =
      'https://hoppr-backend-3d2b7f783917.herokuapp.com/api';
  static String baseUrl =
      'https://hoppr-face-two-dbe557472d7f.herokuapp.com/api';
  static String loginApi = '$baseUrl/users/signUp';
  static String verifyOtp = '$baseUrl/users/verify-otp';
  static String verifyOtpProtect = '$baseUrl/users/verify-otp-protect';
  static String resendOTP = '$baseUrl/users/resendOTP';
  static String updateUserDetails = '$baseUrl/users/updateUserDetails';
  static String states = '$baseUrl/users/states';
  static String driverResponse = '$baseUrl/users/driver-response';
  static String getUserDetails = '$baseUrl/users/getUserDetailsById';
  static String generateOtp = '$baseUrl/users/generate-otp';
  static String rideVerifyOtp = '$baseUrl/users/ride-verify-otp';
  // static String driverOnlineStatus =
  //     '$baseUrl2/users/toggle-status/683fed0a00aa693559289fbc';

  static String cancelBooking = '$baseUrl/users/cancel-booking/574636';
  static String driverStatus = '$baseUrl/users/status';
  static String userImageUpload = 'https://next.fenizotechnologies.com/Adrox/api/image-save';
  static String driverOnlineStatus({required String driverId}) {
    return '$baseUrl/users/toggle-status';
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
