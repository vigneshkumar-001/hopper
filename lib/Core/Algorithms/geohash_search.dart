import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'haversine.dart';

/// Geohash encoding + neighbor computation.
///
/// This file does NOT depend on Firestore. Callers can use the hashes to query
/// any backend/index, then filter results by Haversine distance.
class GeohashDriverSearch {
  static const String _base32 = '0123456789bcdefghjkmnpqrstuvwxyz';

  String encode(double lat, double lng, {int precision = 6}) {
    var minLat = -90.0, maxLat = 90.0;
    var minLng = -180.0, maxLng = 180.0;
    var isEven = true;
    var bit = 0, ch = 0;
    final hash = StringBuffer();

    while (hash.length < precision) {
      if (isEven) {
        final mid = (minLng + maxLng) / 2.0;
        if (lng > mid) {
          ch |= 1 << (4 - bit);
          minLng = mid;
        } else {
          maxLng = mid;
        }
      } else {
        final mid = (minLat + maxLat) / 2.0;
        if (lat > mid) {
          ch |= 1 << (4 - bit);
          minLat = mid;
        } else {
          maxLat = mid;
        }
      }

      isEven = !isEven;
      if (bit < 4) {
        bit++;
      } else {
        hash.write(_base32[ch]);
        bit = 0;
        ch = 0;
      }
    }

    return hash.toString();
  }

  /// Returns 8 adjacent geohashes: N, NE, E, SE, S, SW, W, NW.
  List<String> getNeighborHashes(String hash) {
    final n = _neighbor(hash, _Dir.n);
    final s = _neighbor(hash, _Dir.s);
    final e = _neighbor(hash, _Dir.e);
    final w = _neighbor(hash, _Dir.w);
    return <String>[
      n,
      _neighbor(n, _Dir.e),
      e,
      _neighbor(s, _Dir.e),
      s,
      _neighbor(s, _Dir.w),
      w,
      _neighbor(n, _Dir.w),
    ];
  }

  /// Helper that filters arbitrary driver candidates by real distance.
  List<T> filterWithinRadius<T>({
    required LatLng center,
    required double radiusKm,
    required Iterable<T> candidates,
    required LatLng Function(T) locationOf,
  }) {
    final rMeters = radiusKm * 1000.0;
    final out = <T>[];
    for (final c in candidates) {
      final loc = locationOf(c);
      if (Haversine.distanceMeters(center, loc) <= rMeters) out.add(c);
    }
    out.sort((a, b) {
      final da = Haversine.distanceMeters(center, locationOf(a));
      final db = Haversine.distanceMeters(center, locationOf(b));
      return da.compareTo(db);
    });
    return out;
  }

  // ---------------- internal neighbor algorithm ----------------

  static const Map<_Dir, String> _neighborEven = <_Dir, String>{
    _Dir.n: 'p0r21436x8zb9dcf5h7kjnmqesgutwvy',
    _Dir.s: '14365h7k9dcfesgujnmqp0r2twvyx8zb',
    _Dir.e: 'bc01fg45238967deuvhjyznpkmstqrwx',
    _Dir.w: '238967debc01fg45kmstqrwxuvhjyznp',
  };

  static const Map<_Dir, String> _neighborOdd = <_Dir, String>{
    _Dir.n: 'bc01fg45238967deuvhjyznpkmstqrwx',
    _Dir.s: '238967debc01fg45kmstqrwxuvhjyznp',
    _Dir.e: 'p0r21436x8zb9dcf5h7kjnmqesgutwvy',
    _Dir.w: '14365h7k9dcfesgujnmqp0r2twvyx8zb',
  };

  static const Map<_Dir, String> _borderEven = <_Dir, String>{
    _Dir.n: 'prxz',
    _Dir.s: '028b',
    _Dir.e: 'bcfguvyz',
    _Dir.w: '0145hjnp',
  };

  static const Map<_Dir, String> _borderOdd = <_Dir, String>{
    _Dir.n: 'bcfguvyz',
    _Dir.s: '0145hjnp',
    _Dir.e: 'prxz',
    _Dir.w: '028b',
  };

  String _neighbor(String hash, _Dir dir) {
    if (hash.isEmpty) return hash;
    final last = hash.substring(hash.length - 1);
    final parent = hash.substring(0, hash.length - 1);
    final isOdd = hash.length.isOdd;
    final border = (isOdd ? _borderOdd : _borderEven)[dir]!;
    final neighbor = (isOdd ? _neighborOdd : _neighborEven)[dir]!;

    final newParent =
        border.contains(last) && parent.isNotEmpty ? _neighbor(parent, dir) : parent;
    final idx = neighbor.indexOf(last);
    final repl = _base32[idx >= 0 ? idx : 0];
    return newParent + repl;
  }
}

enum _Dir { n, s, e, w }

// Utility (not strictly needed above, but kept for callers needing grid sizing).
double geohashCellApproxSizeKm(int precision) {
  // Rough average at equator; used only for heuristics.
  // Source: common geohash tables.
  const table = <int, double>{
    1: 5000,
    2: 1250,
    3: 156,
    4: 39.1,
    5: 4.89,
    6: 1.22,
    7: 0.153,
    8: 0.0382,
  };
  final v = table[precision.clamp(1, 8)] ?? 1.22;
  return v;
}
