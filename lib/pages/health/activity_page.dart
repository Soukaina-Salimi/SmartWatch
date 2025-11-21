//activity_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/widgets/custom_card.dart';
import '../../data/providers/health_provider.dart';
import '../../routing/app_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:smartwatch_v2/main.dart';

class ActivityPage extends StatefulWidget {
  const ActivityPage({super.key});

  @override
  _ActivityPageState createState() => _ActivityPageState();
}

class _ActivityPageState extends State<ActivityPage> {
  int _currentIndex = 1; // 1 = Activity
  final _formKeyCalories = GlobalKey<FormState>();
  bool _loading = false;
  String? _resultCalories;
  final _durationController = TextEditingController();
  final _bodyTempController = TextEditingController();
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

  @override
  Widget build(BuildContext context) {
    final health = Provider.of<HealthProvider>(context);

    return Scaffold(
      appBar: AppBar(title: Text('Activité')),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: ListView(
          children: [
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
          ],
        ),
      ),
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
}
