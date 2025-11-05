import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:flutter/services.dart';

import 'Core/Constants/log.dart';
import 'Core/Firebase/firebase_service.dart';
import 'splash_screen.dart';
import 'utils/init_Controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initController();

  await Firebase.initializeApp();

  final firebaseService = FirebaseService();
  await firebaseService.initializeFirebase();
  await firebaseService.fetchFCMTokenIfNeeded(); // ensures token is ready
  final token = await FirebaseMessaging.instance.getToken();
  CommonLogger.log.i("🔥 FCM Token: $token");

  firebaseService.listenToMessages(
    onMessage: (msg) {
      CommonLogger.log.i('📩 [FG] ${msg.messageId}');
      firebaseService.showNotification(msg);
    },
    onMessageOpenedApp: (msg) {
      CommonLogger.log.i('📬 [OPENED] ${msg.messageId}');
    },
  );

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.white,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.black,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(360, 690),
      builder: (context, child) => GetMaterialApp(
        theme: ThemeData(scaffoldBackgroundColor: Colors.white),
        debugShowCheckedModeBanner: false,
        home: const SplashScreen(),
      ),
    );
  }
}


// import 'package:firebase_core/firebase_core.dart';
// import 'package:firebase_messaging/firebase_messaging.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_screenutil/flutter_screenutil.dart';
// import 'package:get/get.dart';
// import 'package:hopper/Core/Constants/log.dart';
//
// import 'Core/Firebase/firebase_service.dart';
// import 'Presentation/DriverScreen/screens/background_service.dart';
// import 'Presentation/DriverScreen/screens/driver_main_screen.dart';
// import 'dummy_screen.dart';
// import 'splash_screen.dart';
// import 'utils/init_Controller.dart';
// import 'package:flutter/services.dart';
//
// void main() async {
//   WidgetsFlutterBinding.ensureInitialized();
//   await initController();
//
//   await Firebase.initializeApp();
//   final firebaseService = FirebaseService();
//   await firebaseService.initializeFirebase();
//   await fetchFCMTokenWithRetry();
//   firebaseService.fetchFCMTokenIfNeeded();
//   firebaseService.listenToMessages(
//     onMessage: (msg) {
//       CommonLogger.log.i('📩 [FG] ${msg.messageId}');
//       firebaseService.showNotification(msg);
//     },
//     onMessageOpenedApp: (msg) {
//       CommonLogger.log.i('📬 [OPENED] ${msg.messageId}');
//     },
//   );
//   SystemChrome.setSystemUIOverlayStyle(
//     const SystemUiOverlayStyle(
//       statusBarColor: Colors.white,
//       statusBarIconBrightness: Brightness.dark,
//       statusBarBrightness: Brightness.dark,
//       systemNavigationBarColor: Colors.black,
//       systemNavigationBarIconBrightness: Brightness.dark,
//     ),
//   );
//   runApp(const MyApp());
// }
//
//
// Future<void> fetchFCMTokenWithRetry({int maxRetries = 5}) async {
//   for (int i = 0; i < maxRetries; i++) {
//     try {
//       await Future.delayed(Duration(seconds: i * 2));
//       final token = await FirebaseMessaging.instance.getToken();
//       if (token != null && token.isNotEmpty) {
//         CommonLogger.log.i("✅ FCM Token: $token");
//         return;
//       }
//     } catch (e) {
//       CommonLogger.log.e(
//         "⚠️ FCM getToken failed (attempt ${i + 1}/$maxRetries): $e",
//       );
//       if (e.toString().contains("SERVICE_NOT_AVAILABLE")) {
//         CommonLogger.log.w("Service temporarily unavailable, retrying...");
//       } else {
//         rethrow;
//       }
//     }
//   }
//   CommonLogger.log.w("❌ FCM token not fetched after $maxRetries attempts");
// }
//
// class MyApp extends StatelessWidget {
//   const MyApp({super.key});
//
//   @override
//   Widget build(BuildContext context) {
//     return ScreenUtilInit(
//       designSize: const Size(360, 690),
//       child: GetMaterialApp(
//         theme: ThemeData(scaffoldBackgroundColor: Colors.white),
//         debugShowCheckedModeBanner: false,
//
//         home: SplashScreen(),
//       ),
//     );
//   }
// }
