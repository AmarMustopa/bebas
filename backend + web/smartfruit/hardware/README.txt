# Cara Integrasi ESP32 + DHT22 dengan Smart Fruit Backend

1. **Upload kode `esp32_dht22_post.ino` ke ESP32**
   - Buka file `hardware/esp32_dht22_post.ino` di Arduino IDE.
   - Install library: DHT sensor library by Adafruit.
   - Ganti `NAMA_WIFI`, `PASSWORD_WIFI`, dan `<IP_BACKEND>` sesuai jaringan dan alamat server Django Anda.
   - Upload ke board ESP32.

2. **Pastikan server Django sudah berjalan**
   - Jalankan: `python manage.py runserver` di backend.

3. **Cek dashboard**
   - Data sensor akan otomatis masuk dan tampil di dashboard web.

4. **Troubleshooting**
   - Jika data tidak masuk, cek koneksi WiFi, IP backend, dan pastikan endpoint `/api/sensor/` bisa diakses dari jaringan ESP32.


**Catatan:**
- Untuk sensor gas, ganti variabel `gas` sesuai pembacaan sensor Anda.
- Bisa dikembangkan untuk perangkat lain (NodeMCU, Raspberry Pi, dsb) dengan prinsip POST data ke API backend.
