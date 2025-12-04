from django.http import JsonResponse
from .models import SensorData
from rest_framework.decorators import api_view
from rest_framework.response import Response
import json
from . import influx_client

@api_view(['GET'])
def get_sensor_status(request):
    """Get latest sensor readings for dashboard"""
    try:
        latest = SensorData.objects.last()
        if latest:
            data = {
                'temperature': latest.temperature,
                'humidity': latest.humidity,
                'mq2': latest.mq2 if latest.mq2 is not None else 0,
                'mq3': latest.mq3 if latest.mq3 is not None else 0,
                'mq135': latest.mq135 if latest.mq135 is not None else 0,
                'status': latest.status,
                'timestamp': latest.timestamp.strftime('%Y-%m-%d %H:%M:%S')
            }
            return Response(data)
        return Response({
            'temperature': 0,
            'humidity': 0,
            'mq2': 0,
            'mq3': 0,
            'mq135': 0,
            'status': 'NO_DATA',
            'timestamp': None
        })
    except Exception as e:
        print(f"Error getting sensor status: {e}")
        return Response({'error': str(e)}, status=500)

@api_view(['GET'])
def get_sensor_history(request):
    """Get sensor reading history for charts"""
    try:
        # Get last 10 readings ordered by timestamp
        history = SensorData.objects.order_by('-timestamp')[:10]
        data = []
        
        for reading in reversed(list(history)):  # Reverse to get chronological order
            entry = {
                'timestamp': reading.timestamp.strftime('%H:%M:%S'),
                'suhu': reading.temperature,
                'kelembapan': reading.humidity,
                'mq2': reading.mq2 if reading.mq2 is not None else 0,
                'mq3': reading.mq3 if reading.mq3 is not None else 0,
                'mq135': reading.mq135 if reading.mq135 is not None else 0,
                'status': reading.status
            }
            data.append(entry)
            
        return Response(data)
    except Exception as e:
        print(f"Error getting sensor history: {e}")
        return Response({'error': str(e)}, status=500)

@api_view(['GET'])
def api_status(request):
    """API endpoint used by the dashboard to get latest readings.

    Preference order:
    1. Try to fetch from InfluxDB via `influx_client.get_latest_data()`.
    2. Fallback to local database `SensorData` if Influx is unavailable.
    """
    try:
        # Try InfluxDB first
        try:
            data = influx_client.get_latest_data()
            # map to expected keys by frontend
            payload = {
                'suhu': data.get('suhu'),
                'kelembapan': data.get('kelembapan'),
                'mq2': data.get('mq2'),
                'mq3': data.get('mq3'),
                'mq135': data.get('mq135'),
                'status': 'OK',
                'source': 'influx'
            }
            return Response(payload)
        except Exception as ie:
            # Influx failed -> fallback to DB
            print(f"Influx fetch failed, falling back to DB: {ie}")

        latest = SensorData.objects.last()
        if latest:
            data = {
                'suhu': latest.temperature,
                'kelembapan': latest.humidity,
                'mq2': latest.mq2 if latest.mq2 is not None else 0,
                'mq3': latest.mq3 if latest.mq3 is not None else 0,
                'mq135': latest.mq135 if latest.mq135 is not None else 0,
                'status': latest.status,
                'timestamp': latest.timestamp.strftime('%Y-%m-%d %H:%M:%S'),
                'source': 'db'
            }
            return Response(data)
        return Response({
            'suhu': 0,
            'kelembapan': 0,
            'mq2': 0,
            'mq3': 0,
            'mq135': 0,
            'status': 'NO_DATA',
            'timestamp': None
        })
    except Exception as e:
        print(f"Error getting api_status: {e}")
        return Response({'error': str(e)}, status=500)
@api_view(['POST'])
def update_sensor_data(request):
    """Update sensor readings from hardware"""
    try:
        data = json.loads(request.body)
        
        # Create new sensor reading
        sensor_data = SensorData(
            temperature=float(data.get('temperature', 0)),
            humidity=float(data.get('humidity', 0)),
            mq2=float(data.get('mq2', 0)),
            mq3=float(data.get('mq3', 0)),
            mq135=float(data.get('mq135', 0))
        )

        # Determine status based on thresholds
        # You can adjust these thresholds based on your requirements
        if (sensor_data.temperature > 35 or 
            sensor_data.humidity > 90 or 
            sensor_data.mq2 > 200 or 
            sensor_data.mq3 > 300 or 
            sensor_data.mq135 > 150):
            sensor_data.status = "TIDAK LAYAK"
        elif (sensor_data.temperature > 30 or 
              sensor_data.humidity > 80 or 
              sensor_data.mq2 > 100 or 
              sensor_data.mq3 > 150 or 
              sensor_data.mq135 > 80):
            sensor_data.status = "PERINGATAN"
        else:
            sensor_data.status = "LAYAK"

        sensor_data.save()

        # Broadcast to WebSocket
        channel_layer = get_channel_layer()
        async_to_sync(channel_layer.group_send)(
            "sensor_updates",
            {
                "type": "sensor_update",
                "data": {
                    'temperature': sensor_data.temperature,
                    'humidity': sensor_data.humidity,
                    'mq2': sensor_data.mq2,
                    'mq3': sensor_data.mq3,
                    'mq135': sensor_data.mq135,
                    'status': sensor_data.status,
                    'timestamp': sensor_data.timestamp.strftime('%Y-%m-%d %H:%M:%S')
                }
            }
        )

        return Response({'status': 'success'})
    except Exception as e:
        print(f"Error updating sensor data: {e}")
        return Response({'error': str(e)}, status=500)