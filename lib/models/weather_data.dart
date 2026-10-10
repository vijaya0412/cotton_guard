/// Live Agricultural Weather Data Model with observation time, caching support & agronomic insights.
class WeatherData {
  final double temperature;
  final double relativeHumidity;
  final double windSpeed;
  final String weatherCondition;
  final String locationName;
  final bool isAvailable;
  final DateTime observationTime;
  final bool isCached;
  final String? advisoryWarning;

  WeatherData({
    required this.temperature,
    required this.relativeHumidity,
    required this.windSpeed,
    required this.weatherCondition,
    required this.locationName,
    required this.isAvailable,
    DateTime? observationTime,
    this.isCached = false,
    this.advisoryWarning,
  }) : observationTime = observationTime ?? DateTime.now();

  String get temperatureFormatted => '${temperature.round()}°C';
  String get humidityFormatted => '${relativeHumidity.round()}%';
  String get windSpeedFormatted => '${windSpeed.round()} km/h';

  String get freshnessLabel {
    if (!isAvailable) return 'Offline';
    if (!isCached) return 'Live';
    final diff = DateTime.now().difference(observationTime);
    if (diff.inMinutes < 1) return 'Cached (just now)';
    if (diff.inMinutes < 60) return 'Cached (${diff.inMinutes}m ago)';
    return 'Cached (${diff.inHours}h ago)';
  }

  factory WeatherData.unavailable(String location) {
    return WeatherData(
      temperature: 0.0,
      relativeHumidity: 0.0,
      windSpeed: 0.0,
      weatherCondition: 'Weather unavailable',
      locationName: location,
      isAvailable: false,
      observationTime: DateTime.now(),
      isCached: false,
      advisoryWarning: null,
    );
  }

  static String _deriveAdvisory(double temp, double humidity, double wind) {
    if (humidity >= 78.0) {
      return 'High humidity (>78%): elevated risk of bacterial blight & fungal foliar leaf spot.';
    }
    if (wind >= 20.0) {
      return 'Breezy conditions (>20 km/h): avoid foliar spraying to prevent spray drift.';
    }
    if (temp >= 38.0) {
      return 'High heat (>38°C): ensure timely irrigation to minimize square and boll shedding.';
    }
    return 'Atmospheric conditions favorable for field operations & scouting.';
  }

  factory WeatherData.fromOpenMeteo(
    Map<String, dynamic> json,
    String location, {
    bool isCached = false,
    DateTime? cachedTime,
  }) {
    try {
      final current = json['current'] as Map<String, dynamic>?;
      if (current == null) return WeatherData.unavailable(location);

      final temp = (current['temperature_2m'] as num?)?.toDouble() ?? 0.0;
      final humidity = (current['relative_humidity_2m'] as num?)?.toDouble() ?? 0.0;
      final wind = (current['wind_speed_10m'] as num?)?.toDouble() ?? 0.0;
      final weatherCode = (current['weather_code'] as num?)?.toInt() ?? 0;
      final timeStr = current['time'] as String?;
      final obsTime = cachedTime ??
          (timeStr != null ? DateTime.tryParse(timeStr) : null) ??
          DateTime.now();

      String condition = 'Clear Sky';
      if (weatherCode == 1 || weatherCode == 2) {
        condition = 'Partly Cloudy';
      } else if (weatherCode == 3) {
        condition = 'Overcast';
      } else if (weatherCode >= 51 && weatherCode <= 67) {
        condition = 'Light Rain';
      } else if (weatherCode >= 80 && weatherCode <= 82) {
        condition = 'Rain Showers';
      } else if (weatherCode >= 95) {
        condition = 'Thunderstorm';
      }

      final advisory = _deriveAdvisory(temp, humidity, wind);

      return WeatherData(
        temperature: temp,
        relativeHumidity: humidity,
        windSpeed: wind,
        weatherCondition: condition,
        locationName: location,
        isAvailable: true,
        observationTime: obsTime,
        isCached: isCached,
        advisoryWarning: advisory,
      );
    } catch (_) {
      return WeatherData.unavailable(location);
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'temperature': temperature,
      'relative_humidity': relativeHumidity,
      'wind_speed': windSpeed,
      'weather_condition': weatherCondition,
      'location_name': locationName,
      'is_available': isAvailable,
      'observation_time': observationTime.toIso8601String(),
      'is_cached': isCached,
      'advisory_warning': advisoryWarning,
    };
  }

  factory WeatherData.fromJson(Map<String, dynamic> json, {bool asCached = true}) {
    return WeatherData(
      temperature: (json['temperature'] as num?)?.toDouble() ?? 0.0,
      relativeHumidity: (json['relative_humidity'] as num?)?.toDouble() ?? 0.0,
      windSpeed: (json['wind_speed'] as num?)?.toDouble() ?? 0.0,
      weatherCondition: json['weather_condition'] as String? ?? 'Clear',
      locationName: json['location_name'] as String? ?? 'India',
      isAvailable: json['is_available'] as bool? ?? false,
      observationTime: DateTime.tryParse(json['observation_time'] as String? ?? '') ??
          DateTime.now(),
      isCached: asCached,
      advisoryWarning: json['advisory_warning'] as String?,
    );
  }

  WeatherData asCachedCopy() {
    return WeatherData(
      temperature: temperature,
      relativeHumidity: relativeHumidity,
      windSpeed: windSpeed,
      weatherCondition: weatherCondition,
      locationName: locationName,
      isAvailable: isAvailable,
      observationTime: observationTime,
      isCached: true,
      advisoryWarning: advisoryWarning,
    );
  }
}
