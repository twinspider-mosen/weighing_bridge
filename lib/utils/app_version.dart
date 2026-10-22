/// Application version configuration.
/// Auto-updated during build execution.
class AppVersion {
  static const String version = '26.10.22.1';
  static const int buildNumber = 1;

  static String get fullVersion => 'v$version';
  static String get displayVersion => 'v$version';
}
