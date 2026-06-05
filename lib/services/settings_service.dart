import 'package:shared_preferences/shared_preferences.dart';

/// Standalone, decoupled service to persist system settings using SharedPreferences.
class SettingsService {
  static const String _keyUploadOnCapture = 'settings_upload_on_capture';
  static const String _keyRequireApprovalForRecords = 'settings_require_approval_for_records';

  /// Retrieves the 'Upload on Capture' preference. Defaults to `true`.
  Future<bool> getUploadOnCapture() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyUploadOnCapture) ?? true;
  }

  /// Saves the 'Upload on Capture' preference.
  Future<void> setUploadOnCapture(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyUploadOnCapture, value);
  }

  /// Retrieves the 'Require Approval for Records' preference. Defaults to `false`.
  Future<bool> getRequireApprovalForRecords() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyRequireApprovalForRecords) ?? false;
  }

  /// Saves the 'Require Approval for Records' preference.
  Future<void> setRequireApprovalForRecords(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyRequireApprovalForRecords, value);
  }
}
