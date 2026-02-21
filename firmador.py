from flask import Flask, request, send_from_directory
from werkzeug.utils import secure_filename
import subprocess
import os
import uuid
import re

app = Flask(__name__)

# =========================================================
# RUTA BASE AUTOMÁTICA (donde está ESTE script)
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

    for f in os.listdir(base_dir):
        lf = f.lower()
        if lf.endswith(".p12"):
            p12 = os.path.join(base_dir, f)
        elif lf.endswith(".mobileprovision"):
            mobileprovision = os.path.join(base_dir, f)

    if not p12:
        raise RuntimeError("❌ No se encontró ningún archivo .p12 en el directorio del script")

    if not mobileprovision:
        raise RuntimeError("❌ No se encontró ningún archivo .mobileprovision en el directorio del script")

    print("🔐 Certificados detectados automáticamente:")
    print("   📄 P12:", p12)
    print("   📄 MobileProvision:", mobileprovision)

    return p12, mobileprovision


CERT_P12, CERT_MOBILEPROVISION = detectar_certificados(BASE_DIR)

# =========================================================
# MEMORIA TEMPORAL
# =========================================================
session_data = {
    "url": "",
    "bundle_id": ""
}

PUBLIC_URL = None

# =========================================================
# CLOUDflare TUNNEL
# =========================================================
def iniciar_tunel_cloudflare():
    global PUBLIC_URL

    print("☁️ Iniciando túnel de Cloudflare...")

    process = subprocess.Popen(
        ["cloudflared", "tunnel", "--url", "http://localhost:5000"],
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True # Se usa Cloudflared para tener certificados SSL gratis (🤑💸) para que el iDevice objetivo no rechace la instalación 
    )

    for _ in range(40):
        line = process.stdout.readline()
        if not line:
            break

        print(line.strip())

        match = re.search(r"https://[a-zA-Z0-9-]+\.trycloudflare\.com", line)
        if match:
            PUBLIC_URL = match.group(0)
            break

    if not PUBLIC_URL:
        raise RuntimeError("❌ No se pudo obtener la URL de Cloudflare")

    print("\n" + "=" * 60)
    print("✅ Cloudflare URL ACTIVA")
    print(f"👉 {PUBLIC_URL}")
    print("📋 Copia ESTA URL y pégala en tu frontend del iDevice")
    print("=" * 60 + "\n")

# =========================================================
# ENDPOINTS
# =========================================================
@app.route('/config', methods=['POST'])
def configurar():
    session_data["url"] = request.form.get('url', '').strip("/")
    session_data["bundle_id"] = request.form.get('bundle_id', '').strip()
    session_data["password"] = request.form.get('password', '').strip()
	
    print(f"⚙️ Configuración recibida: {session_data}")
    return "Configuracion guardada", 200


@app.route('/upload_ipa', methods=['POST'])
def recibir_y_firmar():

    if 'file' not in request.files:
        return "No hay archivo", 400

    if not session_data["url"] or not session_data["bundle_id"]:
        return "Error: Falta configurar URL o Bundle ID primero", 400

    file = request.files['file']
    original_name = secure_filename(file.filename)

    if not original_name.endswith(".ipa"):
        return "Archivo no es IPA", 400

    # =====================================================
    # JOB AISLADO
    # =====================================================
    job_id = str(uuid.uuid4())
    job_dir = os.path.join(UPLOAD_DIR, job_id)
    os.makedirs(job_dir, exist_ok=True)

    original_path = os.path.join(job_dir, original_name)
    signed_name = f"signed_{original_name}"
    signed_path = os.path.join(job_dir, signed_name)

    file.save(original_path)

    if not os.path.exists(original_path):
        return "Error: IPA no se pudo guardar", 500

    print("📂 CWD:", os.getcwd())
    print("📦 IPA guardado en:", original_path)
    print(f"🚀 Iniciando firma de {original_name}...")

    # =====================================================
    # FIRMA CON ZSIGN
    # =====================================================
    comando = [
        "zsign",
        "-k", CERT_P12,
        "-p", session_data["password"], 
        "-m", CERT_MOBILEPROVISION,
        "-b", session_data["bundle_id"],
        "-n", original_name.replace(".ipa", ""),
        "-o", signed_path,
        original_path
    ]

    process = subprocess.run(
        comando,
        capture_output=True,
        text=True
    )

    print("🔹 zsign stdout:\n", process.stdout)
    print("🔹 zsign stderr:\n", process.stderr)

    if process.returncode != 0:
        return f"Error en firma:\n{process.stderr}", 500

    generar_plist(session_data["url"], session_data["bundle_id"], signed_name, job_id)

    return (
        f"itms-services://?action=download-manifest&url="
        f"{session_data['url']}/manifest/{job_id}",
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
<string>{filename}</string>
</dict>
</dict>
</array>
</dict>
</plist>
"""
    job_dir = os.path.join(UPLOAD_DIR, job_id)
    with open(os.path.join(job_dir, "manifest.plist"), "w") as f:
        f.write(content)


@app.route('/download/<job_id>/<filename>')
def download(job_id, filename):
    return send_from_directory(os.path.join(UPLOAD_DIR, job_id), filename)


@app.route('/manifest/<job_id>')
def get_manifest(job_id):
    return send_from_directory(os.path.join(UPLOAD_DIR, job_id), "manifest.plist")


# =========================================================
# MAIN
# =========================================================
if __name__ == '__main__':
    iniciar_tunel_cloudflare()
    app.run(
        host='0.0.0.0',
        port=5000,
        debug=True,
        use_reloader=False   # 🔑 evita doble Cloudflare con el modo debug activado
    )
