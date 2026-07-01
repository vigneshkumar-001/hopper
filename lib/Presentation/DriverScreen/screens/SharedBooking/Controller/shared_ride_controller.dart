import 'package:action_slider/action_slider.dart';
import 'package:geocoding/geocoding.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hopper/Core/Services/log_manager.dart';

enum SharedRiderStage {
  waitingPickup, // not in car yet
  onboardDrop, // in car, need to drop
  dropped, // finished
}

class SharedRiderItem {
  final String bookingId;

  String name;
  String phone;
  String profilePic;

  String pickupAddress;
  String dropoffAddress;

  num amount;

  /// How many seats THIS booking reserved (a single customer can book 2-4).
  /// Drives the driver's occupied/free seat count (sum of seats, not riders).
  int seatCount;

  /// The exact seat numbers this booking occupies (e.g. [3, 4]) so the driver's
  /// car layout shows the SAME seats the customer picked. Empty until known.
  List<int> seatNumbers;

  final LatLng pickupLatLng;
  final LatLng dropLatLng;

  // UI state
  bool arrived;
  int secondsLeft;
  final ActionSliderController sliderController;
  SharedRiderStage stage;

  /// True when THIS passenger cancelled their own seat. We keep the rider in the
  /// list (so the driver sees a disabled "Cancelled by customer" card) but treat
  /// them as inactive for routing/targeting.
  bool cancelledByCustomer;

  /// Reason the customer gave when cancelling — shown on the disabled card.
  String cancelReason;

  /// Customer-authored "Directions to reach" note. Empty until the customer adds
  /// one; updated live via the `pickup_instruction_updated` socket event.
  String pickupInstruction;

  SharedRiderItem({
    required this.bookingId,
    required this.name,
    required this.phone,
    required this.profilePic,
    required this.pickupAddress,
    required this.dropoffAddress,
    required this.amount,
    required this.pickupLatLng,
    required this.dropLatLng,
    this.seatCount = 1,
    this.seatNumbers = const [],
    this.arrived = false,
    this.secondsLeft = 0,
    this.stage = SharedRiderStage.waitingPickup,
    this.cancelledByCustomer = false,
    this.cancelReason = '',
    this.pickupInstruction = '',
    ActionSliderController? sliderController,
  }) : sliderController = sliderController ?? ActionSliderController();

  String get firstName {
    final parts = name.trim().split(' ');
    return parts.isNotEmpty && parts[0].isNotEmpty ? parts[0] : 'Guest';
  }
}

class SharedRideController extends GetxController {
  /// All riders in this shared/pooled booking
  final RxList<SharedRiderItem> riders = <SharedRiderItem>[].obs;

  /// Current target (pickup or drop)
  final Rxn<SharedRiderItem> activeTarget = Rxn<SharedRiderItem>();

  /// Latest driver location
  final Rxn<LatLng> driverLocation = Rxn<LatLng>();

  // -------------------- radius gates (UI only) --------------------
  // The "Arrived" button arms only when the driver is genuinely AT the pickup —
  // within 150 m. (Was 500 m, which let "Arrived" show from far away.) The exit
  // radius is wider (hysteresis) so GPS jitter near the boundary doesn't flicker
  // the button: once shown at ≤150 m it stays until the driver moves past 230 m.
  static const double _ARRIVED_PICKUP_RADIUS_M = 150.0;
  static const double _ARRIVED_PICKUP_EXIT_RADIUS_M = 230.0; // hysteresis
  static const double _COMPLETE_DROP_RADIUS_M = 200.0;
  static const double _COMPLETE_DROP_EXIT_RADIUS_M = 320.0; // hysteresis

  /// Show Arrived CTA only when driver is near active pickup.
  final RxBool canArriveAtActivePickup = false.obs;

  /// Show Complete Stop CTA only when driver is near active drop.
  final RxBool canCompleteActiveDrop = false.obs;

  // -------------------- helpers --------------------

  double _safeToDouble(dynamic v) {
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }

  String _safeString(dynamic v) => (v ?? '').toString();

