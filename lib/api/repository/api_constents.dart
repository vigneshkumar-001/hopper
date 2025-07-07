class ApiConstents {
  static String baseUrl =
      'https://hoppr-backend-3d2b7f783917.herokuapp.com/api';
  static String loginApi = '$baseUrl/users/signUp';
  static String verifyOtp = '$baseUrl/users/verify-otp';
  static String verifyOtpProtect = '$baseUrl/users/verify-otp-protect';
  static String resendOTP = '$baseUrl/users/resendOTP';
  static String updateUserDetails = '$baseUrl/users/updateUserDetails';
  static String states = '$baseUrl/users/states';
  static String driverResponse = '$baseUrl/users/driver-response';
  static String getUserDetails = '$baseUrl/users/getUserDetailsById';
  static String userImageUpload = 'https://adrox.ai/api/image-save';


  // https://hoppr-backend-3d2b7f783917.herokuapp.com/api/users/districts?state=$state

}
