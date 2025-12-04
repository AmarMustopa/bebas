import time
import requests
import random

# URL endpoint Django API yang menerima data sensor
API_URL = "http://127.0.0.1:8000/api/sensor/"  # sesuaikan dengan endpoint kamu

while True:
    # Simulasikan data sensor
    temperature = round(random.uniform(24.0, 32.0), 2)
    humidity = round(random.uniform(50.0, 90.0), 2)
    
    data = {
        "temperature": temperature,
        "humidity": humidity,
    }

    try:
        response = requests.post(API_URL, json=data)

        # Log hasil pengiriman
        if response.status_code == 200:
            print(f"Data terkirim: {data} | Status: {response.status_code}")
        else:
            print(f"Data terkirim: {data} | Status: {response.status_code}")
    except Exception as e:
        print("Gagal mengirim data:", e)

    # Kirim data setiap 5 detik
    time.sleep(5)
