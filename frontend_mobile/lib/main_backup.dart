import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'firebase_options.dart';
import 'services/notification_service.dart';

// Global API Configuration - dapat diubah dari Settings
String API_BASE_URL = 'http://172.20.10.3:5000';  // Default Flask API server

// List of possible API server addresses to try (IN ORDER)
const List<String> POSSIBLE_API_URLS = [
  'http://172.20.10.3:5000',        // Primary - Direct PC IP
  'http://192.168.218.1:5000',      // VirtualBox host-only network
  'http://192.168.130.1:5000',      // Second adapter
  'http://192.168.56.1:5000',       // VMware adapter
  'http://10.0.2.2:5000',           // Android emulator host
  'http://localhost:5000',           // Fallback localhost
];

// Function untuk auto-discover API server dengan timeout yang lebih ketat
Future<String> discoverAPIServer() async {
  print('🔍 Discovering Flask API server...');
  print('🔹 Trying ${POSSIBLE_API_URLS.length} possible URLs');
  
  // First try: parallel pings to health endpoint
  for (int i = 0; i < POSSIBLE_API_URLS.length; i++) {
    String url = POSSIBLE_API_URLS[i];
    try {
      print('   ➜ Attempt ${i+1}/${POSSIBLE_API_URLS.length}: $url/health');
      final response = await http.get(
        Uri.parse('$url/health'),
      ).timeout(const Duration(seconds: 3));
      
      if (response.statusCode == 200) {
        print('✅ FOUND API server at: $url');
        return url;
      }
    } catch (e) {
      // Continue silently if this URL fails
      continue;
    }
  }
  
  // If auto-discovery fails, use first (primary) default
  print('⚠️ No API server discovered, using PRIMARY default: ${POSSIBLE_API_URLS[0]}');
  return POSSIBLE_API_URLS[0];
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  print('🚀 App starting...');

  // Initialize Firebase with error handling AND TIMEOUT
  try {
    print('📱 Initializing Firebase...');
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      ).timeout(const Duration(seconds: 15));
      print('✅ Firebase initialized');
    } on TimeoutException {
      print('⚠️ Firebase init TIMEOUT - continuing without Firebase');
    }

    try {
      FirebaseFirestore.instance.settings =
          const Settings(persistenceEnabled: false);
      print('✅ Firestore configured');
    } catch (e) {
      print('⚠️ Firestore config error: $e');
    }

    try {
      await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
      print('✅ Auth persistence enabled');
    } catch (e) {
      print('⚠️ Auth persistence error: $e');
    }
  } catch (e) {
    print('⚠️ Firebase initialization warning: $e');
  }

  // Initialize notifications with error handling
  try {
    print('📲 Initializing notifications...');
    await NotificationService().initialize();
    print('✅ Notifications initialized');
  } catch (e) {
    print('⚠️ Notification initialization warning: $e');
  }

  // Auto-discover API server
  print('🔌 AUTO-DISCOVERING API SERVER...');
  API_BASE_URL = await discoverAPIServer();
  print('✅ FINAL API_BASE_URL SET TO: $API_BASE_URL');
  print('📍 This URL will be used for all API calls');

  print('🎯 Running app...');
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Meat Freshness Monitor',
      theme: ThemeData(
        primarySwatch: Colors.green,
        useMaterial3: true,
      ),
      home: const LoginScreenSimple(),
      debugShowCheckedModeBanner: false,
    );
  }
}

/// Login Screen
class LoginScreenSimple extends StatefulWidget {
  const LoginScreenSimple({Key? key}) : super(key: key);

  @override
  State<LoginScreenSimple> createState() => _LoginScreenSimpleState();
}

