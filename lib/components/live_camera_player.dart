import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:path_provider/path_provider.dart';

class LiveCameraPlayer extends StatefulWidget {
  final String rtspUrl;
  final String cameraName;
  final bool showHeader;
  final bool paused;
  final bool showPauseButton;
  final String? ipAddress;

  /// Called whenever the zoom level changes (pinch, programmatic, etc.)
  final ValueChanged<double>? onZoomChanged;

  const LiveCameraPlayer({
    super.key,
    required this.rtspUrl,
    required this.cameraName,
    this.ipAddress,
    this.showHeader = true,
    this.paused = false,
    this.showPauseButton = true,
    this.onZoomChanged,
  });

  @override
  State<LiveCameraPlayer> createState() => LiveCameraPlayerState();
}

class LiveCameraPlayerState extends State<LiveCameraPlayer> {
  Player? player;
  VideoController? controller;
  bool isInitialized = false;
  String? errorMessage;
  bool? _localOverride; // null = follow widget.paused, true = force play, false = force pause
  
  final TransformationController _transformationController = TransformationController();
  double _zoomLevel = 1.0;
  double get zoom => _zoomLevel;
  Size _viewportSize = Size.zero;

  /// Key attached to the RepaintBoundary that wraps the live video view.
  /// Used by captureSnapshot() to render exactly what the operator sees.
  final GlobalKey _repaintKey = GlobalKey();

  bool get _shouldPlay => _localOverride ?? !widget.paused;

  @override
  void initState() {
    super.initState();
    _transformationController.addListener(_onTransformationChanged);
    if (_shouldPlay) {
      _initPlayer();
    }
  }

  void _onTransformationChanged() {
    final double scale = _transformationController.value.getMaxScaleOnAxis();
    if ((scale - _zoomLevel).abs() > 0.01) {
      setState(() {
        _zoomLevel = scale;
      });
      widget.onZoomChanged?.call(scale);
    }
  }

