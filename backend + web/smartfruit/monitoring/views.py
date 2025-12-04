# ==========================================================
# 📊 Endpoint Debug: Raw Data InfluxDB
# ==========================================================
from rest_framework.decorators import api_view
from rest_framework.response import Response

@api_view(['GET'])
def api_sensor_raw(request):
    """Return 10 data mentah terakhir dari InfluxDB untuk debugging."""
    raw = influx_client.get_latest_raw(limit=10)
    return Response(raw)
# ==========================================================
# Landing Auth View
# ==========================================================
from django.contrib.auth.decorators import login_required
from django.shortcuts import redirect, render
def landing_auth(request):
    if request.user.is_authenticated:
        return redirect('dashboard')
    return render(request, 'landing_auth.html')

import os
import csv
import pickle
import numpy as np
import json
import requests
from django.http import HttpResponse, JsonResponse
from rest_framework.decorators import api_view
from rest_framework.response import Response
from .models import SensorData, DeviceToken, ContactMessage
from .serializers import SensorDataSerializer
from . import influx_client
from asgiref.sync import async_to_sync
from channels.layers import get_channel_layer
from rest_framework import status

# Import ML Service & AI Agent
import sys
ML_PATH = os.path.join(os.path.dirname(os.path.dirname(__file__)), 'ml')
if ML_PATH not in sys.path:
    sys.path.insert(0, ML_PATH)

try:
    from ml_service import predict_status as ml_predict, add_realtime_data as ml_add_data
    from ai_agent import analyze_sensor_data as ai_analyze
    ML_ENABLED = True
    AI_ENABLED = True
    print("✅ ML Service & AI Agent loaded successfully")
except Exception as e:
    ML_ENABLED = False
    AI_ENABLED = False
    print(f"⚠️ ML/AI Service not available: {e}")


# ==========================================================
# 🔔 Register Device Token
# ==========================================================
@api_view(['POST'])
def register_token(request):
    token = request.data.get('token')
    if token:
        DeviceToken.objects.update_or_create(token=token)
        print(f"DEBUG: Token device baru diregister = {token}")
        return Response({'status': 'ok'})
    print("WARNING: Tidak ada token di request")
    return Response({'status': 'error', 'message': 'No token'}, status=400)


# ==========================================================
# 🔔 Kirim Notifikasi FCM
# ==========================================================
def send_fcm_notification(token, title, body):
    server_key = "YOUR_FCM_SERVER_KEY"  # ganti dengan server key FCM Anda
    url = "https://fcm.googleapis.com/fcm/send"
    headers = {
        "Authorization": "key=" + server_key,
        "Content-Type": "application/json"
    }
    payload = {
        "to": token,
        "notification": {
            "title": title,
            "body": body
        }
    }
    try:
        r = requests.post(url, json=payload, headers=headers)
        print(f"DEBUG: FCM response = {r.status_code}, {r.text}")
    except Exception as e:
        print("ERROR: Gagal kirim FCM:", e)


# ==========================================================
# 📊 Export Data ke CSV
# ==========================================================
def export_csv(request):
    qs = SensorData.objects.all()
    date_str = request.GET.get('date')
    time_str = request.GET.get('time')
    status = request.GET.get('status')

    if date_str:
        qs = qs.filter(timestamp__date=date_str)
    if time_str:
        qs = qs.filter(timestamp__time=time_str)
    if status:
        qs = qs.filter(status=status)

    print(f"DEBUG: Export {qs.count()} data ke CSV (filter: date={date_str}, time={time_str}, status={status})")

    response = HttpResponse(content_type='text/csv')
    response['Content-Disposition'] = 'attachment; filename=\"sensor_data.csv\"'
    writer = csv.writer(response)
    writer.writerow(['Waktu', 'Suhu', 'Kelembapan', 'MQ2 (ppm)', 'MQ3 (ppm)', 'MQ135 (ppm)', 'Status'])

    for row in qs.order_by('-timestamp'):
        writer.writerow([
            row.timestamp,
            row.temperature,
            row.humidity,
            getattr(row, 'mq2', None),
            getattr(row, 'mq3', None),
            getattr(row, 'mq135', None),
            row.status
        ])

    return response


