import json
import paho.mqtt.client as mqtt
from asgiref.sync import async_to_sync
from channels.layers import get_channel_layer
from .models import SensorData

# MQTT broker configuration
BROKER_URL = "103.151.63.80"
BROKER_PORT = 1883
TOPIC = "annas/esp32/sensor"

def process_sensor_data(temperature, humidity):
    """Process sensor data and determine status."""
    status = "LAYAK" if temperature <= 30 and humidity >= 30 else "TIDAK LAYAK"
    return status

def on_message(client, userdata, msg):
    """Callback for when a message is received from the MQTT broker."""
    try:
        data = json.loads(msg.payload)
        temperature = data.get("temperature")
        humidity = data.get("humidity")
        status = process_sensor_data(temperature, humidity)

        # Save to database
        sensor_data = SensorData.objects.create(
            temperature=temperature,
            humidity=humidity,
            mq2=data.get("mq2"),
            mq3=data.get("mq3"),
            mq135=data.get("mq135"),
            status=status
        )

        # Broadcast to WebSocket group
        channel_layer = get_channel_layer()
        async_to_sync(channel_layer.group_send)(
            "sensor_data_group",
            {
                "type": "send_sensor_data",
                "data": {
                    "timestamp": str(sensor_data.timestamp),
                    "temperature": sensor_data.temperature,
                    "humidity": sensor_data.humidity,
                    "mq2": sensor_data.mq2,
                    "mq3": sensor_data.mq3,
                    "mq135": sensor_data.mq135,
                    "status": sensor_data.status
                }
            }
        )
    except Exception as e:
        print(f"Error processing message: {e}")

def start_mqtt_client():
    """Start the MQTT client and subscribe to the topic."""
    client = mqtt.Client()
    client.on_message = on_message
    client.connect(BROKER_URL, BROKER_PORT, 60)
    client.subscribe(TOPIC)
    client.loop_start()