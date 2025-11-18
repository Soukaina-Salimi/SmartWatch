// FILE: lib/core/widgets/chart_widget.dart
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/constants/colors.dart';

class ChartWidget extends StatelessWidget {
  final List<FlSpot> spots;
  final double height;
  final bool curved;

  const ChartWidget({
    super.key,
    required this.spots,
    this.height = 120,
    this.curved = true,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: curved,
              color: AppColors.primary,
              barWidth: 3,
              dotData: FlDotData(show: false),
            ),
          ],
        ),
      ),
    );
  }
}
