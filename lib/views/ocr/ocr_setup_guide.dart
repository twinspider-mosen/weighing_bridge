import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Tesseract OCR local installation setup guide card.
class OcrSetupGuide extends StatelessWidget {
  const OcrSetupGuide({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blueAccent.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blueAccent.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.info_outline, color: Colors.blueAccent, size: 20),
            const SizedBox(width: 10),
            Text(
              'TESSERACT OCR SETUP GUIDE',
              style: GoogleFonts.inter(
                color: Colors.blue.shade100,
                fontWeight: FontWeight.bold,
                fontSize: 12,
                letterSpacing: 1,
              ),
            ),
          ]),
          const SizedBox(height: 12),
          Text(
            'Tesseract OCR runs entirely locally on your machine. '
            'To enable it on Windows desktop:',
            style: GoogleFonts.inter(
                color: Colors.white70, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 10),
          _buildStep('1',
              'Download and run the Windows Tesseract installer from the UB-Mannheim library.'),
          _buildStep('2',
              "Add the installation path (usually C:\\Program Files\\Tesseract-OCR) to your system environment variables 'PATH'."),
          _buildStep('3',
              'Restart the Weighing Bridge app or console to register the environment change.'),
          const SizedBox(height: 8),
          Text(
            'Note: You can still use the Simulation engine above to test all '
            'scan workflows and UI animations without installing Tesseract.',
            style: GoogleFonts.inter(
              color: Colors.white30,
              fontSize: 11,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep(String stepNumber, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.blueAccent.withOpacity(0.2),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(stepNumber,
              style: GoogleFonts.robotoMono(
                  color: Colors.blueAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 10)),
        ),
        const SizedBox(width: 8),
        Expanded(
            child: Text(text,
                style: GoogleFonts.inter(
                    color: Colors.white70, fontSize: 11.5, height: 1.3))),
      ]),
    );
  }
}
