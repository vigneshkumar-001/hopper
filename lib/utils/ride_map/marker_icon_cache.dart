import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:hopper/Core/Utility/images.dart';

import 'map_ui_config.dart';

enum RideVehicleType { car, bike, packageBike }

/// Loads and caches non-stretched marker icons across the app.
///
/// - Generates bitmaps once per (asset, logicalSize, dpr).
/// - Resizes using devicePixelRatio correctly.
/// - Preserves aspect ratio (contain) so the icon never stretches.
class MarkerIconCache {
  static final Map<String, Future<BitmapDescriptor>> _cache = {};

  static void clear() => _cache.clear();

  static String _assetForVehicle(RideVehicleType type) {
    switch (type) {
      case RideVehicleType.bike:
        return AppImages.parcelBike;
      case RideVehicleType.packageBike:
        return AppImages.packageBike;
      case RideVehicleType.car:
        return AppImages.movingCar;
    }
  }

  static double _dpr() {
    final views = WidgetsBinding.instance.platformDispatcher.views;
    if (views.isEmpty) return 2.0;
    return views.first.devicePixelRatio == 0 ? 2.0 : views.first.devicePixelRatio;
  }

  static Future<BitmapDescriptor> loadVehicle(RideVehicleType type) async {
    final asset = _assetForVehicle(type);
    final logical = (type == RideVehicleType.car)
        ? MapUiConfig.carMarkerSize
        : MapUiConfig.bikeMarkerSize;
    return _loadAssetContain(asset, logicalSize: logical);
  }

  static Future<BitmapDescriptor> loadPickupPin() {
    // Using existing `loc` asset for consistency with shared stop pin.
    return _loadAssetContain(AppImages.loc, logicalSize: MapUiConfig.pickupMarkerSize);
  }

  static Future<BitmapDescriptor> loadDropPin() {
    return _loadAssetContain(AppImages.loc, logicalSize: MapUiConfig.dropMarkerSize);
  }

  static Future<BitmapDescriptor> _loadAssetContain(
    String asset, {
    required double logicalSize,
  }) {
    final dpr = _dpr();
    final key = '$asset|${logicalSize.toStringAsFixed(2)}@${dpr.toStringAsFixed(2)}';
    return _cache.putIfAbsent(key, () async {
      final widthPx = (logicalSize * dpr).round().clamp(1, 1024);
      final heightPx = (logicalSize * dpr).round().clamp(1, 1024);
      final cfg = ImageConfiguration(devicePixelRatio: dpr);

      ui.Image? decoded;
      ui.Image? rendered;
      try {
        final provider = AssetImage(asset);
        final key = await provider.obtainKey(cfg);
        final bd = await key.bundle.load(key.name);

        final codec = await ui.instantiateImageCodec(bd.buffer.asUint8List());
        final frame = await codec.getNextFrame();
        decoded = frame.image;

        final recorder = ui.PictureRecorder();
        final canvas = ui.Canvas(recorder);
        final paint = ui.Paint()
          ..isAntiAlias = true
          ..filterQuality = ui.FilterQuality.high;

        final src = ui.Rect.fromLTWH(
          0,
          0,
          decoded.width.toDouble(),
          decoded.height.toDouble(),
        );
        final dst = ui.Rect.fromLTWH(0, 0, widthPx.toDouble(), heightPx.toDouble());

        // Contain (preserve aspect ratio), center in target.
        final scale = math.min(dst.width / src.width, dst.height / src.height);
        final drawW = src.width * scale;
        final drawH = src.height * scale;
        final offsetX = (dst.width - drawW) / 2.0;
        final offsetY = (dst.height - drawH) / 2.0;
        final dstFit = ui.Rect.fromLTWH(offsetX, offsetY, drawW, drawH);
        canvas.drawImageRect(decoded, src, dstFit, paint);

        final picture = recorder.endRecording();
        rendered = await picture.toImage(widthPx, heightPx);
        final png = await rendered.toByteData(format: ui.ImageByteFormat.png);
        if (png == null) return BitmapDescriptor.defaultMarker;
        return BitmapDescriptor.bytes(png.buffer.asUint8List());
      } catch (_) {
        // Fallback to plugin decoding if custom render fails.
        try {
          return await BitmapDescriptor.asset(
            cfg,
            asset,
            width: logicalSize,
            height: logicalSize,
          );
        } catch (_) {
          return BitmapDescriptor.defaultMarker;
        }
      } finally {
        try {
          decoded?.dispose();
        } catch (_) {}
        try {
          rendered?.dispose();
        } catch (_) {}
      }
    });
  }
}

