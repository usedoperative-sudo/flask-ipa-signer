#!/usr/bin/env bash

DIRECTORY=$(pwd)


echo "Detecting environment..."

# Detect Termux (PREFIX típico)
if [[ "$PREFIX" == "/data/data/com.termux/files/usr" ]]; then
    echo "🟣 Termux (experimental) detected!"
    PYTHON=python

    apt install -y \
        clang \
        make \
        git \
        *ssl* \
        *minizip* \
        python \
        build-essential

    # Cloudflared y Flask en Termux (ya existe paquete)
    apt install -y cloudflared
    pip install Flask

    cd $DIRECTORY
    git clone https://github.com/zhlynn/zsign.git
    sed -i 's|/tmp|/data/data/com.termux/files/usr/tmo|g' zsign/src/common/fs.cpp
    cd zsign/build/linux
    make clean && make

    mv $DIRECTORY/zsign/bin/zsign $PREFIX/bin/
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
    cd zsign/build/linux
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
