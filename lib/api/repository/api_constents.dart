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
  static String userImageUpload = 'https://adrox.ai/api/image-save';
  static String driverOnlineStatus({required String driverId}) {
    return '$baseUrl/users/toggle-status/$driverId';
  }

  static String todayStatus({required String driverId}) {
    return '$baseUrl/users/today/$driverId';
  }

  static String weeklyChallenge({required String driverId}) {
    return '$baseUrl/users/weekly-challenge/$driverId';
  }

  static String completeRide({required String booking}) {
    return '$baseUrl/users/ride-complete/$booking';
  }

  // https://hoppr-backend-3d2b7f783917.herokuapp.com/api/users/districts?state=$state
}
