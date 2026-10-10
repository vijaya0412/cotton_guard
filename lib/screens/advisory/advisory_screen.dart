import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../constants/canonical_classes.dart';
import '../../services/storage_service.dart';
import '../../services/api_service.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/status_badge.dart';

class AdvisoryScreen extends StatefulWidget {
  final StorageService storageService;
  final ApiService apiService;
  final String? initialDisease;

  const AdvisoryScreen({
    super.key,
    required this.storageService,
    required this.apiService,
    this.initialDisease,
  });

  @override
  State<AdvisoryScreen> createState() => _AdvisoryScreenState();
}

class _AdvisoryScreenState extends State<AdvisoryScreen> {
  late String _selectedDisease;
  int _selectedTabIndex = 0; // 0 = Action Plan, 1 = Treatment, 2 = Prevention

  @override
  void initState() {
    super.initState();
    _selectedDisease = widget.initialDisease ?? CanonicalClasses.bacterialBlight;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final diseaseData =
        CanonicalClasses.diseaseDetails[_selectedDisease] ??
            CanonicalClasses.diseaseDetails[CanonicalClasses.bacterialBlight]!;

    final scientificName = diseaseData['scientificName'] as String;
    final severity = diseaseData['severity'] as String;
    final severityLevel = diseaseData['severityLevel'] as int;
    final treatmentList = diseaseData['treatment'] as List<String>;
    final preventionList = diseaseData['prevention'] as List<String>;
    final symptomsList = diseaseData['symptoms'] as List<String>;
    final leafImage = CanonicalClasses.getPrimaryAssetImage(_selectedDisease);

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Treatment Advisory'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Disease Selector horizontal pill selector
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: CanonicalClasses.all.map((disease) {
                    final isSel = disease == _selectedDisease;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: FilterChip(
                        label: Text(disease),
                        selected: isSel,
                        onSelected: (val) {
                          if (val) setState(() => _selectedDisease = disease);
                        },
                        selectedColor: (isDark
                                ? AppColors.secondary
                                : AppColors.primary)
                            .withAlpha(40),
                        checkmarkColor:
                            isDark ? AppColors.secondary : AppColors.primary,
                        labelStyle: TextStyle(
                          fontSize: 12,
                          fontWeight:
                              isSel ? FontWeight.w700 : FontWeight.w500,
                          color: isSel
                              ? (isDark
                                  ? AppColors.secondary
                                  : AppColors.primary)
                              : (isDark
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondaryLight),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),

              // Top Leaf Image & Disease Header Card
              Container(
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceDark : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark ? AppColors.borderDark : AppColors.borderLight,
                  ),
                  boxShadow: isDark
                      ? []
                      : [
                          BoxShadow(
                            color: Colors.black.withAlpha(8),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Leaf Image
                    ClipRRect(
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(20)),
                      child: SizedBox(
                        height: 180,
                        width: double.infinity,
                        child: Image.asset(leafImage, fit: BoxFit.cover),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  _selectedDisease,
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: isDark
                                        ? AppColors.textPrimaryDark
                                        : AppColors.textPrimaryLight,
                                  ),
                                ),
                              ),
                              StatusBadge.severity(severity, severityLevel),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            scientificName,
                            style: TextStyle(
                              fontSize: 13,
                              fontStyle: FontStyle.italic,
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
              ),
              const SizedBox(height: 18),

              // Tabs: Action Plan | Treatment | Prevention
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceDark : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    _buildTab(0, 'Action Plan', isDark),
                    _buildTab(1, 'Treatment', isDark),
                    _buildTab(2, 'Prevention', isDark),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Tab Content
              if (_selectedTabIndex == 0)
                _buildActionPlanTab(treatmentList, symptomsList, isDark)
              else if (_selectedTabIndex == 1)
                _buildTreatmentTab(treatmentList, isDark)
              else
                _buildPreventionTab(preventionList, isDark),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTab(int index, String label, bool isDark) {
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

  Widget _buildActionPlanTab(
      List<String> treatments, List<String> symptoms, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section: What to do now (Numbered Steps)
        Text(
          'What to do now',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color:
                isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
          ),
        ),
        const SizedBox(height: 12),
        ...treatments.asMap().entries.map((entry) {
          final stepNum = entry.key + 1;
          final stepText = entry.value;

          return Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: GlassCard(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Circular Number Badge
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.secondary : AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$stepNum',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color:
                            isDark ? AppColors.backgroundDark : Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      stepText,
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.45,
                        color: isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimaryLight,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildTreatmentTab(List<String> treatments, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recommended Formulations & Sprays',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color:
                isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
          ),
        ),
        const SizedBox(height: 12),
        ...treatments.map((t) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: GlassCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.medication_liquid_outlined,
                          color: Color(0xFF2E7D32), size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Chemical & IPM Formulation',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? AppColors.secondary
                              : const Color(0xFF2E7D32),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    t,
                    style: TextStyle(
                      fontSize: 13.5,
                      height: 1.45,
                      color: isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildPreventionTab(List<String> preverntion, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Cultural & Preventive Practices',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color:
                isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
          ),
        ),
        const SizedBox(height: 12),
        ...preverntion.map((p) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: GlassCard(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.shield_outlined,
                      size: 20, color: Color(0xFF2563EB)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      p,
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.45,
                        color: isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimaryLight,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}
