import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:spider_weighbridge/components/action_button.dart';

class WeighingControlPanel extends StatelessWidget {
  final String? selectedPort;
  final List<String> ports;
  final bool isScanning;
  final bool isListening;
  final ValueChanged<String?> onPortChanged;
  final VoidCallback onRefreshPorts;
  final VoidCallback onStartScan;
  final VoidCallback onToggleListener;

  const WeighingControlPanel({
    super.key,
    required this.selectedPort,
    required this.ports,
    required this.isScanning,
    required this.isListening,
    required this.onPortChanged,
    required this.onRefreshPorts,
    required this.onStartScan,
    required this.onToggleListener,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = isListening
        ? Colors.greenAccent
        : isScanning
            ? Colors.amberAccent
            : Colors.white24;
    final statusLabel = isListening
        ? 'CONNECTED'
        : isScanning
            ? 'SCANNING…'
            : 'DISCONNECTED';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Status chip ───────────────────────────────────────────────────
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: statusColor,
                  boxShadow: [
                    BoxShadow(color: statusColor.withOpacity(0.6), blurRadius: 6),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                statusLabel,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                  color: statusColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // ── Port selector label ───────────────────────────────────────────
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
          // ── Port dropdown + refresh ───────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: selectedPort,
                    items: ports
                        .map(
                          (p) => DropdownMenuItem(
                            value: p,
                            child: Text(
                              p,
                              style: GoogleFonts.inter(fontSize: 14),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged:
                        isScanning || isListening ? null : onPortChanged,
                    dropdownColor: const Color(0xFF1A1F25),
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.refresh,
                  size: 18,
                  color: Colors.white38,
                ),
                onPressed:
                    isScanning || isListening ? null : onRefreshPorts,
                tooltip: 'Refresh Ports',
              ),
            ],
          ),
          const SizedBox(height: 20),
          // ── Action buttons ────────────────────────────────────────────────
          ActionButton(
            label: isScanning ? 'SCANNING...' : 'AUTO-SCAN',
            icon: Icons.search,
            color: Colors.blueAccent,
            isPrimary: false,
            onPressed: isListening || isScanning ? null : onStartScan,
          ),
          const SizedBox(height: 12),
          ActionButton(
            label: isListening ? 'STOP' : 'START',
            icon: isListening ? Icons.stop_rounded : Icons.play_arrow_rounded,
            color: isListening ? Colors.redAccent : Colors.greenAccent,
            onPressed: isScanning ? null : onToggleListener,
            isPrimary: true,
          ),
        ],
      ),
    );
  }
}
