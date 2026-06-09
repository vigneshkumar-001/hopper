import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../model/bank_details_models.dart';

/// Local cache of the driver's saved withdraw bank. The backend has NO GET to
/// read bank details back, so after a successful save we persist them here and
/// the withdraw screen reads from this cache (masked).
class SavedBankStore {
  static const String _key = 'driver_saved_bank_v1';

  static Future<void> save(SavedBankDetails bank) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(bank.toJson()));
    } catch (_) {
      // Non-fatal: cache is best-effort.
    }
  }

  static Future<SavedBankDetails?> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null || raw.trim().isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return SavedBankDetails.fromJson(decoded);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  static Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (_) {}
  }
}
