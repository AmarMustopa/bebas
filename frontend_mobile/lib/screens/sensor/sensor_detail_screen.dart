import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/sensor_data.dart' as model;

class SensorDetailScreen extends StatefulWidget {
  final String sensorType;

  const SensorDetailScreen({Key? key, required this.sensorType})
      : super(key: key);

  @override
  State<SensorDetailScreen> createState() => _SensorDetailScreenState();
}

class _SensorDetailScreenState extends State<SensorDetailScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Detail ${widget.sensorType}'),
        backgroundColor: Colors.redAccent,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('sensor_data')
            .orderBy('timestamp', descending: true)
            .limit(50)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('Tidak ada data sensor'));
          }

          final docs = snapshot.data!.docs;
          final sensorData = docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return model.SensorData(
              temperature: (data['temperature'] ?? 0).toDouble(),
              humidity: (data['humidity'] ?? 0).toDouble(),
              mq2: (data['mq2'] ?? 0).toDouble(),
              mq3: (data['mq3'] ?? 0).toDouble(),
              mq135: (data['mq135'] ?? 0).toDouble(),
              status: data['status'] ?? 'Layak',
              timestamp: (data['timestamp'] as Timestamp).toDate(),
            );
          }).toList();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSensorInfo(sensorData.first),
                const SizedBox(height: 24),
                Text(
                  'Riwayat Data ${widget.sensorType}',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                _buildHistoryList(sensorData),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSensorInfo(model.SensorData data) {
    String title;
    String description;
    double value;
    String unit;
    String status;
    Color statusColor;

    switch (widget.sensorType) {
      case 'MQ2':
        title = 'MQ2 - Gas H₂ & CH₄';
        description =
            'Mendeteksi gas hidrogen (H₂) dan metana (CH₄) yang dihasilkan oleh bakteri anaerob saat daging mulai membusuk. Penelitian menunjukkan daging segar menghasilkan 200-300 ppm, sedangkan daging busuk menghasilkan >1000 ppm. Peningkatan gas ini adalah indikator awal pembusukan oleh bakteri penghasil gas seperti Clostridium spp.';
        value = data.mq2;
        unit = 'ppm';
        status = data.mq2 > 1000 ? 'Sangat Tinggi - Spoiled' : (data.mq2 > 300 ? 'Warning - Tahap Awal' : 'Normal - Fresh');
        statusColor = data.mq2 > 1000 ? Colors.red : (data.mq2 > 300 ? Colors.orange : Colors.green);
        break;
      case 'MQ3':
        title = 'MQ3 - VOC & Alkohol (Etanol)';
        description =
            'Mendeteksi senyawa organik volatil (VOC) dan etanol dari fermentasi bakteri. Daging segar: 100-300 ppm, daging busuk: >800 ppm. VOC seperti asetaldehida, aseton, dan senyawa sulfur adalah biomarker kuat pembusukan. Etanol meningkat karena aktivitas fermentasi bakteri Lactobacillus dan Pseudomonas pada daging yang membusuk.';
        value = data.mq3;
        unit = 'ppm';
        status = data.mq3 > 800 ? 'Sangat Tinggi - Spoiled' : (data.mq3 > 300 ? 'Warning - Fermentasi Aktif' : 'Normal - Fresh');
        statusColor = data.mq3 > 800 ? Colors.red : (data.mq3 > 300 ? Colors.orange : Colors.green);
        break;
      case 'MQ135':
        title = 'MQ135 - Amonia (NH₃) & CO₂';
        description =
            'Mendeteksi amonia (NH₃) dari degradasi protein dan CO₂ dari respirasi bakteri. Daging segar: 30-100 ppm, daging busuk: >300 ppm. Amonia adalah hasil dekomposisi protein oleh bakteri proteolitik (Pseudomonas, Shewanella). Peningkatan NH₃ menunjukkan pembusukan lanjut dengan protein breakdown aktif.';
        value = data.mq135;
        unit = 'ppm';
        status = data.mq135 > 300 ? 'Sangat Tinggi - Spoiled' : (data.mq135 > 100 ? 'Warning - Degradasi Protein' : 'Normal - Fresh');
        statusColor = data.mq135 > 300 ? Colors.red : (data.mq135 > 100 ? Colors.orange : Colors.green);
        break;
      case 'Temperature':
        title = 'DHT11 - Temperature Control';
        description =
            'Mengukur suhu lingkungan penyimpanan daging. Suhu optimal: 0-4°C (refrigerated), aman: <10°C. Suhu >15°C sangat berbahaya karena mempercepat pertumbuhan bakteri patogen (Salmonella, E. coli, Listeria). Pada suhu >15°C, bakteri berkembang biak dengan cepat (doubling time ~20 menit), mengakselerasi pembusukan.';
        value = data.temperature;
        unit = '°C';
        status = data.temperature > 15
            ? 'Berbahaya - bakteri cepat berkembang'
            : (data.temperature > 10 ? 'Warning - suhu naik' : 'Optimal - safe storage');
        statusColor = data.temperature > 15 ? Colors.red : (data.temperature > 10 ? Colors.orange : Colors.green);
        break;
      case 'Humidity':
        title = 'DHT11 - Kelembapan Udara';
        description =
            'Mengukur kelembapan udara di lingkungan penyimpanan. Kelembapan optimal: 75-90% untuk daging segar. Kelembapan >90% meningkatkan risiko pertumbuhan jamur (mold) dan bakteri seperti Pseudomonas yang menyebabkan pembusukan. Kelembapan <70% menyebabkan daging mengering, perubahan tekstur, dan penurunan kualitas.';
        value = data.humidity;
        unit = '%';
        status = data.humidity > 90
            ? 'Terlalu lembab - risiko jamur'
            : (data.humidity < 75 ? 'Terlalu kering - tekstur rusak' : 'Optimal');
        statusColor = (data.humidity > 90 || data.humidity < 75) ? Colors.orange : Colors.green;
        break;
      default:
        title = widget.sensorType;
        description = 'Informasi sensor tidak tersedia';
        value = 0;
        unit = '';
        status = 'Tidak diketahui';
        statusColor = Colors.grey;
    }

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${value.toStringAsFixed(1)} $unit',
                      style: GoogleFonts.poppins(
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Terakhir update: ${TimeOfDay.fromDateTime(data.timestamp).format(context)}',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor),
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
            const SizedBox(height: 16),
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

  Widget _buildHistoryList(List<model.SensorData> sensorData) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: sensorData.length,
      itemBuilder: (context, index) {
        final data = sensorData[index];
        double value;
        String unit;

        switch (widget.sensorType) {
          case 'MQ2':
            value = data.mq2;
            unit = 'ppm';
            break;
          case 'MQ3':
            value = data.mq3;
            unit = 'ppm';
            break;
          case 'MQ135':
            value = data.mq135;
            unit = 'ppm';
            break;
          case 'Temperature':
            value = data.temperature;
            unit = '°C';
            break;
          case 'Humidity':
            value = data.humidity;
            unit = '%';
            break;
          default:
            value = 0;
            unit = '';
        }

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          child: ListTile(
            title: Text('${value.toStringAsFixed(1)} $unit'),
            subtitle: Text(
              '${data.timestamp.day}/${data.timestamp.month}/${data.timestamp.year} ${TimeOfDay.fromDateTime(data.timestamp).format(context)}',
            ),
            trailing: Text(
              data.status,
              style: TextStyle(
                color: Color(data.statusColor),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        );
      },
    );
  }
}
