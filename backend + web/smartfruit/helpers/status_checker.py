def check_status(data):
    suhu = data.get("suhu")
    hum = data.get("kelembapan")
    mq2 = data.get("mq2")
    mq3 = data.get("mq3")
    mq135 = data.get("mq135")

    issues = []

    # RULE SUHU
    if not (20 <= suhu <= 35):
        issues.append(f"Suhu tidak normal ({suhu}°C)")

    # RULE KELEMBAPAN
    if not (40 <= hum <= 90):
        issues.append(f"Kelembapan tidak normal ({hum}%)")

    # RULE MQ3
    if mq3 > 1200:
        issues.append(f"Alkohol (MQ3) terlalu tinggi ({mq3} ppm)")

    # RULE MQ135
    if mq135 > 1200:
        issues.append(f"Amonia (MQ135) terlalu tinggi ({mq135} ppm)")

    # OUTPUT
    if len(issues) == 0:
        return {
            "status": "Layak",
            "alasan": "Semua parameter dalam batas wajar."
        }

    return {
        "status": "Tidak Layak",
        "alasan": "; ".join(issues)
    }
