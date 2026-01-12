from flask import Flask, request
import os

app = Flask(__name__)

@app.route('/firmar', methods=['POST'])
def firmar_ipa():
    # Esto nos ayudará a ver qué nombres está enviando el iPhone
    print("Archivos recibidos:", request.files)
    
    if 'file' not in request.files:
        return "Error: No encontré el campo 'file' en la petición", 400
    
    file = request.files['file']
    if file.filename == '':
        return "Error: Nombre de archivo vacío", 400
    
    # Guardar el archivo en la carpeta actual
    path = os.path.join("./", file.filename)
    file.save(path)
    
    print(f"✅ ¡Éxito! Archivo guardado como: {path}")
    return f"Archivo {file.filename} recibido y guardado en la tablet.", 200

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
