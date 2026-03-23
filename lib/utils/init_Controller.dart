import 'package:get/get.dart';
import 'package:hopper/Presentation/Drawer/controller/ride_history_controller.dart';
import 'package:hopper/Presentation/CustomerSupport/controller/customer_support_controller.dart';
import 'package:hopper/Presentation/DriverScreen/screens/SharedBooking/Controller/booking_request_controller.dart';
import 'package:hopper/Presentation/DriverScreen/screens/SharedBooking/Controller/shared_ride_controller.dart';
import '../Presentation/Authentication/controller/authController.dart';
import '../Presentation/Authentication/controller/network_handling_controller.dart';
import '../Presentation/Authentication/controller/otp_controller.dart';
import '../Presentation/Drawer/controller/notification_controller.dart';
import '../Presentation/DriverScreen/controller/driver_status_controller.dart';
import '../Presentation/OnBoarding/controller/basicInfo_controller.dart';
import '../Presentation/OnBoarding/controller/caronwership_controller.dart';
import '../Presentation/OnBoarding/controller/chooseservice_controller.dart';
import '../Presentation/OnBoarding/controller/driverLicense_controller.dart';
import '../Presentation/OnBoarding/controller/driveraddress_controller.dart';
import '../Presentation/OnBoarding/controller/exteriorImage_controller.dart';
import '../Presentation/OnBoarding/controller/guidelines_Controller.dart';
import '../Presentation/OnBoarding/controller/interiorimage_controller.dart';
import '../Presentation/OnBoarding/controller/nin_controller.dart';
import '../Presentation/OnBoarding/controller/stateList_Controller.dart';
import '../Presentation/OnBoarding/controller/userprofile_controller.dart';
import '../Presentation/OnBoarding/controller/vehicledetails_controller.dart';
import '../api/repository/api_config_controller.dart';
import 'map/navigation_assist.dart';

Future<void> initController() async {
  Get.lazyPut(() => NetworkController());
  Get.lazyPut(() => AuthController());
  // Get.lazyPut(() => OtpController());
  Get.lazyPut(() => OtpController(), fenix: true);

  Get.lazyPut(() => BasicInfoController());
  Get.lazyPut<DriverAddressController>(
    () => DriverAddressController(),
    fenix: true,
  );

  Get.lazyPut(() => ChooseServiceController());
  Get.put(SharedRideController(), permanent: true);

  Get.lazyPut(() => UserProfileController());
  Get.lazyPut(() => CarOwnerShipController());
  Get.lazyPut(() => NinController());
  Get.lazyPut(() => DriverLicenseController());
  Get.lazyPut(() => VehicleDetailsController());
  Get.lazyPut(() => ExteriorImageController());
  Get.lazyPut(() => InteriorImageController());
  Get.lazyPut(() => StateListController());
  Get.lazyPut(() => GuidelinesController());
  Get.lazyPut(() => DriverStatusController());
  Get.lazyPut(() => RideHistoryController());
  Get.lazyPut(() => NotificationController());
  Get.lazyPut(() => CustomerSupportController());
  Get.put(BookingRequestController(), permanent: true);

  // Get.lazyPut(() => BookingRequestController(), fenix: true);
  Get.put(ApiConfigController(), permanent: true);
  Get.put(DriverAnalyticsController(), permanent: true);
}
