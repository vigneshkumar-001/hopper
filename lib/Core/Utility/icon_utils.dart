import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Icon helpers for Google Maps markers.
///
/// - Caches scaled bitmaps to avoid re-decoding on every camera move.
/// - Lets you scale driver marker with zoom (Uber/Ola feel).
class IconUtils {
  static final Map<String, BitmapDescriptor> _iconCache = <String, BitmapDescriptor>{};

  static void clearCache() => _iconCache.clear();

  static bool shouldUpdateIcon(double oldZoom, double newZoom) =>
      (newZoom - oldZoom).abs() > 0.5;

  static Future<BitmapDescriptor> getScaledDriverIcon({
    required String assetPath,
    required double zoom,
    required String vehicleType,
  }) async {
    final size = ((zoom - 10.0) * 5.0 + 30.0).clamp(24.0, 80.0);
    final cacheKey = '${vehicleType}_${size.toInt()}@$assetPath';
    final hit = _iconCache[cacheKey];
    if (hit != null) return hit;

    final data = await rootBundle.load(assetPath);
    final codec = await ui.instantiateImageCodec(
      data.buffer.asUint8List(),
      targetWidth: size.toInt(),
      targetHeight: size.toInt(),
    );
    final frame = await codec.getNextFrame();
    final bytes = await frame.image.toByteData(format: ui.ImageByteFormat.png);
    final icon = BitmapDescriptor.bytes(bytes!.buffer.asUint8List());
    _iconCache[cacheKey] = icon;
    return icon;
  }
}

