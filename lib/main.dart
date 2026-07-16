import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:flutter/services.dart';

import 'Core/Constants/log.dart';
import 'Core/Firebase/firebase_service.dart';
import 'Core/Utility/snackbar.dart';
import 'Core/Services/driver_background_location_service.dart';
import 'Core/Services/logger_service.dart';
import 'Presentation/DriverScreen/controller/driver_main_controller.dart';
import 'splash_screen.dart';
import 'utils/init_Controller.dart';
import 'utils/map/route_info.dart';
import 'api/repository/api_constents.dart';

Future<void> main() async {
  // ZONE FIX: ensureInitialized() and runApp() MUST run in the same zone, otherwise Flutter
  // reports a "Zone mismatch" (logged as a crash by our handler). So the WHOLE startup —
  // including ensureInitialized — runs inside one runZonedGuarded. loggerService is declared
  // out here (nullable) so the zone's error handler below can still reach it.
  LoggerService? loggerService;
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // ✅ init GetX controllers first (your code)
    await initController();

    DirectionsConfig.apiKey = ApiConstents.googleMapApiKey;

    // ✅ Configure (do not start) background tracking service
    await DriverBackgroundLocationService.initialize();

    // ✅ Initialize logging system
    loggerService = LoggerService();
    await loggerService!.logDeviceInfo();

    // ✅ Setup error/crash handling
    FlutterError.onError = (details) {
      loggerService?.logAppCrash(
        details.exceptionAsString(),
        details.stack ?? StackTrace.current,
      );
    };

    // ✅ Firebase init should never crash the app
    var firebaseReady = false;
    try {
      await Firebase.initializeApp();
      firebaseReady = true;
    } catch (e, st) {
      CommonLogger.log.e("❌ Firebase.initializeApp failed (app continues): $e");
      CommonLogger.log.e("STACK: $st");
    }

    // ✅ Register BG handler early (only if Firebase is ready)
    if (firebaseReady) {
      try {
        FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      } catch (e) {
        CommonLogger.log.e("❌ FirebaseMessaging BG handler register failed: $e");
      }
    }

    // ✅ UI (same zone as ensureInitialized — no zone mismatch)
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
  }, (error, stack) {
    loggerService?.logAppCrash(error.toString(), stack);
  });
}

Future<void> _initFcmSafely() async {
  try {
    // If Firebase core failed, skip FCM to avoid crashes.
    if (Firebase.apps.isEmpty) {
      CommonLogger.log.w('⚠️ Firebase not initialized – skipping FCM init');
      return;
    }

    final firebaseService = FirebaseService();
    await firebaseService.initializeFirebase();
    await firebaseService.fetchFCMTokenIfNeeded();

    firebaseService.listenToMessages(
      onMessage: (msg) {
        _logFcmMessage('FG', msg);
        unawaited(firebaseService.showNotification(msg));
        if (FirebaseService.isBookingRequestNotification(msg.data)) {
          if (Get.isRegistered<DriverMainController>()) {
            unawaited(
              Get.find<DriverMainController>().handleBookingRequestNotification(
                msg.data,
                source: 'fcm_foreground',
              ),
            );
          } else {
            unawaited(
              FirebaseService.queueBookingRequestNotification(msg.data),
            );
          }
        }
      },
      onMessageOpenedApp: (msg) {
        _logFcmMessage('OPENED', msg);
      },
      onBookingRequestOpened: (data) {
        if (Get.isRegistered<DriverMainController>()) {
          unawaited(
            Get.find<DriverMainController>()
                .handleBookingRequestNotification(
                  data,
                  source: 'notification_tap',
                  payloadAlreadyQueued: true,
                ),
          );
        }
      },
    );

    if (Get.isRegistered<DriverMainController>()) {
      unawaited(
        Get.find<DriverMainController>()
            .restorePendingBookingRequestFromNotification(force: true),
      );
    }

    CommonLogger.log.d("FCM initialized");
  } catch (e, st) {
    // ✅ Never crash app
    CommonLogger.log.e("❌ FCM init failed: $e");
    CommonLogger.log.e("STACK: $st");
  }
}

void _logFcmMessage(String phase, RemoteMessage msg) {
  CommonLogger.log.i(
    '📩 [$phase] messageId=${msg.messageId} data=${msg.data} '
    'title=${msg.notification?.title} body=${msg.notification?.body}',
  );
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
            // CRASH FIX: dismiss the custom top-snack OverlayEntry on any route
            // removal/replacement (Get.offAll etc.) — a live entry surviving a
            // navigator teardown crashes with "Duplicate GlobalKeys detected".
            navigatorObservers: [SnackSafeNavigatorObserver()],
            builder: (context, child) {
              final mq = MediaQuery.of(context);
              return MediaQuery(
                data: mq.copyWith(boldText: false),
                child: child ?? const SizedBox.shrink(),
              );
            },
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
