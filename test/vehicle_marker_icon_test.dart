import 'package:flutter_test/flutter_test.dart';
import 'package:hopper/utils/map/vehicle_marker_icon.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('HopprVehicleMarkerIcon includes overridden logical size in config key', () {
    final key = HopprVehicleMarkerIcon.currentConfigKeyForServiceType(
      'car',
      logicalSizeDp: 48.0,
    );

    expect(key, contains('48.00x48.00'));
  });

  test('HopprVehicleMarkerIcon includes badge config key', () {
    final key = HopprVehicleMarkerIcon.currentBadgeConfigKeyForServiceType(
      'car',
      diameterDp: 48.0,
      imageScale: 0.70,
    );

    expect(key, startsWith('badge|'));
    expect(key, contains('|48.00|'));
  });
}
