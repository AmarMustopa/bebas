import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../models/sensor_data.dart';

class SensorTrendOverview extends StatelessWidget {
  final Stream<List<SensorData>> stream;

  const SensorTrendOverview({super.key, required this.stream});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<SensorData>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const SizedBox(
              height: 200, child: Center(child: Text('Error loading trend')));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox(
              height: 200, child: Center(child: Text('No data')));
        }

        final data = snapshot.data!;
        final temps = data.map((d) => d.temperature).toList();
        final hums = data.map((d) => d.humidity).toList();
        final times = data.map((d) => d.timestamp).toList();

        final spotsTemp = temps
            .asMap()
            .entries
            .map((e) => FlSpot(e.key.toDouble(), e.value))
            .toList();
        final spotsHum = hums
            .asMap()
            .entries
            .map((e) => FlSpot(e.key.toDouble(), e.value))
            .toList();

        final int step = (data.length / 4).ceil().clamp(1, data.length);

        return Card(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 4,
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Temperature & Humidity',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                    Row(children: [
                      _legend(Colors.orangeAccent, 'Temperature'),
                      const SizedBox(width: 8),
                      _legend(
                          Colors.pinkAccent.withValues(alpha: 0.9), 'Humidity'),
                    ])
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 180,
                  child: LineChart(
                    LineChartData(
                      gridData: FlGridData(show: false),
                      titlesData: FlTitlesData(
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 36,
                            getTitlesWidget: (value, meta) {
                              final idx = value.toInt();
                              if (idx < 0 || idx >= times.length)
                                return const SizedBox.shrink();
                              if (idx % step != 0)
                                return const SizedBox.shrink();
                              return Text(
                                  DateFormat('HH:mm').format(times[idx]),
                                  style: const TextStyle(fontSize: 10));
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        topTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        rightTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                      ),
                      borderData: FlBorderData(show: false),
                      lineTouchData: LineTouchData(
                        touchTooltipData: LineTouchTooltipData(
                          tooltipBgColor: Colors.black87,
                          getTooltipItems: (touched) {
                            return touched.map((t) {
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
                          spots: spotsTemp,
                          isCurved: true,
                          color: Colors.orangeAccent,
                          barWidth: 3,
                          dotData: FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(colors: [
                              Colors.orangeAccent.withValues(alpha: 0.4),
                              Colors.orangeAccent.withValues(alpha: 0.05)
                            ]),
                          ),
                        ),
                        LineChartBarData(
                          spots: spotsHum,
                          isCurved: true,
                          color: Colors.pinkAccent.withValues(alpha: 0.9),
                          barWidth: 3,
                          dotData: FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(colors: [
                              Colors.pinkAccent.withValues(alpha: 0.35),
                              Colors.pinkAccent.withValues(alpha: 0.05)
                            ]),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _legend(Color color, String label) {
    return Row(
      children: [
        Container(
            width: 10,
            height: 6,
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(4))),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}
