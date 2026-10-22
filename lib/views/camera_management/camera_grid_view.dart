import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:spider_weighbridge/components/live_camera_player.dart';
import 'package:spider_weighbridge/services/camera_service.dart';

class CameraGridView extends StatelessWidget {
  final List<CameraConfig> cameras;
  final bool allStreamsPaused;
  final Function(CameraConfig) onDeleteCamera;
  final Function(CameraConfig)? onEditCamera;
  final Function(CameraConfig)? onToggleAnpr;

  const CameraGridView({
    super.key,
    required this.cameras,
    required this.allStreamsPaused,
    required this.onDeleteCamera,
    this.onEditCamera,
    this.onToggleAnpr,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount = 1;
        if (constraints.maxWidth > 1200) {
          crossAxisCount = 3;
        } else if (constraints.maxWidth > 700) {
          crossAxisCount = 2;
        }

        return GridView.builder(
          padding: const EdgeInsets.all(24),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 24,
            mainAxisSpacing: 24,
            childAspectRatio: 16 / 10,
          ),
          itemCount: cameras.length,
          itemBuilder: (context, index) {
            final camera = cameras[index];
            return Card(
              color: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.white.withOpacity(0.1)),
              ),
              elevation: 8,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  LiveCameraPlayer(
                    rtspUrl: camera.rtspUrl,
                    cameraName: camera.name,
                    ipAddress: camera.ipAddress,
                    paused: allStreamsPaused,
                  ),

                  // Top overlay: Camera name and action controls (ANPR toggle, edit, delete)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withOpacity(0.85),
                            Colors.transparent,
                          ],
                        ),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Camera Name
                          Expanded(
                            child: Text(
                              camera.name,
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),

                          // ANPR Toggle Button
                          Tooltip(
                            message: camera.enableAnpr
                                ? 'ANPR Enabled. Click to disable.'
                                : 'ANPR Disabled. Click to enable.',
                            child: InkWell(
                              onTap: () => onToggleAnpr?.call(camera),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: camera.enableAnpr
                                      ? Colors.greenAccent.withOpacity(0.2)
                                      : Colors.black.withOpacity(0.6),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: camera.enableAnpr
                                        ? Colors.greenAccent
                                        : Colors.white24,
                                    width: 1.2,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.document_scanner_outlined,
                                      size: 13,
                                      color: camera.enableAnpr
                                          ? Colors.greenAccent
                                          : Colors.white38,
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      camera.enableAnpr
                                          ? "ANPR ON"
                                          : "ANPR OFF",
                                      style: GoogleFonts.inter(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: camera.enableAnpr
                                            ? Colors.greenAccent
                                            : Colors.white54,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),

                          // Edit Camera Button
                          if (onEditCamera != null)
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.6),
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                constraints: const BoxConstraints(
                                  minWidth: 32,
                                  minHeight: 32,
                                ),
                                padding: EdgeInsets.zero,
                                icon: const Icon(
                                  Icons.edit_outlined,
                                  color: Colors.white70,
                                  size: 17,
                                ),
                                tooltip: 'Edit Camera & ANPR',
                                onPressed: () => onEditCamera!(camera),
                              ),
                            ),
                          const SizedBox(width: 4),

                          // Delete Button
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.6),
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              constraints: const BoxConstraints(
                                minWidth: 32,
                                minHeight: 32,
                              ),
                              padding: EdgeInsets.zero,
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.redAccent,
                                size: 17,
                              ),
                              tooltip: 'Remove Camera',
                              onPressed: () => onDeleteCamera(camera),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Bottom overlay: IP and ANPR status info
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withOpacity(0.85),
                            Colors.transparent,
                          ],
                        ),
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(16),
                          bottomRight: Radius.circular(16),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.wifi,
                                color: Colors.tealAccent,
                                size: 13,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                camera.ipAddress,
                                style: GoogleFonts.inter(
                                  color: Colors.white70,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: camera.enableAnpr
                                  ? Colors.greenAccent.withOpacity(0.12)
                                  : Colors.white.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: camera.enableAnpr
                                    ? Colors.greenAccent.withOpacity(0.3)
                                    : Colors.white12,
                              ),
                            ),
                            child: Text(
                              camera.enableAnpr
                                  ? "ANPR ACTIVE"
                                  : "ANPR DISABLED",
                              style: GoogleFonts.inter(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                                color: camera.enableAnpr
                                    ? Colors.greenAccent
                                    : Colors.white38,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