  @override
  void didUpdateWidget(LiveCameraPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rtspUrl != widget.rtspUrl) {
      _localOverride = null;
      _restartPlayer();
    } else if (oldWidget.paused != widget.paused) {
      _localOverride = null; // Sync back to parent state
      _syncPlayerState();
    }
  }

  Future<void> _syncPlayerState() async {
    if (_shouldPlay) {
      if (!isInitialized) {
        await _initPlayer();
      }
    } else {
      await _stopPlayer();
    }
  }

  Future<void> _initPlayer() async {
    try {
      final p = Player();
      final c = VideoController(p);

      await p.open(Media(widget.rtspUrl));

      if (mounted) {
        setState(() {
          player = p;
          controller = c;
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

  Future<void> _stopPlayer() async {
    if (player != null) {
      await player!.dispose();
      if (mounted) {
        setState(() {
          player = null;
          controller = null;
          isInitialized = false;
          errorMessage = null;
        });
      }
    }
  }

  Future<void> _restartPlayer() async {
    await _stopPlayer();
    if (_shouldPlay) {
      await _initPlayer();
    }
  }

  /// Public method to force refresh the active media stream in case it gets stuck.
  Future<void> refreshStream() async {
    await _restartPlayer();
  }

  @override
  void dispose() {
    _transformationController.removeListener(_onTransformationChanged);
    _transformationController.dispose();
    player?.dispose();
    super.dispose();
  }

  /// Public: zoom in by 0.5x steps, up to 10x
  void zoomIn() {
    final double nextZoom = (_zoomLevel + 0.5).clamp(1.0, 10.0);
    _applyZoom(nextZoom);
  }

  /// Public: zoom out by 0.5x steps, down to 1x
  void zoomOut() {
    final double nextZoom = (_zoomLevel - 0.5).clamp(1.0, 10.0);
    _applyZoom(nextZoom);
  }

  /// Public: reset zoom to 1x immediately
  void resetZoom() {
    _applyZoom(1.0);
  }

  void _applyZoom(double targetZoom) {
    setState(() {
      _zoomLevel = targetZoom;
      if (targetZoom <= 1.01) {
        _transformationController.value = Matrix4.identity();
      } else {
        final double centerX = _viewportSize.width / 2;
        final double centerY = _viewportSize.height / 2;
        
        final Matrix4 matrix = Matrix4.identity()
          ..translate(centerX, centerY)
          ..scale(targetZoom)
          ..translate(-centerX, -centerY);
        
        _transformationController.value = matrix;
      }
    });
    widget.onZoomChanged?.call(_zoomLevel);
  }



  /// Captures exactly what the operator sees (zoomed / panned view).
  /// Uses the RepaintBoundary render pipeline as primary method so the
  /// InteractiveViewer transform is baked into the image.
  /// Falls back to the raw player frame if the boundary render fails.
  Future<String> captureSnapshot() async {
    if (!isInitialized || errorMessage != null || player == null) {
      throw Exception("Camera stream is not active or initialized.");
    }

    final directory = await getApplicationDocumentsDirectory();
    final sanitizedName = widget.cameraName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    final timestamp   = DateTime.now().millisecondsSinceEpoch;

    // ── Primary: render the zoomed widget view ────────────────────────────
    try {
      final RenderRepaintBoundary? boundary =
          _repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;

      if (boundary != null) {
        // pixelRatio 2.0 doubles resolution for crisp output on desktop
        final ui.Image image = await boundary.toImage(pixelRatio: 2.0);
        final ByteData? byteData =
            await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();

        if (byteData != null) {
          final pngPath = "${directory.path}/snap_${sanitizedName}_$timestamp.png";
          await File(pngPath).writeAsBytes(byteData.buffer.asUint8List());
          return pngPath;
        }
      }
    } catch (_) {
      // boundary render failed — fall through to raw player screenshot
    }

    // ── Fallback: raw unzoomed frame from the media decoder ───────────────
    final Uint8List? imageBytes =
        await player!.screenshot(format: 'image/jpeg');

    if (imageBytes != null && imageBytes.isNotEmpty) {
      final jpgPath = "${directory.path}/snap_${sanitizedName}_$timestamp.jpg";
      await File(jpgPath).writeAsBytes(imageBytes);
      return jpgPath;
    }

    throw Exception("Failed to acquire video frame from stream.");
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
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Store the viewport size so public zoomIn/zoomOut can centre correctly
            _viewportSize = Size(constraints.maxWidth, constraints.maxHeight);
            return Stack(
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
                              widget.ipAddress != null
                                  ? "${widget.cameraName} (${widget.ipAddress})"
                                  : widget.cameraName,
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
                if (_shouldPlay && isInitialized && widget.showPauseButton)
                  Positioned(
                    bottom: 12,
                    right: 12,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white.withOpacity(0.1)),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () {
                            setState(() {
                              _localOverride = false;
                            });
                            _syncPlayerState();
                          },
                          child: const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Icon(
                              Icons.pause_rounded,
                              color: Colors.white70,
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildVideoView() {
    if (!_shouldPlay) {
      return InkWell(
        onTap: () {
          setState(() {
            _localOverride = true;
          });
          _syncPlayerState();
        },
        child: Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 1.2,
              colors: [Color(0xFF232931), Color(0xFF0F1216)],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.greenAccent.withOpacity(0.05),
                  border: Border.all(color: Colors.greenAccent.withOpacity(0.2), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.greenAccent.withOpacity(0.1),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.greenAccent,
                  size: 40,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                "CAMERA PAUSED",
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                "Click to stream live feed",
                style: GoogleFonts.inter(
                  color: Colors.white54,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      );
    }

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

    // RepaintBoundary lets captureSnapshot() render exactly what is on screen,
    // including the current zoom / pan transform from InteractiveViewer.
    return RepaintBoundary(
      key: _repaintKey,
      child: ClipRect(
        child: InteractiveViewer(
          transformationController: _transformationController,
          maxScale: 10.0,
          minScale: 1.0,
          boundaryMargin: EdgeInsets.zero,
          panEnabled: _zoomLevel > 1.01,
          scaleEnabled: true,
          child: Video(
            controller: controller!,
            fit: BoxFit.cover,
            controls: null,
          ),
        ),
      ),
    );
  }
}
