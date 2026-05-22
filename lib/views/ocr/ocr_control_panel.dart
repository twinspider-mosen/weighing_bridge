import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path/path.dart' as p;
import 'package:weighing_bridge/services/ocr_service.dart';
import 'ocr_setup_guide.dart';
import 'ocr_shared_widgets.dart';

/// Left-hand control panel for the OCR screen: connection toggle,
/// engine selector, and image picker with scan button.
class OcrControlPanel extends StatelessWidget {
  final OcrService ocrService;
  final String? selectedImagePath;
  final bool isScanning;
  final AnimationController scannerAnimationController;
  final Animation<double> scannerValue;
  final VoidCallback onPickImage;
  final VoidCallback onClearImage;
  final VoidCallback onRunOcr;

  const OcrControlPanel({
    super.key,
    required this.ocrService,
    required this.selectedImagePath,
    required this.isScanning,
    required this.scannerAnimationController,
    required this.scannerValue,
    required this.onPickImage,
    required this.onClearImage,
    required this.onRunOcr,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        buildSectionCard(child: _buildConnectionToggle()),
        const SizedBox(height: 16),
        buildSectionCard(
            title: 'OCR RECOGNITION ENGINE',
            child: _buildEngineSelector()),
        const SizedBox(height: 16),
        buildSectionCard(
            title: 'SOURCE SNAPSHOT IMAGE',
            child: _buildImageSection()),
      ],
    );
  }

  Widget _buildConnectionToggle() {
    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      activeColor: Colors.greenAccent,
      activeTrackColor: Colors.greenAccent.withOpacity(0.3),
      inactiveThumbColor: Colors.white30,
      inactiveTrackColor: Colors.white10,
      secondary: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: ocrService.isConnected
              ? Colors.greenAccent.withOpacity(0.08)
              : Colors.white.withOpacity(0.04),
          shape: BoxShape.circle,
          border: Border.all(
            color: ocrService.isConnected
                ? Colors.greenAccent.withOpacity(0.2)
                : Colors.white.withOpacity(0.08),
          ),
        ),
        child: Icon(
          ocrService.isConnected ? Icons.link : Icons.link_off,
          color: ocrService.isConnected ? Colors.greenAccent : Colors.white54,
        ),
      ),
      title: Text('Connect OCR to System',
          style: GoogleFonts.inter(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
      subtitle: Text(
        ocrService.isConnected
            ? 'OCR is connected globally. Dashboard snapshot capture will auto-trigger text parsing.'
            : 'OCR is bypassed. Manual upload testing is still fully operational.',
        style: GoogleFonts.inter(color: Colors.white38, fontSize: 11),
      ),
      value: ocrService.isConnected,
      onChanged: (val) => ocrService.setConnectionState(val),
    );
  }

  Widget _buildEngineSelector() {
    return Column(
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
          child: Row(children: [
            _buildEngineTab(
                OcrEngineType.simulation, 'Simulation', Icons.auto_awesome),
            _buildEngineTab(
                OcrEngineType.tesseract, 'Tesseract OCR', Icons.terminal),
          ]),
        ),
        if (ocrService.activeEngine == OcrEngineType.tesseract) ...[
          const SizedBox(height: 16),
          const OcrSetupGuide(),
        ],
      ],
    );
  }

  Widget _buildEngineTab(OcrEngineType type, String label, IconData icon) {
    final isSelected = ocrService.activeEngine == type;
    return Expanded(
      child: InkWell(
        onTap: () => ocrService.setEngineType(type),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? Colors.greenAccent.withOpacity(0.08)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? Colors.greenAccent.withOpacity(0.2)
                  : Colors.transparent,
            ),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon,
                color: isSelected ? Colors.greenAccent : Colors.white38,
                size: 14),
            const SizedBox(width: 6),
            Text(label,
                style: GoogleFonts.inter(
                    color: isSelected ? Colors.white : Colors.white38,
                    fontWeight: FontWeight.bold,
                    fontSize: 11)),
          ]),
        ),
      ),
    );
  }

  Widget _buildImageSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        selectedImagePath == null
            ? _buildImageDropZone()
            : _buildSelectedImagePreview(),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed:
              selectedImagePath == null || isScanning ? null : onRunOcr,
          icon: isScanning
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      color: Colors.black, strokeWidth: 2))
              : const Icon(Icons.document_scanner_outlined, size: 18),
          label: Text(
            isScanning ? 'RECOGNIZING TEXT...' : 'SCAN SNAPSHOT NOW',
            style: GoogleFonts.inter(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                letterSpacing: 1),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.greenAccent.shade700,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 18),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            elevation: 4,
          ),
        ),
      ],
    );
  }

  Widget _buildImageDropZone() {
    return InkWell(
      onTap: onPickImage,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 180,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.01),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.greenAccent.withOpacity(0.05),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.cloud_upload_outlined,
                color: Colors.greenAccent, size: 28),
          ),
          const SizedBox(height: 12),
          Text('Upload local snapshot image',
              style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('PNG, JPG, JPEG supported',
              style: GoogleFonts.inter(color: Colors.white38, fontSize: 11)),
        ]),
      ),
    );
  }

  Widget _buildSelectedImagePreview() {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Stack(alignment: Alignment.center, children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            height: 180,
            width: double.infinity,
            color: Colors.black54,
            child: Image.file(File(selectedImagePath!), fit: BoxFit.cover),
          ),
        ),
        if (isScanning)
          Positioned.fill(
            child: AnimatedBuilder(
              animation: scannerAnimationController,
              builder: (context, child) => Stack(children: [
                Positioned(
                  top: 180 * scannerValue.value - 2,
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
                        )
                      ],
                    ),
                  ),
                ),
                Container(color: Colors.black.withOpacity(0.15)),
              ]),
            ),
          ),
        Positioned(
          top: 8,
          right: 8,
          child: CircleAvatar(
            backgroundColor: Colors.black.withOpacity(0.6),
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 18),
              onPressed: isScanning ? null : onClearImage,
            ),
          ),
        ),
      ]),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(
          child: Text(p.basename(selectedImagePath!),
              style:
                  GoogleFonts.robotoMono(color: Colors.white54, fontSize: 11),
              overflow: TextOverflow.ellipsis),
        ),
        TextButton.icon(
          onPressed: isScanning ? null : onPickImage,
          icon: const Icon(Icons.sync, size: 14, color: Colors.greenAccent),
          label: Text('Change',
              style:
                  GoogleFonts.inter(color: Colors.greenAccent, fontSize: 12)),
        ),
      ]),
    ]);
  }
}
