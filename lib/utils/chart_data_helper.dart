// FILE: lib/utils/chart_data_helper.dart
// small helper wrapper in case you want to transform or fetch data later
import 'package:fl_chart/fl_chart.dart';

class ChartDataHelper {
  static List<FlSpot> spotsFromMock() => ChartDataHelperInternal.spots();

  static List<FlSpot> spotsFrom(List<double> values) {
    return values
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value))
        .toList();
  }
}

class ChartDataHelperInternal {
  static List<FlSpot> spots() {
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
