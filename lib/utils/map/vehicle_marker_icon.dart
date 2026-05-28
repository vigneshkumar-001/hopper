import 'dart:math' as math;
import 'dart:typed_data';
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

  /// Customer app uses ~48dp vehicle markers on the map for clarity.
  /// Driver app can optionally opt-in per-screen via [logicalSizeDp].
  static const double defaultLogicalSizeDpCar = MapUiConfig.carMarkerSize;
  static const double defaultLogicalSizeDpBike = MapUiConfig.bikeMarkerSize;

  // Badge rendering defaults (customer-like).
  static const int _badgeStrokeColorArgb = 0xFFE5E7EB;
  static const int _badgeFillColorArgb = 0xFFFFFFFF;

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
    final logical = isBike ? defaultLogicalSizeDpBike : defaultLogicalSizeDpCar;
    final width = logical;
    final height = logical;

    return ImageConfiguration(size: Size(width, height), devicePixelRatio: dpr);
  }

  static String currentConfigKeyForServiceType(
    dynamic serviceType, {
    double? logicalSizeDp,
  }) {
    final type = fromServiceType(serviceType);
    final asset = assetForType(type);
    final cfg = _imageConfigForVehicleTypeWithOverride(type, logicalSizeDp: logicalSizeDp);
    final size = cfg.size ?? const Size(0, 0);
    final dpr = cfg.devicePixelRatio ?? 2.0;
    return '$asset|${type.name}:${size.width.toStringAsFixed(2)}x${size.height.toStringAsFixed(2)}@${dpr.toStringAsFixed(2)}';
  }

  static Future<BitmapDescriptor> loadForServiceType(
    dynamic serviceType, {
    double? logicalSizeDp,
  }) {
    final type = fromServiceType(serviceType);
    return loadForType(type, logicalSizeDp: logicalSizeDp);
  }

  /// Customer-like circular badge icon for better contrast and perceived clarity.
  /// This keeps the vehicle centered within a white circle + light border.
  static Future<BitmapDescriptor> loadBadgeForServiceType(
    dynamic serviceType, {
    double diameterDp = 48.0,
    double imageScale = 0.62,
  }) {
    final type = fromServiceType(serviceType);
    return loadBadgeForType(type, diameterDp: diameterDp, imageScale: imageScale);
  }

  static String currentBadgeConfigKeyForServiceType(
    dynamic serviceType, {
    double diameterDp = 48.0,
    double imageScale = 0.62,
  }) {
    final type = fromServiceType(serviceType);
    final asset = assetForType(type);
    final dpr = _devicePixelRatio().clamp(1.0, 4.0);
    final diameter = diameterDp.clamp(18.0, 96.0);
    return 'badge|$asset|${diameter.toStringAsFixed(2)}|${imageScale.toStringAsFixed(3)}@${dpr.toStringAsFixed(2)}';
  }

  static Future<BitmapDescriptor> loadForType(
    HopprVehicleType type, {
    double? logicalSizeDp,
  }) {
    final asset = assetForType(type);
    final cfg = _imageConfigForVehicleTypeWithOverride(type, logicalSizeDp: logicalSizeDp);
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

  static Future<BitmapDescriptor> loadBadgeForType(
    HopprVehicleType type, {
    double diameterDp = 48.0,
    double imageScale = 0.62,
  }) {
    final asset = assetForType(type);
    final dpr = _devicePixelRatio().clamp(1.0, 4.0);
    final diameter = diameterDp.clamp(18.0, 96.0);
    final key = 'badge|$asset|${diameter.toStringAsFixed(2)}|${imageScale.toStringAsFixed(3)}@${dpr.toStringAsFixed(2)}';

    return _cache.putIfAbsent(key, () async {
      final targetPx = (diameter * dpr).round().clamp(18, 512);
      try {
        final bytes = await _badgePngBytesFromAsset(
          asset,
          dpr: dpr,
          targetPx: targetPx,
          imageScale: imageScale.clamp(0.35, 0.88),
        );
        if (bytes == null) return BitmapDescriptor.defaultMarker;
        return BitmapDescriptor.bytes(bytes);
      } catch (_) {
        return BitmapDescriptor.defaultMarker;
      }
    });
  }

  static ImageConfiguration _imageConfigForVehicleTypeWithOverride(
    HopprVehicleType type, {
    double? logicalSizeDp,
  }) {
    if (logicalSizeDp == null) return _imageConfigForVehicleType(type);
    final dpr = _devicePixelRatio();
    final logical = logicalSizeDp.clamp(8.0, 96.0);
    return ImageConfiguration(
      size: Size(logical, logical),
      devicePixelRatio: dpr,
    );
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

  static Future<ui.Rect?> _opaqueBounds(ui.Image image) async {
    const int alphaThreshold = 12;
    ByteData? bd;
    try {
      bd = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    } catch (_) {
      bd = null;
    }
    if (bd == null) return null;

    final bytes = bd.buffer.asUint8List();
    final w = image.width;
    final h = image.height;
    int minX = w, minY = h, maxX = -1, maxY = -1;

    for (int y = 0; y < h; y++) {
      final rowOffset = y * w * 4;
      for (int x = 0; x < w; x++) {
        final a = bytes[rowOffset + x * 4 + 3];
        if (a > alphaThreshold) {
          if (x < minX) minX = x;
          if (y < minY) minY = y;
          if (x > maxX) maxX = x;
          if (y > maxY) maxY = y;
        }
      }
    }

    if (maxX < 0 || maxY < 0) return null;
    minX = (minX - 1).clamp(0, w - 1);
    minY = (minY - 1).clamp(0, h - 1);
    maxX = (maxX + 1).clamp(0, w - 1);
    maxY = (maxY + 1).clamp(0, h - 1);
    return ui.Rect.fromLTRB(
      minX.toDouble(),
      minY.toDouble(),
      (maxX + 1).toDouble(),
      (maxY + 1).toDouble(),
    );
  }

  static Future<Uint8List?> _badgePngBytesFromAsset(
    String asset, {
    required double dpr,
    required int targetPx,
    required double imageScale,
  }) async {
    ui.Image? decoded;
    ui.Image? rendered;
    try {
      final cfg = ImageConfiguration(devicePixelRatio: dpr);
      final provider = AssetImage(asset);
      final key = await provider.obtainKey(cfg);
      final bd = await key.bundle.load(key.name);
      final codec = await ui.instantiateImageCodec(bd.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      decoded = frame.image;

      final srcRect = (await _opaqueBounds(decoded)) ??
          ui.Rect.fromLTWH(
            0,
            0,
            decoded.width.toDouble(),
            decoded.height.toDouble(),
          );

      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(
        recorder,
        ui.Rect.fromLTWH(0, 0, targetPx.toDouble(), targetPx.toDouble()),
      );

      final center = ui.Offset(targetPx / 2.0, targetPx / 2.0);
      final radius = targetPx / 2.0;
      final stroke = (targetPx * 0.06).clamp(1.0, 6.0);

      final fillPaint = ui.Paint()
        ..isAntiAlias = true
        ..color = const ui.Color(_badgeFillColorArgb);
      final strokePaint = ui.Paint()
        ..isAntiAlias = true
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = const ui.Color(_badgeStrokeColorArgb);

      canvas.drawCircle(center, radius * 0.88, fillPaint);
      canvas.drawCircle(center, radius * 0.88, strokePaint);

      // Vehicle image contained inside a scaled box to make it more readable.
      final box = targetPx * imageScale;
      final dst = ui.Rect.fromCenter(center: center, width: box, height: box);

      final paint = ui.Paint()
        ..isAntiAlias = true
        ..filterQuality = ui.FilterQuality.high;

      // Preserve aspect ratio by fitting within dst rect.
      final scale = math.min(dst.width / srcRect.width, dst.height / srcRect.height);
      final drawW = srcRect.width * scale;
      final drawH = srcRect.height * scale;
      final dstFit = ui.Rect.fromCenter(
        center: center,
        width: drawW,
        height: drawH,
      );

      canvas.drawImageRect(decoded, srcRect, dstFit, paint);

      final picture = recorder.endRecording();
      rendered = await picture.toImage(targetPx, targetPx);
      final png = await rendered.toByteData(format: ui.ImageByteFormat.png);
      return png?.buffer.asUint8List();
    } catch (_) {
      return null;
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
