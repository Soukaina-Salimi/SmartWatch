// FILE: lib/pages/auth/sign_up_page.dart
import 'package:flutter/material.dart';
import 'package:smartwatch_v2/core/theme/app_theme.dart';
import 'package:smartwatch_v2/main.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;
  late Animation<Color?> _colorAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1500),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Interval(0.2, 0.8, curve: Curves.easeOut),
      ),
    );

    _slideAnimation = Tween<double>(begin: 50.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Interval(0.3, 1.0, curve: Curves.easeOutBack),
      ),
    );

    _colorAnimation = ColorTween(
      begin: AppTheme.lightTheme.primaryColor.withOpacity(0.3),
      end: AppTheme.lightTheme.primaryColor.withOpacity(0.1),
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _controller.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _controller.dispose();
    super.dispose();
  }

  // Fonction d'inscription avec Supabase
  void _signUp() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. Appel à la fonction d'inscription Supabase
      await supabase.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        // Supabase enverra un e-mail de confirmation par défaut
      );

      // 2. Afficher un message de succès et naviguer vers la page de connexion
      if (mounted) {
        _showSnackBar(
          "Succès ! Un lien de confirmation a été envoyé à votre e-mail.",
          isError: false,
        );
        // Après l'inscription (et l'envoi de l'e-mail), on revient à la page de connexion
        Navigator.pop(context);
      }
    } on AuthException catch (error) {
      _showSnackBar(error.message, isError: true);
    } catch (e) {
      _showSnackBar('Erreur inattendue : $e', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? Colors.redAccent
            : AppTheme.lightTheme.primaryColor,
      ),
    );
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
              // Arrière-plan animé (même que welcome)
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

              // Contenu principal avec animations
              Transform.translate(
                offset: Offset(0, _slideAnimation.value),
                child: Opacity(
                  opacity: _fadeAnimation.value,
                  child: SafeArea(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Bouton retour avec style amélioré
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: Icon(
                                Icons.arrow_back_ios_new_rounded,
                                size: 18,
                              ),
                              color: Colors.grey[600],
                              padding: EdgeInsets.all(12),
                            ),
                          ),

                          SizedBox(height: 40),

                          // En-tête avec icône
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Container(
                                width: 70,
                                height: 70,
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
                              SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Créez votre\ncompte !',
                                      style: TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.grey[900],
                                        height: 1.2,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'Commencez votre suivi de santé',
                                      style: TextStyle(
                                        fontSize: 15,
                                        color: Colors.grey[600],
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          SizedBox(height: 48),

                          // Carte du formulaire avec ombre subtile
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 20,
                                  offset: Offset(0, 10),
                                ),
                              ],
                              border: Border.all(
                                color: Colors.grey[100]!,
                                width: 1,
                              ),
                            ),
                            padding: const EdgeInsets.all(24),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                children: [
                                  // Email avec style amélioré
                                  Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      color: Colors.grey[50],
                                      border: Border.all(
                                        color: Colors.grey[100]!,
                                        width: 1,
                                      ),
                                    ),
                                    child: TextFormField(
                                      controller: _emailController,
                                      decoration: InputDecoration(
                                        labelText: 'Email',
                                        labelStyle: TextStyle(
                                          color: Colors.grey[600],
                                          fontWeight: FontWeight.w500,
                                        ),
                                        prefixIcon: Container(
                                          margin: EdgeInsets.only(right: 12),
                                          child: Icon(
                                            Icons.email_rounded,
                                            color: Colors.grey[500],
                                          ),
                                        ),
                                        border: InputBorder.none,
                                        focusedBorder: InputBorder.none,
                                        enabledBorder: InputBorder.none,
                                        contentPadding: EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 18,
                                        ),
                                      ),
                                      style: TextStyle(
                                        color: Colors.grey[800],
                                        fontWeight: FontWeight.w500,
                                      ),
                                      keyboardType: TextInputType.emailAddress,
                                      validator: (value) {
                                        if (value == null ||
                                            value.isEmpty ||
                                            !value.contains('@')) {
                                          return 'Veuillez entrer un email valide';
                                        }
                                        return null;
                                      },
                                    ),
                                  ),

                                  SizedBox(height: 20),

                                  // Mot de passe avec style amélioré
                                  Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      color: Colors.grey[50],
                                      border: Border.all(
                                        color: Colors.grey[100]!,
                                        width: 1,
                                      ),
                                    ),
                                    child: TextFormField(
                                      controller: _passwordController,
                                      obscureText: _obscurePassword,
                                      decoration: InputDecoration(
                                        labelText:
                                            'Mot de passe (minimum 6 caractères)',
                                        labelStyle: TextStyle(
                                          color: Colors.grey[600],
                                          fontWeight: FontWeight.w500,
                                        ),
                                        prefixIcon: Container(
                                          margin: EdgeInsets.only(right: 12),
                                          child: Icon(
                                            Icons.lock_rounded,
                                            color: Colors.grey[500],
                                          ),
                                        ),
                                        suffixIcon: IconButton(
                                          icon: Icon(
                                            _obscurePassword
                                                ? Icons.visibility_off_rounded
                                                : Icons.visibility_rounded,
                                            color: Colors.grey[500],
                                            size: 20,
                                          ),
                                          onPressed: () {
                                            setState(
                                              () => _obscurePassword =
                                                  !_obscurePassword,
                                            );
                                          },
                                        ),
                                        border: InputBorder.none,
                                        focusedBorder: InputBorder.none,
                                        enabledBorder: InputBorder.none,
                                        contentPadding: EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 18,
                                        ),
                                      ),
                                      style: TextStyle(
                                        color: Colors.grey[800],
                                        fontWeight: FontWeight.w500,
                                      ),
                                      validator: (value) {
                                        if (value == null ||
                                            value.isEmpty ||
                                            value.length < 6) {
                                          return 'Le mot de passe doit contenir au moins 6 caractères';
                                        }
                                        return null;
                                      },
                                    ),
                                  ),

                                  SizedBox(height: 24),

                                  // Information sur la confirmation email
                                  Container(
                                    padding: EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: primaryColor.withOpacity(0.05),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: primaryColor.withOpacity(0.1),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.info_outline_rounded,
                                          color: primaryColor,
                                          size: 20,
                                        ),
                                        SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            'Un lien de confirmation vous sera envoyé par email',
                                            style: TextStyle(
                                              color: Colors.grey[700],
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  SizedBox(height: 24),

                                  // Bouton d'inscription avec gradient subtil
                                  Container(
                                    width: double.infinity,
                                    height: 56,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(14),
                                      gradient: LinearGradient(
                                        colors: [
                                          primaryColor,
                                          Color.alphaBlend(
                                            Colors.black.withOpacity(0.1),
                                            primaryColor,
                                          ),
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: primaryColor.withOpacity(0.3),
                                          blurRadius: 15,
                                          offset: Offset(0, 8),
                                        ),
                                      ],
                                    ),
                                    child: ElevatedButton(
                                      onPressed: _isLoading ? null : _signUp,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.transparent,
                                        shadowColor: Colors.transparent,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                        ),
                                      ),
                                      child: _isLoading
                                          ? SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                valueColor:
                                                    AlwaysStoppedAnimation<
                                                      Color
                                                    >(Colors.white),
                                              ),
                                            )
                                          : Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Text(
                                                  "S'inscrire",
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                                SizedBox(width: 8),
                                                Icon(
                                                  Icons.arrow_forward_rounded,
                                                  size: 20,
                                                  color: Colors.white,
                                                ),
                                              ],
                                            ),
                                    ),
                                  ),

                                  SizedBox(height: 24),

                                  // Lien vers la page de connexion
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        'Déjà un compte ?',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      SizedBox(width: 6),
                                      Container(
                                        decoration: BoxDecoration(
                                          border: Border(
                                            bottom: BorderSide(
                                              color: primaryColor.withOpacity(
                                                0.3,
                                              ),
                                              width: 1,
                                            ),
                                          ),
                                        ),
                                        child: TextButton(
                                          onPressed: () {
                                            Navigator.pop(context);
                                          },
                                          style: TextButton.styleFrom(
                                            padding: EdgeInsets.only(bottom: 2),
                                            tapTargetSize: MaterialTapTargetSize
                                                .shrinkWrap,
                                          ),
                                          child: Text(
                                            'Se connecter',
                                            style: TextStyle(
                                              color: primaryColor,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),

                          SizedBox(height: 40),
                        ],
                      ),
                    ),
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
    final primaryColor = AppTheme.lightTheme.primaryColor;

    return Stack(
      children: List.generate(6, (index) {
        final delay = index * 0.1;
        final particleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(
            parent: animation,
            curve: Interval(delay, 1.0, curve: Curves.easeInOut),
          ),
        );

        return AnimatedBuilder(
          animation: particleAnimation,
          builder: (context, child) {
            return Positioned(
              left: (index * 60.0) % MediaQuery.of(context).size.width,
              top: (index * 80.0) % MediaQuery.of(context).size.height,
              child: Opacity(
                opacity: particleAnimation.value * 0.2,
                child: Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    color: primaryColor,
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
