import 'dart:async';
import 'package:flutter/material.dart';
import 'package:spider_weighbridge/components/live_camera_player.dart';
import 'package:spider_weighbridge/model/command_model.dart';
import 'package:spider_weighbridge/services/anpr_service.dart';
import 'package:spider_weighbridge/services/camera_service.dart';
import 'package:spider_weighbridge/services/ocr_service.dart';
import 'package:spider_weighbridge/services/session_service.dart';
import 'package:spider_weighbridge/services/weighing_command_service.dart';
import 'package:spider_weighbridge/views/camera_management_screen.dart';
import 'weighing/weighing_drawer.dart';
import 'weighing/weighing_status_header.dart';
import 'weighing/weighing_screen_controller.dart';
import 'weighing/weighing_desktop_view.dart';
import 'weighing/weighing_dialogs.dart';
import 'weighing/weighing_layout_helper.dart';
import 'weighing/weighing_app_bar.dart';

class WeighingScreen extends StatefulWidget {
  const WeighingScreen({super.key});

  @override
  State<WeighingScreen> createState() => _WeighingScreenState();
}

class _WeighingScreenState extends State<WeighingScreen> {
  final WeighingScreenController _controller = WeighingScreenController();
  final WeighingCommandService _commandService = WeighingCommandService();

  final GlobalKey<LiveCameraPlayerState> _frontCameraKey =
      GlobalKey<LiveCameraPlayerState>();
  final GlobalKey<LiveCameraPlayerState> _backCameraKey =
      GlobalKey<LiveCameraPlayerState>();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  StreamSubscription<String>? _weightSubscription;

  @override
  void initState() {
    super.initState();
    _controller.refreshPorts(() {});
    _controller.loadSavedCameras(() {});
    _controller.loadSettings(() {});
    _controller.loadUser(() {});
    _weightSubscription = _controller.scaleService.weightStream.listen((data) {
      _controller.handleNewData(data, () {
        if (mounted) setState(() {});
      });
    });

    _commandService.initCommandListener(
      contextProvider: () => context,
      isMounted: () => mounted,
      onLoadingChanged: (l) => setState(() => _controller.isCapturingSnap = l),
      frontKeyProvider: () => _frontCameraKey,
      backKeyProvider: () => _backCameraKey,
      requestApproval: (cmd) =>
          WeighingDialogs.showApprovalDialog(context, cmd),
      currentWeightProvider: () => _controller.currentWeight,
      unitProvider: () => _controller.unit,
      uploadOnCaptureProvider: () => _controller.uploadOnCapture,
      enableFrontProvider: () => _controller.enableFrontCamera,
      enableBackProvider: () => _controller.enableBackCamera,
      frontCameraProvider: () => _controller.frontCamera,
      backCameraProvider: () => _controller.backCamera,
    );
  }

