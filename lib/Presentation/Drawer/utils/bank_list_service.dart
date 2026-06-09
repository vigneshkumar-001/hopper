import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hopper/Core/Constants/log.dart';
import '../model/bank_details_models.dart';
import 'nigerian_banks.dart';

/// Supplies the Nigerian bank list for the withdraw bank picker.
///
/// Order of preference:
///   1. In-memory (this session).
///   2. Cached list from a previous live fetch (SharedPreferences).
///   3. Live Paystack list — ONLY if [_paystackProxyUrl] is configured.
///   4. Bundled static list ([kNigerianBanksStatic]) — always works offline.
///
/// SECURITY: Paystack's `GET https://api.paystack.co/bank` requires your SECRET
/// key, which must NEVER ship inside a mobile app. To use live data, expose a
/// thin backend proxy (e.g. GET /users/banks) that calls Paystack server-side
/// and returns `{ data: [{ name, code }] }`, then put that URL in
/// [_paystackProxyUrl]. Until then the static list is used (safe + reliable).
class BankListService {
  // Leave empty to use the static list. Point this at a BACKEND proxy that
  // returns Paystack's bank list — do NOT point it directly at Paystack with a
  // secret key embedded in the app.
  static const String _paystackProxyUrl = '';

  static const String _cacheKey = 'nigerian_banks_cache_v1';

  static List<NigerianBank>? _memory;

  static Future<List<NigerianBank>> getBanks() async {
    if (_memory != null && _memory!.isNotEmpty) return _memory!;

    // 2) Cached from a previous live fetch.
    final cached = await _loadCache();
    if (cached.isNotEmpty) {
      _memory = cached;
      // Refresh in the background for next time.
      if (_paystackProxyUrl.isNotEmpty) {
        _fetchLive().then((live) {
          if (live.isNotEmpty) {
            _memory = live;
            _saveCache(live);
          }
        });
      }
      return cached;
    }

    // 3) Live (only when a proxy URL is configured).
    if (_paystackProxyUrl.isNotEmpty) {
      final live = await _fetchLive();
      if (live.isNotEmpty) {
        _memory = live;
        await _saveCache(live);
        return live;
      }
    }

    // 4) Static fallback — always available.
    _memory = kNigerianBanksStatic;
    return kNigerianBanksStatic;
  }

  static Future<List<NigerianBank>> _fetchLive() async {
    try {
      final dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );
      final res = await dio.get(_paystackProxyUrl);
      final data = res.data;
      final list = (data is Map ? data['data'] : data);
      if (list is List) {
        final banks = list
            .whereType<Map>()
            .map((e) => NigerianBank.fromJson(Map<String, dynamic>.from(e)))
            .where((b) => b.name.isNotEmpty && b.code.isNotEmpty)
            .toList();
        if (banks.isNotEmpty) return banks;
      }
    } catch (e) {
      CommonLogger.log.w('Bank list live fetch failed, using static: $e');
    }
    return const <NigerianBank>[];
  }

  static Future<List<NigerianBank>> _loadCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw == null || raw.trim().isEmpty) return const <NigerianBank>[];
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((e) => NigerianBank.fromJson(Map<String, dynamic>.from(e)))
            .where((b) => b.name.isNotEmpty && b.code.isNotEmpty)
            .toList();
      }
    } catch (_) {}
    return const <NigerianBank>[];
  }

  static Future<void> _saveCache(List<NigerianBank> banks) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = jsonEncode(
        banks.map((b) => {'name': b.name, 'code': b.code}).toList(),
      );
      await prefs.setString(_cacheKey, raw);
    } catch (_) {}
  }
}
