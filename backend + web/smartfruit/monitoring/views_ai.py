from django.http import JsonResponse
from django.views.decorators.http import require_http_methods
from django.contrib.auth.decorators import login_required
import joblib
import os
from .models import AIModel
import numpy as np

def load_latest_model():
    """Load the latest trained model and scaler"""
    model_path = 'models/fruit_quality_model.joblib'
    scaler_path = 'models/scaler.joblib'
    
    if not (os.path.exists(model_path) and os.path.exists(scaler_path)):
        return None, None
        
    try:
        model = joblib.load(model_path)
        scaler = joblib.load(scaler_path)
        return model, scaler
    except Exception as e:
        print(f"Error loading model: {e}")
        return None, None

@login_required
@require_http_methods(["POST"])
def predict_quality(request):
    """API endpoint for fruit quality prediction"""
    try:
        # Load model
        model, scaler = load_latest_model()
        if not model or not scaler:
            return JsonResponse({
                'error': 'Model not found. Please train the model first.'
            }, status=404)
            
        # Get sensor data from request
        data = json.loads(request.body)
        suhu = float(data.get('suhu', 0))
        kelembapan = float(data.get('kelembapan', 0))
        mq2 = float(data.get('mq2', 0))
        mq3 = float(data.get('mq3', 0))
        mq135 = float(data.get('mq135', 0))
        
        # Format input
        X = np.array([[suhu, kelembapan, mq2, mq3, mq135]])
        
        # Scale input
        X_scaled = scaler.transform(X)
        
        # Make prediction
        prediction = model.predict(X_scaled)[0]
        probabilities = model.predict_proba(X_scaled)[0]
        
        return JsonResponse({
            'status': prediction,
            'confidence': float(max(probabilities)),
            'probabilities': {
                'LAYAK': float(probabilities[list(model.classes_).index('LAYAK')]),
                'WARNING': float(probabilities[list(model.classes_).index('WARNING')]),
                'TIDAK_LAYAK': float(probabilities[list(model.classes_).index('TIDAK_LAYAK')])
            }
        })
        
    except Exception as e:
        return JsonResponse({'error': str(e)}, status=400)

@login_required
def model_info(request):
    """Get information about the current AI model"""
    model, _ = load_latest_model()
    if not model:
        return JsonResponse({
            'status': 'No model found',
            'features': None,
            'classes': None
        })
        
    return JsonResponse({
        'status': 'Model loaded',
        'features': ['suhu', 'kelembapan', 'mq2', 'mq3', 'mq135'],
        'classes': list(model.classes_)
    })