import 'dart:io';

import 'package:dio/dio.dart';

class CommandModel {
  final String subdomain;
  final String requestID;
  final String scaleName;
  final File frontImage;
  final File backImage;
  final double weight;
  final String status;
  final String scaleStockId;
  final String recordType;
  final String recordStage;
  final String moduleType;

  const CommandModel({
    required this.subdomain,
    required this.requestID,
    required this.scaleName,
    required this.frontImage,
    required this.backImage,
    required this.weight,
    required this.status,
    required this.scaleStockId,
    required this.recordType,
    required this.recordStage,
    required this.moduleType,
  });

  CommandModel copyWith({
    String? subdomain,
    String? requestID,
    String? scaleName,
    File? frontImage,
    File? backImage,
    double? weight,
    String? status,
    String? recordType,
    String? scaleStockId,
    String? recordStage,
    String? moduleType,
  }) {
    return CommandModel(
      subdomain: subdomain ?? this.subdomain,
      requestID: requestID ?? this.requestID,
      scaleName: scaleName ?? this.scaleName,
      frontImage: frontImage ?? this.frontImage,
      backImage: backImage ?? this.backImage,
      weight: weight ?? this.weight,
      status: status ?? this.status,
      recordType: recordType ?? this.recordType,
      scaleStockId: scaleStockId ?? this.scaleStockId,
      recordStage: recordStage ?? this.recordStage,
      moduleType: moduleType ?? this.moduleType,
    );
  }

  factory CommandModel.fromMap(Map<String, dynamic> data) {
    return CommandModel(
      subdomain: data['subdomain'] ?? '',
      requestID: data['request_id'] ?? '',
      scaleName: data['scale_name'] ?? '',
      frontImage: File(data['front_image'] ?? ''),
      backImage: File(data['back_image'] ?? ''),
      weight: (data['weight'] ?? 0).toDouble(),
      status: data['status'] ?? '',
      recordType: data['record_type'] ?? '',
      scaleStockId: data['scale_stock_id'] ?? '',
      recordStage: data['record_stage'] ?? '',
      moduleType: data['module_type'] ?? '',
    );
  }

  factory CommandModel.dummy() {
    return CommandModel(
      subdomain: '',
      requestID: '',
      frontImage: File('/'),
      backImage: File('/'),
      weight: 0.0,
      status: 'pending',
      scaleName: '',
      scaleStockId: '',
      recordType: '',
      recordStage: '',
      moduleType: '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'subdomain': subdomain,
      'request_id': requestID,
      'scale_name': scaleName,
      'front_image': frontImage.path,
      'back_image': backImage.path,
      'weight': weight,
      'status': status,
      'record_type': recordType,
      'scale_stock_id': scaleStockId,
      'record_stage': recordStage,
      'module_type': moduleType,
    };
  }

  @override
  String toString() {
    return '''
CommandModel(
  subdomain: $subdomain,
  requestID: $requestID,
  scaleName: $scaleName,
  frontImage: ${frontImage.path},
  backImage: ${backImage.path},
  weight: $weight,
  status: $status,
  recordType: $recordType,
  scaleStockId: $scaleStockId,
  recordStage: $recordStage,
  moduleType: $moduleType,
)
''';
  }

  Future<FormData> toFormData() async {
    return FormData.fromMap({
      'subdomain': subdomain.trim(),
      'request_id': requestID.trim(),
      'scale_name': scaleName.trim(),

      'weight': weight,
      'status': status.trim(),
      'scale_stock_id': scaleStockId.trim(),
      'record_type': recordType.trim(),
      'record_stage': recordStage.trim(),
      'module_type': moduleType.trim(),
      'front_image': MultipartFile.fromFile(
        frontImage.path,
        filename: frontImage.path.split('/').last,
      ),
      'back_image': MultipartFile.fromFile(
        backImage.path,
        filename: backImage.path.split('/').last,
      ),
    });
  }
}
