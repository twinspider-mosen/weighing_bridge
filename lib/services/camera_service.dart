import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spider_weighbridge/components/live_camera_player.dart';
import 'package:spider_weighbridge/components/upload_dialog.dart';
import 'package:spider_weighbridge/services/anpr_service.dart';
import 'package:spider_weighbridge/services/logger_service.dart';
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

    bool enableFrontCamera = true,
    bool enableBackCamera = true,
    bool? cameraEnabled,

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
    if (!context.mounted) return;
    onLoadingChanged(true);

    final bool isCameraAllowed = cameraEnabled ?? true;
    final bool effectiveFront = isCameraAllowed && enableFrontCamera;
    final bool effectiveBack = isCameraAllowed && enableBackCamera;

    if (!isCameraAllowed) {
      await LoggerService().log(
        "Camera capture is DISABLED by incoming request ('camera_enabled: false'). Bypassing all cameras.",
      );
    }

    String? frontPath;
    String? backPath;
    String? frontPlateImagePath;
    String? frontPlateText;
    String? backPlateImagePath;
    String? backPlateText;

    // ── Parallel Front & Back Camera Capture ──────────────────────────────────
    Future<void> captureFront() async {
      if (!effectiveFront || frontCameraConfig == null) {
        await LoggerService().log(
          "Front camera skipped (requestAllowed=$isCameraAllowed, settingEnabled=$enableFrontCamera, config=${frontCameraConfig?.name ?? 'null'}).",
        );
        return;
      }

      if (frontCameraConfig.enableAnpr == true) {
        try {
          await LoggerService().log(
            "Front ANPR: starting capture from ${frontCameraConfig.ipAddress} (Camera='${frontCameraConfig.name}')",
          );
          final result = await AnprService().captureAnpr(
            cameraConfig: frontCameraConfig,
          );
          await LoggerService().log(
            "Front ANPR result: success=${result.success}, plate=${result.plateNumber ?? 'none'}${result.error != null ? ', details=${result.error}' : ''}",
          );
          if (result.success) {
            frontPath = result.vehicleImagePath;
            frontPlateImagePath = result.plateImagePath;
            frontPlateText = result.plateNumber;
          }
        } catch (e, stack) {
          await LoggerService().log(
            "Front ANPR exception (non-critical)",
            e,
            stack,
          );
        }

        // If ANPR didn't capture full vehicle image, capture directly via camera HTTP snapshot API
        if (frontPath == null) {
          try {
            await LoggerService().log(
              "Front ANPR did not yield full vehicle image; attempting native HTTP snapshot fallback...",
            );
            frontPath = await AnprService().captureNativeSnapshot(
              cameraConfig: frontCameraConfig,
            );
            await LoggerService().log(
              "Front native snapshot fallback result: path=$frontPath",
            );
          } catch (e) {
            await LoggerService().log(
              "Front native snapshot fallback error: $e",
            );
          }
        }
        // Fallback to video player snapshot if HTTP snapshot was unavailable
        if (frontPath == null && frontCameraKey != null) {
          try {
            await LoggerService().log(
              "Front HTTP snapshot unavailable; attempting video player frame snapshot fallback...",
            );
            frontPath = await frontCameraKey.currentState?.captureSnapshot();
            await LoggerService().log(
              "Front video player snapshot result: path=$frontPath",
            );
          } catch (e) {
            await LoggerService().log("Front video player snapshot error: $e");
          }
        }
      } else {
        try {
          await LoggerService().log(
            "Front camera (${frontCameraConfig.name}): ANPR is OFF, capturing native snapshot from ${frontCameraConfig.ipAddress}",
          );
          frontPath = await AnprService().captureNativeSnapshot(
            cameraConfig: frontCameraConfig,
          );
        } catch (e) {
          await LoggerService().log("Front native snapshot error: $e");
        }
        if (frontPath == null && frontCameraKey != null) {
          try {
            frontPath = await frontCameraKey.currentState?.captureSnapshot();
          } catch (e) {
            await LoggerService().log(
              "Front camera capture failed (non-critical)",
              e,
            );
          }
        }
      }
    }

    Future<void> captureBack() async {
      if (!effectiveBack || backCameraConfig == null) {
        await LoggerService().log(
          "Back camera skipped (requestAllowed=$isCameraAllowed, settingEnabled=$enableBackCamera, config=${backCameraConfig?.name ?? 'null'}).",
        );
        return;
      }

      if (backCameraConfig.enableAnpr == true) {
        try {
          await LoggerService().log(
            "Back ANPR: starting capture from ${backCameraConfig.ipAddress} (Camera='${backCameraConfig.name}')",
          );
          final result = await AnprService().captureAnpr(
            cameraConfig: backCameraConfig,
          );
          await LoggerService().log(
            "Back ANPR result: success=${result.success}, plate=${result.plateNumber ?? 'none'}${result.error != null ? ', details=${result.error}' : ''}",
          );
          if (result.success) {
            backPath = result.vehicleImagePath;
            backPlateImagePath = result.plateImagePath;
            backPlateText = result.plateNumber;
          }
        } catch (e, stack) {
          await LoggerService().log(
            "Back ANPR exception (non-critical)",
            e,
            stack,
          );
        }

        // If ANPR didn't capture full vehicle image, capture directly via camera HTTP snapshot API
        if (backPath == null) {
          try {
            await LoggerService().log(
              "Back ANPR did not yield full vehicle image; attempting native HTTP snapshot fallback...",
            );
            backPath = await AnprService().captureNativeSnapshot(
              cameraConfig: backCameraConfig,
            );
            await LoggerService().log(
              "Back native snapshot fallback result: path=$backPath",
            );
          } catch (e) {
            await LoggerService().log(
              "Back native snapshot fallback error: $e",
            );
          }
        }
        // Fallback to video player snapshot if HTTP snapshot was unavailable
        if (backPath == null && backCameraKey != null) {
          try {
            await LoggerService().log(
              "Back HTTP snapshot unavailable; attempting video player frame snapshot fallback...",
            );
            backPath = await backCameraKey.currentState?.captureSnapshot();
            await LoggerService().log(
              "Back video player snapshot result: path=$backPath",
            );
          } catch (e) {
            await LoggerService().log("Back video player snapshot error: $e");
          }
        }
      } else {
        try {
          await LoggerService().log(
            "Back camera (${backCameraConfig.name}): ANPR is OFF, capturing native snapshot from ${backCameraConfig.ipAddress}",
          );
          backPath = await AnprService().captureNativeSnapshot(
            cameraConfig: backCameraConfig,
          );
        } catch (e) {
          await LoggerService().log("Back native snapshot error: $e");
        }
        if (backPath == null && backCameraKey != null) {
          try {
            backPath = await backCameraKey.currentState?.captureSnapshot();
          } catch (e) {
            await LoggerService().log(
              "Back camera capture failed (non-critical)",
              e,
            );
          }
        }
      }
    }

    await Future.wait([captureFront(), captureBack()]);

    await LoggerService().log(
      "Weighbridge capture summary: Front=[image: $frontPath, plate: $frontPlateText, crop: $frontPlateImagePath] | Back=[image: $backPath, plate: $backPlateText, crop: $backPlateImagePath]",
    );

    try {
      if (uploadOnCapture) {
        if (autoUpload) {
          await UploadService.uploadSnapshot(
            frontImagePath: frontPath,
            backImagePath: backPath,
            currentWeight: currentWeight.toString(),
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
        if (!context.mounted) return;
        if (frontPath != null) {
          await _handleDirectSave(
            context: context,
            path: frontPath!,
            plateImagePath: frontPlateImagePath,
            plateText: frontPlateText,
            label: "Front snapshot",
          );
        }
        if (backPath != null && context.mounted) {
          await _handleDirectSave(
            context: context,
            path: backPath!,
            plateImagePath: backPlateImagePath,
            plateText: backPlateText,
            label: "Back snapshot",
          );
        }
      }
    } finally {
      onLoadingChanged(false);
    }
  }

  static Future<void> _handleDirectSave({
    required BuildContext context,
    required String path,
    String? plateImagePath,
    String? plateText,
    String label = 'Snapshot',
  }) async {
    await LoggerService().log(
      "$label direct save: image=$path, plateCrop=$plateImagePath, plateText=$plateText",
    );

    if (!context.mounted) return;

    final String plateInfo = (plateText != null && plateText.isNotEmpty)
        ? "\nCamera ANPR Plate: $plateText"
        : "";
    final String plateCropInfo =
        (plateImagePath != null && plateImagePath.isNotEmpty)
        ? "\nPlate Crop: $plateImagePath"
        : "";

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.green.shade800,
        content: Text(
          "$label saved to disk:\n$path$plateInfo$plateCropInfo",
          style: const TextStyle(color: Colors.white),
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }
}
