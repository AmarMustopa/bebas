from django.http import HttpResponse, JsonResponse
from django.views.decorators.http import require_http_methods
from django.contrib.auth.decorators import login_required
from django.shortcuts import render, get_object_or_404
from .models import SensorData, DeviceToken
from django.conf import settings
import influxdb_client
from django.contrib import messages
import json
from datetime import datetime, timedelta


@login_required
@require_http_methods(["GET"])
def data_history(request):
    """View for historical sensor data page."""
    # Get filter parameters
    date_filter = request.GET.get('date')
    status_filter = request.GET.get('status')
    
    # Get base queryset
    history = SensorData.objects.all().order_by('-timestamp')
    
    # Apply filters if provided
    if date_filter:
        try:
            date = datetime.strptime(date_filter, '%Y-%m-%d')
            history = history.filter(timestamp__date=date)
        except ValueError:
            pass
            
    if status_filter:
        history = history.filter(jenis_buah=status_filter)
    
    # Provide both 'data' (used for emptiness check) and 'history' (used for iteration)
    limited = history[:100]
    
    # Prepare chart data for JavaScript
    if limited:
        labels = json.dumps([row.timestamp.strftime('%Y-%m-%d %H:%M:%S') for row in limited[:10]])
        temp_data = json.dumps([float(row.temperature) if row.temperature is not None else 0 for row in limited[:10]])
        hum_data = json.dumps([float(row.humidity) if row.humidity is not None else 0 for row in limited[:10]])
        mq2_data = json.dumps([float(getattr(row, 'mq2', 0)) if getattr(row, 'mq2', None) is not None else 0 for row in limited[:10]])
        mq3_data = json.dumps([float(getattr(row, 'mq3', 0)) if getattr(row, 'mq3', None) is not None else 0 for row in limited[:10]])
        mq135_data = json.dumps([float(getattr(row, 'mq135', 0)) if getattr(row, 'mq135', None) is not None else 0 for row in limited[:10]])
    else:
        labels = '[]'
        temp_data = '[]'
        hum_data = '[]'
        mq2_data = '[]'
        mq3_data = '[]'
        mq135_data = '[]'
    
    return render(request, 'monitoring/history.html', {
        'title': 'Data History',
        'active_page': 'history',
        'data': limited,  # used by template to check empty
        'history': limited,  # used by template to iterate rows
        'date_filter': date_filter,
        'status_filter': status_filter,
        'total_records': history.count(),
        'labels_js': labels,
        'temp_js': temp_data,
        'hum_js': hum_data,
        'mq2_js': mq2_data,
        'mq3_js': mq3_data,
        'mq135_js': mq135_data,
    })


@login_required
@require_http_methods(["GET"])
def sensor_config_list(request):
    """View for sensor configuration management page."""
    sensors = DeviceToken.objects.all()
    return render(request, 'monitoring/sensor_configs.html', {
        'sensors': sensors,
        'title': 'Sensor Configuration',
        'active_page': 'sensor-config'
    })


@login_required
@require_http_methods(["GET"])
def ai_model_list(request):
    """View for AI model management page."""
    return render(request, 'monitoring/ai_models.html', {
        'title': 'AI Models',
        'active_page': 'ai-model'
    })


@login_required
@require_http_methods(["GET", "POST"])
def settings_page(request):
    """View for system settings page."""
    # Get all InfluxDB settings with defaults
    influx_settings = {
        'url': getattr(settings, 'INFLUXDB_URL', 'http://localhost:8086'),
        'token': getattr(settings, 'INFLUXDB_TOKEN', ''),
        'org': getattr(settings, 'INFLUXDB_ORG', ''),
        'bucket': getattr(settings, 'INFLUXDB_BUCKET', 'sensor_data')
    }
    
    if request.method == "POST":
        # Handle form submission
        try:
            # Validate and test connection
            test_settings = {
                'url': request.POST.get('influx_url'),
                'token': request.POST.get('influx_token') or influx_settings['token'],
                'org': request.POST.get('influx_org'),
                'bucket': request.POST.get('influx_bucket')
            }
            
            # Test connection with new settings
            client = influxdb_client.InfluxDBClient(
                url=test_settings['url'],
                token=test_settings['token'],
                org=test_settings['org']
            )
            health = client.health()
            client.close()
            
            # Store settings in .env or similar (implementation depends on your setup)
            # For now, we'll just show success message
            messages.success(request, 'Settings updated successfully')
            influx_settings = test_settings
            
        except Exception as e:
            messages.error(request, f'Failed to update settings: {str(e)}')
    
    return render(request, 'monitoring/settings.html', {
        'title': 'Settings',
        'active_page': 'settings',
        'influx': influx_settings,
        'last_updated': datetime.now().strftime('%Y-%m-%d %H:%M:%S') if request.method == "POST" else None
    })


