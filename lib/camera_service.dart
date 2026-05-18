import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class CameraConfig {
  final String id;
  final String name;
  final String ipAddress;
  final String rtspUrl;

  CameraConfig({
    required this.id,
    required this.name,
    required this.ipAddress,
    required this.rtspUrl,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'ipAddress': ipAddress,
    'rtspUrl': rtspUrl,
  };

  factory CameraConfig.fromJson(Map<String, dynamic> json) => CameraConfig(
    id: json['id'] as String,
    name: json['name'] as String,
    ipAddress: json['ipAddress'] as String,
    rtspUrl: json['rtspUrl'] as String,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CameraConfig && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class CameraStorageService {
  static const String _storageKey = 'saved_cameras';

  Future<List<CameraConfig>> getCameras() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStringList = prefs.getStringList(_storageKey) ?? [];
    
    return jsonStringList.map((str) {
      try {
        return CameraConfig.fromJson(jsonDecode(str) as Map<String, dynamic>);
      } catch (e) {
        return null;
      }
    }).whereType<CameraConfig>().toList();
  }

  Future<void> saveCamera(CameraConfig camera) async {
    final cameras = await getCameras();
    final index = cameras.indexWhere((c) => c.id == camera.id);
    if (index >= 0) {
      cameras[index] = camera;
    } else {
      cameras.add(camera);
    }
    
    final prefs = await SharedPreferences.getInstance();
    final jsonStringList = cameras.map((c) => jsonEncode(c.toJson())).toList();
    await prefs.setStringList(_storageKey, jsonStringList);
  }

  Future<void> deleteCamera(String id) async {
    final cameras = await getCameras();
    cameras.removeWhere((c) => c.id == id);
    
    final prefs = await SharedPreferences.getInstance();
    final jsonStringList = cameras.map((c) => jsonEncode(c.toJson())).toList();
    await prefs.setStringList(_storageKey, jsonStringList);
  }
}
