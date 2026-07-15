import 'dart:convert';

import 'package:http/http.dart' as http;

/// Wetterdaten von Open-Meteo.
///
/// Open-Meteo braucht keinen API-Key und erlaubt CORS — deshalb funktioniert es
/// sowohl im Web als auch nativ, ohne dass der Nutzer irgendwo einen Account anlegt.
class WeatherService {
  WeatherService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// Kleiner In-Memory-Cache, damit die Karte beim Scrollen nicht dieselbe
  /// Koordinate mehrfach abfragt.
  final Map<String, _CacheEntry> _cache = {};
  static const _cacheTtl = Duration(minutes: 30);

  Future<List<DailyWeather>> forecast(double lat, double lng, {int days = 7}) async {
    final key = '${lat.toStringAsFixed(2)},${lng.toStringAsFixed(2)},$days';
    final cached = _cache[key];
    if (cached != null && DateTime.now().difference(cached.at) < _cacheTtl) {
      return cached.data;
    }

    final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': lat.toStringAsFixed(4),
      'longitude': lng.toStringAsFixed(4),
      'daily': [
        'weather_code',
        'temperature_2m_max',
        'temperature_2m_min',
        'precipitation_sum',
        'precipitation_probability_max',
        'cloud_cover_mean',
        'wind_speed_10m_max',
        'relative_humidity_2m_mean',
      ].join(','),
      'forecast_days': '$days',
      'timezone': 'auto',
    });

    final res = await _client.get(uri).timeout(const Duration(seconds: 12));
    if (res.statusCode != 200) {
      throw WeatherException('Open-Meteo antwortete mit ${res.statusCode}');
    }

    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final daily = json['daily'] as Map<String, dynamic>;
    final dates = (daily['time'] as List).cast<String>();

    double at(String field, int i) {
      final list = daily[field] as List?;
      final v = list == null || i >= list.length ? null : list[i];
      return (v as num?)?.toDouble() ?? 0;
    }

    final result = <DailyWeather>[];
    for (var i = 0; i < dates.length; i++) {
      result.add(DailyWeather(
        date: DateTime.parse(dates[i]),
        weatherCode: at('weather_code', i).toInt(),
        tempMax: at('temperature_2m_max', i),
        tempMin: at('temperature_2m_min', i),
        precipitationMm: at('precipitation_sum', i),
        precipitationProbability: at('precipitation_probability_max', i),
        cloudCover: at('cloud_cover_mean', i),
        windSpeedKmh: at('wind_speed_10m_max', i),
        humidity: at('relative_humidity_2m_mean', i),
      ));
    }

    _cache[key] = _CacheEntry(result, DateTime.now());
    return result;
  }
}

class _CacheEntry {
  _CacheEntry(this.data, this.at);
  final List<DailyWeather> data;
  final DateTime at;
}

class WeatherException implements Exception {
  WeatherException(this.message);
  final String message;
  @override
  String toString() => message;
}

class DailyWeather {
  const DailyWeather({
    required this.date,
    required this.weatherCode,
    required this.tempMax,
    required this.tempMin,
    required this.precipitationMm,
    required this.precipitationProbability,
    required this.cloudCover,
    required this.windSpeedKmh,
    required this.humidity,
  });

  final DateTime date;
  final int weatherCode;
  final double tempMax;
  final double tempMin;
  final double precipitationMm;

  /// 0-100 %
  final double precipitationProbability;

  /// 0-100 %
  final double cloudCover;
  final double windSpeedKmh;
  final double humidity;

  /// WMO-Wettercodes, wie Open-Meteo sie liefert.
  String get condition {
    if (weatherCode == 0) return 'klar';
    if (weatherCode <= 2) return 'leicht bewölkt';
    if (weatherCode == 3) return 'bedeckt';
    if (weatherCode <= 48) return 'Nebel';
    if (weatherCode <= 57) return 'Nieselregen';
    if (weatherCode <= 67) return 'Regen';
    if (weatherCode <= 77) return 'Schnee';
    if (weatherCode <= 82) return 'Regenschauer';
    if (weatherCode <= 86) return 'Schneeschauer';
    return 'Gewitter';
  }

  String get emoji {
    if (weatherCode == 0) return '☀️';
    if (weatherCode <= 2) return '🌤️';
    if (weatherCode == 3) return '☁️';
    if (weatherCode <= 48) return '🌫️';
    if (weatherCode <= 57) return '🌦️';
    if (weatherCode <= 67) return '🌧️';
    if (weatherCode <= 77) return '🌨️';
    if (weatherCode <= 82) return '🌧️';
    if (weatherCode <= 86) return '❄️';
    return '⛈️';
  }
}
