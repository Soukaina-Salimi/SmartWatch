import 'dart:async';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:path/path.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:smartwatch_v2/main.dart';
import 'package:smartwatch_v2/pages/health/HealthMonitorScreen.dart';
import 'package:smartwatch_v2/routing/app_router.dart';
import 'package:smartwatch_v2/services/data_sync_service.dart';
import 'package:smartwatch_v2/services/notification_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/widgets/custom_card.dart';
import '../../core/widgets/stat_card.dart';
import '../../data/providers/health_provider.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'dart:math';
import 'package:smartwatch_v2/data/models/user_metric.dart';
import 'package:smartwatch_v2/data/models/user_configuration.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../../presentation/bluetooth/bluetooth_page.dart'
    hide HealthMonitorScreen;
import '../../presentation/bluetooth//device_page.dart';

final StreamController<Map<String, dynamic>> chartStream =
    StreamController.broadcast();

class RealTimeChart extends StatefulWidget {
  @override
  _RealTimeChartState createState() => _RealTimeChartState();
}

class _RealTimeChartState extends State<RealTimeChart> {
  final List<FlSpot> ibiData = []; // Changé de bpmData à ibiData
  int xValue = 0;
  StreamSubscription? _chartSubscription;

  @override
  void initState() {
    super.initState();
    _chartSubscription = chartStream.stream.listen((data) {
      if (mounted) {
        setState(() {
          // Utiliser l'IBI au lieu du BPM
          final ibiValue = (data['ibi'] as double?) ?? 0.0;
          ibiData.add(FlSpot(xValue.toDouble(), ibiValue));
          xValue++;
          if (ibiData.length > 50) {
            ibiData.removeAt(0);
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _chartSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LineChart(
      LineChartData(
        minY: 0.3, // IBI typique en secondes (300ms à 1200ms)
        maxY: 1.5, // Plage adaptée pour l'IBI
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                return Text('${value.toStringAsFixed(1)}s');
              },
            ),
          ),
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: ibiData,
            isCurved: true,
            color: Colors.green, // Changé la couleur pour différencier
            barWidth: 2,
            dotData: FlDotData(show: false),
          ),
        ],
      ),
    );
  }
}

class CaloriesService {
  final supabase = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> getCaloriesData() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        print("❌ Utilisateur non connecté pour calories");
        return [];
      }

      print("🔄 Chargement calories pour user: ${user.id}");

      final response = await supabase
          .from('calories_predictions')
          .select('created_at, calories_burned')
          .eq('user_id', user.id)
          .order('created_at', ascending: true)
          .limit(30);

      print("✅ Données calories reçues: ${response.length} entrées");

      if (response.isEmpty) {
        print("📭 Table calories_predictions vide pour cet utilisateur");
      }

      return response;
    } catch (e) {
      print("❌ Erreur getCaloriesData: $e");
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getRecentCaloriesData() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return [];

      final sevenDaysAgo = DateTime.now()
          .subtract(Duration(days: 7))
          .toIso8601String();

      final response = await supabase
          .from('calories_predictions')
          .select('created_at, calories_burned')
          .eq('user_id', user.id)
          .gte('created_at', sevenDaysAgo)
          .order('created_at', ascending: true);

      return response;
    } catch (e) {
      print("Erreur dans getRecentCaloriesData: $e");
      return [];
    }
  }
}

List<FlSpot> caloriesToSpots(List<Map<String, dynamic>> data) {
  return data.asMap().entries.map((entry) {
    int index = entry.key;
    double calories = (entry.value['calories_burned'] as num).toDouble();
    return FlSpot(index.toDouble(), calories);
  }).toList();
}

class CaloriesChart extends StatelessWidget {
  final List<Map<String, dynamic>> data;

  const CaloriesChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final spots = caloriesToSpots(data);

    // Calculer les valeurs min/max pour l'échelle Y
    double minY = 0;
    double maxY = 500;
    if (spots.isNotEmpty) {
      final calories = data
          .map((e) => (e['calories_burned'] as num).toDouble())
          .toList();
      minY = 0; // Toujours commencer à 0 pour les calories
      maxY = calories.reduce((a, b) => a > b ? a : b) * 1.2;
      maxY = maxY.clamp(100, 2000); // Limiter entre 100 et 2000 calories
    }

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          horizontalInterval: max(50, maxY / 5),
          verticalInterval: 1,
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              interval: data.length > 10 ? 2 : 1,
              getTitlesWidget: (value, meta) {
                if (value.toInt() < data.length) {
                  final date = DateTime.parse(
                    data[value.toInt()]['created_at'],
                  );
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      '${date.day}/${date.month}',
                      style: TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  );
                }
                return Text('');
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: max(50, maxY / 5),
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                return Text(
                  '${value.toInt()}',
                  style: TextStyle(fontSize: 10, color: Colors.grey),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border.all(color: Colors.grey.withOpacity(0.3), width: 1),
        ),
        minY: minY,
        maxY: maxY,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Colors.orange,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  Colors.orange.withOpacity(0.3),
                  Colors.orange.withOpacity(0.1),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class VitaminDService {
  final supabase = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> getVitaminDScores() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        print("Utilisateur non connecté");
        return [];
      }

