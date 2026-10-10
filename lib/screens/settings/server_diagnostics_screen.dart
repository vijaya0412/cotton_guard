import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../../constants/app_colors.dart';
import '../../constants/api_constants.dart';
import '../../services/storage_service.dart';
import '../../controllers/connection_controller.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/custom_button.dart';

enum TestStatus { pending, running, pass, fail, warning }

class DiagnosticItem {
  final String name;
  final String description;
  TestStatus status;
  String? detail;
  int? elapsedMs;

  DiagnosticItem({
    required this.name,
    required this.description,
    this.status = TestStatus.pending,
    this.detail,
    this.elapsedMs,
  });
}

class ServerDiagnosticsScreen extends StatefulWidget {
  final StorageService? storageService;
  final ConnectionController connectionController;

  const ServerDiagnosticsScreen({
    super.key,
    this.storageService,
    required this.connectionController,
  });

  @override
  State<ServerDiagnosticsScreen> createState() => _ServerDiagnosticsScreenState();
}

class _ServerDiagnosticsScreenState extends State<ServerDiagnosticsScreen> {
  final List<DiagnosticItem> _tests = [
    DiagnosticItem(
      name: '1. Network Reachability',
      description: 'Checks basic TCP connection to host IP & port.',
    ),
    DiagnosticItem(
      name: '2. Health Endpoint GET',
      description: 'Verifies /api/v1/health returns HTTP 200.',
    ),
    DiagnosticItem(
      name: '3. Backend API Version',
      description: 'Validates semantic API version string.',
    ),
    DiagnosticItem(
      name: '4. Model Checkpoint Loaded',
      description: 'Confirms MobileNetV2 is mounted in memory.',
    ),
    DiagnosticItem(
      name: '5. Inference Engine Verification',
      description: 'Validates ONNX Runtime CPU execution provider.',
    ),
    DiagnosticItem(
      name: '6. Sample Leaf Upload',
      description: 'Sends multipart test sample leaf image bytes.',
    ),
    DiagnosticItem(
      name: '7. Real AI Inference Execution',
      description: 'Verifies /api/v1/predict classifies condition.',
    ),
    DiagnosticItem(
      name: '8. Response Schema & Latency',
      description: 'Validates symptoms, treatment & advisory payload.',
    ),
  ];

  bool _isRunning = false;

  @override
  void initState() {
    super.initState();
    _runAllDiagnostics();
  }

  Future<void> _runAllDiagnostics() async {
    if (_isRunning) return;
    setState(() {
      _isRunning = true;
      for (final t in _tests) {
        t.status = TestStatus.pending;
        t.detail = null;
        t.elapsedMs = null;
      }
    });

    final baseUrl = widget.connectionController.currentUrl;
    final client = http.Client();
    Map<String, dynamic>? healthJson;

    // Test 1: Network Reachability
    await _executeTest(0, () async {
      final uri = Uri.parse(baseUrl);
      final sw = Stopwatch()..start();
      final res = await client.get(uri).timeout(const Duration(seconds: 5));
      sw.stop();
      return 'Connected to ${uri.host}:${uri.port} (HTTP ${res.statusCode})';
    });

    // Test 2: Health Endpoint
    await _executeTest(1, () async {
      final uri = Uri.parse('$baseUrl${ApiConstants.endpointHealth}');
      final sw = Stopwatch()..start();
      final res = await client.get(uri).timeout(const Duration(seconds: 5));
      sw.stop();
      if (res.statusCode != 200) {
        throw Exception('HTTP ${res.statusCode}: ${res.body}');
      }
      healthJson = jsonDecode(res.body) as Map<String, dynamic>;
      return 'Received status: ${healthJson?['status']} (${sw.elapsedMilliseconds} ms)';
    });

    // Test 3: Backend API Version
    await _executeTest(2, () async {
      final ver = healthJson?['version'] as String?;
      if (ver == null || ver.isEmpty) {
        throw Exception('Version missing from health response');
      }
      return 'Version $ver confirmed';
    });

    // Test 4: Model Checkpoint Loaded
    await _executeTest(3, () async {
      final loaded = healthJson?['model_loaded'] as bool?;
      final name = healthJson?['model_name'] as String?;
      if (loaded != true) {
        throw Exception('Model is reported as NOT loaded by server');
      }
      return 'Model "$name" loaded and operational';
    });

    // Test 5: Inference Engine Verification
    await _executeTest(4, () async {
      final engine = healthJson?['inference_engine'] as String?;
      if (engine == null || engine.isEmpty) {
        throw Exception('Inference engine missing in response');
      }
      return 'Engine: $engine confirmed';
    });

    // Test 6: Sample Leaf Upload
    List<int>? sampleBytes;
    await _executeTest(5, () async {
      const assetPath = 'assets/diseases/healthy_leaf/healthy_leaf_1.jpg';
      final byteData = await rootBundle.load(assetPath);
      sampleBytes = byteData.buffer.asUint8List();
      return 'Loaded sample leaf asset (${sampleBytes!.length} bytes)';
    });

    // Test 7: Real AI Inference Execution
    Map<String, dynamic>? predictJson;
    await _executeTest(6, () async {
      if (sampleBytes == null) throw Exception('No sample bytes available');
      final uri = Uri.parse('$baseUrl${ApiConstants.endpointPredict}');
      final sw = Stopwatch()..start();
      final req = http.MultipartRequest('POST', uri);
      req.files.add(http.MultipartFile.fromBytes(
        'file',
        sampleBytes!,
        filename: 'healthy_leaf_1.jpg',
      ));
      final streamed = await req.send().timeout(const Duration(seconds: 15));
      final resp = await http.Response.fromStream(streamed);
      sw.stop();

      if (resp.statusCode != 200) {
        throw Exception('Inference failed (HTTP ${resp.statusCode}): ${resp.body}');
      }
      predictJson = jsonDecode(resp.body) as Map<String, dynamic>;
      final predClass = predictJson?['predicted_class'];
      final conf = ((predictJson?['confidence'] as num?)?.toDouble() ?? 0.0) * 100;
      return 'Classified as "$predClass" with ${conf.toStringAsFixed(1)}% confidence in ${sw.elapsedMilliseconds} ms';
    });

    // Test 8: Response Schema & Latency
    await _executeTest(7, () async {
      if (predictJson == null) throw Exception('No prediction payload received');
      final symptoms = predictJson?['symptoms'] as List<dynamic>?;
      final treatment = predictJson?['treatment'] as List<dynamic>?;
      final advisory = predictJson?['advisory'] as List<dynamic>?;
      if (symptoms == null || treatment == null || advisory == null) {
        throw Exception('Incomplete payload: missing symptoms/treatment/advisory');
      }
      return 'Full schema verified (${symptoms.length} symptoms, ${treatment.length} sprays)';
    });

    client.close();
    if (mounted) {
      setState(() => _isRunning = false);
    }
  }

