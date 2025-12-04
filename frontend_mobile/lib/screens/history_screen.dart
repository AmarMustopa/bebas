import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../providers/theme_provider.dart';
import '../services/auth_service.dart';
import '../config.dart';

/// Model untuk data riwayat per menit
class HistoryData {
  final String timestamp;
  final String status;
  final double mq2;
  final double mq3;
  final double mq135;
  final double temperature;
  final double humidity;
  final double score;

  HistoryData({
    required this.timestamp,
    required this.status,
    required this.mq2,
    required this.mq3,
    required this.mq135,
    required this.temperature,
    required this.humidity,
    required this.score,
  });

  factory HistoryData.fromJson(Map<String, dynamic> json) {
    // Parse timestamp and convert to local time (WIB = UTC+7)
    String displayTime = json['timestamp'] ?? '';
    try {
      final utcTime = DateTime.parse(displayTime);
      // Convert UTC to WIB (UTC+7)
      final wibTime = utcTime.add(const Duration(hours: 7));
      // Format as: 2025-12-03 10:40:51
      displayTime = '${wibTime.year}-${wibTime.month.toString().padLeft(2, '0')}-${wibTime.day.toString().padLeft(2, '0')} ${wibTime.hour.toString().padLeft(2, '0')}:${wibTime.minute.toString().padLeft(2, '0')}:${wibTime.second.toString().padLeft(2, '0')}';
    } catch (e) {
      print('Error parsing timestamp: $e');
    }
    
    return HistoryData(
      timestamp: displayTime,
      status: json['status'] ?? '',
      mq2: (json['mq2'] ?? 0).toDouble(),
      mq3: (json['mq3'] ?? 0).toDouble(),
      mq135: (json['mq135'] ?? 0).toDouble(),
      temperature: (json['temperature'] ?? json['suhu'] ?? 0).toDouble(),
      humidity: (json['humidity'] ?? json['kelembapan'] ?? 0).toDouble(),
      score: (json['score'] ?? 0).toDouble(),
    );
  }
}

/// Screen untuk menampilkan riwayat data per menit
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({Key? key}) : super(key: key);

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<HistoryData> _historyData = [];
  bool _isLoading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _fetchHistoryData();
  }

  Future<void> _fetchHistoryData() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final response = await http.get(
        Uri.parse('${AppConfig.apiBaseUrl}/api/history'),
      ).timeout(const Duration(seconds: 10));

      if (!mounted) return;

      if (response.statusCode == 200) {
        try {
          final Map<String, dynamic> jsonResponse = json.decode(response.body);
          
          // Validasi struktur response
          if (jsonResponse['status'] != 'success') {
            setState(() {
              _error = 'API Error: ${jsonResponse['message'] ?? 'Unknown error'}';
              _isLoading = false;
            });
            return;
          }
          
          final List<dynamic> jsonData = jsonResponse['data'] ?? [];
          
          if (jsonData.isEmpty) {
            setState(() {
              _error = 'Tidak ada data riwayat tersedia';
              _isLoading = false;
            });
            return;
          }
          
          setState(() {
            _historyData = jsonData
                .map((item) => HistoryData.fromJson(item))
                .toList();
            _isLoading = false;
          });
        } catch (parseError) {
          setState(() {
            _error = 'Parsing error: $parseError';
            _isLoading = false;
          });
        }
      } else {
        // Try to parse JSON error message from server
        String serverMsg = '';
        try {
          final Map<String, dynamic> err = json.decode(response.body);
          serverMsg = err['message'] ?? err['error'] ?? response.body;
        } catch (_) {
          serverMsg = response.body;
        }

        setState(() {
          _error = 'Gagal memuat data: ${response.statusCode} - $serverMsg';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        // Provide friendlier message for timeouts or http exceptions
        _error = e.toString().contains('TimeoutException') ? 'Request timed out. Coba lagi.' : 'Error: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    final authService = Provider.of<AuthService>(context);
    final username = authService.user?.displayName ?? 'User';
    
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(
          'Riwayat Data',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _fetchHistoryData,
            tooltip: 'Refresh',
          ),
          // Username dengan avatar di kanan
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.white.withOpacity(0.2),
                  child: const Icon(
                    Icons.person_rounded,
                    size: 20,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  username,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: _buildBody(isDark),
    );
  }

  Widget _buildBody(bool isDark) {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Memuat riwayat data...',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    if (_error.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 64,
                color: Colors.red[300],
              ),
              const SizedBox(height: 16),
              Text(
                'Gagal memuat data',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _error,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _fetchHistoryData,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
      );
    }

    if (_historyData.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history_rounded,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Belum ada riwayat data',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchHistoryData,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _historyData.length,
        itemBuilder: (context, index) {
          return _buildHistoryCard(_historyData[index], isDark);
        },
      ),
    );
  }

  Widget _buildHistoryCard(HistoryData data, bool isDark) {
    final isLayak = data.status.toLowerCase() == 'layak';
    final statusColor = isLayak ? const Color(0xFF4CAF50) : const Color(0xFFF44336);
    final borderColor = isLayak ? const Color(0xFF4CAF50) : const Color(0xFFF44336);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: borderColor,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          childrenPadding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isLayak ? Icons.check_circle_rounded : Icons.cancel_rounded,
              color: statusColor,
              size: 24,
            ),
          ),
          title: Text(
            data.timestamp,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    data.status.toUpperCase(),
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          children: [
            const Divider(),
            const SizedBox(height: 8),
            _buildSensorRow('MQ2 - Gas Umum', '${data.mq2.toStringAsFixed(0)} ppm', isDark),
            _buildSensorRow('MQ3 - Alkohol dan VOC', '${data.mq3.toStringAsFixed(0)} ppm', isDark),
            _buildSensorRow('MQ135 - Amonia dan CO₂', '${data.mq135.toStringAsFixed(0)} ppm', isDark),
            _buildSensorRow('Temperature', '${data.temperature.toStringAsFixed(1)} °C', isDark),
            _buildSensorRow('Humidity', '${data.humidity.toStringAsFixed(1)} %', isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildSensorRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: isDark ? Colors.white70 : Colors.grey[700],
            ),
          ),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
