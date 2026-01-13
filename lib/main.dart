import 'dart:async';
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

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ init GetX controllers first (your code)
  await initController();

  // ✅ Firebase init must be before messaging handlers
  await Firebase.initializeApp();

  // ✅ Register BG handler early
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // ✅ UI first (prevents black screen even if FCM fails)
  runApp(const MyApp());

  // ✅ Safe style set (non-blocking)
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.white,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.black,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  // ✅ Initialize notifications + token fetch AFTER UI starts
  unawaited(_initFcmSafely());
}

Future<void> _initFcmSafely() async {
  try {
    final firebaseService = FirebaseService();
    await firebaseService.initializeFirebase();
    await firebaseService.fetchFCMTokenIfNeeded();

    firebaseService.listenToMessages(
      onMessage: (msg) {
        CommonLogger.log.i('📩 [FG] ${msg.messageId}');
        firebaseService.showNotification(msg);
      },
      onMessageOpenedApp: (msg) {
        CommonLogger.log.i('📬 [OPENED] ${msg.messageId}');
      },
    );

    // ✅ If you really want to log token, use your cached token safely:
    CommonLogger.log.i("🔥 FCM Token (cached): ${firebaseService.fcmToken}");
  } catch (e, st) {
    // ✅ Never crash app
    CommonLogger.log.e("❌ FCM init failed: $e");
    CommonLogger.log.e("STACK: $st");
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(360, 690),
      builder:
          (context, child) => GetMaterialApp(
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
// import 'package:flutter/services.dart';
//
// import 'Core/Constants/log.dart';
// import 'Core/Firebase/firebase_service.dart';
// import 'splash_screen.dart';
// import 'utils/init_Controller.dart';
//
// void main() async {
//   WidgetsFlutterBinding.ensureInitialized();
//   await initController();
//
//   await Firebase.initializeApp();
//
//   final firebaseService = FirebaseService();
//   await firebaseService.initializeFirebase();
//   await firebaseService.fetchFCMTokenIfNeeded(); // ensures token is ready
//   final token = await FirebaseMessaging.instance.getToken();
//   CommonLogger.log.i("🔥 FCM Token: $token");
//
//   firebaseService.listenToMessages(
//     onMessage: (msg) {
//       CommonLogger.log.i('📩 [FG] ${msg.messageId}');
//       firebaseService.showNotification(msg);
//     },
//     onMessageOpenedApp: (msg) {
//       CommonLogger.log.i('📬 [OPENED] ${msg.messageId}');
//     },
//   );
//
//   SystemChrome.setSystemUIOverlayStyle(
//     const SystemUiOverlayStyle(
//       statusBarColor: Colors.white,
//       statusBarIconBrightness: Brightness.dark,
//       systemNavigationBarColor: Colors.black,
//       systemNavigationBarIconBrightness: Brightness.dark,
//     ),
//   );
//
//   runApp(const MyApp());
// }
//
// class MyApp extends StatelessWidget {
//   const MyApp({super.key});
//
//   @override
//   Widget build(BuildContext context) {
//     return ScreenUtilInit(
//       designSize: const Size(360, 690),
//       builder: (context, child) => GetMaterialApp(
//         theme: ThemeData(scaffoldBackgroundColor: Colors.white),
//         debugShowCheckedModeBanner: false,
//         home: const SplashScreen(),
//       ),
//     );
//   }
// }
