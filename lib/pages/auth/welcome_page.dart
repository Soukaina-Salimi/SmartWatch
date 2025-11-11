// FILE: lib/pages/auth/welcome_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../../core/constants/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../routing/app_router.dart';

class WelcomePage extends StatefulWidget {
  @override
  _WelcomePageState createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<Color?> _colorAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 2000),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _slideAnimation = Tween<double>(begin: 100.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Interval(0.2, 0.8, curve: Curves.easeOutBack),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Interval(0.4, 1.0, curve: Curves.elasticOut),
      ),
    );

    _colorAnimation = ColorTween(
      begin: AppTheme.lightTheme.primaryColor.withOpacity(0.3),
      end: AppTheme.lightTheme.primaryColor.withOpacity(0.1),
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    // Démarrer l'animation après un court délai
    Future.delayed(Duration(milliseconds: 300), () {
      _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = AppTheme.lightTheme.primaryColor;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Stack(
            children: [
              // Arrière-plan animé
              Container(
                width: double.infinity,
                height: double.infinity,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.topRight,
                    radius: 1.5,
                    colors: [_colorAnimation.value!, Colors.white],
                  ),
                ),
              ),

              // Particules flottantes
              _ParticlesBackground(animation: _controller),

              // Éléments décoratifs
              Positioned(
                top: size.height * 0.1,
                right: -size.width * 0.1,
                child: _FloatingCircle(
                  size: size.width * 0.3,
                  color: primaryColor.withOpacity(0.1),
                  animation: _controller,
                  delay: 0.1,
                ),
              ),

              Positioned(
                bottom: size.height * 0.2,
                left: -size.width * 0.15,
                child: _FloatingCircle(
                  size: size.width * 0.4,
                  color: primaryColor.withOpacity(0.08),
                  animation: _controller,
                  delay: 0.3,
                ),
              ),

              SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      SizedBox(height: 50),

                      // Titre principal
                      Transform.translate(
                        offset: Offset(0, _slideAnimation.value),
                        child: Opacity(
                          opacity: _fadeAnimation.value,
                          child: Column(
                            children: [
                              Text(
                                AppStrings.welcomeTitle,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 48,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.grey[900],
                                  height: 1.0,
                                  letterSpacing: -1.0,
                                  shadows: [
                                    Shadow(
                                      blurRadius: 10,
                                      color: Colors.black.withOpacity(0.1),
                                      offset: Offset(2, 2),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(height: 16),
                              Text(
                                AppStrings.welcomeSubtitle,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 20,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w400,
                                  height: 1.4,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      SizedBox(height: 60),

                      // Carte principale
                      Transform.scale(
                        scale: _scaleAnimation.value,
                        child: Opacity(
                          opacity: _fadeAnimation.value,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(36),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(32),
                              color: Colors.white,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.15),
                                  blurRadius: 40,
                                  offset: Offset(0, 25),
                                ),
                                BoxShadow(
                                  color: Colors.white.withOpacity(0.9),
                                  blurRadius: 10,
                                  offset: Offset(0, -5),
                                ),
                              ],
                              border: Border.all(
                                color: Colors.white.withOpacity(0.8),
                                width: 1,
                              ),
                            ),
                            child: Column(
                              children: [
                                // Icône smartwatch
                                Container(
                                  width: 90,
                                  height: 90,
                                  decoration: BoxDecoration(
                                    color: Colors.blueAccent,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: const Color.fromARGB(
                                        255,
                                        61,
                                        123,
                                        224,
                                      ), // Une teinte plus claire de BlueAccent pour la bordure
                                      width: 2,
                                    ),
                                  ),
                                  child: Image.asset(
                                    'assets/images/logo_coeur_bleu.png', // <-- Assurez-vous que ce chemin est correct
                                    height:
                                        24, // Ajustez la taille à la hauteur du bouton
                                    width: 24,
                                    // Si le logo est monochrome, vous pouvez appliquer une couleur avec color:
                                    // color: primaryColor,
                                  ),
                                ),

                                SizedBox(height: 24),

                                // Titre
                                Text(
                                  'Smartwatch Santé',
                                  style: TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.grey[900],
                                    letterSpacing: -0.5,
                                  ),
                                ),

                                SizedBox(height: 8),

                                // Description
                                Text(
                                  'Votre compagnon santé intelligent\npour une vie plus saine',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w400,
                                    height: 1.5,
                                  ),
                                ),

                                SizedBox(height: 32),

                                // Indicateurs de fonctionnalités
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: [
                                    _FeatureIndicator(
                                      icon: Icons.favorite_rounded,
                                      label: 'Cardio',
                                      color: primaryColor,
                                    ),
                                    _FeatureIndicator(
                                      icon: Icons.thermostat_rounded,
                                      label: 'Temp',
                                      color: primaryColor,
                                    ),
                                    _FeatureIndicator(
                                      icon: Icons.wb_sunny_rounded,
                                      label: 'UV',
                                      color: primaryColor,
                                    ),
                                    _FeatureIndicator(
                                      icon: Icons.directions_walk_rounded,
                                      label: 'Activité',
                                      color: primaryColor,
                                    ),
                                  ],
                                ),

                                SizedBox(height: 40),

                                // Bouton principal
                                _AnimatedButton(
                                  onPressed: () => Navigator.pushNamed(
                                    context,
                                    AppRouter.signUp,
                                  ),
                                  label: "Commencer Maintenant",
                                  isPrimary: true,
                                  animation: _controller,
                                ),

                                SizedBox(height: 16),

                                // Bouton secondaire
                                _AnimatedButton(
                                  onPressed: () => Navigator.pushNamed(
                                    context,
                                    AppRouter.login,
                                  ),
                                  label: "J'ai déjà un compte",
                                  isPrimary: false,
                                  animation: _controller,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      SizedBox(height: 40),

                      // Footer animé
                      Opacity(
                        opacity: _fadeAnimation.value,
                        child: Transform.translate(
                          offset: Offset(0, _slideAnimation.value * 0.3),
                          child: Text(
                            'Rejoignez notre communauté santé',
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
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
}

// Widget pour les particules flottantes
class _ParticlesBackground extends StatelessWidget {
  final Animation<double> animation;

  const _ParticlesBackground({required this.animation});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: List.generate(8, (index) {
        final delay = index * 0.1;
        final animation = Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(
            parent: this.animation,
            curve: Interval(delay, 1.0, curve: Curves.easeInOut),
          ),
        );

        return AnimatedBuilder(
          animation: animation,
          builder: (context, child) {
            return Positioned(
              left: (index * 50.0) % MediaQuery.of(context).size.width,
              top: (index * 70.0) % MediaQuery.of(context).size.height,
              child: Opacity(
                opacity: animation.value * 0.3,
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: AppTheme.lightTheme.primaryColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          },
        );
      }),
    );
  }
}

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

// Widget pour les indicateurs de fonctionnalités
class _FeatureIndicator extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _FeatureIndicator({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
            border: Border.all(color: color.withOpacity(0.2), width: 1),
          ),
          child: Icon(icon, size: 24, color: color),
        ),
        SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[700],
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

// Widget pour les boutons animés
class _AnimatedButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String label;
  final bool isPrimary;
  final Animation<double> animation;

  const _AnimatedButton({
    required this.onPressed,
    required this.label,
    required this.isPrimary,
    required this.animation,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = AppTheme.lightTheme.primaryColor;
    final buttonAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: animation,
        curve: Interval(0.6, 1.0, curve: Curves.elasticOut),
      ),
    );

    return AnimatedBuilder(
      animation: buttonAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: buttonAnimation.value,
          child: Container(
            width: double.infinity,
            height: 60,
            decoration: isPrimary
                ? BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: LinearGradient(
                      colors: [
                        primaryColor,
                        Color.alphaBlend(
                          Colors.purple.withOpacity(0.3),
                          primaryColor,
                        ),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withOpacity(0.4),
                        blurRadius: 20,
                        offset: Offset(0, 10),
                      ),
                    ],
                  )
                : BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    color: Colors.transparent,
                    border: Border.all(
                      color: primaryColor.withOpacity(0.3),
                      width: 2,
                    ),
                  ),
            child: ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isPrimary ? Colors.white : primaryColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                  if (isPrimary) ...[
                    SizedBox(width: 8),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 20,
                      color: Colors.white,
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
