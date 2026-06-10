import 'dart:io';

import 'package:dio/dio.dart';

class CommandModel {
  final String subdomain;
  final String requestID;
  final String scaleName;
  final File image;
  final double weight;
  final String status;
  final String scaleStockId;
  final String recordType;

  const CommandModel({
    required this.subdomain,
    required this.requestID,
    required this.scaleName,
    required this.image,
    required this.weight,
    required this.status,
    required this.scaleStockId,
    required this.recordType,
  });

  CommandModel copyWith({
    String? subdomain,
    String? requestID,
    String? scaleId,
    File? image,
    double? weight,
    String? status,
  }) {
    return CommandModel(
      subdomain: subdomain ?? this.subdomain,
      requestID: requestID ?? this.requestID,
      scaleName: scaleName ?? this.scaleName,
      image: image ?? this.image,
      weight: weight ?? this.weight,
      status: status ?? this.status,
      recordType: recordType ?? this.recordType,
      scaleStockId: scaleStockId ?? this.scaleStockId,
    );
  }

  factory CommandModel.fromMap(Map<String, dynamic> data) {
    return CommandModel(
      subdomain: data['subdomain'] ?? '',
      requestID: data['request_id'] ?? '',
      scaleName: data['scale_name'] ?? '',
      image: File(data['image_path'] ?? ''),
      weight: (data['weight'] ?? 0).toDouble(),
      status: data['status'] ?? '',
      recordType: data['record_type'] ?? '',
      scaleStockId: data['scale_stock_id'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'subdomain': subdomain,
      'request_id': requestID,
      'scale_name': scaleName,
      'image_path': image.path,
      'weight': weight,
      'status': status,
      'record_type': recordType,
      'scale_stock_id': scaleStockId,
    };
  }

  @override
  String toString() {
    return '''
CommandModel(
  subdomain: $subdomain,
  requestID: $requestID,
  scaleName: $scaleName,
  image: ${image.path},
  weight: $weight,
  status: $status,
  recordType: $recordType,
  scaleStockId: $scaleStockId,
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
      'image': MultipartFile.fromFile(
        image.path,
        filename: image.path.split('/').last,
      ),
    });
  }
}
