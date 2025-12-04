"""
MQTT to InfluxDB Bridge
Menerima data sensor dari MQTT dan menyimpan ke InfluxDB
"""
import json
import paho.mqtt.client as mqtt
from influxdb_client import InfluxDBClient, Point, WritePrecision
from influxdb_client.client.write_api import SYNCHRONOUS
from datetime import datetime
import time

# MQTT Configuration
MQTT_BROKER = "broker.hivemq.com"  # Broker MQTT publik - ganti jika pakai broker sendiri
MQTT_PORT = 1883
MQTT_TOPIC = "annas/esp32/sensor"  # Topic MQTT dari ESP32 Anda

# InfluxDB Configuration
INFLUX_URL = "http://103.151.63.80:8086"
INFLUX_TOKEN = "Wv4fUOXPpqTi7FFQDVskdQjrLVEaweO0wh00QYNKOdM1_wpQArozJdxz7esh7j-B0V24P3CcSa-aXogVSco9Yg=="
INFLUX_ORG = "polinela"
INFLUX_BUCKET = "datamonitoring"
MEASUREMENT = "sensordata"

# Global InfluxDB client
influx_client = None
write_api = None

def init_influx():
    """Initialize InfluxDB client"""
    global influx_client, write_api
    try:
        influx_client = InfluxDBClient(url=INFLUX_URL, token=INFLUX_TOKEN, org=INFLUX_ORG)
        write_api = influx_client.write_api(write_options=SYNCHRONOUS)
        print("✅ InfluxDB client initialized")
        return True
    except Exception as e:
        print(f"❌ Failed to initialize InfluxDB: {e}")
        return False

def on_connect(client, userdata, flags, rc):
    """Callback ketika terhubung ke MQTT broker"""
    if rc == 0:
        print(f"✅ Connected to MQTT Broker: {MQTT_BROKER}")
        client.subscribe(MQTT_TOPIC)
        print(f"📡 Subscribed to topic: {MQTT_TOPIC}")
    else:
        print(f"❌ Failed to connect to MQTT Broker, return code: {rc}")

def on_message(client, userdata, msg):
    """Callback ketika menerima pesan dari MQTT"""
    try:
        # Parse JSON data
        payload = msg.payload.decode('utf-8')
        data = json.loads(payload)
        
        print(f"\n📩 Received data from MQTT:")
        print(f"   Topic: {msg.topic}")
        print(f"   Data: {json.dumps(data, indent=2)}")
        
        # Extract sensor values
        suhu = data.get('suhu', 0.0)
        kelembapan = data.get('kelembapan', 0.0)
        mq2 = data.get('mq2', 0.0)
        mq3 = data.get('mq3', 0.0)
        mq135 = data.get('mq135', 0.0)
        status = data.get('status')  # 0 atau 1
        skorTotal = data.get('skorTotal', 0.0)
        
        # Create InfluxDB point
        point = Point(MEASUREMENT)
        point.field("suhu", float(suhu))
        point.field("kelembapan", float(kelembapan))
        point.field("mq2", float(mq2))
        point.field("mq3", float(mq3))
        point.field("mq135", float(mq135))
        
        # Only add status if it's not None
        if status is not None:
            point.field("status", int(status))
        
        point.field("skorTotal", float(skorTotal))
        point.time(datetime.utcnow(), WritePrecision.NS)
        
        # Write to InfluxDB
        write_api.write(bucket=INFLUX_BUCKET, org=INFLUX_ORG, record=point)
        
        print(f"✅ Data saved to InfluxDB:")
        print(f"   Suhu: {suhu}°C, Kelembapan: {kelembapan}%")
        print(f"   MQ2: {mq2}, MQ3: {mq3}, MQ135: {mq135}")
        print(f"   Status: {status}, Skor Total: {skorTotal}")
        
    except json.JSONDecodeError as e:
        print(f"❌ JSON decode error: {e}")
        print(f"   Raw payload: {msg.payload}")
    except Exception as e:
        print(f"❌ Error processing message: {e}")

def on_disconnect(client, userdata, rc):
    """Callback ketika terputus dari MQTT broker"""
    if rc != 0:
        print(f"⚠️ Unexpected disconnection. Reconnecting...")

def main():
    """Main function"""
    print("=" * 60)
    print("🚀 Starting MQTT to InfluxDB Bridge")
    print("=" * 60)
    
    # Initialize InfluxDB
    if not init_influx():
        print("❌ Cannot start without InfluxDB connection")
        return
    
    # Create MQTT client
    mqtt_client = mqtt.Client()
    mqtt_client.on_connect = on_connect
    mqtt_client.on_message = on_message
    mqtt_client.on_disconnect = on_disconnect
    
    # Connect to MQTT broker
    try:
        print(f"🔌 Connecting to MQTT Broker: {MQTT_BROKER}:{MQTT_PORT}")
        mqtt_client.connect(MQTT_BROKER, MQTT_PORT, 60)
        
        # Start the loop
        print("🔄 Starting MQTT loop...")
        mqtt_client.loop_forever()
        
    except KeyboardInterrupt:
        print("\n⏹️ Stopping MQTT to InfluxDB Bridge...")
        mqtt_client.disconnect()
        if influx_client:
            influx_client.close()
        print("👋 Goodbye!")
    except Exception as e:
        print(f"❌ Error: {e}")

if __name__ == "__main__":
    main()
