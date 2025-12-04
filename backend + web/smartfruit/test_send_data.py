"""
Script untuk mengirim data sensor dummy ke API Django
"""
import requests
import json
import time

# API endpoint
API_URL = "http://127.0.0.1:8000/api/sensor/data/"

# Data sensor dari MQTT Anda (data asli, bukan dummy)
sensor_data = {
    "suhu": 30.8,
    "kelembapan": 85.1,
    "mq135": 239,
    "mq3": 1657,
    "mq2": 97,
    "skorGas": 35.12,
    "skorSuhu": 83.5,
    "skorRH": 49.8,
    "skorTotal": 52.57,
    "status": 0
}

print("=" * 60)
print("🚀 Mengirim data sensor ke API Django")
print("=" * 60)
print(f"📡 Endpoint: {API_URL}")
print(f"📊 Data: {json.dumps(sensor_data, indent=2)}")
print()

try:
    # Kirim data via POST
    response = requests.post(
        API_URL,
        json=sensor_data,
        headers={"Content-Type": "application/json"},
        timeout=5
    )
    
    print(f"✅ Response Status: {response.status_code}")
    print(f"📥 Response: {response.json()}")
    
    if response.status_code == 200:
        print("\n✅ Data berhasil dikirim!")
        print("🔄 Coba refresh dashboard Anda dalam beberapa detik...")
    else:
        print(f"\n❌ Gagal mengirim data: {response.text}")
        
except requests.exceptions.ConnectionError:
    print("❌ Tidak dapat terhubung ke server. Pastikan Django server sedang berjalan.")
except Exception as e:
    print(f"❌ Error: {e}")

print("\n" + "=" * 60)
