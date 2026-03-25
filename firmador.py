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
        raise RuntimeError("❌ No such .p12 file on current directory")

    if not mobileprovision:
        raise RuntimeError("❌ No such .mobileprovision file on current directory")

    print("🔐 Auto-detecting certificate files:")
    print("   📄 P12:", p12)
    print("   📄 MobileProvision:", mobileprovision)

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

    print("☁️ Starting CloudFlare free tunnel...")

    process = subprocess.Popen(
        ["cloudflared", "tunnel", "--url", "http://localhost:5000"],
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True
    ) # SSL gratis para todos! 🥳

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
        raise RuntimeError("❌ Could not find CloudFlare URL")

    print("\n" + "=" * 60)
    print("✅ CloudFlare URL:")
    print(f"👉 {PUBLIC_URL}")
    print("📋 Paste this URL in the iPhone/iPad frontend")
    print("=" * 60 + "\n") # Si no como sabe el frontend a donde enviar la información? 🙃

# =========================================================
# ENDPOINTS
# =========================================================
@app.route('/config', methods=['POST'])
def configurar():
    session_data["url"] = request.form.get('url', '').strip("/")
    session_data["bundle_id"] = request.form.get('bundle_id', '').strip()
    session_data["password"] = request.form.get('password', '').strip()
    print(f"⚙️ Detected Configuration: {session_data}")
    return "Configuration saved", 200


@app.route('/upload_ipa', methods=['POST'])
def recibir_y_firmar():

    if 'file' not in request.files:
        return "No such file or directory ", 400 # Referencia a Linux 👈🤯

    if not session_data["url"] or not session_data["bundle_id"]:
        return "Error: URL or Bundle ID are missing", 400

    file = request.files['file']
    original_name = secure_filename(file.filename)

    if not original_name.endswith(".ipa"):
        return "File is not a IPA", 400

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
        return "Error: Could not save IPA file", 500

    print("📂 CWD:", os.getcwd())
    print("📦 IPA saved in:", original_path)
    print(f"🚀 Signing {original_name}...")

    # =====================================================
    # FIRMA CON ZSIGN
    # =====================================================
    comando = [
        "zsign",
        "-k", CERT_P12,
        "-p", session_data["password"], 
        "-m", CERT_MOBILEPROVISION,
        "-b", session_data["bundle_id"],
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
        return f"Sign Error:\n{process.stderr}", 500

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
<string>App</string>
</dict>
</dict>
</array>
</dict>
</plist>
"""
    job_dir = os.path.join(UPLOAD_DIR, job_id)
    with open(os.path.join(job_dir, "manifest.plist"), "w") as f:
        f.write(content) # Para que la porquería de iPhone que va a instalar la app sepa donde buscarla 😒


@app.route('/download/<job_id>/<filename>')
def download(job_id, filename):
    return send_from_directory(os.path.join(UPLOAD_DIR, job_id), filename) # Aquí le servimos su IPA comensal 🧐


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
        use_reloader=False   # 🔑 evita doble Cloudflare en modo debug
    )