# API Endpoints for Sensor Configuration
@login_required
@require_http_methods(["GET"])
def get_sensor_config(request, id):
    """Get details for a specific sensor configuration."""
    sensor = get_object_or_404(DeviceToken, id=id)
    return JsonResponse({
        'id': sensor.id,
        'token': sensor.token,
        'name': sensor.name,
        'created_at': sensor.created_at.isoformat()
    })


@login_required
@require_http_methods(["DELETE"])
def delete_sensor_config(request, id):
    """Delete a sensor configuration."""
    sensor = get_object_or_404(DeviceToken, id=id)
    sensor.delete()
    return JsonResponse({'status': 'success'})


# API Endpoints for AI Models
@login_required
@require_http_methods(["GET"])
def get_ai_model(request, id):
    """Get details for a specific AI model."""
    # TODO: Implement AI model retrieval
    return JsonResponse({'error': 'Not implemented'}, status=501)


@login_required
@require_http_methods(["DELETE"])
def delete_ai_model(request, id):
    """Delete an AI model."""
    # TODO: Implement AI model deletion
    return JsonResponse({'error': 'Not implemented'}, status=501)


@login_required
@require_http_methods(["POST"])
def test_ai_model(request, id):
    """Test an AI model with sample data."""
    # TODO: Implement AI model testing
    return JsonResponse({'error': 'Not implemented'}, status=501)


@login_required
@require_http_methods(["GET"])
def test_influx_connection(request):
    """Test connection to InfluxDB."""
    try:
        client = influxdb_client.InfluxDBClient(
            url=settings.INFLUXDB_URL,
            token=settings.INFLUXDB_TOKEN,
            org=settings.INFLUXDB_ORG
        )
        health = client.health()
        client.close()
        return JsonResponse({
            'status': 'success',
            'message': 'Connected successfully',
            'health': health
        })
    except Exception as e:
        return JsonResponse({
            'status': 'error',
            'message': str(e)
        }, status=500)


# Per-sensor detail view
@login_required
@require_http_methods(["GET"])
def sensor_detail(request, sensor_type):
    """Render detail page for a specific sensor type using realtime InfluxDB data."""
    from .influx_client import get_latest_data, get_history_data
    
    sensor_type = (sensor_type or '').lower()
    display_map = {
        'mq2': 'MQ2 - Gas Umum',
        'mq3': 'MQ3 - Alkohol/VOC',
        'mq135': 'MQ135 - Amonia/CO₂',
        'temperature': 'TEMPERATURE',
        'humidity': 'HUMIDITY'
    }
    display_name = display_map.get(sensor_type, sensor_type.upper())
    
    # Define thresholds for individual sensor status (berdasarkan dokumen penelitian)
    thresholds = {
        'mq2': {'warning': 400, 'danger': 800},      # Gas busuk (CH₄, H₂S)
        'mq3': {'warning': 800, 'danger': 1500},     # Alkohol / Etanol
        'mq135': {'warning': 600, 'danger': 900},    # Gas amonia / CO₂
        'temperature': {'warning': 30, 'danger': 35},
        'humidity': {'warning': 80, 'danger': 90}
    }
    
    # Get latest value from InfluxDB
    try:
        latest_data = get_latest_data()
        
        # Map sensor type to field name
        field_map = {
            'mq2': 'mq2',
            'mq3': 'mq3',
            'mq135': 'mq135',
            'temperature': 'suhu',
            'humidity': 'kelembapan'
        }
        field_name = field_map.get(sensor_type, sensor_type)
        last_value = float(latest_data.get(field_name, 0))
        
        # Calculate individual sensor status (not overall status)
        threshold = thresholds.get(sensor_type, {'warning': 50, 'danger': 100})
        if last_value >= threshold['danger']:
            status = 'Danger'
        elif last_value >= threshold['warning']:
            status = 'Warning'
        else:
            status = 'Normal'
        
        # Get historical data from InfluxDB
        history_data = get_history_data(limit=20)
        
        if history_data and len(history_data) > 0:
            # Reverse to show chronological order
            history_data = list(reversed(history_data))
            labels = [entry['timestamp'].split(' ')[1][:5] for entry in history_data]  # Extract HH:MM
            values = [float(entry.get(field_name, 0)) for entry in history_data]
        else:
            # Fallback to single point
            labels = [datetime.now().strftime('%H:%M')]
            values = [last_value]
            
    except Exception as e:
        print(f"ERROR getting sensor detail data: {e}")
        last_value = 0.0
        status = 'Unknown'
        labels = [datetime.now().strftime('%H:%M')]
        values = [0.0]
    
    # Determine unit based on sensor type
    unit = 'ppm'
    if sensor_type == 'temperature':
        unit = '°C'
    elif sensor_type == 'humidity':
        unit = '%'
    
    context = {
        'title': f'{display_name} Detail',
        'sensor_type': sensor_type,
        'display_name': display_name,
        'last_value': last_value,
        'unit': unit,
        'status': status,
        'labels_js': json.dumps(labels),
        'values_js': json.dumps(values),
    }

    return render(request, 'monitoring/sensor_detail.html', context)
