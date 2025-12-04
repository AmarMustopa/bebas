import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../models/sensor_data.dart';
import '../auth/login_screen.dart';

/// Enhanced Dashboard Screen - Sesuai dengan tampilan web
class EnhancedDashboardScreen extends StatefulWidget {
  const EnhancedDashboardScreen({Key? key}) : super(key: key);

  @override
  State<EnhancedDashboardScreen> createState() => _EnhancedDashboardScreenState();
}

class _EnhancedDashboardScreenState extends State<EnhancedDashboardScreen> {
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _checkApiConnection();
  }

  Future<void> _checkApiConnection() async {
    try {
      final isHealthy = await _apiService.checkHealth();
      print('🔗 API Connection Status: ${isHealthy ? '✅ Connected' : '❌ Failed'}');
      print('   Base URL: ${ApiService.baseUrl}');
      
      if (!isHealthy) {
        print('   ⚠️ API might not be reachable from the device');
        print('   ⚠️ Check if phone and PC are on the same WiFi network');
      }
    } catch (e) {
      print('❌ Health check exception: $e');
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
          'Dashboard Kualitas Daging',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        actions: [
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
      body: StreamBuilder<SensorData>(
        stream: _apiService.getSensorDataStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildLoadingState();
          }

          if (snapshot.hasError) {
            return _buildErrorState(snapshot.error.toString());
          }

          if (!snapshot.hasData) {
            return _buildNoDataState();
          }

          final sensorData = snapshot.data!;
          
          return RefreshIndicator(
            onRefresh: () async {
              setState(() {});
              await Future.delayed(const Duration(seconds: 1));
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(12),
              child: _buildSensorGrid(sensorData, isDark),
            ),
          );
        },
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Logout',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
            ),
          ),
          content: Text(
            'Apakah Anda yakin ingin keluar?',
            style: GoogleFonts.poppins(),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(
                'Batal',
                style: GoogleFonts.poppins(
                  color: Colors.grey,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                // Navigate to login screen and remove all previous routes
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (context) => const LoginScreen(),
                  ),
                  (route) => false,
                );
              },
              child: Text(
                'Logout',
                style: GoogleFonts.poppins(
                  color: Colors.red,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSensorGrid(SensorData data, bool isDark) {
    // Status overall daging: 'LAYAK' atau 'TIDAK LAYAK'
    final overallStatus = data.status.toUpperCase() == 'LAYAK' ? 'Normal' : 'Danger';
    
    return Column(
      children: [
        // Baris 1: 4 cards (MQ2, MQ3, MQ135, Temperature)
        SizedBox(
          height: 180,
          child: Row(
            children: [
              Expanded(
                child: _buildSensorCard(
                  title: 'MQ2 - Gas Umum',
                  value: data.mq2.toStringAsFixed(0),
                  unit: 'ppm',
                  icon: Icons.air_rounded,
                  iconColor: const Color(0xFF2196F3),
                  status: overallStatus,
                  threshold: 600,
                  currentValue: data.mq2,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildSensorCard(
                  title: 'MQ3 - Alkohol dan VOC',
                  value: data.mq3.toStringAsFixed(0),
                  unit: 'ppm',
                  icon: Icons.science_rounded,
                  iconColor: const Color(0xFF9C27B0),
                  status: overallStatus,
                  threshold: 600,
                  currentValue: data.mq3,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildSensorCard(
                  title: 'MQ135 - Amonia dan CO₂',
                  value: data.mq135.toStringAsFixed(0),
                  unit: 'ppm',
                  icon: Icons.cloud_rounded,
                  iconColor: const Color(0xFF4CAF50),
                  status: overallStatus,
                  threshold: 200,
                  currentValue: data.mq135,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildSensorCard(
                  title: 'Temperature',
                  value: data.temperature.toStringAsFixed(1),
                  unit: '°C',
                  icon: Icons.thermostat_rounded,
                  iconColor: const Color(0xFFF44336),
                  status: overallStatus,
                  threshold: 10,
                  currentValue: data.temperature,
                  isDark: isDark,
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 8),
        
        // Baris 2: 2 cards (Humidity, Overall Status)
        SizedBox(
          height: 180,
          child: Row(
            children: [
              Expanded(
                child: _buildSensorCard(
                  title: 'Humidity',
                  value: data.humidity.toStringAsFixed(1),
                  unit: '%',
                  icon: Icons.water_drop_rounded,
                  iconColor: const Color(0xFF00BCD4),
                  status: overallStatus,
                  threshold: 90,
                  currentValue: data.humidity,
                  isDark: isDark,
                  isHumidity: true,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildOverallStatusCard(
                  status: data.status,
                  lastUpdate: 'Just now',
                  isDark: isDark,
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildThresholdItem(String sensor, String threshold, String status, Color color, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              sensor,
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: isDark ? Colors.white70 : Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              threshold,
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              status,
              style: GoogleFonts.poppins(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSensorCard({
    required String title,
    required String value,
    required String unit,
    required IconData icon,
    required Color iconColor,
    required String status,
    required double threshold,
    required double currentValue,
    required bool isDark,
    bool isHumidity = false,
  }) {
    final isNormal = status == 'Normal';
    final borderColor = isNormal ? const Color(0xFF4CAF50) : const Color(0xFFF44336);
    final statusColor = isNormal ? const Color(0xFF4CAF50) : const Color(0xFFF44336);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: borderColor,
          width: 3,
        ),
        boxShadow: [
          BoxShadow(
            color: borderColor.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon dengan background gradient
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  iconColor.withOpacity(0.2),
                  iconColor.withOpacity(0.1),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: iconColor.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(icon, color: iconColor, size: 32),
          ),
          
          const SizedBox(height: 10),
          
          // Title
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : Colors.grey[700],
              height: 1.2,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          
          const Spacer(),
          
          // Value dengan style yang lebih besar
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Text(
                  unit,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white60 : Colors.grey[600],
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildOverallStatusCard({
    required String status,
    required String lastUpdate,
    required bool isDark,
  }) {
    final isLayak = status.toLowerCase() == 'layak';
    final borderColor = isLayak ? const Color(0xFF4CAF50) : const Color(0xFFF44336);
    final statusColor = isLayak ? const Color(0xFF4CAF50) : const Color(0xFFF44336);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: borderColor,
          width: 3,
        ),
        boxShadow: [
          BoxShadow(
            color: borderColor.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon dengan gradient background yang sesuai status
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isLayak
                    ? [
                        const Color(0xFF4CAF50).withOpacity(0.2),
                        const Color(0xFF4CAF50).withOpacity(0.1),
                      ]
                    : [
                        const Color(0xFFF44336).withOpacity(0.2),
                        const Color(0xFFF44336).withOpacity(0.1),
                      ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: isLayak
                      ? const Color(0xFF4CAF50).withOpacity(0.3)
                      : const Color(0xFFF44336).withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(
              isLayak ? Icons.check_circle_rounded : Icons.cancel_rounded,
              color: isLayak ? const Color(0xFF4CAF50) : const Color(0xFFF44336),
              size: 32,
            ),
          ),
          
          const SizedBox(height: 10),
          
          // Title
          Text(
            'Overall Status',
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : Colors.grey[700],
            ),
          ),
          
          const Spacer(),
          
          // Status dengan handling yang lebih baik
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isLayak)
                Text(
                  'LAYAK',
                  style: GoogleFonts.poppins(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                    letterSpacing: 0.5,
                  ),
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TIDAK',
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                        height: 0.95,
                        letterSpacing: 0.3,
                      ),
                    ),
                    Text(
                      'LAYAK',
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                        height: 0.95,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          
          const SizedBox(height: 8),
          
          // Last Update
          Text(
            'Last update: $lastUpdate',
            style: GoogleFonts.poppins(
              fontSize: 9,
              color: isDark ? Colors.white54 : Colors.grey[600],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            'Memuat data sensor...',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
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
              error,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoDataState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.cloud_off_rounded,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Tidak ada data tersedia',
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
}
