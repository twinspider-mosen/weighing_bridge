import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:path_provider/path_provider.dart';

class LiveCameraPlayer extends StatefulWidget {
  final String rtspUrl;
  final String cameraName;
  final bool showHeader;

  const LiveCameraPlayer({
    super.key,
    required this.rtspUrl,
    required this.cameraName,
    this.showHeader = true,
  });

  @override
  State<LiveCameraPlayer> createState() => LiveCameraPlayerState();
}

class LiveCameraPlayerState extends State<LiveCameraPlayer> {
  late final Player player;
  late final VideoController controller;
  bool isInitialized = false;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  @override
  void didUpdateWidget(LiveCameraPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rtspUrl != widget.rtspUrl) {
      _restartPlayer();
    }
  }

  Future<void> _initPlayer() async {
    try {
      player = Player();
      controller = VideoController(player);

      await player.open(Media(widget.rtspUrl));

      if (mounted) {
        setState(() {
          isInitialized = true;
          errorMessage = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          errorMessage = e.toString();
        });
      }
    }
  }

  Future<void> _restartPlayer() async {
    setState(() {
      isInitialized = false;
      errorMessage = null;
    });
    try {
      await player.open(Media(widget.rtspUrl));
      if (mounted) {
        setState(() {
          isInitialized = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          errorMessage = e.toString();
        });
      }
    }
  }

  @override
  void dispose() {
    player.dispose();
    super.dispose();
  }

  /// Captures a screenshot and saves it to Application Documents directory.
  /// Returns the saved file path on success.
  Future<String> captureSnapshot() async {
    if (!isInitialized || errorMessage != null) {
      throw Exception("Camera stream is not active or initialized.");
    }
    final directory = await getApplicationDocumentsDirectory();
    final sanitizedName = widget.cameraName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    final fileName = "snap_${sanitizedName}_${DateTime.now().millisecondsSinceEpoch}.png";
    final path = "${directory.path}/$fileName";

    final Uint8List? imageBytes = await player.screenshot(format: 'image/png');

    if (imageBytes != null && imageBytes.isNotEmpty) {
      final file = File(path);
      await file.writeAsBytes(imageBytes);
      return path;
    } else {
      throw Exception("Failed to acquire video frame from stream.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 15,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _buildVideoView(),
            if (widget.showHeader)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.8),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: errorMessage == null && isInitialized
                              ? Colors.greenAccent
                              : Colors.redAccent,
                          boxShadow: [
                            BoxShadow(
                              color: errorMessage == null && isInitialized
                                  ? Colors.greenAccent
                                  : Colors.redAccent,
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.cameraName,
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            shadows: [
                              const Shadow(
                                color: Colors.black,
                                blurRadius: 4,
                              )
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoView() {
    if (errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.videocam_off, color: Colors.redAccent, size: 36),
              const SizedBox(height: 8),
              Text(
                "Stream Error:\n$errorMessage",
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _restartPlayer,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text("Retry"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white12,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
              )
            ],
          ),
        ),
      );
    }

    if (!isInitialized) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Colors.greenAccent),
            const SizedBox(height: 12),
            Text(
              "Connecting to stream...",
              style: GoogleFonts.inter(color: Colors.white54, fontSize: 12),
            )
          ],
        ),
      );
    }

    return Video(
      controller: controller,
      fit: BoxFit.cover,
    );
  }
}
