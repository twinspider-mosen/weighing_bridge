import 'dart:developer';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dio/io.dart';

/// Standalone Service to handle scale and screenshot uploads using the Dio package.
///
/// This class is fully decoupled and can be easily attached/detached from any UI flow.
class ApiService {
  final Dio _dio =
      Dio(
          BaseOptions(
            connectTimeout: const Duration(seconds: 30),
            receiveTimeout: const Duration(seconds: 30),
            headers: {'App-Ref-Type': 'weighBridge', 'App-Ref': 'flour_mill'},
          ),
        )
        ..httpClientAdapter = IOHttpClientAdapter(
          createHttpClient: () {
            final client = HttpClient();
            client.badCertificateCallback =
                (X509Certificate cert, String host, int port) => true;
            return client;
          },
        )
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) async {
              // By default, token is required unless explicitly disabled via extra params
              final bool requiresToken = options.extra['requiresToken'] ?? true;

              if (requiresToken &&
                  !options.headers.containsKey('Authorization')) {
                final prefs = await SharedPreferences.getInstance();
                final token = prefs.getString('active_token');
                if (token != null && token.isNotEmpty) {
                  options.headers['Authorization'] = 'Bearer $token';
                }
              }
              return handler.next(options);
            },
          ),
        );

  Future<Response> uploadScreenshot({
    required String requestID,
    required String scaleName,
    required String subdomain,
    required String weight,
    required String imagePath,
    required String recordType,
    required String scaleStockId,
  }) async {
    // Verify file exists
    final file = File(imagePath);
    if (!await file.exists()) {
      throw FileNotFoundException(
        "Snapshot file does not exist at path: $imagePath",
      );
    }

    // Build the multipart Form Data with exact keys: subdomain, domain, weight, and snap.
    final FormData formData = FormData.fromMap({
      'subdomain': subdomain.trim(),
      'request_id': requestID,
      'scale_name': scaleName,
      'record_type': recordType,
      'scale_stock_id': scaleStockId,
      'weight': weight,

      'back_image': '',
      'front_image': await MultipartFile.fromFile(
        file.path,
        filename: p.basename(file.path),
      ),
    });
    print("Form Data = ${formData.fields}");
    final url = "https://${subdomain.trim()}.${Urls.uploadUrl}";
    print("Final URL $url");

    // return Response(requestOptions: RequestOptions(data: formData
    // ));
    // Execute the POST request to the fixed uploadUrl
    try {
      return await _dio.post(url, data: formData);
    } catch (e) {
      log("Error on posting data to server: ${e.toString()}");
      return Response(requestOptions: RequestOptions(data: 'null'));
    }
  }

  // Verify Subdomain
  Future<Response> verifySubdomain({required String subdomain}) async {
    final url = "${Urls.subDomain}$subdomain";
    try {
      return await _dio.get(
        url,
        options: Options(extra: {'requiresToken': false}),
      );
    } catch (e) {
      log("Error on verifying subdomain: ${e.toString()}");
      return Response(requestOptions: RequestOptions(data: 'null'));
    }
  }

  Future<Response> login(String email, String pass, String subDomain) async {
    final String url = "https://$subDomain.${Urls.authenticate}";
    // final String url = "https://${Urls.authenticate}";
    print(url);
    final data = FormData.fromMap({
      'email': email.trim(),
      'password': pass.trim(),
    });

    var response = await _dio.post(
      url,
      data: data,
      options: Options(extra: {'requiresToken': false}),
    );
    return response;
  }
}

class FileNotFoundException implements Exception {
  final String message;
  FileNotFoundException(this.message);
  @override
  String toString() => "FileNotFoundException: $message";
}

class Urls {
  static const String subDomain =
      "https://flour.twincloud.app/api/v1/app_dashboard/verify_subdomain?subdomain=";

  static const String base = "twincloud.app/";
  // // static const String base = "20e2-182-189-116-35.ngrok-free.app/";
  // static const String base = "20e2-182-189-116-35.ngrok-free.app/";
  // static const String subDomain =
  //     "https://${base}api/v1/app_dashboard/verify_subdomain?subdomain=";
  static const String baseUrl = "${base}api/v1/";
  static const String uploadUrl = '${baseUrl}scales/submit_data';
  static const String authenticate = "${baseUrl}authenticate?";
}
