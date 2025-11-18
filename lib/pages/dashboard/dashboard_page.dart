import 'dart:async';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:provider/provider.dart';
import 'package:smartwatch_v2/main.dart';
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

final StreamController<Map<String, dynamic>> chartStream =
    StreamController.broadcast();

class RealTimeChart extends StatefulWidget {
  @override
  _RealTimeChartState createState() => _RealTimeChartState();
}

class _RealTimeChartState extends State<RealTimeChart> {
  final List<FlSpot> bpmData = [];
  int xValue = 0;
  StreamSubscription? _chartSubscription; // AJOUT

  @override
  void initState() {
    super.initState();
    _chartSubscription = chartStream.stream.listen((data) {
      // MODIFICATION
      if (mounted) {
        // AJOUT : vérifier si le widget est toujours monté
        setState(() {
          bpmData.add(
            FlSpot(xValue.toDouble(), (data['bpm'] as int).toDouble()),
          );
          xValue++;
          if (bpmData.length > 50) {
            bpmData.removeAt(0);
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _chartSubscription?.cancel(); // AJOUT : annuler la subscription
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LineChart(
      LineChartData(
        minY: 50,
        maxY: 120,
        lineBarsData: [
          LineChartBarData(spots: bpmData, isCurved: true, color: Colors.red),
        ],
      ),
    );
  }
}

void startSimulatedData(DataSyncService service) {
  Timer.periodic(Duration(seconds: 5), (_) async {
    final data = service.generateTestData(); // Génère des données simulées
    chartStream.add(data); // Envoie au chart
    print("Nouvelle donnée simulée : $data");
  });
}

final supabase = Supabase.instance.client;

/// ⚡ Calcule le nombre approximatif de pas à partir des données d'accélération
int calculateSteps(List<UserMetric> metrics) {
  int steps = 0;
  for (var m in metrics) {
    // Simple estimation: chaque "pic" d'accélération compte comme un pas
    double magnitude = sqrt(
      pow(m.accelX, 2) + pow(m.accelY, 2) + pow(m.accelZ - 1.0, 2),
    );
    if (magnitude > 0.2) steps += 1; // seuil à ajuster selon capteur
  }
  return steps;
}

/// ⚡ Calcule la qualité du sommeil (0-100) approximativement
double calculateSleepQuality(List<UserMetric> metrics) {
  if (metrics.isEmpty) return 50.0; // valeur par défaut

  double motionPenalty = 0.0;
  double bpmPenalty = 0.0;

  for (var m in metrics) {
    // motion "STATIONARY" = pas de pénalité
    if (m.motion != null && m.motion?.toUpperCase() != 'STATIONARY')
      motionPenalty += 1.0;

    // BPM élevé la nuit = moins bonne qualité
    if (m.bpm != null && m.bpm! > 80) bpmPenalty += (m.bpm! - 80) / 100;
  }

  double quality =
      100.0 - min(50.0, motionPenalty) - min(50.0, bpmPenalty * 50);
  return quality.clamp(0.0, 100.0);
}

/// ⚡ Calcule le niveau d'activité physique
double calculatePhysicalActivity(List<UserMetric> metrics) {
  if (metrics.isEmpty) return 1.0;

  double activityScore = 0.0;
  for (var m in metrics) {
    double magnitude = sqrt(
      pow(m.accelX, 2) + pow(m.accelY, 2) + pow(m.accelZ - 1.0, 2),
    );
    activityScore += magnitude;
  }

  // Normaliser sur le nombre d'échantillons pour obtenir un score moyen
  double avgScore = activityScore / metrics.length;
  return (avgScore * 5).clamp(0.5, 3.0); // score approximatif 0.5-3.0
}

/// ⚡ Estimation de la pression artérielle à partir du BPM et du BMI
double estimateBloodPressure(
  UserConfiguration config,
  List<UserMetric> metrics,
) {
  if (metrics.isEmpty) return 120.0;

  double avgBpm =
      metrics.map((m) => m.bpm ?? 70).reduce((a, b) => a + b) / metrics.length;

  // Approximation simple : systolic = 110 + 0.5*BPM + 0.1*BMI
  double bmi = config.weightKg / pow(config.heightCm / 100, 2);
  double systolic = 110 + 0.5 * avgBpm + 0.1 * bmi;
  return systolic.clamp(90.0, 160.0); // bornes réalistes
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

    // 1️⃣ Charger la config
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

    // 2️⃣ Charger les metrics récentes
    final metricsData = await supabase
        .from('user_metrics')
        .select()
        .eq('user_id', userId)
        .order('ts', ascending: false)
        .limit(50);

    final metricsList = (metricsData as List<dynamic>)
        .map((m) => UserMetric.fromMap(m))
        .toList();

    // 3️⃣ Calculs
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

    // 4️⃣ Appel Edge Function
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
        onUpdate(stress); // <-- On envoie la valeur au widget
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

  // MODIFICATION: Pas besoin de contexte
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

  // MODIFICATION: Navigation globale sans contexte
  void _startBreathingExercise() {
    print("🧘‍♂️ Navigation vers l'exercice de respiration...");

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Utiliser la navigation globale via navigatorKey
      if (navigatorKey.currentState != null) {
        navigatorKey.currentState!.pushNamed(AppRouter.breathingExercise);
        print('✅ Navigation réussie vers BreathingExercise');
      } else {
        print('❌ Navigator key non disponible');
      }
    });
  }
}

// Constante pour le nom de l'Edge Function
const String _vitaminDFunctionName =
    'vitamin_d_estimator'; // Renommé pour clarté

// Service isolé pour les appels à l'Edge Function
class HealthIndicatorService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<Map<String, dynamic>?> calculateDailyVitaminD(String userId) async {
    try {
      final response = await _supabase.functions.invoke(
        _vitaminDFunctionName,
        body: {'user_id': userId},
      );
      print('Réponse complète VitD: ${response.data}');

      if (response.status == 200) {
        final result = response.data;
        print('Score Vitamine D reçu : ${result['vitamin_d_score']}');
        return result;
      } else {
        print('Erreur Edge Function Vitamine D (Statut: ${response.status})');
        print('Corps de l\'erreur: ${response.data}');
        // Retourne une structure pour indiquer l'erreur ou l'absence de données
        return {
          'error': response.data['error'] ?? 'Unknown error',
          'vitamin_d_score': 0,
        };
      }
    } catch (e) {
      print('Erreur générale lors de l\'appel de l\'Edge Function: $e');
      return null;
    }
  }
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  _DashboardPageState createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  // --- NOUVELLE VARIABLE D'ÉTAT ---
  String _vitaminDScore = '--'; // Affichera le score ou '--' en attendant
  String? _userAvatarUrl;
  String? _stressLevel = '--';

  final StressPredictionService _predictionService = StressPredictionService();
  final StressNotificationService _stressNotificationService; // AJOUT
  // AJOUT: Constructeur pour initialiser le service de notification
  _DashboardPageState()
    : _stressNotificationService = StressNotificationService(
        StressPredictionService(),
      );
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

  // ... (autres variables d'état existantes)
  int _currentIndex = 0;
  final _formKey = GlobalKey<FormState>();
  final _formKeyCalories = GlobalKey<FormState>();
  bool _loading = false;
  String? _result;
  String? _resultCalories;
  String _weatherDescription = 'Chargement...';
  String _temperature = '--';
  IconData _weatherIcon = Icons.cloud_off;
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

  // --- NOUVELLE FONCTION DE CHARGEMENT ---
  Future<void> _loadVitaminDScore() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;

    if (userId == null) {
      setState(() {
        _vitaminDScore = 'N/A';
      });
      return;
    }

    final service = HealthIndicatorService();
    final result = await service.calculateDailyVitaminD(userId);

    if (mounted) {
      // Vérifie si le widget est toujours monté
      setState(() {
        if (result != null && result.containsKey('vitamin_d_score')) {
          _vitaminDScore = result['vitamin_d_score'].toString();
        } else {
          // Affiche N/A si une erreur ou absence de données
          _vitaminDScore = 'N/A';
        }
      });
    }
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
      // 1. Requête la table 'user_configurations' pour l'utilisateur actuel
      final response = await Supabase.instance.client
          .from('user_configurations')
          .select(
            'profile_image_url',
          ) // Sélectionne uniquement la colonne de l'image
          .eq('user_id', userId) // Filtre par l'ID de l'utilisateur
          .single(); // N'attend qu'un seul résultat (le profil utilisateur)

      // 2. Vérifie et extrait l'URL
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
  // --- (Fonctions _predictStress, _predictCalories, getCurrentLocation, getWeather, _loadWeatherData, _mapWeatherCode inchangées) ---

  Future<void> _predictCalories(String userId) async {
    setState(() {
      _loading = true;
      _resultCalories = null;
    });

    try {
      final supabase = Supabase.instance.client;

      // 1️⃣ Extraction des données de configuration (inchangée)
      final userConfigResponse = await supabase
          .from('user_configurations')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (userConfigResponse == null) {
        if (mounted) {
          setState(() {
            _resultCalories = "Erreur: Configuration utilisateur non trouvée.";
            _loading = false;
          });
        }
        return;
      }

      final int age = userConfigResponse['age'] ?? 0;
      final double weight = (userConfigResponse['weightKg'] ?? 0).toDouble();
      final double height = (userConfigResponse['heightCm'] ?? 0).toDouble();
      final int gender = (userConfigResponse['gender'] == 'Homme'
          ? 1
          : userConfigResponse['gender'] == 'Femme'
          ? 2
          : 0);

      // 2️⃣ Extraction des variables du formulaire (DOIT ÊTRE FAIT AVANT LA REQUÊTE)
      final double duration = double.tryParse(_durationController.text) ?? 0.0;
      final double bodyTemp = double.tryParse(_bodyTempController.text) ?? 0.0;

      // --- CORRECTION DU BPM ---

      // Calculer le timestamp de début : Maintenant moins la durée en minutes.
      // La durée est en minutes, donc on la convertit en secondes
      // Calculer l'heure de fin actuelle en UTC
      final DateTime nowUtc = DateTime.now().toUtc(); // <-- Utilisez UTC

      // Calculer le timestamp de début : Maintenant (UTC) moins la durée en minutes.
      final DateTime startUtc = nowUtc.subtract(
        Duration(minutes: duration.toInt()),
      );
      // Le timestamp dans Supabase est généralement au format ISO 8601 (String) ou epoch.
      // Nous utiliserons le format String pour Supabase.
      // Le filtre doit être une string ISO 8601 en UTC
      final String timeFilter = startUtc.toIso8601String();
      // 3️⃣ Récupérer les métriques BPM (heart rate) depuis user_metrics
      final metricsData = await supabase
          .from('user_metrics')
          .select('bpm')
          .eq('user_id', userId)
          // 🚨 NOUVEAU FILTRE : Récupérer seulement les BPM enregistrés APRÈS timeFilter
          .gte('ts', timeFilter)
          .order('ts', ascending: false) // On conserve l'ordre
          .limit(100); // Récupérer un nombre suffisant d'échantillons

      // Vérification de la réponse et calcul de la moyenne
      final List<int> bpmValues = (metricsData as List<dynamic>)
          .map(
            (e) => (e['bpm'] as int?) ?? 0,
          ) // Convertir en int, gérer les nulls
          .where((bpm) => bpm > 0) // Ignorer les valeurs nulles/zéros
          .toList();

      if (bpmValues.isEmpty) {
        if (mounted) {
          setState(() {
            _resultCalories =
                "Erreur: Aucune donnée cardiaque trouvée pour cette période.";
            _loading = false;
          });
        }
        return;
      }

      // Calculer la moyenne
      final double heartRate =
          bpmValues.reduce((a, b) => a + b) / bpmValues.length;
      // --- FIN CORRECTION DU BPM ---

      // 4️⃣ Appel à l'Edge Function (inchangé)
      final predictionResponse = await supabase.functions.invoke(
        'predict_calories',
        body: {
          'user_id': userId,
          'Gender': gender,
          'Age': age,
          'Height': height,
          'Weight': weight,
          'Duration': duration,
          'Heart_Rate': heartRate, // ✅ Maintenant la moyenne
          'Body_Temp': bodyTemp,
        },
      );

      // ... (Reste de la gestion de la réponse)
      final predictionData = predictionResponse.data;
      print("📩 Response from Edge Function: $predictionData");

      final resultValue =
          predictionData?['calories_burned']?.toString() ?? 'Unknown';

      setState(() {
        _resultCalories = "Calories brûlées estimées : $resultValue kcal";
      });
    } catch (e) {
      setState(() {
        _resultCalories = "Erreur critique de prédiction: $e";
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  // MODIFIER CETTE FONCTION DANS VOTRE CODE
  Future<Position?> getCurrentLocation() async {
    try {
      // 💡 AJOUT DU TRY/CATCH DANS CETTE FONCTION 💡
      bool serviceEnabled;
      LocationPermission permission;

      // Teste si les services de localisation sont activés
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print("DEBUG: Geolocator Service Désactivé.");
        return null;
      }

      // Demande la permission
      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          print("DEBUG: Permission refusée par l'utilisateur.");
          return null;
        }
      }

      // Obtient la position actuelle AVEC TIMEOUT
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
        timeLimit: const Duration(seconds: 10),
      );
    } catch (e, stacktrace) {
      // 💡 Ce catch devrait afficher la VRAIE erreur si le plugin bloque 💡
      print('ERREUR NATALE DANS getCurrentLocation: $e');
      print('STACKTRACE DANS getCurrentLocation: $stacktrace');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getWeather(Position position) async {
    final lat = position.latitude;
    final lon = position.longitude;

    // Construire l'URL de l'API
    final url = Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': lat.toString(),
      'longitude': lon.toString(),
      'current': 'temperature_2m,weather_code',
      'forecast_hours': '1', // Juste pour l'actuel et une heure
      'timezone': 'auto',
    });
    print('URL Météo: $url');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      // Succès ! Décoder la réponse JSON
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      // Échec de la requête
      print('Erreur API Open-Meteo: ${response.statusCode}');
      return null;
    }
  }

  void displayWeather() async {
    final position = await getCurrentLocation();
    if (position == null) {
      print("Impossible d'obtenir la localisation.");
      return;
    }

    final weatherData = await getWeather(position);

    if (weatherData != null) {
      // Exemple d'extraction de la température actuelle
      final currentTemperature = weatherData['current']['temperature_2m'];
      final weatherCode = weatherData['current']['weather_code'];

      print('Température actuelle: $currentTemperature °C');
      print('Code Météo (à interpréter): $weatherCode');

      // Mettre à jour l'interface utilisateur de votre smartwatch avec ces valeurs
    }
  }

  // NOUVELLE FONCTION MODIFIÉE : _loadWeatherData
  void _loadWeatherData() async {
    print("DEBUG: 1. Début de _loadWeatherData");

    try {
      // 💡 Le bloc TRY doit commencer ici 💡

      // 1. Appel de la localisation
      final position = await getCurrentLocation();

      if (position == null) {
        print(
          "DEBUG: 2. Localisation est NULL (Problème de permission ou GPS)",
        );
        setState(() {
          _weatherDescription = 'Localisation désactivée';
          _weatherIcon = Icons.location_off;
        });
        return;
      }

      print("DEBUG: 3. Localisation obtenue: Lat ${position.latitude}");

      // 2. Appel de l'API Météo
      final weatherData = await getWeather(position);

      if (weatherData != null) {
        print("DEBUG: 4. Données météo reçues, mise à jour de l'UI.");

        // On vérifie directement les types JSON pour être plus sûr
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
            print(
              "DEBUG: 5a. Données 'temperature' ou 'code' manquantes dans le JSON.",
            );
            setState(() {
              _weatherDescription = 'Données incomplètes';
              _weatherIcon = Icons.error_outline;
            });
          }
        } else {
          print("DEBUG: 5b. La clé 'current' est absente ou non formatée.");
        }
      } else {
        print(
          "DEBUG: 5c. getWeather a retourné NULL (Problème API/Status code)",
        );
        // Si getWeather retourne NULL, l'état initial des variables sera conservé jusqu'au prochain setState.
        // Ici, nous n'avons rien à faire de plus, car nous voulons voir les prints.
      }
    } catch (e, stacktrace) {
      // 💡 Le catch attrape les erreurs de Localisation, de HTTP ou de Parsing JSON 💡
      print('ERREUR FATALE DANS _loadWeatherData: $e');
      print('STACKTRACE: $stacktrace');
      setState(() {
        _weatherDescription = 'Erreur critique: $e';
        _weatherIcon = Icons.warning;
      });
    }
  }

