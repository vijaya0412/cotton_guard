import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../data/indian_locations.dart';

/// Modal bottom sheet allowing farmers to manually pick or search their Indian agricultural location.
class LocationPickerSheet extends StatefulWidget {
  final String currentLocation;
  final ValueChanged<IndianLocation> onLocationSelected;

  const LocationPickerSheet({
    super.key,
    required this.currentLocation,
    required this.onLocationSelected,
  });

  static Future<void> show({
    required BuildContext context,
    required String currentLocation,
    required ValueChanged<IndianLocation> onLocationSelected,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => LocationPickerSheet(
        currentLocation: currentLocation,
        onLocationSelected: onLocationSelected,
      ),
    );
  }

  @override
  State<LocationPickerSheet> createState() => _LocationPickerSheetState();
}

class _LocationPickerSheetState extends State<LocationPickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedState = 'All';
  List<IndianLocation> _filteredLocations = IndianLocations.all;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onFilterChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onFilterChanged() {
    final query = _searchController.text.trim();
    List<IndianLocation> list = IndianLocations.search(query);
    if (_selectedState != 'All') {
      list = list
          .where((l) => l.state.toLowerCase() == _selectedState.toLowerCase())
          .toList();
    }
    setState(() {
      _filteredLocations = list;
    });
  }

  void _selectState(String state) {
    setState(() {
      _selectedState = state;
    });
    _onFilterChanged();
  }

  void _showCustomEntryDialog() {
    final textCtrl = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enter Custom Location'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter your village, mandal, or town in India:',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: textCtrl,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'e.g. Wardha Rural, Maharashtra',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final text = textCtrl.text.trim();
              if (text.isNotEmpty) {
                // Approximate coordinates using Warangal fallback if unknown
                final customLoc = IndianLocation(
                  state: 'India',
                  district: text,
                  cityOrTown: text,
                  latitude: 17.9784,
                  longitude: 79.5941,
                );
                Navigator.of(ctx).pop();
                Navigator.of(context).pop();
                widget.onLocationSelected(customLoc);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final states = ['All', ...IndianLocations.states];

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Drag handle
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 44,
              height: 4.5,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(3),
              ),
            ),

            // Title & Custom entry action
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Select Location',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'All 28 States & 8 UTs (${IndianLocations.all.length} Districts)',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                        ),
                      ),
                    ],
                  ),
                  TextButton.icon(
                    onPressed: _showCustomEntryDialog,
                    icon: const Icon(Icons.add_location_alt_outlined, size: 16),
                    label: const Text('Other'),
                  ),
                ],
              ),
            ),

            // Two-tier State/UT Selector
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.cardDark : const Color(0xFFF0F3F1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: states.contains(_selectedState) ? _selectedState : 'All',
                    isExpanded: true,
                    icon: const Icon(Icons.arrow_drop_down_rounded),
                    dropdownColor: isDark ? AppColors.surfaceDark : Colors.white,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                    ),
                    items: states.map((s) {
                      final label = s == 'All'
                          ? 'All States & UTs (${IndianLocations.all.length} Districts)'
                          : '$s (${IndianLocations.byState(s).length} Districts)';
                      return DropdownMenuItem<String>(
                        value: s,
                        child: Text(label),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) _selectState(val);
                    },
                  ),
                ),
              ),
            ),

            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search district or town in India...',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () => _searchController.clear(),
                        )
                      : null,
                  filled: true,
                  fillColor: isDark ? AppColors.cardDark : const Color(0xFFF0F3F1),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),

            // Quick State Filter Chips
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                itemCount: states.length,
                separatorBuilder: (context, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final state = states[index];
                  final isSelected = _selectedState.toLowerCase() == state.toLowerCase();

                  return ChoiceChip(
                    label: Text(state),
                    selected: isSelected,
                    onSelected: (_) => _selectState(state),
                    selectedColor: isDark ? AppColors.secondary : AppColors.primary,
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected
                          ? (isDark ? AppColors.backgroundDark : Colors.white)
                          : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                    ),
                  );
                },
              ),
            ),

            const Divider(height: 16),

            // Location list
            Expanded(
              child: _filteredLocations.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.location_off_outlined,
                            size: 42,
                            color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'No matching locations found',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                            ),
                          ),
                          const SizedBox(height: 4),
                          TextButton(
                            onPressed: _showCustomEntryDialog,
                            child: const Text('Enter custom village / town'),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                      itemCount: _filteredLocations.length,
                      separatorBuilder: (context, _) => Divider(
                        height: 1,
                        color: isDark ? AppColors.borderDark : AppColors.borderLight,
                      ),
                      itemBuilder: (context, index) {
                        final loc = _filteredLocations[index];
                        final isCurrent = widget.currentLocation.toLowerCase().contains(
                              loc.cityOrTown.toLowerCase(),
                            ) &&
                            widget.currentLocation.toLowerCase().contains(
                              loc.state.toLowerCase(),
                            );

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: (isCurrent
                                      ? (isDark ? AppColors.secondary : AppColors.primary)
                                      : (isDark ? Colors.white10 : Colors.black.withAlpha(10))),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.location_on_rounded,
                              size: 18,
                              color: isCurrent
                                  ? (isDark ? AppColors.backgroundDark : Colors.white)
                                  : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                            ),
                          ),
                          title: Text(
                            loc.cityOrTown,
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w600,
                              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                            ),
                          ),
                          subtitle: Text(
                            '${loc.district} District, ${loc.state}',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                            ),
                          ),
                          trailing: isCurrent
                              ? Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: (isDark ? AppColors.secondary : AppColors.primary).withAlpha(30),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.check_rounded,
                                        size: 14,
                                        color: isDark ? AppColors.secondary : AppColors.primary,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Active',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: isDark ? AppColors.secondary : AppColors.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : null,
                          onTap: () {
                            Navigator.of(context).pop();
                            widget.onLocationSelected(loc);
                          },
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}
