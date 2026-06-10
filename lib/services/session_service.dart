import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:weighing_bridge/model/user_model.dart';

class SessionService {
  static const String _usersKey = 'available_users';
  static const String _activeTokenKey = 'active_token';
  static const String _activeUserKey = 'active_user';
  static const String _activeSubdomainKey = 'active_subdomain';

  /// Saves a user session. Overwrites active user but keeps existing users in hash.
  static Future<void> saveUser(UserModel user) async {
    final prefs = await SharedPreferences.getInstance();

    // Set active token & user
    await prefs.setString(_activeTokenKey, user.token);
    await prefs.setString(_activeUserKey, user.toJson());

    // Update available users hash
    final String? usersJson = prefs.getString(_usersKey);
    Map<String, dynamic> usersMap = {};
    if (usersJson != null && usersJson.isNotEmpty) {
      usersMap = json.decode(usersJson);
    }
    
    usersMap[user.id] = user.toMap();
    await prefs.setString(_usersKey, json.encode(usersMap));
  }

  /// Switches the active user to the one matching the given email ID.
  static Future<void> switchActiveUser(String emailId) async {
    final prefs = await SharedPreferences.getInstance();
    final String? usersJson = prefs.getString(_usersKey);
    if (usersJson != null && usersJson.isNotEmpty) {
      final Map<String, dynamic> usersMap = json.decode(usersJson);
      if (usersMap.containsKey(emailId)) {
        final user = UserModel.fromMap(usersMap[emailId]);
        await prefs.setString(_activeTokenKey, user.token);
        await prefs.setString(_activeUserKey, user.toJson());
      }
    }
  }

  /// Removes a user. If it's the active user, clears the active session.
  static Future<void> removeUser(String emailId) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Update hash
    final String? usersJson = prefs.getString(_usersKey);
    if (usersJson != null && usersJson.isNotEmpty) {
      final Map<String, dynamic> usersMap = json.decode(usersJson);
      usersMap.remove(emailId);
      await prefs.setString(_usersKey, json.encode(usersMap));
    }

    // Clear active session if it was the active user
    final activeUser = await getActiveUser();
    if (activeUser != null && activeUser.id == emailId) {
      await prefs.remove(_activeTokenKey);
      await prefs.remove(_activeUserKey);
    }
  }

  /// Logs out the active user. If other users exist, switches to the first available one.
  static Future<bool> logoutActiveUser() async {
    final activeUser = await getActiveUser();
    if (activeUser != null) {
      await removeUser(activeUser.id);
      
      final users = await getAvailableUsers();
      if (users.isNotEmpty) {
        // Automatically switch to the next available user
        await switchActiveUser(users.first.id);
        return true; // Still logged in as someone else
      }
    }
    return false; // No users left, redirect to login
  }

  /// Gets the currently active user model
  static Future<UserModel?> getActiveUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString(_activeUserKey);
    if (userJson != null && userJson.isNotEmpty) {
      return UserModel.fromJson(userJson);
    }
    return null;
  }

  /// Gets all available logged-in users
  static Future<List<UserModel>> getAvailableUsers() async {
    final prefs = await SharedPreferences.getInstance();
    final String? usersJson = prefs.getString(_usersKey);
    if (usersJson != null && usersJson.isNotEmpty) {
      final Map<String, dynamic> usersMap = json.decode(usersJson);
      return usersMap.values.map((v) => UserModel.fromMap(v)).toList();
    }
    return [];
  }

  /// Helper to check if a valid session exists on startup
  static Future<bool> hasActiveSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_activeTokenKey);
    return token != null && token.isNotEmpty;
  }
}
