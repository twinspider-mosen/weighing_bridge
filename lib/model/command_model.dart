import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';

class CommandModel {
  final String subdomain;
  final String requestID;
  final String scaleName;
  final File frontImage;
  final File backImage;
  final double weight;
  final String status;
  String? scaleStockId;
  final String recordType;
  final String recordStage;
  final String moduleType;
  final DateTime? createdAt;

  final File? frontPlate;
  final String? frontPlateText;
  final File? backPlate;
  final String? backPlateText;

  CommandModel({
    required this.subdomain,
    required this.requestID,
    required this.scaleName,
    required this.frontImage,
    required this.backImage,
    required this.weight,
    required this.status,
    this.scaleStockId,
    required this.recordType,
    required this.recordStage,
    required this.moduleType,
    this.createdAt,
    this.frontPlate,
    this.frontPlateText,
    this.backPlate,
    this.backPlateText,
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
    DateTime? createdAt,
    File? frontPlate,
    String? frontPlateText,
    File? backPlate,
    String? backPlateText,
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
      createdAt: createdAt ?? this.createdAt,
      frontPlate: frontPlate ?? this.frontPlate,
      frontPlateText: frontPlateText ?? this.frontPlateText,
      backPlate: backPlate ?? this.backPlate,
      backPlateText: backPlateText ?? this.backPlateText,
    );
  }

  static DateTime? _parseDateTime(dynamic val) {
    if (val == null) return null;
    if (val is Timestamp) return val.toDate();
    if (val is DateTime) return val;
    if (val is String) return DateTime.tryParse(val);
    if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
    return null;
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
      scaleStockId: data['scale_stock_id'] != null
          ? "${data['scale_stock_id']}"
          : null,
      recordStage: data['record_stage'] ?? '',
      moduleType: data['module_type'] ?? '',
      createdAt: _parseDateTime(data['created_at']) ??
          _parseDateTime(data['timestamp']) ??
          _parseDateTime(data['createdAt']),
      frontPlate: data['front_plate'] != null &&
              data['front_plate'].toString().isNotEmpty
          ? File(data['front_plate'].toString())
          : null,
      frontPlateText: data['front_plate_text']?.toString(),
      backPlate: data['back_plate'] != null &&
              data['back_plate'].toString().isNotEmpty
          ? File(data['back_plate'].toString())
          : null,
      backPlateText: data['back_plate_text']?.toString(),
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
    final map = <String, dynamic>{
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

    if (createdAt != null) {
      map['created_at'] = createdAt!.toIso8601String();
    }

    if (frontPlate != null && frontPlate!.path.isNotEmpty) {
      map['front_plate'] = frontPlate!.path;
    }
    if (frontPlateText != null && frontPlateText!.isNotEmpty) {
      map['front_plate_text'] = frontPlateText;
    }
    if (backPlate != null && backPlate!.path.isNotEmpty) {
      map['back_plate'] = backPlate!.path;
    }
    if (backPlateText != null && backPlateText!.isNotEmpty) {
      map['back_plate_text'] = backPlateText;
    }

    return map;
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
  frontPlate: ${frontPlate?.path},
  frontPlateText: $frontPlateText,
  backPlate: ${backPlate?.path},
  backPlateText: $backPlateText,
)
''';
  }

  Future<FormData> toFormData() async {
    final Map<String, dynamic> map = {
      'subdomain': subdomain.trim(),
      'request_id': requestID.trim(),
      'scale_name': scaleName.trim(),
      'weight': weight,
      'status': status.trim(),
      'scale_stock_id': scaleStockId,
      'record_type': recordType.trim(),
      'record_stage': recordStage.trim(),
      'module_type': moduleType.trim(),
    };

    if (await frontImage.exists()) {
      map['front_image'] = await MultipartFile.fromFile(
        frontImage.path,
        filename: frontImage.path.split(Platform.pathSeparator).last,
      );
    }
    if (await backImage.exists()) {
      map['back_image'] = await MultipartFile.fromFile(
        backImage.path,
        filename: backImage.path.split(Platform.pathSeparator).last,
      );
    }

    // Only send ANPR keys if available
    if (frontPlate != null && await frontPlate!.exists()) {
      map['front_plate'] = await MultipartFile.fromFile(
        frontPlate!.path,
        filename: frontPlate!.path.split(Platform.pathSeparator).last,
      );
    }
    if (frontPlateText != null && frontPlateText!.isNotEmpty) {
      map['front_plate_text'] = frontPlateText;
    }

    if (backPlate != null && await backPlate!.exists()) {
      map['back_plate'] = await MultipartFile.fromFile(
        backPlate!.path,
        filename: backPlate!.path.split(Platform.pathSeparator).last,
      );
    }
    if (backPlateText != null && backPlateText!.isNotEmpty) {
      map['back_plate_text'] = backPlateText;
    }

    return FormData.fromMap(map);
  }
}
