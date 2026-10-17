import 'dart:convert';

import 'package:http/http.dart' as http;
import 'api_config.dart';

class PredictionResult {
  final int floodOccurred;
  final String floodLabel;
  final double floodProbability;
  final double floodProbabilityPercent;
  final String riskLevel;
  final String model;
  final String disclaimer;

  PredictionResult({
    required this.floodOccurred,
    required this.floodLabel,
    required this.floodProbability,
    required this.floodProbabilityPercent,
    required this.riskLevel,
    required this.model,
    required this.disclaimer,
  });

  factory PredictionResult.fromJson(Map<String, dynamic> json) => PredictionResult(
        floodOccurred: (json['flood_occurred'] as num).toInt(),
        floodLabel: json['flood_label'] as String,
        floodProbability: (json['flood_probability'] as num).toDouble(),
        floodProbabilityPercent: (json['flood_probability_percent'] as num).toDouble(),
        riskLevel: json['risk_level'] as String,
        model: json['model'] as String,
        disclaimer: json['disclaimer'] as String,
      );
}

class PredictionService {
  String get baseUrl => ApiConfig.baseUrl;

  Future<PredictionResult> predictFlood({
    required double latitude,
    required double longitude,
    required double rainfall,
    required double rainfall3Day,
    required double temperature,
    required double humidity,
    required double riverDischarge,
    required double waterLevel,
    required double elevation,
    required String landCover,
    required String soilType,
    required double populationDensity,
    required int infrastructure,
    required int historicalFloods,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/predict'),
      headers: const {'Content-Type': 'application/json', 'Accept': 'application/json'},
      body: jsonEncode({
        'latitude': latitude,
        'longitude': longitude,
        'rainfall': rainfall,
        'rainfall_3day': rainfall3Day,
        'temperature': temperature,
        'humidity': humidity,
        'river_discharge': riverDischarge,
        'water_level': waterLevel,
        'elevation': elevation,
        'land_cover': landCover,
        'soil_type': soilType,
        'population_density': populationDensity,
        'infrastructure': infrastructure,
        'historical_floods': historicalFloods,
      }),
    ).timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw Exception('Prediction failed: ${response.statusCode}\n${response.body}');
    }
    return PredictionResult.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }
}
