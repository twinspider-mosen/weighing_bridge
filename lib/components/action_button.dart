import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ActionButton extends StatelessWidget {
   final String label;
    final IconData? icon;
    final Color color;
    final VoidCallback? onPressed;
   final bool isPrimary;
  const ActionButton({super.key, required this.label,  this.icon, required this.color, this.onPressed, required this.isPrimary,  });

  @override
  Widget build(
   BuildContext context
  ) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: icon !=null?Icon(icon, size: 20):null,
      label: Text(
        label,
        style: GoogleFonts.inter(fontWeight: FontWeight.bold, letterSpacing: 1),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: isPrimary ? color : color.withOpacity(0.1),
        foregroundColor: isPrimary ? Colors.black : color,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: isPrimary
              ? BorderSide.none
              : BorderSide(color: color.withOpacity(0.3)),
        ),
        elevation: isPrimary ? 8 : 0,
        shadowColor: color.withOpacity(0.4),
      ),
    );
  }
}

