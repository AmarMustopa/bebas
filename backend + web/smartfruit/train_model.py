import pickle
from sklearn.tree import DecisionTreeClassifier
import numpy as np

# Contoh data dummy: [temperature, humidity, gas]
X = np.array([
    [25, 60, 0.1],
    [30, 80, 0.2],
    [28, 70, 0.15],
    [32, 85, 0.25],
    [26, 65, 0.12],
    [29, 75, 0.18]
])
y = np.array([0, 1, 0, 1, 0, 1])  # 0=LAYAK, 1=TIDAK LAYAK

model = DecisionTreeClassifier()
model.fit(X, y)

with open('monitoring/fruit_quality_model.pkl', 'wb') as f:
    pickle.dump(model, f)

print('Model AI Decision Tree berhasil disimpan ke monitoring/fruit_quality_model.pkl')
