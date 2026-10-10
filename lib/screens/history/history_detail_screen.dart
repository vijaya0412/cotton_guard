import 'dart:io';
import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../models/scan_record.dart';
import '../../controllers/history_controller.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/custom_button.dart';

class HistoryDetailScreen extends StatelessWidget {
  final ScanRecord record;
  final HistoryController historyController;

  const HistoryDetailScreen({
    super.key,
    required this.record,
    required this.historyController,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget imageWidget;
    if (record.imagePath.startsWith('assets/')) {
      imageWidget = Image.asset(record.imagePath, fit: BoxFit.cover);
    } else {
      final f = File(record.imagePath);
      imageWidget = f.existsSync()
          ? Image.file(f, fit: BoxFit.cover)
          : Image.asset('assets/images/cotton_guard_logo.png', fit: BoxFit.contain);
    }

    final dateStr =
        '${record.timestamp.day.toString().padLeft(2, '0')}/${record.timestamp.month.toString().padLeft(2, '0')}/${record.timestamp.year} at ${record.timestamp.hour.toString().padLeft(2, '0')}:${record.timestamp.minute.toString().padLeft(2, '0')}';

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Scan Record Detail'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
            tooltip: 'Delete Record',
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Delete Record?'),
                  content: const Text('Do you want to permanently delete this scan?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: const Text('Delete', style: TextStyle(color: AppColors.danger)),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                await historyController.deleteScan(record.id);
                if (context.mounted) Navigator.of(context).pop();
              }
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Image Container
              Container(
                height: 230,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(20),
                      blurRadius: 15,
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
                      Positioned(
                        bottom: 12,
                        left: 12,
                        right: 12,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            StatusBadge.confidence(record.confidence),
                            StatusBadge.severity(record.severity, record.severityLevel),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Disease Title & Date Card
              GlassCard(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            record.predictedClass,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: record.isHealthy ? AppColors.successLight : AppColors.dangerLight,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            record.isHealthy ? 'HEALTHY' : 'DISEASE DETECTED',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: record.isHealthy ? AppColors.success : AppColors.danger,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.calendar_today_outlined, size: 13, color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight),
                        const SizedBox(width: 6),
                        Text(
                          dateStr,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Symptoms
              if (record.symptoms.isNotEmpty) ...[
                GlassCard(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.biotech_outlined, color: isDark ? AppColors.secondary : AppColors.primary, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Recorded Symptoms',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ...record.symptoms.map((s) => Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(top: 4.0),
                                  child: Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: isDark ? AppColors.secondary : AppColors.primary,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    s,
                                    style: TextStyle(
                                      fontSize: 13,
                                      height: 1.4,
                                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Treatment
              if (record.treatment.isNotEmpty) ...[
                GlassCard(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.healing_outlined, color: AppColors.accent, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Management & Spray Guidance',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ...record.treatment.map((t) => Padding(
                            padding: const EdgeInsets.only(bottom: 10.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.check_circle_outline, size: 16, color: AppColors.success),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    t,
                                    style: TextStyle(
                                      fontSize: 13,
                                      height: 1.4,
                                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Prevention
              if (record.prevention.isNotEmpty) ...[
                GlassCard(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.shield_outlined, color: AppColors.info, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Field Sanitation & Prevention',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ...record.prevention.map((p) => Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.arrow_right_rounded, size: 20, color: AppColors.info),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    p,
                                    style: TextStyle(
                                      fontSize: 13,
                                      height: 1.4,
                                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],

              CustomButton(
                text: 'Done',
                onPressed: () => Navigator.of(context).pop(),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
