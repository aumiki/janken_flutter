import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';
import '../models/user.dart';

class AuthService {
  static const _tokenKey = 'jwt_token';
  static const _userKey = 'user_data';

  static String? _token;
  static UserModel? _currentUser;

  static String? get token => _token;
  static UserModel? get currentUser => _currentUser;

  /// Load stored token + user from SharedPreferences
  static Future<bool> loadFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_tokenKey);
    final userJson = prefs.getString(_userKey);
    if (_token != null && userJson != null) {
      try {
        _currentUser = UserModel.fromJson(jsonDecode(userJson));
        return true;
      } catch (_) {}
    }
    return false;
  }

  static Future<void> saveAuth(String token, UserModel user) async {
    _token = token;
    _currentUser = user;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_userKey, jsonEncode(user.toJson()));
  }

  static Future<void> updateUser(UserModel user) async {
    _currentUser = user;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, jsonEncode(user.toJson()));
  }

  static Future<void> clearAuth() async {
    _token = null;
    _currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
  }

  static Map<String, String> get authHeaders => {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  // ── Login ──────────────────────────────────────────────────
  static Future<Map<String, dynamic>> login(
      String email, String password) async {
    final res = await http.post(
      Uri.parse('${AppConfig.baseUrl}${AppConfig.loginEndpoint}'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode == 200) {
      final user = UserModel.fromJson(data['user']);
      await saveAuth(data['token'], user);
      return {'success': true, 'user': user};
    }
    return {'success': false, 'error': data['error'] ?? 'Login gagal'};
  }

  // ── Register ───────────────────────────────────────────────
  static Future<Map<String, dynamic>> register(
      String username, String email, String password) async {
    final res = await http.post(
      Uri.parse('${AppConfig.baseUrl}${AppConfig.registerEndpoint}'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(
          {'username': username, 'email': email, 'password': password}),
    );
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode == 201 || res.statusCode == 200) {
      return {'success': true};
    }
    return {'success': false, 'error': data['error'] ?? 'Registrasi gagal'};
  }

  // ── Guest ──────────────────────────────────────────────────
  static Future<Map<String, dynamic>> loginAsGuest(String username) async {
    final res = await http.post(
      Uri.parse('${AppConfig.baseUrl}${AppConfig.guestEndpoint}'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username}),
    );
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode == 200) {
      final user = UserModel.fromJson(data['user']);
      await saveAuth(data['token'], user);
      return {'success': true, 'user': user};
    }
    return {'success': false, 'error': data['error'] ?? 'Gagal masuk sebagai tamu'};
  }

  // ── Logout ─────────────────────────────────────────────────
  static Future<void> logout() async {
    try {
      await http.post(
        Uri.parse('${AppConfig.baseUrl}${AppConfig.logoutEndpoint}'),
        headers: authHeaders,
      );
    } catch (_) {}
    await clearAuth();
  }

  // ── Fetch profile ──────────────────────────────────────────
  static Future<UserModel?> fetchProfile() async {
    try {
      final res = await http.get(
        Uri.parse('${AppConfig.baseUrl}${AppConfig.profileEndpoint}'),
        headers: authHeaders,
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final user = UserModel.fromJson(data['user']);
        await updateUser(user);
        return user;
      }
    } catch (_) {}
    return null;
  }

  // ── Update profile (username/avatar) ──────────────────────
  static Future<Map<String, dynamic>> updateProfile(
      {String? username, String? avatar}) async {
    final body = <String, dynamic>{};
    if (username != null) body['username'] = username;
    if (avatar != null) body['avatar'] = avatar;

    final res = await http.patch(
      Uri.parse('${AppConfig.baseUrl}${AppConfig.profileEndpoint}'),
      headers: authHeaders,
      body: jsonEncode(body),
    );
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode == 200) {
      final user = UserModel.fromJson(data['user']);
      await updateUser(user);
      return {'success': true, 'user': user};
    }
    return {'success': false, 'error': data['error'] ?? 'Gagal update profil'};
  }
}
