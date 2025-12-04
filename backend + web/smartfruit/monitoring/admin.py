from django.contrib import admin
from .models import SensorData, SensorConfig, AIModel, Setting, DeviceToken
from .models import ContactMessage


@admin.register(SensorData)
class SensorDataAdmin(admin.ModelAdmin):
	list_display = ('timestamp', 'temperature', 'humidity', 'mq2', 'mq3', 'mq135', 'status')
	list_filter = ('status',)
	ordering = ('-timestamp',)


@admin.register(SensorConfig)
class SensorConfigAdmin(admin.ModelAdmin):
	list_display = ('name', 'sensor_type', 'device_id', 'update_interval')
	search_fields = ('name', 'sensor_type', 'device_id')


@admin.register(AIModel)
class AIModelAdmin(admin.ModelAdmin):
	list_display = ('name', 'uploaded_at')
	readonly_fields = ('uploaded_at',)


@admin.register(Setting)
class SettingAdmin(admin.ModelAdmin):
	list_display = ('key', 'value')


@admin.register(DeviceToken)
class DeviceTokenAdmin(admin.ModelAdmin):
	list_display = ('token', 'registered_at')


@admin.register(ContactMessage)
class ContactMessageAdmin(admin.ModelAdmin):
	list_display = ('created_at', 'name', 'email', 'phone')
	search_fields = ('name', 'email', 'phone', 'company', 'message')
	readonly_fields = ('created_at',)
