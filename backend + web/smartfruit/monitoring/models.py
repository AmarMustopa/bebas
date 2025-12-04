from django.db import models

class DeviceToken(models.Model):
    token = models.CharField(max_length=256, unique=True)
    registered_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return self.token

class SensorData(models.Model):
    timestamp = models.DateTimeField(auto_now_add=True)
    temperature = models.FloatField()
    humidity = models.FloatField()
    mq2 = models.FloatField(verbose_name="Gas MQ2", help_text="Gas umum (ppm)", null=True, blank=True)
    mq3 = models.FloatField(verbose_name="Gas MQ3", help_text="Alkohol/VOC (ppm)", null=True, blank=True)
    mq135 = models.FloatField(verbose_name="Gas MQ135", help_text="Amonia/CO₂ (ppm)", null=True, blank=True)
    status = models.CharField(max_length=20, default="LAYAK")
    jenis_buah = models.CharField(max_length=50, default="UNKNOWN")

    def __str__(self):
        return f"{self.timestamp} - Temp: {self.temperature}°C, Humidity: {self.humidity}%, Status: {self.status}, Jenis Buah: {self.jenis_buah}"


class SensorConfig(models.Model):
    name = models.CharField(max_length=100)
    sensor_type = models.CharField(max_length=50, help_text="e.g. MQ2, MQ3, MQ135, DHT11")
    threshold_warning = models.FloatField(null=True, blank=True)
    threshold_danger = models.FloatField(null=True, blank=True)
    device_id = models.CharField(max_length=100, null=True, blank=True)
    update_interval = models.IntegerField(default=10, help_text="Update interval in seconds")

    def __str__(self):
        return f"{self.name} ({self.sensor_type})"


class AIModel(models.Model):
    name = models.CharField(max_length=200)
    uploaded_at = models.DateTimeField(auto_now_add=True)
    file = models.FileField(upload_to='models/')
    description = models.TextField(blank=True)

    def __str__(self):
        return f"{self.name} - {self.uploaded_at.strftime('%Y-%m-%d %H:%M:%S')}"


class Setting(models.Model):
    key = models.CharField(max_length=100, unique=True)
    value = models.TextField(blank=True, null=True)

    def __str__(self):
        return f"{self.key}"


class ContactMessage(models.Model):
    name = models.CharField(max_length=200, blank=True)
    email = models.EmailField(blank=True)
    company = models.CharField(max_length=200, blank=True)
    phone = models.CharField(max_length=50, blank=True)
    message = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"ContactMessage from {self.name or self.phone or 'anonymous'} at {self.created_at:%Y-%m-%d %H:%M:%S}"
