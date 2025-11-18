import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/widgets/custom_card.dart';
import '../../core/widgets/chart_widget.dart';
import '../../data/providers/health_provider.dart';
import '../../routing/app_router.dart';

class UVMonitoringPage extends StatefulWidget {
  const UVMonitoringPage({super.key});

  @override
  _UVMonitoringPageState createState() => _UVMonitoringPageState();
}

class _UVMonitoringPageState extends State<UVMonitoringPage> {
  int _currentIndex = 0; // ou mettre l'index correspondant à UV

  @override
  Widget build(BuildContext context) {
    final health = Provider.of<HealthProvider>(context);
    final uvSpots = health.chartSpots
        .map((s) => FlSpot(s.x, (s.y % 10) / 2))
        .toList();

    return Scaffold(
      appBar: AppBar(title: Text('UV Monitoring')),
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
                      Text('UV', style: TextStyle(fontSize: 18)),
                      Text(
                        health.data.uvIndex.toStringAsFixed(1),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 22,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  ChartWidget(spots: uvSpots, height: 120),
                  SizedBox(height: 12),
                  Text('Indice UV élevé: protégez-vous du soleil.'),
                ],
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
