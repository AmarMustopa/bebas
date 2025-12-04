import os
try:
    from dotenv import load_dotenv
except Exception:
    # dotenv is optional; if not installed, define a noop loader
    def load_dotenv():
        return None

# Load environment variables from .env if present (noop if python-dotenv missing)
load_dotenv()

# --- Konfigurasi InfluxDB Anda ---
# Nilai-nilai ini diambil dari environment variable atau menggunakan default Anda
url = os.environ.get('INFLUX_URL', 'http://127.0.0.1:8034')
token = os.environ.get('INFLUX_TOKEN', 'Wv4fUOXPpqTi7FFQDVskdQjrLVEaweO0wh00QYNKOdM1_wpQArozJdxz7esh7j-B0V24P3CcSa-aXogVSco9Yg==')
org = os.environ.get('INFLUX_ORG', 'polinela')
bucket = os.environ.get('INFLUX_BUCKET', 'datamonitoring')

# Measurement name - HARUS SESUAI dengan data di InfluxDB
MEASUREMENT = 'monitoring'


def test_connection():
    """Test InfluxDB connection"""
    try:
        from influxdb_client import InfluxDBClient
        # set timeout to 10 seconds (10000 ms)
        with InfluxDBClient(url=url, token=token, org=org, timeout=10000) as client:
            health = client.health()
            if getattr(health, 'status', None) == "pass":
                print("✅ InfluxDB connection successful: pass")
            else:
                message = getattr(health, 'message', None) or getattr(health, 'status', None)
                print("❌ InfluxDB connection failed:", message)
    except Exception as e:
        print("❌ Connection failed:", e)


def get_latest_data():
    """Get latest sensor data from InfluxDB - OPTIMIZED"""
    try:
        from influxdb_client import InfluxDBClient
        with InfluxDBClient(url=url, token=token, org=org, timeout=30000) as client:
            query_api = client.query_api()
            
            # Query SEDERHANA - ambil data 5 menit terakhir, tanpa pivot
            query = f'''
                from(bucket: "{bucket}")
                |> range(start: -5m)
                |> filter(fn: (r) => r["_measurement"] == "monitoring")
                |> last()
            '''
            tables = query_api.query(query, org=org)
            out = {
                'suhu': 0.0,
                'kelembapan': 0.0,
                'mq2': 0.0,
                'mq3': 0.0,
                'mq135': 0.0,
                'status': None,
                'skorTotal': 0.0
            }
            
            # Ambil nilai dari setiap field
            for table in tables:
                for record in table.records:
                    field = record.get_field().lower()
                    value = record.get_value()
                    if field == 'suhu':
                        out['suhu'] = float(value) if value else 0.0
                    elif field == 'kelembapan':
                        out['kelembapan'] = float(value) if value else 0.0
                    elif field == 'mq2':
                        out['mq2'] = float(value) if value else 0.0
                    elif field == 'mq3':
                        out['mq3'] = float(value) if value else 0.0
                    elif field == 'mq135':
                        out['mq135'] = float(value) if value else 0.0
                    elif field == 'status':
                        out['status'] = int(value) if value is not None else None
                    elif field == 'skortotal':
                        out['skorTotal'] = float(value) if value else 0.0
                        
            print(f"DEBUG InfluxDB get_latest_data: {out}")
            return out
    except Exception as e:
        print(f"Error fetching data: {e}")
        return {'suhu': 0.0, 'kelembapan': 0.0, 'mq2': 0.0, 'mq3': 0.0, 'mq135': 0.0, "error": str(e)}

def get_history_data(limit=50):
    """Get historical sensor data from InfluxDB (last N records)"""
    try:
        from influxdb_client import InfluxDBClient
        from datetime import datetime
        
        with InfluxDBClient(url=url, token=token, org=org, timeout=10000) as client:
            query_api = client.query_api()
            
            # Query untuk mengambil data history dengan measurement monitoring
            query = f'''
                from(bucket:"{bucket}")
                |> range(start: -24h)
                |> filter(fn: (r) => r["_measurement"] == "monitoring")
                |> sort(columns:["_time"], desc: true)
                |> limit(n:{limit})
            '''
            tables = query_api.query(query, org=org)
            
            # Group data by timestamp
            data_by_time = {}
            
            for table in tables:
                for record in table.records:
                    timestamp = record.get_time()
                    field = record.get_field().lower()
                    value = record.get_value()
                    
                    timestamp_str = timestamp.strftime('%Y-%m-%d %H:%M:%S')
                    
                    if timestamp_str not in data_by_time:
                        data_by_time[timestamp_str] = {
                            'timestamp': timestamp_str,
                            'suhu': 0.0,
                            'kelembapan': 0.0,
                            'mq2': 0.0,
                            'mq3': 0.0,
                            'mq135': 0.0,
                            'status': None,
                            'skorTotal': 0.0
                        }
                    
                    if field == 'suhu':
                        data_by_time[timestamp_str]['suhu'] = float(value)
                    elif field == 'kelembapan':
                        data_by_time[timestamp_str]['kelembapan'] = float(value)
                    elif field == 'mq2':
                        data_by_time[timestamp_str]['mq2'] = float(value)
                    elif field == 'mq3':
                        data_by_time[timestamp_str]['mq3'] = float(value)
                    elif field == 'mq135':
                        data_by_time[timestamp_str]['mq135'] = float(value)
                    elif field == 'status':
                        data_by_time[timestamp_str]['status'] = int(value) if value is not None else None
                    elif field == 'skortotal':
                        data_by_time[timestamp_str]['skorTotal'] = float(value)
            
            # Convert to list and sort by timestamp descending
            result = list(data_by_time.values())
            result.sort(key=lambda x: x['timestamp'], reverse=True)
            
            return result[:limit]
            
    except Exception as e:
        print(f"Error fetching history data: {e}")
        return []


def get_latest_raw(limit=100):
    """Return raw recent records from InfluxDB for debugging. (Ini untuk cek nama field jika 0.0 masih muncul)"""
    try:
        from influxdb_client import InfluxDBClient
        with InfluxDBClient(url=url, token=token, org=org, timeout=10000) as client:
            query_api = client.query_api()
            query = f'''
                from(bucket:"{bucket}")
                |> range(start: -24h)
                |> sort(columns:["_time"], desc: true)
                |> limit(n:{limit})
            '''
            tables = query_api.query(query, org=org)
            out = []
            for table in tables:
                for record in table.records:
                    out.append({
                        'measurement': record.get_measurement(),
                        'field': record.get_field(),
                        'value': record.get_value(),
                        'time': str(record.get_time()),
                        'values': dict(record.values) if hasattr(record, 'values') else None,
                    })
            return out
    except Exception as e:
        print(f"Error fetching raw data: {e}")
        return {"error": str(e)}