# ==========================================================
# 📊 Dashboard View
# ==========================================================
@login_required
@login_required
def dashboard(request):
    latest = SensorData.objects.last()
    history = SensorData.objects.all().order_by('-timestamp')[:10]

    context = {
        'title': 'Dashboard',
        'latest': latest if latest else None,
        'history': history
    }

    if history:
        # Decide whether to include seconds in labels: include seconds only if timestamps differ by seconds
        seconds = { row.timestamp.strftime('%S') for row in history }
        include_seconds = len(seconds) > 1
        label_fmt = '%H:%M:%S' if include_seconds else '%H:%M'
        labels = json.dumps([row.timestamp.strftime(label_fmt) for row in reversed(history)])
        suhu = json.dumps([row.temperature if row.temperature is not None else None for row in reversed(history)])
        hum = json.dumps([row.humidity if row.humidity is not None else None for row in reversed(history)])
        mq2 = json.dumps([getattr(row, 'mq2', None) for row in reversed(history)])
        mq3 = json.dumps([getattr(row, 'mq3', None) for row in reversed(history)])
        mq135 = json.dumps([getattr(row, 'mq135', None) for row in reversed(history)])
    else:
        labels, suhu, hum, mq2, mq3, mq135 = '[]', '[]', '[]', '[]', '[]', '[]'
        include_seconds = False

    return render(request, "dashboard.html", {
        "data": latest,
        "history": history,
        "labels_js": labels,
        "suhu_js": suhu,
        "hum_js": hum,
        "mq2_js": mq2,
        "mq3_js": mq3,
        "mq135_js": mq135,
        "labels_with_seconds": include_seconds
    })


# ==========================================================
# 🤖 AI Model Loader
# ==========================================================
def load_model():
    MODEL_PATH = os.path.join(os.path.dirname(__file__), "fruit_quality_model.pkl")
    try:
        with open(MODEL_PATH, "rb") as f:
            model = pickle.load(f)
        print("DEBUG: Model AI berhasil diload")
        return model
    except FileNotFoundError:
        print("WARNING: Model AI tidak ditemukan")
        return None
    except Exception as e:
        print("ERROR: Gagal load model AI:", e)
        return None


# ==========================================================
# 📡 API untuk Update Sensor
# ==========================================================
@api_view(['POST'])
def update_sensor(request):
    temperature = request.data.get("temperature")
    humidity = request.data.get("humidity")
    # Support both legacy 'gas' field and new 'mq2','mq3','mq135' fields
    mq2 = request.data.get('mq2', None)
    mq3 = request.data.get('mq3', None)
    mq135 = request.data.get('mq135', None)
    legacy_gas = request.data.get('gas', None)

    # if mq2 not provided, fall back to legacy gas value for compatibility
    if mq2 is None and legacy_gas is not None:
        mq2 = legacy_gas
    # convert to floats with defaults
    try:
        mq2 = float(mq2) if mq2 is not None else 0.0
    except (ValueError, TypeError):
        mq2 = 0.0
    try:
        mq3 = float(mq3) if mq3 is not None else 0.0
    except (ValueError, TypeError):
        mq3 = 0.0
    try:
        mq135 = float(mq135) if mq135 is not None else 0.0
    except (ValueError, TypeError):
        mq135 = 0.0

    print(f"DEBUG: Data sensor masuk => Suhu={temperature}, Hum={humidity}, MQ2={mq2}, MQ3={mq3}, MQ135={mq135}")

    # For model features keep previous shape; use mq2 as representative gas if available
    features = np.array([[temperature, humidity, mq2]])
    model = load_model()

    jenis_buah = "UNKNOWN"
    status = "UNKNOWN"

    if model:
        try:
            result = model.predict(features)
            print("DEBUG: Hasil prediksi model =", result)

            if isinstance(result[0], (list, tuple)) and len(result[0]) == 2:
                status_pred, jenis_pred = result[0]
                status = "LAYAK" if status_pred == 0 else "TIDAK LAYAK"
                jenis_buah = str(jenis_pred)
            else:
                status = "LAYAK" if result[0] == 0 else "TIDAK LAYAK"
        except Exception as e:
            print("ERROR: Gagal prediksi model AI:", e)

    data = SensorData.objects.create(
        temperature=temperature,
        humidity=humidity,
        mq2=mq2,
        mq3=mq3,
        mq135=mq135,
        status=status,
        jenis_buah=jenis_buah
    )

    print(f"DEBUG: Data sensor tersimpan => ID={data.id}, Status={status}")

    if status == "TIDAK LAYAK":
        tokens = DeviceToken.objects.values_list('token', flat=True)
        for device_token in tokens:
            send_fcm_notification(
                device_token,
                "Peringatan Kualitas Buah",
                f"Status buah TIDAK LAYAK! Suhu: {temperature}°C, Kelembapan: {humidity}%"
            )

    serializer = SensorDataSerializer(data)
    return Response(serializer.data)


