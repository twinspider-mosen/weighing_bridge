import 'dart:async';
import 'package:flutter/material.dart';
import 'package:spider_weighbridge/model/user_model.dart';
import 'package:spider_weighbridge/services/camera_service.dart';
import 'package:spider_weighbridge/services/scale_service.dart';
import 'package:spider_weighbridge/services/session_service.dart';
import 'package:spider_weighbridge/services/settings_service.dart';

class WeighingScreenController {
  final ScaleService scaleService = ScaleService();
  final CameraStorageService cameraStorage = CameraStorageService();
  final SettingsService settingsService = SettingsService();

  String currentWeight = '0.00';
  String unit = 'kg';
  String? selectedPort;
  bool isScanning = false;
  bool isListening = false;
  String status = 'Disconnected';
  ScaleConfig? activeConfig;
  ScaleProtocol scaleProtocol = ScaleProtocol.binaryAutoDetect;

  List<CameraConfig> savedCameras = [];
  CameraConfig? frontCamera;
  CameraConfig? backCamera;
  
  bool isCapturingSnap = false;
  double frontCameraZoom = 1.0;
  double backCameraZoom = 1.0;

  bool uploadOnCapture = true;
  bool requireApprovalForRecords = false;
  bool enableFrontCamera = true;
  bool enableBackCamera = true;
  
  List<UserModel> availableUsers = [];
  UserModel? activeUser;

  Future<void> loadUser(VoidCallback onUpdate) async {
    activeUser = await SessionService.getActiveUser();
    availableUsers = await SessionService.getAvailableUsers();
    onUpdate();
  }

  Future<void> loadSettings(VoidCallback onUpdate) async {
    uploadOnCapture = await settingsService.getUploadOnCapture();
    requireApprovalForRecords = await settingsService.getRequireApprovalForRecords();
    enableFrontCamera = await settingsService.getEnableFrontCamera();
    enableBackCamera = await settingsService.getEnableBackCamera();
    scaleProtocol = await settingsService.getScaleProtocol();
    onUpdate();
  }

  Future<void> loadSavedCameras(VoidCallback onUpdate) async {
    final cameras = await cameraStorage.getCameras();
    savedCameras = cameras;
    if (frontCamera != null && !cameras.any((c) => c.id == frontCamera!.id)) {
      frontCamera = null;
    }
    if (frontCamera == null && cameras.isNotEmpty) {
      frontCamera = cameras.first;
    }
    if (backCamera != null && !cameras.any((c) => c.id == backCamera!.id)) {
      backCamera = null;
    }
    if (backCamera == null && cameras.length > 1) {
      backCamera = cameras[1];
    }
    onUpdate();
  }

  void refreshPorts(VoidCallback onUpdate) {
    try {
      final ports = scaleService.getAvailablePorts();
      if (ports.isNotEmpty) {
        if (selectedPort == null || !ports.contains(selectedPort)) {
          selectedPort = ports.first;
        }
      } else {
        selectedPort = null;
        status = 'No ports found';
      }
    } catch (e) {
      status = 'Error loading ports: $e';
    }
    onUpdate();
  }

  void handleNewData(String data, VoidCallback onUpdate) {
    final trimmed = data.trim();
    if (trimmed.isEmpty) return;
    final match = RegExp(r'([0-9]+\.[0-9]+|[0-9]+)').firstMatch(trimmed);
    // Order matters: 'kg' must come before 'g', and 'g' is anchored with \b
    // so it won't match the 'g' tail inside 'kg'.
    final unitMatch = RegExp(r'\b(kg|lb|g)\b', caseSensitive: false).firstMatch(trimmed);
    if (match != null) {
      final raw = match.group(0)!;
      try {
        currentWeight = raw.contains('.')
            ? double.parse(raw).toStringAsFixed(2)
            : int.parse(raw).toString();
      } catch (_) {
        currentWeight = raw;
      }
    }
    if (unitMatch != null) {
      unit = unitMatch.group(0)!.toLowerCase();
    }
    onUpdate();
  }

  Future<void> startScan(BuildContext context, VoidCallback onUpdate) async {
    if (selectedPort == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a COM port first')),
      );
      return;
    }
    isScanning = true;
    status = 'Scanning...';
    onUpdate();
    try {
      final scanned = await scaleService.scanPort(selectedPort!).timeout(const Duration(seconds: 45));
      if (scanned != null) {
        // Stamp the user-selected protocol onto the scanned baud/parity config.
        // This leaves all existing binary systems unaffected (default = binaryAutoDetect).
        final config = ScaleConfig(
          baudRate: scanned.baudRate,
          parity: scanned.parity,
          dataBits: scanned.dataBits,
          stopBits: scanned.stopBits,
          protocol: scaleProtocol,
        );
        activeConfig = config;
        isListening = await scaleService.startListening(selectedPort!, config);
        status = isListening ? 'Connected' : 'Connection Failed';
      } else {
        status = 'Scan Failed (No Signal)';
      }
    } catch (e) {
      status = 'Scan Error: $e';
    } finally {
      isScanning = false;
      onUpdate();
    }
  }

  Future<void> toggleListener(BuildContext context, VoidCallback onUpdate) async {
    if (isListening) {
      await scaleService.stopListening();
      isListening = false;
      status = 'Disconnected';
      onUpdate();
    } else {
      if (activeConfig != null && selectedPort != null) {
        // Re-apply the current protocol in case it was changed in Settings
        // since the last scan without requiring a new full scan.
        final config = ScaleConfig(
          baudRate: activeConfig!.baudRate,
          parity: activeConfig!.parity,
          dataBits: activeConfig!.dataBits,
          stopBits: activeConfig!.stopBits,
          protocol: scaleProtocol,
        );
        activeConfig = config;
        isListening = await scaleService.startListening(selectedPort!, config);
        status = isListening ? 'Connected' : 'Connection Failed';
        onUpdate();
      } else {
        startScan(context, onUpdate);
      }
    }
  }

  void dispose() {
    scaleService.dispose();
  }
}
