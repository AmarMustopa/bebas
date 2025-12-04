from django.contrib.auth import authenticate, login, logout
from django.contrib.auth.models import User
from django.shortcuts import render, redirect
from django.contrib import messages
from django import forms
from django.contrib.auth.forms import UserCreationForm
from django.views.decorators.csrf import csrf_exempt
from django.http import JsonResponse
import json

class CustomUserCreationForm(UserCreationForm):
    email = forms.EmailField(required=True)

    class Meta:
        model = User
        fields = ("username", "email", "password1", "password2")

    def save(self, commit=True):
        user = super().save(commit=False)
        user.email = self.cleaned_data["email"]
        if commit:
            user.save()
        return user

def register(request):
    if request.user.is_authenticated:
        return redirect('dashboard')
        
    if request.method == 'POST':
        form = CustomUserCreationForm(request.POST)
        if form.is_valid():
            user = form.save()
            # Auto-login the user after successful registration
            login(request, user)
            messages.success(request, 'Pendaftaran berhasil. Anda telah login.')
            return redirect('dashboard')
        else:
            for error in form.errors.values():
                messages.error(request, error)
    else:
        form = CustomUserCreationForm()
    
    return render(request, 'registration/register.html', {'form': form})

@csrf_exempt
def ajax_register(request):
    if request.method == 'POST':
        data = json.loads(request.body.decode('utf-8'))
        email = data.get('email')
        username = data.get('username')
        password = data.get('password')
        if not (email and username and password):
            return JsonResponse({'success': False, 'message': 'All fields are required.'})
        if User.objects.filter(username=username).exists():
            return JsonResponse({'success': False, 'message': 'Username is already taken.'})
        user = User.objects.create_user(username=username, email=email, password=password)
        return JsonResponse({'success': True, 'message': 'Registration successful.'})
    return JsonResponse({'success': False, 'message': 'Method not allowed.'})

@csrf_exempt
def ajax_login(request):
    if request.method == 'POST':
        data = json.loads(request.body.decode('utf-8'))
        username = data.get('username')
        password = data.get('password')
        user = authenticate(request, username=username, password=password)
        if user is not None:
            login(request, user)
            return JsonResponse({'success': True, 'message': 'Login berhasil.', 'username': user.username})
        else:
            return JsonResponse({'success': False, 'message': 'Username atau password salah.'})
    return JsonResponse({'success': False, 'message': 'Metode tidak diizinkan.'})

@csrf_exempt
def ajax_logout(request):
    if request.method == 'POST':
        logout(request)
        return JsonResponse({'success': True, 'message': 'Logout berhasil.'})
    return JsonResponse({'success': False, 'message': 'Metode tidak diizinkan.'})
