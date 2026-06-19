import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:spider_weighbridge/components/live_camera_player.dart';
import 'package:spider_weighbridge/services/camera_service.dart';
import 'package:spider_weighbridge/services/ocr_service.dart';
import 'camera_zoom_controls.dart';

class CameraFeedPanel extends StatelessWidget {
  final List<CameraConfig> savedCameras;

  // Front camera
  final CameraConfig? frontCamera;
  final GlobalKey<LiveCameraPlayerState> frontCameraKey;
  final double frontCameraZoom;
  final ValueChanged<CameraConfig?> onFrontCameraChanged;
  final VoidCallback onFrontRefreshStream;
  final VoidCallback onFrontZoomIn;
  final VoidCallback onFrontZoomOut;
  final VoidCallback onFrontResetZoom;

  // Back camera
  final CameraConfig? backCamera;
  final GlobalKey<LiveCameraPlayerState> backCameraKey;
  final double backCameraZoom;
  final ValueChanged<CameraConfig?> onBackCameraChanged;
  final VoidCallback onBackRefreshStream;
  final VoidCallback onBackZoomIn;
  final VoidCallback onBackZoomOut;
  final VoidCallback onBackResetZoom;

  // Shared
  final bool isCapturingSnap;
  final bool shrinkWrap;
  final VoidCallback onCaptureSnap;
  final VoidCallback onManageCameras;
  final bool enableFront;
  final bool enableBack;

  const CameraFeedPanel({
    super.key,
    required this.savedCameras,
    required this.frontCamera,
    required this.frontCameraKey,
    required this.frontCameraZoom,
    required this.onFrontCameraChanged,
    required this.onFrontRefreshStream,
    required this.onFrontZoomIn,
    required this.onFrontZoomOut,
    required this.onFrontResetZoom,
    required this.backCamera,
    required this.backCameraKey,
    required this.backCameraZoom,
    required this.onBackCameraChanged,
    required this.onBackRefreshStream,
    required this.onBackZoomIn,
    required this.onBackZoomOut,
    required this.onBackResetZoom,
    required this.isCapturingSnap,
    required this.shrinkWrap,
    required this.onCaptureSnap,
    required this.onManageCameras,
    required this.enableFront,
    required this.enableBack,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      // decoration: BoxDecoration(
      //   color: Colors.black.withOpacity(0.3),
      //   borderRadius: BorderRadius.circular(24),
      //   border: Border.all(color: Colors.white.withOpacity(0.05)),
      //   boxShadow: [
      //     BoxShadow(
      //       color: Colors.black.withOpacity(0.2),
      //       blurRadius: 20,
      //       spreadRadius: 2,
      //     ),
      // ],
      // ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: shrinkWrap ? MainAxisSize.min : MainAxisSize.max,
        children: [
          _buildHeader(),
          const SizedBox(height: 16),
          if (savedCameras.isEmpty)
            _buildEmptyState()
          else ...[
            // Side-by-side camera feeds
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (enableFront)
                  Expanded(
                    child: _buildSingleFeed(
                      label: 'FRONT',
                      labelColor: Colors.greenAccent,
                      camera: frontCamera,
                      playerKey: frontCameraKey,
                      zoom: frontCameraZoom,
                      onCameraChanged: onFrontCameraChanged,
                      onRefresh: onFrontRefreshStream,
                      onZoomIn: onFrontZoomIn,
                      onZoomOut: onFrontZoomOut,
                      onResetZoom: onFrontResetZoom,
                    ),
                  ),
                if (enableFront && enableBack) const SizedBox(width: 16),
                if (enableBack)
                  Expanded(
                    child: _buildSingleFeed(
                      label: 'BACK',
                      labelColor: Colors.orangeAccent,
                      camera: backCamera,
                      playerKey: backCameraKey,
                      zoom: backCameraZoom,
                      onCameraChanged: onBackCameraChanged,
                      onRefresh: onBackRefreshStream,
                      onZoomIn: onBackZoomIn,
                      onZoomOut: onBackZoomOut,
                      onResetZoom: onBackResetZoom,
                    ),
                  ),
                if (!enableFront && !enableBack)
                  Expanded(
                    child: Container(
                      height: 220,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.05),
                        ),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.videocam_off,
                              color: Colors.white24,
                              size: 48,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Both front and back cameras are disabled in settings',
                              style: GoogleFonts.inter(
                                color: Colors.white38,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            _buildCaptureButton(),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            const Icon(Icons.camera_alt_outlined, color: Colors.greenAccent),
            const SizedBox(width: 10),
            Text(
              'VEHICLE CAMERA FEEDS',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
                color: Colors.white,
              ),
            ),
            if (OcrService().isConnected) ...[
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.greenAccent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: Colors.greenAccent.withOpacity(0.3),
                  ),
                ),
                child: Text(
                  "OCR ACTIVE",
                  style: GoogleFonts.inter(
                    color: Colors.greenAccent,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ],
        ),
        IconButton(
          icon: const Icon(
            Icons.settings_outlined,
            color: Colors.white54,
            size: 20,
          ),
          tooltip: 'Manage IP Cameras',
          onPressed: onManageCameras,
        ),
      ],
    );
  }

