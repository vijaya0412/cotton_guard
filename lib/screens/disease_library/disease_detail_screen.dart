import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../constants/canonical_classes.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/status_badge.dart';

class DiseaseDetailScreen extends StatefulWidget {
  final String className;

  const DiseaseDetailScreen({super.key, required this.className});

  @override
  State<DiseaseDetailScreen> createState() => _DiseaseDetailScreenState();
}

class _DiseaseDetailScreenState extends State<DiseaseDetailScreen> {
  int _selectedImageIndex = 0;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final details = CanonicalClasses.diseaseDetails[widget.className]!;
    final images = CanonicalClasses.getSampleAssetImages(widget.className);

    final scientificName = details['scientificName'] as String;
    final severity = details['severity'] as String;
    final severityLevel = details['severityLevel'] as int;
    final isHealthy = details['isHealthy'] as bool;
    final summary = details['summary'] as String;
    final symptoms = details['symptoms'] as List<String>;
    final treatment = details['treatment'] as List<String>;
    final prevention = details['prevention'] as List<String>;
    final favorableConditions = details['favorableConditions'] as String;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      appBar: AppBar(
        title: Text(widget.className),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 14.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Main High-Res Image Display
              Container(
                height: 240,
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
                      Image.asset(
                        images.isNotEmpty ? images[_selectedImageIndex] : 'assets/images/cotton_guard_logo.png',
                        fit: BoxFit.cover,
                      ),
                      Positioned(
                        top: 12,
                        right: 12,
                        child: StatusBadge.severity(severity, severityLevel),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Thumbnail Selector (all 4 verified leaf images)
              if (images.length > 1) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(images.length, (index) {
                    final isSelected = _selectedImageIndex == index;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedImageIndex = index),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 5),
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected
                                ? (isDark ? AppColors.secondary : AppColors.primary)
                                : Colors.transparent,
                            width: 2.2,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.asset(images[index], fit: BoxFit.cover),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 20),
              ],

              // Scientific Profile Header
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
                            widget.className,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isHealthy ? AppColors.successLight : AppColors.dangerLight,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            isHealthy ? 'HEALTHY LEAF' : 'DISEASE / DEFICIENCY',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: isHealthy ? AppColors.success : AppColors.danger,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      scientificName,
                      style: TextStyle(
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      summary,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.45,
                        color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Symptoms
              GlassCard(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.biotech_outlined, color: isDark ? AppColors.secondary : AppColors.primary, size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          'Symptom Manifestations',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...symptoms.map((s) => Padding(
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

              // Recommended Treatments
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
                          'Recommended Management & Sprays',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...treatment.map((t) => Padding(
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

              // Cultural Prevention
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
                          'Prevention & IPM Cultural Practices',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...prevention.map((p) => Padding(
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
              const SizedBox(height: 16),

              // Favorable Conditions
              GlassCard(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.thermostat_outlined, color: AppColors.warning, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Favorable Climatic Conditions',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            favorableConditions,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
