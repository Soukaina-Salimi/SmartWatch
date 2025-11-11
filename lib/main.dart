// FILE: lib/main.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'data/providers/user_provider.dart';
import 'data/providers/health_provider.dart';
import 'routing/app_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';

// Global accessor pour Supabase
final supabase = Supabase.instance.client;

Future<void> main() async {
  // 1. Charger le fichier .env
  await dotenv.load(fileName: ".env");
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Initialiser Supabase
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => HealthProvider()),
      ],
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  final AppRouter _router = AppRouter();
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smartwatch Santé',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      initialRoute: AppRouter.welcome,
      onGenerateRoute: _router.onGenerateRoute,
    );
  }
}

// Widget qui écoute l'état d'authentification de Supabase
class AuthChecker extends StatefulWidget {
  const AuthChecker({super.key});

  @override
  State<AuthChecker> createState() => _AuthCheckerState();
}

class _AuthCheckerState extends State<AuthChecker> {
  late final StreamSubscription<AuthState> _authStateSubscription;

  @override
  void initState() {
    super.initState();

    // Initialisation et écoute des changements d'état d'authentification
    _authStateSubscription = supabase.auth.onAuthStateChange.listen((data) {
      if (mounted) {
        // Redirige lors d'un changement d'état (login, logout, initial)
        _redirect(data.session);
      }
    });

    // Vérification initiale pour assurer une navigation immédiate au lancement
    final session = supabase.auth.currentSession;
    _redirect(session);
  }

  // Fonction de redirection
  void _redirect(Session? session) {
    if (!mounted) return;

    // Utilise un microtask pour s'assurer que la navigation se fait en toute sécurité
    Future.microtask(() {
      if (session != null) {
        // Si connecté, aller au tableau de bord
        Navigator.of(context).pushReplacementNamed('/dashboard');
      } else {
        // Si déconnecté, aller à la page de bienvenue
        Navigator.of(context).pushReplacementNamed('/welcome');
      }
    });
  }

  @override
  void dispose() {
    _authStateSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Écran de chargement initial
    return const Scaffold(
      body: Center(child: CircularProgressIndicator(color: Colors.white)),
    );
  }
}