  @override
  void dispose() {
    _weightSubscription?.cancel();
    _commandService.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final layout = WeighingLayoutHelper(context);
    return AnimatedBuilder(
      animation: OcrService(),
      builder: (context, _) => Scaffold(
        key: _scaffoldKey,
        resizeToAvoidBottomInset: false,
        appBar: WeighingAppBar(
          activeUser: _controller.activeUser,
          availableUsers: _controller.availableUsers,
          onTitleLongPress: () => _scaffoldKey.currentState?.openDrawer(),
          onUserChanged: (newUserId) async {
            if (newUserId != null && newUserId != _controller.activeUser!.id) {
              await SessionService.switchActiveUser(newUserId);
              if (!context.mounted) return;
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const WeighingScreen()),
              );
            }
          },
        ),
        drawer: WeighingDrawer(
          onCamerasUpdated: () =>
              _controller.loadSavedCameras(() => setState(() {})),
          onSettingsUpdated: () =>
              _controller.loadSettings(() => setState(() {})),
        ),
        body: Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 1.5,
              colors: [Color(0xFF1A1F25), Color(0xFF0A0E12)],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.all(layout.padding),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 950;
                  return SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        WeighingStatusHeader(
                          isListening: _controller.isListening,
                          status: _controller.status,
                          requireApproval:
                              _controller.requireApprovalForRecords,
                        ),
                        SizedBox(height: layout.gap),
                        WeighingDesktopView(
                          controller: _controller,
                          command: CommandModel.dummy(),
                          isWide: isWide,
                          onStateChanged: () => setState(() {}),
                          onManageCameras: _manageCameras,
                          frontCameraKey: _frontCameraKey,
                          backCameraKey: _backCameraKey,
                          onFrontRefreshStream: () =>
                              _frontCameraKey.currentState?.refreshStream(),
                          onFrontZoomIn: () {
                            _frontCameraKey.currentState?.zoomIn();
                            setState(
                              () => _controller.frontCameraZoom =
                                  _frontCameraKey.currentState?.zoom ?? 1.0,
                            );
                          },
                          onFrontZoomOut: () {
                            _frontCameraKey.currentState?.zoomOut();
                            setState(
                              () => _controller.frontCameraZoom =
                                  _frontCameraKey.currentState?.zoom ?? 1.0,
                            );
                          },
                          onFrontResetZoom: () {
                            _frontCameraKey.currentState?.resetZoom();
                            setState(() => _controller.frontCameraZoom = 1.0);
                          },
                          onBackRefreshStream: () =>
                              _backCameraKey.currentState?.refreshStream(),
                          onBackZoomIn: () {
                            _backCameraKey.currentState?.zoomIn();
                            setState(
                              () => _controller.backCameraZoom =
                                  _backCameraKey.currentState?.zoom ?? 1.0,
                            );
                          },
                          onBackZoomOut: () {
                            _backCameraKey.currentState?.zoomOut();
                            setState(
                              () => _controller.backCameraZoom =
                                  _backCameraKey.currentState?.zoom ?? 1.0,
                            );
                          },
                          onBackResetZoom: () {
                            _backCameraKey.currentState?.resetZoom();
                            setState(() => _controller.backCameraZoom = 1.0);
                          },
                          onCaptureSnap: () =>
                              _captureSnap(CommandModel.dummy()),
                          onTriggerManualSnap: _triggerManualSnap,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _triggerManualSnap(CameraConfig camera) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          "Sending native trigger to ${camera.name} (${camera.ipAddress})...",
        ),
        duration: const Duration(seconds: 2),
      ),
    );
    try {
      final success = await AnprService().triggerManualSnap(
        cameraConfig: camera,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? "Native trigger sent to ${camera.name}!"
                  : "Trigger command sent to ${camera.name}",
            ),
            backgroundColor: success ? Colors.green.shade800 : Colors.blueGrey,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to trigger snap: $e"),
            backgroundColor: Colors.red.shade800,
          ),
        );
      }
    }
  }

  void _captureSnap(CommandModel command) {
    CameraCaptureService.captureAndHandle(
      context: context,
      enableFrontCamera: _controller.enableFrontCamera,
      enableBackCamera: _controller.enableBackCamera,
      cameraEnabled: command.cameraEnabled,
      frontCameraKey: _controller.enableFrontCamera ? _frontCameraKey : null,
      backCameraKey:
          (_controller.enableBackCamera && _controller.backCamera != null)
          ? _backCameraKey
          : null,
      frontCameraConfig: _controller.enableFrontCamera
          ? _controller.frontCamera
          : null,
      backCameraConfig: _controller.enableBackCamera
          ? _controller.backCamera
          : null,
      uploadOnCapture: _controller.uploadOnCapture,
      currentWeight: _controller.currentWeight,
      unit: _controller.unit,
      requestID: command.requestID,
      subdomain: command.subdomain,
      scaleName: command.scaleName,
      scaleStockId: command.scaleStockId,
      recordType: command.recordType,
      recordStage: command.recordStage,
      moduleType: command.moduleType,
      onLoadingChanged: (loading) =>
          setState(() => _controller.isCapturingSnap = loading),
    );
  }

  Future<void> _manageCameras() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CameraManagementScreen()),
    );
    _controller.loadSavedCameras(() => setState(() {}));
  }
}
