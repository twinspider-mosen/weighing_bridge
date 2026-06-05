import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/tflite_detection_service.dart';

/// A highly polished, glassmorphic popup modal displaying detection results.
/// Allows the user to inspect the bounded original image, see the cropped plate,
/// edit the extracted plate number, and confirm to produce the final JSON.
class DetectionResultPopup extends StatefulWidget {
  final TfliteDetectionResult detectionResult;

  const DetectionResultPopup({
    super.key,
    required this.detectionResult,
  });

  @override
  State<DetectionResultPopup> createState() => _DetectionResultPopupState();
}

class _DetectionResultPopupState extends State<DetectionResultPopup> {
  late TextEditingController _plateTextController;

  @override
  void initState() {
    super.initState();
    _plateTextController = TextEditingController(text: widget.detectionResult.extractedText);
  }

  @override
  void dispose() {
    _plateTextController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 36.0),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 900, maxHeight: 680),
          decoration: BoxDecoration(
            color: const Color(0xFF161B21).withOpacity(0.95),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.cyanAccent.withOpacity(0.2)),
            boxShadow: [
              BoxShadow(
                color: Colors.cyanAccent.withOpacity(0.08),
                blurRadius: 32,
                spreadRadius: 4,
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.6),
                blurRadius: 24,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              _buildHeader(),
              
              // Body
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildImageComparison(),
                      const SizedBox(height: 24),
                      _buildExtractionEditor(),
                    ],
                  ),
                ),
              ),

              // Footer
              _buildFooter(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.black12,
        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.cyanAccent.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.filter_center_focus, color: Colors.cyanAccent, size: 22),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TFLITE PLATE DETECTION VISUALIZER',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Active Model: ${widget.detectionResult.modelUsed}',
                    style: GoogleFonts.inter(
                      color: Colors.cyanAccent.withOpacity(0.7),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.greenAccent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.greenAccent.withOpacity(0.2)),
            ),
            child: Text(
              '${(widget.detectionResult.confidence * 100).toStringAsFixed(1)}% CONFIDENCE',
              style: GoogleFonts.robotoMono(
                color: Colors.greenAccent,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageComparison() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useRow = constraints.maxWidth > 580;
        final images = [
          // Left: Bounded original
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildPanelTitle('ACTUAL VEHICLE IMAGE (WITH DETECTED BBOX)'),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    height: 240,
                    color: Colors.black38,
                    child: Image.file(
                      File(widget.detectionResult.originalWithBoxPath),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: useRow ? 18 : 0, height: useRow ? 0 : 20),
          // Right: Cropped license plate
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildPanelTitle('TFLITE CROPPED PLATE SEGMENT'),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    height: 240,
                    color: Colors.black54,
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          width: double.infinity,
                          height: 120,
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.cyanAccent.withOpacity(0.3), width: 2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Image.file(
                            File(widget.detectionResult.croppedPlatePath),
                            fit: BoxFit.contain,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Icon(Icons.zoom_in, color: Colors.white24, size: 20),
                        const SizedBox(height: 4),
                        Text(
                          'ROI Dimensions: ${(widget.detectionResult.width * 100).toStringAsFixed(0)}% x ${(widget.detectionResult.height * 100).toStringAsFixed(0)}%',
                          style: GoogleFonts.robotoMono(color: Colors.white30, fontSize: 10),
                        )
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ];

        return useRow
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: images,
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  images[0],
                  const SizedBox(height: 16),
                  images[2],
                ],
              );
      },
    );
  }

  Widget _buildExtractionEditor() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.04)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.edit_note, color: Colors.cyanAccent, size: 20),
              const SizedBox(width: 8),
              Text(
                'EXTRACTED LICENSE PLATE NUMBER',
                style: GoogleFonts.inter(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Confirm or edit the alphanumeric license plate characters below before adding to the system weight ledger.',
            style: GoogleFonts.inter(color: Colors.white38, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _plateTextController,
            style: GoogleFonts.robotoMono(
              color: Colors.greenAccent,
              fontSize: 22,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFF0F1216),
              prefixIcon: const Icon(Icons.directions_car, color: Colors.white38),
              hintText: 'e.g. ABC 1234',
              hintStyle: GoogleFonts.robotoMono(color: Colors.white12),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.greenAccent, width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
            textCapitalization: TextCapitalization.characters,
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.black12,
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            ),
            child: Text(
              'CANCEL SCAN',
              style: GoogleFonts.inter(
                color: Colors.white54,
                fontWeight: FontWeight.bold,
                fontSize: 12,
                letterSpacing: 1,
              ),
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: () {
              final confirmedText = _plateTextController.text.trim().toUpperCase();
              
              // Construct the JSON structure
              final resultJson = {
                'status': 'success',
                'timestamp': DateTime.now().toIso8601String(),
                'model_used': widget.detectionResult.modelUsed,
                'confidence': widget.detectionResult.confidence,
                'license_plate': confirmedText,
                'bounding_box': {
                  'x': double.parse(widget.detectionResult.x.toStringAsFixed(4)),
                  'y': double.parse(widget.detectionResult.y.toStringAsFixed(4)),
                  'width': double.parse(widget.detectionResult.width.toStringAsFixed(4)),
                  'height': double.parse(widget.detectionResult.height.toStringAsFixed(4)),
                },
                'original_image_path': widget.detectionResult.originalImagePath,
                'original_image_with_box': widget.detectionResult.originalWithBoxPath,
                'cropped_plate_image': widget.detectionResult.croppedPlatePath,
              };
              
              // Pop and return the confirmed JSON result
              Navigator.pop(context, resultJson);
            },
            icon: const Icon(Icons.check, size: 16),
            label: Text(
              'CONFIRM & SAVE DATA',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                letterSpacing: 1,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.cyanAccent.shade700,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPanelTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.inter(
        color: Colors.cyanAccent,
        fontSize: 10,
        fontWeight: FontWeight.bold,
        letterSpacing: 1,
      ),
    );
  }
}
