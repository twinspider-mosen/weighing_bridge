import 'package:weighing_bridge/services/api_service.dart';
import 'package:weighing_bridge/services/logger_service.dart';
import 'package:weighing_bridge/services/ocr_service.dart';

class UploadService {
  static final ApiService _apiService = ApiService();

  static Future<void> uploadSnapshot({
    required String imagePath,
    required String currentWeight,
    required String requestID,
    required String scaleID,
    required String subdomain,
    bool runOCR = true,
  }) async {
    OcrResult? ocrResult;

    // Optional OCR
    if (runOCR && OcrService().isConnected) {
      try {
        ocrResult = await OcrService().scanImage(imagePath);

        await LoggerService().log(
          "OCR Complete: ${ocrResult.labeledTexts}",
        );
      } catch (e) {
        await LoggerService().log(
          "OCR Failed",
          e,
        );
      }
    }

    // Upload image
    await _apiService.uploadScreenshot(
      requestID: requestID,
      subdomain: subdomain,
      weight: currentWeight,
      imagePath: imagePath,
      scaleId: scaleID,
    );
    
    await LoggerService().log(
      "Upload completed successfully",
    );
  }
}