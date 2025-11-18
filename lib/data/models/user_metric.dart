class UserMetric {
  final String id;
  final String userId;
  final DateTime ts;
  final int? bpm;
  final int? ibi;
  final int? quality;
  final String? motion;
  final double accelX;
  final double accelY;
  final double accelZ;
  final double gyroX;
  final double gyroY;
  final double gyroZ;

  UserMetric({
    required this.id,
    required this.userId,
    required this.ts,
    this.bpm,
    this.ibi,
    this.quality,
    this.motion,
    required this.accelX,
    required this.accelY,
    required this.accelZ,
    required this.gyroX,
    required this.gyroY,
    required this.gyroZ,
  });

  factory UserMetric.fromMap(Map<String, dynamic> map) {
    return UserMetric(
      id: map['id'],
      userId: map['user_id'],
      ts: DateTime.parse(map['ts']),
      bpm: map['bpm'],
      ibi: map['ibi'],
      quality: map['quality'],
      motion: map['motion'],
      accelX: (map['accel_x'] as num).toDouble(),
      accelY: (map['accel_y'] as num).toDouble(),
      accelZ: (map['accel_z'] as num).toDouble(),
      gyroX: (map['gyro_x'] as num).toDouble(),
      gyroY: (map['gyro_y'] as num).toDouble(),
      gyroZ: (map['gyro_z'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'ts': ts.toIso8601String(),
      'bpm': bpm,
      'ibi': ibi,
      'quality': quality,
      'motion': motion,
      'accel_x': accelX,
      'accel_y': accelY,
      'accel_z': accelZ,
      'gyro_x': gyroX,
      'gyro_y': gyroY,
      'gyro_z': gyroZ,
    };
  }
}
