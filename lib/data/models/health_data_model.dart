// FILE: lib/data/models/health_data_model.dart
class HealthDataModel {
  final int heartBpm;
  final double temperature;
  final double uvIndex;
  final int steps;

  HealthDataModel({
    required this.heartBpm,
    required this.temperature,
    required this.uvIndex,
    required this.steps,
  });

  HealthDataModel copyWith({
    int? heartBpm,
    double? temperature,
    double? uvIndex,
    int? steps,
  }) {
    return HealthDataModel(
      heartBpm: heartBpm ?? this.heartBpm,
      temperature: temperature ?? this.temperature,
      uvIndex: uvIndex ?? this.uvIndex,
      steps: steps ?? this.steps,
    );
  }
}
