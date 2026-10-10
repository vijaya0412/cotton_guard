import 'dart:io';
import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../constants/cotton_assets.dart';
import '../../models/scan_record.dart';
import '../../services/storage_service.dart';
import '../../controllers/history_controller.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/empty_state_view.dart';
import 'history_detail_screen.dart';

class HistoryScreen extends StatefulWidget {
  final StorageService storageService;
  final HistoryController historyController;

  const HistoryScreen({
    super.key,
    required this.storageService,
    required this.historyController,
  });

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String _filter = 'All'; // 'All', 'Diseased', 'Healthy', 'Low Confidence'
  final TextEditingController _searchController = TextEditingController();

  final List<String> _filters = ['All', 'Diseased', 'Healthy', 'Low Confidence'];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<ScanRecord> _getFilteredRecords(List<ScanRecord> all) {
    var list = all;

    if (_filter == 'Healthy') {
      list = list.where((r) => r.isHealthy).toList();
    } else if (_filter == 'Diseased') {
      list = list.where((r) => !r.isHealthy).toList();
    } else if (_filter == 'Low Confidence') {
      list = list.where((r) => r.isLowConfidence).toList();
    }

    final query = _searchController.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      list = list.where((r) {
        return r.predictedClass.toLowerCase().contains(query) ||
            r.severity.toLowerCase().contains(query);
      }).toList();
    }

    return list;
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final m = months[dt.month - 1];
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$m ${dt.day}, ${dt.year} • $h:$min';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Scan History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
            tooltip: 'Clear History',
            onPressed: () => _confirmClearHistory(context),
          ),
        ],
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: widget.historyController,
          builder: (context, _) {
            final records =
                _getFilteredRecords(widget.historyController.records);

            return Column(
              children: [
                // Search Bar
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Search condition or severity...',
                      prefixIcon: const Icon(Icons.search_rounded, size: 20),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {});
                              },
                            )
                          : null,
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ),

                // Filter Chips Row
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20.0, vertical: 4.0),
                  child: Row(
                    children: _filters.map((f) {
                      final isSelected = _filter == f;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: FilterChip(
                          label: Text(f),
                          selected: isSelected,
                          onSelected: (val) {
                            if (val) setState(() => _filter = f);
                          },
                          selectedColor: (isDark
                                  ? AppColors.secondary
                                  : AppColors.primary)
                              .withAlpha(40),
                          checkmarkColor: isDark
                              ? AppColors.secondary
                              : AppColors.primary,
                          labelStyle: TextStyle(
                            fontSize: 12,
                            fontWeight:
                                isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected
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
                const SizedBox(height: 8),

                // Scans List / Empty State
                Expanded(
                  child: records.isEmpty
                      ? EmptyStateView(
                          icon: Icons.history_rounded,
                          title: 'No Historical Scans',
                          description: widget.historyController.totalScans == 0
                              ? 'Your diagnosis records and field history will appear here after you scan cotton leaves.'
                              : 'No scan records match "$_filter".',
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20.0, vertical: 10.0),
                          itemCount: records.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final item = records[index];
                            return _buildScanRow(item, isDark);
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildScanRow(ScanRecord item, bool isDark) {
    Widget thumb;
    if (item.imagePath.startsWith('assets/')) {
      thumb = Image.asset(item.imagePath, fit: BoxFit.cover);
    } else {
      final f = File(item.imagePath);
      thumb = f.existsSync()
          ? Image.file(f, fit: BoxFit.cover)
          : Image.asset(CottonAssets.logo, fit: BoxFit.contain);
    }

    final dateStr = _formatDate(item.timestamp);

    return GlassCard(
      onTap: () {
        Navigator.of(context).push(
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 300),
            pageBuilder: (context, animation, secondaryAnimation) =>
                HistoryDetailScreen(
              record: item,
              historyController: widget.historyController,
            ),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
          ),
        );
      },
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          // Photographic Thumbnail
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 64,
              height: 64,
              child: thumb,
            ),
          ),
          const SizedBox(width: 14),

          // Disease Info, Date, Confidence, Severity
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        item.predictedClass,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? AppColors.textPrimaryDark
                              : AppColors.textPrimaryLight,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    StatusBadge.severity(item.severity, item.severityLevel),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  dateStr,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: isDark
                        ? AppColors.textMutedDark
                        : AppColors.textMutedLight,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${(item.confidence * 100).toStringAsFixed(1)}% Confidence',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.secondary : const Color(0xFF2E7D32),
                  ),
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
  }

  void _confirmClearHistory(BuildContext context) {
    if (widget.historyController.totalScans == 0) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear All Scans?'),
        content: const Text(
            'Are you sure you want to delete all saved scan logs? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await widget.historyController.clearAll();
            },
            child: const Text('Clear', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
  }
}
