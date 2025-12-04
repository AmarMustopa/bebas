"""
Simulasi ESP32 mengirim data sensor setiap 2 detik
untuk test apakah web realtime
"""
import requests
import time
import random

API_URL = "http://127.0.0.1:8000/api/sensor/data/"

print("=" * 60)
print("🔄 Simulasi ESP32 - Kirim Data Realtime SETIAP 1 DETIK")
print("=" * 60)
print("Tekan Ctrl+C untuk berhenti")
print("Buka http://127.0.0.1:8000/dashboard/ dan lihat data berubah!")
print()

# Nilai awal
suhu = 25.0
kelembapan = 60.0
mq2 = 300
mq3 = 1700
mq135 = 700

try:
    counter = 1
    while True:
        # Simulasi perubahan sensor (naik/turun random)
        suhu += random.uniform(-0.5, 0.5)
        kelembapan += random.uniform(-1, 1)
        mq2 += random.randint(-20, 20)
        mq3 += random.randint(-30, 30)
        mq135 += random.randint(-10, 10)
        
        # Batasi nilai
        suhu = max(20, min(35, suhu))
        kelembapan = max(50, min(90, kelembapan))
        mq2 = max(50, min(500, mq2))
        mq3 = max(1500, min(2000, mq3))
        mq135 = max(600, min(900, mq135))
        
        # Hitung status (0 = TIDAK LAYAK jika ada yang bahaya)
        status = 0 if (mq3 > 1500 or mq135 > 900 or suhu > 30) else 1
        
        sensor_data = {
            "suhu": round(suhu, 1),
            "kelembapan": round(kelembapan, 1),
            "mq135": int(mq135),
            "mq3": int(mq3),
            "mq2": int(mq2),
            "skorTotal": round(random.uniform(45, 55), 2),
            "status": status
        }
        
        print(f"[{counter}] Kirim: Suhu={sensor_data['suhu']}°C, "
              f"RH={sensor_data['kelembapan']}%, MQ2={sensor_data['mq2']}, "
              f"MQ3={sensor_data['mq3']}, MQ135={sensor_data['mq135']}, "
              f"Status={'LAYAK' if status==1 else 'TIDAK LAYAK'}")
        
        try:
            response = requests.post(API_URL, json=sensor_data, timeout=2)
            if response.status_code == 200:
                print(f"     ✅ Data terkirim")
            else:
                print(f"     ❌ Error: {response.status_code}")
        except Exception as e:
            print(f"     ❌ Gagal: {e}")
        
        counter += 1
        time.sleep(1)  # Kirim setiap 1 detik
        
except KeyboardInterrupt:
    print("\n⏹️ Simulasi dihentikan")
    print("👋 Selesai!")
