import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:weighing_bridge/components/action_button.dart';

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
                          value: selectedPort,
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
                          onChanged: isScanning || isListening ? null : onPortChanged,
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
                      onPressed: isScanning || isListening ? null : onRefreshPorts,
                      tooltip: 'Refresh Ports',
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 24),
          ActionButton(
            label: isScanning ? 'SCANNING...' : 'AUTO-SCAN',
            icon: Icons.search,
            color: Colors.blueAccent,
            isPrimary: false,
            onPressed: isListening || isScanning ? null : onStartScan,
          ),
          const SizedBox(width: 16),
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
