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
  final OtpController controller = Get.put(OtpController());

  final AndroidNotificationChannel channel = const AndroidNotificationChannel(
    'flutter_notification',
    'flutter_notification_title',
    description: 'Channel for high priority notifications',
    importance: Importance.high,
  );

  String? _fcmToken;
  String? get fcmToken => _fcmToken;

  Future<void> initializeFirebase() async {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
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
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);

    await _requestNotificationPermission();
  }

  /// Request permissions (iOS & Android)
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

  /// Fetch FCM token safely with APNs check
  Future<void> fetchFCMTokenIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    _fcmToken = prefs.getString('fcmToken');

    if (_fcmToken == null) {
      _fcmToken = await _getFCMTokenWithRetry();
      if (_fcmToken != null) {
        await prefs.setString('fcmToken', _fcmToken!);
        await controller.sendFcmToken(fcmToken: _fcmToken!);
      } else {
        CommonLogger.log.w('❌ FCM token could not be fetched');
      }
    } else {
      CommonLogger.log.i('ℹ️ Existing FCM token: $_fcmToken');
      controller.sendFcmToken(fcmToken: _fcmToken!);
    }

    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      CommonLogger.log.i('🔁 Token refreshed: $newToken');
      _fcmToken = newToken;
      await prefs.setString('fcmToken', newToken);
      controller.sendFcmToken(fcmToken: newToken);
    });
  }

  /// Retry until APNs token is available
  Future<String?> _getFCMTokenWithRetry({int retries = 5}) async {
    for (int i = 0; i < retries; i++) {
      try {
        final token = await FirebaseMessaging.instance.getToken();
        if (token != null && token.isNotEmpty) return token;
      } catch (_) {
        await Future.delayed(Duration(seconds: 2));
      }
    }
    return null;
  }

  /// Foreground notifications
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
      payload: message.data['screen'] ?? '',
    );
  }

  /// Listen to foreground, background, and terminated messages
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
      _handleNotificationTap(msg.data['screen']);
      onMessageOpenedApp(msg);
    });

    FirebaseMessaging.instance.getInitialMessage().then((msg) {
      if (msg != null) {
        CommonLogger.log.i('🚀 [TERMINATED] Message: ${msg.messageId}');
        _handleNotificationTap(msg.data['screen']);
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

//
// import 'package:firebase_core/firebase_core.dart';
// import 'package:firebase_messaging/firebase_messaging.dart';
// import 'package:flutter_local_notifications/flutter_local_notifications.dart';
// import 'package:flutter/material.dart';
//
// import 'package:hopper/Core/Constants/log.dart';
// import 'package:hopper/Presentation/Authentication/controller/otp_controller.dart';
//
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:get/get.dart';
//
// /// 🔹 Background message handler (MUST be top-level)
// @pragma('vm:entry-point')
// Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
//   await Firebase.initializeApp();
//   CommonLogger.log.i('🔕 [BG] messageId=${message.messageId}');
//   CommonLogger.log.i('🔕 [BG] New background message received!');
//   CommonLogger.log.i('📦 Message ID: ${message.messageId}');
//   CommonLogger.log.i('🔔 Title: ${message.notification?.title}');
//   CommonLogger.log.i('📝 Body: ${message.notification?.body}');
//   CommonLogger.log.i('💾 Data: ${message.data}');
//   CommonLogger.log.i('📱 From: ${message.from}');
// }
//
// class FirebaseService {
//   final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
//       FlutterLocalNotificationsPlugin();
//   final OtpController controller = Get.put(OtpController());
//   final AndroidNotificationChannel channel = const AndroidNotificationChannel(
//     'flutter_notification',
//     'flutter_notification_title',
//     description: 'Channel for high priority notifications',
//     importance: Importance.high,
//     enableLights: true,
//     showBadge: true,
//     playSound: true,
//   );
//
//   String? _fcmToken;
//   String? get fcmToken => _fcmToken;
//   Future<void> initializeFirebase() async {
//     // Register background handler (must be done only once)
//     FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
//
//     // -----------------------------
//     // iOS / Android initialization
//     // -----------------------------
//     const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
//
//     // iOS / macOS initialization
//     const iosInit = DarwinInitializationSettings(
//       requestAlertPermission: true,
//       requestBadgePermission: true,
//       requestSoundPermission: true,
//     );
//
//     // Combine settings
//     const initSettings = InitializationSettings(
//       android: androidInit,
//       iOS: iosInit,
//       macOS: iosInit,
//     );
//
//     // Initialize plugin
//     await flutterLocalNotificationsPlugin.initialize(
//       initSettings,
//       onDidReceiveNotificationResponse: (response) {
//         final payload = response.payload;
//         if (payload != null && payload.isNotEmpty) {
//           _handleNotificationTap(payload);
//         }
//       },
//     );
//
//     // Android channel
//     await flutterLocalNotificationsPlugin
//         .resolvePlatformSpecificImplementation<
//         AndroidFlutterLocalNotificationsPlugin>()
//         ?.createNotificationChannel(channel);
//
//     // Request permission for notifications
//     await _requestNotificationPermission();
//   }
//
//   // 🔹 Initialize Firebase Messaging + Local Notifications
//   // Future<void> initializeFirebase() async {
//   //   // Register background handler (must be done only once)
//   //   FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
//   //
//   //   // Android local notifications init
//   //   const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
//   //   const initSettings = InitializationSettings(android: androidInit);
//   //
//   //
//   //   // Handle tap when notification received while app is in foreground
//   //   await flutterLocalNotificationsPlugin.initialize(
//   //     initSettings,
//   //     onDidReceiveNotificationResponse: (response) {
//   //       final payload = response.payload;
//   //       if (payload != null && payload.isNotEmpty) {
//   //         _handleNotificationTap(payload);
//   //       }
//   //     },
//   //   );
//   //
//   //   await flutterLocalNotificationsPlugin
//   //       .resolvePlatformSpecificImplementation<
//   //         AndroidFlutterLocalNotificationsPlugin
//   //       >()
//   //       ?.createNotificationChannel(channel);
//   //
//   //   // Ask notification permission (Android 13+ & iOS)
//   //   await _requestNotificationPermission();
//   // }
//
//   // 🔹 Ask for permission (Android 13+ & iOS)
//   Future<void> _requestNotificationPermission() async {
//     final settings = await FirebaseMessaging.instance.requestPermission(
//       alert: true,
//       badge: true,
//       sound: true,
//       provisional: false,
//     );
//
//     CommonLogger.log.i(
//       '🔔 Notification permission: ${settings.authorizationStatus}',
//     );
//
//     if (settings.authorizationStatus == AuthorizationStatus.denied) {
//       CommonLogger.log.w('🚫 User denied notification permission');
//       Get.snackbar(
//         'Notifications Disabled',
//         'Please enable notifications in settings to stay updated.',
//         snackPosition: SnackPosition.BOTTOM,
//       );
//     }
//   }
//
//   Future<void> fetchFCMTokenIfNeeded() async {
//     final prefs = await SharedPreferences.getInstance();
//     _fcmToken = prefs.getString('fcmToken');
//
//     if (_fcmToken == null) {
//       final messaging = FirebaseMessaging.instance;
//       final token = await messaging.getToken();
//       CommonLogger.log.i('✅ New FCM Token: $token');
//       _fcmToken = token;
//       if (token != null) {
//         await prefs.setString('fcmToken', token);
//         await controller.sendFcmToken(fcmToken: token);
//       }
//     } else {
//       CommonLogger.log.i('ℹ️ Existing FCM Token: $_fcmToken');
//       controller.sendFcmToken(fcmToken: _fcmToken!);
//     }
//
//     // 🔁 Listen for token refresh
//     FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
//       CommonLogger.log.i('🔁 Token refreshed: $newToken');
//       final prefs = await SharedPreferences.getInstance();
//       await prefs.setString('fcmToken', newToken);
//       controller.sendFcmToken(fcmToken: newToken);
//     });
//   }
//
//   // 🔹 Show local notification (for foreground)
//   Future<void> showNotification(RemoteMessage message) async {
//     final data = message.data;
//
//     final androidDetails = AndroidNotificationDetails(
//       channel.id,
//       channel.name,
//       channelDescription: channel.description,
//       importance: Importance.max,
//       priority: Priority.high,
//       showWhen: true,
//     );
//
//     final details = NotificationDetails(android: androidDetails);
//
//     await flutterLocalNotificationsPlugin.show(
//       0,
//       message.notification?.title ?? 'Notification',
//       message.notification?.body ?? '',
//       details,
//       payload: data['screen'] ?? '',
//     );
//   }
//
//   void listenToMessages({
//     required void Function(RemoteMessage) onMessage,
//     required void Function(RemoteMessage) onMessageOpenedApp,
//   }) {
//     // Foreground message
//     FirebaseMessaging.onMessage.listen((msg) {
//       CommonLogger.log.i('📩 [FOREGROUND] Full Message Data:');
//       _printFullMessage(msg);
//       onMessage(msg);
//     });
//
//     FirebaseMessaging.onMessageOpenedApp.listen((msg) {
//       CommonLogger.log.i('📬 [OPENED FROM BG] Full Message Data:');
//       _printFullMessage(msg);
//       _handleNotificationTap(msg.data['screen']);
//       onMessageOpenedApp(msg);
//     });
//
//     // Terminated (app launched from notification)
//     FirebaseMessaging.instance.getInitialMessage().then((msg) {
//       if (msg != null) {
//         CommonLogger.log.i('🚀 [TERMINATED TAP] Full Message Data:');
//         _printFullMessage(msg);
//         _handleNotificationTap(msg.data['screen']);
//         onMessageOpenedApp(msg);
//       }
//     });
//   }
//
//   void _printFullMessage(RemoteMessage message) {
//     CommonLogger.log.i('🔔 Notification Title: ${message.notification?.title}');
//     CommonLogger.log.i('📝 Notification Body: ${message.notification?.body}');
//     CommonLogger.log.i('📦 Message ID: ${message.messageId}');
//     CommonLogger.log.i('📱 From: ${message.from}');
//     CommonLogger.log.i('⏰ Sent Time: ${message.sentTime}');
//     CommonLogger.log.i('🌐 Category: ${message.category}');
//     CommonLogger.log.i('🧩 Collapse Key: ${message.collapseKey}');
//     CommonLogger.log.i(
//       '💾 Data Payload: ${message.data.isNotEmpty ? message.data : 'No data'}',
//     );
//   }
//
//   void _handleNotificationTap(String? route) {
//     if (route == null || route.isEmpty) return;
//
//     switch (route) {
//       case 'TeacherMessageDetails':
//         // Get.to(MessageScreen());
//         break;
//       case 'attendance':
//         Get.toNamed('/attendance');
//         break;
//       default:
//         CommonLogger.log.i('⚠️ Unknown route: $route');
//         break;
//     }
//   }
// }
