import pandas as pd
import numpy as np
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import StandardScaler
from sklearn.ensemble import RandomForestClassifier
import joblib
import os

def train_model_quick():
    """Versi cepat untuk testing dengan data lebih sedikit"""
    # Buat contoh data lebih sedikit
    np.random.seed(42)
    n_samples = 100  # dikurangi dari 1000 jadi 100 samples
    
    # Generate synthetic data
    data = pd.DataFrame({
        'suhu': np.random.normal(28, 3, n_samples),
        'kelembapan': np.random.normal(65, 10, n_samples),
        'mq2': np.random.normal(50, 20, n_samples),
        'mq3': np.random.normal(30, 10, n_samples),
        'mq135': np.random.normal(40, 15, n_samples),
    })
    
    # Rules sederhana untuk klasifikasi
    conditions = [
        # Kondisi ideal
        (data['suhu'].between(25, 30)) & 
        (data['kelembapan'].between(60, 70)) & 
        (data['mq2'] < 60) & 
        (data['mq3'] < 40) & 
        (data['mq135'] < 50),
        
        # Kondisi warning
        (data['suhu'].between(23, 32)) & 
        (data['kelembapan'].between(55, 75))
    ]
    choices = ['LAYAK', 'WARNING', 'TIDAK_LAYAK']
    data['status'] = np.select(conditions, choices[:2], default=choices[2])

    # Prepare features dan target
    X = data[['suhu', 'kelembapan', 'mq2', 'mq3', 'mq135']]
    y = data['status']

    # Train dengan data lebih sedikit
    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)

    # Scale features
    scaler = StandardScaler()
    X_train_scaled = scaler.fit_transform(X_train)
    X_test_scaled = scaler.transform(X_test)

    # Model lebih sederhana (10 trees instead of 100)
    model = RandomForestClassifier(n_estimators=10, random_state=42)
    model.fit(X_train_scaled, y_train)

    # Evaluate
    train_score = model.score(X_train_scaled, y_train)
    test_score = model.score(X_test_scaled, y_test)
    print(f"Training accuracy: {train_score:.2f}")
    print(f"Testing accuracy: {test_score:.2f}")

    # Save model
    os.makedirs('models', exist_ok=True)
    joblib.dump(model, 'models/fruit_quality_model.joblib')
    joblib.dump(scaler, 'models/scaler.joblib')
    print("Model saved as 'models/fruit_quality_model.joblib'")
    print("Scaler saved as 'models/scaler.joblib'")

    return model, scaler

def test_prediction(model, scaler):
    """Test model dengan beberapa contoh data"""
    test_cases = [
        # Kondisi ideal
        {
            'suhu': 27.5,
            'kelembapan': 65,
            'mq2': 45,
            'mq3': 30,
            'mq135': 40
        },
        # Kondisi warning
        {
            'suhu': 32,
            'kelembapan': 75,
            'mq2': 58,
            'mq3': 38,
            'mq135': 48
        },
        # Kondisi tidak layak
        {
            'suhu': 35,
            'kelembapan': 85,
            'mq2': 70,
            'mq3': 50,
            'mq135': 60
        }
    ]
    
    print("\nTest Predictions:")
    for case in test_cases:
        X = np.array([[
            case['suhu'],
            case['kelembapan'],
            case['mq2'],
            case['mq3'],
            case['mq135']
        ]])
        X_scaled = scaler.transform(X)
        prediction = model.predict(X_scaled)[0]
        probabilities = model.predict_proba(X_scaled)[0]
        
        print(f"\nInput: {case}")
        print(f"Predicted: {prediction}")
        print(f"Confidence: {max(probabilities):.2%}")

if __name__ == '__main__':
    print("Training quick model...")
    model, scaler = train_model_quick()
    test_prediction(model, scaler)