import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:smartwatch_v2/main.dart';
import 'package:smartwatch_v2/routing/app_router.dart';
import 'package:smartwatch_v2/core/widgets/custom_card.dart';

class VitaminDEstimatorService {
  final SupabaseClient supabase = Supabase.instance.client;

  /// 🔹 CRÉER la configuration utilisateur si elle n'existe pas
  Future<void> _ensureUserConfigExists(String userId) async {
    try {
      print("🔍 Vérification user_conf pour: $userId");

      final existing = await supabase
          .from('user_configurations')
          .select()
          .eq('user_id', userId);

      if (existing.isEmpty) {
        print("➕ Création user_conf avec valeurs par défaut");

        await supabase.from('user_configurations').upsert({
          'user_id': userId,
          'skin_type': 3,
          'age': 30,
          'weight': 70,
          'height': 170,
          'gender': 'other',
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });

        print("✅ User config créé avec succès");
      } else {
        print("✅ User config existe déjà");
      }
    } catch (e) {
      print("❌ Erreur création user_conf: $e");
      // On continue quand même, l'Edge Function gérera les valeurs par défaut
    }
  }

  /// 🔹 Récupérer latitude & longitude
  Future<Position> _getLocation() async {
    bool enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      throw Exception("Veuillez activer la localisation.");
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception("Permission localisation refusée.");
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception(
        "Permission localisation définitivement refusée. Activez-la dans les paramètres.",
      );
    }

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.medium,
    );
  }

  /// 🔹 Lire le UV intensity dans user_metrics
  Future<num> _getUvIntensity(String userId) async {
    try {
      final response = await supabase
          .from('user_metrics')
          .select('uv_index')
          .eq('user_id', userId)
          .order('ts', ascending: false)
          .limit(1);

      if (response.isEmpty || response[0]['uv_index'] == null) {
        print(
          "⚠️ Aucune donnée UV trouvée, utilisation valeur par défaut: 5.0",
        );
        return 5.0;
      }

      return response[0]['uv_index'];
    } catch (e) {
      print("⚠️ Erreur récupération UV, utilisation valeur par défaut: 5.0");
      return 5.0;
    }
  }

  /// 🔹 Appeler l'Edge Function - VERSION CORRIGÉER
  Future<Map<String, dynamic>> estimateVitaminD(String userId) async {
    try {
      print("🟡 Début estimateVitaminD pour: $userId");

      // 1. S'assurer que user_conf existe
      await _ensureUserConfigExists(userId);

      // 2. Récupérer la localisation
      print("📍 Récupération position...");
      final pos = await _getLocation();
      print("📍 Position: ${pos.latitude}, ${pos.longitude}");

      // 3. Récupérer UV intensity
      print("☀️ Récupération UV intensity...");
      final uvIntensity = await _getUvIntensity(userId);
      print("☀️ UV Intensity: $uvIntensity");

      // 4. Durée d'exposition (5 heures = 300 minutes)
      final exposureDuration = 300;

      // 5. Préparer les données pour l'Edge Function
      final requestBody = {
        "user_id": userId,
        "uv_intensity": uvIntensity,
        "exposure_duration": exposureDuration,
        "latitude": pos.latitude,
        "longitude": pos.longitude,
        "timestamp": DateTime.now().toIso8601String(),
      };

      print("📤 Appel Edge Function avec:");
      print("  - user_id: $userId");
      print("  - uv_intensity: $uvIntensity");
      print("  - exposure_duration: $exposureDuration");
      print("  - latitude: ${pos.latitude}");
      print("  - longitude: ${pos.longitude}");
      print("  - body size: ${requestBody.toString().length} bytes");

      // 6. Appeler l'Edge Function
      final response = await supabase.functions.invoke(
        "vitamin_d_estimator",
        body: requestBody,
      );

      print("📥 Réponse reçue, status: ${response.status}");

      if (response.data == null) {
        throw Exception("Edge Function a retourné une réponse vide");
      }

      final result = Map<String, dynamic>.from(response.data);
      print("✅ Résultat: ${result.keys.toList()}");

      return result;
    } catch (e) {
      print("🔴 Erreur dans estimateVitaminD: $e");
      print("🔴 Type d'erreur: ${e.runtimeType}");
      rethrow;
    }
  }
}

class VitaminDResultScreen extends StatefulWidget {
  final String userId;

  const VitaminDResultScreen({required this.userId, super.key});

  @override
  _VitaminDResultScreenState createState() => _VitaminDResultScreenState();
}

class _VitaminDResultScreenState extends State<VitaminDResultScreen> {
  Map<String, dynamic>? result;
  bool loading = true;
  String? error;
  int _currentIndex = 2; // Analytics

  final VitaminDEstimatorService _service = VitaminDEstimatorService();

  @override
  void initState() {
    super.initState();
    loadVitaminD();
  }

  Future<void> loadVitaminD() async {
    try {
      print("🚀 Début loadVitaminD");
      final data = await _service.estimateVitaminD(widget.userId);
      setState(() {
        result = data;
        loading = false;
      });
      print("🎉 LoadVitaminD terminé avec succès");
    } catch (e) {
      print("💥 Erreur loadVitaminD: $e");
      setState(() {
        error = e.toString();
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Estimation Vitamine D'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Padding(padding: EdgeInsets.all(16), child: _buildContent()),
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

  Widget _buildContent() {
    if (loading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              "Calcul de votre vitamine D...",
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 8),
            Text(
              "Cela peut prendre quelques secondes",
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    if (error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red),
            SizedBox(height: 16),
            Text(
              "Erreur",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                error!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey[700]),
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: loadVitaminD,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text("Réessayer", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }

    final r = result!;
    return ListView(
      children: [
        // Carte principale des résultats
        CustomCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.sunny, color: Theme.of(context).primaryColor),
                  SizedBox(width: 8),
                  Text(
                    'Résultats Vitamine D',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              SizedBox(height: 16),
              _buildResultItem(
                'Vitamine D produite',
                '${r['vitamin_d_ui']} UI',
                Icons.health_and_safety,
                Colors.green,
              ),
              _buildResultItem(
                'Exposition effective',
                '${r['effective_exposure_minutes']} min',
                Icons.timer,
                Colors.blue,
              ),
              _buildResultItem(
                'UV Index',
                '${r['uv_index']}',
                Icons.wb_sunny,
                Colors.orange,
              ),
              _buildResultItem(
                'Pourcentage quotidien',
                '${r['percentage_daily']}%',
                Icons.percent,
                Colors.purple,
              ),
            ],
          ),
        ),

        SizedBox(height: 16),

        // Carte des recommandations
        CustomCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.lightbulb_outline,
                    color: Theme.of(context).primaryColor,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Recommandations',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              SizedBox(height: 12),
              ...List<Widget>.from(
                (r['recommendations'] as List).map(
                  (msg) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.fiber_manual_record,
                          size: 8,
                          color: Theme.of(context).primaryColor,
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(msg, style: TextStyle(fontSize: 14)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        SizedBox(height: 16),

        // Bouton de rafraîchissement
        ElevatedButton(
          onPressed: loadVitaminD,
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).primaryColor,
            minimumSize: Size(double.infinity, 50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.refresh, color: Colors.white),
              SizedBox(width: 8),
              Text(
                "Actualiser les données",
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildResultItem(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
                SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
