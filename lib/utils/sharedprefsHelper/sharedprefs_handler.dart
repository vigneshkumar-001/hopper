import 'package:shared_preferences/shared_preferences.dart';

class SharedPrefHelper {
  static Future<String?> getToken() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  static Future<String?> getUserId() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('userId');
  }
  static Future<String?> getDriverId() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('driverId');
  }

  static Future<void> setToken(String token) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
  }

  static Future<void> setUserId(String userId) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('userId', userId);
  }
  static Future<void> setDriverId(String driverId) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('driverId', driverId);
  }

  static Future<void> clearAll() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
