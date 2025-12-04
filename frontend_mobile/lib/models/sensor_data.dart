import 'package:cloud_firestore/cloud_firestore.dart';

class SensorData {
  final double temperature;   // Suhu (°C)
  final double humidity;      // Kelembapan (%)
  final double mq2;           // Sensor Gas MQ-2
  final double mq3;           // Sensor Gas MQ-3
  final double mq135;         // Sensor Gas MQ-135
  final String status;        // Status daging: "LAYAK" / "TIDAK LAYAK"
  final DateTime timestamp;   // Waktu pembacaan data
  final double skorGas;       // Skor komponen gas (0-100)
  final double skorSuhu;      // Skor komponen suhu (0-100)
  final double skorRH;        // Skor komponen kelembapan (0-100)
  final double skorTotal;     // Skor total (0-100)

  SensorData({
    required this.temperature,
    required this.humidity,
    required this.mq2,
    required this.mq3,
    required this.mq135,
    required this.status,
    required this.timestamp,
    this.skorGas = 0,
    this.skorSuhu = 0,
    this.skorRH = 0,
    this.skorTotal = 0,
  });

  /// Factory untuk membuat objek dari data Firestore / JSON
  factory SensorData.fromMap(Map<String, dynamic> map) {
    // Convert status dari integer ke string
    String statusText;
    if (map['status'] is int) {
      statusText = map['status'] == 1 ? 'LAYAK' : 'TIDAK LAYAK';
    } else if (map['status'] is String) {
      statusText = map['status'];
    } else {
      statusText = 'TIDAK LAYAK';
    }
    
    return SensorData(
      temperature: (map['temperature'] ?? 0.0).toDouble(),
      humidity: (map['humidity'] ?? 0.0).toDouble(),
      mq2: (map['mq2'] ?? 0.0).toDouble(),
      mq3: (map['mq3'] ?? 0.0).toDouble(),
      mq135: (map['mq135'] ?? 0.0).toDouble(),
      status: statusText,
      timestamp: map['timestamp'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['timestamp'])
          : DateTime.now(),
      skorGas: (map['skorGas'] ?? 0.0).toDouble(),
      skorSuhu: (map['skorSuhu'] ?? 0.0).toDouble(),
      skorRH: (map['skorRH'] ?? 0.0).toDouble(),
      skorTotal: (map['skorTotal'] ?? 0.0).toDouble(),
    );
  }

  factory SensorData.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    // guard against missing or unexpected types
    final mq2 = (data['mq2'] ?? 0);
    final mq3 = (data['mq3'] ?? 0);
    final mq135 = (data['mq135'] ?? 0);
    final temperature = (data['temperature'] ?? 0);
    final humidity = (data['humidity'] ?? 0);
    final rawTs = data['timestamp'];
    DateTime timestamp;
    if (rawTs is Timestamp) {
      timestamp = rawTs.toDate();
    } else if (rawTs is int) {
      timestamp = DateTime.fromMillisecondsSinceEpoch(rawTs);
    } else {
      timestamp = DateTime.now();
    }

    return SensorData(
      mq2: mq2.toDouble(),
      mq3: mq3.toDouble(),
      mq135: mq135.toDouble(),
      temperature: temperature.toDouble(),
      humidity: humidity.toDouble(),
      status: data['status'] ?? 'TIDAK LAYAK',
      timestamp: timestamp,
      skorGas: (data['skorGas'] ?? 0.0).toDouble(),
      skorSuhu: (data['skorSuhu'] ?? 0.0).toDouble(),
      skorRH: (data['skorRH'] ?? 0.0).toDouble(),
      skorTotal: (data['skorTotal'] ?? 0.0).toDouble(),
    );
  }

  /// Konversi objek ke Map (untuk dikirim ke Firebase)
  Map<String, dynamic> toMap() {
    return {
      'temperature': temperature,
      'humidity': humidity,
      'mq2': mq2,
      'mq3': mq3,
      'mq135': mq135,
      'status': status,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'skorGas': skorGas,
      'skorSuhu': skorSuhu,
      'skorRH': skorRH,
      'skorTotal': skorTotal,
    };
  }

  /// Total nilai gas (gabungan 3 sensor)
  double get totalGas => mq2 + mq3 + mq135;

  /// Logika untuk menentukan apakah daging masih segar
  bool get isMeatFresh {
    // Kamu bisa atur ambang batas ini sesuai hasil kalibrasi
    return totalGas < 800 && temperature < 40 && humidity < 80;
  }

  /// Rekomendasi berdasarkan data
  String get freshnessRecommendation {
    if (!isMeatFresh) {
      if (mq135 > 200 || temperature > 30) {
        return "Peringatan! Daging menunjukkan tanda pembusukan.";
      } else if (mq2 > 150 || mq3 > 150) {
        return "Daging mulai tidak stabil, periksa penyimpanan.";
      } else {
        return "Daging tidak layak konsumsi. Suhu atau gas terlalu tinggi.";
      }
    } else {
      return "Daging dalam kondisi segar dan layak konsumsi.";
    }
  }

  /// Get status with emoji
  String get statusWithEmoji {
    switch (status.toLowerCase()) {
      case 'layak':
        return '🟢 Layak';
      case 'perlu diperhatikan':
        return '🟡 Perlu diperhatikan';
      case 'tidak layak':
        return '🔴 Tidak layak';
      default:
        return '⚪ Tidak diketahui';
    }
  }

  /// Get status color
  int get statusColor {
    switch (status.toLowerCase()) {
      case 'layak':
        return 0xFF4CAF50; // Green
      case 'perlu diperhatikan':
        return 0xFFFF9800; // Orange
      case 'tidak layak':
        return 0xFFF44336; // Red
      default:
        return 0xFF9E9E9E; // Grey
    }
  }
}
