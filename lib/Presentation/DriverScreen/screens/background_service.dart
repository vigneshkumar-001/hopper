// lib/services/background_service.dart
import 'dart:async';
import 'dart:io' show Platform;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hopper/Core/Constants/log.dart';
import '../../../api/repository/api_config_controller.dart';
import '../../../utils/sharedprefsHelper/sharedprefs_handler.dart';

Future<void>? _configureOnce;
Future<void>? _startOnce;
DateTime _lastStartRequestedAt = DateTime.fromMillisecondsSinceEpoch(0);

// Poll wakes every 1s so an active trip keeps a steady ~1s feed even when the
// OS throttles the background position stream (was 12s -> the customer car
// barely moved while the driver app was minimised). When idle the per-emit gap
// below (18s) still short-circuits the poll before any GPS read, so battery is
// unaffected when nobody is on a live ride.
const Duration _bgActiveTripPollInterval = Duration(seconds: 1);
// Active trip: allow the poll fallback to emit ~every 1s (was 10s).
const Duration _bgActiveTripMinEmitGap = Duration(seconds: 1);
const Duration _bgIdleMinEmitGap = Duration(seconds: 18);

// Freshness guard: never emit a GPS fix older than this. Android can hand the
// position stream a BACKLOG of buffered fixes after a stall; emitting them in
// order (gated to ~1/s) drains the backlog one-per-second, so the customer
// tracks the driver's position from N seconds ago. We compare `now` to the
// fix's OWN timestamp (same device clock) — immune to clock skew / timezone —
// and drop anything stale so only the genuinely current fix is sent. Generous
// enough to allow normal GPS provider latency (sub-second to ~2s).
const Duration _bgMaxFixAge = Duration(seconds: 5);

// Mirrors the foreground emit's `_STATIONARY_EMIT_M` (driver_main_controller).
// When the car physically moved less than this since the last emitted fix we
// send speed 0 instead of the raw (often phantom) GPS speed, so the customer
// HOLDS the marker instead of dead-reckoning it forward. Without this the
// background feed — the one that's live on the DROP leg, where the driver is
// navigating in Google Maps with the app backgrounded — made the customer's
// car creep ahead on a stopped/crawling driver and then snap back on the next
// fix (the "moves but jerky on drop" symptom). Pickup stayed smooth because it
// runs foreground, which already zeroes speed this way.
const double _bgStationaryEmitMeters = 1.5;

bool isBackgroundTrackingEnabled() {
  // Enabled for production: this app needs to send driver location even when the
  // app is backgrounded / screen-locked (Android foreground service).
  //
  // NOTE: Ensure Play Console declarations (background location / FGS types) are
  // completed when publishing builds that include these permissions.
  return true;
}

Future<void> initializeBackgroundService() async {
  if (!isBackgroundTrackingEnabled()) return;

  // Idempotent: multiple callers can await this safely (prevents race where
  // `startService()` is called before `configure()` finishes on app launch).
  _configureOnce ??= () async {
    // Ensure the notification channel exists before Android starts the FGS.
    // Missing/invalid notification can crash on newer Android.
    try {
      const channel = AndroidNotificationChannel(
        'hopper_driver_location',
        'Hopper Driver Location',
        description: 'Driver navigation background location tracking',
        importance: Importance.low,
      );
      final plugin = FlutterLocalNotificationsPlugin();
      await plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(channel);
    } catch (_) {}

    final service = FlutterBackgroundService();

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        isForegroundMode: true,
        autoStart: false,
        autoStartOnBoot: false,
        foregroundServiceTypes: const [AndroidForegroundType.location],
        notificationChannelId: 'hopper_driver_location',
        initialNotificationTitle: 'Hopper - Navigation Active',
        initialNotificationContent: 'Tap to return to Hopper',
        foregroundServiceNotificationId: 888,
      ),
      iosConfiguration: IosConfiguration(
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );
  }();

  await _configureOnce;
}