class _LoginScreenSimpleState extends State<LoginScreenSimple> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String _errorMessage = '';
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _login() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _errorMessage = 'Email dan Password tidak boleh kosong';
        _isLoading = false;
      });
      return;
    }

    if (password.length < 6) {
      setState(() {
        _errorMessage = 'Password minimal 6 karakter';
        _isLoading = false;
      });
      return;
    }

    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => HomeScreen(userEmail: email),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('🥩 Meat Freshness Monitor'),
        backgroundColor: Colors.green,
        centerTitle: true,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              Center(
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.local_dining_rounded,
                        size: 64,
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Login',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Monitor Kesegaran Daging Real-time',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              if (_errorMessage.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    border: Border.all(color: Colors.red, width: 1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _errorMessage,
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ),
              const SizedBox(height: 16),
              TextField(
                controller: _emailController,
                enabled: !_isLoading,
                decoration: InputDecoration(
                  labelText: 'Email',
                  prefixIcon: const Icon(Icons.email_rounded, color: Colors.green),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.grey),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.green, width: 2),
                  ),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                enabled: !_isLoading,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_rounded, color: Colors.green),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_off : Icons.visibility,
                      color: Colors.green,
                    ),
                    onPressed: () {
                      setState(() => _obscurePassword = !_obscurePassword);
                    },
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.grey),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.green, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _login,
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : const Icon(Icons.login_rounded),
                label: Text(_isLoading ? 'Loading...' : 'Login'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  border: Border.all(color: Colors.blue, width: 1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '📝 Demo Login:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Email: demo@smartfruit.com',
                      style: TextStyle(fontSize: 11, color: Colors.blue),
                    ),
                    Text(
                      'Password: demo123456',
                      style: TextStyle(fontSize: 11, color: Colors.blue),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Main Home Screen dengan Tab Navigation
class HomeScreen extends StatefulWidget {
  final String userEmail;
  const HomeScreen({Key? key, required this.userEmail}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  void _logout() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const LoginScreenSimple()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      DashboardTab(userEmail: widget.userEmail),
      HistoryTab(userEmail: widget.userEmail),
      ProfileTab(userEmail: widget.userEmail, onLogout: _logout),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('🥩 Meat Freshness Monitor'),
        backgroundColor: Colors.green,
        centerTitle: true,
        elevation: 0,
      ),
      body: screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        backgroundColor: Colors.white,
        selectedItemColor: Colors.green,
        unselectedItemColor: Colors.grey,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_rounded),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history_rounded),
            label: 'Riwayat',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_rounded),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}

/// Dashboard Tab - Menampilkan data sensor real-time
class DashboardTab extends StatefulWidget {
  final String userEmail;
  const DashboardTab({Key? key, required this.userEmail}) : super(key: key);

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  late Future<Map<String, dynamic>> _sensorDataFuture;

  @override
  void initState() {
    super.initState();
    _sensorDataFuture = _fetchSensorData();
    // Auto-refresh setiap 10 detik
    Future.delayed(const Duration(seconds: 10), () {
      if (mounted) {
        setState(() {
          _sensorDataFuture = _fetchSensorData();
        });
      }
    });
  }

  Future<Map<String, dynamic>> _fetchSensorData() async {
    print('🔄 Fetching sensor data from: $API_BASE_URL/sensor/latest');
    
    // Retry logic untuk handle timeout
    int maxRetries = 3;
    for (int i = 0; i < maxRetries; i++) {
      try {
        final response = await http.get(
          Uri.parse('$API_BASE_URL/sensor/latest'),
        ).timeout(const Duration(seconds: 25));

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          print('✅ Sensor data received: $data');
          
          // Add status berdasarkan suhu
          final suhu = _parseDouble(data['suhu'] ?? data['temperature'] ?? 0);
          final status = _getStatus(suhu);
          data['status'] = status;
          
          return data;
        } else {
          throw Exception('HTTP ${response.statusCode}');
        }
      } on TimeoutException catch (e) {
        print('⏱️ Timeout attempt ${i+1}/$maxRetries: $e');
        if (i < maxRetries - 1) {
          await Future.delayed(const Duration(seconds: 2));
          continue;
        } else {
          return {'error': 'TimeoutException: Server tidak merespons'};
        }
      } catch (e) {
        print('❌ Error attempt ${i+1}/$maxRetries: $e');
        if (i < maxRetries - 1) {
          await Future.delayed(const Duration(seconds: 1));
          continue;
        } else {
          return {'error': 'Error: $e'};
        }
      }
    }
    
