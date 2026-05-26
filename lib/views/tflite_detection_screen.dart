import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import '../services/tflite_detection_service.dart';
import 'tflite/detection_result_popup.dart';

class TfliteDetectionScreen extends StatefulWidget {
  const TfliteDetectionScreen({super.key});

  @override
  State<TfliteDetectionScreen> createState() => _TfliteDetectionScreenState();
}

class _TfliteDetectionScreenState extends State<TfliteDetectionScreen> with SingleTickerProviderStateMixin {
  final TfliteDetectionService _tfliteService = TfliteDetectionService();

  String? _selectedImagePath;
  Map<String, dynamic>? _confirmedJson;
  bool _isScanning = false;
  String? _errorMessage;

  late AnimationController _scannerAnimationController;
  late Animation<double> _scannerValue;

  @override
  void initState() {
    super.initState();
    _tfliteService.init().then((_) {
      if (mounted) {
        setState(() {});
      }
    });

    _scannerAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _scannerValue = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _scannerAnimationController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _scannerAnimationController.dispose();
    super.dispose();
  }

  Future<void> _pickModel() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['tflite'],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _errorMessage = null;
        });
        await _tfliteService.loadCustomModel(result.files.single.path!);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.teal.shade800,
            content: Row(
              children: [
                const Icon(Icons.check_circle_outline, color: Colors.greenAccent),
                const SizedBox(width: 12),
                Text(
                  'Custom TFLite model loaded successfully!',
                  style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Failed to load model file: $e";
      });
    }
  }

  Future<void> _unloadModel() async {
    await _tfliteService.unloadCustomModel();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.orange.shade900,
        content: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.amberAccent),
            const SizedBox(width: 12),
            Text(
              'Unloaded custom model. Reverted to built-in fallback.',
              style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage() async {
    setState(() {
      _errorMessage = null;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _selectedImagePath = result.files.single.path;
          _confirmedJson = null;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Failed to pick file: $e";
      });
    }
  }

  Future<void> _runPlateDetection() async {
    if (_selectedImagePath == null) return;

    setState(() {
      _isScanning = true;
      _confirmedJson = null;
      _errorMessage = null;
    });
    _scannerAnimationController.repeat(reverse: true);

    try {
      // 1. Run detection & image crop service
      final result = await _tfliteService.processImage(_selectedImagePath!);
      
      if (!mounted) return;

      // Stop scanner animation before opening popup
      _scannerAnimationController.stop();
      _scannerAnimationController.reset();
      setState(() {
        _isScanning = false;
      });

      // 2. Open popup modal to display bounded/cropped image & edit plate text
      final confirmedData = await showDialog<Map<String, dynamic>>(
        context: context,
        barrierDismissible: false,
        builder: (context) => DetectionResultPopup(detectionResult: result),
      );

      // 3. Process confirmed JSON payload returned from the popup
      if (confirmedData != null) {
        setState(() {
          _confirmedJson = confirmedData;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.teal.shade800,
            content: Row(
              children: [
                const Icon(Icons.verified, color: Colors.greenAccent),
                const SizedBox(width: 12),
                Text(
                  'License Plate Confirmed and Compiled into JSON Ledger!',
                  style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst("Exception: ", "").replaceFirst("StateError: ", "");
        _isScanning = false;
      });
      _scannerAnimationController.stop();
      _scannerAnimationController.reset();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _tfliteService,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            backgroundColor: const Color(0xFF161B21),
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            title: Row(
              children: [
                const Icon(Icons.filter_center_focus_outlined, color: Colors.cyanAccent),
                const SizedBox(width: 12),
                Text(
                  'TFLITE LICENSE PLATE DETECTOR',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    letterSpacing: 2,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          body: Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.5,
                colors: [Color(0xFF161B21), Color(0xFF090C0E)],
              ),
            ),
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    LayoutBuilder(
                      builder: (context, constraints) {
                        if (constraints.maxWidth > 950) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 3, child: _buildLeftControlPanel()),
                              const SizedBox(width: 24),
                              Expanded(flex: 4, child: _buildRightResultsPanel()),
                            ],
                          );
                        } else {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildLeftControlPanel(),
                              const SizedBox(height: 24),
                              _buildRightResultsPanel(),
                            ],
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLeftControlPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Custom Model Management Card
        _buildSectionCard(
          title: "CUSTOM DETECTOR MODEL CONFIG",
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.cyanAccent.withOpacity(0.08)),
                ),
                child: Row(
                  children: [
                    Icon(
                      _tfliteService.isModelLoaded ? Icons.memory : Icons.no_sim_outlined,
                      color: _tfliteService.isModelLoaded ? Colors.cyanAccent : Colors.white24,
                      size: 24,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _tfliteService.isModelLoaded ? 'ACTIVE MODEL LOADED' : 'BUILT-IN MOCK INFERENCE',
                            style: GoogleFonts.inter(
                              color: _tfliteService.isModelLoaded ? Colors.cyanAccent : Colors.white54,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _tfliteService.isModelLoaded
                                ? _tfliteService.customModelName!
                                : 'default_yolov8_lp_nano.tflite',
                            style: GoogleFonts.robotoMono(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (_tfliteService.isModelLoaded) ...[
                _buildModelMetadataItem('Input Tensor Shape', '1 x 320 x 320 x 3 (Float32)'),
                _buildModelMetadataItem('Output Tensor Shape', '1 x 8400 x 6 (Float32)'),
                _buildModelMetadataItem('Detection Class', 'Class 0: License Plate'),
                const SizedBox(height: 12),
              ],
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _pickModel,
                      icon: const Icon(Icons.file_open_outlined, size: 14),
                      label: Text(
                        _tfliteService.isModelLoaded ? 'CHANGE MODEL' : 'LOAD CUSTOM MODEL',
                        style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 11),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.cyanAccent.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  if (_tfliteService.isModelLoaded) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                      tooltip: 'Revert to Built-in',
                      onPressed: _unloadModel,
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.redAccent.withOpacity(0.08),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(color: Colors.redAccent.withOpacity(0.2)),
                        ),
                      ),
                    )
                  ]
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 2. Source Image Upload/Picker
        _buildSectionCard(
          title: "INPUT SNAPSHOT IMAGE",
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              if (_selectedImagePath == null)
                InkWell(
                  onTap: _pickImage,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    height: 180,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.01),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.1),
                        style: BorderStyle.solid,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.cyanAccent.withOpacity(0.05),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.add_photo_alternate_outlined,
                            color: Colors.cyanAccent,
                            size: 28,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          "Choose image from gallery",
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "PNG, JPG, JPEG supported",
                          style: GoogleFonts.inter(color: Colors.white38, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            height: 180,
                            width: double.infinity,
                            decoration: const BoxDecoration(color: Colors.black54),
                            child: Image.file(
                              File(_selectedImagePath!),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        if (_isScanning)
                          Positioned.fill(
                            child: AnimatedBuilder(
                              animation: _scannerAnimationController,
                              builder: (context, child) {
                                return Stack(
                                  children: [
                                    Positioned(
                                      top: 180 * _scannerValue.value - 2,
                                      left: 0,
                                      right: 0,
                                      child: Container(
                                        height: 4,
                                        decoration: BoxDecoration(
                                          color: Colors.cyanAccent,
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.cyanAccent.withOpacity(0.8),
                                              blurRadius: 12,
                                              spreadRadius: 3,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    Container(
                                      color: Colors.black.withOpacity(0.15),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: CircleAvatar(
                            backgroundColor: Colors.black.withOpacity(0.6),
                            child: IconButton(
                              icon: const Icon(Icons.close, color: Colors.white, size: 18),
                              onPressed: _isScanning
                                  ? null
                                  : () {
                                      setState(() {
                                        _selectedImagePath = null;
                                        _confirmedJson = null;
                                      });
                                    },
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            p.basename(_selectedImagePath!),
                            style: GoogleFonts.robotoMono(color: Colors.white54, fontSize: 11),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _isScanning ? null : _pickImage,
                          icon: const Icon(Icons.sync, size: 14, color: Colors.cyanAccent),
                          label: Text(
                            "Change",
                            style: GoogleFonts.inter(color: Colors.cyanAccent, fontSize: 12),
                          ),
                        )
                      ],
                    ),
                  ],
                ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _selectedImagePath == null || _isScanning ? null : _runPlateDetection,
                icon: _isScanning
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2),
                      )
                    : const Icon(Icons.center_focus_strong_outlined, size: 18),
                label: Text(
                  _isScanning ? "DETECTING VEHICLE..." : "RUN PLATE DETECTION",
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.cyanAccent.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildModelMetadataItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.inter(color: Colors.white30, fontSize: 11)),
          Text(value, style: GoogleFonts.robotoMono(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildRightResultsPanel() {
    if (_errorMessage != null) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.redAccent.withOpacity(0.04),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.redAccent.withOpacity(0.15)),
        ),
        child: Column(
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
            const SizedBox(height: 16),
            Text(
              "TFLITE DETECTION FAILED",
              style: GoogleFonts.inter(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
                fontSize: 14,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _errorMessage!,
              style: GoogleFonts.inter(color: Colors.white70, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    if (_isScanning) {
      return Container(
        height: 400,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.01),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 50,
                height: 50,
                child: CircularProgressIndicator(color: Colors.cyanAccent, strokeWidth: 3),
              ),
              const SizedBox(height: 24),
              Text(
                "EXECUTING DEEP LEARNING MODEL INFERENCE",
                style: GoogleFonts.inter(
                  color: Colors.cyanAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "TFLite custom plate locator scanning image grids...",
                style: GoogleFonts.inter(color: Colors.white38, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    if (_confirmedJson == null) {
      return Container(
        height: 400,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.01),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.filter_center_focus, color: Colors.white24, size: 54),
              const SizedBox(height: 16),
              Text(
                "AWAITING DEEP LEARNING TARGET",
                style: GoogleFonts.inter(
                  color: Colors.white38,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40.0),
                child: Text(
                  "Upload a photo of a vehicle. The custom TFLite engine will detect, highlight, crop, and compile plate number payloads.",
                  style: GoogleFonts.inter(color: Colors.white24, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final confirmed = _confirmedJson!;
    final prettyJson = const JsonEncoder.withIndent('  ').convert(confirmed);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Top Diagnositic metric indicators
        Row(
          children: [
            Expanded(
              child: _buildDiagnosticMetric(
                "DETECTED TEXT",
                confirmed['license_plate'] as String? ?? 'N/A',
                Icons.directions_car,
                Colors.greenAccent,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildDiagnosticMetric(
                "CONFIDENCE SCORE",
                "${((confirmed['confidence'] as double? ?? 1.0) * 100).toStringAsFixed(1)}%",
                Icons.radar,
                Colors.cyanAccent,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildDiagnosticMetric(
                "BBOX MATRIX",
                "[x:${confirmed['bounding_box']['x']}, y:${confirmed['bounding_box']['y']}]",
                Icons.view_in_ar,
                Colors.orangeAccent,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Beautiful Interactive JSON Code Viewer
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0F1216),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.greenAccent.withOpacity(0.12)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 16,
                spreadRadius: 2,
              )
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Code Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.black38,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.04))),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(color: Colors.amberAccent, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(color: Colors.greenAccent, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 14),
                        Text(
                          'tflite_detection_payload.json',
                          style: GoogleFonts.robotoMono(
                            color: Colors.greenAccent,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy, color: Colors.greenAccent, size: 16),
                      tooltip: 'Copy JSON Payload',
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: prettyJson));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: Colors.teal.shade800,
                            content: Row(
                              children: [
                                const Icon(Icons.check, color: Colors.greenAccent),
                                const SizedBox(width: 12),
                                Text(
                                  'JSON Payload copied to clipboard!',
                                  style: GoogleFonts.inter(color: Colors.white),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              
              // Json highlights
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: _buildJsonHighlighter(prettyJson),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Verified double image card display
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.01),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.04)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'COMPILED FILE LEDGERS',
                style: GoogleFonts.inter(
                  color: Colors.cyanAccent,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              _buildFileLocationRow('Bounded Frame', confirmed['original_image_with_box'] as String),
              const SizedBox(height: 8),
              _buildFileLocationRow('Cropped Plate', confirmed['cropped_plate_image'] as String),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFileLocationRow(String label, String filePath) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black12,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.03)),
      ),
      child: Row(
        children: [
          const Icon(Icons.image_outlined, color: Colors.white30, size: 18),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: GoogleFonts.inter(color: Colors.cyanAccent, fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 1),
              ),
              const SizedBox(height: 2),
              Text(
                p.basename(filePath),
                style: GoogleFonts.robotoMono(color: Colors.white70, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDiagnosticMetric(String title, String val, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.01),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 14),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(color: Colors.white30, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            val,
            style: GoogleFonts.robotoMono(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildJsonHighlighter(String jsonText) {
    final List<TextSpan> spans = [];
    final RegExp regExp = RegExp(r'("(?:\\u[a-fA-F0-9]{4}|\\[^u]|[^\\"])*")(\s*:)?|(-?\d+(?:\.\d*)?(?:[eE][+-]?\d+)?)|(true|false)|(null)|([\{\}\[\]\,])');

    int lastMatchEnd = 0;
    
    jsonText.splitMapJoin(
      regExp,
      onMatch: (Match match) {
        // Add plain text between matches
        if (match.start > lastMatchEnd) {
          spans.add(TextSpan(text: jsonText.substring(lastMatchEnd, match.start), style: const TextStyle(color: Colors.white30)));
        }

        final String matchStr = match.group(0)!;

        if (match.group(1) != null) {
          // It is a string
          if (match.group(2) != null) {
            // It is a key
            spans.add(TextSpan(text: match.group(1), style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)));
            spans.add(TextSpan(text: match.group(2), style: const TextStyle(color: Colors.white70)));
          } else {
            // It is a string value
            spans.add(TextSpan(text: matchStr, style: const TextStyle(color: Colors.cyanAccent)));
          }
        } else if (match.group(3) != null) {
          // It is a number
          spans.add(TextSpan(text: matchStr, style: const TextStyle(color: Colors.orangeAccent)));
        } else if (match.group(4) != null) {
          // It is boolean
          spans.add(TextSpan(text: matchStr, style: const TextStyle(color: Colors.pinkAccent, fontWeight: FontWeight.bold)));
        } else if (match.group(5) != null) {
          // It is null
          spans.add(TextSpan(text: matchStr, style: const TextStyle(color: Colors.redAccent, fontStyle: FontStyle.italic)));
        } else if (match.group(6) != null) {
          // Structurals like brackets, braces, commas
          spans.add(TextSpan(text: matchStr, style: const TextStyle(color: Colors.amberAccent)));
        }

        lastMatchEnd = match.end;
        return matchStr;
      },
      onNonMatch: (String nonMatch) {
        if (lastMatchEnd < jsonText.length) {
          spans.add(TextSpan(text: jsonText.substring(lastMatchEnd), style: const TextStyle(color: Colors.white30)));
        }
        return nonMatch;
      },
    );

    return SelectableText.rich(
      TextSpan(
        style: GoogleFonts.robotoMono(fontSize: 12.5, height: 1.4),
        children: spans,
      ),
    );
  }

  Widget _buildSectionCard({String? title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.01),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null) ...[
            Text(
              title,
              style: GoogleFonts.inter(
                color: Colors.cyanAccent,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 16),
          ],
          child,
        ],
      ),
    );
  }
}
