import 'package:supabase_flutter/supabase_flutter.dart';

class DataSyncService {
  final SupabaseClient supabase;

  DataSyncService({required this.supabase});

  Future<void> sendProcessedData({
    required int bpm,
    required int ibi,
    required int quality,
    required String motion,
    required double accelX,
    required double accelY,
    required double accelZ,
    required double gyroX,
    required double gyroY,
    required double gyroZ,
    required double uvIndex,
  }) async {
    final session = supabase.auth.currentSession;
    if (session == null) {
      print("❌ Utilisateur non connecté");
      return;
    }

    final userId = session.user.id;

    final Map<String, dynamic> metric = {
      'user_id': userId,
      'ts': DateTime.now().toUtc().toIso8601String(),
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
      'uv_index': uvIndex,
    };

    try {
      await supabase.from('user_metrics').insert(metric);
      print("📤 Données envoyées Supabase");
    } catch (e) {
      print("❌ Erreur envoi Supabase: $e");
    }
  }
}
