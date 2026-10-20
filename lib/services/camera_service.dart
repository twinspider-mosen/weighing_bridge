import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spider_weighbridge/components/live_camera_player.dart';
import 'package:spider_weighbridge/components/upload_dialog.dart';
import 'package:spider_weighbridge/services/anpr_service.dart';
import 'package:spider_weighbridge/services/logger_service.dart';
import 'package:spider_weighbridge/services/ocr_service.dart';
import 'package:spider_weighbridge/services/upload_service.dart';

class CameraConfig {
  final String id;
  final String name;
  final String ipAddress;
  final String rtspUrl;

  /// When true, ANPR capture is triggered for this camera on every request.
  final bool enableAnpr;

  CameraConfig({
    required this.id,
    required this.name,
    required this.ipAddress,
    required this.rtspUrl,
    this.enableAnpr = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'ipAddress': ipAddress,
    'rtspUrl': rtspUrl,
    'enableAnpr': enableAnpr,
  };

  factory CameraConfig.fromJson(Map<String, dynamic> json) => CameraConfig(
    id: json['id'] as String,
    name: json['name'] as String,
    ipAddress: json['ipAddress'] as String,
    rtspUrl: json['rtspUrl'] as String,
    enableAnpr: json['enableAnpr'] as bool? ?? false,
  );

  CameraConfig copyWith({
    String? id,
    String? name,
    String? ipAddress,
    String? rtspUrl,
    bool? enableAnpr,
  }) => CameraConfig(
    id: id ?? this.id,
    name: name ?? this.name,
    ipAddress: ipAddress ?? this.ipAddress,
    rtspUrl: rtspUrl ?? this.rtspUrl,
    enableAnpr: enableAnpr ?? this.enableAnpr,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CameraConfig &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class CameraStorageService {
  static const String _storageKey = 'saved_cameras';

  Future<List<CameraConfig>> getCameras() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStringList = prefs.getStringList(_storageKey) ?? [];

    return jsonStringList
        .map((str) {
          try {
            return CameraConfig.fromJson(
              jsonDecode(str) as Map<String, dynamic>,
            );
          } catch (e) {
            return null;
          }
        })
        .whereType<CameraConfig>()
        .toList();
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
    GlobalKey<LiveCameraPlayerState>? frontCameraKey,
    GlobalKey<LiveCameraPlayerState>? backCameraKey,

    /// Full CameraConfig for the front camera (used for ANPR if enableAnpr==true).
    CameraConfig? frontCameraConfig,

    /// Full CameraConfig for the back camera (used for ANPR if enableAnpr==true).
    CameraConfig? backCameraConfig,

    bool autoUpload = false,
    required bool uploadOnCapture,

    required String currentWeight,
    required String unit,

    required String scaleName,
    required String requestID,
    required String subdomain,

    required String recordType,
    String? scaleStockId,
    required String recordStage,
    required String moduleType,

    required Function(bool loading) onLoadingChanged,
  }) async {
    String? frontPath;
    String? backPath;

    if (frontCameraKey != null) {
      try {
        frontPath = await frontCameraKey.currentState?.captureSnapshot();
      } catch (e) {
        await LoggerService().log("Front camera capture failed (non-critical)", e);
      }
    }

    if (backCameraKey != null) {
      try {
        backPath = await backCameraKey.currentState?.captureSnapshot();
      } catch (e) {
        await LoggerService().log("Back camera capture failed (non-critical)", e);
      }
    }

    if (!context.mounted) return;
    onLoadingChanged(true);

    // ── Per-camera ANPR ────────────────────────────────────────────────────────
    // Run ANPR independently for front and back cameras when their flag is set.
    String? frontPlateImagePath;
    String? frontPlateText;
    String? backPlateImagePath;
    String? backPlateText;

    if (frontCameraConfig?.enableAnpr == true) {
      try {
        await LoggerService().log("Front ANPR: starting capture from ${frontCameraConfig!.ipAddress}");
        final result = await AnprService().captureAnpr(cameraConfig: frontCameraConfig);
        await LoggerService().log("Front ANPR: success=${result.success}, plate=${result.plateNumber}");
        if (result.success) {
          frontPlateImagePath = result.plateImagePath;
          frontPlateText = result.plateNumber;
        }
      } catch (e, stack) {
        await LoggerService().log("Front ANPR exception (non-critical)", e, stack);
      }
    }

    if (backCameraConfig?.enableAnpr == true) {
      try {
        await LoggerService().log("Back ANPR: starting capture from ${backCameraConfig!.ipAddress}");
        final result = await AnprService().captureAnpr(cameraConfig: backCameraConfig);
        await LoggerService().log("Back ANPR: success=${result.success}, plate=${result.plateNumber}");
        if (result.success) {
          backPlateImagePath = result.plateImagePath;
          backPlateText = result.plateNumber;
        }
      } catch (e, stack) {
        await LoggerService().log("Back ANPR exception (non-critical)", e, stack);
      }
    }
    // ──────────────────────────────────────────────────────────────────────────

    try {
      if (uploadOnCapture) {
        if (autoUpload) {
          await UploadService.uploadSnapshot(
            frontImagePath: frontPath,
            backImagePath: backPath,
            currentWeight: "$currentWeight",
            requestID: requestID,
            scaleName: scaleName,
            subdomain: subdomain,
            recordType: recordType,
            scaleStockId: scaleStockId,
            recordStage: recordStage,
            moduleType: moduleType,
            frontPlateImagePath: frontPlateImagePath,
            frontPlateText: frontPlateText,
            backPlateImagePath: backPlateImagePath,
            backPlateText: backPlateText,
          );
        } else {
          await showUploadDialog(
            context: context,
            frontImagePath: frontPath,
            backImagePath: backPath,
            currentWeight: currentWeight,
            requestID: requestID,
            scaleName: scaleName,
            subdomain: subdomain,
            recordType: recordType,
            scaleStockId: scaleStockId,
            recordStage: recordStage,
            moduleType: moduleType,
            frontPlateImagePath: frontPlateImagePath,
            frontPlateText: frontPlateText,
            backPlateImagePath: backPlateImagePath,
            backPlateText: backPlateText,
          );
        }
      } else {
        if (frontPath != null) {
          await _handleDirectSave(context: context, path: frontPath, label: "Front snapshot");
        }
        if (backPath != null && context.mounted) {
          await _handleDirectSave(context: context, path: backPath, label: "Back snapshot");
        }
      }
    } finally {
      onLoadingChanged(false);
    }
  }

  static Future<void> _handleDirectSave({
    required BuildContext context,
    required String path,
    String label = 'Snapshot',
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

        await LoggerService().log("Direct Capture OCR failed", e);
      }
    }

    if (!context.mounted) return;

    final isPlate = res?.labeledTexts.containsKey("Car Number Plate") ?? false;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.green.shade800,
        content: Text(
          "$label saved to disk:\n$path"
          "${res != null ? "\nAUTOMATIC OCR: ${isPlate ? "Recognized Plate: ${res.labeledTexts["Car Number Plate"]}" : "Scanned Text Detected"}" : ""}"
          "${err != null ? "\nOCR Scan Failed: $err" : ""}",
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
  }
}
