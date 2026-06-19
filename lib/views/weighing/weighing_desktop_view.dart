import 'package:flutter/material.dart';
import 'package:spider_weighbridge/components/live_camera_player.dart';
import 'package:spider_weighbridge/model/command_model.dart';
import 'package:spider_weighbridge/views/weighing/camera_feed_panel.dart';
import 'package:spider_weighbridge/views/weighing/weighing_control_panel.dart';
import 'package:spider_weighbridge/views/weighing/weighing_layout_helper.dart';
import 'package:spider_weighbridge/views/weighing/weighing_screen_controller.dart';
import 'package:spider_weighbridge/views/weighing/weight_display_card.dart';

class WeighingDesktopView extends StatelessWidget {
  final WeighingScreenController controller;
  final CommandModel command;
  final bool isWide;
  final VoidCallback onStateChanged;
  final VoidCallback onManageCameras;

  final GlobalKey<LiveCameraPlayerState> frontCameraKey;
  final GlobalKey<LiveCameraPlayerState> backCameraKey;
  final VoidCallback onFrontRefreshStream;
  final VoidCallback onFrontZoomIn;
  final VoidCallback onFrontZoomOut;
  final VoidCallback onFrontResetZoom;

  final VoidCallback onBackRefreshStream;
  final VoidCallback onBackZoomIn;
  final VoidCallback onBackZoomOut;
  final VoidCallback onBackResetZoom;
  final VoidCallback onCaptureSnap;

  const WeighingDesktopView({
    super.key,
    required this.controller,
    required this.command,
    required this.isWide,
    required this.onStateChanged,
    required this.onManageCameras,
    required this.frontCameraKey,
    required this.backCameraKey,
    required this.onFrontRefreshStream,
    required this.onFrontZoomIn,
    required this.onFrontZoomOut,
    required this.onFrontResetZoom,
    required this.onBackRefreshStream,
    required this.onBackZoomIn,
    required this.onBackZoomOut,
    required this.onBackResetZoom,
    required this.onCaptureSnap,
  });

  @override
  Widget build(BuildContext context) {
    final layout = WeighingLayoutHelper(context);
    final bool showCameraPanel =
        controller.enableFrontCamera || controller.enableBackCamera;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // V2 (wide) vs V1 (narrow) weighing section
        isWide
            ? _buildWeighingColumnV2(layout)
            : _buildWeighingColumn(layout),
        if (showCameraPanel) ...[
          SizedBox(height: layout.cardGap),
          _buildCameraColumn(layout, shrinkWrap: true),
        ],
      ],
    );
  }

  // ── V1: stacked column layout (narrow screens) ────────────────────────────
  Widget _buildWeighingColumn(WeighingLayoutHelper layout) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        WeightDisplayCard(
          currentWeight: controller.currentWeight,
          unit: controller.unit,
          activeConfig: controller.activeConfig,
        ),
        SizedBox(height: layout.gap),
        WeighingControlPanel(
          selectedPort: controller.selectedPort,
          ports: controller.scaleService.getAvailablePorts(),
          isScanning: controller.isScanning,
          isListening: controller.isListening,
          onPortChanged: (val) {
            controller.selectedPort = val;
            onStateChanged();
          },
          onRefreshPorts: () => controller.refreshPorts(onStateChanged),
          onStartScan: () =>
              controller.startScan(layout.context, onStateChanged),
          onToggleListener: () =>
              controller.toggleListener(layout.context, onStateChanged),
        ),
      ],
    );
  }

  // ── V2: side-by-side row layout (wide screens) ────────────────────────────
  Widget _buildWeighingColumnV2(WeighingLayoutHelper layout) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Left: large weight display
          Expanded(
            flex: 3,
            child: WeightDisplayCard(
              currentWeight: controller.currentWeight,
              unit: controller.unit,
              activeConfig: controller.activeConfig,
            ),
          ),
          SizedBox(width: layout.cardGap),
          // Right: control panel card
          Expanded(
            flex: 2,
            child: WeighingControlPanel(
              selectedPort: controller.selectedPort,
              ports: controller.scaleService.getAvailablePorts(),
              isScanning: controller.isScanning,
              isListening: controller.isListening,
              onPortChanged: (val) {
                controller.selectedPort = val;
                onStateChanged();
              },
              onRefreshPorts: () => controller.refreshPorts(onStateChanged),
              onStartScan: () =>
                  controller.startScan(layout.context, onStateChanged),
              onToggleListener: () =>
                  controller.toggleListener(layout.context, onStateChanged),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraColumn(
    WeighingLayoutHelper layout, {
    required bool shrinkWrap,
  }) {
    return CameraFeedPanel(
      savedCameras: controller.savedCameras,
      frontCamera: controller.frontCamera,
      frontCameraKey: frontCameraKey,
      frontCameraZoom: controller.frontCameraZoom,
      onFrontCameraChanged: (val) {
        controller.frontCamera = val;
        controller.frontCameraZoom = 1.0;
        frontCameraKey.currentState?.resetZoom();
        onStateChanged();
      },
      onFrontRefreshStream: onFrontRefreshStream,
      onFrontZoomIn: onFrontZoomIn,
      onFrontZoomOut: onFrontZoomOut,
      onFrontResetZoom: onFrontResetZoom,
      backCamera: controller.backCamera,
      backCameraKey: backCameraKey,
      backCameraZoom: controller.backCameraZoom,
      onBackCameraChanged: (val) {
        controller.backCamera = val;
        controller.backCameraZoom = 1.0;
        backCameraKey.currentState?.resetZoom();
        onStateChanged();
      },
      onBackRefreshStream: onBackRefreshStream,
      onBackZoomIn: onBackZoomIn,
      onBackZoomOut: onBackZoomOut,
      onBackResetZoom: onBackResetZoom,
      isCapturingSnap: controller.isCapturingSnap,
      shrinkWrap: shrinkWrap,
      onCaptureSnap: onCaptureSnap,
      onManageCameras: onManageCameras,
      enableFront: controller.enableFrontCamera,
      enableBack: controller.enableBackCamera,
    );
  }
}
