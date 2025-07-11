class ApiConstents {
  static String baseUrl =
      'https://hoppr-backend-3d2b7f783917.herokuapp.com/api';
  static String baseUrl2 =
      'https://hoppr-face-two-dbe557472d7f.herokuapp.com/api';
  static String loginApi = '$baseUrl/users/signUp';
  static String verifyOtp = '$baseUrl/users/verify-otp';
  static String verifyOtpProtect = '$baseUrl/users/verify-otp-protect';
  static String resendOTP = '$baseUrl/users/resendOTP';
  static String updateUserDetails = '$baseUrl/users/updateUserDetails';
  static String states = '$baseUrl/users/states';
  static String driverResponse = '$baseUrl/users/driver-response';
  static String getUserDetails = '$baseUrl/users/getUserDetailsById';
  static String generateOtp = '$baseUrl2/users/generate-otp';
  static String  rideVerifyOtp = '$baseUrl2/users/ride-verify-otp';
  static String  driverOnlineStatus = '$baseUrl2/users/toggle-status/683fed0a00aa693559289fbc';
  static String  todayStatus = '$baseUrl2/users/today/683fed0a00aa693559289fbc';
  static String  weeklyChallenge = '$baseUrl2/users/weekly-challenge/683fed0a00aa693559289fbc';
  static String  cancelBooking = '$baseUrl2/users/cancel-booking/574636';
  static String userImageUpload = 'https://adrox.ai/api/image-save';


  // https://hoppr-backend-3d2b7f783917.herokuapp.com/api/users/districts?state=$state

}
