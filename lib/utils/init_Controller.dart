import 'package:get/get.dart';
import '../Presentation/Authentication/controller/authController.dart';
import '../Presentation/Authentication/controller/otp_controller.dart';
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

Future<void> initController() async {
  Get.lazyPut(() => AuthController());
  // Get.lazyPut(() => OtpController());
  Get.lazyPut(() => OtpController(), fenix: true);

  Get.lazyPut(() => BasicInfoController());
  Get.lazyPut<DriverAddressController>(
    () => DriverAddressController(),
    fenix: true,
  );
  Get.lazyPut(() => ChooseServiceController());
  Get.lazyPut(() => UserProfileController());
  Get.lazyPut(() => CarOwnerShipController());
  Get.lazyPut(() => NinController());
  Get.lazyPut(() => DriverLicenseController());
  Get.lazyPut(() => VehicleDetailsController());
  Get.lazyPut(() => ExteriorImageController());
  Get.lazyPut(() => InteriorImageController());
  Get.lazyPut(() => StateListController());
  Get.lazyPut(() => GuidelinesController());
}
