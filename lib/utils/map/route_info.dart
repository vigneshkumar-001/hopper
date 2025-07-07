import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';

Future<Map<String, dynamic>> getRouteInfo({
  required LatLng origin,
  required LatLng destination,
}) async {
  const String apiKey = "AIzaSyB_QYxuo9RQbTYz0XcuxBYLkh-ws5PYr7A";

  final url =
      'https://maps.googleapis.com/maps/api/directions/json?origin=${origin.latitude},${origin.longitude}&destination=${destination.latitude},${destination.longitude}&key=$apiKey';

  final response = await http.get(Uri.parse(url));

  if (response.statusCode == 200) {
    final data = json.decode(response.body);

    final route = data['routes'][0];
    final leg = route['legs'][0];
    final steps = leg['steps'];

    final polyline = route['overview_polyline']['points'];
    final directionText = steps[0]['html_instructions'];
    final distance = steps[0]['distance']['text'];

    return {
      "direction": directionText,
      "distance": distance,
      "polyline": polyline,
    };
  } else {
    throw Exception('Failed to fetch route');
  }
}
List<LatLng> decodePolyline(String encoded) {
  List<LatLng> points = [];
  int index = 0, len = encoded.length;
  int lat = 0, lng = 0;

  while (index < len) {
    int b, shift = 0, result = 0;
    do {
      b = encoded.codeUnitAt(index++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
    lat += dlat;

    shift = 0;
    result = 0;
    do {
      b = encoded.codeUnitAt(index++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
    lng += dlng;

    points.add(LatLng(lat / 1E5, lng / 1E5));
  }

  return points;
}
