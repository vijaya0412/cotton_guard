/// Prediction result model matching the backend API response.
class PredictionResult {
  final bool success;
  final String predictedClass;
  final double confidence;
  final bool isLowConfidence;
  final String severity;
  final int severityLevel;
  final bool isHealthy;
  final String scientificName;
  final String summary;
  final List<String> symptoms;
  final List<String> treatment;
  final List<String> prevention;
  final List<String> advisory;
  final String favorableConditions;
  final double latencyMs;
  final String modelName;
  final String engine;
  final Map<String, dynamic>? qualityMetrics;

  PredictionResult({
    required this.success,
    required this.predictedClass,
    required this.confidence,
    required this.isLowConfidence,
    required this.severity,
    required this.severityLevel,
    required this.isHealthy,
    required this.scientificName,
    required this.summary,
    required this.symptoms,
    required this.treatment,
    required this.prevention,
    required this.advisory,
    required this.favorableConditions,
    required this.latencyMs,
    required this.modelName,
    required this.engine,
    this.qualityMetrics,
  });

  factory PredictionResult.fromJson(Map<String, dynamic> json) {
    return PredictionResult(
      success: json['success'] as bool? ?? true,
      predictedClass: json['predicted_class'] as String? ?? 'Unknown',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      isLowConfidence: json['is_low_confidence'] as bool? ?? false,
      severity: json['severity'] as String? ?? 'Moderate',
      severityLevel: json['severity_level'] as int? ?? 1,
      isHealthy: json['is_healthy'] as bool? ?? false,
      scientificName: json['scientific_name'] as String? ?? '',
      summary: json['summary'] as String? ?? '',
      symptoms: (json['symptoms'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      treatment: (json['treatment'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      prevention: (json['prevention'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      advisory: (json['advisory'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      favorableConditions: json['favorable_conditions'] as String? ?? '',
      latencyMs: (json['latency_ms'] as num?)?.toDouble() ?? 0.0,
      modelName: json['model_name'] as String? ?? 'MobileNetV2',
      engine: json['engine'] as String? ?? 'ONNX Runtime',
      qualityMetrics: json['quality_metrics'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'predicted_class': predictedClass,
      'confidence': confidence,
      'is_low_confidence': isLowConfidence,
      'severity': severity,
      'severity_level': severityLevel,
      'is_healthy': isHealthy,
      'scientific_name': scientificName,
      'summary': summary,
      'symptoms': symptoms,
      'treatment': treatment,
      'prevention': prevention,
      'advisory': advisory,
      'favorable_conditions': favorableConditions,
      'latency_ms': latencyMs,
      'model_name': modelName,
      'engine': engine,
      'quality_metrics': qualityMetrics,
    };
  }
}
