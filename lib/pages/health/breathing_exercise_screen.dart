// FILE: lib/screens/breathing_exercise_screen.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:smartwatch_v2/core/theme/app_theme.dart';

// FILE: lib/screens/breathing_exercise_screen.dart
import 'package:flutter/material.dart';

class BreathingExerciseScreen extends StatefulWidget {
  const BreathingExerciseScreen({super.key});

  @override
  State<BreathingExerciseScreen> createState() =>
      _BreathingExerciseScreenState();
}

class _BreathingExerciseScreenState extends State<BreathingExerciseScreen>
    with TickerProviderStateMixin {
  // CHANGEMENT: SingleTickerProviderStateMixin → TickerProviderStateMixin
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<Color?> _colorAnimation;

  // Animations de respiration
  late AnimationController _breathController;
  late Animation<double> _breathAnimation;
  late Animation<double> _pulseAnimation;

  int _breathCount = 0;
  String _instruction = "Inspirez profondément";
  bool _isInhaling = true;
  bool _isExerciseActive = true;

  @override
  void initState() {
    super.initState();
    _setupEntranceAnimations();
    _setupBreathingAnimations();
  }

  void _setupEntranceAnimations() {
    _controller = AnimationController(
      vsync: this, // ✅ Maintenant compatible avec multiple tickers
      duration: const Duration(milliseconds: 1500),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _slideAnimation = Tween<double>(begin: 50.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.2, 0.8, curve: Curves.easeOutBack),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.4, 1.0, curve: Curves.elasticOut),
      ),
    );

    _colorAnimation = ColorTween(
      begin: AppTheme.lightTheme.primaryColor.withOpacity(0.3),
      end: AppTheme.lightTheme.primaryColor.withOpacity(0.1),
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _controller.forward();
  }

  void _setupBreathingAnimations() {
    _breathController = AnimationController(
      vsync: this, // ✅ Même vsync, maintenant compatible
      duration: const Duration(seconds: 4),
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

  void _startBreathing() {
    if (_isExerciseActive) {
      _breathController.forward();
    }
  }

  void _switchBreath() {
    if (!_isExerciseActive) return;

    setState(() {
      _isInhaling = !_isInhaling;
      if (_isInhaling) {
        _breathCount++;
        _instruction = "Inspirez profondément\npar le nez";
      } else {
        _instruction = "Expirez lentement\npar la bouche";
      }
    });
  }

  void _toggleExercise() {
    setState(() {
      _isExerciseActive = !_isExerciseActive;
      if (_isExerciseActive) {
        _breathController.forward();
      } else {
        _breathController.stop();
      }
    });
  }

  void _resetExercise() {
    setState(() {
      _breathCount = 0;
      _isInhaling = true;
      _instruction = "Inspirez profondément\npar le nez";
    });
    _breathController.reset();
    if (_isExerciseActive) {
      _breathController.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = AppTheme.lightTheme.primaryColor;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: AnimatedBuilder(
        animation: Listenable.merge([
          _controller,
          _breathController,
        ]), // ✅ Écouter les deux controllers
        builder: (context, child) {
          return Stack(
            children: [
              // Arrière-plan animé
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
                  color: primaryColor.withOpacity(0.1),
                  animation: _controller,
                  delay: 0.1,
                ),
              ),

              Positioned(
                bottom: size.height * 0.15,
                right: -size.width * 0.2,
                child: _FloatingCircle(
                  size: size.width * 0.35,
                  color: primaryColor.withOpacity(0.08),
                  animation: _controller,
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
                                'Exercice Anti-Stress',
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

                      const SizedBox(height: 40),

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
                                BoxShadow(
                                  color: Colors.white.withOpacity(0.9),
                                  blurRadius: 10,
                                  offset: const Offset(0, -5),
                                ),
                              ],
                              border: Border.all(
                                color: Colors.white.withOpacity(0.8),
                                width: 1,
                              ),
                            ),
                            child: Column(
                              children: [
                                // Compteur de respirations
                                Text(
                                  'Respirations',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '$_breathCount',
                                  style: TextStyle(
                                    fontSize: 48,
                                    fontWeight: FontWeight.w800,
                                    color: primaryColor,
                                    letterSpacing: -1,
                                  ),
                                ),

                                const SizedBox(height: 40),

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
                                                primaryColor,
                                                Color.alphaBlend(
                                                  Colors.blueAccent.withOpacity(
                                                    0.6,
                                                  ),
                                                  primaryColor,
                                                ),
                                              ]
                                            : [
                                                Colors.green[400]!,
                                                Colors.green[300]!,
                                              ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color:
                                              (_isInhaling
                                                      ? primaryColor
                                                      : Colors.green[400]!)
                                                  .withOpacity(0.4),
                                          blurRadius: 30,
                                          spreadRadius: 5,
                                        ),
                                      ],
                                    ),
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        // Cercle principal animé
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

                                        // Icône animée
                                        ScaleTransition(
                                          scale: _pulseAnimation,
                                          child: Icon(
                                            _isInhaling
                                                ? Icons.arrow_upward_rounded
                                                : Icons.arrow_downward_rounded,
                                            size: 40,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 40),

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
                                  '4 secondes d\'inspiration • 4 secondes d\'expiration',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[500],
                                  ),
                                ),

                                const SizedBox(height: 32),

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
                                    ),
                                    const SizedBox(width: 16),
                                    _ControlButton(
                                      icon: Icons.replay_rounded,
                                      label: 'Recommencer',
                                      onPressed: _resetExercise,
                                      isPrimary: false,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),

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
                              ),
                              _ExerciseCard(
                                title: '👊 Shadow Boxing',
                                description:
                                    'Libère la frustration et l\'énergie négative',
                                duration: '2 min',
                                onTap: () =>
                                    _startQuickExercise('Shadow Boxing'),
                              ),
                              _ExerciseCard(
                                title: '🔄 Rotation Épaules',
                                description:
                                    'Détend le haut du corps et réduit les tensions',
                                duration: '30 sec',
                                onTap: () =>
                                    _startQuickExercise('Rotation Épaules'),
                              ),
                              _ExerciseCard(
                                title: '🧘‍♂️ Étirement complet',
                                description:
                                    'Relâche toutes les tensions musculaires',
                                duration: '1 min',
                                onTap: () =>
                                    _startQuickExercise('Étirement complet'),
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

  void _startQuickExercise(String exercise) {
    showDialog(
      context: context,
      builder: (context) => _ExerciseTimerDialog(exercise: exercise),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _breathController.dispose();
    super.dispose();
  }
}

// [RESTE DU CODE IDENTIQUE - _FloatingCircle, _ControlButton, _ExerciseCard, _ExerciseTimerDialog]

// Widget pour les cercles flottants
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

// Widget pour les boutons de contrôle
class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool isPrimary;

  const _ControlButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    required this.isPrimary,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = AppTheme.lightTheme.primaryColor;

    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: isPrimary ? primaryColor : Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
            border: Border.all(
              color: isPrimary
                  ? Colors.transparent
                  : primaryColor.withOpacity(0.3),
              width: 2,
            ),
          ),
          child: IconButton(
            icon: Icon(icon, size: 24),
            onPressed: onPressed,
            color: isPrimary ? Colors.white : primaryColor,
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

// Widget pour les cartes d'exercice
class _ExerciseCard extends StatelessWidget {
  final String title;
  final String description;
  final String duration;
  final VoidCallback onTap;

  const _ExerciseCard({
    required this.title,
    required this.description,
    required this.duration,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = AppTheme.lightTheme.primaryColor;

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
            color: primaryColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.fitness_center_rounded, color: primaryColor),
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
                color: primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                duration,
                style: TextStyle(
                  color: primaryColor,
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

// Dialog pour le minuteur d'exercice
class _ExerciseTimerDialog extends StatefulWidget {
  final String exercise;

  const _ExerciseTimerDialog({required this.exercise});

  @override
  State<_ExerciseTimerDialog> createState() => _ExerciseTimerDialogState();
}

class _ExerciseTimerDialogState extends State<_ExerciseTimerDialog> {
  late int _secondsRemaining;
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    // Déterminer la durée en fonction de l'exercice
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
        title: const Text('Exercice Terminé! 🎉'),
        content: const Text('Félicitations! Vous avez complété l\'exercice.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Ferme la completion dialog
              Navigator.pop(context); // Ferme le timer dialog
            },
            child: const Text('Super!'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = AppTheme.lightTheme.primaryColor;

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
                    valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
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
                    onPressed: () {
                      _timer.cancel();
                      Navigator.pop(context);
                    },
                    child: const Text('Terminé'),
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