  // NOUVELLE FONCTION : Mapping des Codes WMO (très simplifiée)
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
  void initState() {
    super.initState();
    final service = DataSyncService(supabase: Supabase.instance.client);
    startSimulatedData(service);
    // 1. Charger les données qui ne dépendent pas du login actif (Météo, Avatar)
    _loadWeatherData();
    _loadUserAvatarFromDatabase();

    // 2. Écouter les changements d'état d'authentification
    // Ceci est la MEILLEURE PRATIQUE pour synchroniser l'UI avec l'état de la session.
    _authSubscription = supabase.auth.onAuthStateChange.listen((data) {
      final AuthChangeEvent event = data.event;

      // Si l'événement est un LOGIN ou la RECUPERATION d'une session existante
      if (event == AuthChangeEvent.signedIn ||
          event == AuthChangeEvent.initialSession) {
        print(
          "AUTH CHANGE: User is Signed In/Initial Session Loaded. Démarrage des services.",
        );

        // Démarrer les services qui DÉPENDENT de l'ID utilisateur (stress, vit D)
        _predictionService
            .stopAutoPrediction(); // Arrêter l'ancien service au cas où
        _loadStressPrediction();
        _loadVitaminDScore();

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
        _stressNotificationService
            .stopMonitoring(); // ✅ ARRÊTER LA SURVEILLANCE
        if (mounted) {
          setState(() {
            _stressLevel = '--'; // Réinitialiser l'état
            _vitaminDScore = '--';
          });
        }
      }
    });
  }

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
              // Correction: Navigator.pushNamed dans onTap pour l'index actuel n'est pas nécessaire
              // Navigator.pushNamed(context, AppRouter.dashboard);
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
              // ... (dans _buildDashboardBody, à l'intérieur de la Row du HEADER)
              CircleAvatar(
                // Si _userAvatarUrl est non-null, on utilise NetworkImage
                backgroundImage: _userAvatarUrl != null
                    ? NetworkImage(_userAvatarUrl!) as ImageProvider<Object>?
                    : null, // Sinon, pas d'image de fond
                // Si NetworkImage est utilisé, le child (icône) n'est pas nécessaire
                // On utilise un opérateur ternaire pour afficher l'icône seulement si l'URL est nulle
                backgroundColor: _userAvatarUrl != null
                    ? Colors.grey[300] // Fond clair si image de profil chargée
                    : Theme.of(context).primaryColor,

                child: _userAvatarUrl == null
                    ? Icon(Icons.person, color: Colors.white)
                    : null, // Pas d'enfant si l'image est chargée
              ),
              // ...
            ],
          ),

          SizedBox(height: 16),

          // 🌿 SECTION HERO : Score de bien-être (inchangé)
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
                      // Score visuel + barre de progression
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

          SizedBox(height: 24),
          // Dans _buildDashboardBody, après la section "Score de bien-être"
          CustomCard(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    _stressLevel == 'high' ? Icons.warning : Icons.psychology,
                    color: _stressLevel == 'high'
                        ? Colors.orange
                        : Colors.green,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Niveau de stress',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          _stressLevel == 'high'
                              ? 'Élevé - Surveillance active'
                              : _stressLevel == 'medium'
                              ? 'Modéré'
                              : 'Normal',
                          style: TextStyle(
                            color: _stressLevel == 'high'
                                ? Colors.orange
                                : Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_stressLevel == 'high')
                    Icon(Icons.notifications_active, color: Colors.orange),
                ],
              ),
            ),
          ),
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
                        icon: Icons.favorite,
                        label: 'Rythme cardiaque',
                        value: '${health.data.heartBpm} BPM',
                        onPressed: () =>
                            Navigator.pushNamed(context, AppRouter.heart),
                      ),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: StatCard(
                        icon: Icons.thermostat,
                        label: 'Température',
                        value:
                            '${health.data.temperature.toStringAsFixed(1)} °C',
                        onPressed: () =>
                            Navigator.pushNamed(context, AppRouter.temp),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: StatCard(
                        icon: Icons.wb_sunny,
                        label: 'UV',
                        value: health.data.uvIndex.toStringAsFixed(1),
                        onPressed: () =>
                            Navigator.pushNamed(context, AppRouter.uv),
                      ),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: StatCard(
                        icon: _weatherIcon, // Utilisation de l'icône d'état
                        label: 'Météo Actuelle',
                        value:
                            _temperature, // Utilisation de la température d'état
                        subValue:
                            _weatherDescription, // Description dans le sous-texte
                        onPressed: _loadWeatherData, // Bouton pour réactualiser
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: StatCard(
                        icon: Icons
                            .local_florist, // Icône plus pertinente pour la Vit D
                        label: 'Vitamine D (Score)',
                        // ✅ UTILISATION DE LA VARIABLE D'ÉTAT MISE À JOUR
                        value: '$_vitaminDScore / 100',
                        // ✅ On utilise la nouvelle fonction de rechargement comme action
                        onPressed: _loadVitaminDScore,
                      ),
                    ),
                    SizedBox(width: 10),
                    // Espace vide ou autre carte ici
                  ],
                ),

                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => health.randomUpdate(),
                        child: Text('Actualiser Santé (Local)'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          SizedBox(height: 16),

          // ANALYSE IA (stress, calories - inchangée)
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

                // 🧩 FORMULAIRE DE SIMULATION stress detection
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
                  'Simulation prédiction du calories',
                  style: TextStyle(fontSize: 16),
                ),

                // 🧩 FORMULAIRE DE SIMULATION calories calcul
                SizedBox(height: 8),

                Form(
                  key: _formKeyCalories,
                  child: Column(
                    children: [
                      _buildTextField(_durationController, 'Duration (min)'),
                      _buildTextField(
                        _bodyTempController,
                        'Body Temperature (°C)',
                      ),

                      const SizedBox(height: 12),

                      ElevatedButton(
                        onPressed: _loading
                            ? null
                            : () async {
                                final user =
                                    Supabase.instance.client.auth.currentUser;
                                if (user != null) {
                                  await _predictCalories(
                                    user.id,
                                  ); // ✅ nouvelle fonction
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        "Aucun utilisateur connecté",
                                      ),
                                    ),
                                  );
                                }
                              },
                        child: _loading
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : const Text("Prédire les calories brûlées"),
                      ),

                      const SizedBox(height: 16),

                      if (_resultCalories != null)
                        Text(
                          _resultCalories!,
                          style: const TextStyle(
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

          // GRAPHIQUE CARDIAQUE (inchangé)
          CustomCard(
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Rythme cardiaque', style: TextStyle(fontSize: 18)),
                    Text(
                      '${health.data.heartBpm} BPM',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Container(
                  height: 140,
                  child: RealTimeChart(), // ← chart dynamique
                ),
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
        ],
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        keyboardType: TextInputType.number,
        validator: (value) =>
            value == null || value.isEmpty ? 'Champ requis' : null,
      ),
    );
  }

  // Fonction désormais inutilisée dans ce fichier après les corrections
  // void _onCalculateTap() async { /* ... */ }

  @override
  void dispose() {
    _authSubscription.cancel(); // 👈 TRÈS IMPORTANT : Annuler l'écoute
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
