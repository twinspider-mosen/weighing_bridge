import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:weighing_bridge/services/scale_service.dart';

class WeightDisplayCard extends StatelessWidget {
  final String currentWeight;
  final String unit;
  final ScaleConfig? activeConfig;

  const WeightDisplayCard({
    super.key,
    required this.currentWeight,
    required this.unit,
    required this.activeConfig,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 40),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.4),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
              boxShadow: [
                BoxShadow(
                  color: Colors.greenAccent.withOpacity(0.05),
                  blurRadius: 50,
                  spreadRadius: 10,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  currentWeight,
                  style: GoogleFonts.robotoMono(
                    fontSize: 110,
                    fontWeight: FontWeight.w500,
                    color: Colors.greenAccent,
                    shadows: [
                      Shadow(
                        color: Colors.greenAccent.withOpacity(0.5),
                        blurRadius: 20,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                Text(
                  unit,
                  style: GoogleFonts.inter(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: Colors.white.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ),
          if (activeConfig != null)
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: Text(
                'SIGNAL: ${activeConfig.toString()}',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  letterSpacing: 2,
                  color: Colors.white24,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
