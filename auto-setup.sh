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
    
    # 🕵️ Detectar qué versión de minizip está disponible
    if apt-cache show libminizip-ng-dev > /dev/null 2>&1; then
        MINIZIP_PKG="libminizip-ng-dev"
        USE_SHIM=false
    else
        MINIZIP_PKG="libminizip-dev"
        USE_SHIM=true
    fi

    sudo apt install -y curl g++ pkg-config libssl-dev $MINIZIP_PKG \
        build-essential make python3-flask zlib1g-dev

    # 🔧 Crear el shim de compatibilidad solo si es necesario
    if [ "$USE_SHIM" = true ]; then
        echo "🔧 Applying minizip-ng shim..."
        sudo mkdir -p /usr/local/lib/pkgconfig
        LIB_PATH=$(gcc -print-multiarch)
        sudo bash -c "cat << EOF > /usr/local/lib/pkgconfig/minizip-ng.pc
prefix=/usr
exec_prefix=\${prefix}
libdir=\${prefix}/lib/$LIB_PATH
includedir=\${prefix}/include/minizip

Name: minizip-ng
Description: Compatibility shim for zsign
Version: 3.0.0
Libs: -L\${libdir} -lminizip
Cflags: -I\${includedir}
EOF"
        # Exportar la ruta para que pkg-config lo encuentre
        export PKG_CONFIG_PATH=/usr/local/lib/pkgconfig:$PKG_CONFIG_PATH
    fi

    # 🛠️ Descargar cloudflared
    ARCH=$(uname -m)
    [[ "$ARCH" == "x86_64" ]] && BIN_ARCH="amd64" || BIN_ARCH="arm64"
    curl -L "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-$BIN_ARCH" -o cloudflared
    sudo mv cloudflared /usr/local/bin/cloudflared
    sudo chmod +x /usr/local/bin/cloudflared

    # 🏗️ Compilación de zsign (Limpia y directa)
    cd "$DIRECTORY"
    rm -rf zsign # Borrar restos de intentos fallidos
    git clone https://github.com/zhlynn/zsign.git
    cd zsign/build/linux
    
    # IMPORTANTE: Ejecutamos make a secas. 
    # El Makefile usará pkg-config internamente y encontrará nuestro shim.
    make clean && make

    if [ -f "../../bin/zsign" ]; then
        sudo mv "../../bin/zsign" /usr/local/bin/zsign
        sudo chmod +x /usr/local/bin/zsign
        echo "✅ zsign installed successfully!"
    else
        echo "❌ Error: zsign binary not found."
        exit 1
    fi

    cd "$DIRECTORY"
    rm -rf "$DIRECTORY/zsign"
fi

cd "$DIRECTORY"
echo "✅ Preparation done!"
echo "---------------------------"
echo "SHOWING INSTALLED COMMANDS:"
command -v zsign || echo "zsign not found"
command -v cloudflared || echo "cloudflared not found"
$PYTHON -c "import flask; print('Python lib - Flask')" 2>/dev/null || echo "Flask not found"
