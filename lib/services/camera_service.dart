import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:weighing_bridge/components/live_camera_player.dart';
import 'package:weighing_bridge/components/upload_dialog.dart';
import 'package:weighing_bridge/services/logger_service.dart';
import 'package:weighing_bridge/services/ocr_service.dart';
import 'package:weighing_bridge/services/upload_service.dart';

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

class CameraCaptureService {
  static Future<void> captureAndHandle({
    required BuildContext context,
    required GlobalKey<LiveCameraPlayerState> cameraPlayerKey,
bool autoUpload= false,
    required bool uploadOnCapture,

    required String currentWeight,
    required String unit,
    
    required String scaleID,
    required String requestID,
    required String subdomain,

    required Function(bool loading) onLoadingChanged,
  }) async {
    String? path;

    try {
      path = await cameraPlayerKey.currentState?.captureSnapshot();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red.shade800,
            content: Row(
              children: [
                const Icon(Icons.error_outline),
                const SizedBox(width: 8),
                Expanded(
                  child: Text("Capture Error: $e"),
                ),
              ],
            ),
          ),
        );
      }
      return;
    }

    if (path == null || !context.mounted) return;

    onLoadingChanged(true);

    try {
      if (uploadOnCapture) {
        if(autoUpload){
await UploadService.uploadSnapshot(
   imagePath: path,
          currentWeight: "$currentWeight $unit",
          requestID: requestID,
          scaleID: scaleID,
          subdomain: subdomain,
          
);
        }else{

        await showUploadDialog(
          context: context,
          imagePath: path,
          currentWeight: "$currentWeight $unit",
          requestID: requestID,
          scaleID: scaleID,
          subdomain: subdomain,
        );
        }
      } else {
        await _handleDirectSave(
          context: context,
          path: path,
        );
      }
    } finally {
      onLoadingChanged(false);
    }
  }

  static Future<void> _handleDirectSave({
    required BuildContext context,
    required String path,
  }) async {
    OcrResult? res;
    String? err;

    if (OcrService().isConnected) {
      try {
        res = await OcrService().scanImage(path);

        await LoggerService().log(
          "Direct Capture OCR complete. Plate: ${res.labeledTexts["Car Number Plate"]}",
        );
      } catch (e) {
        err = e
            .toString()
            .replaceFirst("Exception: ", "")
            .replaceFirst("StateError: ", "");

        await LoggerService().log(
          "Direct Capture OCR failed",
          e,
        );
      }
    }

    if (!context.mounted) return;

    final isPlate =
        res?.labeledTexts.containsKey("Car Number Plate") ?? false;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.teal.shade800,
        content: Text(
          "Snapshot saved to disk:\n$path"
          "${res != null ? "\nAUTOMATIC OCR: ${isPlate ? "Recognized Plate: ${res.labeledTexts["Car Number Plate"]}" : "Scanned Text Detected"}" : ""}"
          "${err != null ? "\nOCR Scan Failed: $err" : ""}",
        ),
      ),
    );
  }
}