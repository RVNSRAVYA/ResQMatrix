import 'dart:convert';

import 'package:http/http.dart' as http;

class WeatherData {
  final double temperature;
  final double humidity;
  final double rainfall;
  final double windSpeed;

  WeatherData({
    required this.temperature,
    required this.humidity,
    required this.rainfall,
    required this.windSpeed,
  });
}

class WeatherService {
  Future<WeatherData> getWeather({
    required double latitude,
    required double longitude,
  }) async {
    final url = Uri.parse(
      'https://api.open-meteo.com/v1/forecast'
      '?latitude=$latitude'
      '&longitude=$longitude'
      '&current=temperature_2m,relative_humidity_2m,rain,wind_speed_10m'
      '&timezone=auto',
    );

    final response = await http.get(url);

    if (response.statusCode != 200) {
      throw Exception('Failed to load weather data');
    }

    final data = jsonDecode(response.body);

    final current = data['current'];

    return WeatherData(
      temperature: (current['temperature_2m'] as num).toDouble(),
      humidity: (current['relative_humidity_2m'] as num).toDouble(),
      rainfall: (current['rain'] as num).toDouble(),
      windSpeed: (current['wind_speed_10m'] as num).toDouble(),
    );
  }
}