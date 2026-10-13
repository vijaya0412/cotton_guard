import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../constants/app_colors.dart';
import '../../models/prediction_result.dart';
import '../../models/scan_record.dart';
import '../../services/storage_service.dart';
import '../../services/api_service.dart';
import '../../controllers/connection_controller.dart';
import '../../controllers/history_controller.dart';
import '../../widgets/error_state_view.dart';
import '../settings/server_connection_screen.dart';
import 'diagnosis_result_screen.dart';

class AiAnalysisScreen extends StatefulWidget {
  final File? imageFile;
  final String? assetPath;

  /// Optional in-memory image payload. When provided it takes precedence over
  /// [imageFile]/[assetPath] and is used for deterministic capture sources
  /// (e.g. tests or future in-memory camera APIs).
  final List<int>? imageBytes;
  final String? imageFileName;

  final StorageService storageService;
  final ConnectionController connectionController;
  final HistoryController historyController;

  /// Optional injected API client. Defaults to a real [ApiService] in production
  /// and allows tests to supply deterministic responses without network access.
  final ApiService? apiService;

  const AiAnalysisScreen({
    super.key,
    this.imageFile,
    this.assetPath,
    this.imageBytes,
    this.imageFileName,
    required this.storageService,
    required this.connectionController,
    required this.historyController,
    this.apiService,
  });

  @override
  State<AiAnalysisScreen> createState() => _AiAnalysisScreenState();
}