  /// Resolve the customer's display name from the many shapes the backend may
  /// send it in (shared-ride payloads are not always consistent). Returns an
  /// empty string when nothing usable is found so callers can decide on a
  /// fallback without clobbering an already-known name.
  String _resolveCustomerName(Map data) {
    String pick(dynamic v) => _safeString(v).trim();

    final direct = [
      data['customerName'],
      data['name'],
      data['userName'],
      data['fullName'],
      data['passengerName'],
    ];
    for (final c in direct) {
      final s = pick(c);
      if (s.isNotEmpty) return s;
    }

    // first + last name pair
    final first = pick(data['firstName']);
    final last = pick(data['lastName']);
    final joined = [first, last].where((s) => s.isNotEmpty).join(' ').trim();
    if (joined.isNotEmpty) return joined;

    // nested customer / user objects
    for (final key in ['customer', 'user', 'passenger']) {
      final nested = data[key];
      if (nested is Map) {
        final n = pick(nested['name']);
        if (n.isNotEmpty) return n;
        final f = pick(nested['firstName']);
        final l = pick(nested['lastName']);
        final j = [f, l].where((s) => s.isNotEmpty).join(' ').trim();
        if (j.isNotEmpty) return j;
      }
    }
    return '';
  }

  Future<String> _addressFromLatLng(double lat, double lng) async {
    try {
      final placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isEmpty) return "Location not available";
      final p = placemarks.first;
      final name = (p.name ?? '').trim();
      final locality = (p.locality ?? '').trim();
      final admin = (p.administrativeArea ?? '').trim();

      final parts = <String>[
        if (name.isNotEmpty) name,
        if (locality.isNotEmpty) locality,
        if (admin.isNotEmpty) admin,
      ];

      return parts.isEmpty ? "Location not available" : parts.join(', ');
    } catch (_) {
      return "Location not available";
    }
  }

  // -------------------- CRUD / UPDATE FROM SOCKET --------------------
  /// ✅ IMPORTANT:
  /// Your socket payload does NOT contain pickupAddress/dropoffAddress.
  /// So we:
  /// - use keys if present (pickupLocationAddress/dropLocationAddress)
  /// - else reverse-geocode fromLatLng and dropLatLng
  Future<void> upsertFromSocket(Map<String, dynamic> data) async {
    final bookingIdStr = _safeString(data['bookingId']).trim();
    if (bookingIdStr.isEmpty) return;

    final customerLoc = data['customerLocation'];
    if (customerLoc == null || customerLoc is! Map) return;

    final fromLat = _safeToDouble(customerLoc['fromLatitude']);
    final fromLng = _safeToDouble(customerLoc['fromLongitude']);
    final toLat = _safeToDouble(customerLoc['toLatitude']);
    final toLng = _safeToDouble(customerLoc['toLongitude']);

    if (fromLat == 0 || fromLng == 0 || toLat == 0 || toLng == 0) {
      // invalid coordinates
      return;
    }

    final resolvedName = _resolveCustomerName(data);
    final customerPhone = _safeString(data['customerPhone']);
    final customerProfilePic = _safeString(data['customerProfilePic']);
    final amount = (data['amount'] is num) ? (data['amount'] as num) : 0;

    // How many seats this booking reserved, and the exact seat numbers (e.g.
    // [3,4]) so the driver shows the SAME seats the customer picked.
    final dynamic rawSeatCount =
        data['seatCount'] ?? data['sharedCount'] ?? data['numberOfSeats'];
    int parsedSeatCount = int.tryParse((rawSeatCount ?? '').toString()) ?? 0;

    final List<int> parsedSeatNumbers = <int>[];
    final seatsRaw = data['seats'];
    if (seatsRaw is List) {
      for (final e in seatsRaw) {
        final n = int.tryParse(e.toString());
        if (n != null && n > 0) parsedSeatNumbers.add(n);
      }
    }
    if (parsedSeatCount <= 0 && parsedSeatNumbers.isNotEmpty) {
      parsedSeatCount = parsedSeatNumbers.length;
    }
    if (parsedSeatCount <= 0) parsedSeatCount = 1;

    // ✅ Support both formats (if backend sends later)
    String pickupAddrs = _safeString(
      data['pickupLocationAddress'] ?? data['pickupAddress'],
    );
    String dropoffAddrs = _safeString(
      data['dropLocationAddress'] ?? data['dropoffAddress'],
    );
    // Customer's "Directions to reach" note (shown on the driver pickup card).
    final String parsedInstr = _safeString(data['pickupInstruction']);

    // ✅ fallback: reverse geocode if empty
    if (pickupAddrs.trim().isEmpty) {
      pickupAddrs = await _addressFromLatLng(fromLat, fromLng);
    }
    if (dropoffAddrs.trim().isEmpty) {
      dropoffAddrs = await _addressFromLatLng(toLat, toLng);
    }

    final idx = riders.indexWhere((r) => r.bookingId == bookingIdStr);

    if (idx >= 0) {
      final r = riders[idx];
      r
        // Never overwrite a known name with an empty payload.
        ..name = resolvedName.isNotEmpty ? resolvedName : r.name
        ..phone = customerPhone
        ..profilePic = customerProfilePic
        ..pickupAddress = pickupAddrs
        ..dropoffAddress = dropoffAddrs
        // Don't overwrite a known instruction with an empty payload.
        ..pickupInstruction =
            parsedInstr.isNotEmpty ? parsedInstr : r.pickupInstruction
        ..amount = amount
        // Keep a known multi-seat count; never downgrade to 1 on a thin payload.
        ..seatCount = parsedSeatCount > 1 ? parsedSeatCount : r.seatCount
        // Keep known seat numbers if this payload doesn't carry them.
        ..seatNumbers =
            parsedSeatNumbers.isNotEmpty ? parsedSeatNumbers : r.seatNumbers;

      riders.refresh();

      // 📊 Log rider update
      logManager.logRider(
        action: 'RIDER_UPDATED',
        bookingId: bookingIdStr,
        riderData: {
          'name': r.name,
          'phone': customerPhone,
          'pickup': pickupAddrs,
          'dropoff': dropoffAddrs,
        },
      );
    } else {
      final newRider = SharedRiderItem(
        bookingId: bookingIdStr,
        name: resolvedName.isNotEmpty ? resolvedName : 'Customer',
        phone: customerPhone,
        profilePic: customerProfilePic,
        pickupAddress: pickupAddrs,
        dropoffAddress: dropoffAddrs,
        pickupInstruction: parsedInstr,
        amount: amount,
        seatCount: parsedSeatCount,
        seatNumbers: parsedSeatNumbers,
        pickupLatLng: LatLng(fromLat, fromLng),
        dropLatLng: LatLng(toLat, toLng),
      );

      riders.add(newRider);

      // 📊 Log new rider added
      logManager.logRider(
        action: 'RIDER_ADDED',
        bookingId: bookingIdStr,
        riderData: {
          'name': newRider.name,
          'totalRiders': riders.length,
          'pickup': pickupAddrs,
          'dropoff': dropoffAddrs,
        },
      );

      // ✅ if nothing active yet, make first rider active pickup
      activeTarget.value ??= newRider;
    }

    // ✅ recompute after insert/update
    recomputeNextTarget();
  }

  void markArrived(String bookingId) {
    final idx = riders.indexWhere((r) => r.bookingId == bookingId);
    if (idx == -1) return;

    riders[idx].arrived = true;
    riders.refresh();
    _recomputeRadiusGates(driverLocation.value);

    // 📊 Log arrival
    logManager.logRider(
      action: 'RIDER_ARRIVED',
      bookingId: bookingId,
      riderData: {'name': riders[idx].name},
    );
  }

  void markOnboard(String bookingId) {
    final idx = riders.indexWhere((r) => r.bookingId == bookingId);
    if (idx == -1) return;

    riders[idx].stage = SharedRiderStage.onboardDrop;
    riders[idx].secondsLeft = 0;

    activeTarget.value = riders[idx];
    riders.refresh();
    _recomputeRadiusGates(driverLocation.value);

    // 📊 Log onboard
    logManager.logRider(
      action: 'RIDER_ONBOARD',
      bookingId: bookingId,
      riderData: {
        'name': riders[idx].name,
        'dropoff': riders[idx].dropoffAddress,
      },
    );
  }

  void markDropped(String bookingId) {
    final idx = riders.indexWhere((r) => r.bookingId == bookingId);
    if (idx == -1) return;

    final riderName = riders[idx].name;

    riders[idx].stage = SharedRiderStage.dropped;
    riders[idx].secondsLeft = 0;

    if (activeTarget.value?.bookingId == bookingId) {
      activeTarget.value = null;
    }

    riders.refresh();
    recomputeNextTarget();
    _recomputeRadiusGates(driverLocation.value);

    // 📊 Log dropped
    logManager.logRider(
      action: 'RIDER_DROPPED',
      bookingId: bookingId,
      riderData: {
        'name': riderName,
        'remainingRiders': riders.where((r) => r.stage != SharedRiderStage.dropped).length,
      },
    );
  }

  /// Removes a rider from the pool (e.g., due to cancellation).
  /// Returns the name of the removed rider, or null if not found.
  String? removeRider(String bookingId) {
    final idx = riders.indexWhere((r) => r.bookingId == bookingId);
    if (idx == -1) return null;

    final removedRider = riders.removeAt(idx);
    riders.refresh();

    logManager.logRider(
      action: 'RIDER_REMOVED',
      bookingId: bookingId,
      riderData: {
        'name': removedRider.name,
        'reason': 'Cancelled',
        'remainingRiders': riders.length,
      },
    );

    recomputeNextTarget();
    return removedRider.name;
  }

  /// Marks a rider as cancelled-by-customer WITHOUT removing them, so the driver
  /// keeps seeing a disabled "Cancelled by customer" card for the rest of the
  /// trip. The backend has already freed the seat; here we only flip the rider to
  /// an inactive/disabled state and move the active target on if needed.
  /// Returns the rider name, or null if not found.
  String? markCancelledByCustomer(String bookingId, {String? reason}) {
    final idx = riders.indexWhere((r) => r.bookingId == bookingId);
    if (idx == -1) return null;

    final r = riders[idx];
    if (r.cancelledByCustomer) {
      // Already handled — but capture a reason if we didn't have one yet.
      if ((r.cancelReason).trim().isEmpty && (reason ?? '').trim().isNotEmpty) {
        r.cancelReason = reason!.trim();
        riders.refresh();
      }
      return r.name;
    }

    r.cancelledByCustomer = true;
    r.cancelReason = (reason ?? '').trim();

    // If they were the active stop, drop the selection so we re-pick a valid one.
    if (activeTarget.value?.bookingId == bookingId) {
      activeTarget.value = null;
    }

    riders.refresh();
    recomputeNextTarget();

    logManager.logRider(
      action: 'RIDER_CANCELLED_BY_CUSTOMER',
      bookingId: bookingId,
      riderData: {
        'name': r.name,
        'activeRiders': getAllActiveRiders().length,
      },
    );

    return r.name;
  }

  void setActiveTarget(String bookingId, SharedRiderStage stage) {
    final idx = riders.indexWhere((r) => r.bookingId == bookingId);
    if (idx == -1) return;

    riders[idx].stage = stage;
    activeTarget.value = riders[idx];
    riders.refresh();
    _recomputeRadiusGates(driverLocation.value);
  }

  void updateDriverLocation(LatLng loc) {
    driverLocation.value = loc;
    _recomputeRadiusGates(loc);
  }

  /// Wipes all pooled rider state. MUST be called when a shared-ride session
  /// fully ends (ride cancelled or all legs completed and the driver returns to
  /// home) so a brand-new shared ride never inherits stale/old riders.
  void reset() {
    riders.clear();
    activeTarget.value = null;
    driverLocation.value = null;
    canArriveAtActivePickup.value = false;
    canCompleteActiveDrop.value = false;
    riders.refresh();
  }

  void _recomputeRadiusGates(LatLng? loc) {
    final active = activeTarget.value;
    if (loc == null || active == null) {
      canArriveAtActivePickup.value = false;
      canCompleteActiveDrop.value = false;
      return;
    }

    if (active.stage == SharedRiderStage.waitingPickup) {
      final d = Geolocator.distanceBetween(
        loc.latitude,
        loc.longitude,
        active.pickupLatLng.latitude,
        active.pickupLatLng.longitude,
      );

      // hysteresis: avoid flicker near boundary
      final show = d <= _ARRIVED_PICKUP_RADIUS_M;
      final hide = d >= _ARRIVED_PICKUP_EXIT_RADIUS_M;
      if (!canArriveAtActivePickup.value && show) {
        canArriveAtActivePickup.value = true;
      } else if (canArriveAtActivePickup.value && hide) {
        canArriveAtActivePickup.value = false;
      }

      canCompleteActiveDrop.value = false;
      return;
    }

    if (active.stage == SharedRiderStage.onboardDrop) {
      final d = Geolocator.distanceBetween(
        loc.latitude,
        loc.longitude,
        active.dropLatLng.latitude,
        active.dropLatLng.longitude,
      );

      final show = d <= _COMPLETE_DROP_RADIUS_M;
      final hide = d >= _COMPLETE_DROP_EXIT_RADIUS_M;
      if (!canCompleteActiveDrop.value && show) {
        canCompleteActiveDrop.value = true;
      } else if (canCompleteActiveDrop.value && hide) {
        canCompleteActiveDrop.value = false;
      }

      canArriveAtActivePickup.value = false;
      return;
    }

    // dropped
    canArriveAtActivePickup.value = false;
    canCompleteActiveDrop.value = false;
  }

  // -------------------- HELPERS --------------------

  /// Defensive guard for the destructive "complete drop" action.
  ///
  /// Re-validates — independent of whatever `activeTarget` currently is — that
  /// THIS specific rider is still a legitimate onboard drop within the
  /// completion radius. The swipe UI captures a rider at build time, but the
  /// active target can change underneath it (socket re-pick / cancellation)
  /// before the swipe is released; without this check the driver could mark the
  /// WRONG passenger dropped (one still in the car). Call this immediately
  /// before invoking the completion API.
  bool canSafelyCompleteDropFor(String bookingId) {
    final loc = driverLocation.value;
    if (loc == null) return false;
    final idx = riders.indexWhere((r) => r.bookingId == bookingId);
    if (idx == -1) return false;
    final r = riders[idx];
    if (r.cancelledByCustomer) return false;
    if (r.stage != SharedRiderStage.onboardDrop) return false;
    final d = Geolocator.distanceBetween(
      loc.latitude,
      loc.longitude,
      r.dropLatLng.latitude,
      r.dropLatLng.longitude,
    );
    return d <= _COMPLETE_DROP_RADIUS_M;
  }

  /// Onboard, non-cancelled riders whose drop is within [radiusM] of [anchor].
  List<SharedRiderItem> onboardRidersNearDrop(LatLng anchor,
      {double radiusM = 80}) {
    return riders.where((r) {
      if (r.cancelledByCustomer) return false;
      if (r.stage != SharedRiderStage.onboardDrop) return false;
      final d = Geolocator.distanceBetween(
        anchor.latitude,
        anchor.longitude,
        r.dropLatLng.latitude,
        r.dropLatLng.longitude,
      );
      return d <= radiusM;
    }).toList();
  }

  /// Onboard riders SHARING the active drop point AND reachable right now (the
  /// driver is within the completion radius). Returns the cluster ONLY when 2+
  /// riders qualify, so the grouped "complete drops here" UI shows strictly when
  /// it helps. This NEVER completes anyone — it only lists who is eligible for a
  /// one-tap that still completes each booking SEPARATELY & atomically.
  List<SharedRiderItem> completableDropClusterAtActive(
      {double clusterRadiusM = 80}) {
    final active = activeTarget.value;
    final loc = driverLocation.value;
    if (active == null || loc == null) return const [];
    if (active.stage != SharedRiderStage.onboardDrop) return const [];
    final dDriver = Geolocator.distanceBetween(
      loc.latitude,
      loc.longitude,
      active.dropLatLng.latitude,
      active.dropLatLng.longitude,
    );
    if (dDriver > _COMPLETE_DROP_RADIUS_M) return const [];
    final cluster =
        onboardRidersNearDrop(active.dropLatLng, radiusM: clusterRadiusM);
    return cluster.length >= 2 ? cluster : const [];
  }

  bool hasPendingOrOnboard() {
    return riders.any(
      (r) =>
          !r.cancelledByCustomer &&
          (r.stage == SharedRiderStage.waitingPickup ||
              r.stage == SharedRiderStage.onboardDrop),
    );
  }

  SharedRiderItem? getNearestPickup() {
    final loc = driverLocation.value;
    if (loc == null) return null;

    SharedRiderItem? nearest;
    double best = double.infinity;

    for (final r in riders) {
      if (r.cancelledByCustomer) continue;
      if (r.stage != SharedRiderStage.waitingPickup) continue;

      final d = Geolocator.distanceBetween(
        loc.latitude,
        loc.longitude,
        r.pickupLatLng.latitude,
        r.pickupLatLng.longitude,
      );

      if (d < best) {
        best = d;
        nearest = r;
      }
    }
    return nearest;
  }

  /// ✅ NEAREST-FIRST legal stop — mirrors the backend `buildStopSequence` so the
  /// driver's active target == backend stops[0] == the customer's shared_my_state
  /// "next stop" (no driver/customer contradiction).
  ///
  /// Legal stops: a `waitingPickup` rider's PICKUP, or an `onboardDrop` rider's
  /// DROP (a drop is legal ONLY after pickup → no drop-before-pickup). Cancelled
  /// and dropped riders contribute nothing. The NEAREST legal stop from the
  /// driver's current location wins; on a <=1m tie a DROP is preferred (offload
  /// first), matching the backend's tie-break. Always exactly one activeTarget.
  ///
  /// NOTE: previously this dropped any onboard rider FIRST, which could send the
  /// driver to a drop while a much closer pickup was pending — diverging from the
  /// backend queue and making the customer's "you are next" wrong.
  SharedRiderItem? recomputeNextTarget() {
    if (!hasPendingOrOnboard()) {
      activeTarget.value = null;
      _recomputeRadiusGates(driverLocation.value);
      return null;
    }

    final loc = driverLocation.value;
    SharedRiderItem? best;
    double bestDist = double.infinity;
    bool bestIsDrop = false;

    for (final r in riders) {
      if (r.cancelledByCustomer) continue;
      final bool isDrop;
      final LatLng target;
      if (r.stage == SharedRiderStage.waitingPickup) {
        isDrop = false;
        target = r.pickupLatLng;
      } else if (r.stage == SharedRiderStage.onboardDrop) {
        isDrop = true;
        target = r.dropLatLng;
      } else {
        continue; // dropped — never a legal stop
      }

      if (loc == null) {
        // No GPS yet: stable list order, drop preferred on a tie.
        if (best == null || (isDrop && !bestIsDrop)) {
          best = r;
          bestIsDrop = isDrop;
        }
        continue;
      }

      final d = Geolocator.distanceBetween(
        loc.latitude,
        loc.longitude,
        target.latitude,
        target.longitude,
      );
      final bool nearer = d < bestDist - 1.0; // ~1m grid, same as backend
      final bool tieDropWins =
          (d - bestDist).abs() <= 1.0 && isDrop && !bestIsDrop;
      if (best == null || nearer || tieDropWins) {
        best = r;
        bestDist = d;
        bestIsDrop = isDrop;
      }
    }

    activeTarget.value = best;
    _recomputeRadiusGates(driverLocation.value);
    return best;
  }

  /// Get all active riders (not just for one booking)
  /// ✅ Use this for shared ride pools with multiple customers
  List<SharedRiderItem> getAllActiveRiders() {
    return riders
        .where((r) =>
            !r.cancelledByCustomer && r.stage != SharedRiderStage.dropped)
        .toList();
  }

  /// Riders that cancelled their own seat. Kept in the list so the driver can see
  /// a disabled "Cancelled by customer" card (with reason) and swipe to dismiss.
  List<SharedRiderItem> getCancelledRiders() {
    return riders.where((r) => r.cancelledByCustomer).toList();
  }

  /// Get active riders for a specific booking (legacy - for single rides)
  List<SharedRiderItem> getActiveRidersForBooking(String bookingId) {
    return riders
        .where((r) =>
            r.bookingId == bookingId &&
            r.stage != SharedRiderStage.dropped)
        .toList();
  }

  /// Get riders by stage (waiting, onboard, etc)
  List<SharedRiderItem> getRidersByStage(SharedRiderStage stage) {
    return riders.where((r) => r.stage == stage).toList();
  }

  /// Get completed/dropped riders (for history)
  List<SharedRiderItem> getDroppedRiders() {
    return riders.where((r) => r.stage == SharedRiderStage.dropped).toList();
  }

  /// Apply a live "Directions to reach" note (backend `pickup_instruction_updated`)
  /// to the matching rider and refresh so the pickup card rebuilds. No-op if the
  /// booking isn't in this driver's pool.
  void updatePickupInstruction(String bookingId, String instruction) {
    final idx = riders.indexWhere((r) => r.bookingId == bookingId);
    if (idx < 0) return;
    riders[idx].pickupInstruction = instruction;
    riders.refresh();
  }
}

