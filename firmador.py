from flask import Flask, request, send_from_directory
from werkzeug.utils import secure_filename
import subprocess
import os
import uuid
import re
import threading
import time
import shutil

app = Flask(__name__)

# =========================================================
# CONFIGURACIÓN DE USUARIO (Toggles)
# =========================================================
# Quieres ver las contraseñas en texto plano o prefieres jugar al agente secreto? 😎
SHOW_SENSITIVE_LOGS = True 

# =========================================================
# CONFIGURACIÓN DE RUTAS
# =========================================================
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
UPLOAD_DIR = os.path.join(BASE_DIR, "uploads")
os.makedirs(UPLOAD_DIR, exist_ok=True)

# =========================================================
# DETECCIÓN AUTOMÁTICA DE CERTIFICADOS
# =========================================================
def detectar_certificados(base_dir):
    p12 = None
    mobileprovision = None

    print("🔐 Auto-detecting certificate files:")
    for f in os.listdir(base_dir):
        lf = f.lower()
        if lf.endswith(".p12"):
            p12 = os.path.join(base_dir, f)
        elif lf.endswith(".mobileprovision"):
            mobileprovision = os.path.join(base_dir, f)

    if not p12 or not mobileprovision:
        raise RuntimeError("❌ Missing .p12 or .mobileprovision files.")

    print(f"   📄 P12: {os.path.basename(p12)}")
    print(f"   📄 MobileProvision: {os.path.basename(mobileprovision)}")
    return p12, mobileprovision

CERT_P12, CERT_MOBILEPROVISION = detectar_certificados(BASE_DIR)

# =========================================================
# GESTIÓN DE SESIONES Y LIMPIEZA QUIRÚRGICA
# =========================================================
user_sessions = {}

# Si Apple no limpia su desastre, alguien tiene que limpiarlo, ni eso pueden hacer 😒
def tarea_limpieza_inteligente(intervalo=600, edad_maxima=3600):
    while True:
        time.sleep(intervalo)
        if not os.path.exists(UPLOAD_DIR):
            continue

        ahora = time.time()
        for folder_name in os.listdir(UPLOAD_DIR):
            folder_path = os.path.join(UPLOAD_DIR, folder_name)
            if os.path.isdir(folder_path):
                if (ahora - os.path.getmtime(folder_path)) > edad_maxima:
                    try:
                        shutil.rmtree(folder_path)
                        print(f"🧹 Cleanup: Deleted expired job [{folder_name}]")
                    except: pass

threading.Thread(target=tarea_limpieza_inteligente, daemon=True).start()

# =========================================================
# CLOUDFLARE TUNNEL
# =========================================================
PUBLIC_URL = None

def iniciar_tunel_cloudflare():
    global PUBLIC_URL
    print("☁️ Starting CloudFlare tunnel...")
    
    process = subprocess.Popen(
        ["cloudflared", "tunnel", "--url", "http://localhost:5000"],
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True
    ) # SSL gratis para todos! 🥳

    # Solo queremos tu URL, gracias 🙂
    for _ in range(100):
        line = process.stdout.readline()
        if not line: break
        
        match = re.search(r"https://[a-zA-Z0-9-]+\.trycloudflare\.com", line)
        if match:
            PUBLIC_URL = match.group(0)
            break

    if not PUBLIC_URL:
        raise RuntimeError("❌ Could not capture CloudFlare URL")

    print("\n" + "=" * 60)
    print("✅ CloudFlare URL captured successfully:")
    print(f"👉 {PUBLIC_URL}")
    print("📋 Paste this URL in the iDevice frontend")
    print("=" * 60 + "\n") # Si no como sabe el frontend a donde enviar la información? 🙃

# =========================================================
# ENDPOINTS
# =========================================================

@app.route('/config', methods=['POST'])
def configurar():
    device_id = request.form.get('device_name', 'Generic_Device').strip() # Ah, caray!, tu quien eres!? 😧
    config = {
        "url": request.form.get('url', '').strip("/"),
        "bundle_id": request.form.get('bundle_id', '').strip(),
        "password": request.form.get('password', '').strip()
    }
    user_sessions[device_id] = config
    
    if SHOW_SENSITIVE_LOGS:
        print(f"⚙️ Detected Configuration for [{device_id}]: {config}")
    else:
        print(f"⚙️ Config updated for: {device_id} (Details hidden)")
        
    return f"Config saved for {device_id}", 200

@app.route('/upload_ipa', methods=['POST'])
def recibir_y_firmar():
    device_id = request.form.get('device_name', 'Generic_Device').strip()
    config = user_sessions.get(device_id)

    if not config and len(user_sessions) == 1:
        config = list(user_sessions.values())[0]

    if not config:
        return f"{device_id}.config: No such file or directory", 400 # Referencia a Linux 👈🤯

    file = request.files['file']
    original_name = secure_filename(file.filename)

    job_id = str(uuid.uuid4())
    job_dir = os.path.join(UPLOAD_DIR, job_id)
    os.makedirs(job_dir, exist_ok=True)

    original_path = os.path.join(job_dir, original_name)
    signed_name = f"signed_{original_name}"
    signed_path = os.path.join(job_dir, signed_name)

    file.save(original_path)

    print(f"🚀 Signing {original_name} for {device_id}...")

    comando = [
        "zsign", "-k", CERT_P12, "-p", config["password"],
        "-m", CERT_MOBILEPROVISION, "-b", config["bundle_id"],
        "-o", signed_path, original_path
    ]

    process = subprocess.run(comando, capture_output=True, text=True)
    
    # Imprimiendo el testamento de zsign 🔹
    print("🔹 zsign output:\n", process.stdout)

    if process.returncode != 0:
        return f"Sign Error:\n{process.stderr}", 500

    generar_plist(config["url"], config["bundle_id"], signed_name, job_id)

    return (
        f"itms-services://?action=download-manifest&url="
        f"{config['url']}/manifest/{job_id}",
        200
    )

def generar_plist(base_url, bid, filename, job_id):
    content = f"""<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
<key>items</key>
<array>
<dict>
<key>assets</key>
<array>
<dict>
<key>kind</key>
<string>software-package</string>
<key>url</key>
<string>{base_url}/download/{job_id}/{filename}</string>
</dict>
</array>
<key>metadata</key>
<dict>
<key>bundle-identifier</key>
<string>{bid}</string>
<key>bundle-version</key>
<string>1.0</string>
<key>kind</key>
<string>software</string>
<key>title</key>
<string>App</string>
</dict>
</dict>
</array>
</dict>
</plist>
"""
    with open(os.path.join(UPLOAD_DIR, job_id, "manifest.plist"), "w") as f:
        f.write(content) # Para que la porquería de iPhone que va a instalar la app sepa donde buscarla 😒

@app.route('/download/<job_id>/<filename>')
def download(job_id, filename):
    return send_from_directory(os.path.join(UPLOAD_DIR, job_id), filename) # Aquí le servimos su IPA comensal 🧐

@app.route('/manifest/<job_id>')
def get_manifest(job_id):
    return send_from_directory(os.path.join(UPLOAD_DIR, job_id), "manifest.plist")

if __name__ == '__main__':
    iniciar_tunel_cloudflare()
    app.run(host='0.0.0.0', port=5000, debug=True, use_reloader=False) # 🔑 evita doble Cloudflare en modo debug
