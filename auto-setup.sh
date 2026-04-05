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
    
    # 🕵️ Detectar versión de minizip
    if apt-cache show libminizip-ng-dev > /dev/null 2>&1; then
        MINIZIP_PKG="libminizip-ng-dev"
        USE_SHIM=false
    else
        MINIZIP_PKG="libminizip-dev"
        USE_SHIM=true
    fi

    sudo apt install -y curl g++ pkg-config libssl-dev $MINIZIP_PKG \
        build-essential make python3-flask zlib1g-dev

    # 🛠️ Descargar cloudflared
    ARCH=$(uname -m)
    [[ "$ARCH" == "x86_64" ]] && BIN_ARCH="amd64" || BIN_ARCH="arm64"
    curl -L "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-$BIN_ARCH" -o cloudflared
    sudo mv cloudflared /usr/local/bin/cloudflared
    sudo chmod +x /usr/local/bin/cloudflared

    # 🏗️ Compilación de zsign
    cd "$DIRECTORY"
    rm -rf zsign
    
    if [ "$USE_SHIM" = true ]; then
        echo "🚀 Running external build script for legacy minizip..."
        chmod +x build_zsign.sh
        ./build_zsign.sh
    else
        echo "🏗️ Building zsign with native minizip-ng..."
        git clone https://github.com/zhlynn/zsign.git
        cd zsign/build/linux
        make clean && make
    fi

    # Mover el binario final si existe
    if [ -f "$DIRECTORY/zsign/bin/zsign" ]; then
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
command -v cloudflared || echo "cloudflared not found"
$PYTHON -c "import flask; print('Python lib - Flask')" 2>/dev/null || echo "Flask not found"
