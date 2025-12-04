import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../widgets/sensor_chart.dart';
import '../../widgets/sensor_card.dart';
import '../../models/sensor_data.dart' as model;
import '../sensor/sensor_detail_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final ApiService _apiService = ApiService();

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    final user = auth.user;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Dashboard Kualitas Daging'),
        centerTitle: true,
        backgroundColor: Colors.redAccent,
        actions: [
          if (user != null)
            Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: Text(user.displayName ?? user.email ?? ''),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: CircleAvatar(
                    radius: 14,
                    backgroundColor: Colors.white24,
                    backgroundImage: user.photoURL != null
                        ? NetworkImage(user.photoURL!)
                        : null,
                    child: user.photoURL == null
                        ? Text(
                            (user.displayName != null &&
                                    user.displayName!.isNotEmpty)
                                ? user.displayName!
                                    .substring(0, 1)
                                    .toUpperCase()
                                : (user.email != null
                                    ? user.email!.substring(0, 1).toUpperCase()
                                    : ''),
                            style: const TextStyle(color: Colors.white),
                          )
                        : null,
                  ),
                ),
              ],
            ),
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (c) => AlertDialog(
                  title: const Text('Konfirmasi Logout'),
                  content: const Text('Anda yakin ingin logout?'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.of(c).pop(false),
                        child: const Text('Batal')),
                    TextButton(
                        onPressed: () => Navigator.of(c).pop(true),
                        child: const Text('Logout')),
                  ],
                ),
              );

              if (ok == true) {
                await auth.signOut();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Anda telah logout')),
                );
              }
            },
          ),
        ],
      ),
      body: StreamBuilder<model.SensorData?>(
        stream: _apiService.getSensorDataStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: ${snapshot.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {}); // Trigger rebuild
                    },
                    child: const Text('Coba Lagi'),
                  ),
                ],
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data == null) {
            // Render empty-state dashboard shell so UI matches design even when there's no data
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Empty status banner
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
                          child: Text('Status Daging: Layak',
                              style: TextStyle(
                                  color: Colors.green.shade800,
                                  fontWeight: FontWeight.bold))),
                    ]),
                  ),

                  // Small metric cards row (zeros)
                  Row(children: [
                    _smallMetricPlaceholder('MQ2', '0.0', 'ppm'),
                    const SizedBox(width: 8),
                    _smallMetricPlaceholder('MQ3', '0.0', 'ppm'),
                    const SizedBox(width: 8),
                    _smallMetricPlaceholder('MQ135', '0.0', 'ppm'),
                    const SizedBox(width: 8),
                    _smallMetricPlaceholder('Suhu', '0.0', '°C'),
                    const SizedBox(width: 8),
                    _smallMetricPlaceholder('Kelembapan', '0.0', '%'),
                  ]),

                  const SizedBox(height: 24),
                  Text('Grafik Tren Sensor',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),

                  // placeholder large area
                  Container(
                      height: 280,
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(color: Colors.black12, blurRadius: 4)
                          ]),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.cloud_off, size: 48, color: Colors.grey),
                            const SizedBox(height: 8),
                            const Text('Tidak ada data sensor tersedia'),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: () async {
                                await _apiService.testConnection();
                                setState(() {});
                              },
                              icon: const Icon(Icons.refresh),
                              label: const Text('Test Koneksi API'),
                            ),
                            const SizedBox(height: 8),
                            const Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Text(
                                'Pastikan:\n'
                                '1. Flask API server running (python api_server.py)\n'
                                '2. URL API benar di api_service.dart\n'
                                '3. Data tersedia di InfluxDB',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ),
                          ],
                        ),
                      )),
                  const SizedBox(height: 12),
                  Container(
                      height: 180,
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(color: Colors.black12, blurRadius: 4)
                          ]),
                      child: const Center(child: Text('No data'))),
                ],
              ),
            );
          }

          // Ambil data sensor dari API
          final sensor = snapshot.data!;

          // Tentukan status berdasarkan nilai sensor dengan threshold yang benar
          final bool isLayak = _isDagingLayak(sensor);
          final String status = isLayak ? 'LAYAK' : 'TIDAK LAYAK';
          final String statusExplanation = _getDetailedStatusExplanation(sensor);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStatusCard(status),
                const SizedBox(height: 16),

                // Informasi keterangan layak dan tidak layak dengan penjelasan detail
                _buildStatusExplanation(status, statusExplanation),

                _buildSensorSummary(sensor),

                const SizedBox(height: 24),
                Text(
                  "Informasi Sensor",
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                _buildSensorDetails(sensor),
              ],
            ),
          );
        },
      ),
    );
  }

  // 🟢🔴 Tentukan status daging berdasarkan semua sensor
  String _getStatus(model.SensorData data) {
    // Thresholds untuk Tidak Layak (gabung medium dan high risk)
    bool isTidakLayak = data.mq2 > 50 ||
        data.mq3 > 150 ||
        data.mq135 > 100 ||
        data.temperature > 20 ||
        data.humidity > 70;

    if (isTidakLayak) {
      return "Tidak Layak";
    } else {
      return "Layak";
    }
  }

  Widget _buildStatusCard(String status) {
    // Normalisasi status (case-insensitive)
    final normalizedStatus = status.toUpperCase();
    final isLayak = normalizedStatus.contains('LAYAK') && !normalizedStatus.contains('TIDAK');
    
    Color color = isLayak ? Colors.green : Colors.redAccent;
    IconData icon = isLayak ? Icons.check_circle : Icons.cancel;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 2),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Status Daging:",
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.black54,
                  ),
                ),
                Text(
                  status.toUpperCase(),
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _smallMetricPlaceholder(String title, String value, String suffix) {
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
          Text('$value $suffix',
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.red)),
        ]),
      ),
    );
  }

  Widget _buildSensorSummary(model.SensorData data) {
    // Fungsi untuk mendapatkan status sensor dengan threshold yang benar
    Map<String, dynamic> getSensorStatus(String sensorType, double value) {
      String status;
      Color statusColor;
      String description;
      TrendDirection trend;

      switch (sensorType) {
        case 'MQ2':
          // Threshold yang benar: < 50 ppm (Normal), dari screenshot terlihat 355 ppm = tinggi
          if (value < 50) {
            status = '✅ Normal';
            statusColor = Colors.green;
            description = 'Gas umum dalam batas aman';
            trend = TrendDirection.down;
          } else if (value < 300) {
            status = '⚠️ Warning';
            statusColor = Colors.orange;
            description = 'Gas meningkat, tahap awal pembusukan';
            trend = TrendDirection.up;
          } else {
            status = '❌ Danger';
            statusColor = Colors.red;
            description = 'Tinggi - indikasi pembusukan awal';
            trend = TrendDirection.up;
          }
          break;

        case 'MQ3':
          // Threshold yang benar: < 150 ppm (Normal), dari screenshot 1957 ppm = sangat tinggi
          if (value < 150) {
            status = '✅ Normal';
            statusColor = Colors.green;
            description = 'Alkohol/VOC normal';
            trend = TrendDirection.down;
          } else if (value < 1000) {
            status = '⚠️ Warning';
            statusColor = Colors.orange;
            description = 'Tinggi - indikasi pembusukan';
            trend = TrendDirection.up;
          } else {
            status = '❌ Danger';
            statusColor = Colors.red;
            description = 'Tinggi - indikasi pembusukan';
            trend = TrendDirection.up;
          }
          break;

        case 'MQ135':
          // Threshold research-based: Fresh 30-100 ppm, Spoiled >300 ppm
          if (value < 100) {
            status = '✅ Normal';
            statusColor = Colors.green;
            description = 'NH₃ & CO₂ dalam batas aman';
            trend = TrendDirection.down;
          } else if (value < 300) {
            status = '⚠️ Warning';
            statusColor = Colors.orange;
            description = 'Amonia meningkat - degradasi protein';
            trend = TrendDirection.up;
          } else {
            status = '❌ Danger';
            statusColor = Colors.red;
            description = 'Sangat tinggi - protein breakdown';
            trend = TrendDirection.up;
          }
          break;

        case 'Temperature':
          // Ideal storage: 0-4°C (refrigerated), Safe: <10°C, Danger: >15°C
          if (value <= 10) {
            status = '✅ Optimal';
            statusColor = Colors.green;
            description = 'Suhu penyimpanan aman';
            trend = TrendDirection.down;
          } else if (value <= 15) {
            status = '⚠️ Warning';
            statusColor = Colors.orange;
            description = 'Suhu mulai naik, risiko bakteri';
            trend = TrendDirection.up;
          } else {
            status = '❌ Danger';
            statusColor = Colors.red;
            description = 'Terlalu panas, bakteri cepat berkembang';
            trend = TrendDirection.up;
          }
          break;

        case 'Humidity':
          // Optimal meat storage: 75-90%, Critical: <70% atau >95%
          if (value >= 75 && value <= 90) {
            status = '✅ Optimal';
            statusColor = Colors.green;
            description = 'Kelembapan ideal untuk penyimpanan';
            trend = TrendDirection.down;
          } else if (value >= 70 && value <= 95) {
            status = '⚠️ Warning';
            statusColor = Colors.orange;
            description = value < 75 ? 'Agak kering' : 'Agak lembap';
            trend = value < 75 ? TrendDirection.down : TrendDirection.up;
          } else {
            status = '❌ Tidak Ideal';
            statusColor = Colors.red;
            description = value < 70 ? 'Terlalu kering, tekstur rusak' : 'Terlalu lembap, risiko jamur';
            trend = value < 70 ? TrendDirection.down : TrendDirection.up;
          }
          break;

        default:
          status = '❓ Unknown';
          statusColor = Colors.grey;
          description = 'Status tidak diketahui';
          trend = TrendDirection.down;
      }

      return {
        'status': status,
        'color': statusColor,
        'description': description,
        'trend': trend,
      };
    }

    // Buat sensor cards dengan status yang sesuai
    final mq2Status = getSensorStatus('MQ2', data.mq2);
    final mq3Status = getSensorStatus('MQ3', data.mq3);
    final mq135Status = getSensorStatus('MQ135', data.mq135);
    final tempStatus = getSensorStatus('Temperature', data.temperature);
    final humidityStatus = getSensorStatus('Humidity', data.humidity);

    final cards = [
      _buildEnhancedSensorCard(
        title: "MQ2 - Gas Umum",
        subtitle: "LPG, Propana, Hidrogen",
        value: data.mq2.toStringAsFixed(0),
        unit: "ppm",
        threshold: "< 50 ppm",
        status: mq2Status['status'],
        statusColor: mq2Status['color'],
        description: mq2Status['description'],
        trend: mq2Status['trend'],
        icon: Icons.air,
        lastUpdate: data.timestamp,
        onDetailTap: () => _navigateToSensorDetail('MQ2'),
      ),
      _buildEnhancedSensorCard(
        title: "MQ3 - Alkohol/VOC",
        subtitle: "Indikator Pembusukan",
        value: data.mq3.toStringAsFixed(0),
        unit: "ppm",
        threshold: "< 150 ppm",
        status: mq3Status['status'],
        statusColor: mq3Status['color'],
        description: mq3Status['description'],
        trend: mq3Status['trend'],
        icon: Icons.science,
        lastUpdate: data.timestamp,
        onDetailTap: () => _navigateToSensorDetail('MQ3'),
      ),
      _buildEnhancedSensorCard(
        title: "MQ135 - NH₃/CO₂",
        subtitle: "Degradasi Protein",
        value: data.mq135.toStringAsFixed(0),
        unit: "ppm",
        threshold: "< 100 ppm",
        status: mq135Status['status'],
        statusColor: mq135Status['color'],
        description: mq135Status['description'],
        trend: mq135Status['trend'],
        icon: Icons.warning_amber,
        lastUpdate: data.timestamp,
        onDetailTap: () => _navigateToSensorDetail('MQ135'),
      ),
      _buildEnhancedSensorCard(
        title: "DHT11 - Suhu",
        subtitle: "Temperature Control",
        value: data.temperature.toStringAsFixed(1),
        unit: "°C",
        threshold: "0-10°C (Safe)",
        status: tempStatus['status'],
        statusColor: tempStatus['color'],
        description: tempStatus['description'],
        trend: tempStatus['trend'],
        icon: Icons.thermostat,
        lastUpdate: data.timestamp,
        onDetailTap: () => _navigateToSensorDetail('Temperature'),
      ),
      _buildEnhancedSensorCard(
        title: "DHT11 - Kelembapan",
        subtitle: "Humidity Control",
        value: data.humidity.toStringAsFixed(1),
        unit: "%",
        threshold: "75-90% (Optimal)",
        status: humidityStatus['status'],
        statusColor: humidityStatus['color'],
        description: humidityStatus['description'],
        trend: humidityStatus['trend'],
        icon: Icons.water_drop,
        lastUpdate: data.timestamp,
        onDetailTap: () => _navigateToSensorDetail('Humidity'),
      ),
    ];

    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 0.75, // Adjust ratio untuk card yang lebih tinggi
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: cards,
    );
  }

  void _navigateToSensorDetail(String sensorType) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SensorDetailScreen(sensorType: sensorType),
      ),
    );
  }

  Widget _buildStatusExplanation(String status, String detailedExplanation) {
    String explanation;
    Color color;

    switch (status.toLowerCase()) {
      case "layak":
        explanation =
            "✅ Daging dalam kondisi baik dan aman untuk dikonsumsi. Semua parameter sensor berada dalam batas normal.";
        color = Colors.green;
        break;
      case "tidak layak":
        explanation =
            "❌ Daging menunjukkan tanda-tanda pembusukan. TIDAK AMAN untuk dikonsumsi!";
        color = Colors.redAccent;
        break;
      default:
        explanation = "Status tidak diketahui.";
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                status.toLowerCase() == "layak" 
                    ? Icons.check_circle_outline 
                    : Icons.warning_amber_rounded,
                color: color,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                "Penjelasan Status",
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            explanation,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.black87,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (detailedExplanation.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.white, Colors.grey.shade50],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.shade200,
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.analytics_outlined, 
                           size: 18, 
                           color: Colors.indigo.shade600),
                      const SizedBox(width: 8),
                      Text(
                        "Analisis Detail",
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.indigo.shade700,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    detailedExplanation,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.black87,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          _buildThresholdInfo(),
        ],
      ),
    );
  }

  Widget _buildThresholdInfo() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade50, Colors.cyan.shade50],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade300, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.shade100,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.speed_outlined, 
                   size: 18, 
                   color: Colors.blue.shade700),
              const SizedBox(width: 8),
              Text(
                "Batas Threshold Sensor",
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.blue.shade800,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildThresholdRow("MQ2 (H₂ & CH₄)", "< 300 ppm (Fresh)"),
          _buildThresholdRow("MQ3 (VOC & Etanol)", "< 300 ppm (Fresh)"),
          _buildThresholdRow("MQ135 (NH₃ & CO₂)", "< 100 ppm (Fresh)"),
          _buildThresholdRow("Suhu (Safe Storage)", "0-10°C"),
          _buildThresholdRow("Kelembapan", "75-90%"),
        ],
      ),
    );
  }

  Widget _buildThresholdRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 11.5,
              color: Colors.black87,
              fontWeight: FontWeight.w500,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.blue.shade300, width: 1),
            ),
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: Colors.blue.shade800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Fungsi untuk menentukan apakah daging layak berdasarkan threshold
  bool _isDagingLayak(model.SensorData sensor) {
    // Threshold berdasarkan research literature dan kalibrasi sensor real
    // Reference: Meat spoilage detection using MQ gas sensors
    const double MQ2_THRESHOLD = 300.0;    // Fresh: 200-300 ppm, Spoiled: >1000 ppm
    const double MQ3_THRESHOLD = 300.0;    // Fresh: 100-300 ppm, Spoiled: >800 ppm
    const double MQ135_THRESHOLD = 100.0;  // Fresh: 30-100 ppm, Spoiled: >300 ppm
    const double TEMP_MAX = 10.0;          // Safe storage: 0-10°C (refrigerated)
    const double HUMIDITY_MIN = 75.0;      // Optimal meat storage
    const double HUMIDITY_MAX = 90.0;      // Prevent excessive moisture

    // Daging TIDAK LAYAK jika salah satu kondisi terpenuhi:
    if (sensor.mq2 > MQ2_THRESHOLD) return false;
    if (sensor.mq3 > MQ3_THRESHOLD) return false;
    if (sensor.mq135 > MQ135_THRESHOLD) return false;
    if (sensor.temperature > TEMP_MAX) return false;
    if (sensor.humidity > HUMIDITY_MAX || sensor.humidity < HUMIDITY_MIN) return false;

    return true; // Semua parameter normal = LAYAK
  }

  // Fungsi untuk mendapatkan penjelasan detail berdasarkan nilai sensor
  String _getDetailedStatusExplanation(model.SensorData sensor) {
    List<String> issues = [];

    // Threshold berdasarkan research literature
    const double MQ2_THRESHOLD = 300.0;    // Gas H₂, CH₄ dari bakteri anaerob
    const double MQ3_THRESHOLD = 300.0;    // VOC, etanol dari fermentasi
    const double MQ135_THRESHOLD = 100.0;  // NH₃ dari degradasi protein
    const double TEMP_MAX = 10.0;          // Suhu penyimpanan aman
    const double HUMIDITY_MIN = 75.0;
    const double HUMIDITY_MAX = 90.0;

    // Analisis setiap sensor dengan kategori tingkat bahaya
    if (sensor.mq2 > 1000) {
      issues.add(
          '🔴 MQ2: ${sensor.mq2.toStringAsFixed(0)} ppm (SANGAT TINGGI - Spoiled)\n'
          '   Gas H₂ dan CH₄ sangat tinggi! Pembusukan lanjut oleh bakteri anaerob.');
    } else if (sensor.mq2 > MQ2_THRESHOLD) {
      issues.add(
          '⚠️ MQ2: ${sensor.mq2.toStringAsFixed(0)} ppm (Melebihi ${MQ2_THRESHOLD.toStringAsFixed(0)} ppm)\n'
          '   Terdeteksi gas H₂ dan CH₄ tinggi - tahap awal pembusukan.');
    }

    if (sensor.mq3 > 800) {
      issues.add(
          '🔴 MQ3: ${sensor.mq3.toStringAsFixed(0)} ppm (SANGAT TINGGI - Spoiled)\n'
          '   VOC dan alkohol ekstrem! Fermentasi bakteri sangat aktif.');
    } else if (sensor.mq3 > MQ3_THRESHOLD) {
      issues.add(
          '❌ MQ3: ${sensor.mq3.toStringAsFixed(0)} ppm (Melebihi ${MQ3_THRESHOLD.toStringAsFixed(0)} ppm)\n'
          '   Terdeteksi VOC dan etanol tinggi - aktivitas fermentasi bakteri.');
    }

    if (sensor.mq135 > 300) {
      issues.add(
          '🔴 MQ135: ${sensor.mq135.toStringAsFixed(0)} ppm (SANGAT TINGGI - Spoiled)\n'
          '   Amonia sangat tinggi! Degradasi protein lanjut.');
    } else if (sensor.mq135 > MQ135_THRESHOLD) {
      issues.add(
          '⚠️ MQ135: ${sensor.mq135.toStringAsFixed(0)} ppm (Melebihi ${MQ135_THRESHOLD.toStringAsFixed(0)} ppm)\n'
          '   Terdeteksi NH₃ dan CO₂ dari degradasi protein.');
    }

    if (sensor.temperature > 15) {
      issues.add(
          '🌡️ Suhu: ${sensor.temperature.toStringAsFixed(1)}°C (TERLALU TINGGI)\n'
          '   Suhu tidak aman! Pertumbuhan bakteri sangat cepat di >15°C.');
    } else if (sensor.temperature > TEMP_MAX) {
      issues.add(
          '🌡️ Suhu: ${sensor.temperature.toStringAsFixed(1)}°C (Melebihi ${TEMP_MAX.toStringAsFixed(0)}°C)\n'
          '   Suhu di atas suhu penyimpanan aman (0-10°C).');
    }

    if (sensor.humidity > HUMIDITY_MAX) {
      issues.add(
          '💧 Kelembapan: ${sensor.humidity.toStringAsFixed(1)}% (Melebihi ${HUMIDITY_MAX.toStringAsFixed(0)}%)\n'
          '   Kelembapan berlebih mempercepat pertumbuhan jamur.');
    } else if (sensor.humidity < HUMIDITY_MIN) {
      issues.add(
          '💧 Kelembapan: ${sensor.humidity.toStringAsFixed(1)}% (Kurang dari ${HUMIDITY_MIN.toStringAsFixed(0)}%)\n'
          '   Kelembapan rendah, daging bisa mengering dan berubah tekstur.');
    }

    if (issues.isEmpty) {
      return '✅ Semua parameter sensor dalam batas normal:\n'
          '• MQ2: ${sensor.mq2.toStringAsFixed(0)} ppm (Normal)\n'
          '• MQ3: ${sensor.mq3.toStringAsFixed(0)} ppm (Normal)\n'
          '• MQ135: ${sensor.mq135.toStringAsFixed(0)} ppm (Normal)\n'
          '• Suhu: ${sensor.temperature.toStringAsFixed(1)}°C (Ideal)\n'
          '• Kelembapan: ${sensor.humidity.toStringAsFixed(1)}% (Ideal)';
    }

    return issues.join('\n\n');
  }

  // Widget untuk sensor card yang enhanced dengan status
  Widget _buildEnhancedSensorCard({
    required String title,
    required String subtitle,
    required String value,
    required String unit,
    required String threshold,
    required String status,
    required Color statusColor,
    required String description,
    required TrendDirection trend,
    required IconData icon,
    required DateTime lastUpdate,
    required VoidCallback onDetailTap,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: statusColor.withOpacity(0.3), width: 2),
      ),
      child: InkWell(
        onTap: onDetailTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header dengan icon dan status
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: statusColor, size: 24),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          subtitle,
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            color: Colors.grey.shade600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              // Nilai sensor
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    value,
                    style: GoogleFonts.poppins(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                      height: 1,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      unit,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              
              // Status badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: statusColor.withOpacity(0.3)),
                ),
                child: Text(
                  status,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              
              // Deskripsi
              Text(
                description,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: Colors.black87,
                  height: 1.3,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              
              // Threshold info
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 14, color: Colors.grey.shade700),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Threshold: $threshold',
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          color: Colors.grey.shade700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              
              // Update time
              Row(
                children: [
                  Icon(Icons.access_time, size: 12, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(
                    _formatUpdateTime(lastUpdate),
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatUpdateTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    
    if (diff.inSeconds < 10) {
      return 'Baru saja';
    } else if (diff.inSeconds < 60) {
      return '${diff.inSeconds} detik lalu';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes} menit lalu';
    } else if (diff.inHours < 24) {
      return '${diff.inHours} jam lalu';
    } else {
      return '${diff.inDays} hari lalu';
    }
  }

  Widget _buildStatusExplanation_OLD(String status) {
    String explanation;
    Color color;

    switch (status) {
      case "Layak":
        explanation =
            "Daging dalam kondisi baik dan aman untuk dikonsumsi. Semua parameter sensor berada dalam batas normal.";
        color = Colors.green;
        break;
      case "Tidak Layak":
        explanation =
            "Daging menunjukkan tanda-tanda awal pembusukan. Periksa kondisi penyimpanan dan segera gunakan.";
        color = Colors.redAccent;
        break;
      default:
        explanation = "Status tidak diketahui.";
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.help_outline, color: color, size: 24),
              const SizedBox(width: 8),
              Text(
                "Penjelasan Status",
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            explanation,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSensorDetails(model.SensorData data) {
    return Column(
      children: [
        _buildSensorDetailCard(
          "MQ2 - Gas Umum",
          data.mq2,
          "ppm",
          "Mendeteksi gas hidrogen (H₂) dan metana (CH₄) yang dihasilkan oleh bakteri anaerob saat daging mulai membusuk. Penelitian menunjukkan daging segar menghasilkan 200-300 ppm, sedangkan daging busuk menghasilkan >1000 ppm. Nilai normal: < 300 ppm (Fresh). Peningkatan gas ini adalah indikator awal pembusukan oleh bakteri penghasil gas seperti Clostridium spp.",
          data.mq2 > 1000 ? "Sangat Tinggi - Spoiled" : (data.mq2 > 300 ? "Tinggi - indikasi pembusukan awal" : "Normal"),
          data.mq2 > 1000 ? Colors.red : (data.mq2 > 300 ? Colors.orange : Colors.green),
        ),
        _buildSensorDetailCard(
          "MQ3 - Alkohol dan Volatile Organic Compounds",
          data.mq3,
          "ppm",
          "Mendeteksi senyawa organik volatil (VOC) dan etanol dari fermentasi bakteri. Daging segar: 100-300 ppm, daging busuk: >800 ppm. Nilai normal: < 300 ppm (Fresh). VOC seperti asetaldehida, aseton, dan senyawa sulfur adalah biomarker kuat pembusukan. Etanol meningkat karena aktivitas fermentasi bakteri Lactobacillus dan Pseudomonas pada daging yang membusuk.",
          data.mq3 > 800 ? "Sangat Tinggi - Spoiled" : (data.mq3 > 300 ? "Tinggi - indikasi pembusukan" : "Normal"),
          data.mq3 > 800 ? Colors.red : (data.mq3 > 300 ? Colors.orange : Colors.green),
        ),
        _buildSensorDetailCard(
          "MQ135 - Amonia dan CO₂",
          data.mq135,
          "ppm",
          "Mendeteksi amonia (NH₃) dari degradasi protein dan CO₂ dari respirasi bakteri. Daging segar: 30-100 ppm, daging busuk: >300 ppm. Nilai normal: < 100 ppm (Fresh). Amonia adalah hasil dekomposisi protein oleh bakteri proteolitik (Pseudomonas, Shewanella). Peningkatan NH₃ menunjukkan pembusukan lanjut dengan protein breakdown aktif.",
          data.mq135 > 300 ? "Sangat Tinggi - Spoiled" : (data.mq135 > 100 ? "Tinggi - pembusukan aktif" : "Normal"),
          data.mq135 > 300 ? Colors.red : (data.mq135 > 100 ? Colors.orange : Colors.green),
        ),
        _buildSensorDetailCard(
          "DHT11 - Suhu",
          data.temperature,
          "°C",
          "Mengukur suhu lingkungan penyimpanan daging. Suhu optimal: 0-4°C (refrigerated), aman: <10°C. Nilai safe: 0-10°C. Suhu >15°C sangat berbahaya karena mempercepat pertumbuhan bakteri patogen (Salmonella, E. coli, Listeria). Pada suhu >15°C, bakteri berkembang biak dengan cepat (doubling time ~20 menit), mengakselerasi pembusukan.",
          data.temperature > 15
              ? "Berbahaya - bakteri cepat berkembang"
              : (data.temperature > 10 ? "Warning - suhu naik" : "Optimal"),
          data.temperature > 15 ? Colors.red : (data.temperature > 10 ? Colors.orange : Colors.green),
        ),
        _buildSensorDetailCard(
          "DHT11 - Kelembapan",
          data.humidity,
          "%",
          "Mengukur kelembapan udara di lingkungan penyimpanan. Kelembapan optimal: 75-90% untuk daging segar. Nilai optimal: 75-90%. Kelembapan >90% meningkatkan risiko pertumbuhan jamur (mold) dan bakteri seperti Pseudomonas yang menyebabkan pembusukan. Kelembapan <75% menyebabkan daging mengering, perubahan tekstur, dan penurunan kualitas.",
          data.humidity > 90 ? "Terlalu lembab - risiko jamur" : (data.humidity < 75 ? "Terlalu kering - tekstur rusak" : "Optimal"),
          (data.humidity > 90 || data.humidity < 75) ? Colors.orange : Colors.green,
        ),
      ],
    );
  }

  Widget _buildSensorDetailCard(String title, double value, String unit,
      String description, String status, Color statusColor) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: statusColor, width: 1),
                  ),
                  child: Text(
                    status,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  "${value.toStringAsFixed(1)} $unit",
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Removed old _buildSensorCard method as it's replaced by SensorCard widget
}
