import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:spider_weighbridge/utils/constants.dart';
import 'camera_service.dart';
import 'logger_service.dart';

/// Structured result returned by ANPR capture operations.
class AnprResult {
  final bool success;
  final String? vehicleImagePath;
  final String? plateImagePath;
  final String? plateNumber;
  final Map<String, dynamic>? anprResponse;
  final String? error;

  AnprResult({
    required this.success,
    this.vehicleImagePath,
    this.plateImagePath,
    this.plateNumber,
    this.anprResponse,
    this.error,
  });

  static AnprResult empty({String? error}) =>
      AnprResult(success: false, error: error);
}

/// Helper for HTTP Digest Authentication (RFC 2617).
class DahuaDigestAuth {
  static String computeAuthorizationHeader({
    required String method,
    required String uri,
    required String username,
    required String password,
    required String wwwAuthenticateHeader,
  }) {
    final Map<String, String> params = {};
    final regex = RegExp(r'(\w+)="?([^",]+)"?');
    for (final match in regex.allMatches(wwwAuthenticateHeader)) {
      final key = match.group(1)?.toLowerCase() ?? '';
      final val = match.group(2) ?? '';
      if (key.isNotEmpty) {
        params[key] = val;
      }
    }

    final realm = params['realm'] ?? '';
    final nonce = params['nonce'] ?? '';
    final qop = params['qop'];
    final opaque = params['opaque'];

    final ha1 = md5.convert(utf8.encode('$username:$realm:$password')).toString();
    final ha2 = md5.convert(utf8.encode('$method:$uri')).toString();

    String header;
    if (qop != null && qop.toLowerCase().contains('auth')) {
      final nc = '00000001';
      final cnonce = DateTime.now().millisecondsSinceEpoch.toRadixString(16);
      final response = md5
          .convert(utf8.encode('$ha1:$nonce:$nc:$cnonce:auth:$ha2'))
          .toString();

      header =
          'Digest username="$username", realm="$realm", nonce="$nonce", uri="$uri", response="$response", qop=auth, nc=$nc, cnonce="$cnonce"';
    } else {
      final response = md5.convert(utf8.encode('$ha1:$nonce:$ha2')).toString();
      header =
          'Digest username="$username", realm="$realm", nonce="$nonce", uri="$uri", response="$response"';
    }

    if (opaque != null && opaque.isNotEmpty) {
      header += ', opaque="$opaque"';
    }

    return header;
  }
}

/// Standalone Flutter service that connects to Dahua ANPR IP cameras,
/// listens for real-time TrafficJunction plate recognition events,
/// and extracts vehicle scene image, cropped plate image, and plate number JSON.
class AnprService {
  static final AnprService _instance = AnprService._internal();
  factory AnprService() => _instance;
  AnprService._internal();

  /// Resolves the camera IP address from the CameraConfig.
  /// Does NOT use a default hardcoded IP — strictly requires the configured camera's IP.
  static String? resolveCameraIp(CameraConfig? config) {
    if (config == null) return null;
    if (config.ipAddress.trim().isNotEmpty) {
      return config.ipAddress.trim();
    }
    if (config.rtspUrl.trim().isNotEmpty) {
      try {
        final uri = Uri.parse(config.rtspUrl.trim());
        if (uri.host.isNotEmpty) {
          return uri.host;
        }
      } catch (_) {}
    }
    return null;
  }

  /// Captures a direct native high-resolution snapshot from Dahua/Hikvision camera HTTP API (/cgi-bin/snapshot.cgi).
  Future<String?> captureNativeSnapshot({
    required CameraConfig cameraConfig,
    Directory? outputDirectory,
  }) async {
    final ip = resolveCameraIp(cameraConfig);
    if (ip == null || ip.isEmpty) return null;

    const user = CameraConstants.defaultUsername;
    const pass = CameraConstants.defaultPassword;
    const path = "/cgi-bin/snapshot.cgi";
    final url = Uri.parse("http://$ip$path");

    final outDir = outputDirectory ?? Directory("vehicle_capture");
    if (!await outDir.exists()) {
      await outDir.create(recursive: true);
    }

    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 5)
      ..badCertificateCallback = (cert, host, port) => true;

