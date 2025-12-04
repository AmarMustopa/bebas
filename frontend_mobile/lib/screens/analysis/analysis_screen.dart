import 'package:flutter/material.dart';
import '../../services/prediction_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({Key? key}) : super(key: key);

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  final PredictionService _predictionService = PredictionService();
  bool _loading = false;
  Map<String, dynamic>? _lastPrediction;

  Future<void> _runPrediction() async {
    setState(() => _loading = true);

    // fetch latest sensor
  final snapshot = await FirebaseFirestore.instance
        .collection('sensor_data')
        .orderBy('timestamp', descending: true)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No sensor data to predict')));
      setState(() => _loading = false);
      return;
    }

  final doc = snapshot.docs.first.data();
    final sensors = {
      'mq2': (doc['mq2'] ?? 0).toDouble(),
      'mq3': (doc['mq3'] ?? 0).toDouble(),
      'mq135': (doc['mq135'] ?? 0).toDouble(),
      'temperature': (doc['temperature'] ?? 0).toDouble(),
      'humidity': (doc['humidity'] ?? 0).toDouble(),
    };

    final pred = _predictionService.generateMockPrediction(sensors);
    await _predictionService.savePrediction(pred);

    setState(() {
      _lastPrediction = pred;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Analisis & Prediksi', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _loading ? null : _runPrediction,
                icon: const Icon(Icons.refresh),
                label: _loading ? const Text('Running...') : const Text('Update Prediksi Sekarang'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_lastPrediction != null) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Status: ${_lastPrediction!['predicted_status']}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    Text('Predicted TVC: ${_lastPrediction!['predicted_tvc']}'),
                    Text('Confidence: ${( _lastPrediction!['confidence'] * 100 ).toStringAsFixed(1)}%'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          const Text('Riwayat Prediksi', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('predictions').orderBy('timestamp', descending: true).limit(50).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return const Text('Error loading history');
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final docs = snapshot.data!.docs;
                if (docs.isEmpty) return const Text('No predictions yet');
                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final d = docs[index].data() as Map<String, dynamic>;
                    final ts = (d['timestamp'] as Timestamp).toDate();
                    return ListTile(
                      leading: Icon(d['predicted_status'] == 'Tidak layak' ? Icons.warning_amber_rounded : Icons.check_circle, color: d['predicted_status'] == 'Tidak layak' ? Colors.redAccent : Colors.green),
                      title: Text('${d['predicted_status']} - TVC: ${d['predicted_tvc']}'),
                      subtitle: Text('${ts.toLocal()} • confidence ${(d['confidence'] * 100).toStringAsFixed(1)}%'),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
