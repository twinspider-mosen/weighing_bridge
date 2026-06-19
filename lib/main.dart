import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:media_kit/media_kit.dart';
import 'package:spider_weighbridge/firebase_options.dart';
import 'package:spider_weighbridge/services/logger_service.dart';
import 'package:spider_weighbridge/services/ocr_service.dart';
import 'package:spider_weighbridge/views/auth/login_screen.dart';
import 'package:spider_weighbridge/views/weighing_screen.dart';
import 'package:spider_weighbridge/services/session_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Allow google_fonts to fetch fonts at runtime since assets are not local.
  GoogleFonts.config.allowRuntimeFetching = true;

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
