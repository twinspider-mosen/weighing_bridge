import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;

/// Standalone Service to handle scale and screenshot uploads using the Dio package.
/// 
/// This class is fully decoupled and can be easily attached/detached from any UI flow.
class ApiService {
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );

  // The fixed API endpoint URL for screenshot and weight uploads.
  // This can be easily changed here to target your exact production server API.
  static const String uploadUrl = 'https://api.weighbridge.com/upload';

  /// Uploads a camera snapshot and current scale weight data to the fixed
  /// API endpoint, passing the selected domain, subdomain, weight, and image inside FormData.
  /// 
  /// [domain] - Selected base domain from dropdown (e.g., "weighbridgeportal.com")
  /// [subdomain] - Subdomain input by the user (e.g., "client-a")
  /// [weight] - The active scale reading text (e.g., "124.50 kg")
  /// [imagePath] - Absolute path of the captured JPEG snapshot on disk
  Future<Response> uploadScreenshot({
    required String domain,
    required String subdomain,
    required String weight,
    required String imagePath,
  }) async {
    // Verify file exists
    final file = File(imagePath);
    if (!await file.exists()) {
      throw FileNotFoundException("Snapshot file does not exist at path: $imagePath");
    }

    // Build the multipart Form Data with exact keys: subdomain, domain, weight, and snap.
    final FormData formData = FormData.fromMap({
      'subdomain': subdomain.trim(),
      'domain': domain.trim(),
      'weight': weight.trim(),
      'snap': await MultipartFile.fromFile(
        file.path,
        filename: p.basename(file.path),
      ),
    });

    // Execute the POST request to the fixed uploadUrl
    return await _dio.post(
      uploadUrl,
      data: formData,
      options: Options(
        headers: {
          'Accept': 'application/json',
          'User-Agent': 'WeighingBridgeClient/2.0',
        },
      ),
    );
  }
}

class FileNotFoundException implements Exception {
  final String message;
  FileNotFoundException(this.message);
  @override
  String toString() => "FileNotFoundException: $message";
}
