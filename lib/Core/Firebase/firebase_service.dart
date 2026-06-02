import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hopper/Core/Constants/log.dart';
import 'package:hopper/Presentation/Authentication/controller/otp_controller.dart';

final FlutterLocalNotificationsPlugin _bgLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();
bool _bgLocalNotificationsInitialized = false;

Future<void> _ensureBgLocalNotificationsInitialized() async {
  if (_bgLocalNotificationsInitialized) return;

  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  const iosInit = DarwinInitializationSettings();

  try {
    await _bgLocalNotificationsPlugin.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit, macOS: iosInit),
    );
  } catch (_) {
    // Best-effort; never throw in background isolate.
  }

  _bgLocalNotificationsInitialized = true;
}

Future<void> _showBgLocalNotification(RemoteMessage message) async {
  await _ensureBgLocalNotificationsInitialized();

  final data = message.data;
  final notification = message.notification;
  final title = (notification?.title ?? data['title'] ?? 'Notification').toString();
  final body = (notification?.body ?? data['body'] ?? '').toString();

  if (title.isEmpty && body.isEmpty && data.isEmpty) return;

  const androidDetails = AndroidNotificationDetails(
    'flutter_notification',
    'flutter_notification_title',
    channelDescription: 'Channel for high priority notifications',
    importance: Importance.max,
    priority: Priority.high,
    playSound: true,
  );
  const iosDetails = DarwinNotificationDetails(
    presentAlert: true,
    presentBadge: true,
    presentSound: true,
  );

  try {
    await _bgLocalNotificationsPlugin.show(
      Random().nextInt(1 << 31),
      title,
      body,
      const NotificationDetails(android: androidDetails, iOS: iosDetails),
    );
  } catch (_) {
    // ignore
  }
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
    await _showBgLocalNotification(message);
  } catch (e) {
    // Never crash background isolate.
    CommonLogger.log.w('FCM [BG] Firebase init failed: $e');
  }
  CommonLogger.log.d('FCM [BG] message received: ${message.messageId}');
}

class FirebaseService {
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Keep GetX usage lazy-safe.
  OtpController get controller =>
      Get.isRegistered<OtpController>() ? Get.find<OtpController>() : Get.put(OtpController());

  final AndroidNotificationChannel channel = const AndroidNotificationChannel(
    'flutter_notification',
    'flutter_notification_title',
    description: 'Channel for high priority notifications',
    importance: Importance.high,
  );

  String? _fcmToken;
  String? get fcmToken => _fcmToken;

  bool _tokenRefreshAttached = false;
  Timer? _tokenRetryTimer;
  int _tokenRetryCount = 0;

  Future<void> initializeFirebase() async {
    // Handler also registered in main, but safe to keep.
    try {
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    } catch (_) {}

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    try {
      await flutterLocalNotificationsPlugin.initialize(
        const InitializationSettings(android: androidSettings, iOS: iosSettings, macOS: iosSettings),
        onDidReceiveNotificationResponse: (response) {
          final payload = response.payload;
          if (payload != null && payload.isNotEmpty) {
            _handleNotificationTap(payload);
          }
        },
      );
    } catch (e) {
      CommonLogger.log.w('Local notifications init failed: $e');
    }

    try {
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    } catch (e) {
      CommonLogger.log.w('Notification channel create failed: $e');
    }

    // iOS: ensure foreground notifications can be presented.
    try {
      await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    } catch (_) {}

    await _requestNotificationPermission();
  }

  Future<void> _requestNotificationPermission() async {
    try {
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      CommonLogger.log.i(
        'FCM permission: ${settings.authorizationStatus}',
      );
    } catch (e) {
      CommonLogger.log.w('requestPermission failed: $e');
    }
  }

