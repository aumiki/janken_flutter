import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/user.dart';
import '../services/auth_service.dart';

class ApiService {
  static Future<List<UserModel>> fetchLeaderboard() async {
    try {
      final res = await http.get(
        Uri.parse('${AppConfig.baseUrl}${AppConfig.leaderboardEndpoint}'),
        headers: AuthService.authHeaders,
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final users = (data['users'] as List)
            .map((u) => UserModel.fromJson(u))
            .toList();
        return users;
      }
    } catch (e) {
      print('[API] fetchLeaderboard error: $e');
    }
    return [];
  }
}
