import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/widgets/custom_card.dart';
import '../../core/widgets/chart_widget.dart';
import '../../data/providers/health_provider.dart';
import '../../routing/app_router.dart';

class HeartRatePage extends StatefulWidget {
  const HeartRatePage({super.key});

  @override
  _HeartRatePageState createState() => _HeartRatePageState();
}

class _HeartRatePageState extends State<HeartRatePage> {
  int _currentIndex = 0; // ou l'index correspondant à Rythme cardiaque

  @override
  Widget build(BuildContext context) {
    final health = Provider.of<HealthProvider>(context);

    return Scaffold(
      appBar: AppBar(title: Text('Rythme cardiaque')),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: ListView(
          children: [
            CustomCard(
              child: Column(
                children: [
                  Text('Rythme cardiaque', style: TextStyle(fontSize: 18)),
                  SizedBox(height: 8),
                  Text(
                    '${health.data.heartBpm} BPM',
                    style: TextStyle(fontSize: 34, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  ChartWidget(spots: health.chartSpots, height: 180),
                ],
              ),
            ),
            SizedBox(height: 16),
            CustomCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tendances récentes',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Fréquence cardiaque plus élevée hier entre 15h et 16h.',
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
