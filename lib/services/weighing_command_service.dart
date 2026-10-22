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
    required CameraConfig? Function() frontCameraProvider,
    required CameraConfig? Function() backCameraProvider,
  }) async {
    final details = await HelperFunctions.getSystemDetails();
    final scaleName = details['scale_name'] as String? ?? '';
    final subdomains = details['subdomains'] as List<String>? ?? [];

    if (scaleName.isEmpty || subdomains.isEmpty) {
      LoggerService().log(
        "Firestore listener skipped: scaleID or subdomains is empty.",
      );
      return;
    }

    LoggerService().log("Firestore listener starting for scale: $scaleName");

    _commandSubscription =
        FirebaseService.getCommandStream(
          scaleName: scaleName,
          subdomains: subdomains,
        ).listen(
          (snapshot) async {
            for (final change in snapshot.docChanges) {
              if (change.type != DocumentChangeType.added) continue;

              final docId = change.doc.id;

              CommandModel command;
              try {
                command = CommandModel.fromMap(change.doc.data()!);
              } catch (e) {
                LoggerService().log(
                  "Failed to parse command document $docId: $e",
                );
                continue;
              }

              LoggerService().log(
                "NEW COMMAND RECEIVED: Request ID: ${command.requestID} (doc: $docId)",
              );

              // Atomically claim the request: only update to 'processing' if
              // the document is still 'pending'. This prevents two clients or
              // two listener reconnects from both processing the same request.
              bool claimed = false;
              try {
                final docRef = FirebaseFirestore.instance
                    .collection('ScaleRequests')
                    .doc(docId);

                await FirebaseFirestore.instance.runTransaction((txn) async {
                  final snapshot = await txn.get(docRef);
                  if (!snapshot.exists) return; // doc was deleted, skip
                  final currentStatus = snapshot.data()?['status'] as String?;
                  if (currentStatus != 'pending') return; // already claimed
                  txn.update(docRef, {'status': 'processing'});
                  claimed = true;
                });
              } catch (e) {
                LoggerService().log(
                  "Transaction error while claiming request $docId: $e",
                );
                continue;
              }

              if (!claimed) {
                LoggerService().log(
                  "Request $docId already claimed by another client — skipping.",
                );
                continue;
              }

              final context = contextProvider();
              if (!isMounted()) {
                LoggerService().log(
                  "Widget unmounted before processing request ${command.requestID}. Skipping.",
                );
                continue;
              }

              try {
                final approvalRequired = await _settingsService
                    .getRequireApprovalForRecords();

                if (approvalRequired) {
                  final approved = await requestApproval(command);
                  if (!isMounted()) return;

                  if (approved) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: Colors.green.shade800,
                          content: const Text(
                            "Request approved. Capturing and sending data...",
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      );
                    }
                    await _executeCapture(
                      context: context,
                      docId: docId,
                      command: command,
                      onLoadingChanged: onLoadingChanged,
                      enableFrontCamera: enableFrontProvider(),
                      enableBackCamera: enableBackProvider(),
                      frontKey: enableFrontProvider() ? frontKeyProvider() : null,
                      backKey: (enableBackProvider() && backCameraProvider() != null)
                          ? backKeyProvider()
                          : null,
                      frontCameraConfig: enableFrontProvider() ? frontCameraProvider() : null,
                      backCameraConfig: enableBackProvider() ? backCameraProvider() : null,
                      uploadOnCapture: uploadOnCaptureProvider(),
                      currentWeight: currentWeightProvider(),
                      unit: unitProvider(),
                    );
                  } else {
                    try {
                      await FirebaseFirestore.instance
                          .collection('ScaleRequests')
                          .doc(docId)
                          .update({'status': 'rejected'});
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: Colors.red.shade800,
                            content: const Text(
                              "Request rejected. Status updated to rejected.",
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        );
                      }
                    } catch (e) {
                      LoggerService().log(
                        "Error updating status to rejected: $e",
                      );
                    }
                  }
                } else {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: Colors.teal.shade800,
                        content: const Text(
                          "Incoming request received. Capturing and sending data...",
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    );
                  }
                  await _executeCapture(
                    context: context,
                    docId: docId,
                    command: command,
                    onLoadingChanged: onLoadingChanged,
                    enableFrontCamera: enableFrontProvider(),
                    enableBackCamera: enableBackProvider(),
                    frontKey: enableFrontProvider() ? frontKeyProvider() : null,
                    backKey: (enableBackProvider() && backCameraProvider() != null)
                        ? backKeyProvider()
                        : null,
                    frontCameraConfig: enableFrontProvider() ? frontCameraProvider() : null,
                    backCameraConfig: enableBackProvider() ? backCameraProvider() : null,
                    uploadOnCapture: uploadOnCaptureProvider(),
                    currentWeight: currentWeightProvider(),
                    unit: unitProvider(),
                  );
                }
              } catch (e, stack) {
                LoggerService().log(
                  "Unhandled error while processing command ${command.requestID}",
                  e,
                  stack,
                );
                // Mark request as failed so the server knows something went wrong
                try {
                  await FirebaseFirestore.instance
                      .collection('ScaleRequests')
                      .doc(docId)
                      .update({'status': 'failed', 'error': e.toString()});
                } catch (_) {}
              }
            }
          },
          onError: (e, stack) =>
              LoggerService().log("Firestore listener stream error", e, stack),
        );
  }

  Future<void> _executeCapture({
    required BuildContext context,
    required String docId,
    required CommandModel command,
    required void Function(bool) onLoadingChanged,
    required bool enableFrontCamera,
    required bool enableBackCamera,
    required GlobalKey<LiveCameraPlayerState>? frontKey,
    required GlobalKey<LiveCameraPlayerState>? backKey,
    CameraConfig? frontCameraConfig,
    CameraConfig? backCameraConfig,
    required bool uploadOnCapture,
    required String currentWeight,
    required String unit,
  }) async {
    await CameraCaptureService.captureAndHandle(
      context: context,
      autoUpload: true,
      enableFrontCamera: enableFrontCamera,
      enableBackCamera: enableBackCamera,
      frontCameraKey: frontKey,
      backCameraKey: backKey,
      frontCameraConfig: frontCameraConfig,
      backCameraConfig: backCameraConfig,
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

    // After a successful capture + upload cycle, mark as completed.
    try {
      LoggerService().log("Request ${command.requestID} marked as completed.");
    } catch (e) {
      LoggerService().log(
        "Could not mark request ${command.requestID} as completed: $e",
      );
    }
  }

  void dispose() {
    _commandSubscription?.cancel();
  }
}
