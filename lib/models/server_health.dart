/// Server Health and Readiness model.
class ServerHealth {
  final String status; // CONNECTED, MODEL_NOT_READY, DISCONNECTED, ERROR, CHECKING
  final String version;
  final double uptimeSeconds;
  final bool modelLoaded;
  final String modelName;
  final String inferenceEngine;
  final bool cottonValidationReady;
  final bool diseaseModelReady;
  final List<String> supportedClasses;
  final String timestamp;
  final int latencyMs;
  final String? errorMessage;

  ServerHealth({
    required this.status,
    required this.version,
    required this.uptimeSeconds,
    required this.modelLoaded,
    required this.modelName,
    required this.inferenceEngine,
    required this.cottonValidationReady,
    required this.diseaseModelReady,
    required this.supportedClasses,
    required this.timestamp,
    this.latencyMs = 0,
    this.errorMessage,
  });

  factory ServerHealth.fromJson(Map<String, dynamic> json, {int latencyMs = 0}) {
    return ServerHealth(
      status: json['status'] as String? ?? 'CONNECTED',
      version: json['version'] as String? ?? '1.0.0',
      uptimeSeconds: (json['uptime_seconds'] as num?)?.toDouble() ?? 0.0,
      modelLoaded: json['model_loaded'] as bool? ?? false,
      modelName: json['model_name'] as String? ?? 'MobileNetV2',
      inferenceEngine: json['inference_engine'] as String? ?? 'ONNX Runtime',
      cottonValidationReady: json['cotton_validation_ready'] as bool? ?? false,
      diseaseModelReady: json['disease_model_ready'] as bool? ?? false,
      supportedClasses: (json['supported_classes'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      timestamp: json['timestamp'] as String? ?? DateTime.now().toIso8601String(),
      latencyMs: latencyMs,
    );
  }

  factory ServerHealth.disconnected({String? message}) {
    return ServerHealth(
      status: 'DISCONNECTED',
      version: 'N/A',
      uptimeSeconds: 0,
      modelLoaded: false,
      modelName: 'None',
      inferenceEngine: 'None',
      cottonValidationReady: false,
      diseaseModelReady: false,
      supportedClasses: [],
      timestamp: DateTime.now().toIso8601String(),
      latencyMs: 0,
      errorMessage: message ?? 'Cannot reach AI Backend server. Verify connection URL.',
    );
  }

  factory ServerHealth.checking() {
    return ServerHealth(
      status: 'CHECKING',
      version: '...',
      uptimeSeconds: 0,
      modelLoaded: false,
      modelName: '...',
      inferenceEngine: '...',
      cottonValidationReady: false,
      diseaseModelReady: false,
      supportedClasses: [],
      timestamp: DateTime.now().toIso8601String(),
      latencyMs: 0,
    );
  }

  bool get isConnected => status == 'CONNECTED' && modelLoaded && diseaseModelReady;
  bool get isStopped => status == 'STOPPED';
  bool get isTransitioning => status == 'STARTING' || status == 'STOPPING';
  bool get isError => status == 'ERROR';
}
