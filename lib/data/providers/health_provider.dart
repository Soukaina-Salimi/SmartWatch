// FILE: lib/data/providers/health_provider.dart
import 'package:flutter/foundation.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/health_data_model.dart';
import '../../utils/mock_data.dart';

class HealthProvider extends ChangeNotifier {
  HealthDataModel _data = HealthDataModel(
    heartBpm: 78,
    temperature: 36.6,
    uvIndex: 4.2,
    steps: 3452,
  );

  HealthDataModel get data => _data;

  List<FlSpot> get chartSpots => ChartDataHelper.spotsFromMock();

  void randomUpdate() {
    _data = HealthDataModel(
      heartBpm: 60 + DateTime.now().second % 50,
      temperature: 36.0 + (DateTime.now().second % 10) / 10,
      uvIndex: (DateTime.now().second % 11) / 2,
      steps: 3000 + DateTime.now().second * 10,
    );
    notifyListeners();
  }
}
