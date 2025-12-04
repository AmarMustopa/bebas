import csv
import os
import django

# Set environment Django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'smartfruit.settings')
django.setup()

from monitoring.models import SensorData

# Ganti nama file CSV jika perlu
csv_file = 'dataset_layak_tidaklayak.csv'

with open(csv_file, newline='') as csvfile:
    reader = csv.DictReader(csvfile)
    for row in reader:
        SensorData.objects.create(
            temperature=row['Temperature'],
            humidity=row['Humidity'],
            gas=row['MQ135']
        )
print('Import selesai!')
