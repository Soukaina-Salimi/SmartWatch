// FILE: lib/screens/breathing_exercise_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:smartwatch_v2/core/theme/app_theme.dart';

class BreathingExerciseScreen extends StatefulWidget {
  const BreathingExerciseScreen({super.key});

  @override
  State<BreathingExerciseScreen> createState() =>
      _BreathingExerciseScreenState();
}

class _BreathingExerciseScreenState extends State<BreathingExerciseScreen>
    with TickerProviderStateMixin {
  // Contrôleurs d'animation
  late AnimationController _entranceController;
  late AnimationController _breathController;
  late AnimationController _heartController;

  // Animations d'entrée
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<Color?> _colorAnimation;

  // Animations de respiration
  late Animation<double> _breathAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _heartbeatAnimation;

  int _breathCount = 0;
  String _instruction = "Inspirez profondément";
  bool _isInhaling = true;
  bool _isExerciseActive = true;

  // Nouveaux états pour les différents exercices
  int _currentExerciseIndex = 0;
  final List<BreathingExercise> _exercises = [
    BreathingExercise(
      name: "Respiration Carrée",
      description: "4-4-4-4 : Inspiration, Rétention, Expiration, Pause",
      duration: "5 min",
      color: Colors.blue,
      technique: "square",
    ),
    BreathingExercise(
      name: "Respiration 4-7-8",
      description: "Calme instantané et endormissement facile",
      duration: "4 min",
      color: Colors.purple,
      technique: "478",
    ),
    BreathingExercise(
      name: "Respiration Alternée",
      description: "Équilibre des hémisphères cérébraux",
      duration: "6 min",
      color: Colors.orange,
      technique: "alternate",
    ),
    BreathingExercise(
      name: "Respiration Ventrale",
      description: "Relaxation profonde et réduction du stress",
      duration: "5 min",
      color: Colors.green,
      technique: "belly",
    ),
    BreathingExercise(
      name: "Respiration du Feu",
      description: "Énergisante et revitalisante",
      duration: "3 min",
      color: Colors.red,
      technique: "fire",
    ),
  ];

  @override
  void initState() {
    super.initState();
    _setupEntranceAnimations();
    _setupBreathingAnimations();
    _setupHeartbeatAnimation();
  }

  void _setupEntranceAnimations() {
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _slideAnimation = Tween<double>(begin: 50.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.2, 0.8, curve: Curves.easeOutBack),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.4, 1.0, curve: Curves.elasticOut),
      ),
    );

    _colorAnimation =
        ColorTween(
          begin: _exercises[_currentExerciseIndex].color.withOpacity(0.3),
          end: _exercises[_currentExerciseIndex].color.withOpacity(0.1),
        ).animate(
          CurvedAnimation(parent: _entranceController, curve: Curves.easeInOut),
        );

    _entranceController.forward();
  }

  void _setupBreathingAnimations() {
    _breathController = AnimationController(
      vsync: this,
      duration: _getBreathingDuration(),
    );

    _breathAnimation = Tween<double>(begin: 0.6, end: 1.4).animate(
      CurvedAnimation(parent: _breathController, curve: Curves.easeInOut),
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(
        parent: _breathController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeInOut),
      ),
    );

    _breathController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _switchBreath();
        _breathController.reverse();
      } else if (status == AnimationStatus.dismissed) {
        _switchBreath();
        _breathController.forward();
      }
    });

    _startBreathing();
  }

  void _setupHeartbeatAnimation() {
    _heartController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _heartbeatAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _heartController, curve: Curves.easeInOut),
    );

    _heartController.repeat(reverse: true);
  }

  Duration _getBreathingDuration() {
    switch (_exercises[_currentExerciseIndex].technique) {
      case "square":
        return const Duration(seconds: 4); // 4-4-4-4
      case "478":
        return const Duration(seconds: 8); // 4-7-8
      case "alternate":
        return const Duration(seconds: 6); // 4-2-8-2
      case "belly":
        return const Duration(seconds: 5); // 4-1-6-1
      case "fire":
        return const Duration(seconds: 1); // Rapide
      default:
        return const Duration(seconds: 4);
    }
  }

  void _updateInstructions() {
    final technique = _exercises[_currentExerciseIndex].technique;
    setState(() {
      switch (technique) {
        case "square":
          _instruction = _isInhaling
              ? "Inspirez 4 secondes"
              : "Retenez 4 secondes";
          break;
        case "478":
          _instruction = _isInhaling
              ? "Inspirez 4 secondes"
              : "Retenez 7 secondes";
          break;
        case "alternate":
          _instruction = _isInhaling
              ? "Inspirez narine gauche"
              : "Expirez narine droite";
          break;
        case "belly":
          _instruction = _isInhaling
              ? "Gonflez le ventre"
              : "Rentrez le ventre";
          break;
        case "fire":
          _instruction = "Respirez rapidement\npar le nez";
          break;
        default:
          _instruction = _isInhaling
              ? "Inspirez profondément"
              : "Expirez lentement";
      }
    });
  }

  void _startBreathing() {
    if (_isExerciseActive) {
      _breathController.forward();
    }
  }

  void _switchBreath() {
    if (!_isExerciseActive) return;

    setState(() {
      _isInhaling = !_isInhaling;
      _updateInstructions();

      if (_isInhaling) {
        _breathCount++;
      }
    });
  }

  void _toggleExercise() {
    setState(() {
      _isExerciseActive = !_isExerciseActive;
      if (_isExerciseActive) {
        _breathController.forward();
        _heartController.repeat(reverse: true);
      } else {
        _breathController.stop();
        _heartController.stop();
      }
    });
  }

  void _resetExercise() {
    setState(() {
      _breathCount = 0;
      _isInhaling = true;
      _updateInstructions();
    });
    _breathController.reset();
    if (_isExerciseActive) {
      _breathController.forward();
    }
  }

  void _selectExercise(int index) {
    setState(() {
      _currentExerciseIndex = index;
      _breathCount = 0;
      _isInhaling = true;
      _updateInstructions();
    });

    // Mettre à jour l'animation de couleur
    _colorAnimation =
        ColorTween(
          begin: _exercises[index].color.withOpacity(0.3),
          end: _exercises[index].color.withOpacity(0.1),
        ).animate(
          CurvedAnimation(parent: _entranceController, curve: Curves.easeInOut),
        );

    // Redémarrer avec la nouvelle durée
    _breathController.duration = _getBreathingDuration();
    _breathController.reset();
    if (_isExerciseActive) {
      _breathController.forward();
    }
  }

  Widget _buildTechniqueIcon(String technique) {
    switch (technique) {
      case "square":
        return const Icon(Icons.crop_square_rounded, size: 24);
      case "478":
        return const Icon(Icons.nightlight_round, size: 24);
      case "alternate":
        return const Icon(Icons.swap_horiz_rounded, size: 24);
      case "belly":
        return const Icon(Icons.airline_seat_legroom_reduced_rounded, size: 24);
      case "fire":
        return const Icon(Icons.local_fire_department_rounded, size: 24);
      default:
        return const Icon(Icons.self_improvement_rounded, size: 24);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentExercise = _exercises[_currentExerciseIndex];
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: AnimatedBuilder(
        animation: Listenable.merge([
          _entranceController,
          _breathController,
          _heartController,
        ]),
        builder: (context, child) {
          return Stack(
            children: [
              // Arrière-plan animé avec couleur dynamique
              Container(
                width: double.infinity,
                height: double.infinity,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.topLeft,
                    radius: 1.2,
                    colors: [_colorAnimation.value!, Colors.white],
                  ),
                ),
              ),

              // Éléments décoratifs
              Positioned(
                top: size.height * 0.05,
                left: -size.width * 0.1,
                child: _FloatingCircle(
                  size: size.width * 0.25,
                  color: currentExercise.color.withOpacity(0.1),
                  animation: _entranceController,
                  delay: 0.1,
                ),
              ),

              Positioned(
                bottom: size.height * 0.15,
                right: -size.width * 0.2,
                child: _FloatingCircle(
                  size: size.width * 0.35,
                  color: currentExercise.color.withOpacity(0.08),
                  animation: _entranceController,
                  delay: 0.3,
                ),
              ),

              SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      // Header avec bouton retour
                      Transform.translate(
                        offset: Offset(0, _slideAnimation.value),
                        child: Opacity(
                          opacity: _fadeAnimation.value,
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 10,
                                      offset: const Offset(0, 5),
                                    ),
                                  ],
                                ),
                                child: IconButton(
                                  icon: const Icon(
                                    Icons.arrow_back_rounded,
                                    size: 20,
                                  ),
                                  onPressed: () => Navigator.pop(context),
                                  color: Colors.grey[700],
                                ),
                              ),
                              const Spacer(),
                              Text(
                                'Exercices Respiratoires',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.grey[800],
                                ),
                              ),
                              const Spacer(),
                              const SizedBox(width: 40),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Sélecteur d'exercices
                      Transform.translate(
                        offset: Offset(0, _slideAnimation.value * 0.5),
                        child: Opacity(
                          opacity: _fadeAnimation.value,
                          child: SizedBox(
                            height: 100,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: _exercises.length,
                              itemBuilder: (context, index) {
                                final exercise = _exercises[index];
                                return _ExerciseSelector(
                                  exercise: exercise,
                                  isSelected: index == _currentExerciseIndex,
                                  onTap: () => _selectExercise(index),
                                );
                              },
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Carte principale d'exercice
                      Transform.scale(
                        scale: _scaleAnimation.value,
                        child: Opacity(
                          opacity: _fadeAnimation.value,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(32),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(32),
                              color: Colors.white,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.15),
                                  blurRadius: 40,
                                  offset: const Offset(0, 25),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                // Nom de l'exercice
                                Text(
                                  currentExercise.name,
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: currentExercise.color,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  currentExercise.description,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                ),

                                const SizedBox(height: 20),

                                // Compteur de respirations
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Column(
                                      children: [
                                        Text(
                                          'Respirations',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey[600],
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '$_breathCount',
                                          style: TextStyle(
                                            fontSize: 36,
                                            fontWeight: FontWeight.w800,
                                            color: currentExercise.color,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(width: 40),
                                    ScaleTransition(
                                      scale: _heartbeatAnimation,
                                      child: Column(
                                        children: [
                                          Text(
                                            'Rythme',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey[600],
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Icon(
                                            Icons.favorite_rounded,
                                            color: currentExercise.color,
                                            size: 32,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 30),

                                // Animation de respiration
                                ScaleTransition(
                                  scale: _breathAnimation,
                                  child: Container(
                                    width: 200,
                                    height: 200,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: _isInhaling
                                            ? [
                                                currentExercise.color,
                                                currentExercise.color
                                                    .withOpacity(0.7),
                                              ]
                                            : [
                                                currentExercise.color.withGreen(
                                                  150,
                                                ),
                                                currentExercise.color.withGreen(
                                                  200,
                                                ),
                                              ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: currentExercise.color
                                              .withOpacity(0.4),
                                          blurRadius: 30,
                                        ),
                                      ],
                                    ),
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        Container(
                                          width: 180,
                                          height: 180,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: Colors.white.withOpacity(
                                                0.8,
                                              ),
                                              width: 3,
                                            ),
                                          ),
                                        ),
                                        ScaleTransition(
                                          scale: _pulseAnimation,
                                          child: _buildTechniqueIcon(
                                            currentExercise.technique,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 30),

                                // Instructions
                                Text(
                                  _instruction,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[800],
                                    height: 1.4,
                                  ),
                                ),

                                const SizedBox(height: 8),

                                Text(
                                  _getDurationText(),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[500],
                                  ),
                                ),

                                const SizedBox(height: 30),

                                // Boutons de contrôle
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    _ControlButton(
                                      icon: _isExerciseActive
                                          ? Icons.pause_rounded
                                          : Icons.play_arrow_rounded,
                                      label: _isExerciseActive
                                          ? 'Pause'
                                          : 'Reprendre',
                                      onPressed: _toggleExercise,
                                      isPrimary: true,
                                      color: currentExercise.color,
                                    ),
                                    const SizedBox(width: 16),
                                    _ControlButton(
                                      icon: Icons.replay_rounded,
                                      label: 'Recommencer',
                                      onPressed: _resetExercise,
                                      isPrimary: false,
                                      color: currentExercise.color,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 30),

                      // Section exercices de défoulement
                      Transform.translate(
                        offset: Offset(0, _slideAnimation.value * 0.5),
                        child: Opacity(
                          opacity: _fadeAnimation.value,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                child: Text(
                                  'Exercices de Défoulement Rapides',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.grey[800],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              _ExerciseCard(
                                title: '💪 Pompes Rapides',
                                description:
                                    '10 répétitions - Libère la tension musculaire',
                                duration: '1 min',
                                onTap: () =>
                                    _startQuickExercise('Pompes Rapides'),
                                color: currentExercise.color,
                              ),
                              _ExerciseCard(
                                title: '👊 Shadow Boxing',
                                description:
                                    'Libère la frustration et l\'énergie négative',
                                duration: '2 min',
                                onTap: () =>
                                    _startQuickExercise('Shadow Boxing'),
                                color: currentExercise.color,
                              ),
                              _ExerciseCard(
                                title: '🔄 Rotation Épaules',
                                description:
                                    'Détend le haut du corps et réduit les tensions',
                                duration: '30 sec',
                                onTap: () =>
                                    _startQuickExercise('Rotation Épaules'),
                                color: currentExercise.color,
                              ),
                              _ExerciseCard(
                                title: '🧘‍♂️ Étirement complet',
                                description:
                                    'Relâche toutes les tensions musculaires',
                                duration: '1 min',
                                onTap: () =>
                                    _startQuickExercise('Étirement complet'),
                                color: currentExercise.color,
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _getDurationText() {
    final technique = _exercises[_currentExerciseIndex].technique;
    switch (technique) {
      case "square":
        return "4s Inspiration • 4s Rétention • 4s Expiration • 4s Pause";
      case "478":
        return "4s Inspiration • 7s Rétention • 8s Expiration";
      case "alternate":
        return "4s Inspiration • 2s Rétention • 8s Expiration • 2s Pause";
      case "belly":
        return "4s Inspiration • 1s Pause • 6s Expiration • 1s Pause";
      case "fire":
        return "Respirations rapides et puissantes";
      default:
        return "4 secondes d'inspiration • 4 secondes d'expiration";
    }
  }

  void _startQuickExercise(String exercise) {
    showDialog(
      context: context,
      builder: (context) => _ExerciseTimerDialog(
        exercise: exercise,
        color: _exercises[_currentExerciseIndex].color,
      ),
    );
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _breathController.dispose();
    _heartController.dispose();
    super.dispose();
  }
}

// Nouvelle classe pour les exercices de respiration
class BreathingExercise {
  final String name;
  final String description;
  final String duration;
  final Color color;
  final String technique;

  BreathingExercise({
    required this.name,
    required this.description,
    required this.duration,
    required this.color,
    required this.technique,
  });
}

// Widget pour le sélecteur d'exercices
class _ExerciseSelector extends StatelessWidget {
  final BreathingExercise exercise;
  final bool isSelected;
  final VoidCallback onTap;

  const _ExerciseSelector({
    required this.exercise,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 120,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? exercise.color : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
          border: Border.all(
            color: isSelected ? exercise.color : Colors.grey[300]!,
            width: 2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.self_improvement_rounded,
              color: isSelected ? Colors.white : exercise.color,
              size: 24,
            ),
            const SizedBox(height: 8),
            Text(
              exercise.name.split(' ').first,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : Colors.grey[800],
              ),
            ),
            Text(
              exercise.duration,
              style: TextStyle(
                fontSize: 10,
                color: isSelected
                    ? Colors.white.withOpacity(0.8)
                    : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// [Les autres classes _FloatingCircle, _ControlButton, _ExerciseCard, _ExerciseTimerDialog restent similaires avec adaptation des couleurs]

class _FloatingCircle extends StatelessWidget {
  final double size;
  final Color color;
  final Animation<double> animation;
  final double delay;

  const _FloatingCircle({
    required this.size,
    required this.color,
    required this.animation,
    required this.delay,
  });

  @override
  Widget build(BuildContext context) {
    final circleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: animation,
        curve: Interval(delay, 1.0, curve: Curves.easeInOut),
      ),
    );

    return AnimatedBuilder(
      animation: circleAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: circleAnimation.value,
          child: Transform.scale(
            scale: circleAnimation.value,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(shape: BoxShape.circle, color: color),
            ),
          ),
        );
      },
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool isPrimary;
  final Color color;

  const _ControlButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    required this.isPrimary,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: isPrimary ? color : Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
            border: Border.all(
              color: isPrimary ? Colors.transparent : color.withOpacity(0.3),
              width: 2,
            ),
          ),
          child: IconButton(
            icon: Icon(icon, size: 24),
            onPressed: onPressed,
            color: isPrimary ? Colors.white : color,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
      ],
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  final String title;
  final String description;
  final String duration;
  final VoidCallback onTap;
  final Color color;

  const _ExerciseCard({
    required this.title,
    required this.description,
    required this.duration,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 12,
        ),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.fitness_center_rounded, color: color),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        subtitle: Text(
          description,
          style: TextStyle(color: Colors.grey[600], fontSize: 14),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                duration,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}

class _ExerciseTimerDialog extends StatefulWidget {
  final String exercise;
  final Color color;

  const _ExerciseTimerDialog({required this.exercise, required this.color});

  @override
  State<_ExerciseTimerDialog> createState() => _ExerciseTimerDialogState();
}

class _ExerciseTimerDialogState extends State<_ExerciseTimerDialog> {
  late int _secondsRemaining;
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _secondsRemaining = _getExerciseDuration(widget.exercise);
    _startTimer();
  }

  int _getExerciseDuration(String exercise) {
    switch (exercise) {
      case 'Pompes Rapides':
        return 60;
      case 'Shadow Boxing':
        return 120;
      case 'Rotation Épaules':
        return 30;
      case 'Étirement complet':
        return 60;
      default:
        return 60;
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_secondsRemaining > 0) {
          _secondsRemaining--;
        } else {
          _timer.cancel();
          _showCompletionDialog();
        }
      });
    });
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Exercice Terminé! 🎉'),
        content: const Text('Félicitations! Vous avez complété l\'exercice.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: Text(
              'Super!',
              style: TextStyle(
                color: widget.color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.exercise,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 120,
                  height: 120,
                  child: CircularProgressIndicator(
                    value:
                        1 -
                        (_secondsRemaining /
                            _getExerciseDuration(widget.exercise)),
                    strokeWidth: 8,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(widget.color),
                  ),
                ),
                Text(
                  '$_secondsRemaining',
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'secondes',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () {
                      _timer.cancel();
                      Navigator.pop(context);
                    },
                    child: const Text('Arrêter'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.color,
                    ),
                    onPressed: () {
                      _timer.cancel();
                      Navigator.pop(context);
                    },
                    child: const Text(
                      'Terminé',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }
}
