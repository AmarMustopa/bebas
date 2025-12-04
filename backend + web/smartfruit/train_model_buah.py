import pandas as pd
import numpy as np
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import StandardScaler
from sklearn.ensemble import RandomForestClassifier
import joblib
import os

def train_model():
    # 1. Load data (contoh data, sesuaikan dengan data sensor Anda)
    try:
        data = pd.read_csv('data_sensor.csv')
    except FileNotFoundError:
        # Buat contoh data jika file belum ada
        np.random.seed(42)
        n_samples = 1000
        
        # Generate synthetic data
        data = pd.DataFrame({
            'suhu': np.random.normal(28, 3, n_samples),  # suhu normal ~28°C
            'kelembapan': np.random.normal(65, 10, n_samples),  # kelembapan normal ~65%
            'mq2': np.random.normal(50, 20, n_samples),  # gas umum
            'mq3': np.random.normal(30, 10, n_samples),  # alkohol/VOC
            'mq135': np.random.normal(40, 15, n_samples),  # amonia/CO2
        })
        
        # Buat label berdasarkan rules sederhana
        conditions = [
            # Kondisi ideal
            (data['suhu'].between(25, 30)) & 
            (data['kelembapan'].between(60, 70)) & 
            (data['mq2'] < 60) & 
            (data['mq3'] < 40) & 
            (data['mq135'] < 50),
            
            # Kondisi warning
            (data['suhu'].between(23, 32)) & 
            (data['kelembapan'].between(55, 75)),
            
            # Kondisi tidak layak
        ]
        choices = ['LAYAK', 'WARNING', 'TIDAK_LAYAK']
        data['status'] = np.select(conditions, choices[:2], default=choices[2])
        
        # Simpan data synthetic untuk referensi
        data.to_csv('data_sensor.csv', index=False)
        print("Created synthetic dataset in data_sensor.csv")

    # 2. Prepare features dan target
    X = data[['suhu', 'kelembapan', 'mq2', 'mq3', 'mq135']]
    y = data['status']

    # 3. Split data
    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)

    # 4. Scale features
    scaler = StandardScaler()
    X_train_scaled = scaler.fit_transform(X_train)
    X_test_scaled = scaler.transform(X_test)

    # 5. Train model
    model = RandomForestClassifier(n_estimators=100, random_state=42)
    model.fit(X_train_scaled, y_train)

    # 6. Evaluate model
    train_score = model.score(X_train_scaled, y_train)
    test_score = model.score(X_test_scaled, y_test)
    print(f"Training accuracy: {train_score:.2f}")
    print(f"Testing accuracy: {test_score:.2f}")

    # 7. Save model dan scaler
    os.makedirs('models', exist_ok=True)
    joblib.dump(model, 'models/fruit_quality_model.joblib')
    joblib.dump(scaler, 'models/scaler.joblib')
    print("Model saved as 'models/fruit_quality_model.joblib'")
    print("Scaler saved as 'models/scaler.joblib'")

    return model, scaler

def predict_quality(model, scaler, suhu, kelembapan, mq2, mq3, mq135):
    """Predict fruit quality from sensor data"""
    # Format input data
    X = np.array([[suhu, kelembapan, mq2, mq3, mq135]])
    
    # Scale input
    X_scaled = scaler.transform(X)
    
    # Make prediction
    prediction = model.predict(X_scaled)[0]
    probabilities = model.predict_proba(X_scaled)[0]
    
    return {
        'status': prediction,
        'confidence': float(max(probabilities)),
        'probabilities': {
            'LAYAK': float(probabilities[list(model.classes_).index('LAYAK')]),
            'WARNING': float(probabilities[list(model.classes_).index('WARNING')]),
            'TIDAK_LAYAK': float(probabilities[list(model.classes_).index('TIDAK_LAYAK')])
        }
    }

if __name__ == '__main__':
    # Train model
    model, scaler = train_model()
    
    # Test prediction
    test_data = {
        'suhu': 27.5,
        'kelembapan': 65,
        'mq2': 45,
        'mq3': 30,
        'mq135': 40
    }
    
    result = predict_quality(
        model, scaler,
        test_data['suhu'],
        test_data['kelembapan'],
        test_data['mq2'],
        test_data['mq3'],
        test_data['mq135']
    )
    
    print("\nTest Prediction:")
    print(f"Input data: {test_data}")
    print(f"Predicted status: {result['status']}")
    print(f"Confidence: {result['confidence']:.2%}")
    print("Class probabilities:")
    for status, prob in result['probabilities'].items():
        print(f"  {status}: {prob:.2%}")