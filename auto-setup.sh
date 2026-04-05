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
    
    # 🧠 DETECCIÓN DE MINIZIP-NG
    if apt-cache show libminizip-ng-dev > /dev/null 2>&1; then
        echo "📦 libminizip-ng-dev found."
        MINIZIP_PKG="libminizip-ng-dev"
        USE_SHIM=false
    else
        echo "⚠️ Using legacy libminizip-dev + shim..."
        MINIZIP_PKG="libminizip-dev"
        USE_SHIM=true
    fi

    sudo apt install -y curl g++ pkg-config libssl-dev $MINIZIP_PKG \
        build-essential make python3-flask zlib1g-dev

    if [ "$USE_SHIM" = true ]; then
        echo "🔧 Applying minizip-ng shim..."
        sudo mkdir -p /usr/local/lib/pkgconfig
        LIB_PATH=$(gcc -print-multiarch)
        sudo bash -c "cat << EOF > /usr/local/lib/pkgconfig/minizip-ng.pc
prefix=/usr
exec_prefix=\${prefix}
libdir=\${exec_prefix}/lib/$LIB_PATH
includedir=\${prefix}/include/minizip

Name: minizip-ng
Description: Minizip-ng shim for zsign
Version: 3.0.0
Libs: -L\${libdir} -lminizip
Cflags: -I\${includedir}
EOF"
        # 🔑 ESTA ES LA CLAVE: Hacer que el sistema vea el shim globalmente para esta sesión
        export PKG_CONFIG_PATH=/usr/local/lib/pkgconfig:$PKG_CONFIG_PATH
    fi

    # Descarga de cloudflared (simplificada)
    ARCH=$(uname -m)
    echo "🛠️ Downloading cloudflared..."
    [[ "$ARCH" == "x86_64" ]] && BIN="amd64" || BIN="arm64"
    curl -L "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-$BIN" -o cloudflared
    sudo mv cloudflared /usr/local/bin/cloudflared
    sudo chmod +x /usr/local/bin/cloudflared

    # Compilación de zsign (Limpia, sin banderas que rompan el Makefile)
    cd "$DIRECTORY"
    git clone https://github.com/zhlynn/zsign.git
    cd "$DIRECTORY/zsign/build/linux"
    
    # Solo llamamos a make. El Makefile usará pkg-config y encontrará nuestro shim.
    make clean && make

    sudo mv "$DIRECTORY/zsign/bin/zsign" /usr/local/bin/
    sudo chmod +x /usr/local/bin/zsign
    rm -rf "$DIRECTORY/zsign"
fi

cd "$DIRECTORY"
echo "✅ Preparation done!"
echo "---------------------------"
echo "SHOWING INSTALLED COMMANDS:"
command -v zsign || echo "zsign not found"
command -v cloudflared || echo "cloudflared not found"
$PYTHON -c "import flask; print('Python lib - Flask')" 2>/dev/null || echo "Flask not found"
