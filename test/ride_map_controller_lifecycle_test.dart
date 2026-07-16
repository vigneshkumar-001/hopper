import 'package:flutter_test/flutter_test.dart';
import 'package:hopper/utils/ride_map/ride_map_controller.dart';

void main() {
  test('RideMapController disposal is idempotent', () {
    final controller = RideMapController(mode: RideMapMode.home);

    controller.dispose();

    expect(controller.dispose, returnsNormally);
  });
}
