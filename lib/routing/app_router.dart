// FILE: lib/routing/app_router.dart
import 'package:flutter/material.dart';
import '../pages/auth/welcome_page.dart';
import '../pages/auth/login_page.dart';
import '../pages/auth/sign_up_page.dart';
import '../pages/dashboard/dashboard_page.dart';
import '../pages/health/heart_rate_page.dart';
import '../pages/health/temperature_page.dart';
import '../pages/health/uv_monitoring_page.dart';
import '../pages/health/activity_page.dart';
import '../pages/health/analytics_page.dart';
import '../pages/settings/configuration_page.dart';

class AppRouter {
  static const String welcome = '/welcome';
  static const String login = '/login';
  static const String signUp = '/sign_up';
  static const String dashboard = '/dashboard';
  static const String heart = '/heart';
  static const String temp = '/temperature';
  static const String uv = '/uv';
  static const String activity = '/activity';
  static const String analytics = '/analytics';
  static const String config = '/config';
  static const String mfasetup = '/mfa-setup';

  Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case welcome:
        return MaterialPageRoute(builder: (_) => WelcomePage());
      case login:
        return MaterialPageRoute(builder: (_) => LoginPage());
      case signUp:
        return MaterialPageRoute(builder: (_) => SignUpPage());
      case dashboard:
        return MaterialPageRoute(builder: (_) => DashboardPage());
      case heart:
        return MaterialPageRoute(builder: (_) => HeartRatePage());
      case temp:
        return MaterialPageRoute(builder: (_) => TemperaturePage());
      case uv:
        return MaterialPageRoute(builder: (_) => UVMonitoringPage());
      case activity:
        return MaterialPageRoute(builder: (_) => ActivityPage());
      case analytics:
        return MaterialPageRoute(builder: (_) => AnalyticsPage());
      case config:
        return MaterialPageRoute(builder: (_) => ConfigurationPage());

      default:
        return MaterialPageRoute(builder: (_) => WelcomePage());
    }
  }
}
