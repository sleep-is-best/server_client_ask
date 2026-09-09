import 'package:flutter/material.dart';

class AppColors {
  // Primary Colors
  static const Color primary = Color(0xFF4F7CAC);
  static const Color primaryDark = Color(0xFF315A7D);
  
  // Secondary & Accent
  static const Color secondary = Color(0xFF76A89A);
  static const Color accent = Color(0xFFE8C76A);
  
  // Background & Surfaces
  static const Color background = Color(0xFFF5F8FA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color card = Color(0xFFFFFFFF);
  
  // Text Colors
  static const Color textPrimary = Color(0xFF263746);
  static const Color textSecondary = Color(0xFF71808D);
  static const Color textHint = Color(0xFFA5B1BC);
  
  // Interaction & Feedback
  static const Color border = Color(0x224F7CAC); // Subtle border
  static const Color divider = Color(0xFFDCE4E8);
  static const Color success = Color(0xFF72A98B);
  static const Color warning = Color(0xFFD9A35F);
  static const Color error = Color(0xFFD32F2F);
  
  // Shadow
  static List<BoxShadow> softShadow = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.04),
      blurRadius: 10,
      offset: const Offset(0, 4),
    ),
  ];
}