    return {'error': 'Gagal mengambil data setelah $maxRetries percobaan'};
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _sensorDataFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: Colors.green),
                SizedBox(height: 16),
                Text('Loading data sensor...'),
              ],
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: ${snapshot.error}', textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _sensorDataFuture = _fetchSensorData();
                      });
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Coba Lagi'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final data = snapshot.data ?? {};
        final status = data['status'] ?? 'Unknown';
        final temperature = (data['temperature'] ?? data['suhu'] ?? 0.0).toStringAsFixed(1);
        final humidity = (data['humidity'] ?? data['kelembapan'] ?? 0.0).toStringAsFixed(1);
        final mq2 = (data['mq2'] ?? 0.0).toStringAsFixed(0);
        final mq3 = (data['mq3'] ?? 0.0).toStringAsFixed(0);
        final mq135 = (data['mq135'] ?? 0.0).toStringAsFixed(0);

        final isGood = status.toLowerCase() == 'layak';
        final statusColor = isGood ? Colors.green : Colors.red;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User Info
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  border: Border.all(color: Colors.green),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.account_circle, size: 48, color: Colors.green),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Selamat Datang',
                            style: TextStyle(fontSize: 12, color: Colors.grey)),
                        Text(widget.userEmail,
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.green)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              
              // Status Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  border: Border.all(color: statusColor, width: 2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Icon(
                      isGood ? Icons.check_circle : Icons.cancel,
                      size: 64,
                      color: statusColor,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Status: $status',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              
              // Environmental Sensors
              const Text('Sensor Lingkungan',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child:
                        _sensorCard('🌡️ Suhu', '$temperature °C', Colors.orange),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _sensorCard('💧 Kelembapan', '$humidity %', Colors.blue),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              
              // Gas Sensors
              const Text('Sensor Gas (ppm)',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Column(
                children: [
                  _sensorCard('Gas Umum (MQ2)', '$mq2 ppm', Colors.purple),
                  const SizedBox(height: 12),
                  _sensorCard('Alkohol/VOC (MQ3)', '$mq3 ppm', Colors.indigo),
                  const SizedBox(height: 12),
                  _sensorCard('Amonia/CO₂ (MQ135)', '$mq135 ppm', Colors.teal),
                ],
              ),
              const SizedBox(height: 20),
              
              // Refresh Button
              Center(
                child: ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _sensorDataFuture = _fetchSensorData();
                    });
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh Data'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _sensorCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        border: Border.all(color: color, width: 1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 14, color: Colors.grey)),
          const SizedBox(height: 8),
          Text(value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              )),
        ],
      ),
    );
  }

  double _parseDouble(dynamic value) {
    try {
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) return double.parse(value);
      return 0.0;
    } catch (e) {
      return 0.0;
    }
  }

  String _getStatus(double suhu) {
    // Status berdasarkan suhu
    // > 25°C = Tidak Layak (Busuk)
    // < 25°C = Layak (Segar)
    if (suhu > 25.0) {
      return 'Tidak Layak';
    } else {
      return 'Layak';
    }
  }
}

/// History Tab - Menampilkan riwayat data sensor
class HistoryTab extends StatefulWidget {
  final String userEmail;
  const HistoryTab({Key? key, required this.userEmail}) : super(key: key);

