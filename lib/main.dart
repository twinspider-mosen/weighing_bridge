import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:media_kit/media_kit.dart';
import 'package:spider_weighbridge/firebase_options.dart';
import 'package:spider_weighbridge/services/anpr_service.dart';
import 'package:spider_weighbridge/services/logger_service.dart';
import 'package:spider_weighbridge/services/ocr_service.dart';
import 'package:spider_weighbridge/services/scale_service.dart';
import 'package:spider_weighbridge/services/session_service.dart';
import 'package:spider_weighbridge/views/auth/login_screen.dart';
import 'package:spider_weighbridge/views/weighing_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Allow google_fonts to fetch fonts at runtime since assets are not local.
  GoogleFonts.config.allowRuntimeFetching = true;

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: false,
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

class WeighingBridgeApp extends StatefulWidget {
  final bool hasSession;
  const WeighingBridgeApp({super.key, required this.hasSession});

  @override
  State<WeighingBridgeApp> createState() => _WeighingBridgeAppState();
}

class _WeighingBridgeAppState extends State<WeighingBridgeApp> {
  late final AppLifecycleListener _lifecycleListener;

  @override
  void initState() {
    super.initState();
    _lifecycleListener = AppLifecycleListener(
      onExitRequested: () async {
        try {
          ScaleService().dispose();
          AnprService().dispose();
        } catch (_) {}
        exit(0);
      },
    );
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    super.dispose();
  }

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
      home: widget.hasSession ? const WeighingScreen() : const LoginScreen(),
    );
  }
}
