import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:media_kit/media_kit.dart';
import 'package:weighing_bridge/camera_management_screen.dart';
import 'package:weighing_bridge/test_screen.dart';
import 'camera_service.dart';
import 'live_camera_player.dart';
import 'scale_service.dart';
import 'upload_dialog.dart';
import 'settings_service.dart';
import 'settings_screen.dart';
import 'logger_service.dart';
import 'log_viewer_screen.dart';
import 'ocr_screen.dart';
import 'ocr_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  await LoggerService().init();
  await OcrService().init();
  runApp(const WeighingBridgeApp());
}

class WeighingBridgeApp extends StatelessWidget {
  const WeighingBridgeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Industrial Weighing Bridge',
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.green,
        scaffoldBackgroundColor: const Color(0xFF0A0E12),
        useMaterial3: true,
      ),
      home: const WeighingScreen(),
    );
  }
}

class WeighingScreen extends StatefulWidget {
  const WeighingScreen({super.key});

  @override
  State<WeighingScreen> createState() => _WeighingScreenState();
}

class _WeighingScreenState extends State<WeighingScreen> {
  // Scale state
  final ScaleService _scaleService = ScaleService();
  String _currentWeight = '0.00';
  String _unit = 'kg';
  String? _selectedPort;
  bool _isScanning = false;
  bool _isListening = false;
  String _status = 'Disconnected';
  ScaleConfig? _activeConfig;

  // Camera state
  final CameraStorageService _cameraStorage = CameraStorageService();
  List<CameraConfig> _savedCameras = [];
  CameraConfig? _selectedCamera;
  final GlobalKey<LiveCameraPlayerState> _cameraPlayerKey =
      GlobalKey<LiveCameraPlayerState>();
  bool _isCapturingSnap = false;
  double _currentCameraZoom = 1.0;

  // Settings State
  final SettingsService _settingsService = SettingsService();
  bool _uploadOnCapture = true;

  @override
  void initState() {
    super.initState();
    _refreshPorts();
    _loadSavedCameras();
    _loadSettings();
    _scaleService.weightStream.listen(_handleNewData);
  }

  Future<void> _loadSettings() async {
    final value = await _settingsService.getUploadOnCapture();
    if (mounted) {
      setState(() {
        _uploadOnCapture = value;
      });
    }
  }

  Future<void> _loadSavedCameras() async {
    final cameras = await _cameraStorage.getCameras();
    setState(() {
      _savedCameras = cameras;
      if (_selectedCamera != null &&
          !cameras.any((c) => c.id == _selectedCamera!.id)) {
        _selectedCamera = null;
      }
      if (_selectedCamera == null && cameras.isNotEmpty) {
        _selectedCamera = cameras.first;
      }
    });
  }

  void _refreshPorts() {
    try {
      final ports = _scaleService.getAvailablePorts();
      setState(() {
        if (ports.isNotEmpty) {
          if (_selectedPort == null || !ports.contains(_selectedPort)) {
            _selectedPort = ports.first;
          }
        } else {
          _selectedPort = null;
          _status = 'No ports found';
        }
      });
    } catch (e) {
      setState(() {
        _status = 'Error loading ports: $e';
      });
    }
  }

  void _handleNewData(String data) {
    final trimmedData = data.trim();
    if (trimmedData.isEmpty) return;

    // Find the number in the string
    final match = RegExp(r'([0-9]+\.[0-9]+|[0-9]+)').firstMatch(trimmedData);
    final unitMatch = RegExp(
      r'(kg|lb|g)',
      caseSensitive: false,
    ).firstMatch(trimmedData);

    setState(() {
      if (match != null) {
        final rawWeight = match.group(0)!;
        // Parse the weight as a number to eliminate leading zeros and format it nicely
        try {
          if (rawWeight.contains('.')) {
            _currentWeight = double.parse(rawWeight).toStringAsFixed(2);
          } else {
            _currentWeight = int.parse(rawWeight).toString();
          }
        } catch (e) {
          _currentWeight = rawWeight;
        }
      }
      if (unitMatch != null) {
        _unit = unitMatch.group(0)!.toLowerCase();
      }
    });
  }

  Future<void> _startScan() async {
    if (_selectedPort == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a COM port first')),
      );
      return;
    }

    setState(() {
      _isScanning = true;
      _status = 'Scanning...';
    });

