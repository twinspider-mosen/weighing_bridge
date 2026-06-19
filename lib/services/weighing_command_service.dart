import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:spider_weighbridge/components/live_camera_player.dart';
import 'package:spider_weighbridge/model/command_model.dart';
import 'package:spider_weighbridge/services/camera_service.dart';
import 'package:spider_weighbridge/services/firebase_service.dart';
import 'package:spider_weighbridge/services/logger_service.dart';
import 'package:spider_weighbridge/services/settings_service.dart';
import 'package:spider_weighbridge/utils/helper_functions.dart';

class WeighingCommandService {
  final SettingsService _settingsService = SettingsService();
  StreamSubscription? _commandSubscription;

  Future<void> initCommandListener({
    required BuildContext Function() contextProvider,
    required bool Function() isMounted,
    required void Function(bool loading) onLoadingChanged,
    required GlobalKey<LiveCameraPlayerState> Function() frontKeyProvider,
    required GlobalKey<LiveCameraPlayerState> Function() backKeyProvider,
    required Future<bool> Function(CommandModel command) requestApproval,
    required String Function() currentWeightProvider,
    required String Function() unitProvider,
    required bool Function() uploadOnCaptureProvider,
    required bool Function() enableFrontProvider,
    required bool Function() enableBackProvider,
    required CameraConfig? Function() backCameraProvider,
  }) async {
    final details = await HelperFunctions.getSystemDetails();
    final scaleName = details['scale_name'] as String? ?? '';
    final subdomains = details['subdomains'] as List<String>? ?? [];

    if (scaleName.isEmpty || subdomains.isEmpty) {
      LoggerService().log("Firestore listener skipped: scaleID or subdomains is empty.");
      return;
    }

    _commandSubscription = FirebaseService.getCommandStream(
      scaleName: scaleName,
      subdomains: subdomains,
    ).listen(
      (snapshot) async {
        for (final change in snapshot.docChanges) {
          if (change.type == DocumentChangeType.added) {
            final command = CommandModel.fromMap(change.doc.data()!);
            LoggerService().log("NEW COMMAND RECEIVED: Request ID: ${command.requestID}");

            final approvalRequired = await _settingsService.getRequireApprovalForRecords();
            final context = contextProvider();

            if (approvalRequired) {
              final approved = await requestApproval(command);
              if (!isMounted()) return;

              if (approved) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: Colors.green.shade800,
                    content: const Text("Request approved. Capturing and sending data...", style: TextStyle(color: Colors.white)),
                  ),
                );
                await _executeCapture(
                  context: context,
                  command: command,
                  onLoadingChanged: onLoadingChanged,
                  frontKey: enableFrontProvider() ? frontKeyProvider() : null,
                  backKey: (enableBackProvider() && backCameraProvider() != null) ? backKeyProvider() : null,
                  uploadOnCapture: uploadOnCaptureProvider(),
                  currentWeight: currentWeightProvider(),
                  unit: unitProvider(),
                );
              } else {
                try {
                  await FirebaseFirestore.instance
                      .collection('ScaleRequests')
                      .doc(change.doc.id)
                      .update({'status': 'rejected'});
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: Colors.red.shade800,
                      content: const Text("Request rejected. Status updated to rejected.", style: TextStyle(color: Colors.white)),
                    ),
                  );
                } catch (e) {
                  LoggerService().log("Error updating status to rejected: $e");
                }
              }
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: Colors.teal.shade800,
                  content: const Text("Incoming request received. Capturing and sending data...", style: TextStyle(color: Colors.white)),
                ),
              );
              await _executeCapture(
                context: context,
                command: command,
                onLoadingChanged: onLoadingChanged,
                frontKey: enableFrontProvider() ? frontKeyProvider() : null,
                backKey: (enableBackProvider() && backCameraProvider() != null) ? backKeyProvider() : null,
                uploadOnCapture: uploadOnCaptureProvider(),
                currentWeight: currentWeightProvider(),
                unit: unitProvider(),
              );
            }
          }
        }
      },
      onError: (e) => LoggerService().log("Firestore listener stream error: $e"),
    );
  }

  Future<void> _executeCapture({
    required BuildContext context,
    required CommandModel command,
    required void Function(bool) onLoadingChanged,
    required GlobalKey<LiveCameraPlayerState>? frontKey,
    required GlobalKey<LiveCameraPlayerState>? backKey,
    required bool uploadOnCapture,
    required String currentWeight,
    required String unit,
  }) async {
    await CameraCaptureService.captureAndHandle(
      context: context,
      autoUpload: true,
      frontCameraKey: frontKey,
      backCameraKey: backKey,
      uploadOnCapture: uploadOnCapture,
      currentWeight: currentWeight,
      unit: unit,
      scaleName: command.scaleName,
      requestID: command.requestID,
      subdomain: command.subdomain,
      recordStage: command.recordStage,
      moduleType: command.moduleType,
      recordType: command.recordType,
      scaleStockId: command.scaleStockId,
      onLoadingChanged: onLoadingChanged,
    );
  }

  void dispose() {
    _commandSubscription?.cancel();
  }
}
