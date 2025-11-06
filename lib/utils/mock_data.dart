// FILE: lib/utils/mock_data.dart
import 'package:fl_chart/fl_chart.dart';

class ChartDataHelper {
  static List<FlSpot> spotsFromMock() {
    return [
      FlSpot(0, 50),
      FlSpot(1, 60),
      FlSpot(2, 55),
      FlSpot(3, 65),
      FlSpot(4, 60),
      FlSpot(5, 68),
    ];
  }
}