    try {
      final config = await _scaleService
          .scanPort(_selectedPort!)
          .timeout(const Duration(seconds: 45));

      if (config != null) {
        final success = await _scaleService.startListening(
          _selectedPort!,
          config,
        );
        setState(() {
          _activeConfig = config;
          _isListening = success;
          _status = success ? 'Connected' : 'Connection Failed';
        });
      } else {
        setState(() {
          _status = 'Scan Failed (No Signal)';
        });
      }
    } catch (e) {
      setState(() {
        _status = 'Scan Error: $e';
      });
    } finally {
      setState(() {
        _isScanning = false;
      });
    }
  }

  Future<void> _toggleListener() async {
    if (_isListening) {
      await _scaleService.stopListening();
      setState(() {
        _isListening = false;
        _status = 'Disconnected';
      });
    } else {
      if (_activeConfig != null && _selectedPort != null) {
        final success = await _scaleService.startListening(
          _selectedPort!,
          _activeConfig!,
        );
        setState(() {
          _isListening = success;
          _status = success ? 'Connected' : 'Connection Failed';
        });
      } else {
        _startScan();
      }
    }
  }

  Future<void> _captureCameraSnap() async {
    if (_selectedCamera == null) return;

    // 1. Capture the snapshot first while the layout and GPU textures are completely stable.
    // This avoids thread contention between the Flutter widget paint cycle and GPU frame readback.
    String? savedPath;
    try {
      savedPath = await _cameraPlayerKey.currentState?.captureSnapshot();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red.shade800,
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text("Capture Error: $e")),
              ],
            ),
          ),
        );
      }
      return;
    }

    // 2. Process according to settings (prompt upload or direct save to gallery)
    if (savedPath != null && mounted) {
      setState(() => _isCapturingSnap = true);
      try {
        if (_uploadOnCapture) {
          await showUploadDialog(
            context: context,
            imagePath: savedPath,
            currentWeight: "$_currentWeight $_unit",
          );
        } else {
          // Direct save option: skip upload dialog and show quick success notification with background OCR if enabled
          OcrResult? ocrResult;
          String? ocrError;
          if (OcrService().isConnected) {
            try {
              ocrResult = await OcrService().scanImage(savedPath);
              await LoggerService().log(
                "Direct Capture OCR complete. Raw text: '${ocrResult.rawText.replaceAll('\n', ' ')}'. "
                "Labeled: ${ocrResult.labeledTexts}. Engine: ${ocrResult.engineUsed}."
              );
            } catch (e) {
              ocrError = e.toString().replaceFirst("Exception: ", "").replaceFirst("StateError: ", "");
              await LoggerService().log("Direct Capture OCR failed", e);
            }
          }

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: Colors.teal.shade800,
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.check_circle, color: Colors.white, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            "Snapshot successfully saved to disk:\n$savedPath",
                            style: GoogleFonts.inter(fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                    if (ocrResult != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.psychology_outlined, color: Colors.greenAccent, size: 16),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              ocrResult.labeledTexts.containsKey("Car Number Plate")
                                  ? "AUTOMATIC OCR: Recognized Plate: ${ocrResult.labeledTexts["Car Number Plate"]}"
                                  : "AUTOMATIC OCR: Raw Scanned Text Detected",
                              style: GoogleFonts.inter(
                                color: Colors.greenAccent,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ] else if (ocrError != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.redAccent, size: 16),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              "OCR Scan Failed: $ocrError",
                              style: GoogleFonts.inter(color: Colors.redAccent.shade100, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
                duration: const Duration(seconds: 5),
              ),
            );
          }
        }
      } finally {
        if (mounted) {
          setState(() => _isCapturingSnap = false);
        }
      }
    }
  }

  @override
  void dispose() {
    _scaleService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: OcrService(),
      builder: (context, _) {
        return Scaffold(
          resizeToAvoidBottomInset: false,
          appBar: AppBar(
            backgroundColor: const Color(0xFF1A1F25),
            elevation: 0,
            title: Row(
              children: [
                const Icon(Icons.scale, color: Colors.greenAccent),
                const SizedBox(width: 12),
                Text(
                  'WEIGHING BRIDGE OPERATOR DASHBOARD',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),
          drawer: _buildDrawer(),
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
                padding: const EdgeInsets.all(24.0),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth > 950) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(flex: 3, child: _buildWeighingColumn(shrinkWrap: false)),
                          const SizedBox(width: 24),
                          Container(width: 1, color: Colors.white.withOpacity(0.1)),
                          const SizedBox(width: 24),
                          Expanded(flex: 2, child: _buildCameraColumn(shrinkWrap: false)),
                        ],
                      );
                    } else {
                      return SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildWeighingColumn(shrinkWrap: true),
                            const SizedBox(height: 32),
                            const Divider(color: Colors.white24),
                            const SizedBox(height: 32),
                            _buildCameraColumn(shrinkWrap: true),
                          ],
                        ),
                      );
                    }
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: const Color(0xFF1A1F25),
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: BoxDecoration(
              color: Colors.greenAccent.shade700.withOpacity(0.2),
            ),
            accountName: Text(
              'Weighbridge System',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            accountEmail: Text(
              'v2.0 • Serial & IP Camera Engine',
              style: GoogleFonts.inter(color: Colors.greenAccent, fontSize: 12),
            ),
            currentAccountPicture: const CircleAvatar(
              backgroundColor: Colors.greenAccent,
              child: Icon(
                Icons.factory_outlined,
                color: Colors.black,
                size: 32,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(
              Icons.dashboard_outlined,
              color: Colors.greenAccent,
            ),
            title: const Text(
              'Weighing Screen',
              style: TextStyle(color: Colors.white),
            ),
            onTap: () {
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(
              Icons.videocam_outlined,
              color: Colors.blueAccent,
            ),
            title: const Text(
              'IP Camera Management',
              style: TextStyle(color: Colors.white),
            ),
            onTap: () async {
              Navigator.pop(context);
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CameraManagementScreen(),
                ),
              );
              _loadSavedCameras();
            },
          ),
          ListTile(
            leading: const Icon(
              Icons.bug_report_outlined,
              color: Colors.orangeAccent,
            ),
            title: const Text(
              'IP Camera Test Screen',
              style: TextStyle(color: Colors.white70),
            ),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const TestScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(
              Icons.psychology,
              color: Colors.greenAccent,
            ),
            title: const Text(
              'AI OCR & Text Recognition',
              style: TextStyle(color: Colors.white),
            ),
            onTap: () async {
              Navigator.pop(context);
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const OcrScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(
              Icons.settings_outlined,
              color: Colors.tealAccent,
            ),
            title: const Text(
              'System Settings',
              style: TextStyle(color: Colors.white),
            ),
            onTap: () async {
              Navigator.pop(context);
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
              _loadSettings(); // Refresh settings state upon returning
            },
          ),
          ListTile(
            leading: const Icon(
              Icons.receipt_long_outlined,
              color: Colors.greenAccent,
            ),
            title: const Text(
              'System Diagnostic Logs',
              style: TextStyle(color: Colors.white),
            ),
            onTap: () async {
              Navigator.pop(context);
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const LogViewerScreen(),
                ),
              );
            },
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Antigravity Industrial POS System',
              style: GoogleFonts.inter(color: Colors.white24, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeighingColumn({bool shrinkWrap = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: shrinkWrap ? MainAxisSize.min : MainAxisSize.max,
      children: [
        _buildStatusHeader(),
        shrinkWrap ? const SizedBox(height: 24) : const Spacer(),
        _buildWeightDisplay(),
        shrinkWrap ? const SizedBox(height: 24) : const Spacer(),
        _buildControls(),
      ],
    );
  }

  Widget _buildCameraColumn({bool shrinkWrap = false}) {
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.camera_alt_outlined,
                    color: Colors.greenAccent,
                  ),
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
                icon: const Icon(
                  Icons.settings_outlined,
                  color: Colors.white54,
                  size: 20,
                ),
                tooltip: 'Manage IP Cameras',
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CameraManagementScreen(),
                    ),
                  );
                  _loadSavedCameras();
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_savedCameras.isEmpty) ...[
            shrinkWrap
                ? SizedBox(
                    height: 200,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.videocam_off,
                            size: 48,
                            color: Colors.white24,
                          ),
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
                            onPressed: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const CameraManagementScreen(),
                                ),
                              );
                              _loadSavedCameras();
                            },
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
                    ),
                  )
                : Expanded(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.videocam_off,
                            size: 48,
                            color: Colors.white24,
                          ),
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
                            onPressed: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const CameraManagementScreen(),
                                ),
                              );
                              _loadSavedCameras();
                            },
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
                    ),
                  ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1F25),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<CameraConfig>(
                        isExpanded: true,
                        dropdownColor: const Color(0xFF1A1F25),
                        value: _selectedCamera,
                        icon: const Icon(
                          Icons.arrow_drop_down,
                          color: Colors.greenAccent,
                        ),
                        items: _savedCameras.map((cam) {
                          return DropdownMenuItem<CameraConfig>(
                            value: cam,
                            child: Text(
                              '${cam.name} (${cam.ipAddress})',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setState(() {
                            _selectedCamera = val;
                            _currentCameraZoom = 1.0;
                          });
                          _cameraPlayerKey.currentState?.resetZoom();
                        },
                      ),
                    ),
                  ),
                ),
                if (_selectedCamera != null) ...[
                  const SizedBox(width: 12),
                  // Premium circular refresh button to force-restart stalled RTSP streams
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.tealAccent.withOpacity(0.08),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.tealAccent.withOpacity(0.2),
                      ),
                    ),
                    child: IconButton(
                      tooltip: 'Refresh Camera Stream',
                      icon: const Icon(Icons.refresh, color: Colors.tealAccent),
                      onPressed: () async {
                        // Restart the active live player stream
                        await _cameraPlayerKey.currentState?.refreshStream();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: Colors.teal.shade800,
                              content: Row(
                                children: [
                                  const Icon(
                                    Icons.sync,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      "Refreshing live stream for '${_selectedCamera!.name}'...",
                                      style: GoogleFonts.inter(
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 24),
            shrinkWrap
                ? SizedBox(
                    height: 300,
                    child: _selectedCamera == null
                        ? const Center(
                            child: Text(
                              "Please select a camera",
                              style: TextStyle(color: Colors.white54),
                            ),
                          )
                        : LiveCameraPlayer(
                            key: _cameraPlayerKey,
                            rtspUrl: _selectedCamera!.rtspUrl,
                            cameraName: _selectedCamera!.name,
                            showPauseButton: false,
                            onZoomChanged: (zoom) {
                              setState(() => _currentCameraZoom = zoom);
                            },
                          ),
                  )
                : Expanded(
                    child: _selectedCamera == null
                        ? const Center(
                            child: Text(
                              "Please select a camera",
                              style: TextStyle(color: Colors.white54),
                            ),
                          )
                        : LiveCameraPlayer(
                            key: _cameraPlayerKey,
                            rtspUrl: _selectedCamera!.rtspUrl,
                            cameraName: _selectedCamera!.name,
                            showPauseButton: false,
                            onZoomChanged: (zoom) {
                              setState(() => _currentCameraZoom = zoom);
                            },
                          ),
                  ),
            const SizedBox(height: 24),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // ── Capture Button ──────────────────────────────────────────
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _selectedCamera == null || _isCapturingSnap
                        ? null
                        : _captureCameraSnap,
                    icon: _isCapturingSnap
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
                      _isCapturingSnap ? 'SAVING SNAPSHOT...' : 'CAPTURE SNAP',
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
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 6,
                    ),
                  ),
                ),

                // ── Zoom Controls ───────────────────────────────────────────
                if (_selectedCamera != null) ...[
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1E28),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.greenAccent.withOpacity(0.25),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.35),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Zoom Out
                        Tooltip(
                          message: 'Zoom Out',
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: _currentCameraZoom > 1.01
                                ? () => _cameraPlayerKey.currentState?.zoomOut()
                                : null,
                            child: Container(
                              width: 36,
                              height: 36,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: _currentCameraZoom > 1.01
                                    ? Colors.greenAccent.withOpacity(0.08)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.zoom_out_rounded,
                                size: 20,
                                color: _currentCameraZoom > 1.01
                                    ? Colors.greenAccent
                                    : Colors.white24,
                              ),
                            ),
                          ),
                        ),

                        // Zoom level badge
                        Container(
                          width: 44,
                          alignment: Alignment.center,
                          child: Text(
                            '${_currentCameraZoom.toStringAsFixed(1)}x',
                            style: GoogleFonts.inter(
                              color: _currentCameraZoom > 1.01
                                  ? Colors.greenAccent
                                  : Colors.white54,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),

                        // Zoom In
                        Tooltip(
                          message: 'Zoom In',
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: _currentCameraZoom < 9.99
                                ? () => _cameraPlayerKey.currentState?.zoomIn()
                                : null,
                            child: Container(
                              width: 36,
                              height: 36,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: _currentCameraZoom < 9.99
                                    ? Colors.greenAccent.withOpacity(0.08)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.zoom_in_rounded,
                                size: 20,
                                color: _currentCameraZoom < 9.99
                                    ? Colors.greenAccent
                                    : Colors.white24,
                              ),
                            ),
                          ),
                        ),

                        // Reset (only visible when zoomed in)
                        if (_currentCameraZoom > 1.01) ...[
                          const SizedBox(width: 4),
                          Tooltip(
                            message: 'Reset Zoom',
                            child: InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: () {
                                _cameraPlayerKey.currentState?.resetZoom();
                                setState(() => _currentCameraZoom = 1.0);
                              },
                              child: Container(
                                width: 32,
                                height: 32,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: Colors.redAccent.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.restart_alt_rounded,
                                  size: 17,
                                  color: Colors.redAccent,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'LIVE BRIDGE LOAD',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 4,
                color: Colors.greenAccent.withOpacity(0.7),
              ),
            ),
            Text(
              'Weight Active',
              style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: _isListening
                ? Colors.green.withOpacity(0.1)
                : Colors.red.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _isListening ? Colors.greenAccent : Colors.redAccent,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isListening ? Colors.greenAccent : Colors.redAccent,
                  boxShadow: [
                    BoxShadow(
                      color: _isListening
                          ? Colors.greenAccent
                          : Colors.redAccent,
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                _status.toUpperCase(),
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                  color: _isListening ? Colors.greenAccent : Colors.redAccent,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWeightDisplay() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 40),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.4),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
              boxShadow: [
                BoxShadow(
                  color: Colors.greenAccent.withOpacity(0.05),
                  blurRadius: 50,
                  spreadRadius: 10,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  _currentWeight,
                  style: GoogleFonts.robotoMono(
                    fontSize: 110,
                    fontWeight: FontWeight.w500,
                    color: Colors.greenAccent,
                    shadows: [
                      Shadow(
                        color: Colors.greenAccent.withOpacity(0.5),
                        blurRadius: 20,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                Text(
                  _unit,
                  style: GoogleFonts.inter(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: Colors.white.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ),
          if (_activeConfig != null)
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: Text(
                'SIGNAL: ${_activeConfig.toString()}',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  letterSpacing: 2,
                  color: Colors.white24,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildControls() {
    final ports = _scaleService.getAvailablePorts();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SERIAL PORT',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                    color: Colors.white38,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: _selectedPort,
                          items: ports
                              .map(
                                (p) => DropdownMenuItem(
                                  value: p,
                                  child: Text(
                                    p,
                                    style: GoogleFonts.inter(fontSize: 16),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: _isScanning || _isListening
                              ? null
                              : (val) {
                                  setState(() => _selectedPort = val);
                                },
                          dropdownColor: const Color(0xFF1A1F25),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.refresh,
                        size: 20,
                        color: Colors.white38,
                      ),
                      onPressed: _isScanning || _isListening
                          ? null
                          : _refreshPorts,
                      tooltip: 'Refresh Ports',
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 24),
          _buildActionButton(
            label: _isScanning ? 'SCANNING...' : 'AUTO-SCAN',
            icon: Icons.search,
            color: Colors.blueAccent,
            onPressed: _isListening || _isScanning ? null : _startScan,
          ),
          const SizedBox(width: 16),
          _buildActionButton(
            label: _isListening ? 'STOP' : 'START',
            icon: _isListening ? Icons.stop_rounded : Icons.play_arrow_rounded,
            color: _isListening ? Colors.redAccent : Colors.greenAccent,
            onPressed: _isScanning ? null : _toggleListener,
            isPrimary: true,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback? onPressed,
    bool isPrimary = false,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      label: Text(
        label,
        style: GoogleFonts.inter(fontWeight: FontWeight.bold, letterSpacing: 1),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: isPrimary ? color : color.withOpacity(0.1),
        foregroundColor: isPrimary ? Colors.black : color,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: isPrimary
              ? BorderSide.none
              : BorderSide(color: color.withOpacity(0.3)),
        ),
        elevation: isPrimary ? 8 : 0,
        shadowColor: color.withOpacity(0.4),
      ),
    );
  }
}