# ==========================================================
# 📡 API untuk ambil status terakhir
# ==========================================================
@api_view(['GET'])
def get_status(request):
    # Try InfluxDB first
    try:
        latest_point = influx_client.get_latest_point()
        if latest_point:
            # Ambil data sensor mentah
            data = {
                'suhu': latest_point.get('temperature'),
                'kelembapan': latest_point.get('humidity'),
                'mq2': latest_point.get('mq2'),
                'mq3': latest_point.get('mq3'),
                'mq135': latest_point.get('mq135')
            }
            # Analisis status
            from smartfruit.helpers.status_checker import check_status
            status_result = check_status(data)
            resp = {
                **data,
                'status': status_result['status'],
                'alasan': status_result['alasan'],
                'timestamp': latest_point.get('time')
            }
            print("DEBUG: Ambil status terakhir dari InfluxDB =", resp)
            return Response(resp)
    except Exception as e:
        print("WARNING: get_status - InfluxDB query failed:", e)

    # Fallback to Django DB
    latest = SensorData.objects.last()
    if latest:
        print("DEBUG: Ambil status terakhir dari DB =", latest)
        serializer = SensorDataSerializer(latest)
        return Response(serializer.data)
    print("WARNING: Tidak ada data sensor di DB")
    return Response({"status": "error", "message": "No data"}, status=404)

import json
import os
from ml.ai_agent import SensorAIAgent

TRAIN_DATA_PATH = os.path.join(os.path.dirname(__file__), '..', 'ml', 'train_data.json')
ai_agent_instance = SensorAIAgent()

@api_view(['POST'])
def api_train_status(request):
    """
    Terima data sensor dan label status dari frontend, simpan ke file, update AI Agent.
    Body: {
        'suhu': float,
        'kelembapan': float,
        'mq2': float,
        'mq3': float,
        'mq135': float,
        'status': 'LAYAK' | 'TIDAK LAYAK'
    }
    """
    data = request.data
    required_fields = ['suhu', 'kelembapan', 'mq2', 'mq3', 'mq135', 'status']
    if not all(field in data for field in required_fields):
        return Response({'error': 'Missing fields'}, status=400)

    # Simpan ke file
    train_data = []
    if os.path.exists(TRAIN_DATA_PATH):
        with open(TRAIN_DATA_PATH, 'r') as f:
            try:
                train_data = json.load(f)
            except:
                train_data = []
    train_data.append(data)
    with open(TRAIN_DATA_PATH, 'w') as f:
        json.dump(train_data, f)

    # Update AI Agent (tambahkan ke buffer)
    ai_agent_instance.history_buffer['suhu'].append(float(data['suhu']))
    ai_agent_instance.history_buffer['kelembapan'].append(float(data['kelembapan']))
    ai_agent_instance.history_buffer['mq2'].append(float(data['mq2']))
    ai_agent_instance.history_buffer['mq3'].append(float(data['mq3']))
    ai_agent_instance.history_buffer['mq135'].append(float(data['mq135']))
    ai_agent_instance.total_readings += 1

    return Response({'status': 'ok', 'message': 'Data latih diterima dan AI Agent diupdate.'})
