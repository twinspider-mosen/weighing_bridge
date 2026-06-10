import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:media_kit/media_kit.dart';
import 'package:weighing_bridge/firebase_options.dart';
import 'package:weighing_bridge/services/logger_service.dart';
import 'package:weighing_bridge/services/ocr_service.dart';
import 'package:weighing_bridge/views/auth/login_screen.dart';
import 'package:weighing_bridge/views/weighing_screen.dart';
import 'package:weighing_bridge/services/session_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Prevent google_fonts from downloading fonts at runtime.
  // Without this, the app crashes on systems without internet access.
  GoogleFonts.config.allowRuntimeFetching = false;

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase initialization failed: $e');
  }

  try {
    MediaKit.ensureInitialized();
  } catch (e) {
    debugPrint('MediaKit initialization failed: $e');
  }

  await LoggerService().init();
  await OcrService().init();
  final bool hasSession = await SessionService.hasActiveSession();
  runApp(WeighingBridgeApp(hasSession: hasSession));
}

class WeighingBridgeApp extends StatelessWidget {
  final bool hasSession;
  const WeighingBridgeApp({super.key, required this.hasSession});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Industrial Weighing Bridge',
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.green,
        scaffoldBackgroundColor: const Color(0xFF0A0E12),
        useMaterial3: true,
      ),
      home: hasSession ? const WeighingScreen() : const LoginScreen(),
    );
  }
}
