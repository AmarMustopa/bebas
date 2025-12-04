import requests
import random
import time

URL = "http://127.0.0.1:8000/api/sensor/"

while True:
    data = {
        "temperature": round(random.uniform(24, 32), 2),
        "humidity": round(random.uniform(55, 85), 2),
        "gas": round(random.uniform(0.05, 0.2), 3)
    }
    try:
        r = requests.post(URL, json=data)
        print(f"Kirim: {data} | Status: {r.status_code}")
    except Exception as e:
        print("Gagal kirim:", e)
    time.sleep(5)  # kirim tiap 5 detik
