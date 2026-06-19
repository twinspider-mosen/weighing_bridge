import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path/path.dart' as p;
import '../services/api_service.dart';
import '../services/logger_service.dart';
import '../services/ocr_service.dart';

/// Helper function to show the decoupled Upload Dialog.
/// Can be easily attached or detached from any snapshot capture point.
Future<void> showUploadDialog({
  required BuildContext context,
  String? frontImagePath,
  String? backImagePath,
  required String currentWeight,
  required String requestID,
  required String scaleName,
  required String subdomain,
  required String recordType,
  required String scaleStockId,
  required String recordStage,
  required String moduleType,
}) async {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return UploadDialog(
        frontImagePath: frontImagePath,
        backImagePath: backImagePath,
        currentWeight: currentWeight,
        requestID: requestID,
        scaleName: scaleName,
        scaleStockId: scaleStockId,
        recordType: recordType,
        subdomain: subdomain,
        recordStage: recordStage,
        moduleType: moduleType,
      );
    },
  );
}

class UploadDialog extends StatefulWidget {
  final String? frontImagePath;
  final String? backImagePath;
  final String currentWeight;
  final String requestID;
  final String scaleName;
  final String scaleStockId;
  final String recordType;
  final String subdomain;
  final String recordStage;
  final String moduleType;

  const UploadDialog({
    super.key,
    this.frontImagePath,
    this.backImagePath,
    required this.currentWeight,
    required this.requestID,
    required this.scaleName,
    required this.scaleStockId,
    required this.recordType,
    required this.subdomain,
    required this.recordStage,
    required this.moduleType,
  });

  @override
  State<UploadDialog> createState() => _UploadDialogState();
}

class _UploadDialogState extends State<UploadDialog> {
  final ApiService _apiService = ApiService();
  final _formKey = GlobalKey<FormState>();

  bool _isUploading = false;
  String? _errorMessage;

  bool _isOcrRunning = false;
  OcrResult? _ocrResult;
  String? _ocrError;

  @override
  void initState() {
    super.initState();
    // Dynamically initialize selectedDomain to the first available option in the domain list.
    // This safely avoids Flutter DropdownButton AssertionErrors when modifying list items.

    if (OcrService().isConnected) {
      _runBackgroundOcr();
    }
  }

