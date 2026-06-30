import 'dart:io';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';

class TestScreen extends StatefulWidget {
  const TestScreen({super.key});

  @override
  State<TestScreen> createState() => _TestScreenState();
}

class _TestScreenState extends State<TestScreen> {
  late final Player player;
  late final VideoController controller;
  bool isInitialized = false;
  String? errorMessage;

  final rtspUrl =
      "rtsp://admin:admin%4012345@192.168.0.31:554/cam/realmonitor?channel=1&subtype=0";

  @override
  void initState() {
    super.initState();
    try {
      player = Player();
      controller = VideoController(player);
      
      // Open the RTSP camera stream
      player.open(Media(rtspUrl));
      
      setState(() {
        isInitialized = true;
      });
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
      });
    }
  }

  @override
  void dispose() {
    player.dispose();
    super.dispose();
  }

  Future<void> captureSnapshot() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final fileName =
          "snapshot_${DateTime.now().millisecondsSinceEpoch}.jpg";
      final path = "${directory.path}/$fileName";

      // Take a native screenshot of the video frame
      final Uint8List? imageBytes = await player.screenshot(format: 'image/jpeg');

      if (imageBytes != null) {
        final file = File(path);
        await file.writeAsBytes(imageBytes);
        debugPrint("Saved snapshot: $path");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.green.shade800,
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(child: Text("Saved snapshot: $path")),
                ],
              ),
            ),
          );
        }
      } else {
        throw Exception("Failed to acquire snapshot bytes from stream. Ensure the stream is active.");
      }
    } catch (e) {
      debugPrint("Snapshot error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red.shade800,
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text("Snapshot error: $e")),
              ],
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("IP Camera Live Stream & Capture"),
        elevation: 0,
        backgroundColor: const Color(0xFF1E293B),
      ),
      backgroundColor: const Color(0xFF0F172A),
      body: Column(
        children: [
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: _buildVideoView(),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                )
              ],
            ),
            child: Center(
              child: ElevatedButton.icon(
                onPressed: isInitialized && errorMessage == null ? captureSnapshot : null,
                icon: const Icon(Icons.camera_alt),
                label: const Text("Capture Live Snapshot"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.greenAccent.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoView() {
    if (errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
              const SizedBox(height: 16),
              Text(
                "Failed to initialize player:\n$errorMessage",
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    if (!isInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.greenAccent),
      );
    }

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Video(controller: controller),
    );
  }
}