      final response = await supabase
          .from('daily_vitamin_d')
          .select('date, vitamin_d_score')
          .eq('user_id', user.id)
          .order('date', ascending: true)
          .limit(30);

      return response;
    } catch (e) {
      print("Erreur dans getVitaminDScores: $e");
      return [];
    }
  }
}

List<FlSpot> toSpots(List<Map<String, dynamic>> data) {
  return data.asMap().entries.map((entry) {
    int index = entry.key;
    double score = (entry.value['vitamin_d_score'] as num).toDouble();
    return FlSpot(index.toDouble(), score);
  }).toList();
}

class VitaminDChart extends StatelessWidget {
  final List<Map<String, dynamic>> data;

  const VitaminDChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final spots = toSpots(data);

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          horizontalInterval: 20,
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              interval: data.length > 10 ? 2 : 1,
              getTitlesWidget: (value, meta) {
                if (value.toInt() < data.length) {
                  final date = DateTime.parse(data[value.toInt()]['date']);
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      '${date.day}/${date.month}',
                      style: TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  );
                }
                return Text('');
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 20,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                return Text(
                  '${value.toInt()}',
                  style: TextStyle(fontSize: 10, color: Colors.grey),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border.all(color: Colors.grey.withOpacity(0.3), width: 1),
        ),
        minY: 0,
        maxY: 100,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Colors.blue,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  Colors.blue.withOpacity(0.3),
                  Colors.blue.withOpacity(0.1),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

final supabase = Supabase.instance.client;

class DataUploadService {
  final supabase = Supabase.instance.client;

  Future<bool> uploadHealthData(Map<String, dynamic> healthData) async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        print("❌ Utilisateur non connecté");
        return false;
      }

      // Convertir et valider les données
      final Map<String, dynamic> dataToInsert = {
        'user_id': user.id,
        'ts': DateTime.now().toIso8601String(),
        'bpm': _safeInt(healthData['bpm']),
        'accel_x': _safeDouble(healthData['accel_x']),
        'accel_y': _safeDouble(healthData['accel_y']),
        'accel_z': _safeDouble(healthData['accel_z']),
        'gyro_x': _safeDouble(healthData['gyro_x']),
        'gyro_y': _safeDouble(healthData['gyro_y']),
        'gyro_z': _safeDouble(healthData['gyro_z']),
        'skin_temp': _safeDouble(healthData['skin_temp']),
        'uv_index': _safeInt(healthData['uv_index']),
        'ibi': _safeDouble(healthData['ibi']),
        'motion': null,
      };

      print("📤 Envoi des données à Supabase: ${jsonEncode(dataToInsert)}");

      final response = await supabase.from('user_metrics').insert(dataToInsert);

      if (response.error != null) {
        print("❌ Erreur Supabase: ${response.error!.message}");
        print("❌ Détails: ${response.error!.details}");
        print("❌ Hint: ${response.error!.hint}");
        return false;
      }

      print("✅ Données envoyées avec succès à Supabase");
      return true;
    } catch (e) {
      print("❌ Erreur lors de l'envoi des données: $e");
      return false;
    }
  }

  // Méthodes helper pour la conversion sécurisée
  int _safeInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  double _safeDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }
}

int calculateSteps(List<UserMetric> metrics) {
  int steps = 0;
  for (var m in metrics) {
    double magnitude = sqrt(
      pow(m.accelX, 2) + pow(m.accelY, 2) + pow(m.accelZ - 1.0, 2),
    );
    if (magnitude > 0.2) steps += 1;
  }
  return steps;
}

double calculateSleepQuality(List<UserMetric> metrics) {
  if (metrics.isEmpty) return 50.0;

  double motionPenalty = 0.0;
  double bpmPenalty = 0.0;

  for (var m in metrics) {
    if (m.motion != null && m.motion?.toUpperCase() != 'STATIONARY')
      motionPenalty += 1.0;

    if (m.bpm != null && m.bpm! > 80) bpmPenalty += (m.bpm! - 80) / 100;
  }

  double quality =
      100.0 - min(50.0, motionPenalty) - min(50.0, bpmPenalty * 50);
  return quality.clamp(0.0, 100.0);
}

