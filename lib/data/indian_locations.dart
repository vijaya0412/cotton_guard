import 'india_states_districts.dart';

/// Curated database of primary Indian Cotton Tracts and agricultural districts.
class IndianLocation {
  final String state;
  final String district;
  final String cityOrTown;
  final double latitude;
  final double longitude;

  const IndianLocation({
    required this.state,
    required this.district,
    required this.cityOrTown,
    required this.latitude,
    required this.longitude,
  });

  String get displayName => '$cityOrTown, $state';
  String get fullHierarchy => '$cityOrTown, $district, $state';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IndianLocation &&
          runtimeType == other.runtimeType &&
          state == other.state &&
          district == other.district &&
          cityOrTown == other.cityOrTown;

  @override
  int get hashCode => state.hashCode ^ district.hashCode ^ cityOrTown.hashCode;
}

class IndianLocations {
  static const IndianLocation defaultLocation = IndianLocation(
    state: 'Telangana',
    district: 'Warangal',
    cityOrTown: 'Warangal',
    latitude: 17.9784,
    longitude: 79.5941,
  );

  /// Complete list of 780+ districts across all 28 States & 8 Union Territories
  static List<IndianLocation> get all => IndiaDistrictsData.allDistricts;

  /// All 28 Indian States & 8 Union Territories
  static List<String> get states => IndiaDistrictsData.statesAndUTs;

  static List<IndianLocation> search(String query) {
    if (query.trim().isEmpty) return all;
    final q = query.trim().toLowerCase();
    return all.where((l) {
      return l.cityOrTown.toLowerCase().contains(q) ||
          l.district.toLowerCase().contains(q) ||
          l.state.toLowerCase().contains(q);
    }).toList();
  }

  static List<IndianLocation> byState(String state) {
    if (state == 'All' || state.isEmpty) return all;
    return all.where((l) => l.state.toLowerCase() == state.toLowerCase()).toList();
  }

  static IndianLocation? find(String query) {
    if (query.isEmpty) return null;
    final q = query.trim().toLowerCase();
    for (final loc in all) {
      if (loc.displayName.toLowerCase() == q ||
          loc.cityOrTown.toLowerCase() == q ||
          loc.district.toLowerCase() == q ||
          loc.fullHierarchy.toLowerCase() == q) {
        return loc;
      }
    }
    // Partial fallback match
    for (final loc in all) {
      if (loc.displayName.toLowerCase().contains(q) ||
          q.contains(loc.cityOrTown.toLowerCase())) {
        return loc;
      }
    }
    return null;
  }
}
