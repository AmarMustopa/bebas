
import time
import random
from influxdb_client import InfluxDBClient, Point
from influxdb_client.client.write_api import SYNCHRONOUS

# Konfigurasi InfluxDB
INFLUX_URL = "http://103.151.63.80:8086"
INFLUX_TOKEN = "Wv4fUOXPpqTi7FFQDVskdQjrLVEaweO0wh00QYNKOdM1_wpQArozJdxz7esh7j-B0V24P3CcSa-aXogVSco9Yg=="
INFLUX_ORG = "polinela"
INFLUX_BUCKET = "datamonitoring"

client = InfluxDBClient(url=INFLUX_URL, token=INFLUX_TOKEN, org=INFLUX_ORG)
write_api = client.write_api(write_options=SYNCHRONOUS)

while True:
    suhu = round(random.uniform(28, 32), 1)
    kelembapan = round(random.uniform(80, 90), 1)
    mq2 = round(random.uniform(200, 400), 1)
    mq3 = round(random.uniform(700, 900), 1)
    mq135 = round(random.uniform(500, 700), 1)
    status = 1 if all([
        mq2 < 400,
        mq3 < 800,
        mq135 < 600,
        suhu < 30,
        kelembapan < 85
    ]) else 0

    point = Point("sensor") \
        .field("suhu", suhu) \
        .field("kelembapan", kelembapan) \
        .field("mq2", mq2) \
        .field("mq3", mq3) \
        .field("mq135", mq135) \
        .field("status", status)

    write_api.write(bucket=INFLUX_BUCKET, org=INFLUX_ORG, record=point)
    print(f"Sent: suhu={suhu}, kelembapan={kelembapan}, mq2={mq2}, mq3={mq3}, mq135={mq135}, status={status}")
    time.sleep(5)
