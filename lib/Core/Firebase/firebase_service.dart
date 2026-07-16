import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

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

const String _defaultChannelId = 'flutter_notification';
const String _defaultChannelName = 'General Notifications';
const String _bookingRequestChannelId = 'hopper_booking_request_alerts_v3';
const String _bookingRequestChannelName = 'Booking Request Alerts';
const String _bookingRequestSoundName = 'booking_request_alert';
const String _pendingBookingRequestPayloadKey =
    'pending_booking_request_notification_payload_v1';
final Int64List _bookingVibrationPattern = Int64List.fromList(<int>[
  0,
  350,
  220,
  450,
  220,
  350,
]);

bool _isBookingRequestData(Map<String, dynamic> data) {
  final type = (data['type'] ?? '').toString().trim().toLowerCase();
  final screen = (data['screen'] ?? '').toString().trim().toLowerCase();
  if (type == 'booking_request' ||
      type == 'ride_request' ||
      type == 'shared_ride_request' ||
      type == 'parcel_request') {
    return true;
  }
  return screen == 'booking_request';
}

String _notificationPayload(RemoteMessage message) {
  final payload = <String, dynamic>{
    'data': Map<String, dynamic>.from(message.data),
    'title': (message.notification?.title ?? message.data['title'] ?? '')
        .toString(),
    'body': (message.notification?.body ?? message.data['body'] ?? '')
        .toString(),
  };
  return jsonEncode(payload);
}

AndroidNotificationDetails _androidDetailsFor(Map<String, dynamic> data) {
  final isBookingRequest = _isBookingRequestData(data);
  if (isBookingRequest) {
    return AndroidNotificationDetails(
      _bookingRequestChannelId,
      _bookingRequestChannelName,
      channelDescription: 'Urgent alerts for incoming booking requests',
      importance: Importance.max,
      priority: Priority.max,
      category: AndroidNotificationCategory.call,
      ticker: 'New booking request',
      visibility: NotificationVisibility.public,
      enableVibration: true,
      vibrationPattern: _bookingVibrationPattern,
      playSound: true,
      sound: const RawResourceAndroidNotificationSound(
        _bookingRequestSoundName,
      ),
      audioAttributesUsage: AudioAttributesUsage.alarm,
      fullScreenIntent: false,
    );
  }

  return const AndroidNotificationDetails(
    _defaultChannelId,
    _defaultChannelName,
    channelDescription: 'Channel for general high priority notifications',
    importance: Importance.max,
    priority: Priority.high,
    playSound: true,
  );
}

DarwinNotificationDetails _darwinDetailsFor(Map<String, dynamic> data) {
  final isBookingRequest = _isBookingRequestData(data);
    return DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: isBookingRequest ? 'booking_request_alert.wav' : null,
      interruptionLevel:
          isBookingRequest ? InterruptionLevel.timeSensitive : null,
    );
}

