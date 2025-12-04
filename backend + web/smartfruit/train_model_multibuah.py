import pickle
from sklearn.tree import DecisionTreeClassifier
import numpy as np

# Data dummy multi-buah: [temperature, humidity, gas]
# Label status: 0=LAYAK, 1=TIDAK LAYAK
# Label jenis_buah: 0=Apel, 1=Pisang, 2=Mangga
X = np.array([
    [25, 60, 0.1],  # Apel, LAYAK
    [30, 80, 0.2],  # Pisang, TIDAK LAYAK
    [28, 70, 0.15], # Apel, LAYAK
    [32, 85, 0.25], # Pisang, TIDAK LAYAK
    [26, 65, 0.12], # Mangga, LAYAK
    [29, 75, 0.18], # Mangga, TIDAK LAYAK
    [27, 62, 0.11], # Apel, LAYAK
    [31, 82, 0.22], # Pisang, TIDAK LAYAK
    [24, 63, 0.09], # Mangga, LAYAK
    [33, 88, 0.28], # Pisang, TIDAK LAYAK
])
# Status buah
status = np.array([0, 1, 0, 1, 0, 1, 0, 1, 0, 1])
# Jenis buah
jenis_buah = np.array([0, 1, 0, 1, 2, 2, 0, 1, 2, 1])
# Gabung label status dan jenis_buah
# Model output: [status, jenis_buah]
y = np.array(list(zip(status, jenis_buah)))

model = DecisionTreeClassifier()
model.fit(X, y)

with open('monitoring/fruit_quality_model.pkl', 'wb') as f:
    pickle.dump(model, f)

print('Model AI multi-buah berhasil disimpan ke monitoring/fruit_quality_model.pkl')
