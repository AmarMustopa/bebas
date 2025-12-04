import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/sensor_reading.dart';
import '../providers/sensor_provider.dart';
import '../services/auth_service.dart';
import '../widgets/mqtt_log_widget.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _loggingOut = false;
  @override
  void initState() {
    super.initState();
    final prov = Provider.of<SensorProvider>(context, listen: false);
    prov.start();
  }

  @override
  void dispose() {
    final prov = Provider.of<SensorProvider>(context, listen: false);
    prov.stop();
    super.dispose();
  }

  Color statusColor(MeatStatus s) {
    switch (s) {
      case MeatStatus.LAYAK:
        return Colors.green.shade400;
      case MeatStatus.PERLU_DIPERHATIKAN:
        return Colors.orange.shade600;
      case MeatStatus.TIDAK_LAYAK:
        return Colors.red.shade400;
    }
  }

  Future<void> _handleLogout(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Konfirmasi Logout'),
        content: const Text('Apakah Anda yakin ingin logout?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Batal')),
          ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Logout')),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() {
      _loggingOut = true;
    });
    final auth = Provider.of<AuthService>(context, listen: false);
    try {
      await auth.signOut();
      try {
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (r) => false);
      } catch (_) {
        Navigator.of(context).popUntil((r) => r.isFirst);
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Logout gagal: $e')));
    } finally {
      if (mounted)
        setState(() {
          _loggingOut = false;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.redAccent,
        title: const Text('Dashboard Kualitas Daging',
            style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: _loggingOut
                ? Padding(
                    padding: const EdgeInsets.all(12),
                    child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2)))
                : TextButton.icon(
                    onPressed: () => _handleLogout(context),
                    icon: const Icon(Icons.logout, color: Colors.white),
                    label: const Text('Logout',
                        style: TextStyle(color: Colors.white)),
                  ),
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Consumer<SensorProvider>(builder: (context, prov, _) {
          final latest = prov.readings.isNotEmpty ? prov.readings.first : null;
          
          // Convert readings to log format for LiveLogWidget
          final logList = prov.readings
              .map((reading) {
                final status = prov.mapPredictionToLabel(reading);
                // Convert to uppercase with spaces for display (Layak -> LAYAK)
                final statusDisplay = status
                    .toUpperCase()
                    .replaceAll(' ', '_');
                return {
                  'suhu': reading.temperature,
                  'kelembapan': reading.humidity,
                  'mq2': reading.mq2.toInt(),
                  'mq3': reading.mq3.toInt(),
                  'mq135': reading.mq135.toInt(),
                  'status': statusDisplay,
                };
              })
              .toList();
          
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Green status banner
              if (latest != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade200)),
                  child: Row(children: [
                    const Icon(Icons.info, color: Colors.green),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(
                            'Status Daging: ${Provider.of<SensorProvider>(context, listen: false).mapPredictionToLabel(latest)}',
                            style: TextStyle(
                                color: Colors.green.shade800,
                                fontWeight: FontWeight.bold))),
                  ]),
                )
              else
                const SizedBox(height: 12),

              // Small metric cards
              Row(children: [
                _smallMetric('MQ2', latest?.mq2 ?? 0.0, suffix: 'ppm'),
                const SizedBox(width: 8),
                _smallMetric('MQ3', latest?.mq3 ?? 0.0, suffix: 'ppm'),
                const SizedBox(width: 8),
                _smallMetric('MQ135', latest?.mq135 ?? 0.0, suffix: 'ppm'),
                const SizedBox(width: 8),
                _smallMetric('Suhu', latest?.temperature ?? 0.0, suffix: '°C'),
                const SizedBox(width: 8),
                _smallMetric('Kelembapan', latest?.humidity ?? 0.0,
                    suffix: '%'),
              ]),
              const SizedBox(height: 12),
              
              // MQTT Log Widget (new)
              Expanded(
                child: MqttLogWidget(logs: logList),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _smallMetric(String title, double value, {String suffix = ''}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
          const SizedBox(height: 6),
          Text('${value.toStringAsFixed(1)} $suffix',
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.red)),
        ]),
      ),
    );
  }

  Widget _chartCard(String title, Widget chart) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Expanded(child: chart),
        ]),
      ),
    );
  }

  Widget _buildTempChart(List<SensorReading> readings) {
    final samples = readings.take(20).toList().reversed.toList();
    if (samples.isEmpty) return const Center(child: Text('No data'));
    final spots = <FlSpot>[];
    for (var i = 0; i < samples.length; i++)
      spots.add(FlSpot(i.toDouble(), samples[i].temperature));
    final minY =
        samples.map((e) => e.temperature).reduce((a, b) => a < b ? a : b) - 2;
    final maxY =
        samples.map((e) => e.temperature).reduce((a, b) => a > b ? a : b) + 2;
    return LineChart(LineChartData(
        minY: minY,
        maxY: maxY,
        gridData: FlGridData(show: true),
        titlesData: FlTitlesData(show: true),
        lineBarsData: [
          LineChartBarData(
              spots: spots,
              isCurved: true,
              color: Colors.blueAccent,
              barWidth: 2,
              dotData: FlDotData(show: false))
        ]));
  }

  Widget _buildHumidityChart(List<SensorReading> readings) {
    final samples = readings.take(12).toList().reversed.toList();
    if (samples.isEmpty) return const Center(child: Text('No data'));
    final groups = samples
        .asMap()
        .entries
        .map((e) => BarChartGroupData(x: e.key, barRods: [
              BarChartRodData(
                  toY: e.value.humidity, width: 10, color: Colors.greenAccent)
            ]))
        .toList();
    return BarChart(
        BarChartData(barGroups: groups, titlesData: FlTitlesData(show: true)));
  }

  Widget _gasCard(SensorReading? latest) {
    final value = latest?.mq135 ?? 0.0;
    final pct = (value / 10.0).clamp(0.0, 1.0);
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(children: [
          const Align(
              alignment: Alignment.centerLeft,
              child: Text('Gas Terakhir',
                  style: TextStyle(fontWeight: FontWeight.bold))),
          const SizedBox(height: 8),
          SizedBox(
            height: 160,
            child: Center(
              child: Stack(alignment: Alignment.center, children: [
                SizedBox(
                    width: 120,
                    height: 120,
                    child: CircularProgressIndicator(
                        value: pct,
                        strokeWidth: 14,
                        color: pct > 0.7
                            ? Colors.red
                            : (pct > 0.4 ? Colors.orange : Colors.green))),
                Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('${(pct * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(
                          fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text(value.toStringAsFixed(2))
                ])
              ]),
            ),
          )
        ]),
      ),
    );
  }

  Widget _tableSection(SensorProvider prov) {
    return Expanded(
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Riwayat Data & Status Daging Layak Konsumsi',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              ElevatedButton.icon(
                  onPressed: () async {
                    final csv = prov.exportCsv();
                    final path = _writeCsvToDownloads(csv);
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('CSV diekspor: $path')));
                  },
                  icon: const Icon(Icons.download),
                  label: const Text('Ekspor CSV'))
            ]),
            const SizedBox(height: 8),
            // simple filters row
            Row(children: [
              const Text('Tanggal:'),
              const SizedBox(width: 8),
              TextButton.icon(
                  onPressed: () async {
                    await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now());
                  },
                  icon: const Icon(Icons.date_range),
                  label: const Text('Pilih')),
              const SizedBox(width: 12),
              const Text('Status:'),
              const SizedBox(width: 8),
              DropdownButton<String>(items: const [
                DropdownMenuItem(value: 'all', child: Text('Semua')),
                DropdownMenuItem(value: 'LAYAK', child: Text('LAYAK'))
              ], onChanged: (_) {}, value: 'all')
            ]),
            const SizedBox(height: 12),
            Expanded(
              child: SingleChildScrollView(
                child: DataTable(
                    columns: const [
                      DataColumn(label: Text('Waktu')),
                      DataColumn(label: Text('Suhu (°C)')),
                      DataColumn(label: Text('Kelembapan (%)')),
                      DataColumn(label: Text('Gas')),
                      DataColumn(label: Text('Status')),
                    ],
                    rows: prov.readings.take(20).map((r) {
                      final color = statusColor(r.getStatus());
                      return DataRow(cells: [
                        DataCell(Text(r.formattedTime())),
                        DataCell(Text(r.temperature.toStringAsFixed(1))),
                        DataCell(Text(r.humidity.toStringAsFixed(1))),
                        DataCell(Text(r.mq135.toStringAsFixed(2))),
                        DataCell(Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 6),
                            decoration: BoxDecoration(
                                color: color,
                                borderRadius: BorderRadius.circular(20)),
                            child: Text(
                                Provider.of<SensorProvider>(context,
                                        listen: false)
                                    .mapPredictionToLabel(r),
                                style: const TextStyle(color: Colors.white)))),
                      ]);
                    }).toList()),
              ),
            )
          ]),
        ),
      ),
    );
  }

  String _writeCsvToDownloads(String csv) {
    try {
      final user = Platform.environment['USERPROFILE'] ?? '.';
      final downloads = '$user\\Downloads';
      final file = File(
          '$downloads\\monitoring_export_${DateTime.now().millisecondsSinceEpoch}.csv');
      file.writeAsStringSync(csv);
      return file.path;
    } catch (e) {
      final tmp = Directory.systemTemp.createTempSync();
      final file = File('${tmp.path}\\export.csv');
      file.writeAsStringSync(csv);
      return file.path;
    }
  }
}
