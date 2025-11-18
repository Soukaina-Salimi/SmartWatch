import 'dart:async';
import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';

class DataSyncService {
  final SupabaseClient supabase;
  final Duration sendInterval;
  Timer? _timer;
  final Random _rand = Random();

  DataSyncService({
    required this.supabase,
    this.sendInterval = const Duration(seconds: 5),
  });

  /// Démarre l’envoi automatique de données de test toutes les `sendInterval`
  void startSendingTestData() {
    _timer = Timer.periodic(sendInterval, (_) async {
      final data = generateTestData();
      await sendProcessedData(
        bpm: data['bpm'],
        ibi: data['ibi'],
        quality: data['quality'],
        motion: data['motion'],
        accelX: data['accelX'],
        accelY: data['accelY'],
        accelZ: data['accelZ'],
        gyroX: data['gyroX'],
        gyroY: data['gyroY'],
        gyroZ: data['gyroZ'],
      );
    });
  }

  void stopSendingTestData() {
    _timer?.cancel();
  }

  /// Génère une mesure de test aléatoire
  Map<String, dynamic> generateTestData() {
    // Simule PPG / BPM
    int bpm = 60 + _rand.nextInt(40); // 60 à 100
    int ibi = 600 + _rand.nextInt(200); // 600 à 800 ms
    int quality = 70 + _rand.nextInt(30); // 70 à 100
    String motion = ['STILL', 'WALKING', 'RUNNING'][_rand.nextInt(3)];

    // Simule capteurs IMU
    double accelX = (_rand.nextDouble() * 2) - 1; // -1 à 1
    double accelY = (_rand.nextDouble() * 2) - 1;
    double accelZ = (_rand.nextDouble() * 2) - 1;
    double gyroX = (_rand.nextDouble() * 180) - 90; // -90 à 90 deg/s
    double gyroY = (_rand.nextDouble() * 180) - 90;
    double gyroZ = (_rand.nextDouble() * 180) - 90;

    return {
      'bpm': bpm,
      'ibi': ibi,
      'quality': quality,
      'motion': motion,
      'accelX': accelX,
      'accelY': accelY,
      'accelZ': accelZ,
      'gyroX': gyroX,
      'gyroY': gyroY,
      'gyroZ': gyroZ,
    };
  }

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
    };

    try {
      await supabase.from('user_metrics').insert(metric);
      print("✅ Données traitées envoyées avec succès !");
    } on PostgrestException catch (e) {
      print("❌ Erreur Supabase: ${e.message}");
    } catch (e) {
      print("❌ Erreur inconnue: $e");
    }
  }

  Future<Map<String, dynamic>?> getUserConfig(String userId) async {
    try {
      final response = await supabase
          .from('user_configurations')
          .select()
          .eq('user_id', userId)
          .single();
      return response;
    } catch (e) {
      print("❌ Erreur récupération user_config: $e");
      return null;
    }
  }

  /// Envoie une seule mesure traitée à Supabase
}
