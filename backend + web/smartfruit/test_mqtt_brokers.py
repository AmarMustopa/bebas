"""
Test koneksi ke berbagai MQTT broker publik
untuk menemukan broker yang dipakai ESP32 Anda
"""
import paho.mqtt.client as mqtt
import time

MQTT_TOPIC = "annas/esp32/sensor"

# List broker MQTT publik yang umum
BROKERS = [
    ("broker.hivemq.com", 1883),
    ("mqtt.eclipseprojects.io", 1883),
    ("test.mosquitto.org", 1883),
    ("broker.emqx.io", 1883),
    ("mqtt.flespi.io", 1883),
]

def on_connect(client, userdata, flags, rc):
    broker = userdata['broker']
    if rc == 0:
        print(f"✅ [{broker}] Connected!")
        client.subscribe(MQTT_TOPIC)
        print(f"📡 [{broker}] Subscribed to: {MQTT_TOPIC}")
    else:
        print(f"❌ [{broker}] Failed to connect, code: {rc}")

def on_message(client, userdata, msg):
    broker = userdata['broker']
    print(f"\n🎉 [{broker}] FOUND IT! Data received from ESP32:")
    print(f"   Topic: {msg.topic}")
    print(f"   Payload: {msg.payload.decode()}")
    print(f"\n✅ Broker yang benar: {broker}")
    print(f"   Gunakan broker ini di mqtt_to_influx.py!")

def test_broker(broker, port):
    print(f"\n🔍 Testing {broker}:{port}...")
    try:
        client = mqtt.Client(userdata={'broker': broker})
        client.on_connect = on_connect
        client.on_message = on_message
        
        client.connect(broker, port, 60)
        client.loop_start()
        return client
    except Exception as e:
        print(f"❌ [{broker}] Connection error: {e}")
        return None

print("=" * 60)
print("🔍 Testing MQTT Brokers untuk topic: annas/esp32/sensor")
print("=" * 60)
print("Pastikan ESP32 Anda sedang mengirim data!")
print()

clients = []
for broker, port in BROKERS:
    client = test_broker(broker, port)
    if client:
        clients.append(client)
    time.sleep(1)

print("\n⏳ Listening for 60 seconds...")
print("   Kirim data dari ESP32 Anda sekarang!")
time.sleep(60)

print("\n⏹️ Test selesai. Closing connections...")
for client in clients:
    client.loop_stop()
    client.disconnect()

print("👋 Done!")
