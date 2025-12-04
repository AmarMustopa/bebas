
from django.urls import path
from django.contrib.auth import views as auth_views
from monitoring import views
from monitoring import views_auth
from monitoring import views_admin

urlpatterns = [
    # Main pages
    path('', views.landing_auth, name='landing_auth'),
    path('dashboard/', views.dashboard, name='dashboard'),
    path('history/', views_admin.data_history, name='data_history'),
    path('sensor-config/', views_admin.sensor_config_list, name='sensor_config_list'),
    path('ai-model/', views_admin.ai_model_list, name='ai_model_list'),
    path('settings/', views_admin.settings_page, name='settings_page'),
    # Sensor detail page (per-sensor)
    path('sensor-detail/<str:sensor_type>/', views_admin.sensor_detail, name='sensor_detail'),
    
    # Authentication URLs
    path('login/', auth_views.LoginView.as_view(template_name='registration/login.html'), name='login'),
    path('logout/', auth_views.LogoutView.as_view(next_page='login'), name='logout'),
    path('register/', views_auth.register, name='register'),
    
    # Data export
    path('export/csv/', views.export_csv, name='export_csv'),
    
    # API URLs - Sensors & Data
    path('api/sensor/update/', views.update_sensor, name='update_sensor'),
    path('api/sensor/status/', views.get_latest_status, name='get_latest_status'),
    path('api/sensor/history/', views.get_sensor_history, name='get_sensor_history'),
    path('api/sensor/data/', views.sensor_data, name='sensor_data'),
    path('api/status/', views.api_status_influx, name='api_status'),
    path('api/register-token/', views.register_token, name='register_token'),

    # API training status sensor
    path('api/train-status/', views.api_train_status, name='api_train_status'),

    # Debug endpoint: raw influx data
    path('api/sensor/raw/', views.api_sensor_raw, name='api_sensor_raw'),
    
    # API URLs - Config & Models
    path('api/sensor-config/<int:id>/', views_admin.get_sensor_config, name='get_sensor_config'),
    path('api/sensor-config/<int:id>/delete/', views_admin.delete_sensor_config, name='delete_sensor_config'),
    path('api/ai-model/<int:id>/', views_admin.get_ai_model, name='get_ai_model'),
    path('api/ai-model/<int:id>/delete/', views_admin.delete_ai_model, name='delete_ai_model'),
    path('api/ai-model/<int:id>/test/', views_admin.test_ai_model, name='test_ai_model'),
    path('api/settings/test-influx/', views_admin.test_influx_connection, name='test_influx'),
    
    # API URLs - Machine Learning
    path('api/ml/retrain/', views.ml_retrain, name='ml_retrain'),
    path('api/ml/dataset-info/', views.ml_dataset_info, name='ml_dataset_info'),
    path('api/ml/predict/', views.ml_predict, name='ml_predict_manual'),
    
    # API URLs - AI Agent
    path('api/ai/learning-info/', views.ai_learning_info, name='ai_learning_info'),
    path('api/ai/reset-learning/', views.ai_reset_learning, name='ai_reset_learning'),
    
    # AJAX auth endpoints (for backward compatibility)
    path('api/ajax-register/', views_auth.ajax_register, name='ajax_register'),
    path('api/ajax-login/', views_auth.ajax_login, name='ajax_login'),
    path('api/ajax-logout/', views_auth.ajax_logout, name='ajax_logout'),
    # Contact page
    path('contact/', views.contact_person, name='contact_person'),
]
