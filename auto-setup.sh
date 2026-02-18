#!/usr/bin/env bash

DIRECTORY=$(pwd)


echo "Detecting environment..."

# Detect Termux (PREFIX típico)
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

    cd $DIRECTORY
    git clone https://github.com/zhlynn/zsign.git
    printf "#ifndef _INTS_H\n#define _INTS_H\n#include <stdint.h>\ntypedef uint64_t ui64_t;\ntypedef uint32_t ui32_t;\n#endif" > $PREFIX/include/minizip/ints.h
    sed -i 's|/tmp|/data/data/com.termux/files/usr/tmp|g' zsign/src/common/fs.cpp
    cd $DIRECTORY/zsign/build/linux
    make clean && make CXXFLAGS="-O3 -std=c++11 -I../../src -I../../src/common -I$PREFIX/include/minizip" LDFLAGS="-L$PREFIX/lib -lcrypto -lz -lminizip"

    mv $DIRECTORY/zsign/bin/zsign $PREFIX/bin/
    mv $DIRECTORY/cloudflared-linux-arm64 $PREFIX/bin/
    chmod +x $PREFIX/bin/cloudflared
    chmod +x $PREFIX/bin/zsign
    rm -rf $DIRECTORY/zsign

else
    echo "🟢 Linux normal detected!"
    PYTHON=python3

    sudo apt install -y \
        g++ \
        pkg-config \
        libssl-dev \
        libminizip-dev \
        git \
        make \
        python3-flask

    NONINTERACTIVE=1 /bin/bash -c \
      "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    export PATH=/home/linuxbrew/.linuxbrew/bin:$PATH

    brew install cloudflared

    cd $DIRECTORY
    git clone https://github.com/zhlynn/zsign.git
    cd $DIRECTORY/zsign/build/linux
    make clean && make

    sudo mv /home/linuxbrew/.linuxbrew/opt/cloudflared/bin/cloudflared $PREFIX/bin/
    sudo mv $DIRECTORY/zsign/bin/zsign $PREFIX/bin/
    sudo chmod +x $PREFIX/bin/zsign
    rm -rf $DIRECTORY/zsign
fi

clear
cd $DIRECTORY
echo "Preparation done!"
echo "SHOWING INSTALLED COMMANDS:"
command -v zsign
command -v cloudflared
$PYTHON -c "import flask; print('Python lib - Flask')"
