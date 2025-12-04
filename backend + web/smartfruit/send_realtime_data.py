"""
Script untuk mengirim data sensor secara realtime ke API Django
Simulasi ESP32 mengirim data setiap 10 detik
"""
import requests
import json
import time
import random

# API endpoint - sesuaikan dengan IP server Django Anda
API_URL = "http://127.0.0.1:8000/api/sensor/data/"

def send_sensor_data():
    """Kirim data sensor ke API Django"""
    
    # Data sensor dari MQTT Anda dengan sedikit variasi random
    sensor_data = {
        "suhu": round(30.8 + random.uniform(-0.5, 0.5), 2),
        "kelembapan": round(85.1 + random.uniform(-1, 1), 2),
        "mq135": int(239 + random.uniform(-10, 10)),
        "mq3": int(1657 + random.uniform(-50, 50)),
        "mq2": int(97 + random.uniform(-5, 5)),
        "skorGas": round(35.12 + random.uniform(-2, 2), 2),
        "skorSuhu": round(83.5 + random.uniform(-1, 1), 2),
        "skorRH": round(49.8 + random.uniform(-2, 2), 2),
        "skorTotal": round(52.57 + random.uniform(-1, 1), 2),
        "status": 0  # 0 = TIDAK LAYAK, 1 = LAYAK
    }
    
    try:
        response = requests.post(
            API_URL,
            json=sensor_data,
            headers={"Content-Type": "application/json"},
            timeout=5
        )
        
        if response.status_code == 200:
            print(f"✅ [{time.strftime('%H:%M:%S')}] Data terkirim: Suhu={sensor_data['suhu']}°C, MQ3={sensor_data['mq3']}, Status={sensor_data['status']}")
        else:
            print(f"❌ [{time.strftime('%H:%M:%S')}] Gagal: {response.status_code}")
            
    except requests.exceptions.ConnectionError:
        print(f"❌ [{time.strftime('%H:%M:%S')}] Server tidak terhubung. Pastikan Django server berjalan.")
    except Exception as e:
        print(f"❌ [{time.strftime('%H:%M:%S')}] Error: {e}")

def main():
    print("=" * 70)
    print("🚀 REALTIME DATA SENDER - Simulasi ESP32")
    print("=" * 70)
    print(f"📡 Endpoint: {API_URL}")
    print(f"⏱️  Interval: 10 detik")
    print(f"📊 Data berdasarkan MQTT Anda dengan variasi random")
    print("=" * 70)
    print("\n🔄 Mengirim data realtime... (Tekan Ctrl+C untuk stop)\n")
    
    try:
        while True:
            send_sensor_data()
            time.sleep(10)  # Kirim setiap 10 detik
            
    except KeyboardInterrupt:
        print("\n\n⏹️  Stopped by user")
        print("👋 Goodbye!\n")

if __name__ == "__main__":
    main()
