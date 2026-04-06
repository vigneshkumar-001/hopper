import 'dart:convert';
import 'dart:math' as math;
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

  final distanceToDestinationMeters = _distanceMeters(origin, destination);
  final primary = _pickNextStep(steps, origin: origin, destination: destination);

  String directionText = primary?['html_instructions']?.toString() ?? '';
  String distanceText = primary?['distance']?['text']?.toString() ?? '';
  final rawManeuver = primary?['maneuver']?.toString() ?? '';
  String maneuver = _normalizeManeuver(rawManeuver, directionText);

  if (distanceToDestinationMeters <= 35) {
    directionText = 'Arrived at destination';
    distanceText = '0 m';
    maneuver = 'arrive';
  }

  final laneGuidance = _extractLaneGuidance(primary, maneuver, directionText);
  final maneuverPoints = _extractManeuverPoints(steps);

  return {
    "direction": directionText,
    "distance": distanceText,
    "polyline": polyline,
    "maneuver": maneuver,
    "laneGuidance": laneGuidance,
    "maneuverPoints": maneuverPoints,
    "routeIndex": idx,
    "distanceToDestinationMeters": distanceToDestinationMeters,
    "raw": data,
  };
}

/// Driver-friendly route helper:
/// - Computes a nearby "recommended" stop point using Directions step geometry
/// - Refetches the route to that adjusted point (so polyline + maneuvers align)
///
/// Note: this is a pragmatic "snap to navigable road/approach" heuristic; it
/// cannot fully detect no-parking, gates, or private roads without backend/map data.
Future<Map<String, dynamic>> getDriverFriendlyRouteInfo({
  required LatLng origin,
  required LatLng destination,
  String mode = "driving",
  bool alternatives = false,
  bool traffic = true,
  String units = "metric",
  String region = "in",
  int routeIndex = 0,
  double maxAdjustMeters = 120,
}) async {
  final base = await getRouteInfo(
    origin: origin,
    destination: destination,
    mode: mode,
    alternatives: alternatives,
    traffic: traffic,
    units: units,
    region: region,
    routeIndex: routeIndex,
  );

  final adjusted = _suggestDriverFriendlyStop(
    routeInfo: base,
    rawDestination: destination,
    maxAdjustMeters: maxAdjustMeters,
  );

  if (adjusted == null) {
    base['rawDestination'] = {'lat': destination.latitude, 'lng': destination.longitude};
    base['adjustedDestination'] = {'lat': destination.latitude, 'lng': destination.longitude};
    base['adjustedMeters'] = 0;
    return base;
  }

  final delta = _distanceMeters(destination, adjusted);
  if (delta <= 20) {
    base['rawDestination'] = {'lat': destination.latitude, 'lng': destination.longitude};
    base['adjustedDestination'] = {'lat': destination.latitude, 'lng': destination.longitude};
    base['adjustedMeters'] = delta.round();
    return base;
  }

  final refined = await getRouteInfo(
    origin: origin,
    destination: adjusted,
    mode: mode,
    alternatives: alternatives,
    traffic: traffic,
    units: units,
    region: region,
    routeIndex: routeIndex,
  );
  refined['rawDestination'] = {'lat': destination.latitude, 'lng': destination.longitude};
  refined['adjustedDestination'] = {'lat': adjusted.latitude, 'lng': adjusted.longitude};
  refined['adjustedMeters'] = delta.round();
  return refined;
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

    final distanceToDestinationMeters = _distanceMeters(origin, destination);
    final primary = _pickNextStep(steps, origin: origin, destination: destination);

    String directionText = primary?['html_instructions']?.toString() ?? '';
    String distanceText = primary?['distance']?['text']?.toString() ?? '';
    final rawManeuver = primary?['maneuver']?.toString() ?? '';
    String maneuver = _normalizeManeuver(rawManeuver, directionText);

    if (distanceToDestinationMeters <= 35) {
      directionText = 'Arrived at destination';
      distanceText = '0 m';
      maneuver = 'arrive';
    }

    final laneGuidance = _extractLaneGuidance(primary, maneuver, directionText);
    final maneuverPointsRaw = _extractManeuverPoints(steps);

    return RouteInfo(
      polyline: polyline,
      points: decodePolyline(polyline),
      directionHtml: directionText,
      distanceText: distanceText,
      maneuver: maneuver,
      laneGuidance: laneGuidance,
      maneuverPoints: maneuverPointsRaw
          .map((e) => RouteManeuverPoint.fromJson(e))
          .toList(growable: false),
      routeIndex: idx,
      raw: data,
    );
  }
}

/// ✅ simple config holder
class DirectionsConfig {
  static String apiKey = ApiConstents.googleMapApiKey;
}

