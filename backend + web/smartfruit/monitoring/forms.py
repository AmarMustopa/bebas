from django import forms
from .models import AIModel, SensorConfig, Setting


class AIModelForm(forms.ModelForm):
    class Meta:
        model = AIModel
        fields = ['name', 'file', 'description']


class SensorConfigForm(forms.ModelForm):
    class Meta:
        model = SensorConfig
        fields = ['name', 'sensor_type', 'threshold_warning', 'threshold_danger', 'device_id', 'update_interval']


class SettingForm(forms.ModelForm):
    class Meta:
        model = Setting
        fields = ['key', 'value']