Future<void> ensureDriverTrackingServiceRunning({
  String? driverId,
  String? bookingId,
}) async {
  if (!isBackgroundTrackingEnabled()) return;
  await initializeBackgroundService();

  // Avoid crashing Android 13+ if notifications are disabled for the app.
  try {
    final plugin = FlutterLocalNotificationsPlugin();
    final android =
        plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
    final enabled = await android?.areNotificationsEnabled();
    if (enabled == false) {
      // Do NOT bail out. The foreground-service notification channel already
      // exists (created above), so the location FGS can still start — Android
      // just hides its notification when POST_NOTIFICATIONS is denied. Blocking
      // here left customers with a frozen driver marker the moment the driver
      // opened Google Maps (app backgrounded), because neither the background
      // service NOR the (now-disconnected) foreground socket was emitting.
      CommonLogger.log.w(
        '⚠️ [BG_SERVICE] Notifications disabled — starting FGS anyway '
        '(tracking notification hidden; driver location still emits).',
      );
    }
  } catch (_) {}

  final service = FlutterBackgroundService();
  // Prevent multiple rapid start attempts (can spawn multiple Flutter engines
  // on some OEMs and causes Geolocator "connected engine count" growth).
  final now = DateTime.now();
  if (now.difference(_lastStartRequestedAt) < const Duration(seconds: 2)) {
    service.invoke('data', {
      if (driverId != null) 'driverId': driverId,
      if (bookingId != null) 'bookingId': bookingId,
    });
    return;
  }
  _lastStartRequestedAt = now;

  _startOnce ??= () async {
    final running = await service.isRunning();
    if (running) return;
    try {
      if (kDebugMode) {
        CommonLogger.log.i('🟢 [BG_SERVICE] Starting driver tracking service');
      }
      await service.startService();
      // Give the platform time to spin up the background engine.
      await Future<void>.delayed(const Duration(milliseconds: 350));
    } catch (e) {
      CommonLogger.log.e('❌ [BG_SERVICE] startService failed: $e');
      rethrow;
    } finally {
      // Allow future start attempts if service was stopped later.
      _startOnce = null;
    }
  }();

  try {
    await _startOnce;
  } catch (_) {
    return;
  }

  service.invoke('data', {
    if (driverId != null) 'driverId': driverId,
    if (bookingId != null) 'bookingId': bookingId,
  });
}

Future<void> stopDriverTrackingService() async {
  if (!isBackgroundTrackingEnabled()) return;
  await initializeBackgroundService();
  final service = FlutterBackgroundService();
  final running = await service.isRunning();
  if (!running) return;
  if (kDebugMode) {
    CommonLogger.log.i('🛑 [BG_SERVICE] Stopping driver tracking service');
  }
  service.invoke('data', {'action': 'stopService'});
}

/// Safe to call from the foreground isolate to verify whether the tracking
/// service is actually running (used for handoff decisions).
Future<bool> isDriverTrackingServiceRunning() async {
  if (!isBackgroundTrackingEnabled()) return false;
  try {
    await initializeBackgroundService();
    return await FlutterBackgroundService().isRunning();
  } catch (_) {
    return false;
  }
}

