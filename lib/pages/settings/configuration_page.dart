// FILE: lib/pages/settings/configuration_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smartwatch_v2/core/theme/app_theme.dart';
import 'package:smartwatch_v2/main.dart';
import 'package:smartwatch_v2/routing/app_router.dart';
import '../../core/widgets/custom_card.dart';
import '../../data/providers/user_provider.dart';

class ConfigurationPage extends StatefulWidget {
  @override
  _ConfigurationPageState createState() => _ConfigurationPageState();
}

class _ConfigurationPageState extends State<ConfigurationPage> {
  // 1. Contrôleurs pour les champs de saisie
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _sleepdurationController =
      TextEditingController();

  // 2. Variables d'état pour le genre et l'insomnie
  String? _selectedGender;
  bool _hasInsomnia = false;

  final List<String> _genders = ['Homme', 'Femme', 'Autre'];

  @override
  void dispose() {
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _sleepdurationController.dispose();

    super.dispose();
  }

  void _saveConfiguration() async {
    // Préparer les données saisies par l'utilisateur
    final configData = {
      'age': int.tryParse(_ageController.text),
      'height_cm': int.tryParse(_heightController.text),
      'weight_kg': double.tryParse(_weightController.text),
      'sleep_duration': double.tryParse(_sleepdurationController.text),
      'gender': _selectedGender,
      'has_insomnia': _hasInsomnia,
    };

    try {
      // Vérifier si l'utilisateur est bien connecté
      final user = supabase.auth.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Veuillez vous connecter avant de sauvegarder."),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // 🔍 Vérifier si une configuration existe déjà pour cet utilisateur
      final existing = await supabase
          .from('user_configurations')
          .select()
          .eq('user_id', user.id)
          .maybeSingle();

      if (existing != null) {
        // 🟠 Mise à jour si la configuration existe déjà
        await supabase
            .from('user_configurations')
            .update({
              'age': configData['age'],
              'gender': configData['gender'],
              'height_cm': configData['height_cm'],
              'weight_kg': configData['weight_kg'],
              'has_insomnia': configData['has_insomnia'],
              'sleep_duration': configData['sleep_duration'],
            })
            .eq('user_id', user.id);
      } else {
        // 🟢 Insertion si aucune configuration n’existe encore
        await supabase.from('user_configurations').insert({
          'user_id': user.id,
          'age': configData['age'],
          'gender': configData['gender'],
          'height_cm': configData['height_cm'],
          'weight_kg': configData['weight_kg'],
          'has_insomnia': configData['has_insomnia'],
          'sleep_duration': configData['sleep_duration'],
        });
      }

      // ✅ Notification de succès
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Configuration sauvegardée avec succès !'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Erreur Supabase: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de la sauvegarde : $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  int _currentIndex = 3; // 3 = Settings par défaut

  // --- Composants de l'interface ---

  Widget _buildNumericField({
    required TextEditingController controller,
    required String label,
    required String suffix,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: label,
          suffixText: suffix,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        style: const TextStyle(fontSize: 16),
      ),
    );
  }

  Widget _buildGenderSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
        color: AppTheme.lightTheme.primaryColor,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          hint: const Text('Sélectionnez votre genre'),
          value: _selectedGender,
          items: _genders.map((String value) {
            return DropdownMenuItem<String>(value: value, child: Text(value));
          }).toList(),
          onChanged: (String? newValue) {
            setState(() {
              _selectedGender = newValue;
            });
          },
        ),
      ),
    );
  }

  Widget _buildInsomniaCheckbox() {
    return Card(
      elevation: 0, // Style épuré sans ombre portée
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Souffrez-vous d\'insomnie ou de troubles du sommeil ?',
                style: TextStyle(
                  fontSize: 16,
                  color: AppTheme.lightTheme.primaryColor,
                ),
              ),
            ),
            Switch(
              value: _hasInsomnia,
              onChanged: (bool newValue) {
                setState(() {
                  _hasInsomnia = newValue;
                });
              },
              activeColor: AppTheme.lightTheme.primaryColor,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Configuration du Profil',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- Carte d'informations ---
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Données Personnelles (Pour l\'IA)',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.lightTheme.primaryColor,
                      ),
                    ),
                    const Divider(height: 30),

                    // Champ AGE
                    _buildNumericField(
                      controller: _ageController,
                      label: 'Âge',
                      suffix: 'ans',
                    ),

                    // Sélecteur de GENRE
                    _buildGenderSelector(),
                    const SizedBox(height: 16),

                    // Champ TAILLE (HEIGHT)
                    _buildNumericField(
                      controller: _heightController,
                      label: 'Taille',
                      suffix: 'cm',
                    ),

                    // Champ POIDS (WEIGHT)
                    _buildNumericField(
                      controller: _weightController,
                      label: 'Poids',
                      suffix: 'kg',
                    ),
                    // Champ sleep_duration
                    _buildNumericField(
                      controller: _sleepdurationController,
                      label: 'sleep_duration',
                      suffix: 'H',
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 30),

            // --- Case à cocher pour l'Insomnie ---
            _buildInsomniaCheckbox(),

            const SizedBox(height: 40),

            // --- Bouton de Sauvegarde (Style Plein Rouge) ---
            ElevatedButton(
              onPressed: _saveConfiguration,
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    AppTheme.lightTheme.primaryColor, // Rouge d'accentuation
                minimumSize: const Size(double.infinity, 55),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                elevation: 5,
              ),
              child: const Text(
                'Sauvegarder la Configuration',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
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
          setState(() => _currentIndex = i); // <-- maintenant ok
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
}