  @override
  State<HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<HistoryTab> {
  late Future<List<Map<String, dynamic>>> _historyFuture;

  @override
  void initState() {
    super.initState();
    _historyFuture = _fetchHistory();
  }

  Future<List<Map<String, dynamic>>> _fetchHistory() async {
    print('🔄 Fetching history from: $API_BASE_URL/api/history');
    
    // Retry logic untuk handle timeout
    int maxRetries = 3;
    for (int i = 0; i < maxRetries; i++) {
      try {
        final response = await http.get(
          Uri.parse('$API_BASE_URL/api/history?limit=100'),
        ).timeout(const Duration(seconds: 25));

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          print('✅ History data received');
          
          if (data is List) {
            return List<Map<String, dynamic>>.from(data);
          } else if (data is Map && data.containsKey('data')) {
            return List<Map<String, dynamic>>.from(data['data']);
          }
          return [];
        }
        throw Exception('HTTP ${response.statusCode}');
      } on TimeoutException catch (e) {
        print('⏱️ Timeout attempt ${i+1}/$maxRetries: $e');
        if (i < maxRetries - 1) {
          await Future.delayed(const Duration(seconds: 2));
          continue;
        } else {
          print('❌ Failed to load history after $maxRetries retries');
          return [];
        }
      } catch (e) {
        print('❌ Error attempt ${i+1}/$maxRetries: $e');
        if (i < maxRetries - 1) {
          await Future.delayed(const Duration(seconds: 1));
          continue;
        } else {
          print('❌ Failed to load history: $e');
          return [];
        }
      }
    }
    return [];
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _historyFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: Colors.green),
                SizedBox(height: 16),
                Text('Loading riwayat data...'),
              ],
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: ${snapshot.error}', textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _historyFuture = _fetchHistory();
                      });
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Coba Lagi'),
                  ),
                ],
              ),
            ),
          );
        }

        final history = snapshot.data ?? [];

        if (history.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.history_rounded, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('Belum ada data riwayat'),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _historyFuture = _fetchHistory();
                      });
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh'),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: history.length,
          itemBuilder: (context, index) {
            final item = history[index];
            final timestamp = item['timestamp'] ?? item['time'] ?? 'N/A';
            final status = item['status'] ?? 'Unknown';
            final temp = (item['temperature'] ?? item['suhu'] ?? 0.0)
                .toString()
                .substring(0, 4);
            final humidity = (item['humidity'] ?? item['kelembapan'] ?? 0.0)
                .toString()
                .substring(0, 4);

            final isGood = status.toLowerCase() == 'layak';
            final statusColor = isGood ? Colors.green : Colors.red;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.05),
                border: Border.all(color: statusColor.withOpacity(0.3)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    isGood ? Icons.check_circle : Icons.cancel,
                    color: statusColor,
                    size: 32,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Status: $status',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Suhu: $temp°C | Kelembapan: $humidity%',
                          style:
                              const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        Text(
                          timestamp,
                          style:
                              const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

/// Profile Tab
class ProfileTab extends StatefulWidget {
  final String userEmail;
  final VoidCallback onLogout;

  const ProfileTab({
    Key? key,
    required this.userEmail,
    required this.onLogout,
  }) : super(key: key);

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  late TextEditingController _apiUrlController;

  @override
  void initState() {
    super.initState();
    _apiUrlController = TextEditingController(text: API_BASE_URL);
  }

  @override
  void dispose() {
    _apiUrlController.dispose();
    super.dispose();
  }

  void _updateApiUrl() {
    final newUrl = _apiUrlController.text.trim();
    if (newUrl.isNotEmpty) {
      setState(() {
        API_BASE_URL = newUrl;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('API URL diperbarui ke: $newUrl'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              border: Border.all(color: Colors.green),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.account_circle,
                      size: 48, color: Colors.white),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Pengguna Terdaftar',
                          style: TextStyle(fontSize: 12, color: Colors.grey)),
                      Text(widget.userEmail,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      const Text('Status: Aktif',
                          style: TextStyle(fontSize: 12, color: Colors.green)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // API Settings Section
          const Text('Pengaturan API',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.05),
              border: Border.all(color: Colors.blue.withOpacity(0.3)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'URL API Server',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _apiUrlController,
                  decoration: InputDecoration(
                    hintText: 'Contoh: http://192.168.1.100:5000',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    prefixIcon: const Icon(Icons.link, color: Colors.blue),
                  ),
                  keyboardType: TextInputType.url,
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _updateApiUrl,
                    icon: const Icon(Icons.save),
                    label: const Text('Simpan URL API'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    '💡 Jika app tidak bisa connect ke API, coba ubah IP address sesuai dengan PC Anda. Contoh: http://192.168.x.x:5000',
                    style: TextStyle(fontSize: 11, color: Colors.amber),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Other Settings Section
          const Text('Pengaturan Lainnya',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.05),
              border: Border.all(color: Colors.grey.withOpacity(0.3)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Meat Freshness Monitor',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                Text('Versi: 1.0.0',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
                SizedBox(height: 4),
                Text('Status: Production',
                    style: TextStyle(fontSize: 12, color: Colors.green)),
                SizedBox(height: 8),
                Text(
                  'Aplikasi untuk monitoring kesegaran daging secara real-time menggunakan sensor IoT.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Logout Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: widget.onLogout,
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Logout'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
