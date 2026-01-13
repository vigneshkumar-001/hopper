import 'package:action_slider/action_slider.dart';
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

  // ---------- CRUD / UPDATE FROM SOCKET ----------

  void upsertFromSocket(Map<String, dynamic> data) {
    final customerLoc = data['customerLocation'];
    final String customerName = (data['customerName'] ?? '').toString();
    final String customerPhone = (data['customerPhone'] ?? '').toString();
    final num amount = (data['amount'] as num?) ?? 0;
    final String customerProfilePic =
        (data['customerProfilePic'] ?? '').toString();
    final String bookingIdStr = data['bookingId'].toString();

    final double fromLat = (customerLoc['fromLatitude'] as num).toDouble();
    final double fromLng = (customerLoc['fromLongitude'] as num).toDouble();
    final double toLat = (customerLoc['toLatitude'] as num).toDouble();
    final double toLng = (customerLoc['toLongitude'] as num).toDouble();

    final String pickupAddrs = (data['pickupAddress'] ?? '').toString();
    final String dropoffAddrs = (data['dropoffAddress'] ?? '').toString();

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

      // if nothing active yet, make first rider active pickup
      activeTarget.value ??= newRider;
    }
  }

  void markArrived(String bookingId) {
    final idx = riders.indexWhere((r) => r.bookingId == bookingId);
    if (idx == -1) return;
    riders[idx].arrived = true;
    riders.refresh();
  }

  void markOnboard(String bookingId) {
    final idx = riders.indexWhere((r) => r.bookingId == bookingId);
    if (idx == -1) return;
    riders[idx].stage = SharedRiderStage.onboardDrop;
    riders[idx].secondsLeft = 0;
    activeTarget.value = riders[idx];
    riders.refresh();
  }

  void markDropped(String bookingId) {
    final idx = riders.indexWhere((r) => r.bookingId == bookingId);
    if (idx == -1) return;

    riders[idx].stage = SharedRiderStage.dropped;
    riders[idx].secondsLeft = 0;

    // if active got dropped, clear it (will be recomputed)
    if (activeTarget.value?.bookingId == bookingId) {
      activeTarget.value = null;
    }

    riders.refresh();
  }

  void setActiveTarget(String bookingId, SharedRiderStage stage) {
    final idx = riders.indexWhere((r) => r.bookingId == bookingId);
    if (idx == -1) return;
    riders[idx].stage = stage;
    activeTarget.value = riders[idx];
    riders.refresh();
  }

  void updateDriverLocation(LatLng loc) {
    driverLocation.value = loc;
  }

  // ---------- HELPERS ----------

  bool hasPendingOrOnboard() {
    return riders.any(
      (r) =>
          r.stage == SharedRiderStage.waitingPickup ||
          r.stage == SharedRiderStage.onboardDrop,
    );
  }

  // ---------- NEXT STOP / NEAREST ----------

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
    // 0) if none pending/onboard -> trip finished
    if (!hasPendingOrOnboard()) {
      activeTarget.value = null;
      return null;
    }

    // 1) onboardDrop priority
    final onboard = riders.firstWhereOrNull(
      (r) => r.stage == SharedRiderStage.onboardDrop,
    );
    if (onboard != null) {
      activeTarget.value = onboard;
      return onboard;
    }

    // 2) nearest waitingPickup
    final nearestPickup = getNearestPickup();
    if (nearestPickup != null) {
      activeTarget.value = nearestPickup;
      return nearestPickup;
    }

    // 3) fallback: any non-dropped
    final any = riders.firstWhereOrNull(
      (r) => r.stage != SharedRiderStage.dropped,
    );
    activeTarget.value = any;
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
