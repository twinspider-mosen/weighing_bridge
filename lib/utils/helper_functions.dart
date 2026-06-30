import 'package:shared_preferences/shared_preferences.dart';

class HelperFunctions {
  static Future<Map<String, dynamic>> getSystemDetails() async {
    final prefs = await SharedPreferences.getInstance();

    final String name = prefs.getString('scale_name') ?? '';
    final String domain = prefs.getString('subdomain') ?? '';
    final List<String> subdomains = prefs.getStringList('subdomains') ?? [];

    return {'scale_name': name, 'subdomain': domain, 'subdomains': subdomains};
  }
}