Future<void> _ensureBgLocalNotificationsInitialized() async {
  if (_bgLocalNotificationsInitialized) return;

  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  const iosInit = DarwinInitializationSettings();

  try {
    await _bgLocalNotificationsPlugin.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit, macOS: iosInit),
    );
    await _bgLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            _defaultChannelId,
            _defaultChannelName,
            description: 'Channel for general high priority notifications',
            importance: Importance.high,
          ),
        );
    await _bgLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(
          AndroidNotificationChannel(
            _bookingRequestChannelId,
            _bookingRequestChannelName,
            description: 'Urgent alerts for incoming booking requests',
            importance: Importance.max,
            playSound: true,
            sound: const RawResourceAndroidNotificationSound(
              _bookingRequestSoundName,
            ),
            enableVibration: true,
            vibrationPattern: _bookingVibrationPattern,
            audioAttributesUsage: AudioAttributesUsage.alarm,
          ),
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

  final androidDetails = _androidDetailsFor(data);
  final iosDetails = _darwinDetailsFor(data);

  try {
    await _bgLocalNotificationsPlugin.show(
      Random().nextInt(1 << 31),
      title,
      body,
      NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload: _notificationPayload(message),
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
  CommonLogger.log.d(
    'FCM [BG] message received: ${message.messageId} data=${message.data} '
    'title=${message.notification?.title} body=${message.notification?.body}',
  );
}

class FirebaseService {
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Keep GetX usage lazy-safe.
  OtpController get controller =>
      Get.isRegistered<OtpController>() ? Get.find<OtpController>() : Get.put(OtpController());

  final AndroidNotificationChannel channel = const AndroidNotificationChannel(
    _defaultChannelId,
    _defaultChannelName,
    description: 'Channel for general high priority notifications',
    importance: Importance.high,
  );

  final AndroidNotificationChannel bookingRequestChannel =
      AndroidNotificationChannel(
        _bookingRequestChannelId,
        _bookingRequestChannelName,
        description: 'Urgent alerts for incoming booking requests',
        importance: Importance.max,
        playSound: true,
        sound: const RawResourceAndroidNotificationSound(
          _bookingRequestSoundName,
        ),
        enableVibration: true,
        vibrationPattern: _bookingVibrationPattern,
        audioAttributesUsage: AudioAttributesUsage.alarm,
      );

  String? _fcmToken;
  String? get fcmToken => _fcmToken;

  bool _tokenRefreshAttached = false;
  Timer? _tokenRetryTimer;
  int _tokenRetryCount = 0;
  void Function(Map<String, dynamic>)? _onBookingRequestOpened;

  static bool isBookingRequestNotification(Map<String, dynamic> data) {
    return _isBookingRequestData(data);
  }

  static Future<void> queueBookingRequestNotification(
    Map<String, dynamic> data,
  ) async {
    final sanitized = Map<String, dynamic>.from(data);
    if (!_isBookingRequestData(sanitized)) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _pendingBookingRequestPayloadKey,
        jsonEncode(sanitized),
      );
      CommonLogger.log.i(
        'Queued booking request notification payload: $sanitized',
      );
    } catch (e) {
      CommonLogger.log.w('Failed to queue booking request payload: $e');
    }
  }

  static Future<void> restoreQueuedBookingRequestNotification(
    Map<String, dynamic> data,
  ) async {
    await queueBookingRequestNotification(data);
  }

  static Future<Map<String, dynamic>?> consumeQueuedBookingRequestNotification()
  async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_pendingBookingRequestPayloadKey);
      if (raw == null || raw.trim().isEmpty) return null;
      await prefs.remove(_pendingBookingRequestPayloadKey);
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        final data = Map<String, dynamic>.from(decoded);
        CommonLogger.log.i(
          'Consumed queued booking request notification payload: $data',
        );
        return data;
      }
    } catch (e) {
      CommonLogger.log.w('Failed to consume booking request payload: $e');
    }
    return null;
  }

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
            unawaited(_handleNotificationTapPayload(payload));
          }
        },
      );
      final launchDetails =
          await flutterLocalNotificationsPlugin
              .getNotificationAppLaunchDetails();
      final launchPayload =
          launchDetails?.notificationResponse?.payload ?? '';
      if (launchDetails?.didNotificationLaunchApp == true &&
          launchPayload.isNotEmpty) {
        await _handleNotificationTapPayload(launchPayload);
      }
    } catch (e) {
      CommonLogger.log.w('Local notifications init failed: $e');
    }

    try {
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(bookingRequestChannel);
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
      final androidDetails = _androidDetailsFor(message.data);
      final iosDetails = _darwinDetailsFor(message.data);
      final notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );
      final bookingId = (message.data['bookingId'] ?? '').toString();
      final notificationId =
          int.tryParse(bookingId.replaceAll(RegExp(r'[^0-9]'), '')) ??
          Random().nextInt(1 << 31);
      CommonLogger.log.i(
        'Showing local notification id=$notificationId '
        'channel=${_isBookingRequestData(message.data) ? _bookingRequestChannelId : _defaultChannelId} '
        'bookingId=$bookingId sound=${_isBookingRequestData(message.data) ? _bookingRequestSoundName : 'default'}',
      );

      await flutterLocalNotificationsPlugin.show(
        notificationId,
        (message.notification?.title ?? message.data['title'] ?? 'Notification')
            .toString(),
        (message.notification?.body ?? message.data['body'] ?? '').toString(),
        notificationDetails,
        payload: _notificationPayload(message),
      );
    } catch (e) {
      CommonLogger.log.w('showNotification failed: $e');
    }
  }

  void listenToMessages({
    required void Function(RemoteMessage) onMessage,
    required void Function(RemoteMessage) onMessageOpenedApp,
    void Function(Map<String, dynamic>)? onBookingRequestOpened,
  }) {
    try {
      _onBookingRequestOpened = onBookingRequestOpened;
      FirebaseMessaging.onMessage.listen((msg) {
        onMessage(msg);
      });
      FirebaseMessaging.onMessageOpenedApp.listen((msg) async {
        await _handleNotificationTapData(msg.data);
        onMessageOpenedApp(msg);
      });
      FirebaseMessaging.instance.getInitialMessage().then((msg) async {
        if (msg != null) {
          await _handleNotificationTapData(msg.data);
          onMessageOpenedApp(msg);
        }
      });
    } catch (e) {
      CommonLogger.log.w('listenToMessages failed: $e');
    }
  }

  Future<void> _handleNotificationTapPayload(String payload) async {
    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map) {
        final root = Map<String, dynamic>.from(decoded);
        final nested = root['data'];
        if (nested is Map) {
          final merged = Map<String, dynamic>.from(nested);
          if (!merged.containsKey('title') && root['title'] != null) {
            merged['title'] = root['title'];
          }
          if (!merged.containsKey('body') && root['body'] != null) {
            merged['body'] = root['body'];
          }
          await _handleNotificationTapData(merged);
          return;
        }
        await _handleNotificationTapData(root);
        return;
      }
    } catch (_) {}
    await _handleNotificationTapData(<String, dynamic>{
      'screen': payload,
    });
  }

  Future<void> _handleNotificationTapData(Map<String, dynamic> data) async {
    final fallbackRoute =
        _isBookingRequestData(data) ? 'booking_request' : '';
    final route = ((data['screen'] ?? '').toString().trim().isNotEmpty
            ? data['screen']
            : fallbackRoute)
        .toString();
    final type = (data['type'] ?? '').toString();
    final bookingId = (data['bookingId'] ?? '').toString();
    if (route.isEmpty) return;
    try {
      switch (route) {
        case 'attendance':
          Get.toNamed('/attendance');
          break;
        case 'booking_request':
          await queueBookingRequestNotification(data);
          CommonLogger.log.i(
            'Booking request notification opened type=$type bookingId=$bookingId '
            'payload=$data',
          );
          _onBookingRequestOpened?.call(Map<String, dynamic>.from(data));
          break;
        default:
          CommonLogger.log.i(
            'Unknown route: $route type=$type bookingId=$bookingId',
          );
          break;
      }
    } catch (_) {}
  }
}
