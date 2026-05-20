import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Enum representing the active OCR engine type.
enum OcrEngineType {
  simulation,
  tesseract,
}

/// Structured response container for all OCR operations.
class OcrResult {
  final String rawText;
  final Map<String, String> labeledTexts;
  final bool isBlurry;
  final double confidence;
  final String engineUsed;

  OcrResult({
    required this.rawText,
    required this.labeledTexts,
    required this.isBlurry,
    required this.confidence,
    required this.engineUsed,
  });

  Map<String, dynamic> toJson() => {
        'raw_text': rawText,
        'labeled_texts': labeledTexts,
        'is_blurry': isBlurry,
        'confidence': confidence,
        'engine_used': engineUsed,
        'timestamp': DateTime.now().toIso8601String(),
      };

  factory OcrResult.fromJson(Map<String, dynamic> json) {
    return OcrResult(
      rawText: json['raw_text'] as String? ?? '',
      labeledTexts: Map<String, String>.from(json['labeled_texts'] as Map? ?? {}),
      isBlurry: json['is_blurry'] as bool? ?? false,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 1.0,
      engineUsed: json['engine_used'] as String? ?? 'Unknown',
    );
  }
}

/// Abstract contract that all concrete OCR engines must implement.
abstract class BaseOcrEngine {
  Future<OcrResult> processImage(String imagePath);
}

/// 1. Simulation OCR Engine
/// Highly detailed simulation for testing, running offline, or on unsupported desktop platforms.
class SimulationOcrEngine implements BaseOcrEngine {
  @override
  Future<OcrResult> processImage(String imagePath) async {
    // Artificial delay to simulate processing and laser scanning animation in UI
    await Future.delayed(const Duration(milliseconds: 1500));

    final filename = imagePath.toLowerCase();

    // Smart detection based on filename to make demo testing very predictable and cool
    if (filename.contains('plate') || filename.contains('car') || filename.contains('vehicle')) {
      return OcrResult(
        rawText: "WEIGHING BRIDGE AREA\nVEHICLE DEPARTURE\nNUMBER PLATE: ARB 1234\nSPEED LIMIT 20 KM/H",
        labeledTexts: {
          "Car Number Plate": "ARB 1234",
          "Sign Board": "SPEED LIMIT 20 KM/H",
          "Operational Zone": "WEIGHING BRIDGE DEPARTURE AREA",
        },
        isBlurry: false,
        confidence: 0.98,
        engineUsed: "Simulation Engine",
      );
    } else if (filename.contains('blurry') || filename.contains('blur') || filename.contains('dark')) {
      return OcrResult(
        rawText: "S1GN B0ARD: CL0S3D\nC4R NUMB3R: ??? 5678",
        labeledTexts: {
          "Sign Board": "CLOSED (PARTIALLY READ)",
          "Car Number Plate": "UNK-5678 (LOW CONFIDENCE)",
          "Image Quality Alert": "WARNING: Blurry or low-contrast text detected."
        },
        isBlurry: true,
        confidence: 0.38,
        engineUsed: "Simulation Engine",
      );
    } else if (filename.contains('board') || filename.contains('sign')) {
      return OcrResult(
        rawText: "STOP\nWEIGH BRIDGE 100M AHEAD\nMAX CAPACITY 60 TONS",
        labeledTexts: {
          "Sign Board": "STOP - WEIGH BRIDGE 100M AHEAD",
          "Capacity Instruction": "MAX CAPACITY 60 TONS",
        },
        isBlurry: false,
        confidence: 0.94,
        engineUsed: "Simulation Engine",
      );
    } else {
      // Default mock result
      return OcrResult(
        rawText: "ANTIGRAVITY INDUSTRIAL SYSTEM v2.0\nGATEWAY 4\nWEIGH VALUE STABLE\nTRUCK ID: TR-9981",
        labeledTexts: {
          "Sign Board": "ANTIGRAVITY INDUSTRIAL SYSTEM v2.0",
          "Truck Identifier": "TR-9981",
          "Operational Terminal": "GATEWAY 4",
        },
        isBlurry: false,
        confidence: 0.91,
        engineUsed: "Simulation Engine",
      );
    }
  }
}

