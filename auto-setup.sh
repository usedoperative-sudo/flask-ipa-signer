
#!/usr/bin/env bash

set -e

DIRECTORY=$(pwd)

echo "Detecting environment..."

# --- BLOQUE TERMUX ---
if [[ "$PREFIX" == "/data/data/com.termux/files/usr" ]]; then
    echo "🟣 Termux detected!"
    PYTHON=python

    # Instalación de dependencias base
    pkg install -y clang make pkg-config openssl libminizip zlib python python-pip build-essential cloudflared

    pip install Flask

    # 🛠​️ Crear el SHIM de minizip-ng específico para Termux
    echo "🔧 Creating minizip-ng shim for Termux..."
    mkdir -p "$PREFIX/lib/pkgconfig"
    cat << EOF > "$PREFIX/lib/pkgconfig/minizip-ng.pc"
prefix=$PREFIX
exec_prefix=\${prefix}
libdir=\${exec_prefix}/lib
includedir=\${prefix}/include/minizip

Name: minizip-ng
Description: Minizip-ng shim for zsign (Termux)
Version: 3.0.0
Libs: -L\${libdir} -lminizip
Cflags: -I\${includedir}
EOF

    # Parche para ints.h (necesario en Termux para evitar error en ioapi.h)
    mkdir -p "$PREFIX/include/minizip"
    printf "#ifndef _INTS_H\n#define _INTS_H\n#include <stdint.h>\ntypedef uint64_t ui64_t;\ntypedef uint32_t ui32_t;\n#endif" > "$PREFIX/include/minizip/ints.h"

    # 🏗​️ Compilación de zsign
    cd "$DIRECTORY"
    rm -rf zsign
    git clone https://github.com/zhlynn/zsign.git

    # Parche de rutas temporales para Android/Termux
    sed -i 's|/tmp|/data/data/com.termux/files/usr/tmp|g' zsign/src/common/fs.cpp

    cd "zsign/build/linux"
    echo "🏗​️ Building zsign..."
    make clean && make

    # Instalación del binario final
    if [ -f "../../bin/zsign" ]; then
        mv "../../bin/zsign" "$PREFIX/bin/zsign"
        chmod +x "$PREFIX/bin/zsign"
    fi

    cd "$DIRECTORY"
    rm -rf zsign

# --- BLOQUE LINUX NORMAL ---
else
    echo "🟢 GNU/Linux detected!"
    PYTHON=python3

    sudo apt update

    if apt-cache show libminizip-ng-dev > /dev/null 2>&1; then
        MINIZIP_PKG="libminizip-ng-dev"
        USE_SHIM=false
    else
        MINIZIP_PKG="libminizip-dev"
        USE_SHIM=true
    fi

    sudo apt install -y curl g++ pkg-config libssl-dev $MINIZIP_PKG \
        build-essential make python3-flask zlib1g-dev

    # 🛠​️ Descargar cloudflared
    ARCH=$(uname -m)
    [[ "$ARCH" == "x86_64" ]] && BIN_ARCH="amd64" || BIN_ARCH="arm64"
    curl -L "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-$BIN_ARCH" -o cloudflared
    sudo mv cloudflared /usr/local/bin/cloudflared
    sudo chmod +x /usr/local/bin/cloudflared

    # 🏗​️ Compilación de zsign
    cd "$DIRECTORY"
    rm -rf zsign

    if [ "$USE_SHIM" = true ]; then
        echo "🏗​️ Building zsign with legacy minizip..."
        chmod +x build_zsign.sh
        ./build_zsign.sh
    else
        echo "🏗​️ Building zsign with native minizip-ng..."
        git clone https://github.com/zhlynn/zsign.git
        cd zsign/build/linux
        make clean && make
    fi

    # Mover el binario final si existe
    if [ -f "$DIRECTORY/zsign/bin/zsign" ];then
        sudo mv "$DIRECTORY/zsign/bin/zsign" /usr/local/bin/zsign
        sudo chmod +x /usr/local/bin/zsign
    fi

    rm -rf "$DIRECTORY/zsign"
fi

cd "$DIRECTORY"
echo "✅ Preparation done!"
echo "---------------------------"
echo "SHOWING INSTALLED COMMANDS:"
command -v zsign || echo "zsign not found"
command -v cloudflared || echo "cloudflarednot found"
$PYTHON -c "import flask; print('Python lib - Flask')" 2>/dev/null || echo "Flask not found"
