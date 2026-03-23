import 'package:action_slider/action_slider.dart';
import 'package:geocoding/geocoding.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

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

  final LatLng pickupLatLng;
  final LatLng dropLatLng;

  // UI state
  bool arrived;
  int secondsLeft;
  final ActionSliderController sliderController;
  SharedRiderStage stage;

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
    this.arrived = false,
    this.secondsLeft = 0,
    this.stage = SharedRiderStage.waitingPickup,
    ActionSliderController? sliderController,
  }) : sliderController = sliderController ?? ActionSliderController();
}

class SharedRideController extends GetxController {
  /// All riders in this shared/pooled booking
  final RxList<SharedRiderItem> riders = <SharedRiderItem>[].obs;

  /// Current target (pickup or drop)
  final Rxn<SharedRiderItem> activeTarget = Rxn<SharedRiderItem>();

  /// Latest driver location
  final Rxn<LatLng> driverLocation = Rxn<LatLng>();

  // -------------------- radius gates (UI only) --------------------
  static const double _ARRIVED_PICKUP_RADIUS_M = 500.0;
  static const double _ARRIVED_PICKUP_EXIT_RADIUS_M = 650.0; // hysteresis
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

    final customerName = _safeString(data['customerName']);
    final customerPhone = _safeString(data['customerPhone']);
    final customerProfilePic = _safeString(data['customerProfilePic']);
    final amount = (data['amount'] is num) ? (data['amount'] as num) : 0;

    // ✅ Support both formats (if backend sends later)
    String pickupAddrs = _safeString(
      data['pickupLocationAddress'] ?? data['pickupAddress'],
    );
    String dropoffAddrs = _safeString(
      data['dropLocationAddress'] ?? data['dropoffAddress'],
    );

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
        ..name = customerName
        ..phone = customerPhone
        ..profilePic = customerProfilePic
        ..pickupAddress = pickupAddrs
        ..dropoffAddress = dropoffAddrs
        ..amount = amount;

      riders.refresh();
    } else {
      final newRider = SharedRiderItem(
        bookingId: bookingIdStr,
        name: customerName,
        phone: customerPhone,
        profilePic: customerProfilePic,
        pickupAddress: pickupAddrs,
        dropoffAddress: dropoffAddrs,
        amount: amount,
        pickupLatLng: LatLng(fromLat, fromLng),
        dropLatLng: LatLng(toLat, toLng),
      );

      riders.add(newRider);

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
  }

  void markOnboard(String bookingId) {
    final idx = riders.indexWhere((r) => r.bookingId == bookingId);
    if (idx == -1) return;

    riders[idx].stage = SharedRiderStage.onboardDrop;
    riders[idx].secondsLeft = 0;

    activeTarget.value = riders[idx];
    riders.refresh();
    _recomputeRadiusGates(driverLocation.value);
  }

  void markDropped(String bookingId) {
    final idx = riders.indexWhere((r) => r.bookingId == bookingId);
    if (idx == -1) return;

    riders[idx].stage = SharedRiderStage.dropped;
    riders[idx].secondsLeft = 0;

    if (activeTarget.value?.bookingId == bookingId) {
      activeTarget.value = null;
    }

    riders.refresh();
    recomputeNextTarget();
    _recomputeRadiusGates(driverLocation.value);
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

  bool hasPendingOrOnboard() {
    return riders.any(
      (r) =>
          r.stage == SharedRiderStage.waitingPickup ||
          r.stage == SharedRiderStage.onboardDrop,
    );
  }

  SharedRiderItem? getNearestPickup() {
    final loc = driverLocation.value;
    if (loc == null) return null;

    SharedRiderItem? nearest;
    double best = double.infinity;

    for (final r in riders) {
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

  /// ✅ Priority rule:
  /// 1) If any onboardDrop exists -> must drop first
  /// 2) Else nearest waitingPickup
  /// 3) Else null (no pending)
  SharedRiderItem? recomputeNextTarget() {
    if (!hasPendingOrOnboard()) {
      activeTarget.value = null;
      _recomputeRadiusGates(driverLocation.value);
      return null;
    }

    final onboard = riders.firstWhereOrNull(
      (r) => r.stage == SharedRiderStage.onboardDrop,
    );
    if (onboard != null) {
      activeTarget.value = onboard;
      _recomputeRadiusGates(driverLocation.value);
      return onboard;
    }

    final nearestPickup = getNearestPickup();
    if (nearestPickup != null) {
      activeTarget.value = nearestPickup;
      _recomputeRadiusGates(driverLocation.value);
      return nearestPickup;
    }

    final any = riders.firstWhereOrNull(
      (r) => r.stage != SharedRiderStage.dropped,
    );
    activeTarget.value = any;
    _recomputeRadiusGates(driverLocation.value);
    return any;
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
