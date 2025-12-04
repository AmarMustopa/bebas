/*
 * ESP32 Sensor Monitoring - Realtime ke InfluxDB via Django API
 * 
 * Sensor yang dipakai:
 * - DHT22 (Suhu & Kelembapan) -> Pin GPIO 4
 * - MQ2 (Gas Umum) -> Pin GPIO 34 (ADC1_CH6)
 * - MQ3 (Alkohol/VOC) -> Pin GPIO 35 (ADC1_CH7)
 * - MQ135 (Amonia/CO2) -> Pin GPIO 32 (ADC1_CH4)
 * 
 * Data dikirim setiap 1 detik ke server Django
 */

#include <WiFi.h>
#include <HTTPClient.h>
#include <DHT.h>
#include <ArduinoJson.h>

// ===== KONFIGURASI WIFI =====
const char* ssid = "GANTI_DENGAN_WIFI_ANDA";      // Nama WiFi
const char* password = "GANTI_PASSWORD_WIFI";     // Password WiFi

// ===== KONFIGURASI SERVER =====
const char* serverUrl = "http://103.151.63.80:8000/api/sensor/data/";

// ===== KONFIGURASI SENSOR =====
#define DHTPIN 4           // Pin DHT22
#define DHTTYPE DHT22      // Tipe sensor DHT

#define MQ2_PIN 34         // Pin analog MQ2
#define MQ3_PIN 35         // Pin analog MQ3
#define MQ135_PIN 32       // Pin analog MQ135

DHT dht(DHTPIN, DHTTYPE);

// ===== INTERVAL PENGIRIMAN =====
unsigned long lastSendTime = 0;
const unsigned long sendInterval = 1000; // Kirim setiap 1 detik (1000 ms)

void setup() {
  Serial.begin(115200);
  Serial.println("\n\n");
  Serial.println("====================================");
  Serial.println("  ESP32 Smart Beef Monitoring");
  Serial.println("====================================");
  
  // Init sensor DHT22
  dht.begin();
  Serial.println("✓ DHT22 initialized");
  
  // Init WiFi
  Serial.print("Connecting to WiFi: ");
  Serial.println(ssid);
  WiFi.begin(ssid, password);
  
  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 30) {
    delay(500);
    Serial.print(".");
    attempts++;
  }
  
  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("\n✓ WiFi Connected!");
    Serial.print("IP Address: ");
    Serial.println(WiFi.localIP());
  } else {
    Serial.println("\n✗ WiFi connection failed!");
  }
  
  Serial.println("====================================");
  Serial.println("System ready. Sending data every 1 second...");
  Serial.println();
}

void loop() {
  // Cek apakah sudah waktunya kirim data
  if (millis() - lastSendTime >= sendInterval) {
    lastSendTime = millis();
    
    // Baca sensor DHT22
    float suhu = dht.readTemperature();
    float kelembapan = dht.readHumidity();
    
    // Cek apakah pembacaan DHT22 valid
    if (isnan(suhu) || isnan(kelembapan)) {
      Serial.println("✗ DHT22 read error!");
      suhu = 0;
      kelembapan = 0;
    }
    
    // Baca sensor MQ (analog ADC 0-4095)
    int mq2_raw = analogRead(MQ2_PIN);
    int mq3_raw = analogRead(MQ3_PIN);
    int mq135_raw = analogRead(MQ135_PIN);
    
    // Konversi ADC ke PPM (sesuaikan dengan kalibrasi sensor Anda)
    // Ini adalah contoh konversi sederhana, sesuaikan dengan datasheet sensor
    int mq2 = map(mq2_raw, 0, 4095, 0, 1000);
    int mq3 = map(mq3_raw, 0, 4095, 1000, 2000);
    int mq135 = map(mq135_raw, 0, 4095, 0, 1000);
    
    // Hitung status (0 = TIDAK LAYAK, 1 = LAYAK)
    // Threshold: MQ3 > 1500, MQ135 > 900, Suhu > 30 = TIDAK LAYAK
    int status = (mq3 > 1500 || mq135 > 900 || suhu > 30) ? 0 : 1;
    
    // Hitung skor (contoh sederhana)
    float skorGas = 100 - ((mq2 + mq3 + mq135) / 30.0);
    float skorSuhu = (suhu < 30) ? 100 - (suhu * 2) : 50;
    float skorRH = (kelembapan > 50 && kelembapan < 80) ? 90 : 50;
    float skorTotal = (skorGas + skorSuhu + skorRH) / 3.0;
    
    // Tampilkan di Serial Monitor
    Serial.println("─────────────────────────────────");
    Serial.print("Suhu: "); Serial.print(suhu); Serial.println(" °C");
    Serial.print("Kelembapan: "); Serial.print(kelembapan); Serial.println(" %");
    Serial.print("MQ2: "); Serial.print(mq2); Serial.println(" ppm");
    Serial.print("MQ3: "); Serial.print(mq3); Serial.println(" ppm");
    Serial.print("MQ135: "); Serial.print(mq135); Serial.println(" ppm");
    Serial.print("Status: "); Serial.println(status == 1 ? "LAYAK" : "TIDAK LAYAK");
    Serial.print("Skor Total: "); Serial.println(skorTotal);
    
    // Kirim data ke server jika WiFi terhubung
    if (WiFi.status() == WL_CONNECTED) {
      HTTPClient http;
      
      // Buat JSON payload
      StaticJsonDocument<300> doc;
      doc["suhu"] = suhu;
      doc["kelembapan"] = kelembapan;
      doc["mq2"] = mq2;
      doc["mq3"] = mq3;
      doc["mq135"] = mq135;
      doc["skorGas"] = skorGas;
      doc["skorSuhu"] = skorSuhu;
      doc["skorRH"] = skorRH;
      doc["skorTotal"] = skorTotal;
      doc["status"] = status;
      
      String jsonData;
      serializeJson(doc, jsonData);
      
      // Kirim HTTP POST
      http.begin(serverUrl);
      http.addHeader("Content-Type", "application/json");
      
      int httpCode = http.POST(jsonData);
      
      if (httpCode == 200) {
        Serial.println("✓ Data sent successfully!");
      } else {
        Serial.print("✗ HTTP Error: ");
        Serial.println(httpCode);
      }
      
      http.end();
    } else {
      Serial.println("✗ WiFi disconnected. Reconnecting...");
      WiFi.reconnect();
    }
    
    Serial.println();
  }
}
