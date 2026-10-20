import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
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
          'Digest username="$username", realm="$realm", nonce="$nonce", uri="$uri", response="$response", qop="auth", nc=$nc, cnonce="$cnonce"';
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

  static const String defaultIp = "192.168.0.101";
  static const String defaultUser = "admin";
  static const String defaultPassword = "admin@12345";

  /// Resolves IP, Username, and Password from the provided CameraConfig or defaults.
  static Map<String, String> resolveCredentials(CameraConfig? config) {
    String ip = defaultIp;
    String username = defaultUser;
    String password = defaultPassword;

    if (config != null) {
      if (config.ipAddress.isNotEmpty) {
        ip = config.ipAddress;
      }
      if (config.rtspUrl.isNotEmpty) {
        try {
          final uri = Uri.parse(config.rtspUrl);
          if (uri.userInfo.isNotEmpty) {
            final parts = uri.userInfo.split(':');
            if (parts.isNotEmpty && parts[0].isNotEmpty) {
              username = Uri.decodeComponent(parts[0]);
            }
            if (parts.length > 1) {
              password = Uri.decodeComponent(parts.sublist(1).join(':'));
            }
          }
          if (uri.host.isNotEmpty) {
            ip = uri.host;
          }
        } catch (_) {}
      }
    }

    return {'ip': ip, 'username': username, 'password': password};
  }

  /// Initiates an ANPR capture session, waiting up to [timeoutSeconds] for a recognized vehicle.
  Future<AnprResult> captureAnpr({
    CameraConfig? cameraConfig,
    int timeoutSeconds = 15,
    Directory? outputDirectory,
  }) async {
    final creds = resolveCredentials(cameraConfig);
    final ip = creds['ip']!;
    final user = creds['username']!;
    final pass = creds['password']!;

    final outDir = outputDirectory ?? Directory("vehicle_capture");
    if (!await outDir.exists()) {
      await outDir.create(recursive: true);
    }

    await LoggerService().log(
      "ANPR capture requested: IP=$ip, User=$user, Timeout=${timeoutSeconds}s",
    );

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

      subscription = response.listen(
        (chunk) {
          if (DateTime.now().isAfter(deadline)) {
            timer.cancel();
            finish(AnprResult.empty(error: "ANPR timeout"));
            return;
          }

          streamBuffer.addAll(chunk);

          // Process parts delimited by boundary
          while (true) {
            final boundaryIndex = _findSublist(streamBuffer, boundaryBytes);
            if (boundaryIndex == -1) break;

            final partBytes = streamBuffer.sublist(0, boundaryIndex);
            // Remove processed part plus boundary length
            streamBuffer.removeRange(0, boundaryIndex + boundaryBytes.length);

            // Skip leading whitespace / newlines after boundary
            while (streamBuffer.isNotEmpty &&
                (streamBuffer[0] == 0x0D || streamBuffer[0] == 0x0A)) {
              streamBuffer.removeAt(0);
            }

            if (partBytes.isEmpty) continue;

            // Separate headers from body (separated by \r\n\r\n or \n\n)
            final headerSeparator = _findSublist(partBytes, [0x0D, 0x0A, 0x0D, 0x0A]);
            final sepLen = (headerSeparator != -1) ? 4 : 2;
            final actualHeaderSep = (headerSeparator != -1)
                ? headerSeparator
                : _findSublist(partBytes, [0x0A, 0x0A]);

            if (actualHeaderSep == -1) continue;

            final headerData = partBytes.sublist(0, actualHeaderSep);
            final bodyData = partBytes.sublist(actualHeaderSep + sepLen);

            final headerText = latin1.decode(headerData, allowInvalid: true);
            final partHeaders = <String, String>{};
            for (final line in LineSplitter.split(headerText)) {
              final colon = line.indexOf(':');
              if (colon != -1) {
                partHeaders[line.substring(0, colon).trim().toLowerCase()] =
                    line.substring(colon + 1).trim();
              }
            }

            // Parse metadata if present
            final parsedMeta = _parseMetadata(bodyData);
            if (parsedMeta.isNotEmpty) {
              currentMetadata.addAll(parsedMeta);
            }

            // Check if body looks like binary JPEG or image content
            final partContentType = partHeaders['content-type'] ?? '';
            final bool looksBinary = partContentType.contains('image') ||
                _findSublist(bodyData, [0xFF, 0xD8]) != -1;

            if (looksBinary) {
              recentPayloads.add(bodyData);
              if (recentPayloads.length > 3) {
                recentPayloads.removeAt(0);
              }
            }

            // Check if we have detected a plate number
            final plate = (_getField(currentMetadata, "TrafficCar.PlateNumber") ??
                    _getField(currentMetadata, "Object.Text") ??
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
      if (entry.key.endsWith(suffix) && entry.value.isNotEmpty) {
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
    final plate = (_getField(fields, "TrafficCar.PlateNumber") ??
            _getField(fields, "Object.Text") ??
            '')
        .trim();

    if (plate.isEmpty ||
        ['unknown', 'none', 'null', 'no', '0'].contains(plate.toLowerCase())) {
      return null;
    }

    final sceneOffsetStr = _getField(fields, "SceneImage.Offset");
    final sceneLenStr = _getField(fields, "SceneImage.Length");
    final plateOffsetStr = _getField(fields, "Object.Image.Offset");
    final plateLenStr = _getField(fields, "Object.Image.Length");

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