double calculatePhysicalActivity(List<UserMetric> metrics) {
  if (metrics.isEmpty) return 1.0;

  double activityScore = 0.0;
  for (var m in metrics) {
    double magnitude = sqrt(
      pow(m.accelX, 2) + pow(m.accelY, 2) + pow(m.accelZ - 1.0, 2),
    );
    activityScore += magnitude;
  }

  double avgScore = activityScore / metrics.length;
  return (avgScore * 5).clamp(0.5, 3.0);
}

double estimateBloodPressure(
  UserConfiguration config,
  List<UserMetric> metrics,
) {
  if (metrics.isEmpty) return 120.0;

  double avgBpm =
      metrics.map((m) => m.bpm ?? 70).reduce((a, b) => a + b) / metrics.length;

  double bmi = config.weightKg / pow(config.heightCm / 100, 2);
  double systolic = 110 + 0.5 * avgBpm + 0.1 * bmi;
  return systolic.clamp(90.0, 160.0);
}

class StressPredictionService {
  Timer? _timer;
  Future<Map<String, dynamic>?> sendStressPrediction() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    if (user == null) {
      print("Utilisateur non connecté");
      return null;
    }

    final userId = user.id;

    final configMap = await supabase
        .from('user_configurations')
        .select()
        .eq('user_id', userId)
        .maybeSingle();

    if (configMap == null) {
      print("Aucune configuration trouvée pour l'utilisateur");
      return null;
    }

    final config = UserConfiguration.fromMap(configMap);
    final gender = config.gender == 'Homme'
        ? 1
        : config.gender == 'Femme'
        ? 2
        : 0;

    final metricsData = await supabase
        .from('user_metrics')
        .select()
        .eq('user_id', userId)
        .order('ts', ascending: false)
        .limit(50);

    final metricsList = (metricsData as List<dynamic>)
        .map((m) => UserMetric.fromMap(m))
        .toList();

    final dailySteps = calculateSteps(metricsList);
    final sleepQuality = calculateSleepQuality(metricsList);
    final physicalActivity = calculatePhysicalActivity(metricsList);
    final bloodPressure = estimateBloodPressure(config, metricsList);

    final heartRate = metricsList.isNotEmpty
        ? metricsList.map((m) => m.bpm ?? 70).reduce((a, b) => a + b) /
              metricsList.length
        : 70.0;

    final sleepDuration = config.sleepDuration;
    final bmi = config.weightKg / pow(config.heightCm / 100, 2);

    try {
      final response = await supabase.functions.invoke(
        'prediction',
        body: {
          'user_id': userId,
          'Gender': gender,
          'Age': config.age,
          'Occupation': 0,
          'Sleep_Duration': sleepDuration,
          'Quality_of_Sleep': sleepQuality,
          'Physical_Activity_Level': physicalActivity,
          'BMI_Category': bmi,
          'Blood_Pressure': bloodPressure,
          'Heart_Rate': heartRate,
          'Daily_Steps': dailySteps,
          'Sleep_Disorder': config.hasInsomnia ? 1 : 0,
        },
      );

      final predictionData = Map<String, dynamic>.from(response.data as Map);
      print("Stress prédit : ${predictionData['stress_level']}");
      return predictionData;
    } catch (e) {
      print("Erreur prédiction: $e");
      return null;
    }
  }

  void startAutoPrediction(Function(String) onUpdate) {
    _timer = Timer.periodic(const Duration(minutes: 30), (_) async {
      print("🕒 Envoi automatique de la prédiction...");

      final result = await sendStressPrediction();
      if (result != null) {
        final stress = result['stress_level'].toString();
        onUpdate(stress);
      }
    });
  }

  void stopAutoPrediction() {
    _timer?.cancel();
  }
}

class StressNotificationService {
  Timer? _checkTimer;
  DateTime? _stressStartTime;
  final StressPredictionService stressService;

  StressNotificationService(this.stressService);

  void _showStressNotification() {
    showStressNotification();
    _startBreathingExercise();
  }

