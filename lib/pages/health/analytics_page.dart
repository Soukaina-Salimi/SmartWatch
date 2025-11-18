import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/widgets/custom_card.dart';
import '../../core/widgets/chart_widget.dart';
import '../../data/providers/health_provider.dart';
import '../../routing/app_router.dart';

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});

  @override
  _AnalyticsPageState createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  int _currentIndex = 0; // ou mettre l'index correspondant à Analytics

  @override
  Widget build(BuildContext context) {
    final health = Provider.of<HealthProvider>(context);

    return Scaffold(
      appBar: AppBar(title: Text('Analytics')),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: ListView(
          children: [
            CustomCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Tendances', style: TextStyle(fontSize: 18)),
                  SizedBox(height: 12),
                  ChartWidget(spots: health.chartSpots, height: 140),
                  SizedBox(height: 12),
                  Text(
                    'IA: Risque de stress élevé. Recommandation: Pause de 5 minutes.',
                  ),
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