# ==========================================================
# 📡 API untuk ambil riwayat
# ==========================================================
@api_view(['GET'])
def get_history(request):
    # Try InfluxDB first
    try:
        rows = influx_client.get_history(limit=50, range_hours=24)
        # convert timestamps to ISO strings for JSON
        out = []
        for r in rows:
            out.append({
                'created_at': r.get('timestamp').isoformat() if hasattr(r.get('timestamp'), 'isoformat') else r.get('timestamp'),
                'temperature': r.get('temperature'),
                'humidity': r.get('humidity'),
                'mq2': r.get('mq2'),
                'mq3': r.get('mq3'),
                'mq135': r.get('mq135'),
                'status': None
            })
        print(f"DEBUG: Ambil history dari InfluxDB, total={len(out)}")
        return Response(out)
    except Exception as e:
        print("WARNING: get_history - InfluxDB query failed:", e)

    # Fallback to Django DB
    qs = SensorData.objects.all()
    date_str = request.GET.get('date')
    time_str = request.GET.get('time')
    status = request.GET.get('status')

    if date_str:
        qs = qs.filter(timestamp__date=date_str)
    if time_str:
        qs = qs.filter(timestamp__time=time_str)
    if status:
        qs = qs.filter(status=status)

    history = qs.order_by('-timestamp')[:50]
    print(f"DEBUG: Ambil history (filter: date={date_str}, time={time_str}, status={status}), total={history.count()}")

    serializer = SensorDataSerializer(history, many=True)
    return Response(serializer.data)


# ==========================================================
# 📡 API untuk sensor data realtime (websocket broadcast)
# ==========================================================
from django.views.decorators.csrf import csrf_exempt

@csrf_exempt
def sensor_data(request):
    if request.method == 'POST':
        try:
            data = json.loads(request.body)
            
            # Save to InfluxDB
            try:
                from influxdb_client import InfluxDBClient, Point, WritePrecision
                from influxdb_client.client.write_api import SYNCHRONOUS
                from datetime import datetime
                
                # Get InfluxDB configuration
                url = os.environ.get('INFLUX_URL', 'http://103.151.63.80:8086')
                token = os.environ.get('INFLUX_TOKEN', 'Wv4fUOXPpqTi7FFQDVskdQjrLVEaweO0wh00QYNKOdM1_wpQArozJdxz7esh7j-B0V24P3CcSa-aXogVSco9Yg==')
                org = os.environ.get('INFLUX_ORG', 'polinela')
                bucket = os.environ.get('INFLUX_BUCKET', 'datamonitoring')
                
                # Create InfluxDB client
                client = InfluxDBClient(url=url, token=token, org=org)
                write_api = client.write_api(write_options=SYNCHRONOUS)
                
                # Create point with sensor data
                point = Point("sensordata")
                point.field("suhu", float(data.get('suhu', 0)))
                point.field("kelembapan", float(data.get('kelembapan', 0)))
                point.field("mq2", float(data.get('mq2', 0)))
                point.field("mq3", float(data.get('mq3', 0)))
                point.field("mq135", float(data.get('mq135', 0)))
                
                # Add status only if present
                if 'status' in data and data['status'] is not None:
                    point.field("status", int(data['status']))
                
                point.field("skorTotal", float(data.get('skorTotal', 0)))
                point.time(datetime.utcnow(), WritePrecision.NS)
                
                # Write to InfluxDB
                write_api.write(bucket=bucket, org=org, record=point)
                client.close()
                
                print(f"✅ Data saved to InfluxDB: {data}")
                
            except Exception as influx_error:
                print(f"❌ Failed to save to InfluxDB: {influx_error}")
            
            # Add data to ML dataset untuk continual learning
            if ML_ENABLED:
                try:
                    mq2 = float(data.get('mq2', 0))
                    mq3 = float(data.get('mq3', 0))
                    mq135 = float(data.get('mq135', 0))
                    humidity = float(data.get('kelembapan', 0))
                    temperature = float(data.get('suhu', 0))
                    
                    # Convert status (0/1) ke Layak/Tidak Layak
                    sensor_status = data.get('status')
                    if sensor_status is not None:
                        ml_status = 'Layak' if int(sensor_status) == 1 else 'Tidak Layak'
                        ml_add_data(mq2, mq3, mq135, humidity, temperature, ml_status)
                        print(f"📝 Data added to ML dataset: Status={ml_status}")
                except Exception as ml_error:
                    print(f"⚠️ ML add data error: {ml_error}")
            
            # Broadcast to WebSocket
            channel_layer = get_channel_layer()
            async_to_sync(channel_layer.group_send)(
                "sensor_data",
                {"type": "send_sensor_data", "data": data}
            )
            return JsonResponse({"status": "success"}, status=200)
        except Exception as e:
            return JsonResponse({"status": "error", "message": str(e)}, status=400)
    return JsonResponse({"status": "error", "message": "Invalid request"}, status=400)


