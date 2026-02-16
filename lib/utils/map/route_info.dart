import 'dart:convert';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

import '../../api/repository/api_constents.dart';

/// ============================================================
/// ✅ COMMON DIRECTIONS (Driver + Customer)
/// - Use same params to keep same route
/// - Provides BOTH:
///   1) getRouteInfo() -> Map<String,dynamic> (Driver old usage)
///   2) DirectionsHelper.getRouteInfo() -> RouteInfo (Customer typed usage)
/// ============================================================

Future<Map<String, dynamic>> getRouteInfo({
  required LatLng origin,
  required LatLng destination,

  // ✅ keep SAME in both apps
  String mode = "driving",
  bool alternatives = false,
  bool traffic = true,
  String units = "metric",
  String region = "in",

  // ✅ stable route pick
  int routeIndex = 0,
}) async {
  final data = await _fetchDirectionsRaw(
    origin: origin,
    destination: destination,
    apiKey: DirectionsConfig.apiKey,
    mode: mode,
    alternatives: alternatives,
    traffic: traffic,
    units: units,
    region: region,
  );

  final routes = (data['routes'] as List);
  final idx = routeIndex.clamp(0, routes.length - 1);
  final route = routes[idx];

  final leg = route['legs'][0];
  final steps = (leg['steps'] as List);

  final polyline = route['overview_polyline']['points'] as String;

  final first = steps.isNotEmpty ? steps[0] : null;
  final directionText = first?['html_instructions']?.toString() ?? '';
  final distanceText = first?['distance']?['text']?.toString() ?? '';
  final maneuver = first?['maneuver']?.toString() ?? 'straight';

  return {
    "direction": directionText,
    "distance": distanceText,
    "polyline": polyline,
    "maneuver": maneuver,
    "routeIndex": idx,
    "raw": data,
  };
}

/// ✅ Typed helper for Customer (and if you want you can use in Driver too)
class DirectionsHelper {
  DirectionsHelper({required String apiKey}) {
    DirectionsConfig.apiKey = apiKey; // share same key holder
  }

  Future<RouteInfo> getRouteInfo({
    required LatLng origin,
    required LatLng destination,
    String mode = "driving",
    bool alternatives = false,
    bool traffic = true,
    String units = "metric",
    String region = "in",
    int routeIndex = 0,
  }) async {
    final data = await _fetchDirectionsRaw(
      origin: origin,
      destination: destination,
      apiKey: DirectionsConfig.apiKey,
      mode: mode,
      alternatives: alternatives,
      traffic: traffic,
      units: units,
      region: region,
    );

    final routes = (data['routes'] as List);
    final idx = routeIndex.clamp(0, routes.length - 1);
    final route = routes[idx];

    final leg = route['legs'][0];
    final steps = (leg['steps'] as List);

    final polyline = route['overview_polyline']['points'] as String;

    final first = steps.isNotEmpty ? steps[0] : null;
    final directionText = first?['html_instructions']?.toString() ?? '';
    final distanceText = first?['distance']?['text']?.toString() ?? '';
    final maneuver = first?['maneuver']?.toString() ?? 'straight';

    return RouteInfo(
      polyline: polyline,
      points: decodePolyline(polyline),
      directionHtml: directionText,
      distanceText: distanceText,
      maneuver: maneuver,
      routeIndex: idx,
      raw: data,
    );
  }
}

/// ✅ simple config holder
class DirectionsConfig {
  static String apiKey = ApiConstents.googleMapApiKey;
}

Future<Map<String, dynamic>> _fetchDirectionsRaw({
  required LatLng origin,
  required LatLng destination,
  required String apiKey,

  required String mode,
  required bool alternatives,
  required bool traffic,
  required String units,
  required String region,
}) async {
  if (apiKey.isEmpty) {
    throw Exception("GOOGLE_MAP_API_KEY_MISSING");
  }

  final query = <String, String>{
    "origin": "${origin.latitude},${origin.longitude}",
    "destination": "${destination.latitude},${destination.longitude}",
    "key": apiKey,
    "mode": mode,
    "alternatives": alternatives.toString(),
    "units": units,
    "region": region,
  };

  // ✅ traffic consistency (optional)
  if (traffic) {
    query["departure_time"] = "now";
    query["traffic_model"] = "best_guess";
  }

  final uri = Uri.https(
    "maps.googleapis.com",
    "/maps/api/directions/json",
    query,
  );

  final response = await http.get(uri);

  if (response.statusCode != 200) {
    throw Exception("Directions HTTP ${response.statusCode}");
  }

  final data = json.decode(response.body);

  if (data['status'] != 'OK') {
    throw Exception(
      "Directions error: ${data['status']} ${data['error_message'] ?? ''}",
    );
  }

  return data;
}

/// ✅ Common polyline decode (same for both)
List<LatLng> decodePolyline(String encoded) {
  final points = <LatLng>[];
  int index = 0, len = encoded.length;
  int lat = 0, lng = 0;

  while (index < len) {
    int b, shift = 0, result = 0;
    do {
      b = encoded.codeUnitAt(index++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    final dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
    lat += dlat;

    shift = 0;
    result = 0;
    do {
      b = encoded.codeUnitAt(index++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    final dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
    lng += dlng;

    points.add(LatLng(lat / 1E5, lng / 1E5));
  }

  return points;
}

/// Typed model (Customer usage)
class RouteInfo {
  final String polyline;
  final List<LatLng> points;

  final String directionHtml;
  final String distanceText;
  final String maneuver;

  final int routeIndex;
  final Map<String, dynamic> raw;

  RouteInfo({
    required this.polyline,
    required this.points,
    required this.directionHtml,
    required this.distanceText,
    required this.maneuver,
    required this.routeIndex,
    required this.raw,
  });
}
