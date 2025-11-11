import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smartwatch_v2/routing/app_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/widgets/custom_card.dart';
import '../../core/widgets/stat_card.dart';
import '../../core/widgets/chart_widget.dart';
import '../../data/providers/health_provider.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';

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
  @override
  _DashboardPageState createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  // --- NOUVELLE VARIABLE D'ÉTAT ---
  String _vitaminDScore = '--'; // Affichera le score ou '--' en attendant
  String? _userAvatarUrl;
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

  // 📸 NOUVELLE FONCTION : Charger l'URL de l'avatar
  // 📸 FONCTION CORRIGÉE : Charger l'URL de l'avatar depuis userMetadata
  // 📸 NOUVELLE FONCTION : Charger l'URL de l'avatar depuis la table 'user_configurations'
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

  Future<void> _predictStress(String userId) async {
    setState(() {
      _loading = true;
      _result = null;
    });

    try {
      // 🔹 Appel à l’Edge Function
      final predictionResponse = await Supabase.instance.client.functions
          .invoke(
            'prediction',
            body: {
              'user_id': userId,
              'Gender': int.tryParse(_genderController.text) ?? 0,
              'Age': int.tryParse(_ageController.text) ?? 0,
              'Occupation': int.tryParse(_occupationController.text) ?? 0,
              'Sleep_Duration':
                  double.tryParse(_sleepDurationController.text) ?? 0.0,
              'Quality_of_Sleep':
                  double.tryParse(_sleepQualityController.text) ?? 0.0,
              'Physical_Activity_Level':
                  double.tryParse(_activityController.text) ?? 0.0,
              'BMI_Category': double.tryParse(_bmiController.text) ?? 0.0,
              'Blood_Pressure': double.tryParse(_bpController.text) ?? 0.0,
              'Heart_Rate': double.tryParse(_heartRateController.text) ?? 0.0,
              'Daily_Steps': double.tryParse(_stepsController.text) ?? 0.0,
              'Sleep_Disorder':
                  int.tryParse(_sleepDisorderController.text) ?? 0,
            },
          );

      final predictionData = predictionResponse.data;
      print("📩 Response from Edge Function: $predictionData");

      final resultValue = predictionData['stress_level'] ?? 'Unknown';

      setState(() {
        _result = "Résultat : $resultValue";
      });
    } catch (e) {
      setState(() {
        _result = "Erreur : $e";
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _predictCalories(String userId) async {
    setState(() {
      _loading = true;
      _resultCalories = null;
    });

    try {
      // 🔹 Appel à l’Edge Function Supabase (nom = prediction_calories_brunt)
      final predictionResponse = await Supabase.instance.client.functions.invoke(
        'predict_calories', // ⚠️ Le nom doit correspondre à celui du dossier de ta Edge Function
        body: {
          'user_id': userId,
          'Gender': int.tryParse(_genderController.text) ?? 0,
          'Age': int.tryParse(_ageController.text) ?? 0,
          'Height': double.tryParse(_heightController.text) ?? 0.0,
          'Weight': double.tryParse(_weightController.text) ?? 0.0,
          'Duration': double.tryParse(_durationController.text) ?? 0.0,
          'Heart_Rate': double.tryParse(_heartRateController.text) ?? 0.0,
          'Body_Temp': double.tryParse(_bodyTempController.text) ?? 0.0,
        },
      );

      // 🔹 Vérification de la réponse
      final predictionData = predictionResponse.data;
      print("📩 Response from Edge Function: $predictionData");

      // 🔹 Récupération du champ 'calories_burned' (clé de sortie dans la Edge Function)
      final resultValue =
          predictionData?['calories_burned']?.toString() ?? 'Unknown';

      setState(() {
        _resultCalories = "Calories brûlées estimées : $resultValue kcal";
      });
    } catch (e) {
      setState(() {
        _resultCalories = "Erreur : $e";
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

  @override
  void initState() {
    super.initState();
    // 💡 APPEL DE LA FONCTION MÉTÉO AU DÉMARRAGE 💡
    _loadWeatherData();
    print('DEBUG: Appel de _loadVitaminDScore()');

    // ✅ NOUVEL APPEL : Chargement du score de Vitamine D
    _loadVitaminDScore();

    _loadUserAvatarFromDatabase();
    ();
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
                        "$scoreLabel",
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
                        value: '${health.data.uvIndex.toStringAsFixed(1)}',
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
                      _buildTextField(_genderController, 'Gender (0/1)'),
                      _buildTextField(_ageController, 'Age'),
                      _buildTextField(
                        _occupationController,
                        'Occupation (code)',
                      ),
                      _buildTextField(
                        _sleepDurationController,
                        'Sleep Duration (heures)',
                      ),
                      _buildTextField(
                        _sleepQualityController,
                        'Quality of Sleep (1–10)',
                      ),
                      _buildTextField(
                        _activityController,
                        'Physical Activity Level',
                      ),
                      _buildTextField(_bmiController, 'BMI Category'),
                      _buildTextField(_bpController, 'Blood Pressure'),
                      _buildTextField(_heartRateController, 'Heart Rate'),
                      _buildTextField(_stepsController, 'Daily Steps'),
                      _buildTextField(
                        _sleepDisorderController,
                        'Sleep Disorder (0/1)',
                      ),

                      SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _loading
                            ? null
                            : () {
                                final user =
                                    Supabase.instance.client.auth.currentUser;
                                if (user != null) {
                                  _predictStress(
                                    user.id,
                                  ); // On passe l'id réel de l'utilisateur connecté
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        "Aucun utilisateur connecté",
                                      ),
                                    ),
                                  );
                                }
                              },

                        child: _loading
                            ? CircularProgressIndicator(color: Colors.white)
                            : Text("Prédire le stress"),
                      ),
                      SizedBox(height: 16),
                      if (_result != null)
                        Text(
                          _result!,
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
                      _buildTextField(
                        _genderController,
                        'Gender (0: Female, 1: Male)',
                      ),
                      _buildTextField(_ageController, 'Age'),
                      _buildTextField(_heightController, 'Height (cm)'),
                      _buildTextField(_weightController, 'Weight (kg)'),
                      _buildTextField(_durationController, 'Duration (min)'),
                      _buildTextField(_heartRateController, 'Heart Rate (bpm)'),
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
                ChartWidget(spots: health.chartSpots, height: 140),
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
    super.dispose();
  }
}