  void startMonitoring() {
    _checkTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      final result = await stressService.sendStressPrediction();
      if (result == null) return;

      final stressLevel = result['stress_level']?.toString() ?? 'Low';

      if (stressLevel == 'Extreme') {
        if (_stressStartTime == null) {
          _stressStartTime = DateTime.now();
          print('🚨 Stress Extreme détecté - Début du compteur');
        } else {
          final duration = DateTime.now().difference(_stressStartTime!);
          print('⏱️ Stress Extreme depuis: ${duration.inSeconds} secondes');
          if (duration.inSeconds >= 20) {
            _showStressNotification();
            _stressStartTime = null;
          }
        }
      } else {
        if (_stressStartTime != null) {
          print('✅ Stress retombé - Reset du compteur');
          _stressStartTime = null;
        }
      }
    });
  }

  void stopMonitoring() {
    _checkTimer?.cancel();
    _stressStartTime = null;
  }

  void _startBreathingExercise() {
    print("🧘‍♂️ Navigation vers l'exercice de respiration...");

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (navigatorKey.currentState != null) {
        navigatorKey.currentState!.pushNamed(AppRouter.breathingExercise);
        print('✅ Navigation réussie vers BreathingExercise');
      } else {
        print('❌ Navigator key non disponible');
      }
    });
  }
}

class DashboardPage extends StatefulWidget {
  static final GlobalKey<_DashboardPageState> globalKey =
      GlobalKey<_DashboardPageState>();

  DashboardPage({Key? key}) : super(key: globalKey); // ← très important

  @override
  _DashboardPageState createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  // Tes champs
  String ppgSignal = "";
  String ibi = "";
  String accelX = "";
  String accelY = "";
  String accelZ = "";
  String gyroX = "";
  String gyroY = "";
  String gyroZ = "";
  String skinTemp = "";
  String ambientTemp = "";
  String uvIndex = "";
  String timestamp = "";
  late DataUploadService _uploadService;
  // Variables pour Vitamin D
  String _vitaminDScore = '--';
  List<Map<String, dynamic>> vitaminDData = [];
  bool loadingVitaminD = false;

  void updateDataFields(Map<String, dynamic> data) {
    setState(() {
      ppgSignal = data['ppg']?['raw_signal']?.toString() ?? "";
      ibi = data['ppg']?['ibi']?.toString() ?? "";

      accelX = data['movement']?['accel_x']?.toString() ?? "";
      accelY = data['movement']?['accel_y']?.toString() ?? "";
      accelZ = data['movement']?['accel_z']?.toString() ?? "";

      gyroX = data['movement']?['gyro_x']?.toString() ?? "";
      gyroY = data['movement']?['gyro_y']?.toString() ?? "";
      gyroZ = data['movement']?['gyro_z']?.toString() ?? "";

      skinTemp = data['temperature']?['skin_temp']?.toString() ?? "";
      ambientTemp = data['temperature']?['ambient_temp']?.toString() ?? "";

      uvIndex = data['uv']?['uv_index']?.toString() ?? "";

      timestamp = data['ppg']?['timestamp']?.toString() ?? "";
    });

    // Envoyer automatiquement les données à Supabase
    _uploadDataToSupabase(data);
  }

  Future<void> _uploadDataToSupabase(Map<String, dynamic> data) async {
    try {
      print("🔄 Réception données: ${jsonEncode(data)}");

      // Extraire les valeurs avec des fallbacks sécurisés
      final ppgData = data['ppg'] ?? {};
      final movementData = data['movement'] ?? {};
      final temperatureData = data['temperature'] ?? {};
      final uvData = data['uv'] ?? {};

      final healthData = {
        'bpm': _extractInt(ppgData['bpm']),
        'accel_x': _extractDouble(movementData['accel_x']),
        'accel_y': _extractDouble(movementData['accel_y']),
        'accel_z': _extractDouble(movementData['accel_z']),
        'gyro_x': _extractDouble(movementData['gyro_x']),
        'gyro_y': _extractDouble(movementData['gyro_y']),
        'gyro_z': _extractDouble(movementData['gyro_z']),
        'skin_temp': _extractDouble(temperatureData['skin_temp']),
        'uv_index': _extractInt(uvData['uv_index']),
        'ibi': _extractDouble(ppgData['ibi']),
      };

      print("📦 Données préparées: $healthData");

      final success = await _uploadService.uploadHealthData(healthData);

      if (success) {
        print("✅ Données envoyées à Supabase avec succès");

        // Mettre à jour le graphique
        final ibiValue =
            double.tryParse(data['ppg']?['ibi']?.toString() ?? '0.8') ?? 0.8;
        chartStream.add({
          'ibi': ibiValue, // Envoyer l'IBI au lieu du BPM
          'timestamp': DateTime.now(),
        });
      }
    } catch (e) {
      print("❌ Erreur lors du traitement des données: $e");
    }
  }

