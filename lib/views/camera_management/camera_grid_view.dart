import 'package:flutter/material.dart';
import 'package:spider_weighbridge/components/live_camera_player.dart';
import 'package:spider_weighbridge/services/camera_service.dart';

class CameraGridView extends StatelessWidget {
  final List<CameraConfig> cameras;
  final bool allStreamsPaused;
  final Function(CameraConfig) onDeleteCamera;

  const CameraGridView({
    super.key,
    required this.cameras,
    required this.allStreamsPaused,
    required this.onDeleteCamera,
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
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
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
                      child: const Row(
                        children: [
                          Icon(Icons.link, color: Colors.tealAccent, size: 12),
                          SizedBox(width: 6),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.redAccent,
                          size: 20,
                        ),
                        tooltip: 'Remove Camera',
                        onPressed: () => onDeleteCamera(camera),
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
