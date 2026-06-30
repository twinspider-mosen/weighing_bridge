import 'dart:math';
import 'package:flutter/material.dart';

class WeighingLayoutHelper {
  final BuildContext context;
  late final Size screenSize;
  late final double textScaleFactor;

  WeighingLayoutHelper(this.context) {
    screenSize = MediaQuery.of(context).size;
    textScaleFactor = MediaQuery.of(context).textScaleFactor;
  }

  // Adjust baseline scales for smaller desktop screens (e.g. 1366x768 or smaller)
  bool get isCompact => screenSize.height < 800 || screenSize.width < 1200;

  double get scaleFactor {
    // Reference size: 1920x1080
    double widthScale = screenSize.width / 1920;
    double heightScale = screenSize.height / 1080;
    return min(1.0, min(widthScale, heightScale)).clamp(0.75, 1.0);
  }

  double scale(double base) {
    return base * scaleFactor;
  }

  double fontSize(double base) {
    return (base * scaleFactor) / textScaleFactor;
  }

  double get padding => isCompact ? 14.0 : 20.0;
  double get gap => isCompact ? 8.0 : 16.0;
  double get cardGap => isCompact ? 12.0 : 24.0;
}
