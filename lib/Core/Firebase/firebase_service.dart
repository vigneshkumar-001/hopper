import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hopper/Core/Constants/log.dart';
import 'package:hopper/Presentation/Authentication/controller/otp_controller.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  CommonLogger.log.i('🔕 [BG] Message received: ${message.messageId}');
}

class FirebaseService {
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();

  // ✅ Important: do NOT force put() at file load time in main init sequence.
  // Keep it lazy-safe.
  OtpController get controller => Get.isRegistered<OtpController>()
      ? Get.find<OtpController>()
      : Get.put(OtpController());

  final AndroidNotificationChannel channel = const AndroidNotificationChannel(
    'flutter_notification',
    'flutter_notification_title',
    description: 'Channel for high priority notifications',
    importance: Importance.high,
  );

  String? _fcmToken;
  String? get fcmToken => _fcmToken;

  Future<void> initializeFirebase() async {
    // handler already registered in main, but safe to keep
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await flutterLocalNotificationsPlugin.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
        macOS: iosSettings,
      ),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload != null && payload.isNotEmpty) {
          _handleNotificationTap(payload);
        }
      },
    );

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    await _requestNotificationPermission();
  }

  Future<void> _requestNotificationPermission() async {
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    CommonLogger.log.i(
      '🔔 Notification permission: ${settings.authorizationStatus}',
    );

    if (settings.authorizationStatus != AuthorizationStatus.authorized) {
      CommonLogger.log.w('🚫 User denied notification permission');
      Get.snackbar(
        'Notifications Disabled',
        'Please enable notifications in settings to stay updated.',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Future<void> fetchFCMTokenIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    _fcmToken = prefs.getString('fcmToken');

    if (_fcmToken == null || _fcmToken!.isEmpty) {
      _fcmToken = await _getFCMTokenWithRetry();
      if (_fcmToken != null && _fcmToken!.isNotEmpty) {
        await prefs.setString('fcmToken', _fcmToken!);

        // ✅ send token, but never crash app
        try {
          await controller.sendFcmToken(fcmToken: _fcmToken!);
        } catch (e) {
          CommonLogger.log.w("⚠️ sendFcmToken failed: $e");
        }
      } else {
        CommonLogger.log.w('❌ FCM token could not be fetched now (will retry later)');
      }
    } else {
      CommonLogger.log.i('ℹ️ Existing FCM token: $_fcmToken');
      try {
        await controller.sendFcmToken(fcmToken: _fcmToken!);
      } catch (e) {
        CommonLogger.log.w("⚠️ sendFcmToken failed: $e");
      }
    }

    // ✅ refresh listener
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      CommonLogger.log.i('🔁 Token refreshed: $newToken');
      _fcmToken = newToken;
      await prefs.setString('fcmToken', newToken);
      try {
        await controller.sendFcmToken(fcmToken: newToken);
      } catch (e) {
        CommonLogger.log.w("⚠️ sendFcmToken failed: $e");
      }
    });
  }

  /// ✅ Robust token retry (handles SERVICE_NOT_AVAILABLE)
  Future<String?> _getFCMTokenWithRetry({int retries = 5}) async {
    for (int i = 1; i <= retries; i++) {
      try {
        // iOS only: ensure APNs token exists before requesting FCM
        if (Platform.isIOS) {
          final apns = await FirebaseMessaging.instance.getAPNSToken();
          if (apns == null || apns.isEmpty) {
            CommonLogger.log.w("🍎 APNs not ready (attempt $i), retrying...");
            await Future.delayed(Duration(seconds: 2 * i));
            continue;
          }
        }

        final token = await FirebaseMessaging.instance.getToken();
        if (token != null && token.isNotEmpty) return token;

        CommonLogger.log.w("⚠️ Token null/empty (attempt $i)");
      } catch (e) {
        // ✅ log exact error, don't throw
        CommonLogger.log.w("❌ getToken failed (attempt $i): $e");
      }

      await Future.delayed(Duration(seconds: 2 * i));
    }
    return null;
  }

  Future<void> showNotification(RemoteMessage message) async {
    final androidDetails = AndroidNotificationDetails(
      channel.id,
      channel.name,
      channelDescription: channel.description,
      importance: Importance.max,
      priority: Priority.high,
    );

    final notificationDetails = NotificationDetails(android: androidDetails);

    await flutterLocalNotificationsPlugin.show(
      0,
      message.notification?.title ?? 'Notification',
      message.notification?.body ?? '',
      notificationDetails,
      payload: message.data['screen']?.toString() ?? '',
    );
  }

  void listenToMessages({
    required void Function(RemoteMessage) onMessage,
    required void Function(RemoteMessage) onMessageOpenedApp,
  }) {
    FirebaseMessaging.onMessage.listen((msg) {
      CommonLogger.log.i('📩 [FG] Message: ${msg.messageId}');
      onMessage(msg);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((msg) {
      CommonLogger.log.i('📬 [BG/OPENED] Message: ${msg.messageId}');
      _handleNotificationTap(msg.data['screen']?.toString());
      onMessageOpenedApp(msg);
    });

    FirebaseMessaging.instance.getInitialMessage().then((msg) {
      if (msg != null) {
        CommonLogger.log.i('🚀 [TERMINATED] Message: ${msg.messageId}');
        _handleNotificationTap(msg.data['screen']?.toString());
        onMessageOpenedApp(msg);
      }
    });
  }

  void _handleNotificationTap(String? route) {
    if (route == null || route.isEmpty) return;

    switch (route) {
      case 'attendance':
        Get.toNamed('/attendance');
        break;
      default:
        CommonLogger.log.i('⚠️ Unknown route: $route');
        break;
    }
  }
}

// import 'package:firebase_core/firebase_core.dart';
// import 'package:firebase_messaging/firebase_messaging.dart';
// import 'package:flutter_local_notifications/flutter_local_notifications.dart';
// import 'package:flutter/material.dart';
// import 'package:get/get.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:hopper/Core/Constants/log.dart';
// import 'package:hopper/Presentation/Authentication/controller/otp_controller.dart';
//
// @pragma('vm:entry-point')
// Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
//   await Firebase.initializeApp();
//   CommonLogger.log.i('🔕 [BG] Message received: ${message.messageId}');
// }
//
// class FirebaseService {
//   final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
//       FlutterLocalNotificationsPlugin();
//   final OtpController controller = Get.put(OtpController());
//
//   final AndroidNotificationChannel channel = const AndroidNotificationChannel(
//     'flutter_notification',
//     'flutter_notification_title',
//     description: 'Channel for high priority notifications',
//     importance: Importance.high,
//   );
//
//   String? _fcmToken;
//   String? get fcmToken => _fcmToken;
//
//   Future<void> initializeFirebase() async {
//     FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
//
//     const androidSettings = AndroidInitializationSettings(
//       '@mipmap/ic_launcher',
//     );
//     const iosSettings = DarwinInitializationSettings(
//       requestAlertPermission: true,
//       requestBadgePermission: true,
//       requestSoundPermission: true,
//     );
//
//     await flutterLocalNotificationsPlugin.initialize(
//       const InitializationSettings(
//         android: androidSettings,
//         iOS: iosSettings,
//         macOS: iosSettings,
//       ),
//       onDidReceiveNotificationResponse: (response) {
//         final payload = response.payload;
//         if (payload != null && payload.isNotEmpty) {
//           _handleNotificationTap(payload);
//         }
//       },
//     );
//
//     await flutterLocalNotificationsPlugin
//         .resolvePlatformSpecificImplementation<
//           AndroidFlutterLocalNotificationsPlugin
//         >()
//         ?.createNotificationChannel(channel);
//
//     await _requestNotificationPermission();
//   }
//
//   /// Request permissions (iOS & Android)
//   Future<void> _requestNotificationPermission() async {
//     final settings = await FirebaseMessaging.instance.requestPermission(
//       alert: true,
//       badge: true,
//       sound: true,
//     );
//
//     CommonLogger.log.i(
//       '🔔 Notification permission: ${settings.authorizationStatus}',
//     );
//     if (settings.authorizationStatus != AuthorizationStatus.authorized) {
//       CommonLogger.log.w('🚫 User denied notification permission');
//       Get.snackbar(
//         'Notifications Disabled',
//         'Please enable notifications in settings to stay updated.',
//         snackPosition: SnackPosition.BOTTOM,
//       );
//     }
//   }
//
//   /// Fetch FCM token safely with APNs check
//   Future<void> fetchFCMTokenIfNeeded() async {
//     final prefs = await SharedPreferences.getInstance();
//     _fcmToken = prefs.getString('fcmToken');
//
//     if (_fcmToken == null) {
//       _fcmToken = await _getFCMTokenWithRetry();
//       if (_fcmToken != null) {
//         await prefs.setString('fcmToken', _fcmToken!);
//         await controller.sendFcmToken(fcmToken: _fcmToken!);
//       } else {
//         CommonLogger.log.w('❌ FCM token could not be fetched');
//       }
//     } else {
//       CommonLogger.log.i('ℹ️ Existing FCM token: $_fcmToken');
//       controller.sendFcmToken(fcmToken: _fcmToken!);
//     }
//
//     FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
//       CommonLogger.log.i('🔁 Token refreshed: $newToken');
//       _fcmToken = newToken;
//       await prefs.setString('fcmToken', newToken);
//       controller.sendFcmToken(fcmToken: newToken);
//     });
//   }
//
//   /// Retry until APNs token is available
//   Future<String?> _getFCMTokenWithRetry({int retries = 5}) async {
//     for (int i = 0; i < retries; i++) {
//       try {
//         final token = await FirebaseMessaging.instance.getToken();
//         if (token != null && token.isNotEmpty) return token;
//       } catch (_) {
//         await Future.delayed(Duration(seconds: 2));
//       }
//     }
//     return null;
//   }
//
//   /// Foreground notifications
//   Future<void> showNotification(RemoteMessage message) async {
//     final androidDetails = AndroidNotificationDetails(
//       channel.id,
//       channel.name,
//       channelDescription: channel.description,
//       importance: Importance.max,
//       priority: Priority.high,
//     );
//
//     final notificationDetails = NotificationDetails(android: androidDetails);
//
//     await flutterLocalNotificationsPlugin.show(
//       0,
//       message.notification?.title ?? 'Notification',
//       message.notification?.body ?? '',
//       notificationDetails,
//       payload: message.data['screen'] ?? '',
//     );
//   }
//
//   /// Listen to foreground, background, and terminated messages
//   void listenToMessages({
//     required void Function(RemoteMessage) onMessage,
//     required void Function(RemoteMessage) onMessageOpenedApp,
//   }) {
//     FirebaseMessaging.onMessage.listen((msg) {
//       CommonLogger.log.i('📩 [FG] Message: ${msg.messageId}');
//       onMessage(msg);
//     });
//
//     FirebaseMessaging.onMessageOpenedApp.listen((msg) {
//       CommonLogger.log.i('📬 [BG/OPENED] Message: ${msg.messageId}');
//       _handleNotificationTap(msg.data['screen']);
//       onMessageOpenedApp(msg);
//     });
//
//     FirebaseMessaging.instance.getInitialMessage().then((msg) {
//       if (msg != null) {
//         CommonLogger.log.i('🚀 [TERMINATED] Message: ${msg.messageId}');
//         _handleNotificationTap(msg.data['screen']);
//         onMessageOpenedApp(msg);
//       }
//     });
//   }
//
//   void _handleNotificationTap(String? route) {
//     if (route == null || route.isEmpty) return;
//
//     switch (route) {
//       case 'attendance':
//         Get.toNamed('/attendance');
//         break;
//       default:
//         CommonLogger.log.i('⚠️ Unknown route: $route');
//         break;
//     }
//   }
// }
//
//