  void _runBackgroundOcr() async {
    final ocrPath = widget.frontImagePath ?? widget.backImagePath;
    if (ocrPath == null) return;

    setState(() {
      _isOcrRunning = true;
      _ocrError = null;
    });

    try {
      final result = await OcrService().scanImage(ocrPath);

      await LoggerService().log(
        "Background OCR complete. Raw text: '${result.rawText.replaceAll('\n', ' ')}'. "
        "Labeled: ${result.labeledTexts}. Engine: ${result.engineUsed}.",
      );

      if (mounted) {
        setState(() {
          _ocrResult = result;
          // Pre-fill the subdomain text field with the detected license plate (cleaned for URL compatibility)
          if (result.labeledTexts.containsKey("Car Number Plate")) {
            final rawPlate = result.labeledTexts["Car Number Plate"]!;
            // Strip out non-alphanumeric characters
            final cleanPlate = rawPlate
                .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '')
                .toLowerCase();
            if (cleanPlate.isNotEmpty) {
              // vehicle number plate will be handled here
            }
          }
        });
      }
    } catch (e) {
      await LoggerService().log("Background OCR failed", e);
      if (mounted) {
        setState(() {
          _ocrError = e
              .toString()
              .replaceFirst("Exception: ", "")
              .replaceFirst("StateError: ", "");
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isOcrRunning = false;
        });
      }
    }
  }

  Future<void> _handleUpload() async {
    // if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isUploading = true;
      _errorMessage = null;
    });

    try {
      var response = await _apiService.uploadScreenshot(
        requestID: widget.requestID,
        subdomain: widget.subdomain,
        weight: widget.currentWeight,
        frontImagePath: widget.frontImagePath,
        backImagePath: widget.backImagePath,
        scaleName: widget.scaleName,
        recordType: widget.recordType,
        scaleStockId: widget.scaleStockId,
        recordStage: widget.recordStage,
        moduleType: widget.moduleType,
      );
      // if (response.data != null) {
      print("response = = = = => ${response}");
      LoggerService().log("Response: $response");

      print("response Data = = = = => ${response.data}");
      LoggerService().log("Response Data: ${response.data}");
      // }
      if (mounted) {
        Navigator.of(context).pop(); // Close dialog on success
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.green.shade800,
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "Snapshot and weight uploaded successfully!}",
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isUploading = false;
        _errorMessage = e.toString().replaceFirst("Exception: ", "");
      });
    }
  }

  Widget _buildImagePreview({required String path, required String label}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 130,
        decoration: BoxDecoration(
          color: Colors.black,
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.file(File(path), fit: BoxFit.cover),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withOpacity(0.75)],
                ),
              ),
            ),
            Positioned(
              bottom: 8,
              left: 8,
              right: 8,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.greenAccent.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: Colors.greenAccent.withOpacity(0.4),
                      ),
                    ),
                    child: Text(
                      label,
                      style: GoogleFonts.inter(
                        color: Colors.greenAccent,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      p.basename(path),
                      style: GoogleFonts.inter(
                        color: Colors.white54,
                        fontSize: 9,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1A1F25),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      elevation: 16,
      child: Container(
        width: 480,
        padding: const EdgeInsets.all(28),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Dialog Title and Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.greenAccent.withOpacity(0.08),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.greenAccent.withOpacity(0.2),
                        ),
                      ),
                      child: const Icon(
                        Icons.cloud_upload_outlined,
                        color: Colors.greenAccent,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        "Upload Snapshot",
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Snapshot preview thumbnails
                Row(
                  children: [
                    // Front image
                    if (widget.frontImagePath != null)
                      Expanded(
                        child: _buildImagePreview(
                          path: widget.frontImagePath!,
                          label: 'FRONT',
                        ),
                      ),
                    if (widget.frontImagePath != null && widget.backImagePath != null)
                      const SizedBox(width: 8),
                    if (widget.backImagePath != null)
                      Expanded(
                        child: _buildImagePreview(
                          path: widget.backImagePath!,
                          label: 'BACK',
                        ),
                      ),
                    if (widget.frontImagePath == null && widget.backImagePath == null)
                      Expanded(
                        child: Container(
                          height: 130,
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white.withOpacity(0.05)),
                          ),
                          child: Center(
                            child: Text(
                              "No images captured",
                              style: GoogleFonts.inter(color: Colors.white38, fontSize: 12),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 20),

                // Weight information strip
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.02),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.05)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.scale_outlined,
                        color: Colors.greenAccent,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        "RECORDED WEIGHT:",
                        style: GoogleFonts.inter(
                          color: Colors.white38,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.currentWeight,
                          style: GoogleFonts.robotoMono(
                            color: Colors.greenAccent,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.end,
                        ),
                      ),
                    ],
                  ),
                ),
                if (OcrService().isConnected) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.greenAccent.withOpacity(0.02),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.greenAccent.withOpacity(0.1),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.psychology_outlined,
                              color: Colors.greenAccent,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "AUTOMATIC AI OCR SCAN",
                              style: GoogleFonts.inter(
                                color: Colors.greenAccent,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                              ),
                            ),
                            const Spacer(),
                            if (_isOcrRunning)
                              const SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(
                                  color: Colors.greenAccent,
                                  strokeWidth: 1.5,
                                ),
                              )
                            else
                              Text(
                                "COMPLETED",
                                style: GoogleFonts.inter(
                                  color: Colors.white38,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                          ],
                        ),
                        if (_isOcrRunning) ...[
                          const SizedBox(height: 12),
                          const LinearProgressIndicator(
                            color: Colors.greenAccent,
                            backgroundColor: Colors.white10,
                            minHeight: 2,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Extracting structured vehicle details...",
                            style: GoogleFonts.inter(
                              color: Colors.white38,
                              fontSize: 11,
                            ),
                          ),
                        ] else if (_ocrError != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            "OCR Error: $_ocrError",
                            style: GoogleFonts.inter(
                              color: Colors.redAccent.shade100,
                              fontSize: 11,
                            ),
                          ),
                        ] else if (_ocrResult != null) ...[
                          const SizedBox(height: 12),
                          if (_ocrResult!.isBlurry) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              margin: const EdgeInsets.only(bottom: 10),
                              decoration: BoxDecoration(
                                color: Colors.orangeAccent.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: Colors.orangeAccent.withOpacity(0.2),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.blur_on,
                                    color: Colors.orangeAccent,
                                    size: 14,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      "BLURRY/HAZY TEXT DETECTED",
                                      style: GoogleFonts.inter(
                                        color: Colors.orangeAccent,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          if (_ocrResult!.labeledTexts.isEmpty)
                            Text(
                              "No structured vehicle details recognized.",
                              style: GoogleFonts.inter(
                                color: Colors.white38,
                                fontSize: 11,
                                fontStyle: FontStyle.italic,
                              ),
                            )
                          else
                            Column(
                              children: _ocrResult!.labeledTexts.entries.map((
                                entry,
                              ) {
                                final isPlate = entry.key
                                    .toLowerCase()
                                    .contains("plate");
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 6.0),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        entry.key.toUpperCase(),
                                        style: GoogleFonts.inter(
                                          color: Colors.white38,
                                          fontSize: 10,
                                        ),
                                      ),
                                      Text(
                                        entry.value,
                                        style: GoogleFonts.robotoMono(
                                          color: isPlate
                                              ? Colors.greenAccent
                                              : Colors.white70,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                        ],
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),

                // Input fields
                Text(
                  "DESTINATION ADDRESS",
                  style: GoogleFonts.inter(
                    color: Colors.white38,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 10),

                // Error message banner
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.redAccent.withOpacity(0.2),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Colors.redAccent,
                          size: 16,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            "Upload failed: $_errorMessage",
                            style: GoogleFonts.inter(
                              color: Colors.redAccent.shade100,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Action buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isUploading
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        child: Text(
                          "CANCEL",
                          style: GoogleFonts.inter(
                            color: Colors.white54,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _isUploading ? null : _handleUpload,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.greenAccent.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 4,
                      ),
                      child: _isUploading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              "UPLOAD NOW",
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
