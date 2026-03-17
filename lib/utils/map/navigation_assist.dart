import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NavigationAssist {
  NavigationAssist._();

  static IconData iconForManeuver(
    String maneuver, {
    String directionText = '',
  }) {
    final m = maneuver.toLowerCase();
    if (m.contains('uturn') || m.contains('u-turn')) return Icons.u_turn_left;
    if (m.contains('roundabout')) return Icons.roundabout_right;
    if (m.contains('right')) return Icons.turn_right;
    if (m.contains('left')) return Icons.turn_left;
    if (m.contains('merge')) return Icons.merge;
    if (m.contains('fork')) return Icons.call_split;
    if (m.contains('ramp')) return Icons.alt_route;

    // Fallback when maneuver from API is empty/ambiguous.
    final d = stripHtml(directionText).toLowerCase();
    if (d.contains('u-turn') || d.contains('uturn')) return Icons.u_turn_left;
    if (d.contains('roundabout')) return Icons.roundabout_right;
    if (d.contains('slight left') || d.contains('keep left')) {
      return Icons.turn_slight_left;
    }
    if (d.contains('slight right') || d.contains('keep right')) {
      return Icons.turn_slight_right;
    }
    if (d.contains('right')) return Icons.turn_right;
    if (d.contains('left')) return Icons.turn_left;

    return Icons.straight;
  }

  static String stripHtml(String s) {
    var text = s
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&');

    text = text.replaceAll(
      RegExp(r'\(\s*on the (left|right)\s*\)', caseSensitive: false),
      '',
    );

    return text.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static String buildVoiceLine({
    required String maneuver,
    required String distanceText,
    required String directionText,
  }) {
    final cleanDirection = stripHtml(directionText).trim();
    final cleanDistance = distanceText.trim();
    if (cleanDirection.isNotEmpty && cleanDistance.isNotEmpty) {
      return '$cleanDistance, $cleanDirection';
    }
    if (cleanDirection.isNotEmpty) return cleanDirection;
    if (cleanDistance.isNotEmpty) return '$cleanDistance ahead';
    final m = maneuver.toLowerCase();
    if (m.contains('right')) return 'Turn right ahead';
    if (m.contains('left')) return 'Turn left ahead';
    return 'Continue straight';
  }
}

class DriverAnalyticsController extends GetxController {
  static const String _kOffers = 'driver_analytics_offers';
  static const String _kAccepts = 'driver_analytics_accepts';
  static const String _kDeclines = 'driver_analytics_declines';
  static const String _kCancellations = 'driver_analytics_cancellations';
  static const String _kCompletions = 'driver_analytics_completions';
  static const String _kActiveTrips = 'driver_analytics_active_trips';
  static const String _kPickups = 'driver_analytics_pickups';
  static const String _kOnTimePickups = 'driver_analytics_on_time_pickups';
  static const String _kNoShows = 'driver_analytics_no_shows';
  static const String _kEarnings = 'driver_analytics_earnings';
  static const String _kOnlineHours = 'driver_analytics_online_hours';

  SharedPreferences? _prefs;

  final RxInt offers = 0.obs;
  final RxInt accepts = 0.obs;
  final RxInt declines = 0.obs;
  final RxInt cancellations = 0.obs;
  final RxInt completions = 0.obs;
  final RxInt activeTrips = 0.obs;
  final RxInt pickups = 0.obs;
  final RxInt onTimePickups = 0.obs;
  final RxInt noShows = 0.obs;
  final RxDouble earnings = 0.0.obs;
  final RxDouble onlineHours = 0.0.obs;
  final RxString slaAlert = ''.obs;

  final Set<String> _declinedBookingIds = <String>{};
  final Set<String> _cancelledBookingIds = <String>{};

  @override
  void onInit() {
    super.onInit();
    _restoreFromLocal();
  }

  Future<void> _restoreFromLocal() async {
    _prefs = await SharedPreferences.getInstance();
    final prefs = _prefs;
    if (prefs == null) return;

    // Merge persisted values with any in-memory increments that happened
    // before restore completes.
    offers.value += prefs.getInt(_kOffers) ?? 0;
    accepts.value += prefs.getInt(_kAccepts) ?? 0;
    declines.value += prefs.getInt(_kDeclines) ?? 0;
    cancellations.value += prefs.getInt(_kCancellations) ?? 0;
    completions.value += prefs.getInt(_kCompletions) ?? 0;
    activeTrips.value += prefs.getInt(_kActiveTrips) ?? 0;
    pickups.value += prefs.getInt(_kPickups) ?? 0;
    onTimePickups.value += prefs.getInt(_kOnTimePickups) ?? 0;
    noShows.value += prefs.getInt(_kNoShows) ?? 0;
    earnings.value += prefs.getDouble(_kEarnings) ?? 0.0;
    onlineHours.value += prefs.getDouble(_kOnlineHours) ?? 0.0;

    await _persistSnapshot();
  }

  Future<void> _persistSnapshot() async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs = prefs;
    await prefs.setInt(_kOffers, offers.value);
    await prefs.setInt(_kAccepts, accepts.value);
    await prefs.setInt(_kDeclines, declines.value);
    await prefs.setInt(_kCancellations, cancellations.value);
    await prefs.setInt(_kCompletions, completions.value);
    await prefs.setInt(_kActiveTrips, activeTrips.value);
    await prefs.setInt(_kPickups, pickups.value);
    await prefs.setInt(_kOnTimePickups, onTimePickups.value);
    await prefs.setInt(_kNoShows, noShows.value);
    await prefs.setDouble(_kEarnings, earnings.value);
    await prefs.setDouble(_kOnlineHours, onlineHours.value);
  }

  void trackOffer() {
    offers.value++;
    _persistSnapshot();
  }

  void trackAccept() {
    accepts.value++;
    activeTrips.value++;
    _persistSnapshot();
  }

  void trackDecline({String? bookingId}) {
    final id = bookingId?.trim();
    if (id != null && id.isNotEmpty) {
      if (_declinedBookingIds.contains(id)) return;
      _declinedBookingIds.add(id);
    }
    declines.value++;
    _persistSnapshot();
  }

  void trackCancel({String? bookingId}) {
    final id = bookingId?.trim();
    if (id != null && id.isNotEmpty) {
      if (_cancelledBookingIds.contains(id)) return;
      _cancelledBookingIds.add(id);
    }
    cancellations.value++;
    if (activeTrips.value > 0) activeTrips.value--;
    _persistSnapshot();
  }

  void trackComplete() {
    completions.value++;
    if (activeTrips.value > 0) activeTrips.value--;
    _persistSnapshot();
  }

  void trackPickup({required bool onTime}) {
    pickups.value++;
    if (onTime) onTimePickups.value++;
    _persistSnapshot();
  }

  void trackNoShow() {
    noShows.value++;
    _persistSnapshot();
  }

  void trackEarning(num value) {
    earnings.value += value.toDouble();
    _persistSnapshot();
  }

  void trackOnlineTick(Duration delta) {
    onlineHours.value += (delta.inSeconds / 3600.0);
    _persistSnapshot();
  }

  double get acceptanceRate =>
      offers.value == 0 ? 0 : (accepts.value / offers.value) * 100.0;
  double get declineRate =>
      offers.value == 0 ? 0 : (declines.value / offers.value) * 100.0;
  double get responseRate =>
      offers.value == 0
          ? 0
          : ((accepts.value + declines.value) / offers.value) * 100.0;
  double get cancellationRate {
    final denominator = completions.value + cancellations.value;
    if (denominator == 0) return 0;
    return (cancellations.value / denominator) * 100.0;
  }

  double get onTimePickupRate =>
      pickups.value == 0 ? 0 : (onTimePickups.value / pickups.value) * 100.0;

  double get earningsPerHour {
    final h = onlineHours.value <= 0 ? 1.0 : onlineHours.value;
    return earnings.value / h;
  }

  int get missedOpportunities => declines.value + cancellations.value;

  double get completionEfficiency {
    final resolved = completions.value + cancellations.value;
    if (resolved == 0) return 0;
    return (completions.value / resolved) * 100.0;
  }

  String get declineHealth {
    if (declineRate <= 10) return 'Good';
    if (declineRate <= 20) return 'Watch';
    return 'Critical';
  }

  String get cancelHealth {
    if (cancellationRate <= 5) return 'Good';
    if (cancellationRate <= 10) return 'Watch';
    return 'Critical';
  }

  Future<void> reset({bool clearPersisted = true}) async {
    offers.value = 0;
    accepts.value = 0;
    declines.value = 0;
    cancellations.value = 0;
    completions.value = 0;
    activeTrips.value = 0;
    pickups.value = 0;
    onTimePickups.value = 0;
    noShows.value = 0;
    earnings.value = 0.0;
    onlineHours.value = 0.0;
    slaAlert.value = '';
    _declinedBookingIds.clear();
    _cancelledBookingIds.clear();

    if (!clearPersisted) return;

    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs = prefs;
    await prefs.remove(_kOffers);
    await prefs.remove(_kAccepts);
    await prefs.remove(_kDeclines);
    await prefs.remove(_kCancellations);
    await prefs.remove(_kCompletions);
    await prefs.remove(_kActiveTrips);
    await prefs.remove(_kPickups);
    await prefs.remove(_kOnTimePickups);
    await prefs.remove(_kNoShows);
    await prefs.remove(_kEarnings);
    await prefs.remove(_kOnlineHours);
  }

  void setSlaFromEtaMinutes(double etaMinutes, {double threshold = 12}) {
    if (etaMinutes >= threshold) {
      slaAlert.value =
          'High ETA delay ($etaMinutes min). Suggest: quick message/call rider.';
      Get.snackbar(
        'SLA Alert',
        slaAlert.value,
        snackPosition: SnackPosition.TOP,
        duration: const Duration(seconds: 3),
      );
    } else {
      slaAlert.value = '';
    }
  }
}
