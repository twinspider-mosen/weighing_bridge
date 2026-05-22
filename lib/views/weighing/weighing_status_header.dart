import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class WeighingStatusHeader extends StatelessWidget {
  final bool isListening;
  final String status;

  const WeighingStatusHeader({
    super.key,
    required this.isListening,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = isListening ? Colors.greenAccent : Colors.redAccent;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('LIVE BRIDGE LOAD',
                style: GoogleFonts.inter(
                    fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 4, color: Colors.greenAccent.withOpacity(0.7))),
            Text('Weight Active', style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white)),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isListening ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: statusColor, width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: statusColor,
                  boxShadow: [BoxShadow(color: statusColor, blurRadius: 10, spreadRadius: 2)],
                ),
              ),
              const SizedBox(width: 12),
              Text(status.toUpperCase(),
                  style: GoogleFonts.inter(
                      fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1, color: statusColor)),
            ],
          ),
        ),
      ],
    );
  }
}
