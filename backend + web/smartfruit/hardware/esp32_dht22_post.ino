// ESP32 + DHT22 + HTTP POST ke Django
// Library: DHT sensor library by Adafruit, HTTPClient (bawaan ESP32)
#include <WiFi.h>
#include <HTTPClient.h>
#include "DHT.h"

#define DHTPIN 4      // Pin data DHT22 ke GPIO4
#define DHTTYPE DHT22

const char* ssid = "NAMA_WIFI";
const char* password = "PASSWORD_WIFI";
const char* serverName = "http://<IP_BACKEND>:8000/api/sensor/";

DHT dht(DHTPIN, DHTTYPE);

void setup() {
  Serial.begin(115200);
  WiFi.begin(ssid, password);
  while (WiFi.status() != WL_CONNECTED) {
    delay(1000);
    Serial.println("Connecting to WiFi...");
  }
  Serial.println("Connected!");
  dht.begin();
}

void loop() {
  float h = dht.readHumidity();
  float t = dht.readTemperature();
  float gas = 0.1; // Ganti jika ada sensor gas

  if (!isnan(h) && !isnan(t)) {
    if (WiFi.status() == WL_CONNECTED) {
      HTTPClient http;
      http.begin(serverName);
      http.addHeader("Content-Type", "application/json");
      String postData = "{\"temperature\": " + String(t, 2) + ", \"humidity\": " + String(h, 2) + ", \"gas\": " + String(gas, 2) + "}";
      int httpResponseCode = http.POST(postData);
      Serial.print("HTTP Response code: ");
      Serial.println(httpResponseCode);
      http.end();
    }
  }
  delay(10000); // Kirim data tiap 10 detik
}
