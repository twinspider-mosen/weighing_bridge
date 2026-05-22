import 'dart:io';

import 'package:dio/dio.dart';

class CommandModel {
  final String subdomain;
  final String requestID;
  final String scaleId;
  final File image;
  final double weight;
  final String status;

  const CommandModel({
    required this.subdomain,
    required this.requestID,
    required this.scaleId,
    required this.image,
    required this.weight,
    required this.status,
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
      scaleId: scaleId ?? this.scaleId,
      image: image ?? this.image,
      weight: weight ?? this.weight,
      status: status ?? this.status,
    );
  }

  factory CommandModel.fromMap(Map<String, dynamic> data) {
    return CommandModel(
      subdomain: data['subdomain'] ?? '',
      requestID: data['request_id'] ?? '',
      scaleId: data['scale_id'] ?? '',
      image: File(data['image_path'] ?? ''),
      weight: (data['weight'] ?? 0).toDouble(),
      status: data['status'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'subdomain': subdomain,
      'request_id': requestID,
      'scale_id': scaleId,
      'image_path': image.path,
      'weight': weight,
      'status': status,
    };
  }

  @override
  String toString() {
    return '''
CommandModel(
  subdomain: $subdomain,
  requestID: $requestID,
  scaleId: $scaleId,
  image: ${image.path},
  weight: $weight,
  status: $status,
)
''';
  }

  Future<FormData> toFormData()async{
    return FormData.fromMap({
        'subdomain': subdomain.trim(),
      'request_id': requestID.trim(),
      'scale_id': scaleId.trim(),

      'weight': weight,
      'status': status.trim(),
      'image': MultipartFile.fromFile(image.path, filename: image.path.split('/').last)
    });
  }

}