class _AiAnalysisScreenState extends State<AiAnalysisScreen>
    with SingleTickerProviderStateMixin {
  late final ApiService _apiService;

  // Stages: 0 = Inspecting leaf surface, 1 = Verifying cotton foliage, 2 = Evaluating disease biomarkers, 3 = Finalizing agronomic advisory
  int _currentStageIndex = 0;
  bool _isProcessing = true;
  bool _isCancelled = false;
  Object? _error;

  // Single calm rotation controller for the progress ring
  late final AnimationController _ringController;

  final List<String> _stages = [
    'Inspecting leaf surface...',
    'Verifying cotton foliage...',
    'Evaluating disease biomarkers...',
    'Finalizing agronomic advisory...',
  ];

  @override
  void initState() {
    super.initState();
    _apiService = widget.apiService ?? ApiService(widget.storageService);

    // Single calm animation for smooth 60fps rendering without raster shadow repaint
    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();

    _runAnalysisPipeline();
  }

  @override
  void dispose() {
    _isCancelled = true;
    _ringController.dispose();
    super.dispose();
  }

  void _handleCancel() {
    _isCancelled = true;
    Navigator.of(context).pop();
  }

  Future<void> _runAnalysisPipeline() async {
    try {
      if (!mounted || _isCancelled) return;
      if (widget.connectionController.health.isStopped) {
        throw ApiException('Cotton Guard AI inference service is currently paused by the administrator. Please try again later.');
      }
      setState(() => _currentStageIndex = 0);

      // Read image bytes
      List<int> bytes;
      String fileName;
      if (widget.imageBytes != null) {
        bytes = widget.imageBytes!;
        fileName = widget.imageFileName ?? 'capture.jpg';
      } else if (widget.imageFile != null) {
        bytes = await widget.imageFile!.readAsBytes();
        fileName = widget.imageFile!.path.split(Platform.pathSeparator).last;
      } else {
        final byteData = await rootBundle.load(widget.assetPath!);
        bytes = byteData.buffer.asUint8List();
        fileName = widget.assetPath!.split('/').last;
      }

      if (!mounted || _isCancelled) return;
      setState(() => _currentStageIndex = 1);

      // Send to FastAPI inference endpoint
      final Future<PredictionResult> predictionFuture = _apiService.predictDisease(
        imageBytes: bytes,
        fileName: fileName,
      );

      // Transition to stage 2 while awaiting prediction
      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted || _isCancelled) return;
      setState(() => _currentStageIndex = 2);

      final PredictionResult result = await predictionFuture;
      if (!mounted || _isCancelled) return;

      // Safety guard: a non-successful response must never be rendered as a
      // disease diagnosis nor persisted to scan history. Surface it through the
      // same rejection UI used for NON_COTTON / POOR_QUALITY.
      if (!result.success) {
        throw ValidationException(
          'The diagnosis could not be confirmed for this image. '
          'Please retake a clear, well-lit photo of a single cotton leaf.',
          code: 'UNCERTAIN',
        );
      }

      // Final stage: advisory finalization
      setState(() => _currentStageIndex = 3);

      // Save to local scan history asynchronously
      final scanRecord = ScanRecord.fromPrediction(
        id: 'scan_${DateTime.now().millisecondsSinceEpoch}',
        imagePath: widget.imageFile?.path ?? widget.assetPath ?? 'memory://capture',
        result: result,
      );
      await widget.historyController.addScan(scanRecord);

      if (!mounted || _isCancelled) return;

      _ringController.stop();

      // Navigate smoothly to results screen
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 350),
          pageBuilder: (context, animation, secondaryAnimation) =>
              DiagnosisResultScreen(
            result: result,
            imageSource: widget.imageFile ?? widget.assetPath,
            storageService: widget.storageService,
            historyController: widget.historyController,
          ),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      );
    } catch (err) {
      if (!mounted || _isCancelled) return;
      _ringController.stop();
      setState(() {
        _isProcessing = false;
        _error = err;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final imageSource = widget.imageFile ?? widget.assetPath;

    return PopScope(
      canPop: !_isProcessing,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _handleCancel();
        }
      },
      child: Scaffold(
        backgroundColor:
            isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
        appBar: AppBar(
          title: const Text('Analyzing Leaf'),
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: _handleCancel,
          ),
        ),
        body: SafeArea(
          child: Center(
            child: _isProcessing
                ? SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 26.0, vertical: 20.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // RepaintBoundary isolates animation repaint from entire screen tree
                        RepaintBoundary(
                          child: SizedBox(
                            width: 220,
                            height: 220,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // Single calm spinning progress ring
                                RotationTransition(
                                  turns: _ringController,
                                  child: SizedBox(
                                    width: 216,
                                    height: 216,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 3.5,
                                      strokeCap: StrokeCap.round,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        isDark
                                            ? AppColors.secondary
                                            : AppColors.primary,
                                      ),
                                      backgroundColor: isDark
                                          ? AppColors.borderDark
                                          : AppColors.borderLight,
                                    ),
                                  ),
                                ),

                                // Clean static circular image with hardware-accelerated downscaled cache
                                Container(
                                  width: 190,
                                  height: 190,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isDark
                                          ? AppColors.borderDark
                                          : AppColors.borderLight,
                                      width: 2,
                                    ),
                                  ),
                                  child: ClipOval(
                                    child: _buildImage(imageSource),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Title
                        Text(
                          'Analyzing with AI',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                            color: isDark
                                ? AppColors.textPrimaryDark
                                : AppColors.textPrimaryLight,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Current active status caption
                        Text(
                          _stages[_currentStageIndex.clamp(0, _stages.length - 1)],
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.4,
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
                          ),
                        ),
                        if (_currentStageIndex >= 1) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Connecting to AI backend (cloud instances may take up to 45s if waking from sleep)...',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? AppColors.textMutedDark
                                  : AppColors.textMutedLight,
                            ),
                          ),
                        ],
                        const SizedBox(height: 26),

                        // Stages Card
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 16),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.surfaceDark : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isDark
                                  ? AppColors.borderDark
                                  : AppColors.borderLight,
                              width: 1,
                            ),
                          ),
                          child: Column(
                            children: List.generate(_stages.length, (index) {
                              return _buildStageRow(index, isDark);
                            }),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Explicit Cancel Action
                        TextButton.icon(
                          onPressed: _handleCancel,
                          icon: const Icon(Icons.cancel_outlined, size: 18),
                          label: const Text(
                            'Cancel Analysis',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            foregroundColor: isDark
                                ? AppColors.textMutedDark
                                : AppColors.textMutedLight,
                          ),
                        ),
                      ],
                    ),
                  )
                : _buildErrorState(context),
          ),
        ),
      ),
    );
  }

  Widget _buildImage(dynamic source) {
    if (source is File) {
      return Image.file(
        source,
        cacheWidth: 600,
        fit: BoxFit.cover,
      );
    } else if (source is String) {
      return Image.asset(
        source,
        cacheWidth: 600,
        fit: BoxFit.cover,
      );
    }
    return Container(color: Colors.grey.shade300);
  }

  Widget _buildStageRow(int index, bool isDark) {
    final title = _stages[index];
    final isDone = _currentStageIndex > index;
    final isCurrent = _currentStageIndex == index;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          // Indicator icon
          if (isDone)
            Container(
              width: 20,
              height: 20,
              decoration: const BoxDecoration(
                color: Color(0xFF2E7D32),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_rounded,
                color: Colors.white,
                size: 13,
              ),
            )
          else if (isCurrent)
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  isDark ? AppColors.secondary : AppColors.primary,
                ),
              ),
            )
          else
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark ? AppColors.borderDark : AppColors.borderLight,
                  width: 1.5,
                ),
              ),
            ),
          const SizedBox(width: 14),

          // Stage Title
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: isCurrent
                    ? FontWeight.w700
                    : (isDone ? FontWeight.w600 : FontWeight.w400),
                color: isDone || isCurrent
                    ? (isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight)
                    : (isDark
                        ? AppColors.textMutedDark
                        : AppColors.textMutedLight),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context) {
    final err = _error;

    if (err is ValidationException) {
      if (err.code == 'POOR_QUALITY') {
        return ErrorStateView.poorQuality(
          message: err.message,
          metrics: err.details,
          onRetake: () => Navigator.of(context).pop(),
          onChooseOther: () => Navigator.of(context).pop(),
        );
      } else if (err.code == 'NON_COTTON') {
        return ErrorStateView.nonCotton(
          message: err.message,
          metrics: err.details,
          onTryAgain: () => Navigator.of(context).pop(),
          onBackToHome: () =>
              Navigator.of(context).popUntil((route) => route.isFirst),
        );
      } else if (err.code == 'UNCERTAIN') {
        return ErrorStateView.uncertain(
          message: err.message,
          metrics: err.details,
          onRetake: () => Navigator.of(context).pop(),
          onBackToHome: () =>
              Navigator.of(context).popUntil((route) => route.isFirst),
        );
      }
    }

    if (err is ApiException &&
        (err.code == 'CONNECTION_REFUSED' || err.code == 'TIMEOUT')) {
      return ErrorStateView.serverOffline(
        message: err.message,
        retryButtonText: 'Retry Leaf Analysis',
        onConfigureServer: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ServerConnectionScreen(
                connectionController: widget.connectionController,
              ),
            ),
          );
        },
        onRetry: () {
          setState(() {
            _isProcessing = true;
            _error = null;
          });
          _runAnalysisPipeline();
        },
      );
    }

    return ErrorStateView(
      type: ErrorType.general,
      title: 'Inference Interrupted',
      message: err?.toString() ?? 'An unexpected error occurred.',
      primaryButtonText: 'Retry Analysis',
      onPrimaryPressed: () {
        setState(() {
          _isProcessing = true;
          _error = null;
        });
        _runAnalysisPipeline();
      },
      secondaryButtonText: 'Back',
      onSecondaryPressed: () => Navigator.of(context).pop(),
    );
  }
}