  Future<void> fetchFCMTokenIfNeeded({bool forceRefresh = false}) async {
    // If Firebase core is not ready, avoid touching Messaging.
    if (Firebase.apps.isEmpty) {
      CommonLogger.log.w('Firebase not initialized; skip FCM token fetch');
      return;
    }

    SharedPreferences prefs;
    try {
      prefs = await SharedPreferences.getInstance();
    } catch (e) {
      CommonLogger.log.w('SharedPreferences not available for FCM: $e');
      return;
    }

    _fcmToken = prefs.getString('fcmToken');

    if (forceRefresh || _fcmToken == null || _fcmToken!.isEmpty) {
      _fcmToken = await _getFCMTokenWithRetry();
      if (_fcmToken != null && _fcmToken!.isNotEmpty) {
        _tokenRetryCount = 0;
        _tokenRetryTimer?.cancel();
        _tokenRetryTimer = null;
        try {
          await prefs.setString('fcmToken', _fcmToken!);
        } catch (_) {}
        CommonLogger.log.i('FCM token fetched (${_fcmToken!.length} chars)');

        try {
          await controller.sendFcmToken(fcmToken: _fcmToken!);
        } catch (e) {
          CommonLogger.log.w('sendFcmToken failed: $e');
        }
      } else {
        CommonLogger.log.w('FCM token not available now (will retry later)');
        _scheduleTokenRetry();
      }
    } else {
      CommonLogger.log.d('FCM token loaded from cache (${_fcmToken!.length} chars)');
      try {
        await controller.sendFcmToken(fcmToken: _fcmToken!);
      } catch (e) {
        CommonLogger.log.w('sendFcmToken failed: $e');
      }
    }

    if (_tokenRefreshAttached) return;
    _tokenRefreshAttached = true;

    try {
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
        _fcmToken = newToken;
        _tokenRetryCount = 0;
        _tokenRetryTimer?.cancel();
        _tokenRetryTimer = null;
        CommonLogger.log.d('FCM token refreshed (${newToken.length} chars)');
        try {
          await prefs.setString('fcmToken', newToken);
        } catch (_) {}
        try {
          await controller.sendFcmToken(fcmToken: newToken);
        } catch (e) {
          CommonLogger.log.w('sendFcmToken failed: $e');
        }
      });
    } catch (e) {
      CommonLogger.log.w('onTokenRefresh listen failed: $e');
    }
  }

  void _scheduleTokenRetry() {
    if (_tokenRetryTimer != null) return;
    if (_tokenRetryCount >= 3) return;
    _tokenRetryCount++;

    final delay = Duration(seconds: 20 * _tokenRetryCount);
    _tokenRetryTimer = Timer(delay, () async {
      _tokenRetryTimer = null;
      try {
        await fetchFCMTokenIfNeeded(forceRefresh: true);
      } catch (e) {
        CommonLogger.log.w('FCM retry failed: $e');
      }
    });
  }

  Future<String?> _getFCMTokenWithRetry({int retries = 5}) async {
    for (int i = 1; i <= retries; i++) {
      try {
        // iOS only: ensure APNs token exists before requesting FCM
        if (Platform.isIOS) {
          final apns = await FirebaseMessaging.instance.getAPNSToken();
          if (apns == null || apns.isEmpty) {
            await Future.delayed(Duration(seconds: 2 * i));
            continue;
          }
        }

        final token = await FirebaseMessaging.instance.getToken();
        if (token != null && token.isNotEmpty) return token;
      } catch (e) {
        CommonLogger.log.w('getToken failed (attempt $i): $e');
      }
      await Future.delayed(Duration(seconds: 2 * i));
    }
    return null;
  }

  Future<void> showNotification(RemoteMessage message) async {
    try {
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
    } catch (e) {
      CommonLogger.log.w('showNotification failed: $e');
    }
  }

  void listenToMessages({
    required void Function(RemoteMessage) onMessage,
    required void Function(RemoteMessage) onMessageOpenedApp,
  }) {
    try {
      FirebaseMessaging.onMessage.listen((msg) {
        onMessage(msg);
      });
      FirebaseMessaging.onMessageOpenedApp.listen((msg) {
        _handleNotificationTap(msg.data['screen']?.toString());
        onMessageOpenedApp(msg);
      });
      FirebaseMessaging.instance.getInitialMessage().then((msg) {
        if (msg != null) {
          _handleNotificationTap(msg.data['screen']?.toString());
          onMessageOpenedApp(msg);
        }
      });
    } catch (e) {
      CommonLogger.log.w('listenToMessages failed: $e');
    }
  }

  void _handleNotificationTap(String? route) {
    if (route == null || route.isEmpty) return;
    try {
      switch (route) {
        case 'attendance':
          Get.toNamed('/attendance');
          break;
        default:
          CommonLogger.log.i('Unknown route: $route');
          break;
      }
    } catch (_) {}
  }
}
