import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import '../models/sensor_data.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  FirebaseMessaging? _messaging;

  Future<void> initialize() async {
    // Lazily obtain the instance so we don't trigger platform calls before Firebase is initialized
    _messaging ??= FirebaseMessaging.instance;

    // Request permission
    NotificationSettings settings = await _messaging!.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('User granted permission');
    }

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Got a message whilst in the foreground!');
      print('Message data: ${message.data}');
      if (message.notification != null) {
        print('Message also contained a notification: ${message.notification}');
      }
    });
  }

  void checkAndSendNotifications(SensorData data, BuildContext context) {
    List<String> alerts = [];

    // Logika baru: hanya cek kesegaran daging
    if (!data.isMeatFresh) {
      alerts.add(data.freshnessRecommendation);
    }

    // Tampilkan notifikasi lokal (contoh pakai SnackBar)
    if (alerts.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: alerts.map((alert) => Text('⚠️ $alert')).toList(),
          ),
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }
}
