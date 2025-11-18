class UserConfiguration {
  final String id;
  final String userId;
  final int age;
  final String gender;
  final int heightCm;
  final double weightKg;
  final bool hasInsomnia;
  final double sleepDuration; // ajouté pour le calcul
  final DateTime createdAt;
  final DateTime updatedAt;

  UserConfiguration({
    required this.id,
    required this.userId,
    required this.age,
    required this.gender,
    required this.heightCm,
    required this.weightKg,
    required this.hasInsomnia,
    required this.sleepDuration,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserConfiguration.fromMap(Map<String, dynamic> map) {
    return UserConfiguration(
      id: map['id'],
      userId: map['user_id'],
      age: map['age'],
      gender: map['gender'],
      heightCm: map['height_cm'],
      weightKg: (map['weight_kg'] as num).toDouble(),
      hasInsomnia: map['has_insomnia'] ?? false,
      sleepDuration: (map['sleep_duration'] as num?)?.toDouble() ?? 7.0,
      createdAt: DateTime.parse(map['created_at']),
      updatedAt: DateTime.parse(map['updated_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'age': age,
      'gender': gender,
      'height_cm': heightCm,
      'weight_kg': weightKg,
      'has_insomnia': hasInsomnia,
      'sleep_duration': sleepDuration,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
