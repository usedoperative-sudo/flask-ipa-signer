#!/usr/bin/env bash

DIRECTORY=$(pwd)

echo "Detecting environment..."

# --- BLOQUE TERMUX ---
if [[ "$PREFIX" == "/data/data/com.termux/files/usr" ]]; then
    echo "🟣 Termux detected!"
    PYTHON=python

    pkg install -y \
        clang \
        make \
        pkg-config \
        *ssl* \
        *minizip* \
        python \
        python-pip \
        build-essential

    pkg reinstall cloudflared -y
    pip install Flask

    cd "$DIRECTORY"
    git clone https://github.com/zhlynn/zsign.git
    printf "#ifndef _INTS_H\n#define _INTS_H\n#include <stdint.h>\ntypedef uint64_t ui64_t;\ntypedef uint32_t ui32_t;\n#endif" > "$PREFIX/include/minizip/ints.h"
    sed -i 's|/tmp|/data/data/com.termux/files/usr/tmp|g' zsign/src/common/fs.cpp
    cd "$DIRECTORY/zsign/build/linux"
    make clean && make CXXFLAGS="-O3 -std=c++11 -I../../src -I../../src/common -I$PREFIX/include/minizip" LDFLAGS="-L$PREFIX/lib -lcrypto -lz -lminizip"

    mv "$DIRECTORY/zsign/bin/zsign" "$PREFIX/bin/"
    chmod +x "$PREFIX/bin/zsign"
    rm -rf "$DIRECTORY/zsign"

# --- BLOQUE LINUX NORMAL ---
else
    echo "🟢 GNU/Linux detected!"
    PYTHON=python3

    sudo apt update
    
    # 🧠 DETECCIÓN INTELIGENTE DE MINIZIP-NG
    # Intentamos ver si el paquete "ng" existe en los repositorios
    if apt-cache show libminizip-ng-dev > /dev/null 2>&1; then
        echo "📦 libminizip-ng-dev found in repos, installing..."
        MINIZIP_PKG="libminizip-ng-dev"
        USE_SHIM=false
    else
        echo "⚠️ libminizip-ng-dev NOT found. Using legacy minizip + shim..."
        MINIZIP_PKG="libminizip-dev"
        USE_SHIM=true
    fi

    sudo apt install -y \
        curl \
        g++ \
        pkg-config \
        libssl-dev \
        $MINIZIP_PKG \
        build-essential \
        make \
        python3-flask \
        zlib1g-dev

    # Aplicar el SHIM solo si es necesario (ej. en Ubuntu 22.04 Jammy)
    if [ "$USE_SHIM" = true ]; then
        echo "🔧 Applying minizip-ng shim for compatibility..."
        sudo mkdir -p /usr/local/lib/pkgconfig
        # Determinamos la ruta de las librerías (x86_64 o aarch64)
        LIB_PATH=$(gcc -print-multiarch)
        sudo bash -c "cat << EOF > /usr/local/lib/pkgconfig/minizip-ng.pc
prefix=/usr
exec_prefix=\${prefix}
libdir=\${exec_prefix}/lib/$LIB_PATH
includedir=\${prefix}/include/minizip

Name: minizip-ng
Description: Minizip-ng shim for zsign (Legacy fallback)
Version: 3.0.0
Libs: -L\${libdir} -lminizip
Cflags: -I\${includedir}
EOF"
    fi

    # Descarga de cloudflared
    ARCH=$(uname -m)
    echo "🛠️ Downloading cloudflared for $ARCH..."
    if [[ "$ARCH" == "x86_64" ]]; then
        URL="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64"
    elif [[ "$ARCH" == "aarch64" || "$ARCH" == "arm64" ]]; then
        URL="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64"
    else
        echo "❌ Architecture $ARCH not supported."
        exit 1
    fi

    curl -L "$URL" -o $DIRECTORY/cloudflared
    sudo mv $DIRECTORY/cloudflared /usr/local/bin/cloudflared
    sudo chmod +x /usr/local/bin/cloudflared

    # Compilación de zsign
    cd "$DIRECTORY"
    git clone https://github.com/zhlynn/zsign.git
    cd "$DIRECTORY/zsign/build/linux"
    
    # Si usamos el shim, nos aseguramos que pkg-config busque en /usr/local/lib/pkgconfig
    export PKG_CONFIG_PATH=/usr/local/lib/pkgconfig:$PKG_CONFIG_PATH
    
    make clean && make

    sudo mv "$DIRECTORY/zsign/bin/zsign" /usr/local/bin/
    sudo chmod +x /usr/local/bin/zsign
    rm -rf "$DIRECTORY/zsign"
fi

clear
cd "$DIRECTORY"
echo "✅ Preparation done!"
echo "---------------------------"
echo "SHOWING INSTALLED COMMANDS:"
command -v zsign || echo "zsign not found"
command -v cloudflared || echo "cloudflared not found"
$PYTHON -c "import flask; print('Python lib - Flask')" 2>/dev/null || echo "Flask not found"
