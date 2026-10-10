import 'dart:convert';
import 'prediction_result.dart';

/// Local Persistent Scan History Record
class ScanRecord {
  final String id;
  final DateTime timestamp;
  final String imagePath;
  final String predictedClass;
  final double confidence;
  final bool isLowConfidence;
  final String severity;
  final int severityLevel;
  final bool isHealthy;
  final List<String> symptoms;
  final List<String> treatment;
  final List<String> prevention;
  final List<String> advisory;
  final String status; // 'SUCCESS', 'LOW_CONFIDENCE', 'REJECTED_QUALITY', 'REJECTED_NON_COTTON'
  final String? userNote;

  ScanRecord({
    required this.id,
    required this.timestamp,
    required this.imagePath,
    required this.predictedClass,
    required this.confidence,
    required this.isLowConfidence,
    required this.severity,
    required this.severityLevel,
    required this.isHealthy,
    required this.symptoms,
    required this.treatment,
    required this.prevention,
    required this.advisory,
    this.status = 'SUCCESS',
    this.userNote,
  });

  factory ScanRecord.fromPrediction({
    required String id,
    required String imagePath,
    required PredictionResult result,
    String? note,
  }) {
    String status = 'SUCCESS';
    if (result.isLowConfidence) {
      status = 'LOW_CONFIDENCE';
    }

    return ScanRecord(
      id: id,
      timestamp: DateTime.now(),
      imagePath: imagePath,
      predictedClass: result.predictedClass,
      confidence: result.confidence,
      isLowConfidence: result.isLowConfidence,
      severity: result.severity,
      severityLevel: result.severityLevel,
      isHealthy: result.isHealthy,
      symptoms: result.symptoms,
      treatment: result.treatment,
      prevention: result.prevention,
      advisory: result.advisory,
      status: status,
      userNote: note,
    );
  }

  factory ScanRecord.fromJson(Map<String, dynamic> json) {
    return ScanRecord(
      id: json['id'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      imagePath: json['imagePath'] as String,
      predictedClass: json['predictedClass'] as String,
      confidence: (json['confidence'] as num).toDouble(),
      isLowConfidence: json['isLowConfidence'] as bool? ?? false,
      severity: json['severity'] as String? ?? 'Moderate',
      severityLevel: json['severityLevel'] as int? ?? 1,
      isHealthy: json['isHealthy'] as bool? ?? false,
      symptoms: (json['symptoms'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      treatment: (json['treatment'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      prevention: (json['prevention'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      advisory: (json['advisory'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      status: json['status'] as String? ?? 'SUCCESS',
      userNote: json['userNote'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'imagePath': imagePath,
      'predictedClass': predictedClass,
      'confidence': confidence,
      'isLowConfidence': isLowConfidence,
      'severity': severity,
      'severityLevel': severityLevel,
      'isHealthy': isHealthy,
      'symptoms': symptoms,
      'treatment': treatment,
      'prevention': prevention,
      'advisory': advisory,
      'status': status,
      'userNote': userNote,
    };
  }

  static String encodeList(List<ScanRecord> records) {
    return jsonEncode(records.map((r) => r.toJson()).toList());
  }

  static List<ScanRecord> decodeList(String jsonStr) {
    try {
      final List<dynamic> list = jsonDecode(jsonStr) as List<dynamic>;
      return list.map((item) => ScanRecord.fromJson(item as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }
}
