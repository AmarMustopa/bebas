import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/sensor_data.dart';
import '../config.dart';

/// Service untuk komunikasi dengan Django REST API
/// API mengambil data real-time dari InfluxDB
class ApiService {
  // Base URL now comes from AppConfig (defaulted to project host)
  static final String baseUrl = AppConfig.apiBaseUrl;

  // Endpoint Django API
  static const String latestEndpoint = '/api/status/';
  static const String historyEndpoint = '/api/sensor/history/';
  static const String healthEndpoint = '/api/status/';

  /// Cek apakah API server aktif
  Future<bool> checkHealth() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl$healthEndpoint'))
          .timeout(const Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      print('❌ Health check failed: $e');
      return false;
    }
  }

  /// Mengambil data sensor terbaru dari InfluxDB via Django API
  Future<SensorData?> getLatestSensorData() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl$latestEndpoint'))
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final Map<String, dynamic> json = jsonDecode(response.body);

        print('✅ Data diterima dari API:');
        print('   Suhu: ${json['suhu']}°C');
        print('   Kelembapan: ${json['kelembapan']}%');
        print('   MQ2: ${json['mq2']}');
        print('   MQ3: ${json['mq3']}');
        print('   MQ135: ${json['mq135']}');

        // Konversi response API ke model SensorData
        return SensorData(
          temperature: _toDouble(json['suhu']),
          humidity: _toDouble(json['kelembapan']),
          mq2: _toDouble(json['mq2']),
          mq3: _toDouble(json['mq3']),
          mq135: _toDouble(json['mq135']),
          status: _determineStatusFromSensors(
            _toDouble(json['mq2']),
            _toDouble(json['mq3']),
            _toDouble(json['mq135']),
            _toDouble(json['suhu']),
            _toDouble(json['kelembapan']),
          ),
          timestamp: DateTime.now(),
        );
      } else if (response.statusCode == 204) {
        print('⚠️ Tidak ada data sensor tersedia (204)');
        return null;
      } else if (response.statusCode == 404) {
        print('⚠️ Tidak ada data sensor tersedia');
        return null;
      } else {
        print('❌ Error: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('❌ Gagal mengambil data dari API: $e');
      print('   Pastikan:');
      print('   1. Django server sedang berjalan');
      print('   2. URL API benar: $baseUrl$latestEndpoint');
      return null;
    }
  }

  /// Helper untuk konversi ke double dengan aman
  double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  /// Menentukan status berdasarkan nilai sensor
  String _determineStatusFromSensors(
    double mq2,
    double mq3,
    double mq135,
    double temp,
    double humidity,
  ) {
    // Threshold untuk menentukan kelayakan daging
    // Berdasarkan nilai sensor, jika melebihi batas = TIDAK LAYAK
    if (mq2 > 450) return 'TIDAK LAYAK';
    if (mq3 > 450) return 'TIDAK LAYAK';
    if (mq135 > 450) return 'TIDAK LAYAK';
    if (temp > 30) return 'TIDAK LAYAK';

    return 'LAYAK';
  }

  /// Mengambil history data sensor (1 jam terakhir)
  Future<List<SensorData>> getSensorHistory() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl$historyEndpoint'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        // The API returns an array of history objects. Accept both an array
        // or an object with 'data' key for backward compatibility.
        final decoded = jsonDecode(response.body);
        final List<dynamic> dataList =
            decoded is List ? decoded : (decoded['data'] ?? []);

        return dataList.map((item) {
          // item may have different keys depending on server formatting
          final tsStr = item['timestamp'] ?? item['time'] ?? '';
          DateTime ts = DateTime.now();
          try {
            ts = DateTime.parse(tsStr);
          } catch (_) {
            // fallback to now
          }

          return SensorData(
            temperature: (item['temperature'] ?? item['suhu'] ?? 0).toDouble(),
            humidity: (item['humidity'] ?? item['kelembapan'] ?? 0).toDouble(),
            mq2: (item['mq2'] ?? 0).toDouble(),
            mq3: (item['mq3'] ?? 0).toDouble(),
            mq135: (item['mq135'] ?? 0).toDouble(),
            status: _determineStatus(
              item['score'] ?? item['skorTotal'] ?? 0,
              item['status'] ?? 0,
            ),
            timestamp: ts,
          );
        }).toList();
      } else {
        print('❌ Error mengambil history: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('❌ Gagal mengambil history: $e');
      return [];
    }
  }

  /// Stream data real-time dengan auto-refresh setiap 3 detik
  Stream<SensorData> getSensorDataStream() {
    return Stream.periodic(
          const Duration(seconds: 3),
          (_) async => await getLatestSensorData(),
        )
        .asyncMap((futureData) => futureData)
        .where((data) => data != null)
        .cast<SensorData>()
        .handleError((error) {
          print('❌ Stream error: $error');
          print('   Base URL: $baseUrl');
          print('   Endpoint: $latestEndpoint');
        });
  }

  /// Menentukan status berdasarkan skorTotal atau status dari API
  String _determineStatus(dynamic skorTotal, dynamic statusCode) {
    // Jika ada status code dari API (0 = tidak layak, 1 = layak)
    if (statusCode is num) {
      // Status 1 = LAYAK, Status 0 = TIDAK LAYAK
      return statusCode == 1 ? 'LAYAK' : 'TIDAK LAYAK';
    }

    // Atau berdasarkan skor total (0-100%)
    // Skor >= 70% = LAYAK
    // Skor < 70% = TIDAK LAYAK
    if (skorTotal is num) {
      return skorTotal >= 70 ? 'LAYAK' : 'TIDAK LAYAK';
    }

    return 'TIDAK LAYAK';
  }

  /// Mendapatkan penjelasan detail status berdasarkan nilai sensor
  String getStatusExplanation(
    double mq2,
    double mq3,
    double mq135,
    double temp,
    double humidity,
  ) {
    List<String> issues = [];

    // Threshold berdasarkan research literature untuk meat spoilage detection
    const double MQ2_THRESHOLD =
        300.0; // Fresh: 200-300 ppm, Spoiled: >1000 ppm
    const double MQ3_THRESHOLD = 300.0; // Fresh: 100-300 ppm, Spoiled: >800 ppm
    const double MQ135_THRESHOLD =
        100.0; // Fresh: 30-100 ppm, Spoiled: >300 ppm
    const double TEMP_MIN = 0.0;
    const double TEMP_MAX = 10.0; // Safe refrigerated storage: 0-10°C
    const double HUMIDITY_MIN = 75.0;
    const double HUMIDITY_MAX = 90.0; // Optimal meat storage: 75-90%

    // Cek MQ2 (Gas H₂ & CH₄ dari bakteri anaerob)
    if (mq2 > 1000) {
      issues.add(
        '🔴 MQ2 SANGAT TINGGI (${mq2.toStringAsFixed(0)} ppm) - Daging spoiled!',
      );
    } else if (mq2 > MQ2_THRESHOLD) {
      issues.add(
        '⚠️ MQ2 tinggi (${mq2.toStringAsFixed(0)} ppm) - Terdeteksi gas H₂/CH₄ dari pembusukan awal',
      );
    }

    // Cek MQ3 (VOC & Alkohol dari fermentasi) - INDIKATOR KUAT
    if (mq3 > 800) {
      issues.add(
        '🔴 MQ3 SANGAT TINGGI (${mq3.toStringAsFixed(0)} ppm) - Fermentasi bakteri sangat aktif!',
      );
    } else if (mq3 > MQ3_THRESHOLD) {
      issues.add(
        '❌ MQ3 tinggi (${mq3.toStringAsFixed(0)} ppm) - Terdeteksi VOC/etanol dari fermentasi bakteri',
      );
    }

    // Cek MQ135 (Amonia dari degradasi protein)
    if (mq135 > 300) {
      issues.add(
        '🔴 MQ135 SANGAT TINGGI (${mq135.toStringAsFixed(0)} ppm) - Degradasi protein lanjut!',
      );
    } else if (mq135 > MQ135_THRESHOLD) {
      issues.add(
        '⚠️ MQ135 tinggi (${mq135.toStringAsFixed(0)} ppm) - Terdeteksi NH₃ dari protein breakdown',
      );
    }

    // Cek Suhu
    if (temp > 15) {
      issues.add(
        '🌡️ Suhu BERBAHAYA (${temp.toStringAsFixed(1)}°C) - Bakteri berkembang sangat cepat!',
      );
    } else if (temp > TEMP_MAX) {
      issues.add(
        '🌡️ Suhu tinggi (${temp.toStringAsFixed(1)}°C) - Di atas suhu penyimpanan aman (0-10°C)',
      );
    }

    // Cek Kelembapan
    if (humidity > HUMIDITY_MAX) {
      issues.add(
        '💧 Kelembapan tinggi (${humidity.toStringAsFixed(1)}%) - Risiko pertumbuhan jamur',
      );
    } else if (humidity < HUMIDITY_MIN) {
      issues.add(
        '💧 Kelembapan rendah (${humidity.toStringAsFixed(1)}%) - Daging bisa mengering',
      );
    }

    if (issues.isEmpty) {
      return '✅ Semua parameter sensor dalam batas normal. Daging layak dikonsumsi.';
    } else {
      return issues.join('\n');
    }
  }

  /// Cek apakah daging layak berdasarkan threshold
  bool isDagingLayak(
    double mq2,
    double mq3,
    double mq135,
    double temp,
    double humidity,
  ) {
    // Daging TIDAK LAYAK jika salah satu kondisi terpenuhi:
    if (mq2 > 300.0) return false; // Gas umum tinggi
    if (mq3 > 1500.0)
      return false; // Alkohol/VOC tinggi (INDIKATOR UTAMA pembusukan)
    if (mq135 > 500.0) return false; // Amonia tinggi
    if (temp > 25.0) return false; // Suhu terlalu tinggi
    if (humidity > 90.0 || humidity < 70.0)
      return false; // Kelembapan tidak ideal

    return true; // Semua parameter normal = LAYAK
  }

  /// Test koneksi API - untuk debugging
  Future<void> testConnection() async {
    print('🔍 Testing API Connection...');
    print('   Base URL: $baseUrl');

    final isHealthy = await checkHealth();
    if (isHealthy) {
      print('✅ API Server is running');

      final data = await getLatestSensorData();
      if (data != null) {
        print('✅ Successfully fetched sensor data');
        print('   Temperature: ${data.temperature}°C');
        print('   Humidity: ${data.humidity}%');
        print('   Status: ${data.status}');
      } else {
        print('⚠️ No sensor data available');
      }
    } else {
      print('❌ API Server is not responding');
      print('   Please check:');
      print('   1. Is api_server.py running?');
      print('   2. Is the URL correct?');
      print('   3. Is firewall blocking port 5000?');
    }
  }
}