Map<String, dynamic>? _pickNextStep(
  List steps, {
  required LatLng origin,
  required LatLng destination,
}) {
  if (steps.isEmpty) return null;
  if (_distanceMeters(origin, destination) <= 35) return null;

  final idx = _closestStepIndex(steps, origin);
  int startFrom = idx;

  final current = steps[idx];
  if (current is Map) {
    final endLoc = _latLngFromMap(current['end_location']);
    if (endLoc != null && _distanceMeters(origin, endLoc) <= 18) {
      if (idx + 1 < steps.length) startFrom = idx + 1;
    }
  }

  for (int i = startFrom; i < steps.length; i++) {
    final step = steps[i];
    if (step is! Map) continue;
    if (_stepHasTurnCue(step)) return Map<String, dynamic>.from(step);
  }

  final fallback = steps[startFrom];
  if (fallback is Map) return Map<String, dynamic>.from(fallback);
  return null;
}

bool _stepHasTurnCue(Map step) {
  final m = step['maneuver']?.toString().trim();
  if (m != null && m.isNotEmpty) return true;

  final html = step['html_instructions']?.toString().toLowerCase() ?? '';
  return html.contains(' left') ||
      html.contains(' right') ||
      html.contains('u-turn') ||
      html.contains('roundabout') ||
      html.contains('exit') ||
      html.contains('ramp') ||
      html.contains('fork') ||
      html.contains('merge') ||
      html.contains('keep');
}

int _closestStepIndex(List steps, LatLng origin) {
  double best = double.infinity;
  int bestIdx = 0;

  for (int i = 0; i < steps.length; i++) {
    final step = steps[i];
    if (step is! Map) continue;
    final endLoc = _latLngFromMap(step['end_location']);
    final startLoc = _latLngFromMap(step['start_location']);
    final ref = endLoc ?? startLoc;
    if (ref == null) continue;

    final d = _distanceMeters(origin, ref);
    if (d < best) {
      best = d;
      bestIdx = i;
    }
  }
  return bestIdx.clamp(0, math.max(0, steps.length - 1));
}

LatLng? _latLngFromMap(dynamic raw) {
  if (raw is! Map) return null;
  final lat = raw['lat'];
  final lng = raw['lng'];
  if (lat is num && lng is num) {
    return LatLng(lat.toDouble(), lng.toDouble());
  }
  return null;
}

double _distanceMeters(LatLng a, LatLng b) {
  const r = 6371000.0; // earth radius meters
  final dLat = _degToRad(b.latitude - a.latitude);
  final dLon = _degToRad(b.longitude - a.longitude);
  final lat1 = _degToRad(a.latitude);
  final lat2 = _degToRad(b.latitude);

  final sinDLat = math.sin(dLat / 2);
  final sinDLon = math.sin(dLon / 2);
  final h =
      sinDLat * sinDLat +
      math.cos(lat1) * math.cos(lat2) * sinDLon * sinDLon;
  final c = 2 * math.atan2(math.sqrt(h), math.sqrt(1 - h));
  return r * c;
}

double _degToRad(double deg) => deg * (math.pi / 180.0);

LatLng? _suggestDriverFriendlyStop({
  required Map<String, dynamic> routeInfo,
  required LatLng rawDestination,
  required double maxAdjustMeters,
}) {
  try {
    final raw = routeInfo['raw'];
    if (raw is! Map) return null;

    final routes = raw['routes'];
    if (routes is! List || routes.isEmpty) return null;

    final route = routes.first;
    if (route is! Map) return null;
    final legs = route['legs'];
    if (legs is! List || legs.isEmpty) return null;
    final leg = legs.first;
    if (leg is! Map) return null;

    final legEnd = _latLngFromMap(leg['end_location']);
    if (legEnd == null) return null;

    final endDelta = _distanceMeters(rawDestination, legEnd);
    if (endDelta > 5 && endDelta <= maxAdjustMeters) {
      return legEnd;
    }

    // If end_location is essentially the same as the user point, try moving to
    // the start of the final step (often the last "approach" segment on-road).
    final steps = leg['steps'];
    if (steps is! List || steps.isEmpty) return null;
    final last = steps.last;
    if (last is! Map) return null;

    final lastStart = _latLngFromMap(last['start_location']);
    if (lastStart == null) return null;

    int lastStepMeters = 0;
    final dist = last['distance'];
    if (dist is Map) {
      final v = dist['value'];
      if (v is int) lastStepMeters = v;
      if (v is num) lastStepMeters = v.round();
    }

    final startDelta = _distanceMeters(rawDestination, lastStart);
    if (lastStepMeters > 0 &&
        lastStepMeters <= 250 &&
        startDelta > 5 &&
        startDelta <= maxAdjustMeters) {
      return lastStart;
    }
  } catch (_) {
    // ignore
  }
  return null;
}

