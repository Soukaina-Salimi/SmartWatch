// FILE: lib/pages/auth/welcome_page.dart
import 'package:flutter/material.dart';
import '../../core/widgets/custom_card.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/constants/app_strings.dart';

class WelcomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 24),
              Text(
                AppStrings.welcomeTitle,
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                AppStrings.welcomeSubtitle,
                style: TextStyle(color: Colors.black54),
              ),
              SizedBox(height: 28),
              CustomCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(
                      Icons.watch,
                      size: 48,
                      color: Theme.of(context).primaryColor,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Smartwatch Santé',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Suivi cardio, température, UV et plus',
                      style: TextStyle(color: Colors.black54),
                    ),
                    SizedBox(height: 16),
                    PrimaryButton(
                      label: "S'inscrire",
                      onPressed: () => Navigator.pushNamed(context, '/sign_up'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pushNamed(context, '/login'),
                      child: Text('Se connecter'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