// // lib/Presentation/DriverScreen/screens/SharedBooking/Controller/shared_ride_controller.dart
//
// import 'package:action_slider/action_slider.dart';
// import 'package:get/get.dart';
// import 'package:google_maps_flutter/google_maps_flutter.dart';
// import 'package:geolocator/geolocator.dart';
//
// enum SharedRiderStage {
//   waitingPickup, // not in car yet
//   onboardDrop, // in car, need to drop
//   dropped, // finished
// }
//
// class SharedRiderItem {
//   final String bookingId;
//
//   String name;
//   String phone;
//   String profilePic;
//   String pickupAddress;
//   String dropoffAddress;
//   num amount;
//
//   final LatLng pickupLatLng;
//   final LatLng dropLatLng;
//
//   // UI state
//   bool arrived;
//   int secondsLeft;
//   final ActionSliderController sliderController;
//   SharedRiderStage stage;
//
//   SharedRiderItem({
//     required this.bookingId,
//     required this.name,
//     required this.phone,
//     required this.profilePic,
//     required this.pickupAddress,
//     required this.dropoffAddress,
//     required this.amount,
//     required this.pickupLatLng,
//     required this.dropLatLng,
//     this.arrived = false,
//     this.secondsLeft = 0,
//     this.stage = SharedRiderStage.waitingPickup,
//     ActionSliderController? sliderController,
//   }) : sliderController = sliderController ?? ActionSliderController();
// }
//
// class SharedRideController extends GetxController {
//   /// All riders in this shared/pooled booking
//   final RxList<SharedRiderItem> riders = <SharedRiderItem>[].obs;
//
//   /// Current target (pickup or drop) used by Start screen + map
//   final Rxn<SharedRiderItem> activeTarget = Rxn<SharedRiderItem>();
//
//   /// Latest driver location (for distance calculation)
//   final Rxn<LatLng> driverLocation = Rxn<LatLng>();
//
//   // ---------- CRUD / UPDATE FROM SOCKET ----------
//
//   void upsertFromSocket(Map<String, dynamic> data) {
//     final customerLoc = data['customerLocation'];
//     final String customerName = data['customerName'] ?? '';
//     final String customerPhone = data['customerPhone'] ?? '';
//     final num amount = data['amount'] ?? 0;
//     final String customerProfilePic = data['customerProfilePic'] ?? '';
//     final String bookingIdStr = data['bookingId'].toString();
//
//     final double fromLat = (customerLoc['fromLatitude'] as num).toDouble();
//     final double fromLng = (customerLoc['fromLongitude'] as num).toDouble();
//     final double toLat = (customerLoc['toLatitude'] as num).toDouble();
//     final double toLng = (customerLoc['toLongitude'] as num).toDouble();
//
//     final String pickupAddrs = data['pickupAddress'] ?? '';
//     final String dropoffAddrs = data['dropoffAddress'] ?? '';
//
//     final idx = riders.indexWhere((r) => r.bookingId == bookingIdStr);
//
//     if (idx >= 0) {
//       final r = riders[idx];
//       r
//         ..name = customerName
//         ..phone = customerPhone
//         ..profilePic = customerProfilePic
//         ..pickupAddress = pickupAddrs
//         ..dropoffAddress = dropoffAddrs
//         ..amount = amount;
//       riders.refresh();
//     } else {
//       final newRider = SharedRiderItem(
//         bookingId: bookingIdStr,
//         name: customerName,
//         phone: customerPhone,
//         profilePic: customerProfilePic,
//         pickupAddress: pickupAddrs,
//         dropoffAddress: dropoffAddrs,
//         amount: amount,
//         pickupLatLng: LatLng(fromLat, fromLng),
//         dropLatLng: LatLng(toLat, toLng),
//       );
//       riders.add(newRider);
//
//       // if nothing active yet, make first rider active pickup
//       activeTarget.value ??= newRider;
//     }
//   }
//
//   void markArrived(String bookingId) {
//     final idx = riders.indexWhere((r) => r.bookingId == bookingId);
//     if (idx == -1) return;
//     riders[idx].arrived = true;
//     riders.refresh();
//   }
//
//   void markOnboard(String bookingId) {
//     final idx = riders.indexWhere((r) => r.bookingId == bookingId);
//     if (idx == -1) return;
//     riders[idx].stage = SharedRiderStage.onboardDrop;
//     riders[idx].secondsLeft = 0;
//     activeTarget.value = riders[idx];
//     riders.refresh();
//   }
//
//   void markDropped(String bookingId) {
//     final idx = riders.indexWhere((r) => r.bookingId == bookingId);
//     if (idx == -1) return;
//     riders[idx].stage = SharedRiderStage.dropped;
//     riders.refresh();
//   }
//
//   void setActiveTarget(String bookingId, SharedRiderStage stage) {
//     final idx = riders.indexWhere((r) => r.bookingId == bookingId);
//     if (idx == -1) return;
//     riders[idx].stage = stage;
//     activeTarget.value = riders[idx];
//     riders.refresh();
//   }
//
//   void updateDriverLocation(LatLng loc) {
//     driverLocation.value = loc;
//   }
//
//   // ---------- NEXT STOP / NEAREST ----------
//
//   SharedRiderItem? getNearestStop() {
//     final loc = driverLocation.value;
//     if (loc == null) return null;
//
//     SharedRiderItem? nearest;
//     double best = double.infinity;
//
//     for (final r in riders) {
//       if (r.stage == SharedRiderStage.dropped) continue;
//
//       final LatLng target =
//           r.stage == SharedRiderStage.waitingPickup
//               ? r.pickupLatLng
//               : r.dropLatLng;
//
//       final d = Geolocator.distanceBetween(
//         loc.latitude,
//         loc.longitude,
//         target.latitude,
//         target.longitude,
//       );
//
//       if (d < best) {
//         best = d;
//         nearest = r;
//       }
//     }
//     return nearest;
//   }
//
//   /// When one leg is completed, decide next automatically (optional)
//   SharedRiderItem? recomputeNextTarget() {
//     final loc = driverLocation.value;
//     if (loc == null) {
//       // just first non-dropped
//       final next = riders.firstWhereOrNull(
//         (r) => r.stage != SharedRiderStage.dropped,
//       );
//       activeTarget.value = next;
//       return next;
//     }
//
//     final next = getNearestStop();
//     activeTarget.value = next;
//     return next;
//   }
// }
