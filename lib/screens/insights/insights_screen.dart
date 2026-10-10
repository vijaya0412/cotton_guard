import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../controllers/history_controller.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/empty_state_view.dart';

class InsightsScreen extends StatelessWidget {
  final HistoryController historyController;

  const InsightsScreen({super.key, required this.historyController});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Field AI Insights'),
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: historyController,
          builder: (context, _) {
            final total = historyController.totalScans;

            if (total == 0) {
              return const EmptyStateView(
                icon: Icons.analytics_outlined,
                title: 'No Diagnosis Data Yet',
                description:
                    'Agronomic insights, healthy ratios, and condition distributions are computed dynamically as you scan cotton leaves in your fields.',
              );
            }

            final healthy = historyController.healthyScans;
            final diseased = historyController.diseasedScans;
            final lowConf = historyController.lowConfidenceScans;
            final healthyPct = historyController.healthyPercentage;
            final distribution = historyController.diseaseDistribution;
            final mostDetected = historyController.mostDetectedCondition;

            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Overview Stats Header
                  Text(
                    'Field Health Summary',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                    ),
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: GlassCard(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$total',
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Total Scans',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GlassCard(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${healthyPct.toStringAsFixed(1)}%',
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.success,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Healthy Ratio ($healthy)',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: GlassCard(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$diseased',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.danger,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Disease Incidents',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GlassCard(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$lowConf',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.warning,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Low Confidence',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Most Detected Condition Banner
                  GlassCard(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withAlpha(25),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.star_rounded, color: AppColors.accent, size: 24),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Most Detected Condition',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                mostDetected,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Condition Distribution Breakdown
                  Text(
                    'Condition Occurrence Breakdown',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                    ),
                  ),
                  const SizedBox(height: 12),

                  GlassCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: distribution.entries.map((entry) {
                        final diseaseName = entry.key;
                        final count = entry.value;
                        final fraction = count / total;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      diseaseName,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '$count ($categoryPctStr(fraction))',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: isDark ? AppColors.secondary : AppColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: fraction,
                                  minHeight: 7,
                                  backgroundColor: isDark ? AppColors.surfaceDark : Colors.grey.shade200,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    diseaseName == 'Healthy Leaf'
                                        ? AppColors.success
                                        : (isDark ? AppColors.secondary : AppColors.primary),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  String categoryPctStr(double fraction) {
    return '${(fraction * 100).toStringAsFixed(0)}%';
  }
}
