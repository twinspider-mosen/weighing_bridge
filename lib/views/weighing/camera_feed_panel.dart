import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:weighing_bridge/components/live_camera_player.dart';
import 'package:weighing_bridge/services/camera_service.dart';
import 'package:weighing_bridge/services/ocr_service.dart';
import 'camera_zoom_controls.dart';

class CameraFeedPanel extends StatelessWidget {
  final List<CameraConfig> savedCameras;
  final CameraConfig? selectedCamera;
  final GlobalKey<LiveCameraPlayerState> cameraPlayerKey;
  final double currentCameraZoom;
  final bool isCapturingSnap;
  final bool shrinkWrap;
  final ValueChanged<CameraConfig?> onCameraChanged;
  final VoidCallback onRefreshStream;
  final VoidCallback onCaptureSnap;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onResetZoom;
  final VoidCallback onManageCameras;

  const CameraFeedPanel({
    super.key,
    required this.savedCameras,
    required this.selectedCamera,
    required this.cameraPlayerKey,
    required this.currentCameraZoom,
    required this.isCapturingSnap,
    required this.shrinkWrap,
    required this.onCameraChanged,
    required this.onRefreshStream,
    required this.onCaptureSnap,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onResetZoom,
    required this.onManageCameras,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
    
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: shrinkWrap ? MainAxisSize.min : MainAxisSize.max,
        children: [
          _buildHeader(),
          const SizedBox(height: 16),
          if (savedCameras.isEmpty)
            _buildEmptyState()
          else ...[
            _buildSelectorRow(),
            const SizedBox(height: 24),
            _buildPlayerContainer(),
            const SizedBox(height: 24),
            _buildControlRow(),
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
              'VEHICLE CAMERA FEED',
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
                  border: Border.all(color: Colors.greenAccent.withOpacity(0.3)),
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
          icon: const Icon(Icons.settings_outlined, color: Colors.white54, size: 20),
          tooltip: 'Manage IP Cameras',
          onPressed: onManageCameras,
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    final emptyContent = Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.videocam_off, size: 48, color: Colors.white24),
          const SizedBox(height: 12),
          Text(
            'No IP Cameras Available',
            style: GoogleFonts.inter(color: Colors.white54, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onManageCameras,
            icon: const Icon(Icons.add_a_photo, size: 18),
            label: const Text('Add Camera'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.greenAccent.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );

    return shrinkWrap ? SizedBox(height: 200, child: emptyContent) : Expanded(child: emptyContent);
  }

  Widget _buildSelectorRow() {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1F25),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<CameraConfig>(
                isExpanded: true,
                dropdownColor: const Color(0xFF1A1F25),
                value: selectedCamera,
                icon: const Icon(Icons.arrow_drop_down, color: Colors.greenAccent),
                items: savedCameras.map((cam) {
                  return DropdownMenuItem<CameraConfig>(
                    value: cam,
                    child: Text(
                      '${cam.name} (${cam.ipAddress})',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 14),
                    ),
                  );
                }).toList(),
                onChanged: onCameraChanged,
              ),
            ),
          ),
        ),
        if (selectedCamera != null) ...[
          const SizedBox(width: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.tealAccent.withOpacity(0.08),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.tealAccent.withOpacity(0.2)),
            ),
            child: IconButton(
              tooltip: 'Refresh Camera Stream',
              icon: const Icon(Icons.refresh, color: Colors.tealAccent),
              onPressed: onRefreshStream,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPlayerContainer() {
    final playerWidget = selectedCamera == null
        ? const Center(child: Text("Please select a camera", style: TextStyle(color: Colors.white54)))
        : LiveCameraPlayer(
            key: cameraPlayerKey,
            rtspUrl: selectedCamera!.rtspUrl,
            cameraName: selectedCamera!.name,
            showPauseButton: false,
            onZoomChanged: (zoom) {},
          );

return SizedBox(
  height: 250,
  // height: shrinkWrap ? 250 : 250,
  child: playerWidget,
);
    // return shrinkWrap ? SizedBox(height: 300, child: playerWidget) : Expanded(child: playerWidget);
  }

  Widget _buildControlRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: selectedCamera == null || isCapturingSnap ? null : onCaptureSnap,
            icon: isCapturingSnap
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2),
                  )
                : const Icon(Icons.camera),
            label: Text(
              isCapturingSnap ? 'SAVING SNAPSHOT...' : 'CAPTURE SNAP',
              style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 1),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.greenAccent.shade700,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 20),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 6,
            ),
          ),
        ),
        if (selectedCamera != null) ...[
          const SizedBox(width: 12),
          CameraZoomControls(
            currentCameraZoom: currentCameraZoom,
            onZoomIn: onZoomIn,
            onZoomOut: onZoomOut,
            onResetZoom: onResetZoom,
          ),
        ],
      ],
    );
  }
}