    try {
      var request = await client.openUrl('GET', url);
      var response = await request.close();

      if (response.statusCode == 401) {
        final wwwAuth = response.headers.value(HttpHeaders.wwwAuthenticateHeader);
        if (wwwAuth != null && wwwAuth.toLowerCase().startsWith('digest')) {
          final authHeader = DahuaDigestAuth.computeAuthorizationHeader(
            method: 'GET',
            uri: path,
            username: user,
            password: pass,
            wwwAuthenticateHeader: wwwAuth,
          );
          request = await client.openUrl('GET', url);
          request.headers.set(HttpHeaders.authorizationHeader, authHeader);
          response = await request.close();
        }
      }

      if (response.statusCode == 200) {
        final bytes = await response.fold<List<int>>([], (buf, data) => buf..addAll(data));
        if (bytes.isNotEmpty) {
          final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
          final file = File(p.join(outDir.path, "native_${cameraConfig.id}_$timestamp.jpg"));
          await file.writeAsBytes(bytes);
          await LoggerService().log("Native snapshot captured from ${cameraConfig.name}: ${file.path}");
          return file.path;
        }
      }
    } catch (e) {
      await LoggerService().log("Native snapshot capture failed from ${cameraConfig.name}", e);
    } finally {
      client.close(force: true);
    }
    return null;
  }

  /// Sends a manual snapshot trigger command to Dahua/Hikvision camera to force ANPR evaluation on current view.
  Future<bool> triggerManualSnap({required CameraConfig cameraConfig}) async {
    final ip = resolveCameraIp(cameraConfig);
    if (ip == null || ip.isEmpty) return false;

    const user = CameraConstants.defaultUsername;
    const pass = CameraConstants.defaultPassword;

    final endpoints = [
      "/cgi-bin/trafficSnap.cgi?action=manSnap&channel=1",
      "/cgi-bin/trafficSnap.cgi?action=manSnap",
      "/cgi-bin/trafficSnap.cgi?action=manualSnap",
      "/cgi-bin/snapManager.cgi?action=manualSnap",
      "/cgi-bin/snapManager.cgi?action=snapFileProc&channel=1",
      "/cgi-bin/eventManager.cgi?action=sendEvent&code=TrafficJunction",
    ];

    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 4)
      ..badCertificateCallback = (cert, host, port) => true;

    for (final path in endpoints) {
      try {
        final url = Uri.parse("http://$ip$path");
        var request = await client.openUrl('GET', url);
        var response = await request.close();

        if (response.statusCode == 401) {
          final wwwAuth = response.headers.value(HttpHeaders.wwwAuthenticateHeader);
          if (wwwAuth != null && wwwAuth.toLowerCase().startsWith('digest')) {
            final authHeader = DahuaDigestAuth.computeAuthorizationHeader(
              method: 'GET',
              uri: path,
              username: user,
              password: pass,
              wwwAuthenticateHeader: wwwAuth,
            );
            request = await client.openUrl('GET', url);
            request.headers.set(HttpHeaders.authorizationHeader, authHeader);
            response = await request.close();
          }
        }
        await LoggerService().log("Manual snap trigger to $path: status=${response.statusCode}");
        if (response.statusCode == 200) {
          client.close(force: true);
          return true;
        }
      } catch (e) {
        // try next endpoint
      }
    }
    client.close(force: true);
    return false;
  }

  /// Runs the proven Python ANPR script (capture_anpr.py) which handles Dahua Digest auth
  /// and extracts scene image, cropped plate image, and OCR plate text.
  Future<AnprResult?> _runPythonAnprCapture({
    required CameraConfig cameraConfig,
    required int timeoutSeconds,
    required Directory outputDirectory,
  }) async {
    final ip = resolveCameraIp(cameraConfig);
    if (ip == null || ip.isEmpty) return null;

    final pythonScript = File("lib/capture_anpr.py");
    if (!await pythonScript.exists()) {
      await LoggerService().log("Python ANPR script not found at ${pythonScript.path}");
      return null;
    }

    try {
      await LoggerService().log("Starting Python ANPR capture process for $ip (timeout: ${timeoutSeconds}s)...");
      final process = await Process.start(
        'python',
        [
          pythonScript.path,
          '--ip', ip,
          '--user', CameraConstants.defaultUsername,
          '--password', CameraConstants.defaultPassword,
          '--timeout', timeoutSeconds.toString(),
          '--output', outputDirectory.path,
        ],
        runInShell: true,
      );

      final completer = Completer<AnprResult?>();
      final buffer = StringBuffer();

      process.stdout.transform(utf8.decoder).listen((data) {
        buffer.write(data);
        const startTag = "__ANPR_JSON_START__";
        const endTag = "__ANPR_JSON_END__";
        final fullText = buffer.toString();
        if (fullText.contains(startTag) && fullText.contains(endTag)) {
          final startIdx = fullText.indexOf(startTag);
          final endIdx = fullText.indexOf(endTag);
          if (startIdx != -1 && endIdx > startIdx) {
            final jsonStr = fullText.substring(startIdx + startTag.length, endIdx).trim();
            try {
              final Map<String, dynamic> parsed = jsonDecode(jsonStr);
              if (parsed['success'] == true) {
                if (!completer.isCompleted) {
                  completer.complete(AnprResult(
                    success: true,
                    vehicleImagePath: parsed['vehicle_image'],
                    plateImagePath: parsed['plate_image'],
                    plateNumber: parsed['plate_number'],
                    anprResponse: parsed['anpr_response'] as Map<String, dynamic>?,
                  ));
                }
              } else {
                if (!completer.isCompleted) {
                  completer.complete(AnprResult.empty(error: parsed['error']?.toString()));
                }
              }
            } catch (e) {
              LoggerService().log("Error decoding Python ANPR output JSON: $e");
            }
          }
        }
      });

      process.stderr.transform(utf8.decoder).listen((err) {
        LoggerService().log("Python ANPR stderr: $err");
      });

      process.exitCode.then((code) {
        if (!completer.isCompleted) {
          completer.complete(null);
        }
      });

      final result = await completer.future.timeout(
        Duration(seconds: timeoutSeconds + 4),
        onTimeout: () {
          process.kill();
          return null;
        },
      );

      if (result != null && result.success) {
        await LoggerService().log(
          "Python ANPR capture complete: Plate='${result.plateNumber}', Vehicle='${result.vehicleImagePath}', PlateCrop='${result.plateImagePath}'",
        );
        return result;
      }
    } catch (e) {
      await LoggerService().log("Python ANPR execution error, will fallback to Dart stream", e);
    }
    return null;
  }

  /// Initiates an ANPR capture session, waiting up to [timeoutSeconds] for a recognized vehicle.
  /// Also sends a manual snap trigger command to the camera so that stationary vehicles on the scale are evaluated.
  Future<AnprResult> captureAnpr({
    required CameraConfig? cameraConfig,
    int timeoutSeconds = 20,
    Directory? outputDirectory,
  }) async {
    final ip = resolveCameraIp(cameraConfig);
    if (ip == null || ip.isEmpty) {
      final errorMsg = "ANPR aborted: No IP address configured for camera '${cameraConfig?.name ?? 'Unknown'}'.";
      await LoggerService().log(errorMsg);
      return AnprResult.empty(error: errorMsg);
    }

    // Fixed username and password from app-wide constants
    const user = CameraConstants.defaultUsername;
    const pass = CameraConstants.defaultPassword;

    final outDir = outputDirectory ?? Directory("vehicle_capture");
    if (!await outDir.exists()) {
      await outDir.create(recursive: true);
    }

    await LoggerService().log(
      "ANPR capture requested: IP=$ip, User=$user, Timeout=${timeoutSeconds}s",
    );

    // Step 1: Try Python ANPR engine first (exact match to capture_anpr.py which user tested)
    final pyResult = await _runPythonAnprCapture(
      cameraConfig: cameraConfig!,
      timeoutSeconds: timeoutSeconds,
      outputDirectory: outDir,
    );
    if (pyResult != null && pyResult.success) {
      return pyResult;
    }

    // Step 2: Fallback to native pure-Dart ANPR stream engine
    final streamPath =
        "/cgi-bin/snapManager.cgi?action=attachFileProc&Flags[0]=Event&Events=[TrafficJunction]&heartbeat=5";
    final streamUrl = Uri.parse("http://$ip$streamPath");

    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10)
      ..badCertificateCallback = (cert, host, port) => true;

    try {
      // Step 1: Initial request to trigger 401 & challenge
      var request = await client.openUrl('GET', streamUrl);
      var response = await request.close();

      String? authHeader;
      if (response.statusCode == 401) {
        final wwwAuth = response.headers.value(HttpHeaders.wwwAuthenticateHeader);
        if (wwwAuth == null || !wwwAuth.toLowerCase().startsWith('digest')) {
          await LoggerService().log("ANPR: Unsupported auth type from camera: $wwwAuth");
          return AnprResult.empty(error: "Unsupported auth header from camera");
        }

        authHeader = DahuaDigestAuth.computeAuthorizationHeader(
          method: 'GET',
          uri: streamPath,
          username: user,
          password: pass,
          wwwAuthenticateHeader: wwwAuth,
        );

        // Step 2: Authenticated request
        request = await client.openUrl('GET', streamUrl);
        request.headers.set(HttpHeaders.authorizationHeader, authHeader);
        response = await request.close();
      }

      if (response.statusCode != 200) {
        final msg = "ANPR stream failed with status ${response.statusCode}";
        await LoggerService().log(msg);
        return AnprResult.empty(error: msg);
      }

      // Step 3: Stream reading and boundary extraction
      final contentType = response.headers.value(HttpHeaders.contentTypeHeader) ?? '';
      final boundaryMatch = RegExp(r'boundary="?([^";]+)"?').firstMatch(contentType);
      if (boundaryMatch == null) {
        const msg = "ANPR: Unexpected stream Content-Type without boundary";
        await LoggerService().log(msg);
        return AnprResult.empty(error: msg);
      }

      final boundaryBytes = latin1.encode("--${boundaryMatch.group(1)!}");
      await LoggerService().log(
        "ANPR stream active. Parsing boundary: ${boundaryMatch.group(1)}",
      );

      final completer = Completer<AnprResult>();
      final deadline = DateTime.now().add(Duration(seconds: timeoutSeconds));

      final List<int> streamBuffer = [];
      final Map<String, String> currentMetadata = {};
      final List<List<int>> recentPayloads = [];

      StreamSubscription? subscription;

      void finish(AnprResult result) {
        if (!completer.isCompleted) {
          subscription?.cancel();
          client.close(force: true);
          completer.complete(result);
        }
      }

      // Timer to enforce timeout
      final timer = Timer(Duration(seconds: timeoutSeconds), () {
        finish(AnprResult.empty(error: "ANPR timeout: No recognized vehicle detected"));
      });

      // Send manual snap trigger to camera as soon as listener is connected!
      unawaited(triggerManualSnap(cameraConfig: cameraConfig!));

      subscription = response.listen(
        (chunk) {
          if (DateTime.now().isAfter(deadline)) {
            timer.cancel();
            finish(AnprResult.empty(error: "ANPR timeout"));
            return;
          }

          streamBuffer.addAll(chunk);

          // Content-Length based multipart parser (exact equivalent of Python read_parts)
          while (true) {
            final boundaryIndex = _findSublist(streamBuffer, boundaryBytes);
            if (boundaryIndex == -1) break;

            final headerStart = boundaryIndex + boundaryBytes.length;
            if (streamBuffer.length <= headerStart) break;

            final headerSub = streamBuffer.sublist(headerStart);
            final crlfIdx = _findSublist(headerSub, [0x0D, 0x0A, 0x0D, 0x0A]);
            final lfIdx = _findSublist(headerSub, [0x0A, 0x0A]);

            if (crlfIdx == -1 && lfIdx == -1) break;

            final bool isCrlf = (crlfIdx != -1 && (lfIdx == -1 || crlfIdx <= lfIdx));
            final relSep = isCrlf ? crlfIdx : lfIdx;
            final sepLen = isCrlf ? 4 : 2;
            final sepIdx = headerStart + relSep;

            final headerBytes = streamBuffer.sublist(headerStart, sepIdx);
            final headerText = latin1.decode(headerBytes, allowInvalid: true);
            final partHeaders = <String, String>{};
            for (final line in LineSplitter.split(headerText)) {
              final colon = line.indexOf(':');
              if (colon != -1) {
                partHeaders[line.substring(0, colon).trim().toLowerCase()] =
                    line.substring(colon + 1).trim();
              }
            }

            final lengthStr = partHeaders['content-length'];
            final contentLength = (lengthStr != null) ? int.tryParse(lengthStr) : null;

            final bodyStart = sepIdx + sepLen;
            List<int> bodyData;

            if (contentLength != null) {
              final bodyEnd = bodyStart + contentLength;
              if (streamBuffer.length < bodyEnd) {
                // Whole body not yet arrived — wait for more TCP chunks!
                break;
              }
              bodyData = streamBuffer.sublist(bodyStart, bodyEnd);
              streamBuffer.removeRange(0, bodyEnd);
            } else {
              final nextBoundary = _findSublist(streamBuffer.sublist(bodyStart), boundaryBytes);
              if (nextBoundary == -1) break;
              final bodyEnd = bodyStart + nextBoundary;
              bodyData = streamBuffer.sublist(bodyStart, bodyEnd);
              streamBuffer.removeRange(0, bodyEnd);
            }

            // Check if body looks like binary JPEG
            final partContentType = partHeaders['content-type'] ?? '';
            final bool looksBinary = partContentType.contains('image') ||
                _findSublist(bodyData, [0xFF, 0xD8]) != -1;

            if (looksBinary) {
              recentPayloads.add(bodyData);
              if (recentPayloads.length > 3) {
                recentPayloads.removeAt(0);
              }
            } else {
              // Parse metadata only for text parts
              final parsedMeta = _parseMetadata(bodyData);
              if (parsedMeta.isNotEmpty) {
                currentMetadata.addAll(parsedMeta);
              }
            }

            // Check if we have detected a plate number
            final plate = (_getField(currentMetadata, "PlateNumber") ??
                    _getField(currentMetadata, "Object.Text") ??
                    _getField(currentMetadata, "PlateText") ??
                    _getField(currentMetadata, "Plate") ??
                    '')
                .trim();

            if (plate.isEmpty ||
                ['unknown', 'none', 'null', 'no', '0'].contains(plate.toLowerCase())) {
              continue;
            }

            // Try candidate payloads: latest first, then combined
            final candidates = <List<int>>[];
            candidates.addAll(recentPayloads.reversed);
            if (recentPayloads.length > 1) {
              final combined = <int>[];
              for (final p in recentPayloads) {
                combined.addAll(p);
              }
              candidates.add(combined);
            }

            for (final candidate in candidates) {
              final saved = _tryExtractAndSave(
                fields: currentMetadata,
                payload: candidate,
                outputDir: outDir,
              );

              if (saved != null) {
                timer.cancel();
                finish(saved);
                return;
              }
            }
          }
        },
        onError: (e) {
          timer.cancel();
          finish(AnprResult.empty(error: "ANPR stream error: $e"));
        },
        onDone: () {
          timer.cancel();
          if (!completer.isCompleted) {
            finish(AnprResult.empty(error: "ANPR stream closed before vehicle capture"));
          }
        },
        cancelOnError: true,
      );

      return await completer.future;
    } catch (e, stack) {
      await LoggerService().log("ANPR capture failed with exception", e, stack);
      return AnprResult.empty(error: e.toString());
    } finally {
      client.close(force: true);
    }
  }

  /// Parses Dahua key=value text metadata lines.
  static Map<String, String> _parseMetadata(List<int> data) {
    final text = latin1.decode(data, allowInvalid: true);
    final fields = <String, String>{};
    for (final line in LineSplitter.split(text)) {
      final eqIdx = line.indexOf('=');
      if (eqIdx != -1) {
        final key = line.substring(0, eqIdx).trim();
        var value = line.substring(eqIdx + 1).trim();
        if (value.startsWith('"') && value.endsWith('"') && value.length >= 2) {
          value = value.substring(1, value.length - 1);
        }
        fields[key] = value;
      }
    }
    return fields;
  }

  static String? _getField(Map<String, String> fields, String suffix) {
    for (final entry in fields.entries) {
      if (entry.key.toLowerCase().endsWith(suffix.toLowerCase()) && entry.value.isNotEmpty) {
        return entry.value;
      }
    }
    return null;
  }

  /// Finds index of needle within haystack, returns -1 if not found.
  static int _findSublist(List<int> haystack, List<int> needle) {
    if (needle.isEmpty || haystack.length < needle.length) return -1;
    for (int i = 0; i <= haystack.length - needle.length; i++) {
      bool match = true;
      for (int j = 0; j < needle.length; j++) {
        if (haystack[i + j] != needle[j]) {
          match = false;
          break;
        }
      }
      if (match) return i;
    }
    return -1;
  }

  /// Locates complete JPEG (0xFF,0xD8 to 0xFF,0xD9) in byte list.
  static Uint8List? _jpegFrom(List<int> data) {
    final start = _findSublist(data, [0xFF, 0xD8]);
    if (start < 0) return null;

    final end = _findSublist(data.sublist(start + 2), [0xFF, 0xD9]);
    if (end < 0) return null;

    return Uint8List.fromList(data.sublist(start, start + 2 + end + 2));
  }

  /// Attempts to parse offsets and write scene and plate images to disk.
  static AnprResult? _tryExtractAndSave({
    required Map<String, String> fields,
    required List<int> payload,
    required Directory outputDir,
  }) {
    final plate = (_getField(fields, "PlateNumber") ??
            _getField(fields, "Object.Text") ??
            _getField(fields, "PlateText") ??
            _getField(fields, "LicensePlate") ??
            _getField(fields, "Plate") ??
            '')
        .trim();

    if (plate.isEmpty ||
        ['unknown', 'none', 'null', 'no', '0'].contains(plate.toLowerCase())) {
      return null;
    }

    final sceneOffsetStr = _getField(fields, "SceneImage.Offset") ?? _getField(fields, "Scene.Offset");
    final sceneLenStr = _getField(fields, "SceneImage.Length") ?? _getField(fields, "Scene.Length");
    final plateOffsetStr = _getField(fields, "Object.Image.Offset") ??
        _getField(fields, "PlateImage.Offset") ??
        _getField(fields, "Plate.Offset");
    final plateLenStr = _getField(fields, "Object.Image.Length") ??
        _getField(fields, "PlateImage.Length") ??
        _getField(fields, "Plate.Length");

    Uint8List? sceneJpeg;
    Uint8List? plateJpeg;

    if (sceneOffsetStr != null &&
        sceneLenStr != null &&
        plateOffsetStr != null &&
        plateLenStr != null) {
      final sceneOffset = int.tryParse(sceneOffsetStr) ?? -1;
      final sceneLength = int.tryParse(sceneLenStr) ?? -1;
      final plateOffset = int.tryParse(plateOffsetStr) ?? -1;
      final plateLength = int.tryParse(plateLenStr) ?? -1;

      if (sceneOffset >= 0 &&
          sceneOffset + sceneLength <= payload.length &&
          plateOffset >= 0 &&
          plateOffset + plateLength <= payload.length) {
        sceneJpeg = _jpegFrom(payload.sublist(sceneOffset, sceneOffset + sceneLength));
        plateJpeg = _jpegFrom(payload.sublist(plateOffset, plateOffset + plateLength));
      }
    }

    // Fallback: If declared offsets failed, search for two valid JPEGs directly in payload
    if (sceneJpeg == null || plateJpeg == null) {
      final firstJpeg = _jpegFrom(payload);
      if (firstJpeg != null && firstJpeg.length < payload.length - 4) {
        final remaining = payload.sublist(firstJpeg.length);
        final secondJpeg = _jpegFrom(remaining);
        if (secondJpeg != null) {
          sceneJpeg = firstJpeg;
          plateJpeg = secondJpeg;
        }
      }
    }

    if (sceneJpeg == null || plateJpeg == null) {
      return null;
    }

    final safePlate = plate.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final prefix = "${timestamp}_$safePlate";

    final sceneFileName = "${prefix}_scene.jpg";
    final plateFileName = "${prefix}_plate.jpg";
    final jsonFileName = "$prefix.json";

    final sceneFile = File(p.join(outputDir.path, sceneFileName));
    final plateFile = File(p.join(outputDir.path, plateFileName));
    final jsonFile = File(p.join(outputDir.path, jsonFileName));

    sceneFile.writeAsBytesSync(sceneJpeg);
    plateFile.writeAsBytesSync(plateJpeg);

    final anprResponse = {
      "plate_number": plate,
      "vehicle_image": sceneFileName,
      "plate_image": plateFileName,
      "captured_at": DateTime.now().toIso8601String(),
    };

    jsonFile.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(anprResponse));

    LoggerService().log(
      "ANPR SUCCESS: Plate=$plate, VehicleImage=${sceneFile.path}, PlateImage=${plateFile.path}",
    );

    return AnprResult(
      success: true,
      vehicleImagePath: sceneFile.path,
      plateImagePath: plateFile.path,
      plateNumber: plate,
      anprResponse: anprResponse,
    );
  }
}
