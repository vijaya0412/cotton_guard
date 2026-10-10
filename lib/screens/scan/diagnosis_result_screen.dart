import 'dart:io';
import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../models/prediction_result.dart';
import '../../services/storage_service.dart';
import '../../controllers/history_controller.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/glass_card.dart';
import '../disease_library/disease_detail_screen.dart';

class DiagnosisResultScreen extends StatefulWidget {
  final PredictionResult result;
  final dynamic imageSource; // File or String (asset path)
  final StorageService storageService;
  final HistoryController historyController;

  const DiagnosisResultScreen({
    super.key,
    required this.result,
    required this.imageSource,
    required this.storageService,
    required this.historyController,
  });

  @override
  State<DiagnosisResultScreen> createState() => _DiagnosisResultScreenState();
}

class _DiagnosisResultScreenState extends State<DiagnosisResultScreen>
    with SingleTickerProviderStateMixin {
  int _selectedTabIndex = 0; // 0 = Overview, 1 = Symptoms, 2 = Treatment

  late AnimationController _animController;
  late Animation<double> _imageAnim;
  late Animation<double> _badgeAnim;
  late Animation<Offset> _titleSlideAnim;
  late Animation<double> _titleFadeAnim;
  late Animation<double> _pillsAnim;
  late Animation<double> _contentAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    // 1. Image fades/scales in (0.0 -> 0.35)
    _imageAnim = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.0, 0.35, curve: Curves.easeOut),
    );

    // 2. Disease badge appears (0.2 -> 0.5)
    _badgeAnim = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.2, 0.5, curve: Curves.easeIn),
    );

    // 3. Disease name slides upward (0.3 -> 0.6)
    _titleSlideAnim = Tween<Offset>(
      begin: const Offset(0.0, 0.25),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.3, 0.6, curve: Curves.easeOutCubic),
      ),
    );
    _titleFadeAnim = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.3, 0.6, curve: Curves.easeIn),
    );

    // 4. Confidence & severity pills animate in (0.45 -> 0.75)
    _pillsAnim = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.45, 0.75, curve: Curves.easeOut),
    );

    // 5. Tab content fades in (0.6 -> 1.0)
    _contentAnim = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.6, 1.0, curve: Curves.easeIn),
    );

    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _shareResult() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Diagnosis report ready to share with agronomy advisor.'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final res = widget.result;

    Widget imageWidget;
    if (widget.imageSource is File) {
      imageWidget = Image.file(widget.imageSource as File, fit: BoxFit.cover);
    } else if (widget.imageSource is String) {
      imageWidget = Image.asset(widget.imageSource as String, fit: BoxFit.cover);
    } else {
      imageWidget = Container(color: Colors.grey.shade300);
    }

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Analysis Result'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Share Diagnosis',
            onPressed: _shareResult,
          ),
          IconButton(
            icon: const Icon(Icons.bookmark_border_rounded),
            tooltip: 'Saved to History',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Scan saved to persistent local history.'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 14.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Image Thumbnail with Staggered Fade/Scale
              FadeTransition(
                opacity: _imageAnim,
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.94, end: 1.0).animate(_imageAnim),
                  child: Container(
                    height: 210,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(isDark ? 80 : 25),
                          blurRadius: 16,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          imageWidget,
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withAlpha(140),
                                ],
                              ),
                            ),
                          ),
                          // Low confidence tag if applicable
                          if (res.isLowConfidence)
                            Positioned(
                              top: 12,
                              left: 12,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.warning,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  'Low Confidence Scan',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // 2. Disease Status Badge (Disease Detected / Healthy)
              FadeTransition(
                opacity: _badgeAnim,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: res.isHealthy
                          ? const Color(0xFFE8F5E9)
                          : const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: res.isHealthy
                                ? const Color(0xFF2E7D32)
                                : const Color(0xFFDC2626),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 7),
                        Text(
                          res.isHealthy ? 'Healthy Leaf' : 'Disease Detected',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                            color: res.isHealthy
                                ? const Color(0xFF2E7D32)
                                : const Color(0xFFDC2626),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // 3. Disease Name & Scientific Name (Sliding Upward)
              SlideTransition(
                position: _titleSlideAnim,
                child: FadeTransition(
                  opacity: _titleFadeAnim,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        res.predictedClass,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                          color: isDark
                              ? AppColors.textPrimaryDark
                              : AppColors.textPrimaryLight,
                        ),
                      ),
                      if (res.scientificName.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          res.scientificName,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontStyle: FontStyle.italic,
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // 4. Confidence & Severity Pills
              FadeTransition(
                opacity: _pillsAnim,
                child: Row(
                  children: [
                    // Confidence Pill
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.surfaceDark : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark
                              ? AppColors.borderDark
                              : AppColors.borderLight,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.psychology_outlined,
                            size: 15,
                            color: isDark
                                ? AppColors.secondary
                                : AppColors.primary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${(res.confidence * 100).toStringAsFixed(1)}% Confidence',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? AppColors.textPrimaryDark
                                  : AppColors.textPrimaryLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Severity Pill
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.surfaceDark : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark
                              ? AppColors.borderDark
                              : AppColors.borderLight,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            res.isHealthy
                                ? Icons.verified_rounded
                                : Icons.warning_amber_rounded,
                            size: 15,
                            color: res.isHealthy
                                ? const Color(0xFF2E7D32)
                                : AppColors.warning,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${res.severity} Severity',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? AppColors.textPrimaryDark
                                  : AppColors.textPrimaryLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // 5. Tabs: Overview, Symptoms, Treatment
              FadeTransition(
                opacity: _contentAnim,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.surfaceDark : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      _buildTabItem(0, 'Overview', isDark),
                      _buildTabItem(1, 'Symptoms', isDark),
                      _buildTabItem(2, 'Treatment', isDark),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 6. Tab Content Cards (Staggered Fade-in)
              FadeTransition(
                opacity: _contentAnim,
                child: _buildCurrentTabContent(isDark),
              ),
              const SizedBox(height: 24),

              // Action Buttons
              CustomButton(
                text: 'View Full Advisory Guide',
                icon: Icons.menu_book_rounded,
                variant: ButtonVariant.secondary,
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => DiseaseDetailScreen(
                        className: res.predictedClass,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),
              CustomButton(
                text: 'Back to Home Dashboard',
                icon: Icons.home_rounded,
                onPressed: () {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabItem(int index, String label, bool isDark) {
    final isSelected = _selectedTabIndex == index;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTabIndex = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? const Color(0xFF2A3D33) : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected && !isDark
                ? [
                    BoxShadow(
                      color: Colors.black.withAlpha(8),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [],
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected
                  ? (isDark ? AppColors.secondary : AppColors.primary)
                  : (isDark
                      ? AppColors.textMutedDark
                      : AppColors.textMutedLight),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentTabContent(bool isDark) {
    final res = widget.result;

    switch (_selectedTabIndex) {
      case 0:
        // Overview Tab
        return GlassCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'About this disease',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimaryLight,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                res.summary.isNotEmpty
                    ? res.summary
                    : 'Condition detected with high model certainty on cotton foliage.',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
              ),
              if (res.favorableConditions.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.wb_sunny_outlined,
                        size: 18, color: AppColors.accent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Favorable Field Conditions',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? AppColors.textPrimaryDark
                                  : AppColors.textPrimaryLight,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            res.favorableConditions,
                            style: TextStyle(
                              fontSize: 12.5,
                              height: 1.4,
                              color: isDark
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondaryLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );

      case 1:
        // Symptoms Tab
        return GlassCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Identified Symptoms',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimaryLight,
                ),
              ),
              const SizedBox(height: 12),
              if (res.symptoms.isEmpty)
                Text(
                  'No abnormal symptoms observed.',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark
                        ? AppColors.textMutedDark
                        : AppColors.textMutedLight,
                  ),
                )
              else
                ...res.symptoms.map((symptom) => Padding(
                      padding: const EdgeInsets.only(bottom: 10.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: isDark
                                    ? AppColors.secondary
                                    : AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              symptom,
                              style: TextStyle(
                                fontSize: 13.5,
                                height: 1.4,
                                color: isDark
                                    ? AppColors.textSecondaryDark
                                    : AppColors.textSecondaryLight,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )),
            ],
          ),
        );

      case 2:
      default:
        // Treatment Tab
        return GlassCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Immediate Management & Sprays',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimaryLight,
                ),
              ),
              const SizedBox(height: 12),
              if (res.treatment.isEmpty)
                Text(
                  'Standard crop maintenance applies.',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark
                        ? AppColors.textMutedDark
                        : AppColors.textMutedLight,
                  ),
                )
              else
                ...res.treatment.map((t) => Padding(
                      padding: const EdgeInsets.only(bottom: 10.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.check_circle_outline,
                              size: 16, color: Color(0xFF2E7D32)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              t,
                              style: TextStyle(
                                fontSize: 13.5,
                                height: 1.4,
                                color: isDark
                                    ? AppColors.textSecondaryDark
                                    : AppColors.textSecondaryLight,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )),
            ],
          ),
        );
    }
  }
}
