import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CameraZoomControls extends StatelessWidget {
  final double currentCameraZoom;
  final VoidCallback? onZoomIn;
  final VoidCallback? onZoomOut;
  final VoidCallback? onResetZoom;

  const CameraZoomControls({
    super.key,
    required this.currentCameraZoom,
    this.onZoomIn,
    this.onZoomOut,
    this.onResetZoom,
  });

  @override
  Widget build(BuildContext context) {
    final zoomOutEnabled = currentCameraZoom > 1.01;
    final zoomInEnabled = currentCameraZoom < 9.99;

    return Container(
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
              onTap: zoomOutEnabled ? onZoomOut : null,
              child: Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: zoomOutEnabled
                      ? Colors.greenAccent.withOpacity(0.08)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.zoom_out_rounded,
                  size: 20,
                  color: zoomOutEnabled ? Colors.greenAccent : Colors.white24,
                ),
              ),
            ),
          ),

          // Zoom level badge
          Container(
            width: 44,
            alignment: Alignment.center,
            child: Text(
              '${currentCameraZoom.toStringAsFixed(1)}x',
              style: GoogleFonts.inter(
                color: zoomOutEnabled ? Colors.greenAccent : Colors.white54,
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
              onTap: zoomInEnabled ? onZoomIn : null,
              child: Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: zoomInEnabled
                      ? Colors.greenAccent.withOpacity(0.08)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.zoom_in_rounded,
                  size: 20,
                  color: zoomInEnabled ? Colors.greenAccent : Colors.white24,
                ),
              ),
            ),
          ),

          // Reset (only visible when zoomed in)
          if (zoomOutEnabled) ...[
            const SizedBox(width: 4),
            Tooltip(
              message: 'Reset Zoom',
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: onResetZoom,
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
    );
  }
}
