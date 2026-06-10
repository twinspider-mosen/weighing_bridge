import 'package:weighing_bridge/services/api_service.dart';

class AuthService {
  final ApiService api;
  const AuthService(this.api);
  Future<Map<String,dynamic>>? login({required String email, required String password}){
    try {
      
    } catch (e) {
      
    }
  }

  Future<void> saveUserInSharedPrefs(Map<String,dynamic> user)async{
    
  }

}