  Widget _buildSingleFeed({
    required String label,
    required Color labelColor,
    required CameraConfig? camera,
    required GlobalKey<LiveCameraPlayerState> playerKey,
    required double zoom,
    required ValueChanged<CameraConfig?> onCameraChanged,
    required VoidCallback onRefresh,
    required VoidCallback onZoomIn,
    required VoidCallback onZoomOut,
    required VoidCallback onResetZoom,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Label chip
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          spacing: 12,
          children: [
            if (camera != null)
              CameraZoomControls(
                currentCameraZoom: zoom,
                onZoomIn: onZoomIn,
                onZoomOut: onZoomOut,
                onResetZoom: onResetZoom,
              ),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: labelColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: labelColor.withOpacity(0.3)),
              ),
              child: Text(
                label,
                style: GoogleFonts.inter(
                  color: labelColor,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ),
            if (camera != null) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onRefresh,
                child: Icon(Icons.refresh, color: Colors.tealAccent, size: 18),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        // Camera selector dropdown
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1F25),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<CameraConfig>(
              isExpanded: true,
              dropdownColor: const Color(0xFF1A1F25),
              value: camera,
              hint: Text(
                'Select camera',
                style: GoogleFonts.inter(color: Colors.white38, fontSize: 12),
              ),
              icon: const Icon(
                Icons.arrow_drop_down,
                color: Colors.greenAccent,
              ),
              items: savedCameras.map((cam) {
                return DropdownMenuItem<CameraConfig>(
                  value: cam,
                  child: Text(
                    "${cam.name} (${cam.ipAddress})",
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: onCameraChanged,
            ),
          ),
        ),
        const SizedBox(height: 10),
        // Player
        SizedBox(
          height: 320,
          child: camera == null
              ? Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.05)),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.videocam_off,
                          color: Colors.white24,
                          size: 32,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No camera selected',
                          style: GoogleFonts.inter(
                            color: Colors.white38,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: LiveCameraPlayer(
                    key: playerKey,
                    rtspUrl: camera.rtspUrl,
                    cameraName: camera.name,
                    ipAddress: camera.ipAddress,
                    showPauseButton: false,
                    onZoomChanged: (z) {},
                  ),
                ),
        ),
        const SizedBox(height: 8),

        // Zoom controls
      ],
    );
  }

  Widget _buildEmptyState() {
    final content = Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.videocam_off, size: 48, color: Colors.white24),
          const SizedBox(height: 12),
          Text(
            'No IP Cameras Available',
            style: GoogleFonts.inter(
              color: Colors.white54,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onManageCameras,
            icon: const Icon(Icons.add_a_photo, size: 18),
            label: const Text('Add Camera'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.greenAccent.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
    return shrinkWrap
        ? SizedBox(height: 200, child: content)
        : SizedBox(height: 300, child: content);
  }

  Widget _buildCaptureButton() {
    final hasFront = enableFront && frontCamera != null;
    final hasBack = enableBack && backCamera != null;
    final canCapture = hasFront || hasBack;

    String labelText = 'CAPTURE';
    if (hasFront && hasBack) {
      labelText = 'CAPTURE FRONT + BACK';
    } else if (hasFront) {
      labelText = 'CAPTURE FRONT';
    } else if (hasBack) {
      labelText = 'CAPTURE BACK';
    }

    return ElevatedButton.icon(
      onPressed: canCapture && !isCapturingSnap ? onCaptureSnap : null,
      icon: isCapturingSnap
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                color: Colors.black,
                strokeWidth: 2,
              ),
            )
          : const Icon(Icons.camera),
      label: Text(
        isCapturingSnap ? 'CAPTURING...' : labelText,
        style: GoogleFonts.inter(
          fontWeight: FontWeight.bold,
          fontSize: 15,
          letterSpacing: 1,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.greenAccent.shade700,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 6,
      ),
    );
  }
}