# ==========================================================
# 📡 API endpoint: get the latest sensor data
# ==========================================================
def get_latest_status(request):
    latest_data = SensorData.objects.last()
    if latest_data:
        return JsonResponse({
            "timestamp": latest_data.timestamp.strftime('%Y-%m-%d %H:%M:%S'),
            "temperature": latest_data.temperature,
            "humidity": latest_data.humidity,
            "mq2": getattr(latest_data, 'mq2', None),
            "mq3": getattr(latest_data, 'mq3', None),
            "mq135": getattr(latest_data, 'mq135', None),
            "status": latest_data.status
        })
    return JsonResponse({"error": "No data available"}, status=404)


# ==========================================================
# 📡 API endpoint: get last 50 sensor data entries
# ==========================================================
def get_sensor_history(request):
    """Get realtime sensor history from InfluxDB. Falls back to database if InfluxDB unavailable."""
    try:
        # Try to get data from InfluxDB first
        history_data = influx_client.get_history_data(limit=50)
        
        if history_data and len(history_data) > 0:
            # InfluxDB data available
            data = []
            for entry in history_data:
                suhu = float(entry.get('suhu', 0))
                kelembapan = float(entry.get('kelembapan', 0))
                mq2 = float(entry.get('mq2', 0))
                mq3 = float(entry.get('mq3', 0))
                mq135 = float(entry.get('mq135', 0))
                
                # Use status from MQTT if available, otherwise calculate
                mqtt_status = entry.get('status')
                if mqtt_status is not None:
                    status_value = 'LAYAK' if mqtt_status == 1 else 'TIDAK LAYAK'
                else:
                    status_value = calculate_overall_status(suhu, kelembapan, mq2, mq3, mq135)
                
                data.append({
                    "timestamp": entry.get('timestamp', ''),
                    "suhu": suhu,
                    "kelembapan": kelembapan,
                    "mq2": mq2,
                    "mq3": mq3,
                    "mq135": mq135,
                    "status": status_value,
                    "skorTotal": entry.get('skorTotal', 0)
                })
            return JsonResponse(data, safe=False)
        else:
            # Fallback to database
            print("WARNING: InfluxDB history data unavailable, falling back to database")
            raise Exception("No InfluxDB data")
            
    except Exception as e:
        print(f"ERROR getting InfluxDB history: {e}")
        # Fallback to database
        history = SensorData.objects.order_by('-timestamp')[:50]
        data = [
            {
                "timestamp": entry.timestamp.strftime('%Y-%m-%d %H:%M:%S'),
                "suhu": float(entry.temperature) if entry.temperature else 0,
                "kelembapan": float(entry.humidity) if entry.humidity else 0,
                "mq2": float(getattr(entry, 'mq2', 0)) if getattr(entry, 'mq2', None) else 0,
                "mq3": float(getattr(entry, 'mq3', 0)) if getattr(entry, 'mq3', None) else 0,
                "mq135": float(getattr(entry, 'mq135', 0)) if getattr(entry, 'mq135', None) else 0,
                "status": getattr(entry, 'status', 'UNKNOWN')
            }
            for entry in history
        ]
        return JsonResponse(data, safe=False)


