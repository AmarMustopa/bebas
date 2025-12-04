import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/sensor_data.dart';
import '../providers/theme_provider.dart';

/// Widget untuk menampilkan prediksi AI dan scoring
class AIPredictionCard extends StatelessWidget {
  final SensorData sensorData;

  const AIPredictionCard({Key? key, required this.sensorData}) : super(key: key);

  String get _getFreshnessLevel {
    final score = sensorData.skorTotal;
    if (score >= 85) return 'Sangat Segar';
    if (score >= 70) return 'Segar';
    if (score >= 50) return 'Cukup';
    if (score >= 30) return 'Kurang Segar';
    return 'Tidak Segar';
  }

  Color get _getFreshnessColor {
    final score = sensorData.skorTotal;
    if (score >= 85) return const Color(0xFF2E7D32);
    if (score >= 70) return const Color(0xFF66BB6A);
    if (score >= 50) return const Color(0xFFFFA726);
    if (score >= 30) return const Color(0xFFFF7043);
    return const Color(0xFFE53935);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1A237E), const Color(0xFF283593)]
              : [const Color(0xFF1976D2), const Color(0xFF42A5F5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.psychology_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'AI Prediction',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Freshness Level
          Text(
            'Tingkat Kesegaran',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _getFreshnessLevel,
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Progress Bar
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Skor Kualitas',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.white70,
                    ),
                  ),
                  Text(
                    '${sensorData.skorTotal.toStringAsFixed(1)}%',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: sensorData.skorTotal / 100),
                  duration: const Duration(milliseconds: 1000),
                  builder: (context, value, child) {
                    return LinearProgressIndicator(
                      value: value,
                      minHeight: 8,
                      backgroundColor: Colors.white.withOpacity(0.3),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _getFreshnessColor,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Component Scores
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildComponentScore(
                'Gas',
                sensorData.skorGas.toStringAsFixed(0),
                '50%',
                Colors.white70,
              ),
              _buildComponentScore(
                'Suhu',
                sensorData.skorSuhu.toStringAsFixed(0),
                '30%',
                Colors.white70,
              ),
              _buildComponentScore(
                'RH',
                sensorData.skorRH.toStringAsFixed(0),
                '20%',
                Colors.white70,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildComponentScore(
    String label,
    String score,
    String weight,
    Color color,
  ) {
    return Column(
      children: [
        Text(
          score,
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 11,
            color: color,
          ),
        ),
        Text(
          weight,
          style: GoogleFonts.poppins(
            fontSize: 10,
            color: color.withOpacity(0.7),
          ),
        ),
      ],
    );
  }
}