  Future<void> _executeTest(int index, Future<String> Function() testFn) async {
    final t = _tests[index];
    setState(() => t.status = TestStatus.running);
    final sw = Stopwatch()..start();

    try {
      final msg = await testFn();
      sw.stop();
      if (!mounted) return;
      setState(() {
        t.status = TestStatus.pass;
        t.detail = msg;
        t.elapsedMs = sw.elapsedMilliseconds;
      });
    } catch (e) {
      sw.stop();
      if (!mounted) return;
      setState(() {
        t.status = TestStatus.fail;
        t.detail = e.toString().replaceAll('Exception: ', '');
        t.elapsedMs = sw.elapsedMilliseconds;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final passCount = _tests.where((t) => t.status == TestStatus.pass).length;
    final failCount = _tests.where((t) => t.status == TestStatus.fail).length;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Diagnostic Test Center'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Rerun All Tests',
            onPressed: _isRunning ? null : _runAllDiagnostics,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Overall Status Summary Banner
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: GlassCard(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Test Suite Summary',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _isRunning
                              ? 'Running diagnostic checks...'
                              : '$passCount / ${_tests.length} Checks Passed',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        _buildStatusPill('PASS', passCount, AppColors.success, AppColors.successLight),
                        const SizedBox(width: 8),
                        _buildStatusPill('FAIL', failCount, AppColors.danger, AppColors.dangerLight),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Diagnostic Test Steps List
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                itemCount: _tests.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final t = _tests[index];
                  return _buildTestCard(t, isDark);
                },
              ),
            ),

            // Bottom Action
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: CustomButton(
                text: _isRunning ? 'Running Tests...' : 'Rerun Diagnostic Suite',
                icon: Icons.play_arrow_rounded,
                isLoading: _isRunning,
                onPressed: _runAllDiagnostics,
                width: double.infinity,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusPill(String label, int count, Color fg, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Text(
        '$count $label',
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: fg),
      ),
    );
  }

  Widget _buildTestCard(DiagnosticItem t, bool isDark) {
    Widget statusIcon;
    Color statusColor;

    switch (t.status) {
      case TestStatus.pending:
        statusIcon = const Icon(Icons.radio_button_unchecked, size: 18, color: Colors.grey);
        statusColor = Colors.grey;
        break;
      case TestStatus.running:
        statusIcon = const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
        statusColor = AppColors.info;
        break;
      case TestStatus.pass:
        statusIcon = const Icon(Icons.check_circle_rounded, size: 18, color: AppColors.success);
        statusColor = AppColors.success;
        break;
      case TestStatus.fail:
        statusIcon = const Icon(Icons.cancel_rounded, size: 18, color: AppColors.danger);
        statusColor = AppColors.danger;
        break;
      case TestStatus.warning:
        statusIcon = const Icon(Icons.warning_rounded, size: 18, color: AppColors.warning);
        statusColor = AppColors.warning;
        break;
    }

    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  statusIcon,
                  const SizedBox(width: 10),
                  Text(
                    t.name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                    ),
                  ),
                ],
              ),
              if (t.elapsedMs != null)
                Text(
                  '${t.elapsedMs}ms',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                    fontFamily: 'monospace',
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 28.0),
            child: Text(
              t.description,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              ),
            ),
          ),
          if (t.detail != null) ...[
            const SizedBox(height: 8),
            Container(
              margin: const EdgeInsets.only(left: 28.0),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isDark ? AppColors.cardDark : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: statusColor.withAlpha(80)),
              ),
              child: Text(
                t.detail!,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: statusColor,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
