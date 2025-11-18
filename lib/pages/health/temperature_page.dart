import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/widgets/custom_card.dart';
import '../../core/widgets/chart_widget.dart';
import '../../data/providers/health_provider.dart';
import '../../routing/app_router.dart';

class TemperaturePage extends StatefulWidget {
  const TemperaturePage({super.key});

  @override
  _TemperaturePageState createState() => _TemperaturePageState();
}

class _TemperaturePageState extends State<TemperaturePage> {
  int _currentIndex = 0; // ou mettre l'index correspondant à Température

  @override
  Widget build(BuildContext context) {
    final health = Provider.of<HealthProvider>(context);
    final tempSpots = health.chartSpots
        .map((s) => FlSpot(s.x, s.y / 2))
        .toList();

    return Scaffold(
      appBar: AppBar(title: Text('Température')),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: ListView(
          children: [
            CustomCard(
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Température', style: TextStyle(fontSize: 18)),
                      Text(
                        '${health.data.temperature.toStringAsFixed(1)} °C',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  ChartWidget(spots: tempSpots, height: 140),
                ],
              ),
            ),
            SizedBox(height: 16),
            CustomCard(
              child: Text(
                'Conseil: Si la température dépasse 37.5°C, consultez un médecin.',
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
}
