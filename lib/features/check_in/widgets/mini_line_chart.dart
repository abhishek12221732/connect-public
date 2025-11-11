import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class MiniLineChart extends StatelessWidget {
  final List<double> values;
  final Color accent;
  final double min;
  final double max;
  const MiniLineChart({required this.values, required this.accent, required this.min, required this.max, super.key});
  @override
  Widget build(BuildContext context) {
    if (values.length < 2) return const SizedBox.shrink();
    return LineChart(
      LineChartData(
        minY: min,
        maxY: max,
        lineBarsData: [
          LineChartBarData(
            spots: [
              for (int i = 0; i < values.length; i++)
                FlSpot(i.toDouble(), values[i]),
            ],
            isCurved: true,
            barWidth: 2.5,
            color: accent,
            dotData: FlDotData(show: false),
          ),
        ],
        titlesData: FlTitlesData(show: false),
        gridData: FlGridData(show: false),
        borderData: FlBorderData(show: false),
        lineTouchData: LineTouchData(enabled: false), // Disable all touch/tooltip
      ),
    );
  }
} 
