class CameraConstants {
  static final CameraConstants _instance = CameraConstants._internal();
  factory CameraConstants() => _instance;
  CameraConstants._internal();
  static const String defaultUsername = "admin";
  static const String defaultPassword = "admin@12345";

  /// URL-encoded password for RTSP URLs (e.g. admin%4012345)
  static String get encodedPassword => Uri.encodeComponent(defaultPassword);

  /// Standard Dahua/Hikvision RTSP stream URL
  static String buildRtspUrl(String ip) {
    return "rtsp://$defaultUsername:$encodedPassword@$ip:554/cam/realmonitor?channel=1&subtype=1";
  }
}
