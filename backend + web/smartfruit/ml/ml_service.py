"""
ML Service untuk Smart Beef Monitoring
Continual Learning dengan RandomForestClassifier
"""
import os
import pandas as pd
import numpy as np
import joblib
from sklearn.ensemble import RandomForestClassifier
from sklearn.model_selection import train_test_split
from sklearn.metrics import accuracy_score, classification_report
from datetime import datetime
import logging

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger('ML_Service')

# Path configuration
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
DATASET_PATH = os.path.join(BASE_DIR, 'dataset_layak_tidaklayak.csv')
MODEL_PATH = os.path.join(BASE_DIR, 'model.pkl')

class MLService:
    """Service untuk prediksi dan continual learning"""
    
    def __init__(self):
        self.model = None
        self.feature_names = ['mq2', 'mq3', 'mq135', 'humidity', 'temperature']
        self.load_model()
    
    def load_model(self):
        """Load model dari file, jika tidak ada maka train model baru"""
        try:
            if os.path.exists(MODEL_PATH):
                self.model = joblib.load(MODEL_PATH)
                logger.info(f"✅ Model loaded from {MODEL_PATH}")
            else:
                logger.warning("⚠️ Model not found. Training new model...")
                self.train_model()
        except Exception as e:
            logger.error(f"❌ Error loading model: {e}")
            self.train_model()
    
    def train_model(self):
        """Train model dengan dataset yang ada"""
        try:
            # Load dataset
            if not os.path.exists(DATASET_PATH):
                logger.error(f"❌ Dataset not found: {DATASET_PATH}")
                return False
            
            df = pd.read_csv(DATASET_PATH)
            logger.info(f"📊 Dataset loaded: {len(df)} records")
            
            # Prepare features and target
            X = df[self.feature_names]
            y = df['status']
            
            # Split data
            X_train, X_test, y_train, y_test = train_test_split(
                X, y, test_size=0.2, random_state=42
            )
            
            # Train model
            logger.info("🔄 Training RandomForestClassifier...")
            self.model = RandomForestClassifier(
                n_estimators=100,
                max_depth=10,
                random_state=42,
                n_jobs=-1
            )
            self.model.fit(X_train, y_train)
            
            # Evaluate
            y_pred = self.model.predict(X_test)
            accuracy = accuracy_score(y_test, y_pred)
            
            logger.info(f"✅ Model trained successfully!")
            logger.info(f"📈 Accuracy: {accuracy:.2%}")
            logger.info("\n" + classification_report(y_test, y_pred))
            
            # Save model
            joblib.dump(self.model, MODEL_PATH)
            logger.info(f"💾 Model saved to {MODEL_PATH}")
            
            return True
            
        except Exception as e:
            logger.error(f"❌ Error training model: {e}")
            return False
    
    def predict_status(self, mq2, mq3, mq135, humidity, temperature):
        """
        Prediksi status kelayakan daging
        
        Args:
            mq2: Nilai sensor MQ2 (Gas Umum)
            mq3: Nilai sensor MQ3 (Alkohol/VOC)
            mq135: Nilai sensor MQ135 (Amonia/CO2)
            humidity: Kelembapan (%)
            temperature: Suhu (°C)
        
        Returns:
            dict: {
                'status': 'Layak' atau 'Tidak Layak',
                'confidence': float (0-1),
                'probabilities': {'Layak': float, 'Tidak Layak': float}
            }
        """
        try:
            if self.model is None:
                logger.error("❌ Model not loaded")
                return {
                    'status': 'Error',
                    'confidence': 0.0,
                    'probabilities': {}
                }
            
            # Prepare input
            features = np.array([[mq2, mq3, mq135, humidity, temperature]])
            
            # Predict
            prediction = self.model.predict(features)[0]
            probabilities = self.model.predict_proba(features)[0]
            
            # Get class labels
            classes = self.model.classes_
            prob_dict = {classes[i]: float(probabilities[i]) for i in range(len(classes))}
            
            confidence = max(probabilities)
            
            logger.info(f"🔮 Prediction: {prediction} (confidence: {confidence:.2%})")
            
            return {
                'status': prediction,
                'confidence': float(confidence),
                'probabilities': prob_dict,
                'timestamp': datetime.now().strftime('%Y-%m-%d %H:%M:%S')
            }
            
        except Exception as e:
            logger.error(f"❌ Error predicting: {e}")
            return {
                'status': 'Error',
                'confidence': 0.0,
                'probabilities': {}
            }
    
    def add_realtime_data(self, mq2, mq3, mq135, humidity, temperature, status):
        """
        Tambahkan data realtime ke dataset untuk continual learning
        
        Args:
            mq2, mq3, mq135, humidity, temperature: Nilai sensor
            status: Status aktual ('Layak' atau 'Tidak Layak')
        """
        try:
            # Buat dataframe baru
            new_data = pd.DataFrame([{
                'mq2': mq2,
                'mq3': mq3,
                'mq135': mq135,
                'humidity': humidity,
                'temperature': temperature,
                'status': status
            }])
            
            # Append ke CSV
            if os.path.exists(DATASET_PATH):
                new_data.to_csv(DATASET_PATH, mode='a', header=False, index=False)
            else:
                new_data.to_csv(DATASET_PATH, mode='w', header=True, index=False)
            
            logger.info(f"📝 Data added to dataset: MQ2={mq2}, MQ3={mq3}, MQ135={mq135}, Status={status}")
            
            return True
            
        except Exception as e:
            logger.error(f"❌ Error adding data: {e}")
            return False
    
    def retrain_model(self):
        """Retrain model dengan dataset terbaru (continual learning)"""
        logger.info("🔄 Starting continual learning...")
        success = self.train_model()
        if success:
            self.load_model()  # Reload model baru
        return success
    
    def get_dataset_info(self):
        """Dapatkan informasi dataset"""
        try:
            if os.path.exists(DATASET_PATH):
                df = pd.read_csv(DATASET_PATH)
                return {
                    'total_records': len(df),
                    'layak_count': len(df[df['status'] == 'Layak']),
                    'tidak_layak_count': len(df[df['status'] == 'Tidak Layak']),
                    'last_updated': datetime.fromtimestamp(os.path.getmtime(DATASET_PATH)).strftime('%Y-%m-%d %H:%M:%S')
                }
            return {}
        except Exception as e:
            logger.error(f"❌ Error getting dataset info: {e}")
            return {}


# Global instance
ml_service = MLService()


# Public functions untuk digunakan di views
def predict_status(mq2, mq3, mq135, humidity, temperature):
    """Wrapper function untuk prediksi"""
    return ml_service.predict_status(mq2, mq3, mq135, humidity, temperature)


def add_realtime_data(mq2, mq3, mq135, humidity, temperature, status):
    """Wrapper function untuk menambah data"""
    return ml_service.add_realtime_data(mq2, mq3, mq135, humidity, temperature, status)


def retrain_model():
    """Wrapper function untuk retrain model"""
    return ml_service.retrain_model()


def get_dataset_info():
    """Wrapper function untuk info dataset"""
    return ml_service.get_dataset_info()
