// FILE: lib/main.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:smartwatch_v2/services/data_sync_service.dart';
import 'package:smartwatch_v2/services/notification_service.dart';
import 'core/theme/app_theme.dart';
import 'data/providers/user_provider.dart';
import 'data/providers/health_provider.dart';
import 'routing/app_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'pages/dashboard/dashboard_page.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'presentation/bluetooth/bluetooth_page.dart';
import 'presentation/bluetooth/device_page.dart';

final supabase = Supabase.instance.client;
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  await dotenv.load(fileName: "assets/.env");
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );
  await initNotifications();
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
  final DataSyncService dataSyncService = DataSyncService(
    supabase: Supabase.instance.client,
  );

  MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smartwatch Santé',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: AuthGate(dataSyncService: dataSyncService),
      onGenerateRoute: _router.onGenerateRoute,
      navigatorKey: navigatorKey,
    );
  }
}

class AuthGate extends StatefulWidget {
  final DataSyncService dataSyncService;

  const AuthGate({super.key, required this.dataSyncService});

  @override
  _AuthGateState createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final session = Supabase.instance.client.auth.currentSession;

      if (session != null) {
        // Déjà connecté → dashboard
        Navigator.pushReplacementNamed(context, AppRouter.dashboard);
      } else {
        // Pas de session → welcome
        Navigator.pushReplacementNamed(context, AppRouter.welcome);
      }

      // Démarrer sync
      widget.dataSyncService.startSendingTestData();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Écran vide très court (moins de 20 ms)
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

class AuthChecker extends StatefulWidget {
  final DataSyncService dataSyncService;
  final Widget child;

  const AuthChecker({
    super.key,
    required this.dataSyncService,
    required this.child,
  });

  @override
  State<AuthChecker> createState() => _AuthCheckerState();
}

class _AuthCheckerState extends State<AuthChecker> {
  late final StreamSubscription<AuthState> _authStateSubscription;

  @override
  void initState() {
    super.initState();

    _authStateSubscription = supabase.auth.onAuthStateChange.listen((data) {
      if (mounted) _redirect(data.session);
    });

    _redirect(supabase.auth.currentSession);

    // Démarre l'envoi des données test
    widget.dataSyncService.startSendingTestData();
  }

  void _redirect(Session? session) {
    if (!mounted) return;
    Future.microtask(() async {
      if (session != null) {
        Navigator.of(context).pushReplacementNamed(AppRouter.dashboard);
      } else {
        Navigator.of(context).pushReplacementNamed(AppRouter.welcome);
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
    return widget.child;
  }
}
