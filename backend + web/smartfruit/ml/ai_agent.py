"""
AI Agent untuk Analisis Realtime Sensor Smart Beef Monitoring
Logika: SEMUA sensor NORMAL → LAYAK, ADA yang WARNING → TIDAK LAYAK
"""
from collections import deque
from datetime import datetime
import statistics


class SensorAIAgent:
    """AI Agent untuk analisis sensor realtime dengan adaptive learning"""
    
    def __init__(self):
        # Default thresholds (rentang normal)
        self.thresholds = {
            'suhu': {'min': 20, 'max': 35, 'unit': '°C', 'name': 'Suhu'},
                'kelembapan': {'min': 40, 'max': 85, 'unit': '%', 'name': 'Kelembaban'},
            'mq2': {'min': 0, 'max': 300, 'unit': 'ppm', 'name': 'Gas Umum (MQ2)'},
            'mq3': {'min': 0, 'max': 300, 'unit': 'ppm', 'name': 'Alkohol (MQ3)'},
            'mq135': {'min': 0, 'max': 300, 'unit': 'ppm', 'name': 'Amonia (MQ135)'}
        }
        
        # Buffer untuk adaptive learning (200 data terakhir)
        self.history_buffer = {
            'suhu': deque(maxlen=200),
            'kelembapan': deque(maxlen=200),
            'mq2': deque(maxlen=200),
            'mq3': deque(maxlen=200),
            'mq135': deque(maxlen=200)
        }
        
        self.adaptive_enabled = True
        self.total_readings = 0
    
    def validate_data(self, value):
        """
        Validasi nilai sensor: tidak null, tidak ekstrem
        
        Returns:
            float: nilai yang valid atau 0.0 jika invalid
        """
        try:
            val = float(value) if value is not None else 0.0
            
            # Cek nilai ekstrem (negatif atau terlalu besar)
            if val < 0 or val > 10000:
                return 0.0
            
            return round(val, 2)
        except (ValueError, TypeError):
            return 0.0
    
    def get_adaptive_threshold(self, sensor_name):
        """
        Hitung threshold adaptif berdasarkan data historis
        Menggunakan mean ± 2×std
        
        Returns:
            dict: {'min': float, 'max': float, 'adapted': bool}
        """
        history = self.history_buffer.get(sensor_name, deque())
        default = self.thresholds[sensor_name]
        
        # Minimal 50 data untuk adaptive
        if len(history) < 50:
            return {
                'min': default['min'],
                'max': default['max'],
                'adapted': False
            }
        
        try:
            mean_val = statistics.mean(history)
            std_val = statistics.stdev(history) if len(history) > 1 else 0
            
            # Adaptive threshold: mean ± 2×std
            adaptive_min = mean_val - 2 * std_val
            adaptive_max = mean_val + 2 * std_val
            
            # Pastikan tidak keluar dari batas default terlalu jauh
            adaptive_min = max(default['min'] * 0.5, adaptive_min)
            adaptive_max = min(default['max'] * 1.5, adaptive_max)
            
            return {
                'min': round(adaptive_min, 2),
                'max': round(adaptive_max, 2),
                'adapted': True
            }
        except:
            return {
                'min': default['min'],
                'max': default['max'],
                'adapted': False
            }
    
    def evaluate_sensor(self, sensor_name, value):
        """
        Evaluasi status satu sensor
        
        Returns:
            dict: {
                'status': 'NORMAL' atau 'WARNING',
                'value': nilai sensor,
                'threshold_used': 'default' atau 'adaptive',
                'threshold': dict batas yang digunakan,
                'reason': alasan jika WARNING
            }
        """
        # Get threshold (adaptive jika tersedia, default jika tidak)
        adaptive_threshold = self.get_adaptive_threshold(sensor_name)
        
        threshold_min = adaptive_threshold['min']
        threshold_max = adaptive_threshold['max']
        threshold_type = 'adaptive' if adaptive_threshold['adapted'] else 'default'
        
        sensor_info = self.thresholds[sensor_name]
        
        # Evaluasi status
        if value < threshold_min:
            return {
                'status': 'WARNING',
                'value': value,
                'threshold_used': threshold_type,
                'threshold': {'min': threshold_min, 'max': threshold_max},
                'reason': f"{sensor_info['name']} terlalu rendah ({value} {sensor_info['unit']} < {threshold_min} {sensor_info['unit']})"
            }
        elif value > threshold_max:
            return {
                'status': 'WARNING',
                'value': value,
                'threshold_used': threshold_type,
                'threshold': {'min': threshold_min, 'max': threshold_max},
                'reason': f"{sensor_info['name']} terlalu tinggi ({value} {sensor_info['unit']} > {threshold_max} {sensor_info['unit']})"
            }
        else:
            return {
                'status': 'NORMAL',
                'value': value,
                'threshold_used': threshold_type,
                'threshold': {'min': threshold_min, 'max': threshold_max},
                'reason': f"{sensor_info['name']} dalam rentang normal ({threshold_min}-{threshold_max} {sensor_info['unit']})"
            }
    
    def analyze_realtime(self, suhu, kelembapan, mq2, mq3, mq135):
        """
        Analisis realtime data sensor
        Logika: SEMUA NORMAL → LAYAK, ADA WARNING → TIDAK LAYAK
        
        Returns:
            dict: hasil analisis AI Agent
        """
        # 1. Validasi data
        sensor_data = {
            'suhu': self.validate_data(suhu),
            'kelembapan': self.validate_data(kelembapan),
            'mq2': self.validate_data(mq2),
            'mq3': self.validate_data(mq3),
            'mq135': self.validate_data(mq135)
        }
        
        # 2. Evaluasi setiap sensor
        sensor_results = {}
        all_normal = True
        warning_sensors = []
        
        for sensor, value in sensor_data.items():
            result = self.evaluate_sensor(sensor, value)
            sensor_results[sensor] = result
            
            if result['status'] == 'WARNING':
                all_normal = False
                warning_sensors.append(result['reason'])
        
        # 3. Keputusan akhir
        final_status = 'LAYAK' if all_normal else 'TIDAK LAYAK'
        
        # 4. Penjelasan
        if all_normal:
            explanation = "✅ Semua sensor dalam kondisi NORMAL. Produk LAYAK konsumsi."
        else:
            explanation = f"⚠️ Produk TIDAK LAYAK konsumsi. Alasan: {'; '.join(warning_sensors)}"
        
        # 5. Tambahkan ke history untuk adaptive learning
        for sensor, value in sensor_data.items():
            self.history_buffer[sensor].append(value)
        
        self.total_readings += 1
        
        # 6. Hitung confidence
        confidence = self.calculate_confidence(sensor_results)
        
        return {
            'timestamp': datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
            'sensor_values': sensor_data,
            'sensor_status': sensor_results,
            'final_status': final_status,
            'explanation': explanation,
            'confidence': confidence,
            'ai_info': {
                'total_readings': self.total_readings,
                'adaptive_enabled': self.adaptive_enabled,
                'adaptive_active': self.total_readings >= 50
            }
        }
    
    def calculate_confidence(self, sensor_results):
        """
        Hitung confidence berdasarkan seberapa jauh nilai dari batas
        
        Returns:
            float: 0.0 - 1.0
        """
        confidences = []
        
        for sensor, result in sensor_results.items():
            value = result['value']
            threshold = result['threshold']
            
            min_val = threshold['min']
            max_val = threshold['max']
            
            if value < min_val:
                # Di bawah minimum
                distance = abs(min_val - value)
                range_size = max_val - min_val
                confidence = max(0, 1 - (distance / (range_size * 2)))
            elif value > max_val:
                # Di atas maximum
                distance = abs(value - max_val)
                range_size = max_val - min_val
                confidence = max(0, 1 - (distance / (range_size * 2)))
            else:
                # Dalam rentang normal - confidence tinggi
                center = (min_val + max_val) / 2
                distance = abs(value - center)
                max_distance = (max_val - min_val) / 2
                confidence = 1 - (distance / max_distance * 0.3)  # Max 30% pengurangan
            
            confidences.append(max(0, min(1, confidence)))
        
        return round(sum(confidences) / len(confidences), 2) if confidences else 0.5
    
    def get_info(self):
        """Get info AI Agent"""
        return {
            'total_readings': self.total_readings,
            'adaptive_enabled': self.adaptive_enabled,
            'adaptive_active': self.total_readings >= 50,
            'buffer_sizes': {
                sensor: len(history)
                for sensor, history in self.history_buffer.items()
            }
        }


# Global AI Agent instance
ai_agent = SensorAIAgent()


def analyze_sensor_data(suhu, kelembapan, mq2, mq3, mq135):
    """
    Wrapper function untuk analisis sensor
    
    Returns:
        dict: hasil analisis AI Agent
    """
    return ai_agent.analyze_realtime(suhu, kelembapan, mq2, mq3, mq135)


def get_ai_info():
    """Get info AI Agent"""
    return ai_agent.get_info()


def reset_ai_agent():
    """Reset AI Agent"""
    global ai_agent
    ai_agent = SensorAIAgent()
    return {'status': 'success', 'message': 'AI Agent reset successfully'}