@api_view(['GET'])
def api_status_influx(request):
    print("DEBUG: /api/status dipanggil")
    """Return latest sensor data from InfluxDB (realtime). Falls back to DB."""
    try:
        data = influx_client.get_latest_data()
        print(f"[INFLUXDB] Data terbaru: {data}")
        if isinstance(data, dict) and data.get('error'):
            # log and fallback
            print(f"WARNING: Influx get_latest_data error: {data.get('error')}")
            raise Exception(data.get('error'))

        # ensure numeric values
        suhu = float(data.get('suhu', 0))
        kelembapan = float(data.get('kelembapan', 0))
        mq2 = float(data.get('mq2', 0))
        mq3 = float(data.get('mq3', 0))
        mq135 = float(data.get('mq135', 0))
        
        # Use status from MQTT/InfluxDB if available, otherwise calculate
        mqtt_status = data.get('status')
        if mqtt_status is not None:
            # Convert MQTT status (0 or 1) to text
            status_value = 'LAYAK' if mqtt_status == 1 else 'TIDAK LAYAK'
        else:
            # Fallback: Calculate overall status based on all sensors
            status_value = calculate_overall_status(suhu, kelembapan, mq2, mq3, mq135)
        
        # AI Agent Analysis (analisis realtime tanpa mengubah data sensor)
        ai_analysis = None
        if AI_ENABLED:
            try:
                ai_result = ai_analyze(suhu, kelembapan, mq2, mq3, mq135)
                ai_analysis = {
                    'final_status': ai_result.get('final_status'),
                    'explanation': ai_result.get('explanation'),
                    'confidence': ai_result.get('confidence'),
                    'sensor_status': ai_result.get('sensor_status'),
                    'adaptive_learning': ai_result.get('adaptive_learning')
                }
                print(f"🤖 AI Analysis: {ai_analysis['final_status']} - {ai_analysis['explanation']}")
            except Exception as e:
                print(f"⚠️ AI Analysis error: {e}")
        
        # ML Prediction (tanpa mengubah status realtime)
        ml_prediction = None
        if ML_ENABLED:
            try:
                ml_result = ml_predict(mq2, mq3, mq135, kelembapan, suhu)
                ml_prediction = {
                    'status': ml_result.get('status'),
                    'confidence': ml_result.get('confidence'),
                    'timestamp': ml_result.get('timestamp')
                }
                print(f"🤖 ML Prediction: {ml_prediction}")
            except Exception as e:
                print(f"⚠️ ML Prediction error: {e}")
        
        payload = {
            'suhu': suhu,
            'kelembapan': kelembapan,
            'mq2': mq2,
            'mq3': mq3,
            'mq135': mq135,
            'status': status_value,
            'skorTotal': data.get('skorTotal', 0),
            'ai_analysis': ai_analysis,  # Tambahkan hasil analisis AI Agent
            'ml_prediction': ml_prediction  # Tambahkan hasil prediksi ML
        }
        return Response(payload)


    except Exception as e:
        print(f"INFO: api_status_influx - falling back to DB due to: {e}")
        # fallback to local DB
        latest = SensorData.objects.last()
        if latest:
            suhu = latest.temperature or 0
            kelembapan = latest.humidity or 0
            mq2 = getattr(latest, 'mq2', 0) or 0
            mq3 = getattr(latest, 'mq3', 0) or 0
            mq135 = getattr(latest, 'mq135', 0) or 0
            
            status_value = calculate_overall_status(suhu, kelembapan, mq2, mq3, mq135)
            
            payload = {
                'suhu': suhu,
                'kelembapan': kelembapan,
                'mq2': mq2,
                'mq3': mq3,
                'mq135': mq135,
                'status': status_value,
            }
            return Response(payload)
        return Response({'error': 'no data'}, status=status.HTTP_204_NO_CONTENT)


def calculate_overall_status(suhu, kelembapan, mq2, mq3, mq135):
    """Calculate overall status based on all sensor readings."""
    # Thresholds
    DANGER_THRESHOLDS = {
        'suhu': 35,
        'kelembapan': 90,
        'mq2': 200,
        'mq3': 300,
        'mq135': 150
    }
    
    WARNING_THRESHOLDS = {
        'suhu': 30,
        'kelembapan': 80,
        'mq2': 100,
        'mq3': 150,
        'mq135': 80
    }
    
    # Check for danger conditions
    if (suhu >= DANGER_THRESHOLDS['suhu'] or
        kelembapan >= DANGER_THRESHOLDS['kelembapan'] or
        mq2 >= DANGER_THRESHOLDS['mq2'] or
        mq3 >= DANGER_THRESHOLDS['mq3'] or
        mq135 >= DANGER_THRESHOLDS['mq135']):
        return 'TIDAK LAYAK'
    
    # Check for warning conditions
    if (suhu >= WARNING_THRESHOLDS['suhu'] or
        kelembapan >= WARNING_THRESHOLDS['kelembapan'] or
        mq2 >= WARNING_THRESHOLDS['mq2'] or
        mq3 >= WARNING_THRESHOLDS['mq3'] or
        mq135 >= WARNING_THRESHOLDS['mq135']):
        return 'PERINGATAN'
    
    return 'LAYAK'