String _normalizeManeuver(String rawManeuver, String directionHtml) {
  final m = rawManeuver.toLowerCase().trim().replaceAll('_', '-');
  if (m.isNotEmpty) return m;

  final text = directionHtml.toLowerCase();
  if (text.contains('roundabout')) {
    if (text.contains('left')) return 'roundabout-left';
    if (text.contains('right')) return 'roundabout-right';
    return 'roundabout-right';
  }

  if (text.contains('u-turn') || text.contains('uturn')) {
    if (text.contains('left')) return 'uturn-left';
    if (text.contains('right')) return 'uturn-right';
    return 'uturn-left';
  }

  if (text.contains('keep left') || text.contains('slight left')) {
    return 'turn-slight-left';
  }
  if (text.contains('keep right') || text.contains('slight right')) {
    return 'turn-slight-right';
  }

  if (text.contains(' left')) return 'turn-left';
  if (text.contains(' right')) return 'turn-right';

  return 'straight';
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
  final String laneGuidance;

  final List<RouteManeuverPoint> maneuverPoints;

  final int routeIndex;
  final Map<String, dynamic> raw;

  RouteInfo({
    required this.polyline,
    required this.points,
    required this.directionHtml,
    required this.distanceText,
    required this.maneuver,
    required this.laneGuidance,
    required this.maneuverPoints,
    required this.routeIndex,
    required this.raw,
  });
}

class RouteManeuverPoint {
  final LatLng location;
  final String maneuver;
  final int distanceFromStartMeters;

  const RouteManeuverPoint({
    required this.location,
    required this.maneuver,
    required this.distanceFromStartMeters,
  });

  factory RouteManeuverPoint.fromJson(Map<String, dynamic> json) {
    final lat = (json['lat'] as num?)?.toDouble() ?? 0.0;
    final lng = (json['lng'] as num?)?.toDouble() ?? 0.0;
    final d = json['distanceFromStartMeters'];

    return RouteManeuverPoint(
      location: LatLng(lat, lng),
      maneuver: (json['maneuver'] ?? '').toString(),
      distanceFromStartMeters: d is int ? d : int.tryParse('$d') ?? 0,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'lat': location.latitude,
    'lng': location.longitude,
    'maneuver': maneuver,
    'distanceFromStartMeters': distanceFromStartMeters,
  };
}

List<Map<String, dynamic>> _extractManeuverPoints(List steps) {
  if (steps.isEmpty) return const <Map<String, dynamic>>[];

  final out = <Map<String, dynamic>>[];
  int walked = 0;

  for (final s in steps) {
    if (s is! Map) continue;
    final step = Map<String, dynamic>.from(s);

    final startLoc = _latLngFromMap(step['start_location']);
    if (startLoc == null) continue;

    final html = step['html_instructions']?.toString() ?? '';
    final rawManeuver = step['maneuver']?.toString() ?? '';
    final normalized = _normalizeManeuver(rawManeuver, html);

    final distanceAtStart = walked;
    final dist = step['distance'];
    if (dist is Map) {
      final v = dist['value'];
      if (v is int) walked += v;
      if (v is num) walked += v.round();
    }

    // Keep only actionable points; fall back to "straight" later in UI if needed.
    final m = normalized.trim();
    if (m.isEmpty || m == 'straight') continue;

    out.add(
      RouteManeuverPoint(
        location: startLoc,
        maneuver: m,
        distanceFromStartMeters: distanceAtStart,
      ).toJson(),
    );
  }

  return out;
}

String _extractLaneGuidance(
  dynamic firstStep,
  String maneuver,
  String directionHtml,
) {
  String indication = '';
  try {
    final intersections = firstStep?['intersections'];
    if (intersections is List) {
      for (final inter in intersections) {
        final lanes = inter['lanes'];
        if (lanes is! List || lanes.isEmpty) continue;
        final validLanes = lanes
            .where((l) => l is Map && (l['valid'] == true))
            .cast<Map>()
            .toList();
        if (validLanes.isEmpty) continue;

        final firstValid = validLanes.first;
        final indications = firstValid['indications'];
        if (indications is List && indications.isNotEmpty) {
          indication = indications.first.toString().toLowerCase();
          break;
        }
      }
    }
  } catch (_) {}

  if (indication.isEmpty) {
    final text = directionHtml.toLowerCase();
    if (text.contains('keep left') || text.contains('slight left')) {
      indication = 'left';
    } else if (text.contains('keep right') || text.contains('slight right')) {
      indication = 'right';
    } else if (maneuver.toLowerCase().contains('left')) {
      indication = 'left';
    } else if (maneuver.toLowerCase().contains('right')) {
      indication = 'right';
    }
  }

  if (indication.contains('left')) return 'Keep left lane';
  if (indication.contains('right')) return 'Keep right lane';
  if (indication.contains('straight')) return 'Use straight lane';
  return '';
}
