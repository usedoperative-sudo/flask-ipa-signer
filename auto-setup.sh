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
    
    # Identificar paquete de minizip
    if apt-cache show libminizip-ng-dev > /dev/null 2>&1; then
        MINIZIP_PKG="libminizip-ng-dev"
        USE_SHIM=false
    else
        MINIZIP_PKG="libminizip-dev"
        USE_SHIM=true
    fi

    sudo apt install -y curl g++ pkg-config libssl-dev $MINIZIP_PKG \
        build-essential make python3-flask zlib1g-dev

    # Solo crear el shim si falta minizip-ng
    if [ "$USE_SHIM" = true ]; then
        echo "🔧 Creating minizip-ng compatibility shim..."
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
        export PKG_CONFIG_PATH=/usr/local/lib/pkgconfig:$PKG_CONFIG_PATH
    fi

    # Descarga de cloudflared
    ARCH=$(uname -m)
    [[ "$ARCH" == "x86_64" ]] && CBIN="amd64" || CBIN="arm64"
    curl -L "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-$CBIN" -o cloudflared
    sudo mv cloudflared /usr/local/bin/cloudflared
    sudo chmod +x /usr/local/bin/cloudflared

    # COMPILACIÓN LIMPIA
    cd "$DIRECTORY"
    rm -rf zsign # Borrar intentos previos para evitar basura
    git clone https://github.com/zhlynn/zsign.git
    cd zsign/build/linux
    
    # USAMOS MAKE SIN BANDERAS MANUALES 
    # El Makefile llamará a pkg-config y este usará nuestro shim
    make clean && make

    sudo mv "$DIRECTORY/zsign/bin/zsign" /usr/local/bin/zsign
    sudo chmod +x /usr/local/bin/zsign
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
