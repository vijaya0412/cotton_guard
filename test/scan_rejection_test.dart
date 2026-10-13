import 'dart:convert';

import 'package:cottonguard/constants/canonical_classes.dart';
import 'package:cottonguard/controllers/connection_controller.dart';
import 'package:cottonguard/controllers/history_controller.dart';
import 'package:cottonguard/models/prediction_result.dart';
import 'package:cottonguard/models/server_health.dart';
import 'package:cottonguard/screens/scan/ai_analysis_screen.dart';
import 'package:cottonguard/services/api_service.dart';
import 'package:cottonguard/services/storage_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A 1x1 transparent PNG so the on-screen image widget never reports a decode error.
final List<int> _tinyPngBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
);

/// Fake API client that resolves *after* the screen's 400ms stage delay so the
/// pending prediction future always has a listener attached before it settles.
class _FakeApiService extends ApiService {
  _FakeApiService(super.storage, this._onPredict);

  final Future<PredictionResult> Function() _onPredict;

  @override
  Future<PredictionResult> predictDisease({
    required List<int> imageBytes,
    required String fileName,
  }) =>
      _onPredict();

  @override
  Future<ServerHealth> checkHealth({String? overrideUrl}) async {
    return ServerHealth(
      status: 'CONNECTED',
      version: '1.0.0',
      uptimeSeconds: 5,
      modelLoaded: true,
      modelName: 'test-model',
      inferenceEngine: 'ONNX Runtime',
      cottonValidationReady: true,
      diseaseModelReady: true,
      supportedClasses: CanonicalClasses.all,
      timestamp: DateTime.now().toIso8601String(),
      latencyMs: 5,
    );
  }
}

Future<PredictionResult> _delayedSuccess() async {
  await Future<void>.delayed(const Duration(milliseconds: 600));
  return _successResult();
}

Future<PredictionResult> _delayedUnsuccessful() async {
  await Future<void>.delayed(const Duration(milliseconds: 600));
  return _unsuccessfulResult();
}

Future<PredictionResult> _delayedThrow(String code, String message) async {
  await Future<void>.delayed(const Duration(milliseconds: 600));
  throw ValidationException(message, code: code);
}

PredictionResult _successResult() => PredictionResult(
      success: true,
      predictedClass: 'Bacterial Blight',
      confidence: 0.98,
      isLowConfidence: false,
      severity: 'Moderate to High',
      severityLevel: 3,
      isHealthy: false,
      scientificName: 'Xanthomonas citri pv. malvacearum',
      summary: 'Water-soaked angular leaf spots.',
      symptoms: const ['Angular spots'],
      treatment: const ['Copper Oxychloride spray'],
      prevention: const ['Seed treatment'],
      advisory: const ['Copper Oxychloride spray'],
      favorableConditions: 'High humidity',
      latencyMs: 12,
      modelName: 'test-model',
      engine: 'ONNX Runtime',
    );

PredictionResult _unsuccessfulResult() => PredictionResult(
      success: false,
      predictedClass: 'Unknown',
      confidence: 0.42,
      isLowConfidence: true,
      severity: 'Moderate',
      severityLevel: 1,
      isHealthy: false,
      scientificName: '',
      summary: '',
      symptoms: const [],
      treatment: const [],
      prevention: const [],
      advisory: const [],
      favorableConditions: '',
      latencyMs: 12,
      modelName: 'test-model',
      engine: 'ONNX Runtime',
    );

Future<HistoryController> _pumpAnalysis(
  WidgetTester tester, {
  required Future<PredictionResult> Function() onPredict,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final storage = StorageService(prefs);
  final history = HistoryController(storage);
  final api = _FakeApiService(storage, onPredict);
  final connection = ConnectionController(api, storage);

  await tester.pumpWidget(
    MaterialApp(
      home: AiAnalysisScreen(
        imageBytes: _tinyPngBytes,
        imageFileName: 'leaf.png',
        storageService: storage,
        connectionController: connection,
        historyController: history,
        apiService: api,
      ),
    ),
  );

  // Advance past the 400ms staged delay, then past the 600ms fake response.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 450));
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pumpAndSettle();

  // Dispose the controller to cancel its 30s periodic health-check timer, which
  // would otherwise trip the framework's "no pending timers" invariant.
  connection.dispose();
  return history;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AiAnalysisScreen rejection handling', () {
    testWidgets('valid cotton prediction follows the normal result flow', (tester) async {
      final history = await _pumpAnalysis(tester, onPredict: _delayedSuccess);

      // Navigated to the diagnosis result screen and persisted exactly one scan.
      expect(find.text('Analysis Result'), findsOneWidget);
      expect(find.text('Bacterial Blight'), findsWidgets);
      expect(history.totalScans, 1);
    });

    testWidgets('unsuccessful prediction never becomes a disease diagnosis or history entry', (tester) async {
      final history = await _pumpAnalysis(tester, onPredict: _delayedUnsuccessful);

      // Must NOT navigate to a diagnosis result and must NOT show a disease.
      expect(find.text('Analysis Result'), findsNothing);
      expect(find.text('Disease Detected'), findsNothing);
      expect(find.text('Bacterial Blight'), findsNothing);

      // Rejection UI with a clear retry action.
      expect(find.text('Diagnosis Unclear'), findsOneWidget);
      expect(find.text('Retake Photo'), findsOneWidget);

      // Nothing persisted to history.
      expect(history.totalScans, 0);
    });

    testWidgets('UNCERTAIN rejection response displays retry state and is not saved', (tester) async {
      final history = await _pumpAnalysis(
        tester,
        onPredict: () => _delayedThrow(
          'UNCERTAIN',
          'Unable to confirm a reliable diagnosis. Please retake a clear photo.',
        ),
      );

      expect(find.text('Diagnosis Unclear'), findsOneWidget);
      expect(find.text('Retake Photo'), findsOneWidget);
      expect(find.text('Disease Detected'), findsNothing);
      expect(history.totalScans, 0);
    });

    testWidgets('NON_COTTON rejection remains correctly handled', (tester) async {
      final history = await _pumpAnalysis(
        tester,
        onPredict: () => _delayedThrow(
          'NON_COTTON',
          'This image does not appear to contain a cotton leaf.',
        ),
      );

      expect(find.text('Not a Cotton Leaf'), findsOneWidget);
      expect(history.totalScans, 0);
    });

    testWidgets('POOR_QUALITY rejection remains correctly handled', (tester) async {
      final history = await _pumpAnalysis(
        tester,
        onPredict: () => _delayedThrow(
          'POOR_QUALITY',
          'Image is too blurry or out of focus.',
        ),
      );

      expect(find.text('Image Needs a Clearer View'), findsOneWidget);
      expect(history.totalScans, 0);
    });
  });
}
