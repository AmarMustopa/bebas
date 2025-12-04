import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

class PredictionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Generate a mock prediction from sensor values.
  /// sensors: map with keys mq2, mq3, mq135, temperature, humidity
  Map<String, dynamic> generateMockPrediction(Map<String, dynamic> sensors) {
    final mq135 = (sensors['mq135'] ?? 0).toDouble();
    final temp = (sensors['temperature'] ?? 0).toDouble();

    // simple rule-based mock
    String status;
    if (mq135 > 200 || temp > 25) {
      status = 'Tidak layak';
    } else if (mq135 > 100 || temp > 20) {
      status = 'Perlu diperhatikan';
    } else {
      status = 'Layak';
    }

    // fake TVC: weighted sum + noise
    final noise = (Random().nextDouble() - 0.5) * 0.5;
    final predictedTvc = (0.02 * mq135) + (0.1 * temp) + noise;

    // confidence based on how far from threshold
    double conf = 0.6;
    if (status == 'Tidak layak') conf = 0.85;
    if (status == 'Perlu diperhatikan') conf = 0.75;
    conf = (conf - 0.05) + Random().nextDouble() * 0.1;
    conf = conf.clamp(0.0, 0.99);

    return {
      'timestamp': Timestamp.now(),
      'predicted_tvc': double.parse(predictedTvc.toStringAsFixed(3)),
      'predicted_status': status,
      'confidence': double.parse(conf.toStringAsFixed(3)),
      'sensors': sensors,
      'source': 'mock',
    };
  }

  Future<void> savePrediction(Map<String, dynamic> prediction) async {
    await _firestore.collection('predictions').add(prediction);
  }
}
