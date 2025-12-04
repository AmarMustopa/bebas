import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../models/sensor_data.dart';

enum ChartType { line, bar }

class SensorChart extends StatelessWidget {
  final String title;
  final Stream<List<SensorData>> stream;
  final double Function(SensorData) valueGetter;
  final Color color;
  final ChartType chartType;

  const SensorChart({
    super.key,
    required this.title,
    required this.stream,
    required this.valueGetter,
    required this.color,
    this.chartType = ChartType.line,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<SensorData>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return SizedBox(
            height: 120,
            child:
                Center(child: Text('Error loading chart: ${snapshot.error}')),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const SizedBox(
            height: 120,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox(
            height: 120,
            child: Center(child: Text('No data')),
          );
        }

        final data = snapshot.data!;
        final values = data
            .map((d) => valueGetter(d).isNaN ? 0.0 : valueGetter(d))
            .toList();
        final times = data.map((d) => d.timestamp).toList();

        Widget chartWidget;

        if (chartType == ChartType.bar) {
          // Build vertical bar chart
          final groups = values.asMap().entries.map((e) {
            final x = e.key;
            final y = e.value;
            return BarChartGroupData(x: x, barRods: [
              BarChartRodData(
                toY: y,
                color: color,
                width: 10,
                borderRadius: BorderRadius.circular(4),
              )
            ]);
          }).toList();

          final int step = (values.length / 4).ceil().clamp(1, values.length);

          chartWidget = BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceBetween,
              barGroups: groups,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: true,
                drawHorizontalLine: true,
                horizontalInterval: 10,
                verticalInterval: 5,
                getDrawingHorizontalLine: (value) {
                  return FlLine(
                    color: Colors.grey.withValues(alpha: 0.3),
                    strokeWidth: 1,
                    dashArray: [5, 5],
                  );
                },
                getDrawingVerticalLine: (value) {
                  return FlLine(
                    color: Colors.grey.withValues(alpha: 0.3),
                    strokeWidth: 1,
                    dashArray: [5, 5],
                  );
                },
              ),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 36,
                    getTitlesWidget: (value, meta) {
                      final idx = value.toInt();
                      if (idx < 0 || idx >= times.length)
                        return const SizedBox.shrink();
                      if (idx % step != 0) return const SizedBox.shrink();
                      final dt = times[idx];
                      return Text(DateFormat('HH:mm').format(dt),
                          style: const TextStyle(fontSize: 10));
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    getTitlesWidget: (value, meta) {
                      return Text(value.toStringAsFixed(1),
                          style: const TextStyle(fontSize: 10));
                    },
                  ),
                ),
                topTitles:
                    AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles:
                    AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: false),
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  tooltipBgColor: Colors.black87,
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final dt = times[group.x.toInt()];
                    return BarTooltipItem(
                      '${DateFormat('yyyy-MM-dd HH:mm').format(dt)}\n',
                      const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                      children: [
                        TextSpan(
                            text: '${rod.toY.toStringAsFixed(2)}',
                            style: const TextStyle(
                                color: Colors.white70,
                                fontWeight: FontWeight.normal))
                      ],
                    );
                  },
                ),
              ),
            ),
          );
        } else {
          final spots = values
              .asMap()
              .entries
              .map((e) => FlSpot(e.key.toDouble(), e.value))
              .toList();

          final int step = (values.length / 4).ceil().clamp(1, values.length);

          chartWidget = LineChart(
            LineChartData(
              gridData: FlGridData(
                show: true,
                drawVerticalLine: true,
                drawHorizontalLine: true,
                horizontalInterval: 10,
                verticalInterval: 5,
                getDrawingHorizontalLine: (value) {
                  return FlLine(
                    color: Colors.grey.withValues(alpha: 0.3),
                    strokeWidth: 1,
                    dashArray: [5, 5],
                  );
                },
                getDrawingVerticalLine: (value) {
                  return FlLine(
                    color: Colors.grey.withValues(alpha: 0.3),
                    strokeWidth: 1,
                    dashArray: [5, 5],
                  );
                },
              ),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 36,
                    getTitlesWidget: (value, meta) {
                      final idx = value.toInt();
                      if (idx < 0 || idx >= times.length)
                        return const SizedBox.shrink();
                      if (idx % step != 0) return const SizedBox.shrink();
                      final dt = times[idx];
                      return Text(DateFormat('HH:mm').format(dt),
                          style: const TextStyle(fontSize: 10));
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    getTitlesWidget: (value, meta) {
                      return Text(value.toStringAsFixed(1),
                          style: const TextStyle(fontSize: 10));
                    },
                  ),
                ),
                topTitles:
                    AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles:
                    AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: false),
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  tooltipBgColor: Colors.black87,
                  getTooltipItems: (touchedSpots) {
                    return touchedSpots.map((t) {
                      final idx = t.x.toInt();
                      final dt = times[idx];
                      return LineTooltipItem(
                        '${DateFormat('yyyy-MM-dd HH:mm').format(dt)}\n${t.y.toStringAsFixed(2)}',
                        const TextStyle(color: Colors.white),
                      );
                    }).toList();
                  },
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  color: color,
                  barWidth: 3,
                  dotData: const FlDotData(show: false),
                ),
              ],
            ),
          );
        }

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 3,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                SizedBox(height: 150, child: chartWidget),
              ],
            ),
          ),
        );
      },
    );
  }
}
