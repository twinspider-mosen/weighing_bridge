import 'package:flutter/material.dart';
import 'package:spider_weighbridge/components/live_camera_player.dart';
import 'package:spider_weighbridge/model/command_model.dart';
import 'package:spider_weighbridge/services/camera_service.dart';
import 'package:spider_weighbridge/services/firebase_service.dart';
import 'package:spider_weighbridge/services/logger_service.dart';
import 'package:spider_weighbridge/services/ocr_service.dart';
import 'package:spider_weighbridge/services/session_service.dart';
import 'package:spider_weighbridge/services/weighing_command_service.dart';
import 'package:spider_weighbridge/utils/helper_functions.dart';
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

  final GlobalKey<LiveCameraPlayerState> _frontCameraKey = GlobalKey<LiveCameraPlayerState>();
  final GlobalKey<LiveCameraPlayerState> _backCameraKey = GlobalKey<LiveCameraPlayerState>();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _controller.refreshPorts(() {});
    _controller.loadSavedCameras(() {});
    _controller.loadSettings(() {});
    _controller.loadUser(() {});
    _controller.scaleService.weightStream.listen((data) {
      _controller.handleNewData(data, () => setState(() {}));
    });

    _commandService.initCommandListener(
      contextProvider: () => context, isMounted: () => mounted,
      onLoadingChanged: (l) => setState(() => _controller.isCapturingSnap = l),
      frontKeyProvider: () => _frontCameraKey, backKeyProvider: () => _backCameraKey,
      requestApproval: (cmd) => WeighingDialogs.showApprovalDialog(context, cmd),
      currentWeightProvider: () => _controller.currentWeight, unitProvider: () => _controller.unit,
      uploadOnCaptureProvider: () => _controller.uploadOnCapture,
      enableFrontProvider: () => _controller.enableFrontCamera, enableBackProvider: () => _controller.enableBackCamera,
      backCameraProvider: () => _controller.backCamera,
    );
  }

  @override
  void dispose() {
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
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const WeighingScreen()));
            }
          },
        ),
        drawer: WeighingDrawer(
          onCamerasUpdated: () => _controller.loadSavedCameras(() => setState(() {})),
          onSettingsUpdated: () => _controller.loadSettings(() => setState(() {})),
        ),
        body: FutureBuilder(
          future: HelperFunctions.getSystemDetails(),
          builder: (context, snap) {
            if (!snap.hasData || snap.hasError) return const SizedBox.shrink();
            return StreamBuilder(
              stream: FirebaseService.getCommandStream(
                scaleName: snap.data!['scale_name'] ?? '',
                subdomains: snap.data!['subdomains'] ?? [],
              ),
              builder: (context, snapshot) {
                if (snapshot.hasError) LoggerService().log('Stream error: ${snapshot.error}');
                final commands = snapshot.data != null
                    ? List<CommandModel>.from(snapshot.data!.docs.map((doc) => CommandModel.fromMap(doc.data() as Map<String, dynamic>)))
                    : <CommandModel>[];
                final command = commands.isNotEmpty ? commands.first : CommandModel.dummy();

                return Container(
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
                                  requireApproval: _controller.requireApprovalForRecords,
                                ),
                                SizedBox(height: layout.gap),
                                WeighingDesktopView(
                                  controller: _controller,
                                  command: command,
                                  isWide: isWide,
                                  onStateChanged: () => setState(() {}),
                                  onManageCameras: _manageCameras,
                                  frontCameraKey: _frontCameraKey,
                                  backCameraKey: _backCameraKey,
                                  onFrontRefreshStream: () => _frontCameraKey.currentState?.refreshStream(),
                                  onFrontZoomIn: () { _frontCameraKey.currentState?.zoomIn(); setState(() => _controller.frontCameraZoom = _frontCameraKey.currentState?.zoom ?? 1.0); },
                                  onFrontZoomOut: () { _frontCameraKey.currentState?.zoomOut(); setState(() => _controller.frontCameraZoom = _frontCameraKey.currentState?.zoom ?? 1.0); },
                                  onFrontResetZoom: () { _frontCameraKey.currentState?.resetZoom(); setState(() => _controller.frontCameraZoom = 1.0); },
                                  onBackRefreshStream: () => _backCameraKey.currentState?.refreshStream(),
                                  onBackZoomIn: () { _backCameraKey.currentState?.zoomIn(); setState(() => _controller.backCameraZoom = _backCameraKey.currentState?.zoom ?? 1.0); },
                                  onBackZoomOut: () { _backCameraKey.currentState?.zoomOut(); setState(() => _controller.backCameraZoom = _backCameraKey.currentState?.zoom ?? 1.0); },
                                  onBackResetZoom: () { _backCameraKey.currentState?.resetZoom(); setState(() => _controller.backCameraZoom = 1.0); },
                                  onCaptureSnap: () => _captureSnap(command),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  void _captureSnap(CommandModel command) {
    CameraCaptureService.captureAndHandle(
      context: context,
      frontCameraKey: _controller.enableFrontCamera ? _frontCameraKey : null,
      backCameraKey: (_controller.enableBackCamera && _controller.backCamera != null) ? _backCameraKey : null,
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
      onLoadingChanged: (loading) => setState(() => _controller.isCapturingSnap = loading),
    );
  }

  Future<void> _manageCameras() async {
    await Navigator.push(context, MaterialPageRoute(builder: (context) => const CameraManagementScreen()));
    _controller.loadSavedCameras(() => setState(() {}));
  }

}
