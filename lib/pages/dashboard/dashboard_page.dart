// FILE: lib/pages/dashboard/dashboard_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smartwatch_v2/routing/app_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/widgets/custom_card.dart';
import '../../core/widgets/stat_card.dart';
import '../../core/widgets/chart_widget.dart';
import '../../data/providers/health_provider.dart';
import '../../data/providers/user_provider.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class DashboardPage extends StatefulWidget {
  @override
  _DashboardPageState createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _currentIndex = 0;
  final _formKey = GlobalKey<FormState>();
  final _formKeyCalories = GlobalKey<FormState>();
  bool _loading = false;
  String? _result;
  String? _resultCalories;

  // Champs du formulaire
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

  @override
  Widget build(BuildContext context) {
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
              Navigator.pushNamed(context, AppRouter.dashboard);
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
              CircleAvatar(
                backgroundColor: Theme.of(context).primaryColor,
                child: Icon(Icons.person, color: Colors.white),
              ),
            ],
          ),

          SizedBox(height: 16),

          // 🌿 SECTION HERO : Score de bien-être
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
                  // Cercle décoratif doux en fond
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
                      child: ElevatedButton(
                        onPressed: () => health.randomUpdate(),
                        child: Text('Actualiser'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          SizedBox(height: 16),

          // ANALYSE IA
          // 🌿 SECTION ANALYSE IA EXISTANTE
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

          // GRAPHIQUE CARDIAQUE
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
    super.dispose();
  }
}
