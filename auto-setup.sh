#!/usr/bin/env bash

DIRECTORY=$(pwd)

echo "Detecting environment..."

# --- BLOQUE TERMUX ---
if [[ "$PREFIX" == "/data/data/com.termux/files/usr" ]]; then
    echo "🟣 Termux (experimental) detected!"
    PYTHON=python

    pkg install -y \
        clang \
        make \
        pkg-config \
        *ssl* \
        *minizip* \
        python \
        build-essential

    # Cloudflared y Flask en Termux 
    pkg reinstall cloudflared -y
    pip install Flask

    cd "$DIRECTORY"
    git clone https://github.com/zhlynn/zsign.git
    printf "#ifndef _INTS_H\n#define _INTS_H\n#include <stdint.h>\ntypedef uint64_t ui64_t;\ntypedef uint32_t ui32_t;\n#endif" > "$PREFIX/include/minizip/ints.h"
    sed -i 's|/tmp|/data/data/com.termux/files/usr/tmp|g' zsign/src/common/fs.cpp
    cd "$DIRECTORY/zsign/build/linux"
    make clean && make CXXFLAGS="-O3 -std=c++11 -I../../src -I../../src/common -I$PREFIX/include/minizip" LDFLAGS="-L$PREFIX/lib -lcrypto -lz -lminizip"

    mv "$DIRECTORY/zsign/bin/zsign" "$PREFIX/bin/"
    chmod +x "$PREFIX/bin/cloudflared"
    chmod +x "$PREFIX/bin/zsign"
    rm -rf "$DIRECTORY/zsign"

# --- BLOQUE LINUX NORMAL ---
else
    echo "🟢 Linux normal detected!"
    PYTHON=python3

    # Instalación de dependencias del sistema
    sudo apt update && sudo apt install -y \
        curl \
        g++ \
        pkg-config \
        libssl-dev \
        libminizip-dev \
        build-essential \
        make \
        python3-flask \
        zlib1g-dev

    # NUEVA FORMA: Descarga de cloudflared sin Homebrew
    ARCH=$(uname -m)
    echo "🛠️ Downloading cloudflared for $ARCH..."
    
    if [[ "$ARCH" == "x86_64" ]]; then
        URL="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64"
    elif [[ "$ARCH" == "aarch64" || "$ARCH" == "arm64" ]]; then
        URL="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64"
    else
        echo "❌ Architecture $ARCH not supported for automatic download."
        exit 1
    fi

    # Descarga e instalación limpia
    curl -L "$URL" -o $DIRECTORY/cloudflared
    sudo mv cloudflared /usr/local/bin/cloudflared
    sudo chmod +x /usr/local/bin/cloudflared

    # Compilación de zsign
    cd "$DIRECTORY"
    git clone https://github.com/zhlynn/zsign.git
    cd "$DIRECTORY/zsign/build/linux"
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
