import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/sensor_data.dart';

class DatabaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Stream data sensor terkini
  Stream<SensorData> getLatestSensorStream() {
    return _firestore
        .collection('sensor_data')
        .orderBy('timestamp', descending: true)
        .limit(1)
        .snapshots()
        .map((snapshot) {
      // if there are no documents yet, return a default SensorData
      if (snapshot.docs.isEmpty) {
        return SensorData(
          mq2: 0,
          mq3: 0,
          mq135: 0,
          temperature: 0,
          humidity: 0,
          status: 'TIDAK LAYAK',
          timestamp: DateTime.now(),
        );
      }

      final doc = snapshot.docs.first;
      return SensorData.fromFirestore(doc);
    });
  }

  /// Stream data historis untuk grafik tren
  Stream<List<SensorData>> getSensorHistoryStream() {
    return _firestore
        .collection('sensor_data')
        .orderBy('timestamp', descending: false)
        .limit(100)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => SensorData.fromFirestore(doc)).toList());
  }

  /// Debug helper: seed dummy data into `sensor_data` collection.
  /// If makeBad=true, values will be high to produce status 'Tidak Layak'.
  Future<void> seedDummyData({int count = 12, bool makeBad = false}) async {
    final batch = _firestore.batch();
    final now = DateTime.now();
    final col = _firestore.collection('sensor_data');

    for (int i = 0; i < count; i++) {
      final ts = now.subtract(Duration(minutes: count - i));
      final docRef = col.doc();

      // generate values; if makeBad then set values to exceed thresholds
      final mq2 = makeBad ? 60.0 + i.toDouble() : 30.0 + (i % 10);
      final mq3 = makeBad ? 160.0 + i.toDouble() : 100.0 + (i % 20);
      final mq135 = makeBad ? 120.0 + i.toDouble() : 60.0 + (i % 20);
      final temperature = makeBad ? 25.0 + i % 5 : 15.0 + (i % 5);
      final humidity = makeBad ? 75.0 + (i % 5) : 50.0 + (i % 10);

      // Determine status based on thresholds
      final isTidakLayak = mq2 > 50 ||
          mq3 > 150 ||
          mq135 > 100 ||
          temperature > 20 ||
          humidity > 70;
      final status = isTidakLayak ? 'Tidak Layak' : 'Layak';

      batch.set(docRef, {
        'mq2': mq2,
        'mq3': mq3,
        'mq135': mq135,
        'temperature': temperature,
        'humidity': humidity,
        'status': status,
        'timestamp': Timestamp.fromDate(ts),
      });
    }

    await batch.commit();
  }
}
