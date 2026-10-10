import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/weather_data.dart';
import '../data/indian_locations.dart';
import 'storage_service.dart';

/// Weather Service providing real agricultural atmospheric conditions via Open-Meteo
/// with local 30-minute caching, units, observation time, and offline fallback.
class WeatherService {
  final http.Client _client;
  final StorageService? _storageService;

  WeatherService([this._storageService, http.Client? client])
      : _client = client ?? http.Client();

  // Cache validity duration: 30 minutes
  static const Duration cacheValidity = Duration(minutes: 30);

  // Coordinates for key Indian Cotton Tracts
  static const Map<String, List<double>> regionCoords = {
    'Warangal, Telangana': [17.9784, 79.5941],
    'Nagpur, Maharashtra': [21.1458, 79.0882],
    'Rajkot, Gujarat': [22.3039, 70.8022],
    'Guntur, Andhra Pradesh': [16.3067, 80.4365],
    'Bhatinda, Punjab': [30.2110, 74.9455],
    'Dharwad, Karnataka': [15.4589, 75.0078],
    'Coimbatore, Tamil Nadu': [11.0168, 76.9558],
  };

  WeatherData? _loadCachedWeather(String location) {
    if (_storageService == null) return null;
    final cachedJsonStr = _storageService.getCachedWeatherJson();
    final cachedTimeMs = _storageService.getWeatherCacheTimestamp();
    if (cachedJsonStr != null && cachedTimeMs != null) {
      try {
        final map = jsonDecode(cachedJsonStr) as Map<String, dynamic>;
        final cached = WeatherData.fromJson(map, asCached: true);
        if (cached.locationName.toLowerCase() == location.toLowerCase()) {
          return cached;
        }
      } catch (_) {}
    }
    return null;
  }

  Future<WeatherData> fetchWeather({
    String location = 'Warangal, Telangana',
    double? latitude,
    double? longitude,
    bool forceRefresh = false,
  }) async {
    // 1. Check local cache first if not forced
    if (!forceRefresh) {
      final cached = _loadCachedWeather(location);
      if (cached != null) {
        final age = DateTime.now().difference(cached.observationTime);
        if (age < cacheValidity) {
          return cached;
        }
      }
    }

    // 2. Resolve coordinates
    double lat;
    double lon;

    if (latitude != null && longitude != null) {
      lat = latitude;
      lon = longitude;
    } else {
      final match = IndianLocations.find(location);
      if (match != null) {
        lat = match.latitude;
        lon = match.longitude;
      } else {
        final coords = regionCoords[location] ?? regionCoords['Warangal, Telangana']!;
        lat = coords[0];
        lon = coords[1];
      }
    }

    final uri = Uri.parse(
      'https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&current=temperature_2m,relative_humidity_2m,wind_speed_10m,weather_code',
    );

    try {
      final response = await _client.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final weather = WeatherData.fromOpenMeteo(data, location, isCached: false);

        // Cache locally
        if (_storageService != null && weather.isAvailable) {
          await _storageService.setCachedWeather(
            jsonEncode(weather.toJson()),
            DateTime.now().millisecondsSinceEpoch,
          );
        }

        return weather;
      }

      // If server error, fallback to cached
      final cached = _loadCachedWeather(location);
      if (cached != null) return cached;
      return WeatherData.unavailable(location);
    } catch (_) {
      // Offline or network error: never show fake data, return cached if available
      final cached = _loadCachedWeather(location);
      if (cached != null) return cached;
      return WeatherData.unavailable(location);
    }
  }
}
