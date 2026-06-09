import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:typed_data';

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

  static Future<ui.Rect?> _opaqueBounds(ui.Image image) async {
    // Determine tight bounds for non-transparent pixels so icons with extra
    // whitespace (common with PNG exports) render compactly like Ola/Uber.
    // This runs once per cached icon and is safe for production.
    // NOTE: We treat very low alpha as transparent to avoid noisy edges.
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

    // bytes are RGBA, so alpha is at index + 3
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
    // Expand by 1px to preserve edge antialiasing.
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

  static Future<Uint8List?> _renderContainedCroppedPngBytes({
    required ui.Image srcImage,
    required int targetWidthPx,
    required int targetHeightPx,
    bool withShadow = false,
  }) async {
    final srcRect = (await _opaqueBounds(srcImage)) ??
        ui.Rect.fromLTWH(
          0,
          0,
          srcImage.width.toDouble(),
          srcImage.height.toDouble(),
        );

    final cropW = srcRect.width;
    final cropH = srcRect.height;
    if (cropW <= 1 || cropH <= 1) return null;

    // With a shadow we leave headroom so the blurred silhouette isn't clipped.
    final double contentScale = withShadow ? 0.80 : 1.0;
    final double availW = targetWidthPx * contentScale;
    final double availH = targetHeightPx * contentScale;

    // Contain within the available box without stretching.
    final scale = math.min(availW / cropW, availH / cropH);
    final dstW = cropW * scale;
    final dstH = cropH * scale;
    final dx = (targetWidthPx - dstW) / 2.0;
    final dy = (targetHeightPx - dstH) / 2.0;
    final dstRect = ui.Rect.fromLTWH(dx, dy, dstW, dstH);

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(
      recorder,
      ui.Rect.fromLTWH(0, 0, targetWidthPx.toDouble(), targetHeightPx.toDouble()),
    );

    if (withShadow) {
      // Uber/Ola-style soft "floating" shadow: a blurred dark silhouette of the
      // vehicle, nudged down so it reads as a ground shadow under the car.
      final double shadowDy = targetHeightPx * 0.06;
      final shadowRect = ui.Rect.fromLTWH(dx, dy + shadowDy, dstW, dstH);
      final shadowPaint = ui.Paint()
        ..isAntiAlias = true
        ..colorFilter =
            const ui.ColorFilter.mode(ui.Color(0x4D000000), ui.BlendMode.srcIn)
        ..maskFilter =
            ui.MaskFilter.blur(ui.BlurStyle.normal, targetWidthPx * 0.04);
      canvas.drawImageRect(srcImage, srcRect, shadowRect, shadowPaint);
    }

    final paint = ui.Paint()
      ..isAntiAlias = true
      ..filterQuality = ui.FilterQuality.high;
    canvas.drawImageRect(srcImage, srcRect, dstRect, paint);

    final picture = recorder.endRecording();
    final img = await picture.toImage(targetWidthPx, targetHeightPx);
    final png = await img.toByteData(format: ui.ImageByteFormat.png);
    return png?.buffer.asUint8List();
  }


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
    return _loadAssetContain(asset, logicalSize: logical, withShadow: true);
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
    bool withShadow = false,
  }) {
    final dpr = _dpr();
    final key =
        '$asset|${logicalSize.toStringAsFixed(2)}@${dpr.toStringAsFixed(2)}|s${withShadow ? 1 : 0}';
    return _cache.putIfAbsent(key, () async {
      final widthPx = (logicalSize * dpr).round().clamp(1, 1024);
      final heightPx = (logicalSize * dpr).round().clamp(1, 1024);
      final cfg = ImageConfiguration(devicePixelRatio: dpr);

      try {
        // Prefer direct codec decode + crop transparent padding + contain render.
        final provider = AssetImage(asset);
        final assetKey = await provider.obtainKey(cfg);
        final bd = await assetKey.bundle.load(assetKey.name);
        final codec = await ui.instantiateImageCodec(bd.buffer.asUint8List());
        final frame = await codec.getNextFrame();
        final bytes = await _renderContainedCroppedPngBytes(
          srcImage: frame.image,
          targetWidthPx: widthPx,
          targetHeightPx: heightPx,
          withShadow: withShadow,
        );
        if (bytes == null) return BitmapDescriptor.defaultMarker;
        return BitmapDescriptor.bytes(bytes);
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
      }
    });
  }


}
