from flask import Flask, request, jsonify
from flask_socketio import SocketIO, emit

app = Flask(__name__)
app.config['SECRET_KEY'] = 'secret!'  # Replace with a secure key in production
socketio = SocketIO(app, cors_allowed_origins="*")

# Global variable to store the latest sensor data
latest_data = {
    "temperature": None,
    "humidity": None,
    "gas": None,
    "status": None
}

@app.route('/api/sensor', methods=['POST'])
def receive_sensor_data():
    """Endpoint to receive sensor data from ESP32."""
    global latest_data
    data = request.json
    if not data:
        return jsonify({"error": "Invalid data"}), 400

    # Update the latest data
    latest_data.update({
        "temperature": data.get("temperature"),
        "humidity": data.get("humidity"),
        "gas": data.get("gas"),
        "status": data.get("status")
    })

    # Broadcast the updated data to all connected clients
    socketio.emit('update_data', latest_data)

    return jsonify({"message": "Data received successfully"}), 200

@app.route('/api/latest', methods=['GET'])
def get_latest_data():
    """Endpoint to retrieve the latest sensor data."""
    return jsonify(latest_data)

@app.route('/')
def home():
    return "Welcome to the Smart Beef Freshness Monitoring API!"

if __name__ == '__main__':
    print("Server is running on http://127.0.0.1:5001")
    socketio.run(app, host='0.0.0.0', port=5001)