def contact_person(request):
    """Render Contact Person page. Accepts POST to save messages (supports AJAX).

    If POST via AJAX (X-Requested-With=XMLHttpRequest) returns JSON {status:'ok'}.
    Otherwise redirects/renders the same page with `success=True` in context.
    """
    if request.method == 'POST':
        name = request.POST.get('name', '').strip()
        email = request.POST.get('email', '').strip()
        company = request.POST.get('company', '').strip()
        phone = request.POST.get('phone', '').strip()
        message = request.POST.get('message', '').strip()

        try:
            ContactMessage.objects.create(
                name=name,
                email=email,
                company=company,
                phone=phone,
                message=message
            )
            print(f"DEBUG: ContactMessage saved from {name or phone}")
        except Exception as e:
            print("ERROR: Failed saving ContactMessage:", e)
            if request.headers.get('x-requested-with') == 'XMLHttpRequest':
                return JsonResponse({'status': 'error', 'message': str(e)}, status=500)
            return render(request, 'monitoring/contact_person.html', {'error': 'Gagal menyimpan pesan'})

        # If AJAX, return JSON; otherwise render page with success flag
        if request.headers.get('x-requested-with') == 'XMLHttpRequest':
            return JsonResponse({'status': 'ok'})
        return render(request, 'monitoring/contact_person.html', {'success': True})

    return render(request, 'monitoring/contact_person.html')


# ==========================================================
# 🤖 ML API Endpoints
# ==========================================================
@api_view(['POST'])
def ml_retrain(request):
    """API untuk retrain model ML"""
    if not ML_ENABLED:
        return Response({'error': 'ML service not available'}, status=503)
    
    try:
        from ml_service import retrain_model
        success = retrain_model()
        if success:
            return Response({'status': 'success', 'message': 'Model retrained successfully'})
        else:
            return Response({'status': 'error', 'message': 'Training failed'}, status=500)
    except Exception as e:
        return Response({'status': 'error', 'message': str(e)}, status=500)


@api_view(['GET'])
def ml_dataset_info(request):
    """API untuk mendapatkan info dataset ML"""
    if not ML_ENABLED:
        return Response({'error': 'ML service not available'}, status=503)
    
    try:
        from ml_service import get_dataset_info
        info = get_dataset_info()
        return Response(info)
    except Exception as e:
        return Response({'error': str(e)}, status=500)


@api_view(['POST'])
def ml_predict(request):
    """API untuk prediksi manual"""
    if not ML_ENABLED:
        return Response({'error': 'ML service not available'}, status=503)
    
    try:
        data = request.data
        mq2 = float(data.get('mq2', 0))
        mq3 = float(data.get('mq3', 0))
        mq135 = float(data.get('mq135', 0))
        humidity = float(data.get('humidity', 0))
        temperature = float(data.get('temperature', 0))
        
        from ml_service import predict_status as ml_predict_func
        result = ml_predict_func(mq2, mq3, mq135, humidity, temperature)
        return Response(result)
    except Exception as e:
        return Response({'error': str(e)}, status=500)


# ==========================================================
# 🤖 AI Agent Endpoints
# ==========================================================
@api_view(['GET'])
def ai_learning_info(request):
    """API untuk mendapatkan info adaptive learning AI Agent"""
    if not AI_ENABLED:
        return Response({'error': 'AI Agent not available'}, status=503)
    
    try:
        from ai_agent import get_ai_learning_info
        info = get_ai_learning_info()
        return Response(info)
    except Exception as e:
        return Response({'error': str(e)}, status=500)


@api_view(['POST'])
def ai_reset_learning(request):
    """API untuk reset adaptive learning AI Agent"""
    if not AI_ENABLED:
        return Response({'error': 'AI Agent not available'}, status=503)
    
    try:
        from ai_agent import reset_adaptive_learning
        result = reset_adaptive_learning()
        return Response(result)
    except Exception as e:
        return Response({'error': str(e)}, status=500)
