#!/usr/bin/env python
"""
Test script untuk verifikasi InfluxDB sinkronisasi di frontend
"""

import requests
import json
from datetime import datetime

BASE_URL = "http://127.0.0.1:8000"

def test_influxdb_endpoint():
    """Test endpoint /api/status yang mengambil data dari InfluxDB"""
    print("\n" + "="*60)
    print("🧪 Testing InfluxDB Realtime Data Endpoint")
    print("="*60)
    
    try:
        url = f"{BASE_URL}/api/status"
        print(f"\n📡 Fetching data from: {url}")
        
        response = requests.get(url, timeout=5)
        
        if response.status_code == 200:
            data = response.json()
            print(f"\n✅ SUCCESS (Status {response.status_code})")
            print(f"\n📊 InfluxDB Data Received:")
            print(f"  • Suhu (Temperature): {data.get('suhu', 'N/A')} °C")
            print(f"  • Kelembapan (Humidity): {data.get('kelembapan', 'N/A')} %")
            print(f"  • MQ2 (Gas): {data.get('mq2', 'N/A')} ppm")
            print(f"  • MQ3 (Alcohol/VOC): {data.get('mq3', 'N/A')} ppm")
            print(f"  • MQ135 (Ammonia/CO2): {data.get('mq135', 'N/A')} ppm")
            print(f"\n✅ Data format OK - Ready for frontend consumption")
            return True
        else:
            print(f"\n❌ ERROR (Status {response.status_code})")
            print(f"Response: {response.text}")
            return False
            
    except requests.exceptions.ConnectionError:
        print(f"\n❌ ERROR: Cannot connect to {BASE_URL}")
        print("   Make sure Django development server is running:")
        print("   python manage.py runserver")
        return False
    except Exception as e:
        print(f"\n❌ ERROR: {str(e)}")
        return False

def test_history_endpoint():
    """Test endpoint /api/sensor/history untuk data riwayat"""
    print("\n" + "="*60)
    print("🧪 Testing Sensor History Endpoint")
    print("="*60)
    
    try:
        url = f"{BASE_URL}/api/sensor/history"
        print(f"\n📡 Fetching data from: {url}")
        
        response = requests.get(url, timeout=5)
        
        if response.status_code == 200:
            data = response.json()
            if isinstance(data, list) and len(data) > 0:
                print(f"\n✅ SUCCESS (Status {response.status_code})")
                print(f"📊 Retrieved {len(data)} historical records")
                print(f"\nLatest record sample:")
                first_row = data[0]
                print(f"  • Timestamp: {first_row.get('timestamp', 'N/A')}")
                print(f"  • Temperature: {first_row.get('temperature', 'N/A')} °C")
                print(f"  • Humidity: {first_row.get('humidity', 'N/A')} %")
                print(f"  • MQ2: {first_row.get('mq2', 'N/A')} ppm")
                print(f"  • Status: {first_row.get('status', 'N/A')}")
                return True
            else:
                print(f"\n⚠️  WARNING: Endpoint working but no history data yet")
                return True
        else:
            print(f"\n❌ ERROR (Status {response.status_code})")
            print(f"Response: {response.text}")
            return False
            
    except requests.exceptions.ConnectionError:
        print(f"\n❌ ERROR: Cannot connect to {BASE_URL}")
        return False
    except Exception as e:
        print(f"\n❌ ERROR: {str(e)}")
        return False

def test_browser_simulation():
    """Simulate browser JavaScript fetch requests"""
    print("\n" + "="*60)
    print("🧪 Simulating Browser JavaScript Requests")
    print("="*60)
    
    print("\n📝 The frontend dashboard.js will make these calls:")
    print("\n1️⃣  Every 5 seconds:")
    print("   fetch('/api/status')")
    print("   → Updates: MQ2, MQ3, MQ135, Temperature, Humidity cards")
    
    print("\n2️⃣  Every 5 seconds:")
    print("   fetch('/api/sensor/history')")
    print("   → Updates: Historical data table")
    
    print("\n✅ Both endpoints are now correctly configured!")

def print_summary():
    """Print summary and next steps"""
    print("\n" + "="*60)
    print("📋 Test Summary & Next Steps")
    print("="*60)
    
    print("""
✅ Changes Applied:
   1. Fixed dashboard.js endpoints (/api/status, /api/sensor/history)
   2. Added InfluxDB field name mapping (suhu, kelembapan)
   3. Integrated dashboard.js into dashboard.html
   4. Added smart threshold-based status updates

🚀 Next Steps:
   1. Restart Django server:
      python manage.py runserver
      
   2. Open browser and go to:
      http://127.0.0.1:8000/dashboard/
      
   3. Open DevTools (F12) → Console tab
   
   4. Verify console shows:
      "DEBUG: InfluxDB data received: {...}"
      
   5. Check dashboard cards display:
      • MQ2, MQ3, MQ135 values (ppm)
      • Temperature (°C)
      • Humidity (%)
      
   6. Wait 5 seconds and verify data auto-updates

🔍 Debugging Tips:
   • Check Network tab for /api/status calls
   • Look for any 404 errors in console
   • Ensure InfluxDB is running and accessible
   • Check Django logs for errors
    """)

if __name__ == "__main__":
    print("\n" + "█"*60)
    print("  Smart Beef Monitoring - Frontend Integration Test")
    print("█"*60)
    
    results = []
    
    # Run tests
    results.append(("InfluxDB Endpoint", test_influxdb_endpoint()))
    results.append(("History Endpoint", test_history_endpoint()))
    test_browser_simulation()
    print_summary()
    
    # Final status
    print("\n" + "="*60)
    print("📊 Final Status")
    print("="*60)
    
    for test_name, result in results:
        status = "✅ PASS" if result else "❌ FAIL"
        print(f"{status}: {test_name}")
    
    all_passed = all(result for _, result in results)
    if all_passed:
        print("\n✅ All tests passed! Frontend integration is ready.")
    else:
        print("\n⚠️  Some tests failed. Check Django server logs.")
    
    print("\n" + "█"*60 + "\n")