@pragma('vm:entry-point')
bool onIosBackground(ServiceInstance service) {
  WidgetsFlutterBinding.ensureInitialized();
  return true;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  final AndroidServiceInstance? androidService =
      service is AndroidServiceInstance ? service : null;

  String? driverId;
  String? currentBookingId;
  // Stable per-install id (FCM token) so the backend dedupes this device's
  // foreground/background sockets instead of revoking them as a new-device-login.
  String? deviceId;
  StreamSubscription<Position>? positionSub;
  Timer? pollTimer;
  // C9: grace timer + bounded reclaim counter for the active-ride revoke safety.
  Timer? revokeGraceTimer;
  int revokeReclaimAttempts = 0;
  int clientSeq = 0;
  int emitCountWindow = 0;
  DateTime emitWindowStartedAt = DateTime.now();
  DateTime? lastEmitMetricAt;
  int lastEmitGapMs = 0;

  // Keep service as foreground (Android) so it continues on screen-lock.
  try {
    await androidService?.setAsForegroundService();
    await androidService?.setForegroundNotificationInfo(
      title: 'Driver Tracking Active',
      content: 'Tap to return to Hoppr Driver',
    );
  } catch (_) {}

  // --- jitter filtering / throttling ---
  const double maxAccuracyM = 25.0;
  const double stationaryJumpM = 30.0;
  const double jumpAcceptAccuracyM = 12.0;
  // Background (driver navigating in Google Maps): emit ~1s so the customer map
  // keeps gliding, same as foreground. The movement/jitter filters below still
  // stop emits while the driver is actually stationary, protecting battery.
  const Duration minEmitInterval = Duration(seconds: 1);

  double? lastLat;
  double? lastLng;
  DateTime lastEmitAt = DateTime.fromMillisecondsSinceEpoch(0);
  // Last GPS heading trusted while actually moving. Below ~1 m/s GPS heading is
  // random noise, so we HOLD this instead of sending raw per-fix heading — raw
  // heading made the customer's car icon spin/flip while the driver was stopped.
  // Mirrors the foreground `_lastEmitBearing` gate in DriverMainController.
  double? lastEmitBearing;

  try {
    driverId = await SharedPrefHelper.getDriverId();
  } catch (_) {}

  String socketUrl = ApiConfigController.singleSocket;
  try {
    final shared = await SharedPrefHelper.instance.getSharedBookingEnabled();
    socketUrl =
        shared
            ? ApiConfigController.sharedSocket
            : ApiConfigController.singleSocket;
  } catch (_) {}

  // Optional override (used when a screen explicitly starts tracking before
  // opening external navigation).
  try {
    final prefs = await SharedPreferences.getInstance();
    final persistedDriverId = prefs.getString('bg_driver_id')?.trim();
    if (driverId == null &&
        persistedDriverId != null &&
        persistedDriverId.isNotEmpty) {
      driverId = persistedDriverId;
    }
    final persistedBookingId = prefs.getString('bg_ride_id')?.trim();
    if (persistedBookingId != null && persistedBookingId.isNotEmpty) {
      currentBookingId = persistedBookingId;
    }
    final override = prefs.getString('bg_socket_url');
    if (override != null && override.trim().isNotEmpty) {
      socketUrl = override.trim();
    }
    final fcm = (prefs.getString('fcmToken') ?? '').trim();
    if (fcm.isNotEmpty) deviceId = fcm;
  } catch (_) {}

  Map<String, dynamic>? _pendingPayload;
  String? _pendingEvent;
  DateTime _lastManualReconnectAt = DateTime.fromMillisecondsSinceEpoch(0);
  // Single-session guard (mirrors the foreground SocketService). When the
  // foreground app reclaims the socket on resume, the backend revokes THIS
  // background session ("server namespace disconnect" / `session-revoked`).
  // Reconnecting here would revoke the foreground again -> endless revoke-war.
  // So once revoked we stop the background service entirely; the foreground now
  // owns the single connection.
  bool sessionRevoked = false;

  int nextClientSeq() {
    // Monotonic across ISOLATES — must use the SAME scheme as the foreground
    // SocketService.nextClientLocationSeq(): derive seq from the device wall
    // clock so the foreground and this background isolate share one strictly
    // increasing seq space. Without this the background stream restarts low and
    // the customer's seq-gate drops every packet while the driver is in Google
    // Maps (the navigation freeze bug).
    final int nowMs = DateTime.now().millisecondsSinceEpoch;
    clientSeq = nowMs > clientSeq ? nowMs : clientSeq + 1;
    return clientSeq;
  }

  String maskIdForLog(String? raw) {
    final value = raw?.trim() ?? '';
    if (value.isEmpty) return '';
    if (value.length <= 4) return value;
    return '***${value.substring(value.length - 4)}';
  }

  Future<void> persistLastBgEmit(String? bookingId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
        'bg_last_emit_at',
        DateTime.now().millisecondsSinceEpoch,
      );
      if (bookingId != null && bookingId.trim().isNotEmpty) {
        await prefs.setString('bg_last_emit_booking_id', bookingId.trim());
      } else {
        await prefs.remove('bg_last_emit_booking_id');
      }
    } catch (_) {}
  }

  void noteEmit(String event) {
    final emitNow = DateTime.now();
    final bool hadPrevEmit = lastEmitMetricAt != null;
    if (hadPrevEmit) {
      lastEmitGapMs = emitNow
          .difference(lastEmitMetricAt!)
          .inMilliseconds
          .clamp(0, 1 << 30);
    }

    // [track-gap] DIAGNOSTIC (hop 1/4: driver → server). Fires only when the
    // driver app resumes emitting after an anomalous silence (>3s) during an
    // ACTIVE booking — i.e. the moment the customer's marker would freeze. A
    // gap logged here means the DRIVER stopped sending (FGS throttled / stream
    // stalled / socket dropped during the Google-Maps handoff), localizing the
    // freeze to the device, not the server or customer. Warning-level so it
    // shows in release logcat during a repro; rare by construction (no spam).
    final bool hasActiveBooking =
        currentBookingId != null && currentBookingId!.trim().isNotEmpty;
    if (hadPrevEmit && hasActiveBooking && lastEmitGapMs > 3000) {
      CommonLogger.log.w(
        '[track-gap] hop=driver-emit gap_ms=$lastEmitGapMs event=$event '
        'seq=$clientSeq booking=${maskIdForLog(currentBookingId)} '
        'revoked=$sessionRevoked',
      );
    }

    lastEmitMetricAt = emitNow;
    emitCountWindow += 1;
    final now = emitNow;
    if (now.difference(emitWindowStartedAt) < const Duration(minutes: 1)) {
      return;
    }
    CommonLogger.log.i(
      '[BG_METRIC] emit_rate=$emitCountWindow/min '
      'last_gap_ms=$lastEmitGapMs '
      'event=$event bookingId=${maskIdForLog(currentBookingId)}',
    );
    emitWindowStartedAt = now;
    emitCountWindow = 0;
  }

  IO.Socket buildSocket(String url) {
    return IO.io(
      url,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .enableReconnection()
          .enableAutoConnect()
          .setReconnectionAttempts(999999)
          .setReconnectionDelay(1000)
          .setReconnectionDelayMax(8000)
          .setTimeout(15000)
          .build(),
    );
  }

  late IO.Socket socket;

  void safeRegisterAndFlush() {
    final did = driverId?.trim() ?? '';
    if (did.isNotEmpty) {
      socket.emit('register', {
        'userId': did,
        'type': 'driver',
        if (deviceId != null && deviceId.isNotEmpty) 'deviceId': deviceId,
        if (currentBookingId != null) 'bookingId': currentBookingId,
      });
    }

    final event = _pendingEvent;
    final payload = _pendingPayload;
    if (event != null && payload != null) {
      socket.emit(event, payload);
      noteEmit(event);
      unawaited(persistLastBgEmit(currentBookingId));
      _pendingEvent = null;
      _pendingPayload = null;
    }
  }

  void attachSocketListeners(IO.Socket activeSocket) {
    // C9: a bare `session-revoked` / namespace-disconnect must NOT permanently kill
    // background tracking mid-ride. The LEGITIMATE foreground reclaim sends an
    // explicit `stopService` action (which stopSelf()s this isolate). So when an
    // active ride exists we suppress reconnect (avoid revoke-war) but DEFER the
    // stop: if no explicit stopService arrives within the grace window, the
    // foreground is not actually tracking -> reclaim so the customer marker doesn't
    // freeze. Bounded by revokeReclaimAttempts so the service never runs forever.
    void handleSessionRevoke(String label) {
      sessionRevoked = true;
      try {
        activeSocket.disconnect();
      } catch (_) {}

      final hasActiveBooking =
          currentBookingId != null && currentBookingId!.trim().isNotEmpty;
      if (!hasActiveBooking || revokeReclaimAttempts >= 2) {
        // No active ride, or already reclaimed twice (foreground truly owns the
        // session) -> stop now (original behavior, bounded).
        try {
          service.stopSelf();
        } catch (_) {}
        return;
      }

      revokeGraceTimer?.cancel();
      revokeGraceTimer = Timer(const Duration(seconds: 8), () async {
        revokeGraceTimer = null;
        var stillActive = true;
        try {
          final prefs = await SharedPreferences.getInstance();
          stillActive = (prefs.getString('bg_ride_id') ?? '').trim().isNotEmpty;
        } catch (_) {}
        if (!stillActive) {
          // Ride completed / cancelled / cleared by foreground -> safe to stop.
          try {
            service.stopSelf();
          } catch (_) {}
          return;
        }
        // Ride still active and we were NOT explicitly stopped -> reclaim tracking.
        revokeReclaimAttempts += 1;
        sessionRevoked = false;
        CommonLogger.log.w(
          "[BG_SOCKET] Revoke grace elapsed, ride still active — reclaiming BG "
          "tracking (attempt $revokeReclaimAttempts) label=$label",
        );
        try {
          activeSocket.connect();
        } catch (_) {}
      });
    }

    activeSocket.onConnect((_) {
      if (!identical(activeSocket, socket)) return;
      safeRegisterAndFlush();
      CommonLogger.log.i("[BG_SOCKET] Connected ($socketUrl)");
    });

    activeSocket.onReconnect((_) {
      if (!identical(activeSocket, socket)) return;
      safeRegisterAndFlush();
      CommonLogger.log.i("[BG_SOCKET] Reconnected ($socketUrl)");
    });

    activeSocket.onDisconnect((reason) {
      if (!identical(activeSocket, socket)) return;
      CommonLogger.log.e(
        "[BG_SOCKET] Disconnected ($socketUrl) reason=$reason",
      );

      if (sessionRevoked) return;

      // Single-session revoke: the foreground app reclaimed the socket. Don't
      // reconnect (that revokes the foreground -> revoke-war). Stop this service.
      final rl = (reason?.toString() ?? '').toLowerCase();
      if (rl.contains('server namespace disconnect')) {
        CommonLogger.log.w(
          "[BG_SOCKET] Session revoked (namespace) — checking active ride before stop",
        );
        handleSessionRevoke('namespace-disconnect');
        return;
      }

      // If the server explicitly disconnects, socket.io may not auto-reconnect.
      // Try a debounced manual reconnect; re-register happens on connect.
      final now = DateTime.now();
      if (now.difference(_lastManualReconnectAt) >=
          const Duration(seconds: 2)) {
        _lastManualReconnectAt = now;
        activeSocket.connect();
      }
    });

    activeSocket.onConnectError((err) {
      if (!identical(activeSocket, socket)) return;
      CommonLogger.log.e("[BG_SOCKET] Connect error: $err ($socketUrl)");
    });

    // Explicit single-session signal from the backend (sent to the OLDER socket
    // just before it is disconnected). The foreground now owns the session, so
    // stop the background service instead of reconnecting and fighting it.
    activeSocket.on('session-revoked', (_) {
      if (!identical(activeSocket, socket)) return;
      CommonLogger.log.w(
        "[BG_SOCKET] session-revoked — checking active ride before stop",
      );
      handleSessionRevoke('session-revoked-event');
    });
  }

  Future<void> recreateSocket(String nextUrl) async {
    final normalized = nextUrl.trim();
    if (normalized.isEmpty) return;
    if (normalized == socketUrl && socket.connected) {
      safeRegisterAndFlush();
      return;
    }

    final previousUrl = socketUrl;
    socketUrl = normalized;

    try {
      socket.dispose();
    } catch (_) {
      try {
        socket.disconnect();
      } catch (_) {}
    }

    socket = buildSocket(socketUrl);
    attachSocketListeners(socket);
    socket.connect();

    CommonLogger.log.i(
      "[BG_SOCKET] Recreated socket oldUrl=$previousUrl newUrl=$socketUrl",
    );
  }

  Future<void> emitBootstrapPosition(String reason) async {
    final did = driverId?.trim() ?? '';
    if (did.isEmpty) return;

    // FAST BRIDGE: getCurrentPosition(bestForNavigation) below waits 1-3s for a
    // fresh high-accuracy fix. During the foreground→background handoff (driver
    // tapping "Navigate to Pickup") that wait IS the gap that freezes the
    // customer's marker — it exceeds the 2.5s dead-reckon window, so the car
    // freezes then jumps. So first emit the last-known cached fix INSTANTLY
    // (the foreground was streaming at ~1s right up to the handoff, so it's very
    // recent), keeping the customer's stream alive within ms. We stamp it `now`
    // so the customer's strict timestamp ordering always accepts it (never
    // dropped as stale/out-of-order); the fresh fix below then corrects it.
    if (currentBookingId != null && currentBookingId!.trim().isNotEmpty) {
      try {
        final last = await Geolocator.getLastKnownPosition();
        if (last != null) {
          final accFast = last.accuracy.isFinite ? last.accuracy : 9999.0;
          if (accFast <= maxAccuracyM) {
            final nowFast = DateTime.now();
            final fastSpeed =
                (last.speed.isFinite && last.speed >= 0) ? last.speed : 0.0;
            if (fastSpeed >= 1.0 &&
                last.heading.isFinite &&
                last.heading >= 0) {
              lastEmitBearing = last.heading;
            }
            lastLat = last.latitude;
            lastLng = last.longitude;
            lastEmitAt = nowFast;
            final fastData = <String, dynamic>{
              'userId': did,
              'driverId': did,
              'latitude': last.latitude,
              'longitude': last.longitude,
              'lat': last.latitude,
              'lng': last.longitude,
              if (lastEmitBearing != null) 'bearing': lastEmitBearing,
              'speed': last.speed,
              'accuracy': last.accuracy,
              'bookingId': currentBookingId,
              'rideId': currentBookingId,
              'seq': nextClientSeq(),
              // Stamp NOW (not the cached fix time) so it's never out-of-order.
              'timestamp': nowFast.toUtc().toIso8601String(),
              'deviceTimestamp': nowFast.toUtc().toIso8601String(),
              'clientSentAt': nowFast.toUtc().toIso8601String(),
            };
            if (socket.connected) {
              socket.emit('updateLocation', fastData);
              noteEmit('updateLocation');
              unawaited(persistLastBgEmit(currentBookingId));
            } else {
              // COLD START: the socket (created moments ago in onStart) is still
              // connecting. Queue the cached fix as the pending payload so the
              // onConnect handler (safeRegisterAndFlush) emits it the INSTANT the
              // socket connects — well before the getCurrentPosition fix below.
              // This makes the background's first emit (and `bg_last_emit_at`)
              // land at ~socket-connect time, so the foreground hand-off sees the
              // background as alive quickly and the customer's marker never goes
              // dark when the driver opens Google Maps.
              _pendingEvent = 'updateLocation';
              _pendingPayload = fastData;
            }
            if (kDebugMode) {
              CommonLogger.log.i(
                '[BG_SOCKET_EMIT] event=updateLocation '
                'bookingId=${maskIdForLog(currentBookingId)} '
                'seq=${fastData['seq']} source=$reason-bridge '
                'connected=${socket.connected}',
              );
            }
          }
        }
      } catch (_) {}
    }

    try {
      final now = DateTime.now();
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          // Bound the read so a struggling GPS chip can't hang this poll/bootstrap
          // for tens of seconds (which froze the feed, then jumped on recovery).
          timeLimit: Duration(seconds: 8),
        ),
      );
      // FRAUD (CRIT-5): drop mock/fake-GPS fixes in the background path too, so a driver
      // can't spoof location while the app is backgrounded. Report once so the server flags it.
      if (position.isMocked) {
        try {
          if (socket.connected) {
            socket.emit('driver-integrity', {
              'driverId': driverId,
              if (currentBookingId != null) 'bookingId': currentBookingId,
              'mock': true,
              'source': 'background',
            });
          }
        } catch (_) {}
        return;
      }

      final acc = position.accuracy.isFinite ? position.accuracy : 9999.0;
      if (acc > maxAccuracyM) return;

      final speedMs =
          (position.speed.isFinite && position.speed >= 0)
              ? position.speed
              : 0.0;
      if (speedMs >= 1.0 &&
          position.heading.isFinite &&
          position.heading >= 0) {
        lastEmitBearing = position.heading;
      }

      lastLat = position.latitude;
      lastLng = position.longitude;
      lastEmitAt = now;

      final locationData = <String, dynamic>{
        'userId': did,
        'driverId': did,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'lat': position.latitude,
        'lng': position.longitude,
        if (lastEmitBearing != null) 'bearing': lastEmitBearing,
        'speed': position.speed,
        'accuracy': position.accuracy,
        if (currentBookingId != null) 'bookingId': currentBookingId,
        if (currentBookingId != null) 'rideId': currentBookingId,
        'seq': nextClientSeq(),
        'timestamp': position.timestamp.toUtc().toIso8601String(),
        'deviceTimestamp': position.timestamp.toUtc().toIso8601String(),
        'clientSentAt': now.toUtc().toIso8601String(),
      };

      if (!socket.connected) {
        _pendingEvent = 'updateLocation';
        _pendingPayload = locationData;
        socket.connect();
      } else {
        socket.emit('updateLocation', locationData);
        noteEmit('updateLocation');
        unawaited(persistLastBgEmit(currentBookingId));
      }

      if (kDebugMode) {
        CommonLogger.log.i(
          '[BG_SOCKET_EMIT] event=updateLocation '
          'bookingId=${maskIdForLog(currentBookingId)} seq=${locationData['seq']} '
          'source=$reason',
        );
      }
    } catch (_) {}
  }

  socket = buildSocket(socketUrl);
  attachSocketListeners(socket);
  socket.connect();

  Timer? heartbeatTimer;
  service.on('data').listen((event) async {
    if (event == null) return;

    if (event['action'] == 'stopService') {
      revokeGraceTimer?.cancel(); // C9: explicit foreground stop overrides grace
      heartbeatTimer?.cancel();
      pollTimer?.cancel();
      unawaited(positionSub?.cancel());
      socket.disconnect();
      service.stopSelf();
    }

    var shouldRefreshRegistration = false;

    final nextSocketUrl = event['socketUrl']?.toString().trim() ?? '';
    if (nextSocketUrl.isNotEmpty && nextSocketUrl != socketUrl) {
      shouldRefreshRegistration = true;
      await recreateSocket(nextSocketUrl);
    }

    if (event.containsKey('bookingId')) {
      final nextBookingId = event['bookingId']?.toString();
      if (nextBookingId != currentBookingId) {
        currentBookingId = nextBookingId;
        shouldRefreshRegistration = true;
        try {
          final prefs = await SharedPreferences.getInstance();
          if (nextBookingId != null && nextBookingId.trim().isNotEmpty) {
            await prefs.setString('bg_ride_id', nextBookingId.trim());
          } else {
            await prefs.remove('bg_ride_id');
          }
        } catch (_) {}
      }
    }

    if (event.containsKey('driverId')) {
      final nextDriverId = event['driverId']?.toString();
      if (nextDriverId != driverId) {
        driverId = nextDriverId;
        shouldRefreshRegistration = true;
        try {
          final prefs = await SharedPreferences.getInstance();
          if (nextDriverId != null && nextDriverId.trim().isNotEmpty) {
            await prefs.setString('bg_driver_id', nextDriverId.trim());
          } else {
            await prefs.remove('bg_driver_id');
          }
        } catch (_) {}
      }
    }

    if (shouldRefreshRegistration) {
      if (socket.connected) {
        safeRegisterAndFlush();
      } else {
        socket.connect();
      }
      if (currentBookingId != null && currentBookingId!.trim().isNotEmpty) {
        unawaited(emitBootstrapPosition('booking_refresh'));
      }
    }
  });

  // CRITICAL (Android): base `LocationSettings` leaves geolocator on its DEFAULT
  // 5000ms fused-provider interval, so while the driver is navigating in Google
  // Maps (this FGS owns the feed) the customer only got a fix every ~5s -> a
  // jittery, freezing marker. `AndroidSettings.intervalDuration` requests ~1Hz
  // fixes so the customer keeps a smooth glide. The emit gates below (1s min,
  // movement/jitter filters) still bound chatter and protect battery. iOS keeps
  // base settings (it already streams at the accuracy/distanceFilter rate).
  final LocationSettings bgLocationSettings =
      Platform.isAndroid
          ? AndroidSettings(
            accuracy: LocationAccuracy.bestForNavigation,
            distanceFilter: 0,
            intervalDuration: const Duration(seconds: 1),
          )
          : const LocationSettings(
            accuracy: LocationAccuracy.bestForNavigation,
            // Keep fixes flowing even in crawl / U-turn / parking-lot movement
            // while Google Maps is foregrounded.
            distanceFilter: 0,
          );

  positionSub = Geolocator.getPositionStream(
    locationSettings: bgLocationSettings,
  ).listen((position) {
    if (driverId == null || driverId!.trim().isEmpty) return;

    final now = DateTime.now();
    // Freshness guard (skew-immune: same device clock for `now` and the fix).
    // Drop a stale/buffered fix so we never relay the driver's old position; a
    // backlog burst is discarded and only the current fix reaches the customer.
    if (now.difference(position.timestamp) > _bgMaxFixAge) {
      return;
    }
    if (now.difference(lastEmitAt) < minEmitInterval) return;

    final acc = position.accuracy.isFinite ? position.accuracy : 9999.0;
    if (acc > maxAccuracyM) return;

    final double? movedSinceLast =
        (lastLat != null && lastLng != null)
            ? Geolocator.distanceBetween(
              lastLat!,
              lastLng!,
              position.latitude,
              position.longitude,
            )
            : null;

    if (movedSinceLast != null) {
      final speedMs =
          (position.speed.isFinite && position.speed >= 0)
              ? position.speed
              : 0.0;

      if (speedMs < 1.0 &&
          movedSinceLast >= stationaryJumpM &&
          acc > jumpAcceptAccuracyM) {
        return;
      }

      double driftGate = 8.0;
      final adaptive = (acc * 0.8).clamp(0.0, 20.0);
      if (adaptive > driftGate) driftGate = adaptive;
      if (speedMs < 1.0 && movedSinceLast < driftGate) return;
    }

    lastLat = position.latitude;
    lastLng = position.longitude;
    lastEmitAt = now;

    // Hold heading unless genuinely moving (mirrors the foreground bearing
    // gate). Below ~1 m/s GPS heading is noise; sending raw per-fix heading
    // spun the customer's car icon while the driver was stopped.
    final double bgSpeedMs =
        (position.speed.isFinite && position.speed >= 0) ? position.speed : 0.0;
    if (bgSpeedMs >= 1.0 &&
        position.heading.isFinite &&
        position.heading >= 0) {
      lastEmitBearing = position.heading;
    }

    // Trust position over GPS-reported speed (mirrors the foreground emit): if
    // the car barely moved since the last emitted fix, send speed 0 so the
    // customer holds the marker instead of dead-reckoning it forward on a
    // phantom speed. See [_bgStationaryEmitMeters].
    final double bgEmitSpeed =
        (movedSinceLast != null && movedSinceLast < _bgStationaryEmitMeters)
            ? 0.0
            : bgSpeedMs;

    final locationData = {
      'userId': driverId,
      'driverId': driverId,
      // Keep legacy keys used by backend/customer app.
      'latitude': position.latitude,
      'longitude': position.longitude,
      // Add common aliases for compatibility with other clients.
      'lat': position.latitude,
      'lng': position.longitude,
      // Omit when null so the backend (which gates bearing by speed) treats it
      // as "no heading" and keeps the last good one — never sends 0/north.
      if (lastEmitBearing != null) 'bearing': lastEmitBearing,
      'speed': bgEmitSpeed,
      'accuracy': position.accuracy,
      if (currentBookingId != null) 'bookingId': currentBookingId,
      if (currentBookingId != null) 'rideId': currentBookingId,
      'seq': nextClientSeq(),
      // Device GPS fix time in UTC (not local send-time) for correct ordering.
      'timestamp': position.timestamp.toUtc().toIso8601String(),
      'deviceTimestamp': position.timestamp.toUtc().toIso8601String(),
      'clientSentAt': now.toUtc().toIso8601String(),
    };
    if (!socket.connected) {
      _pendingEvent = 'updateLocation';
      _pendingPayload = locationData;
      socket.connect();
    } else {
      socket.emit('updateLocation', locationData);
      noteEmit('updateLocation');
      unawaited(persistLastBgEmit(currentBookingId));
    }

    // Mirror to the UI isolate (so screens can refresh immediately on return).
    // This is best-effort; if the UI isolate is not active, this is ignored.
    try {
      service.invoke('locationUpdate', {
        'lat': position.latitude,
        'lng': position.longitude,
        'bearing': lastEmitBearing ?? position.heading,
        'speed': bgEmitSpeed,
        'accuracy': position.accuracy,
        if (currentBookingId != null) 'bookingId': currentBookingId,
        if (driverId != null) 'driverId': driverId,
        'timestamp': now.toIso8601String(),
      });
    } catch (_) {}

    if (kDebugMode) {
      CommonLogger.log.i(
        '[BG_SOCKET_EMIT] event=updateLocation '
        'bookingId=${maskIdForLog(currentBookingId)} seq=${locationData['seq']}',
      );
    }
  }, onError: (Object e, StackTrace st) {
    // CRASH FIX: a denied/revoked location permission emits a stream error in
    // the background isolate. Without onError it became an unhandled crash.
    // Swallow it so the background service stays alive.
    if (kDebugMode) CommonLogger.log.w('bg location stream error: $e');
  }, cancelOnError: false);

  if (currentBookingId != null && currentBookingId!.trim().isNotEmpty) {
    unawaited(emitBootstrapPosition('startup'));
  }

  // If the stream doesn't emit (driver stationary / OEM throttling), poll and emit
  // periodically so the server still receives location while driver is online.
  pollTimer = Timer.periodic(_bgActiveTripPollInterval, (_) async {
    if (driverId == null || driverId!.trim().isEmpty) return;

    final now = DateTime.now();
    final hasActiveBooking =
        currentBookingId != null && currentBookingId!.trim().isNotEmpty;
    final minEmitGap =
        hasActiveBooking ? _bgActiveTripMinEmitGap : _bgIdleMinEmitGap;
    if (now.difference(lastEmitAt) < minEmitGap) return;

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          // Bound the read so a struggling GPS chip can't hang this poll/bootstrap
          // for tens of seconds (which froze the feed, then jumped on recovery).
          timeLimit: Duration(seconds: 8),
        ),
      );

      final acc = position.accuracy.isFinite ? position.accuracy : 9999.0;
      if (acc > maxAccuracyM) return;

      final prevLat = lastLat;
      final prevLng = lastLng;

      lastLat = position.latitude;
      lastLng = position.longitude;
      lastEmitAt = now;

      final movedMeters =
          (prevLat == null || prevLng == null)
              ? null
              : Geolocator.distanceBetween(
                prevLat,
                prevLng,
                position.latitude,
                position.longitude,
              );
      final speedMs =
          (position.speed.isFinite && position.speed >= 0)
              ? position.speed
              : 0.0;
      final isMoving =
          (movedMeters != null && movedMeters >= 5.0) || speedMs >= 0.6;

      // Hold heading unless genuinely moving (mirrors the foreground gate).
      if (speedMs >= 1.0 &&
          position.heading.isFinite &&
          position.heading >= 0) {
        lastEmitBearing = position.heading;
      }

      // Trust position over GPS-reported speed (mirrors the foreground emit):
      // send speed 0 when the car barely moved since the last emitted fix, so
      // the customer holds the marker instead of dead-reckoning a phantom
      // speed. See [_bgStationaryEmitMeters].
      final double pollEmitSpeed =
          (movedMeters != null && movedMeters < _bgStationaryEmitMeters)
              ? 0.0
              : speedMs;

      final locationData = {
        'userId': driverId,
        'driverId': driverId,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'lat': position.latitude,
        'lng': position.longitude,
        if (lastEmitBearing != null) 'bearing': lastEmitBearing,
        'speed': pollEmitSpeed,
        'accuracy': position.accuracy,
        if (currentBookingId != null) 'bookingId': currentBookingId,
        if (currentBookingId != null) 'rideId': currentBookingId,
        'seq': nextClientSeq(),
        // Device GPS fix time in UTC (consistent with the stream emit) so the
        // customer's strict ordering doesn't drop these as "out of order".
        'timestamp': position.timestamp.toUtc().toIso8601String(),
        'deviceTimestamp': position.timestamp.toUtc().toIso8601String(),
        'clientSentAt': now.toUtc().toIso8601String(),
      };

      final eventName =
          hasActiveBooking
              ? 'updateLocation'
              : (isMoving ? 'updateLocation' : 'driver-heartbeat');
      if (!socket.connected) {
        _pendingEvent = eventName;
        _pendingPayload = locationData;
        socket.connect();
      } else {
        socket.emit(eventName, locationData);
        noteEmit(eventName);
        unawaited(persistLastBgEmit(currentBookingId));
      }

      try {
        service.invoke('locationUpdate', {
          'lat': position.latitude,
          'lng': position.longitude,
          'bearing': lastEmitBearing ?? position.heading,
          'speed': pollEmitSpeed,
          'accuracy': position.accuracy,
          if (currentBookingId != null) 'bookingId': currentBookingId,
          if (driverId != null) 'driverId': driverId,
          'timestamp': now.toIso8601String(),
        });
      } catch (_) {}

      if (kDebugMode) {
        CommonLogger.log.i(
          '[BG_SOCKET_EMIT] event=$eventName '
          'bookingId=${maskIdForLog(currentBookingId)} seq=${locationData['seq']} '
          'source=poll',
        );
      }
    } catch (_) {}
  });

  // NOTE: Don't call `FlutterBackgroundService().isRunning()` from the
  // background isolate. It can throw `MissingPluginException` on some devices /
  // builds because the method-channel implementation may not be registered in
  // this isolate. If the service stops, the isolate/timer is torn down anyway.
  heartbeatTimer = Timer.periodic(const Duration(minutes: 15), (_) {
    service.invoke('heartbeat', {'time': DateTime.now().toIso8601String()});
  });
}
