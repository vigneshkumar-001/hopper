import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:hopper/Core/Utility/images.dart';
import 'package:hopper/utils/ride_map/map_ui_config.dart';

enum HopprVehicleType { car, bike, packageBike, unknown }

/// Single source of truth for:
/// - mapping serviceType -> vehicle icon asset
/// - consistent (responsive) marker sizing across the app
/// - caching BitmapDescriptors to avoid re-decoding on every screen
class HopprVehicleMarkerIcon {
  static final Map<String, Future<BitmapDescriptor>> _cache = {};

  static void clearCache() => _cache.clear();

  static HopprVehicleType fromServiceType(dynamic raw) {
    final v = (raw ?? '').toString().trim().toLowerCase();
    if (v.isEmpty) return HopprVehicleType.unknown;
    if (v == 'car') return HopprVehicleType.car;
    if (v == 'bike') return HopprVehicleType.bike;
    if (v.contains('package') || v.contains('parcel')) {
      return HopprVehicleType.packageBike;
    }
    return HopprVehicleType.unknown;
  }

  static String assetForType(HopprVehicleType type) {
    switch (type) {
      case HopprVehicleType.bike:
        return AppImages.parcelBike;
      case HopprVehicleType.packageBike:
        return AppImages.packageBike;
      case HopprVehicleType.car:
        return AppImages.movingCar;
      case HopprVehicleType.unknown:
        return AppImages.movingCar;
    }
  }

  static double _devicePixelRatio() {
    final views = WidgetsBinding.instance.platformDispatcher.views;
    if (views.isEmpty) return 2.0;
    return views.first.devicePixelRatio;
  }

  static ImageConfiguration _imageConfigForVehicleType(HopprVehicleType type) {
    final dpr = _devicePixelRatio();

    final bool isBike =
        type == HopprVehicleType.bike || type == HopprVehicleType.packageBike;

    // IMPORTANT: Fixed logical size everywhere (no device-size scaling) so bike/car
    // marker footprint stays consistent across all screens.
    final logical = isBike ? MapUiConfig.bikeMarkerSize : MapUiConfig.carMarkerSize;
    final width = logical;
    final height = logical;

    return ImageConfiguration(size: Size(width, height), devicePixelRatio: dpr);
  }

  static String currentConfigKeyForServiceType(dynamic serviceType) {
    final type = fromServiceType(serviceType);
    final asset = assetForType(type);
    final cfg = _imageConfigForVehicleType(type);
    final size = cfg.size ?? const Size(0, 0);
    final dpr = cfg.devicePixelRatio ?? 2.0;
    return '$asset|${type.name}:${size.width.toStringAsFixed(2)}x${size.height.toStringAsFixed(2)}@${dpr.toStringAsFixed(2)}';
  }

  static Future<BitmapDescriptor> loadForServiceType(dynamic serviceType) {
    final type = fromServiceType(serviceType);
    return loadForType(type);
  }

  static Future<BitmapDescriptor> loadForType(HopprVehicleType type) {
    final asset = assetForType(type);
    final cfg = _imageConfigForVehicleType(type);
    final size = cfg.size ?? const Size(0, 0);
    final dpr = cfg.devicePixelRatio ?? 2.0;
    final key =
        '$asset|${size.width.toStringAsFixed(2)}x${size.height.toStringAsFixed(2)}|${dpr.toStringAsFixed(2)}';

    return _cache.putIfAbsent(key, () async {
      try {
        // Prefer byte-based rendering so we can enforce exact width+height
        // (some plugin builds prioritize width and keep aspect ratio).
        final widthPx = (size.width * dpr).round().clamp(1, 512);
        final heightPx = (size.height * dpr).round().clamp(1, 512);
        return await _bitmapFromAssetExact(
          asset,
          cfg: cfg,
          widthPx: widthPx,
          heightPx: heightPx,
        );
      } catch (_) {
        // Fallback: plugin asset decoding (may keep aspect ratio).
        try {
          return await BitmapDescriptor.asset(
            cfg,
            asset,
            width: size.width,
            height: size.height,
          );
        } catch (_) {
          try {
            // ignore: deprecated_member_use
            return await BitmapDescriptor.fromAssetImage(cfg, asset);
          } catch (_) {
            return BitmapDescriptor.defaultMarker;
          }
        }
      }
    });
  }

  static Future<BitmapDescriptor> _bitmapFromAssetExact(
    String asset, {
    required ImageConfiguration cfg,
    required int widthPx,
    required int heightPx,
  }) async {
    ui.Image? decoded;
    ui.Image? rendered;
    try {
      // IMPORTANT: Use AssetImage + ImageConfiguration so Flutter picks the best
      // resolution variant (2.0x/3.0x) for the current device.
      final provider = AssetImage(asset);
      final key = await provider.obtainKey(cfg);
      final bd = await key.bundle.load(key.name);

      final codec = await ui.instantiateImageCodec(bd.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      decoded = frame.image;

      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      final paint =
          ui.Paint()
            ..isAntiAlias = true
            ..filterQuality = ui.FilterQuality.high;

      final src = ui.Rect.fromLTWH(
        0,
        0,
        decoded.width.toDouble(),
        decoded.height.toDouble(),
      );
      final dst = ui.Rect.fromLTWH(
        0,
        0,
        widthPx.toDouble(),
        heightPx.toDouble(),
      );

      // Preserve aspect ratio (contain) so the vehicle doesn't look stretched.
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
      return BitmapDescriptor.defaultMarker;
    } finally {
      try {
        decoded?.dispose();
      } catch (_) {}
      try {
        rendered?.dispose();
      } catch (_) {}
    }
  }
}
