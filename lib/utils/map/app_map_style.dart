import 'package:flutter/services.dart' show rootBundle;

class AppMapStyle {
  static const String uberLightAsset = 'assets/map_style/map_style1.json';

  static String? _cachedUberLightStyle;

  static Future<String> loadUberLight() async {
    if (_cachedUberLightStyle != null) {
      return _cachedUberLightStyle!;
    }
    final style = await rootBundle.loadString(uberLightAsset);
    _cachedUberLightStyle = style;
    return style;
  }
}
