import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:get/get.dart';

import '../../api/repository/api_constents.dart';

/// Vehicle type used for routing decisions.
enum VehicleType { car, bike, auto }

class VehicleRoutingConfig {
  static Map<String, String> getDirectionsParams(VehicleType type) {
    switch (type) {
      case VehicleType.car:
        return <String, String>{
          'mode': 'driving',
          'avoid': '',
          'alternatives': 'true',
        };
      case VehicleType.bike:
      case VehicleType.auto:
        return <String, String>{
          'mode': 'driving',
          'avoid': 'highways',
          'alternatives': 'true',
        };
    }
  }

  static int estimateEtaMinutes({
    required double distanceMeters,
    required VehicleType type,
    required int hourOfDay,
  }) {
    final isRushHour =
        (hourOfDay >= 8 && hourOfDay <= 10) || (hourOfDay >= 17 && hourOfDay <= 20);

    final avgSpeedKmh = switch (type) {
      VehicleType.car => isRushHour ? 18.0 : 35.0,
      VehicleType.bike || VehicleType.auto => isRushHour ? 20.0 : 30.0,
    };

    final distanceKm = distanceMeters / 1000.0;
    final timeHours = distanceKm / avgSpeedKmh;
    return (timeHours * 60.0).ceil();
  }
}

class RouteService {
  RouteService({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  // Haversine distance between two GPS points (meters)
  double haversineDistance(LatLng a, LatLng b) {
    const r = 6371000.0;
    final dLat = (b.latitude - a.latitude) * math.pi / 180.0;
    final dLon = (b.longitude - a.longitude) * math.pi / 180.0;
    final sinDLat = math.sin(dLat / 2.0);
    final sinDLon = math.sin(dLon / 2.0);
    final aVal =
        sinDLat * sinDLat +
        math.cos(a.latitude * math.pi / 180.0) *
            math.cos(b.latitude * math.pi / 180.0) *
            sinDLon *
            sinDLon;
    return r * 2.0 * math.atan2(math.sqrt(aVal), math.sqrt(1.0 - aVal));
  }

  // Find minimum distance from a point to a polyline (meters)
  double distanceFromPolyline(LatLng point, List<LatLng> polyline) {
    if (polyline.length < 2) return double.infinity;
    double minDist = double.infinity;
    for (int i = 0; i < polyline.length - 1; i++) {
      final dist = _distanceToSegment(point, polyline[i], polyline[i + 1]);
      if (dist < minDist) minDist = dist;
    }
    return minDist;
  }

  Future<List<LatLng>> fetchRoute({
    required LatLng origin,
    required LatLng destination,
    required VehicleType vehicleType,
    String? apiKey,
  }) async {
    final params = VehicleRoutingConfig.getDirectionsParams(vehicleType);
    final mode = params['mode'] ?? 'driving';
    final avoid = params['avoid'];
    final alternatives = params['alternatives'];

    final avoidQuery = (avoid == null || avoid.isEmpty) ? '' : '&avoid=$avoid';
    final altQuery =
        (alternatives == null || alternatives.isEmpty) ? '' : '&alternatives=$alternatives';

    final key = (apiKey ?? ApiConstents.googleMapApiKey).trim();
    if (key.isEmpty) {
      throw Exception('Google Maps API key is empty (ApiConstents.googleMapApiKey)');
    }

    final url =
        'https://maps.googleapis.com/maps/api/directions/json'
        '?origin=${origin.latitude},${origin.longitude}'
        '&destination=${destination.latitude},${destination.longitude}'
        '&mode=$mode'
        '$avoidQuery'
        '$altQuery'
        '&key=$key';

    final response = await _dio.get(url);
    final data = response.data;
    if (data is! Map) throw Exception('Directions API: invalid response');
    if (data['status'] != 'OK') {
      throw Exception('Directions API error: ${data['status']}');
    }

    final encoded =
        data['routes'][0]['overview_polyline']['points'] as String? ?? '';
    if (encoded.isEmpty) return <LatLng>[origin, destination];

    final polylinePoints = PolylinePoints();
    final decoded = polylinePoints.decodePolyline(encoded);
    if (decoded.length < 2) return <LatLng>[origin, destination];

    return decoded.map((p) => LatLng(p.latitude, p.longitude)).toList();
  }

  // ---------------- Offline caching ----------------

  Future<void> cacheRoute(String rideId, List<LatLng> route) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = route.map((p) => '${p.latitude},${p.longitude}').join('|');
    await prefs.setString('cached_route_$rideId', encoded);
  }

  Future<List<LatLng>?> getCachedRoute(String rideId) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getString('cached_route_$rideId');
    if (encoded == null || encoded.trim().isEmpty) return null;
    try {
      return encoded.split('|').map((p) {
        final parts = p.split(',');
        return LatLng(double.parse(parts[0]), double.parse(parts[1]));
      }).toList();
    } catch (_) {
      return null;
    }
  }

  Future<List<LatLng>> fetchRouteWithFallback({
    required String rideId,
    required LatLng origin,
    required LatLng destination,
    required VehicleType vehicleType,
  }) async {
    try {
      final route = await fetchRoute(
        origin: origin,
        destination: destination,
        vehicleType: vehicleType,
      );
      await cacheRoute(rideId, route);
      return route;
    } catch (e) {
      final cached = await getCachedRoute(rideId);
      if (cached != null) {
        Get.snackbar(
          'Offline',
          'Using last known route',
          backgroundColor: Colors.orange,
          colorText: Colors.white,
          snackPosition: SnackPosition.TOP,
        );
        return cached;
      }
      return <LatLng>[origin, destination];
    }
  }

  // ---------------- geometry helpers ----------------

  double _distanceToSegment(LatLng p, LatLng a, LatLng b) {
    // Use fast equirectangular projection in meters for short distances.
    final lat0 = p.latitude * math.pi / 180.0;
    final metersPerDegLat = 111320.0;
    final metersPerDegLng = 111320.0 * math.cos(lat0);

    double toX(double lng) => (lng - p.longitude) * metersPerDegLng;
    double toY(double lat) => (lat - p.latitude) * metersPerDegLat;

    final ax = toX(a.longitude);
    final ay = toY(a.latitude);
    final bx = toX(b.longitude);
    final by = toY(b.latitude);

    final abx = bx - ax;
    final aby = by - ay;
    final denom = (abx * abx) + (aby * aby);
    double t = 0.0;
    if (denom > 0.0) {
      t = ((-ax * abx) + (-ay * aby)) / denom;
      if (t < 0.0) t = 0.0;
      if (t > 1.0) t = 1.0;
    }

    final px = ax + (abx * t);
    final py = ay + (aby * t);
    return math.sqrt(px * px + py * py);
  }
}

