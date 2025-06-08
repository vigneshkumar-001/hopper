import '../Presentation/Authentication/controller/authController.dart';
import 'package:get/get.dart';


void clearState()async{
  AuthController authController = Get.find();
  authController.clearState();
}