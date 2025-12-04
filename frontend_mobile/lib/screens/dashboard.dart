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
      builder:
          (ctx) => AlertDialog(
            title: const Text('Konfirmasi Logout'),
            content: const Text('Apakah Anda yakin ingin logout?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Batal'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Logout'),
              ),
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Logout gagal: $e')));
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
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: const Color(0xFF4CAF50),
        elevation: 0,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Text('🥩 ', style: TextStyle(fontSize: 20)),
            Text(
              'Meat Freshness Monitor',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          _loggingOut
              ? const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                ),
              )
              : IconButton(
                onPressed: () => _handleLogout(context),
                icon: const Icon(Icons.logout, color: Colors.white),
                tooltip: 'Logout',
              ),
        ],
      ),
      body: Consumer<SensorProvider>(
        builder: (context, prov, _) {
          final latest = prov.readings.isNotEmpty ? prov.readings.first : null;
          final statusLabel =
              latest != null
                  ? prov.mapPredictionToLabel(latest)
                  : 'Menunggu Data...';
          final isLayak =
              statusLabel.toUpperCase().contains('LAYAK') &&
              !statusLabel.toUpperCase().contains('TIDAK');

          // Convert readings to log format for LiveLogWidget
          final logList =
              prov.readings.map((reading) {
                final status = prov.mapPredictionToLabel(reading);
                final statusDisplay = status.toUpperCase().replaceAll(' ', '_');
                return {
                  'suhu': reading.temperature,
                  'kelembapan': reading.humidity,
                  'mq2': reading.mq2.toInt(),
                  'mq3': reading.mq3.toInt(),
                  'mq135': reading.mq135.toInt(),
                  'status': statusDisplay,
                };
              }).toList();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Status Card
                _buildStatusCard(statusLabel, isLayak),
                const SizedBox(height: 16),

                // Sensor Lingkungan Section
                _buildSectionTitle('Sensor Lingkungan'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildSensorCard(
                        icon: Icons.thermostat,
                        iconColor: Colors.red,
                        title: 'Suhu',
                        value: latest?.temperature ?? 0.0,
                        unit: '°C',
                        bgColor: Colors.red.shade50,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildSensorCard(
                        icon: Icons.water_drop,
                        iconColor: Colors.blue,
                        title: 'Kelembapan',
                        value: latest?.humidity ?? 0.0,
                        unit: '%',
                        bgColor: Colors.blue.shade50,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Sensor Gas Section
                _buildSectionTitle('Sensor Gas (ppm)'),
                const SizedBox(height: 8),
                _buildGasSensorCard(
                  title: 'Gas Umum (MQ2)',
                  value: latest?.mq2 ?? 0.0,
                  color: Colors.orange,
                ),
                const SizedBox(height: 8),
                _buildGasSensorCard(
                  title: 'Alkohol/VOC (MQ3)',
                  value: latest?.mq3 ?? 0.0,
                  color: Colors.purple,
                ),
                const SizedBox(height: 8),
                _buildGasSensorCard(
                  title: 'Amonia/CO₂ (MQ135)',
                  value: latest?.mq135 ?? 0.0,
                  color: Colors.teal,
                ),
                const SizedBox(height: 16),

                // Refresh Button
                Center(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      prov.fetchFromApi();
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh Data'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4CAF50),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // MQTT Log Widget (collapsed by default on mobile)
                ExpansionTile(
                  title: const Text(
                    'Log Data Realtime',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  leading: const Icon(Icons.terminal, color: Colors.green),
                  children: [
                    SizedBox(height: 300, child: MqttLogWidget(logs: logList)),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusCard(String status, bool isLayak) {
    // Warna dan icon berdasarkan status
    final Color bgColor = isLayak ? Colors.green.shade50 : Colors.red.shade50;
    final Color borderColor = isLayak ? Colors.green : Colors.red;
    final Color iconBgColor = isLayak ? Colors.green : Colors.red;
    final Color textColor =
        isLayak ? Colors.green.shade700 : Colors.red.shade700;
    final IconData statusIcon = isLayak ? Icons.check_circle : Icons.cancel;
    final String displayStatus = isLayak ? 'LAYAK' : 'TIDAK LAYAK';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 2),
        boxShadow: [
          BoxShadow(
            color: borderColor.withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Icon besar di tengah
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: iconBgColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: iconBgColor.withOpacity(0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(statusIcon, color: Colors.white, size: 48),
          ),
          const SizedBox(height: 16),
          // Label Status
          Text(
            'Status Daging',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
          ),
          const SizedBox(height: 8),
          // Status Text
          Text(
            displayStatus,
            style: TextStyle(
              color: textColor,
              fontSize: 28,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          // Deskripsi
          Text(
            isLayak
                ? 'Daging dalam kondisi segar dan aman dikonsumsi'
                : 'Daging tidak layak konsumsi, segera buang!',
            textAlign: TextAlign.center,
            style: TextStyle(color: textColor.withOpacity(0.8), fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    );
  }

  Widget _buildSensorCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required double value,
    required String unit,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: iconColor, width: 4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 18),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${value.toStringAsFixed(1)}$unit',
            style: TextStyle(
              color: iconColor,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _getSensorStatus(title, value),
            style: TextStyle(
              color: Colors.green.shade600,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGasSensorCard({
    required String title,
    required double value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: color, width: 4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  '${value.toInt()} ppm',
                  style: TextStyle(
                    color: color,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Normal',
              style: TextStyle(
                color: Colors.green.shade700,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getSensorStatus(String sensor, double value) {
    if (sensor == 'Suhu') {
      if (value < 0 || value > 40) return 'Tidak Normal';
      return 'Normal';
    } else if (sensor == 'Kelembapan') {
      if (value < 30 || value > 90) return 'Tidak Normal';
      return 'Normal';
    }
    return 'Normal';
  }

  Widget _smallMetric(String title, double value, {String suffix = ''}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
            ),
            const SizedBox(height: 6),
            Text(
              '${value.toStringAsFixed(1)} $suffix',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.red,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chartCard(String title, Widget chart) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Expanded(child: chart),
          ],
        ),
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
    return LineChart(
      LineChartData(
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
            dotData: FlDotData(show: false),
          ),
        ],
      ),
    );
  }

  Widget _buildHumidityChart(List<SensorReading> readings) {
    final samples = readings.take(12).toList().reversed.toList();
    if (samples.isEmpty) return const Center(child: Text('No data'));
    final groups =
        samples
            .asMap()
            .entries
            .map(
              (e) => BarChartGroupData(
                x: e.key,
                barRods: [
                  BarChartRodData(
                    toY: e.value.humidity,
                    width: 10,
                    color: Colors.greenAccent,
                  ),
                ],
              ),
            )
            .toList();
    return BarChart(
      BarChartData(barGroups: groups, titlesData: FlTitlesData(show: true)),
    );
  }

  Widget _gasCard(SensorReading? latest) {
    final value = latest?.mq135 ?? 0.0;
    final pct = (value / 10.0).clamp(0.0, 1.0);
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Gas Terakhir',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 160,
              child: Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 120,
                      height: 120,
                      child: CircularProgressIndicator(
                        value: pct,
                        strokeWidth: 14,
                        color:
                            pct > 0.7
                                ? Colors.red
                                : (pct > 0.4 ? Colors.orange : Colors.green),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${(pct * 100).toStringAsFixed(0)}%',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(value.toStringAsFixed(2)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Riwayat Data & Status Daging Layak Konsumsi',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final csv = prov.exportCsv();
                      final path = _writeCsvToDownloads(csv);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('CSV diekspor: $path')),
                      );
                    },
                    icon: const Icon(Icons.download),
                    label: const Text('Ekspor CSV'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // simple filters row
              Row(
                children: [
                  const Text('Tanggal:'),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: () async {
                      await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                    },
                    icon: const Icon(Icons.date_range),
                    label: const Text('Pilih'),
                  ),
                  const SizedBox(width: 12),
                  const Text('Status:'),
                  const SizedBox(width: 8),
                  DropdownButton<String>(
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('Semua')),
                      DropdownMenuItem(value: 'LAYAK', child: Text('LAYAK')),
                    ],
                    onChanged: (_) {},
                    value: 'all',
                  ),
                ],
              ),
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
                    rows:
                        prov.readings.take(20).map((r) {
                          final color = statusColor(r.getStatus());
                          return DataRow(
                            cells: [
                              DataCell(Text(r.formattedTime())),
                              DataCell(Text(r.temperature.toStringAsFixed(1))),
                              DataCell(Text(r.humidity.toStringAsFixed(1))),
                              DataCell(Text(r.mq135.toStringAsFixed(2))),
                              DataCell(
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: color,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    Provider.of<SensorProvider>(
                                      context,
                                      listen: false,
                                    ).mapPredictionToLabel(r),
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _writeCsvToDownloads(String csv) {
    try {
      final user = Platform.environment['USERPROFILE'] ?? '.';
      final downloads = '$user\\Downloads';
      final file = File(
        '$downloads\\monitoring_export_${DateTime.now().millisecondsSinceEpoch}.csv',
      );
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
