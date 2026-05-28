import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../ride_map/marker_icon_cache.dart';
import '../ride_map/ride_map_controller.dart';

enum RideStage { driverToPickup, driverToDrop, completed }

/// Orchestrates live ride tracking stages (driver->pickup, driver->drop).
///
/// This is a thin coordinator around [RideMapController] so existing screens
/// can adopt it incrementally without UI churn.
///
/// Responsibilities:
/// - Stage/destination switching
/// - Vehicle type propagation (car vs bike vs package bike)
/// - Ingesting location updates (socket/GPS) into the smooth map engine
class RideTrackingEngine {
  RideTrackingEngine({
    required RideStage stage,
    required RideVehicleType vehicleType,
    required RideMapController rideMap,
  }) : _stage = stage,
       _vehicleType = vehicleType,
       map = rideMap {
    map.setVehicleType(vehicleType);
  }

  final RideMapController map;

  RideStage _stage;
  RideStage get stage => _stage;

  RideVehicleType _vehicleType;
  RideVehicleType get vehicleType => _vehicleType;

  LatLng? _pickup;
  LatLng? _drop;

  LatLng? get pickup => _pickup;
  LatLng? get drop => _drop;

  void setVehicleType(RideVehicleType type) {
    if (_vehicleType == type) return;
    _vehicleType = type;
    map.setVehicleType(type);
  }

  void setPickupDrop({LatLng? pickup, LatLng? drop}) {
    _pickup = pickup;
    _drop = drop;
    map.setPickupDrop(pickup: pickup, drop: drop);
    _syncDestination();
  }

  void setStage(RideStage next) {
    if (_stage == next) return;
    _stage = next;
    if (_stage == RideStage.completed) {
      map.clearRoute();
      map.setAutoFollowEnabled(false);
      map.setNavigationDestination(null);
      return;
    }
    _syncDestination();
  }

  void _syncDestination() {
    final dest = switch (_stage) {
      RideStage.driverToPickup => _pickup,
      RideStage.driverToDrop => _drop,
      RideStage.completed => null,
    };
    if (dest == null) return;
    map.setNavigationDestination(dest, driverFriendlyStop: _stage == RideStage.driverToDrop);
  }

  /// Ingest a live location update.
  ///
  /// Call this for:
  /// - GPS updates (driver device)
  /// - socket updates (driver live tracking)
  ///
  /// This method does not directly mutate markers/polylines; it delegates to
  /// [RideMapController.updateVehicleLocation] which handles:
  /// - smoothing (marker animation)
  /// - polyline snapping + trimming
  /// - off-route detection + reroute
  void ingestLocation({
    required LatLng position,
    String source = 'unknown',
    double? speedMetersPerSecond,
    double? headingDeg,
    double? accuracyMeters,
    DateTime? timestamp,
  }) {
    if (_stage == RideStage.completed) return;
    map.updateVehicleLocation(
      position,
      source: source,
      speedMetersPerSecond: speedMetersPerSecond,
      headingDeg: headingDeg,
      accuracyMeters: accuracyMeters,
      timestamp: timestamp,
    );
  }

  /// Convenience for socket payloads where the driver location may be nested.
  ///
  /// Expected formats (best-effort):
  /// - { driverLiveTracking: { latitude, longitude, accuracy, speed, heading, timestamp } }
  /// - { latitude, longitude, ... }
  void ingestSocketPayload(Map<dynamic, dynamic> payload) {
    Map<dynamic, dynamic> loc = payload;
    final live = payload['driverLiveTracking'];
    if (live is Map) loc = live;

    double? asDouble(dynamic v) {
      if (v is num) return v.toDouble();
      return double.tryParse(v?.toString() ?? '');
    }

    final lat = asDouble(loc['latitude'] ?? loc['lat']);
    final lng = asDouble(loc['longitude'] ?? loc['lng']);
    if (lat == null || lng == null) return;

    DateTime? ts;
    final rawTs = loc['timestamp'] ?? loc['ts'];
    if (rawTs is int) {
      // Heuristic: seconds vs millis
      ts = DateTime.fromMillisecondsSinceEpoch(rawTs > 1000000000000 ? rawTs : rawTs * 1000);
    } else if (rawTs is String) {
      ts = DateTime.tryParse(rawTs);
      final i = int.tryParse(rawTs);
      if (ts == null && i != null) {
        ts = DateTime.fromMillisecondsSinceEpoch(i > 1000000000000 ? i : i * 1000);
      }
    }

    ingestLocation(
      position: LatLng(lat, lng),
      accuracyMeters: asDouble(loc['accuracy']),
      speedMetersPerSecond: asDouble(loc['speed']),
      headingDeg: asDouble(loc['heading'] ?? loc['bearing']),
      timestamp: ts,
    );
  }

  /// If a screen wants to pre-load vehicle icons (optional).
  Future<void> warmVehicleIcon() async {
    await MarkerIconCache.loadVehicle(_vehicleType);
  }
}
