import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/sensor_data.dart';
import '../providers/theme_provider.dart';

/// Widget untuk membandingkan kondisi saat ini dengan daging segar ideal
class FreshnessComparisonWidget extends StatelessWidget {
  final SensorData sensorData;

  const FreshnessComparisonWidget({Key? key, required this.sensorData}) : super(key: key);

  // Nilai ideal daging segar (referensi)
  static const Map<String, double> _idealValues = {
    'mq2': 150.0,
    'mq3': 150.0,
    'mq135': 50.0,
    'temperature': 5.0,
    'humidity': 82.5,
  };

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildComparisonRow(
            'MQ2 (Gas)',
            sensorData.mq2,
            _idealValues['mq2']!,
            'ppm',
            isDark,
          ),
          const Divider(height: 24),
          _buildComparisonRow(
            'MQ3 (Alkohol)',
            sensorData.mq3,
            _idealValues['mq3']!,
            'ppm',
            isDark,
          ),
          const Divider(height: 24),
          _buildComparisonRow(
            'MQ135 (NH3)',
            sensorData.mq135,
            _idealValues['mq135']!,
            'ppm',
            isDark,
          ),
          const Divider(height: 24),
          _buildComparisonRow(
            'Suhu',
            sensorData.temperature,
            _idealValues['temperature']!,
            '°C',
            isDark,
          ),
          const Divider(height: 24),
          _buildComparisonRow(
            'Kelembapan',
            sensorData.humidity,
            _idealValues['humidity']!,
            '%',
            isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonRow(
    String label,
    double currentValue,
    double idealValue,
    String unit,
    bool isDark,
  ) {
    final difference = currentValue - idealValue;
    final percentageDiff = (difference / idealValue * 100).abs();
    final isGood = percentageDiff < 20; // Toleransi 20%
    
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ),
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Saat Ini: ${currentValue.toStringAsFixed(1)} $unit',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: isDark ? Colors.white70 : Colors.grey[700],
                    ),
                  ),
                  Icon(
                    isGood ? Icons.check_circle : Icons.info,
                    size: 16,
                    color: isGood ? Colors.green : Colors.orange,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Ideal: ${idealValue.toStringAsFixed(1)} $unit',
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  color: isDark ? Colors.white54 : Colors.grey[500],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