/// 2. Native Tesseract OCR CLI Engine
/// Executes local Tesseract binary via CLI on host desktop system.
class TesseractOcrEngine implements BaseOcrEngine {
  @override
  Future<OcrResult> processImage(String imagePath) async {
    try {
      String executable = 'tesseract';
      bool useShell = true;
      if (Platform.isWindows) {
        final defaultPath = r'C:\Program Files\Tesseract-OCR\tesseract.exe';
        if (File(defaultPath).existsSync()) {
          executable = defaultPath;
          useShell = false;
        }
      }

      final result = await Process.run(
        executable,
        [imagePath, 'stdout', '-l', 'eng'],
        runInShell: useShell,
      );
      
      if (result.exitCode != 0) {
        throw Exception(
          "Tesseract execution failed with exit code ${result.exitCode}.\n"
          "Error: ${result.stderr}"
        );
      }
      
      final rawText = result.stdout.toString().trim();
      if (rawText.isEmpty) {
        return OcrResult(
          rawText: "No text recognized by Tesseract.",
          labeledTexts: {},
          isBlurry: false,
          confidence: 0.8,
          engineUsed: "Tesseract OCR (CLI)",
        );
      }
      
      // Parse labeled texts using smart heuristics
      final Map<String, String> labeledTexts = {};
      
      // Heuristic 1: Extract license plates (common patterns like AAA 1234, AA-123-AA, etc.)
      final plateRegex = RegExp(
        r'\b([A-Z]{2,3}[- ]?[0-9]{3,4}|[0-9]{2,4}[- ]?[A-Z]{2,3}|[A-Z]{1,2}[- ]?[0-9]{1,4}[- ]?[A-Z]{1,3})\b',
        caseSensitive: false,
      );
      final plateMatches = plateRegex.allMatches(rawText);
      if (plateMatches.isNotEmpty) {
        labeledTexts["Car Number Plate"] = plateMatches.first.group(0)!.toUpperCase();
      }

      // Heuristic 2: Look for typical Sign Board indicators
      final signboardIndicators = ["stop", "limit", "capacity", "bridge", "welcome", "gateway", "exit", "entry", "speed"];
      final lines = rawText.split('\n');
      final signBoardLines = <String>[];

      for (var line in lines) {
        final lowerLine = line.toLowerCase();
        if (signboardIndicators.any((indicator) => lowerLine.contains(indicator))) {
          signBoardLines.add(line.trim());
        }
      }

      if (signBoardLines.isNotEmpty) {
        labeledTexts["Sign Board"] = signBoardLines.join(" | ");
      } else if (lines.isNotEmpty && lines.first.trim().isNotEmpty) {
        labeledTexts["Sign Board"] = lines.first.trim();
      }

      // Blurry estimate based on character fragmentation
      final words = rawText.split(RegExp(r'\s+'));
      int shortWords = 0;
      int totalWords = words.length;
      for (var word in words) {
        if (word.length <= 1 && word.isNotEmpty) {
          shortWords++;
        }
      }
      
      bool isBlurry = false;
      double confidence = 0.85;
      
      if (totalWords > 0) {
        final fragmentRatio = shortWords / totalWords;
        if (fragmentRatio > 0.4 && totalWords > 3) {
          isBlurry = true;
          confidence = 0.40;
        }
      }

      return OcrResult(
        rawText: rawText,
        labeledTexts: labeledTexts,
        isBlurry: isBlurry,
        confidence: confidence,
        engineUsed: "Tesseract OCR (CLI)",
      );
    } catch (e) {
      if (e is ProcessException) {
        throw Exception(
          "Tesseract OCR executable was not found on your system PATH.\n\n"
          "Please verify that Tesseract is installed and configured:\n"
          "1. Download & Install Tesseract OCR for Windows (e.g. from UB-Mannheim).\n"
          "2. Add the installation directory (usually C:\\Program Files\\Tesseract-OCR) to your System Environment variables PATH.\n"
          "3. Restart the application/terminal for changes to take effect."
        );
      }
      rethrow;
    }
  }
}

/// Global Pluggable OCR Service Controller
class OcrService extends ChangeNotifier {
  static final OcrService _instance = OcrService._internal();
  factory OcrService() => _instance;
  OcrService._internal();

  static const String _keyOcrConnected = 'ocr_service_connected';
  static const String _keyOcrEngine = 'ocr_service_engine_type';

  bool _isConnected = false;
  OcrEngineType _activeEngine = OcrEngineType.simulation;
  bool _initialized = false;

  bool get isConnected => _isConnected;
  OcrEngineType get activeEngine => _activeEngine;

  /// Initializes the service settings from local storage.
  Future<void> init() async {
    if (_initialized) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      _isConnected = prefs.getBool(_keyOcrConnected) ?? false;
      
      final engineIndex = prefs.getInt(_keyOcrEngine) ?? OcrEngineType.simulation.index;
      if (engineIndex >= OcrEngineType.values.length) {
        _activeEngine = OcrEngineType.simulation;
      } else {
        _activeEngine = OcrEngineType.values[engineIndex];
      }
      
      _initialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint("Failed to initialize OCR settings: $e");
    }
  }

  /// Sets the global connection state of the OCR Service.
  Future<void> setConnectionState(bool connected) async {
    _isConnected = connected;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyOcrConnected, connected);
    notifyListeners();
  }

  /// Changes the active OCR scanning engine.
  Future<void> setEngineType(OcrEngineType type) async {
    _activeEngine = type;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyOcrEngine, type.index);
    notifyListeners();
  }

  /// Processes the given image path through the active engine.
  Future<OcrResult> scanImage(String imagePath) async {
    await init(); // Ensure loaded

    BaseOcrEngine engine;
    switch (_activeEngine) {
      case OcrEngineType.simulation:
        engine = SimulationOcrEngine();
        break;
      case OcrEngineType.tesseract:
        engine = TesseractOcrEngine();
        break;
    }

    return await engine.processImage(imagePath);
  }
}
