import 'package:spider_weighbridge/services/api_service.dart';

class AuthService {
  final ApiService api;
  const AuthService(this.api);
  Future<Map<String, dynamic>>? login({
    required String email,
    required String password,
  }) {
    try {} catch (e) {}
    return null;
  }

  Future<void> saveUserInSharedPrefs(Map<String, dynamic> user) async {}
}
