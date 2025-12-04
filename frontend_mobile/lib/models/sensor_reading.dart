import 'package:cloud_firestore/cloud_firestore.dart';

enum MeatStatus { LAYAK, PERLU_DIPERHATIKAN, TIDAK_LAYAK }

class SensorReading {
  final double temperature;
  final double humidity;
  final double mq2;
  final double mq3;
  final double mq135;
  final DateTime timestamp;

  SensorReading({
    required this.temperature,
    required this.humidity,
    required this.mq2,
    required this.mq3,
    required this.mq135,
    required this.timestamp,
  });

  factory SensorReading.fromMap(Map<String, dynamic> map) {
    return SensorReading(
      temperature: (map['temperature'] ?? 0.0).toDouble(),
      humidity: (map['humidity'] ?? 0.0).toDouble(),
      mq2: (map['mq2'] ?? 0.0).toDouble(),
      mq3: (map['mq3'] ?? 0.0).toDouble(),
      mq135: (map['mq135'] ?? 0.0).toDouble(),
      timestamp: map['timestamp'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['timestamp'])
          : DateTime.now(),
    );
  }

  factory SensorReading.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
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

    return SensorReading(
      mq2: mq2.toDouble(),
      mq3: mq3.toDouble(),
      mq135: mq135.toDouble(),
      temperature: temperature.toDouble(),
      humidity: humidity.toDouble(),
      timestamp: timestamp,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'temperature': temperature,
      'humidity': humidity,
      'mq2': mq2,
      'mq3': mq3,
      'mq135': mq135,
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }

  MeatStatus getStatus() {
    if (mq135 > 200 || temperature > 25 || humidity > 80) {
      return MeatStatus.TIDAK_LAYAK;
    } else if (mq135 > 100 || temperature > 20 || humidity > 70) {
      return MeatStatus.PERLU_DIPERHATIKAN;
    } else {
      return MeatStatus.LAYAK;
    }
  }

  String formattedTime() {
    return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
  }
}
