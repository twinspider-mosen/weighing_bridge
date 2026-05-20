import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'ocr_service.dart';

class OcrScreen extends StatefulWidget {
  const OcrScreen({super.key});

  @override
  State<OcrScreen> createState() => _OcrScreenState();
}

class _OcrScreenState extends State<OcrScreen> with SingleTickerProviderStateMixin {
  final OcrService _ocrService = OcrService();

  String? _selectedImagePath;
  OcrResult? _ocrResult;
  bool _isScanning = false;
  String? _errorMessage;

  late AnimationController _scannerAnimationController;
  late Animation<double> _scannerValue;

  @override
  void initState() {
    super.initState();
    _ocrService.init().then((_) {
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
          _ocrResult = null;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Failed to pick file: $e";
      });
    }
  }

  Future<void> _runOcr() async {
    if (_selectedImagePath == null) return;

    setState(() {
      _isScanning = true;
      _ocrResult = null;
      _errorMessage = null;
    });
    _scannerAnimationController.repeat(reverse: true);

    try {
      final result = await _ocrService.scanImage(_selectedImagePath!);
      setState(() {
        _ocrResult = result;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst("Exception: ", "").replaceFirst("StateError: ", "");
      });
    } finally {
      setState(() {
        _isScanning = false;
      });
      _scannerAnimationController.stop();
      _scannerAnimationController.reset();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ocrService,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            backgroundColor: const Color(0xFF1A1F25),
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            title: Row(
              children: [
                const Icon(Icons.psychology, color: Colors.greenAccent),
                const SizedBox(width: 12),
                Text(
                  'AI OCR & TEXT RECOGNITION HUB',
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
                colors: [Color(0xFF1A1F25), Color(0xFF0A0E12)],
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
        // 1. Connection Toggle Card
        _buildSectionCard(
          child: SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            activeColor: Colors.greenAccent,
            activeTrackColor: Colors.greenAccent.withOpacity(0.3),
            inactiveThumbColor: Colors.white30,
            inactiveTrackColor: Colors.white10,
            secondary: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _ocrService.isConnected
                    ? Colors.greenAccent.withOpacity(0.08)
                    : Colors.white.withOpacity(0.04),
                shape: BoxShape.circle,
                border: Border.all(
                  color: _ocrService.isConnected
                      ? Colors.greenAccent.withOpacity(0.2)
                      : Colors.white.withOpacity(0.08),
                ),
              ),
              child: Icon(
                _ocrService.isConnected ? Icons.link : Icons.link_off,
                color: _ocrService.isConnected ? Colors.greenAccent : Colors.white54,
              ),
            ),
            title: Text(
              "Connect OCR to System",
              style: GoogleFonts.inter(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            subtitle: Text(
              _ocrService.isConnected
                  ? "OCR is connected globally. Dashboard snapshot capture will auto-trigger text parsing."
                  : "OCR is bypassed. Manual upload testing is still fully operational.",
              style: GoogleFonts.inter(color: Colors.white38, fontSize: 11),
            ),
            value: _ocrService.isConnected,
            onChanged: (val) => _ocrService.setConnectionState(val),
          ),
        ),
        const SizedBox(height: 16),

        // 2. Engine Selector Card
        _buildSectionCard(
          title: "OCR RECOGNITION ENGINE",
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                ),
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: [
                    _buildEngineTab(OcrEngineType.simulation, "Simulation", Icons.auto_awesome),
                    _buildEngineTab(OcrEngineType.tesseract, "Tesseract OCR", Icons.terminal),
                  ],
                ),
              ),
              if (_ocrService.activeEngine == OcrEngineType.tesseract) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blueAccent.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blueAccent.withOpacity(0.15)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.info_outline, color: Colors.blueAccent, size: 20),
                          const SizedBox(width: 10),
                          Text(
                            "TESSERACT OCR SETUP GUIDE",
                            style: GoogleFonts.inter(
                              color: Colors.blue.shade100,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        "Tesseract OCR runs entirely locally on your machine. To enable it on Windows desktop:",
                        style: GoogleFonts.inter(color: Colors.white70, fontSize: 12, height: 1.4),
                      ),
                      const SizedBox(height: 10),
                      _buildSetupStep("1", "Download and run the Windows Tesseract installer from the UB-Mannheim library."),
                      _buildSetupStep("2", "Add the installation path (usually C:\\Program Files\\Tesseract-OCR) to your system environment variables 'PATH'."),
                      _buildSetupStep("3", "Restart the Weighing Bridge app or console to register the environment change."),
                      const SizedBox(height: 8),
                      Text(
                        "Note: You can still use the Simulation engine above to test all scan workflows and UI animations without installing Tesseract.",
                        style: GoogleFonts.inter(color: Colors.white30, fontSize: 11, fontStyle: FontStyle.italic),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 3. Image Upload / Pick Card
        _buildSectionCard(
          title: "SOURCE SNAPSHOT IMAGE",
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
                            color: Colors.greenAccent.withOpacity(0.05),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.cloud_upload_outlined,
                            color: Colors.greenAccent,
                            size: 28,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          "Upload local snapshot image",
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
                                          color: Colors.greenAccent,
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.greenAccent.withOpacity(0.8),
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
                                        _ocrResult = null;
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
                          icon: const Icon(Icons.sync, size: 14, color: Colors.greenAccent),
                          label: Text(
                            "Change",
                            style: GoogleFonts.inter(color: Colors.greenAccent, fontSize: 12),
                          ),
                        )
                      ],
                    ),
                  ],
                ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _selectedImagePath == null || _isScanning ? null : _runOcr,
                icon: _isScanning
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2),
                      )
                    : const Icon(Icons.document_scanner_outlined, size: 18),
                label: Text(
                  _isScanning ? "RECOGNIZING TEXT..." : "SCAN SNAPSHOT NOW",
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.greenAccent.shade700,
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

  Widget _buildSetupStep(String stepNumber, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.blueAccent.withOpacity(0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              stepNumber,
              style: GoogleFonts.robotoMono(
                color: Colors.blueAccent,
                fontWeight: FontWeight.bold,
                fontSize: 10,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(color: Colors.white70, fontSize: 11.5, height: 1.3),
            ),
          ),
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
              "OCR SCAN FAILED",
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
                child: CircularProgressIndicator(color: Colors.greenAccent, strokeWidth: 3),
              ),
              const SizedBox(height: 24),
              Text(
                "SCANNING AND EXTRACTING STRUCTURED LABELS",
                style: GoogleFonts.inter(
                  color: Colors.greenAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Executing model-specific text classifiers...",
                style: GoogleFonts.inter(color: Colors.white38, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    if (_ocrResult == null) {
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
              const Icon(Icons.document_scanner, color: Colors.white24, size: 54),
              const SizedBox(height: 16),
              Text(
                "AWAITING INPUT SNAPSHOT",
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
                  "Upload a vehicle photo, scale dashboard image, or gate signboard to extract structured intelligence.",
                  style: GoogleFonts.inter(color: Colors.white24, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final result = _ocrResult!;
    final jsonStr = const JsonEncoder.withIndent('  ').convert(result.toJson());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _buildDiagnosticTile(
                "ENGINE USED",
                result.engineUsed,
                Icons.memory,
                Colors.cyanAccent,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildDiagnosticTile(
                "IMAGE QUALITY",
                result.isBlurry ? "BLURRY TEXT" : "CLEAR TEXT",
                result.isBlurry ? Icons.blur_on : Icons.blur_off,
                result.isBlurry ? Colors.orangeAccent : Colors.greenAccent,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildDiagnosticTile(
                "CONFIDENCE",
                "${(result.confidence * 100).toStringAsFixed(0)}%",
                Icons.check_circle_outline,
                result.confidence > 0.7
                    ? Colors.greenAccent
                    : (result.confidence > 0.4 ? Colors.orangeAccent : Colors.redAccent),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildGlassCard(
          title: "EXTRACTED LABELED STRUCTURES",
          child: result.labeledTexts.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: Text(
                    "No structured labeled keys (e.g. Number Plate, Sign Board) could be automatically parsed. Raw text remains fully scanned.",
                    style: GoogleFonts.inter(color: Colors.white38, fontSize: 13, height: 1.4),
                  ),
                )
              : Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: result.labeledTexts.entries.map((entry) {
                    final isNumberPlate = entry.key.toLowerCase().contains("plate");
                    final isBlurryAlert = entry.key.toLowerCase().contains("blurry") || entry.key.toLowerCase().contains("alert");
                    
                    Color cardAccentColor = Colors.blueAccent;
                    if (isNumberPlate) cardAccentColor = Colors.greenAccent;
                    if (isBlurryAlert) cardAccentColor = Colors.orangeAccent;

                    return Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: cardAccentColor.withOpacity(0.2)),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: cardAccentColor.withOpacity(0.08),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isNumberPlate ? Icons.directions_car : (isBlurryAlert ? Icons.warning_amber : Icons.label_outline),
                              color: cardAccentColor,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  entry.key.toUpperCase(),
                                  style: GoogleFonts.inter(
                                    color: Colors.white38,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  entry.value,
                                  style: GoogleFonts.robotoMono(
                                    color: isNumberPlate ? Colors.greenAccent : Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
        ),
        const SizedBox(height: 16),
        _buildGlassCard(
          title: "RAW TEXT TRANSCRIPT",
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.04)),
            ),
            child: Text(
              result.rawText,
              style: GoogleFonts.robotoMono(color: Colors.white70, fontSize: 13, height: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 16),
        _buildGlassCard(
          title: "RAW EXTRACTED JSON STRUCTURE",
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0F1216),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.greenAccent.withOpacity(0.1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.code, color: Colors.greenAccent, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          "ocr_result.json",
                          style: GoogleFonts.robotoMono(
                            color: Colors.greenAccent,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy, color: Colors.white38, size: 16),
                      tooltip: "Copy JSON",
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: jsonStr));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: Colors.teal.shade800,
                            content: Row(
                              children: [
                                const Icon(Icons.check_circle_outline, color: Colors.greenAccent, size: 16),
                                const SizedBox(width: 12),
                                Text(
                                  "JSON copied to clipboard!",
                                  style: GoogleFonts.inter(fontWeight: FontWeight.w500, color: Colors.white),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    )
                  ],
                ),
                const Divider(color: Colors.white12),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Text(
                    jsonStr,
                    style: GoogleFonts.robotoMono(color: Colors.lightGreenAccent.shade100, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDiagnosticTile(String title, String val, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.01),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
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
                  style: GoogleFonts.inter(
                    color: Colors.white38,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            val,
            style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildEngineTab(OcrEngineType type, String label, IconData icon) {
    final isSelected = _ocrService.activeEngine == type;
    return Expanded(
      child: InkWell(
        onTap: () => _ocrService.setEngineType(type),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? Colors.greenAccent.withOpacity(0.08) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? Colors.greenAccent.withOpacity(0.2) : Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.greenAccent : Colors.white38,
                size: 14,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.inter(
                  color: isSelected ? Colors.white : Colors.white38,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
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
                color: Colors.greenAccent,
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

  Widget _buildGlassCard({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.01),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 16,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              color: Colors.greenAccent,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}
