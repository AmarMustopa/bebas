import requests
import time

# Data dummy dari train_model.py
sensor_data = [
    {'temperature': 25, 'humidity': 60, 'gas': 0.1},
    {'temperature': 30, 'humidity': 80, 'gas': 0.2},
    {'temperature': 28, 'humidity': 70, 'gas': 0.15},
    {'temperature': 32, 'humidity': 85, 'gas': 0.25},
    {'temperature': 26, 'humidity': 65, 'gas': 0.12},
    {'temperature': 29, 'humidity': 75, 'gas': 0.18},
]

url = 'http://127.0.0.1:8000/api/sensor/'

for data in sensor_data:
    r = requests.post(url, json=data)
    print(f"Kirim: {data} => Status: {r.status_code}, Response: {r.text}")
    time.sleep(0.5)  # jeda biar urut created_at

print("Selesai mengirim data dummy ke backend!")
