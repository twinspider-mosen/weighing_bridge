import 'package:spider_weighbridge/services/api_service.dart';
import 'package:spider_weighbridge/services/logger_service.dart';
import 'package:spider_weighbridge/services/ocr_service.dart';

class UploadService {
  static final ApiService _apiService = ApiService();

  static Future<void> uploadSnapshot({
    String? frontImagePath,
    String? backImagePath,
    required String currentWeight,
    required String requestID,
    required String scaleName,
    required String subdomain,
    required String recordType,
    required String scaleStockId,
    required String recordStage,
    required String moduleType,
    bool runOCR = true,
  }) async {
    OcrResult? ocrResult;

    // Optional OCR on whichever image is available (prefer front)
    final ocrPath = frontImagePath ?? backImagePath;
    if (runOCR && ocrPath != null && OcrService().isConnected) {
      try {
        ocrResult = await OcrService().scanImage(ocrPath);

        await LoggerService().log("OCR Complete: ${ocrResult.labeledTexts}");
      } catch (e) {
        await LoggerService().log("OCR Failed", e);
      }
    }

    // Upload images
    var response = await _apiService.uploadScreenshot(
      requestID: requestID,
      subdomain: subdomain,
      weight: currentWeight,
      frontImagePath: frontImagePath,
      backImagePath: backImagePath,
      scaleName: scaleName,
      recordType: recordType,
      scaleStockId: scaleStockId,
      recordStage: recordStage,
      moduleType: moduleType,
    );
    print("response = = = = => ${response}");
    LoggerService().log('response = = = = => $response');

    print("response Data = = = = => ${response.data}");
    LoggerService().log('response Data = = = = => ${response.data}');
    await LoggerService().log("Upload completed successfully");
  }
}
