import 'package:flutter/material.dart';
import 'dart:async';
import '../models/sensor_reading.dart';
import '../models/sensor_data.dart';
import '../services/api_service.dart';

class SensorProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  
  List<SensorReading> _readings = [];
  bool _isLoading = false;
  Timer? _pollTimer;

  List<SensorReading> get readings => _readings;
  bool get isLoading => _isLoading;

  SensorProvider() {
    start();
  }

  void start() {
    print('🚀 SensorProvider.start() - Starting API polling');
    // Start polling from API every 3 seconds for real-time data
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      try {
        print('📡 Polling API for latest sensor data...');
        final sensorData = await _apiService.getLatestSensorData();
        if (sensorData != null) {
          print('✅ Got data from API: Suhu=${sensorData.temperature}, RH=${sensorData.humidity}%');
          
          // Convert API data to SensorReading and prepend to list
          final newReading = SensorReading(
            temperature: sensorData.temperature,
            humidity: sensorData.humidity,
            mq2: sensorData.mq2,
            mq3: sensorData.mq3,
            mq135: sensorData.mq135,
            timestamp: sensorData.timestamp,
          );
          
          // Keep only last 100 readings to avoid memory issues
          _readings.insert(0, newReading);
          if (_readings.length > 100) {
            _readings = _readings.sublist(0, 100);
          }
          
          print('📊 Total readings: ${_readings.length}');
          notifyListeners();
        } else {
          print('⚠️ No data returned from API');
        }
      } catch (e) {
        print('❌ Error polling API: $e');
      }
    });
  }

  void stop() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  String mapPredictionToLabel(SensorReading reading) {
    final status = reading.getStatus();
    switch (status) {
      case MeatStatus.LAYAK:
        return 'Layak';
      case MeatStatus.PERLU_DIPERHATIKAN:
        return 'Perlu Diperhatikan';
      case MeatStatus.TIDAK_LAYAK:
        return 'Tidak Layak';
    }
  }

  String exportCsv() {
    final buffer = StringBuffer();
    buffer.writeln('Timestamp,Temperature,Humidity,MQ2,MQ3,MQ135,Status');
    for (final reading in _readings) {
      buffer.writeln('${reading.timestamp.toIso8601String()},${reading.temperature},${reading.humidity},${reading.mq2},${reading.mq3},${reading.mq135},${mapPredictionToLabel(reading)}');
    }
    return buffer.toString();
  }
}
