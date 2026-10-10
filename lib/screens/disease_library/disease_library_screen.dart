import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../constants/canonical_classes.dart';
import '../../widgets/glass_card.dart';
import 'disease_detail_screen.dart';

class DiseaseLibraryScreen extends StatelessWidget {
  const DiseaseLibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Cotton Disease Library'),
      ),
      body: SafeArea(
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
          itemCount: CanonicalClasses.all.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final className = CanonicalClasses.all[index];
            final details = CanonicalClasses.diseaseDetails[className]!;
            final primaryImg = CanonicalClasses.getPrimaryAssetImage(className);

            final summary = details['summary'] as String;
            final scientificName = details['scientificName'] as String;

            return GlassCard(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => DiseaseDetailScreen(className: className),
                  ),
                );
              },
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: 72,
                      height: 72,
                      child: Image.asset(primaryImg, fit: BoxFit.cover),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          className,
                          style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.1,
                            color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          scientificName,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontStyle: FontStyle.italic,
                            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 5),
                        Text(
                          summary,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                            height: 1.35,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

