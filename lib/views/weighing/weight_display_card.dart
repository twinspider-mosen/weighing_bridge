import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:spider_weighbridge/services/scale_service.dart';
import 'weighing_layout_helper.dart';

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
    final layout = WeighingLayoutHelper(context);
    final double horizontalPadding = layout.isCompact ? 24.0 : 48.0;
    final double verticalPadding = layout.isCompact ? 20.0 : 32.0;
    final double weightFontSize = layout.isCompact ? 56.0 : 96.0;
    final double unitFontSize = layout.isCompact ? 20.0 : 32.0;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: verticalPadding,
            ),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.4),
              borderRadius: BorderRadius.circular(layout.isCompact ? 16 : 24),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
              boxShadow: [
                BoxShadow(
                  color: Colors.greenAccent.withOpacity(0.05),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Flexible(
                  child: Text(
                    currentWeight,
                    style: GoogleFonts.robotoMono(
                      fontSize: weightFontSize,
                      fontWeight: FontWeight.w500,
                      color: Colors.greenAccent,
                      shadows: [
                        Shadow(
                          color: Colors.greenAccent.withOpacity(0.5),
                          blurRadius: 15,
                        ),
                      ],
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                SizedBox(width: layout.isCompact ? 8.0 : 16.0),
                Text(
                  unit,
                  style: GoogleFonts.inter(
                    fontSize: unitFontSize,
                    fontWeight: FontWeight.bold,
                    color: Colors.white.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ),
          if (activeConfig != null)
            Padding(
              padding: EdgeInsets.only(top: layout.isCompact ? 12 : 20),
              child: Text(
                'SIGNAL: ${activeConfig.toString()}',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  letterSpacing: 1.5,
                  color: Colors.white24,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