  // Helpers pour l'extraction sécurisée
  int _extractInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is String) {
      // Nettoyer la chaîne si nécessaire
      final cleaned = value.replaceAll(RegExp(r'[^0-9.-]'), '');
      return int.tryParse(cleaned) ?? 0;
    }
    return 0;
  }

  double _extractDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      // Nettoyer la chaîne si nécessaire
      final cleaned = value.replaceAll(RegExp(r'[^0-9.-]'), '');
      return double.tryParse(cleaned) ?? 0.0;
    }
    return 0.0;
  }

  // Variables pour Calories
  List<Map<String, dynamic>> caloriesData = [];
  bool loadingCalories = false;
  String _todayCalories = '--';

  String? _userAvatarUrl;
  String? _stressLevel = '--';
  final StressPredictionService _predictionService = StressPredictionService();
  final StressNotificationService _stressNotificationService;

  int _currentIndex = 0;
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;

  String _weatherDescription = 'Chargement...';
  String _temperature = '--';
  IconData _weatherIcon = Icons.cloud_off;

  // Contrôleurs
  final _genderController = TextEditingController();
  final _ageController = TextEditingController();
  final _occupationController = TextEditingController();
  final _sleepDurationController = TextEditingController();
  final _sleepQualityController = TextEditingController();
  final _activityController = TextEditingController();
  final _bmiController = TextEditingController();
  final _bpController = TextEditingController();
  final _heartRateController = TextEditingController();
  final _stepsController = TextEditingController();
  final _sleepDisorderController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final _durationController = TextEditingController();
  final _bodyTempController = TextEditingController();

  _DashboardPageState()
    : _stressNotificationService = StressNotificationService(
        StressPredictionService(),
      );

  @override
  void initState() {
    super.initState();
    _uploadService = DataUploadService(); // Ajouter cette ligne
    _loadWeatherData();
    _loadUserAvatarFromDatabase();
    _loadVitaminDData();
    _loadCaloriesData(); // Charger les calories au démarrage

    _authSubscription = supabase.auth.onAuthStateChange.listen((data) {
      final AuthChangeEvent event = data.event;

      if (event == AuthChangeEvent.signedIn ||
          event == AuthChangeEvent.initialSession) {
        print("AUTH CHANGE: User is Signed In. Démarrage des services.");

        _predictionService.stopAutoPrediction();
        _loadStressPrediction();
        _loadVitaminDScore();
        _loadVitaminDData();
        _loadCaloriesData(); // Recharger les calories

        _predictionService.startAutoPrediction((value) {
          if (mounted) {
            setState(() {
              _stressLevel = value;
            });
          }
        });
        _stressNotificationService.startMonitoring();
      } else if (event == AuthChangeEvent.signedOut) {
        print("AUTH CHANGE: User Signed Out. Arrêt des services.");
        _predictionService.stopAutoPrediction();
        _stressNotificationService.stopMonitoring();
        if (mounted) {
          setState(() {
            _stressLevel = '--';
            _vitaminDScore = '--';
            _todayCalories = '--';
            vitaminDData = [];
            caloriesData = [];
          });
        }
      }
    });
  }

  Future<void> _loadCaloriesData() async {
    if (mounted) {
      setState(() {
        loadingCalories = true;
      });
    }

    try {
      final service = CaloriesService();
      final data = await service.getCaloriesData();

      if (mounted) {
        setState(() {
          caloriesData = data;
          loadingCalories = false;
        });
      }

      _calculateTodayCalories(data);
      print("Données calories chargées: ${data.length} enregistrements");
    } catch (e) {
      print("Erreur chargement calories: $e");
      if (mounted) {
        setState(() {
          loadingCalories = false;
        });
      }
    }
  }

  void _calculateTodayCalories(List<Map<String, dynamic>> data) {
    final today = DateTime.now();
    final todayString =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    final todayData = data.where((item) {
      final createdAt = DateTime.parse(item['created_at']);
      final itemDate =
          '${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.day.toString().padLeft(2, '0')}';
      return itemDate == todayString;
    }).toList();

    if (todayData.isNotEmpty) {
      final totalToday = todayData
          .map((e) => (e['calories_burned'] as num).toDouble())
          .reduce((a, b) => a + b);

      setState(() {
        _todayCalories = totalToday.round().toString();
      });
    } else {
      setState(() {
        _todayCalories = '0';
      });
    }
  }

  Future<void> _loadStressPrediction() async {
    setState(() => _loading = true);
    final result = await _predictionService.sendStressPrediction();
    if (result != null) {
      setState(() {
        _stressLevel = result['stress_level'].toString();
        _loading = false;
      });
    } else {
      setState(() => _loading = false);
    }
  }

  Future<void> _loadVitaminDData() async {
    if (mounted) {
      setState(() {
        loadingVitaminD = true;
      });
    }

    try {
      final service = VitaminDService();
      final data = await service.getVitaminDScores();

      if (mounted) {
        setState(() {
          vitaminDData = data;
          loadingVitaminD = false;
        });
      }

      print("Données Vitamin D chargées: ${data.length} enregistrements");
    } catch (e) {
      print("Erreur chargement Vitamin D: $e");
      if (mounted) {
        setState(() {
          loadingVitaminD = false;
        });
      }
    }
  }

  Future<void> _loadVitaminDScore() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;

    if (userId == null) {
      setState(() {
        _vitaminDScore = 'N/A';
      });
      return;
    }

    try {
      final response = await Supabase.instance.client
          .from('daily_vitamin_d')
          .select('vitamin_d_score')
          .eq('user_id', userId)
          .order('date', ascending: false)
          .limit(1)
          .single();

      if (response != null && response['vitamin_d_score'] != null) {
        setState(() {
          _vitaminDScore = response['vitamin_d_score'].toString();
        });
      }
    } catch (e) {
      print("Erreur chargement score Vitamin D: $e");
      setState(() {
        _vitaminDScore = 'N/A';
      });
    }
  }

  Color _getVitaminDColor() {
    if (_vitaminDScore == '--' || _vitaminDScore == 'N/A') {
      return Colors.grey;
    }

    final score = double.tryParse(_vitaminDScore) ?? 0;
    if (score >= 30) return Colors.green;
    if (score >= 20) return Colors.orange;
    return Colors.red;
  }

  Widget _buildVitaminDCard() {
    return CustomCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Niveau Vitamin D",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Text(
                _vitaminDScore,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: _getVitaminDColor(),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Container(
            height: 200,
            child: loadingVitaminD
                ? Center(child: CircularProgressIndicator())
                : vitaminDData.isEmpty
                ? Center(
                    child: Text(
                      "Aucune donnée Vitamin D disponible",
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : VitaminDChart(data: vitaminDData),
          ),
          SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Historique sur ${vitaminDData.length} jours",
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
              IconButton(
                icon: Icon(Icons.refresh),
                onPressed: _loadVitaminDData,
                iconSize: 20,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCaloriesCard() {
    return CustomCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Calories Brûlées",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.local_fire_department,
                      size: 16,
                      color: Colors.orange,
                    ),
                    SizedBox(width: 4),
                    Text(
                      '$_todayCalories cal',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Container(
            height: 200,
            child: loadingCalories
                ? Center(child: CircularProgressIndicator())
                : caloriesData.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.local_fire_department,
                          size: 48,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 8),
                        Text(
                          "Aucune donnée calories",
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : CaloriesChart(data: caloriesData),
          ),
          SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Historique sur ${caloriesData.length} jours",
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
              IconButton(
                icon: Icon(Icons.refresh, size: 20),
                onPressed: _loadCaloriesData,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _loadUserAvatarFromDatabase() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;

    if (userId == null) {
      setState(() {
        _userAvatarUrl = null;
      });
      return;
    }

    try {
      final response = await Supabase.instance.client
          .from('user_configurations')
          .select('profile_image_url')
          .eq('user_id', userId)
          .single();

      final String? url = response['profile_image_url'] as String?;

      if (mounted) {
        setState(() {
          _userAvatarUrl = (url?.isNotEmpty == true) ? url : null;
          print('DEBUG: URL Avatar depuis DB : $_userAvatarUrl');
        });
      }
    } catch (e) {
      print('ERREUR lors du chargement de l\'avatar depuis la DB: $e');
      if (mounted) {
        setState(() {
          _userAvatarUrl = null;
        });
      }
    }
  }

  Future<Position?> getCurrentLocation() async {
    try {
      bool serviceEnabled;
      LocationPermission permission;

      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print("DEBUG: Geolocator Service Désactivé.");
        return null;
      }

      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          print("DEBUG: Permission refusée par l'utilisateur.");
          return null;
        }
      }

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
        timeLimit: const Duration(seconds: 10),
      );
    } catch (e, stacktrace) {
      print('ERREUR NATALE DANS getCurrentLocation: $e');
      print('STACKTRACE DANS getCurrentLocation: $stacktrace');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getWeather(Position position) async {
    final lat = position.latitude;
    final lon = position.longitude;

    final url = Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': lat.toString(),
      'longitude': lon.toString(),
      'current': 'temperature_2m,weather_code',
      'forecast_hours': '1',
      'timezone': 'auto',
    });
    print('URL Météo: $url');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      print('Erreur API Open-Meteo: ${response.statusCode}');
      return null;
    }
  }

  void _loadWeatherData() async {
    print("DEBUG: 1. Début de _loadWeatherData");

    try {
      final position = await getCurrentLocation();

      if (position == null) {
        print("DEBUG: 2. Localisation est NULL");
        setState(() {
          _weatherDescription = 'Localisation désactivée';
          _weatherIcon = Icons.location_off;
        });
        return;
      }

      print("DEBUG: 3. Localisation obtenue: Lat ${position.latitude}");

      final weatherData = await getWeather(position);

      if (weatherData != null) {
        print("DEBUG: 4. Données météo reçues, mise à jour de l'UI.");

        final currentMap = weatherData['current'] as Map<String, dynamic>?;

        if (currentMap != null) {
          final currentTemperature = currentMap['temperature_2m'] as double?;
          final weatherCode = currentMap['weather_code'] as int?;

          if (currentTemperature != null && weatherCode != null) {
            final tempText = currentTemperature.toStringAsFixed(1);
            final (description, icon) = _mapWeatherCode(weatherCode);

            setState(() {
              _temperature = '$tempText °C';
              _weatherDescription = description;
              _weatherIcon = icon;
            });
          } else {
            print("DEBUG: 5a. Données 'temperature' ou 'code' manquantes");
            setState(() {
              _weatherDescription = 'Données incomplètes';
              _weatherIcon = Icons.error_outline;
            });
          }
        } else {
          print("DEBUG: 5b. La clé 'current' est absente");
        }
      } else {
        print("DEBUG: 5c. getWeather a retourné NULL");
      }
    } catch (e, stacktrace) {
      print('ERREUR FATALE DANS _loadWeatherData: $e');
      print('STACKTRACE: $stacktrace');
      setState(() {
        _weatherDescription = 'Erreur critique: $e';
        _weatherIcon = Icons.warning;
      });
    }
  }

  (String, IconData) _mapWeatherCode(int code) {
    if (code >= 0 && code <= 1) {
      return ('Ensoleillé', Icons.wb_sunny);
    } else if (code >= 2 && code <= 3) {
      return ('Nuageux', Icons.cloud);
    } else if (code >= 45 && code <= 48) {
      return ('Brume/Brouillard', Icons.blur_on);
    } else if (code >= 51 && code <= 67) {
      return ('Pluie', Icons.umbrella);
    } else if (code >= 71 && code <= 75) {
      return ('Neige', Icons.ac_unit);
    }
    return ('Conditions inconnues', Icons.question_mark);
  }

  late final StreamSubscription<AuthState> _authSubscription;

  @override
  Widget build(BuildContext context) {
    final health = Provider.of<HealthProvider>(context);
    final wellbeingScore =
        (100 - (health.data.temperature * 10) + (health.data.heartBpm / 10))
            .clamp(0, 100)
            .toInt();

    final scoreLabel = wellbeingScore > 80
        ? "Excellent 😄"
        : wellbeingScore > 60
        ? "Bon 🙂"
        : "Faible 😟";

    return Scaffold(
      body: _buildDashboardBody(context),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: Theme.of(context).primaryColor,
        unselectedItemColor: Colors.grey,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        onTap: (i) {
          setState(() => _currentIndex = i);

          switch (i) {
            case 0:
              break;
            case 1:
              Navigator.pushNamed(context, AppRouter.activity);
              break;
            case 2:
              Navigator.pushNamed(context, AppRouter.analytics);
              break;
            case 3:
              Navigator.pushNamed(context, AppRouter.config);
              break;
          }
        },
        items: [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
          BottomNavigationBarItem(
            icon: Icon(Icons.directions_run),
            label: "Activity",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.insights),
            label: "Analytics",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: "Settings",
          ),
        ],
      ),
    );
  }

  Widget dataTile(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text("$label : $value", style: TextStyle(fontSize: 18)),
    );
  }

  Widget _buildDashboardBody(BuildContext context) {
    final health = Provider.of<HealthProvider>(context);
    final wellbeingScore =
        (100 - (health.data.temperature * 10) + (health.data.heartBpm / 10))
            .clamp(0, 100)
            .toInt();

    final scoreLabel = wellbeingScore > 80
        ? "Excellent 😄"
        : wellbeingScore > 60
        ? "Bon 🙂"
        : "Faible 😟";

    return SafeArea(
      child: ListView(
        padding: EdgeInsets.all(16),
        children: [
          // HEADER
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Smartwatch Santé',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              CircleAvatar(
                backgroundImage: _userAvatarUrl != null
                    ? NetworkImage(_userAvatarUrl!) as ImageProvider<Object>?
                    : null,
                backgroundColor: _userAvatarUrl != null
                    ? Colors.grey[300]
                    : Theme.of(context).primaryColor,
                child: _userAvatarUrl == null
                    ? Icon(Icons.person, color: Colors.white)
                    : null,
              ),
            ],
          ),

          SizedBox(height: 16),

          // SECTION HERO : Score de bien-être
          CustomCard(
            child: Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).primaryColor.withOpacity(0.9),
                    Theme.of(context).primaryColor.withOpacity(0.6),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned(
                    top: -30,
                    right: -30,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -20,
                    left: -20,
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),

                  // Contenu principal
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.self_improvement,
                        size: 50,
                        color: Colors.white,
                      ),
                      SizedBox(height: 8),
                      Text(
                        "Score de bien-être",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 12),
                      Text(
                        scoreLabel,
                        style: TextStyle(color: Colors.white70, fontSize: 16),
                      ),
                      SizedBox(height: 16),
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            height: 70,
                            width: 70,
                            child: CircularProgressIndicator(
                              value: wellbeingScore / 100,
                              strokeWidth: 6,
                              backgroundColor: Colors.white24,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          ),
                          Text(
                            "$wellbeingScore",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          SizedBox(height: 16),

          // CARTE CALORIES - AJOUTÉE ICI
          _buildCaloriesCard(),

          SizedBox(height: 16),

          // CARTE VITAMIN D
          _buildVitaminDCard(),

          SizedBox(height: 16),

          // TABLEAU DE BORD
          CustomCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tableau de bord',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: StatCard(
                        icon: _weatherIcon,
                        label: 'Météo Actuelle',
                        value: _temperature,
                        subValue: _weatherDescription,
                        onPressed: _loadWeatherData,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => BluetoothPage()),
                          );
                        },
                        child: Text(
                          "Lier La montre",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => HealthMonitorScreen(),
                            ),
                          );
                        },
                        child: Text(
                          "Data",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          SizedBox(height: 16),

          // ANALYSE IA
          CustomCard(
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.lightbulb,
                      color: Theme.of(context).primaryColor,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Analyse IA',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                Icon(
                  Icons.lightbulb,
                  color: Theme.of(context).primaryColor,
                  size: 48,
                ),
                SizedBox(height: 8),
                Text(
                  'Simulation prédiction du stress',
                  style: TextStyle(fontSize: 16),
                ),

                SizedBox(height: 16),
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      SizedBox(height: 16),
                      if (_stressLevel != '--')
                        Text(
                          'Stress : $_stressLevel',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.blueAccent,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 16),

          // GRAPHIQUE CARDIAQUE
          CustomCard(
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Rythme cardiaque', style: TextStyle(fontSize: 18)),
                    Text(
                      '${health.data.heartBpm} IBI',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Container(height: 140, child: RealTimeChart()),
                SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pushNamed(context, '/heart'),
                      child: Text('Voir plus'),
                    ),
                    Text('1H 24H 1S 1M'),
                  ],
                ),
              ],
            ),
          ),
          CustomCard(
            child: SizedBox(
              height: 300, // adjust as needed
              child: ListView(
                children: [
                  dataTile("PPG Signal", ppgSignal),
                  dataTile("IBI", ibi),
                  dataTile("Accel X", accelX),
                  dataTile("Accel Y", accelY),
                  dataTile("Accel Z", accelZ),
                  dataTile("Gyro X", gyroX),
                  dataTile("Gyro Y", gyroY),
                  dataTile("Gyro Z", gyroZ),
                  dataTile("Skin Temp", skinTemp),
                  dataTile("Ambient Temp", ambientTemp),
                  dataTile("UV Index", uvIndex),
                  dataTile("Timestamp", timestamp),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    _predictionService.stopAutoPrediction();
    _genderController.dispose();
    _ageController.dispose();
    _occupationController.dispose();
    _sleepDurationController.dispose();
    _sleepQualityController.dispose();
    _activityController.dispose();
    _bmiController.dispose();
    _bpController.dispose();
    _heartRateController.dispose();
    _stepsController.dispose();
    _sleepDisorderController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _durationController.dispose();
    _bodyTempController.dispose();
    chartStream.close();
    _stressNotificationService.stopMonitoring();
    super.dispose();
  }
}
