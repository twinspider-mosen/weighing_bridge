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

  /// Tracks request IDs already handled in this session to prevent duplicate
  /// processing when the Firestore stream replays existing 'pending' docs on
  /// startup or on reconnect.
  final Set<String> _handledRequestIds = {};

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

    // ── Snapshot the current pending request IDs at startup so we do NOT
    // process stale requests that were already sitting in Firestore before
    // the app launched. Only NEW additions after this point are processed.
    try {
      final existingSnapshot = await FirebaseFirestore.instance
          .collection('ScaleRequests')
          .where('scale_name', isEqualTo: scaleName)
          .where('subdomain', whereIn: subdomains)
          .where('status', isEqualTo: 'pending')
          .get();
      for (final doc in existingSnapshot.docs) {
        _handledRequestIds.add(doc.id);
      }
      LoggerService().log(
        "Firestore listener ready. Pre-seeded ${_handledRequestIds.length} existing pending doc(s) to skip.",
      );
    } catch (e) {
      LoggerService().log("Could not pre-seed existing pending requests (non-critical): $e");
    }

    _commandSubscription = FirebaseService.getCommandStream(
      scaleName: scaleName,
      subdomains: subdomains,
    ).listen(
      (snapshot) async {
        for (final change in snapshot.docChanges) {
          if (change.type != DocumentChangeType.added) continue;

          final docId = change.doc.id;

          // Skip docs that existed before the listener started.
          if (_handledRequestIds.contains(docId)) {
            LoggerService().log("Skipping pre-existing doc: $docId");
            continue;
          }
          _handledRequestIds.add(docId);

          CommandModel command;
          try {
            command = CommandModel.fromMap(change.doc.data()!);
          } catch (e) {
            LoggerService().log("Failed to parse command document $docId: $e");
            continue;
          }

          LoggerService().log(
            "NEW COMMAND RECEIVED: Request ID: ${command.requestID} (doc: $docId)",
          );

          // Mark as 'processing' immediately so the server/other clients
          // know we accepted it and no duplicate dispatch happens.
          try {
            await FirebaseFirestore.instance
                .collection('ScaleRequests')
                .doc(docId)
                .update({'status': 'processing'});
          } catch (e) {
            LoggerService().log("Could not mark request as processing: $e — aborting to avoid duplicate.");
            continue;
          }

          final context = contextProvider();
          if (!isMounted()) {
            LoggerService().log("Widget unmounted before processing request ${command.requestID}. Skipping.");
            continue;
          }

          try {
            final approvalRequired = await _settingsService.getRequireApprovalForRecords();

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
                  LoggerService().log("Error updating status to rejected: $e");
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
                frontKey: enableFrontProvider() ? frontKeyProvider() : null,
                backKey: (enableBackProvider() && backCameraProvider() != null) ? backKeyProvider() : null,
                uploadOnCapture: uploadOnCaptureProvider(),
                currentWeight: currentWeightProvider(),
                unit: unitProvider(),
              );
            }
          } catch (e, stack) {
            LoggerService().log("Unhandled error while processing command ${command.requestID}", e, stack);
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
      onError: (e, stack) => LoggerService().log("Firestore listener stream error", e, stack),
    );
  }

  Future<void> _executeCapture({
    required BuildContext context,
    required String docId,
    required CommandModel command,
    required void Function(bool) onLoadingChanged,
    required GlobalKey<LiveCameraPlayerState>? frontKey,
    required GlobalKey<LiveCameraPlayerState>? backKey,
    required bool uploadOnCapture,
    required String currentWeight,
    required String unit,
  }) async {
    // Guard: if no cameras are available, mark failed immediately instead of
    // silently doing nothing and leaving the request stuck at 'processing'.
    if (frontKey == null && backKey == null) {
      LoggerService().log("No cameras available for request ${command.requestID}. Marking as failed.");
      try {
        await FirebaseFirestore.instance
            .collection('ScaleRequests')
            .doc(docId)
            .update({'status': 'failed', 'error': 'No cameras configured or enabled'});
      } catch (_) {}
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red.shade800,
            content: const Text(
              "Request failed: No cameras are enabled or configured.",
              style: TextStyle(color: Colors.white),
            ),
          ),
        );
      }
      return;
    }

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

    // After a successful capture + upload cycle, mark as completed.
    try {
      await FirebaseFirestore.instance
          .collection('ScaleRequests')
          .doc(docId)
          .update({'status': 'completed'});
      LoggerService().log("Request ${command.requestID} marked as completed.");
    } catch (e) {
      LoggerService().log("Could not mark request ${command.requestID} as completed: $e");
    }
  }

  void dispose() {
    _commandSubscription?.cancel();
  }
}
