#!/usr/bin/env bash

echo "Detecting environment..."

# Detect Termux (PREFIX típico)
if [[ "$PREFIX" == "/data/data/com.termux/files/usr" ]]; then
    echo "🟣 Termux detected!"

    apt install -y \
        clang \
        make \
        git \
        *ssl* \
        *minizip* \
        python \
        build-essential

    # Cloudflared en Termux (ya existe paquete)
    apt install -y cloudflared

    cd $HOME
    git clone https://github.com/zhlynn/zsign.git
    sed -i 's|/tmp|/data/data/com.termux/files/usr/tmo|g' zsign/src/common/fs.cpp
    cd zsign/build/linux
    make clean && make

    mv $HOME/zsign/bin/zsign $PREFIX/bin/
    chmod +x $PREFIX/bin/zsign

else
    echo "🟢 Linux normal detected!"

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

    cd $HOME
    git clone https://github.com/zhlynn/zsign.git
    cd zsign/build/linux
    make clean && make

    sudo mv /home/linuxbrew/.linuxbrew/opt/cloudflared/bin/cloudflared $PREFIX/bin/
    sudo mv $HOME/zsign/bin/zsign $PREFIX/bin/
    sudo chmod +x $PREFIX/bin/zsign
fi

clear
cd $HOME/flask-ipa-signer
echo "Preparation done!"
echo "SHOWING INSTALLED COMMANDS:"
command -v zsign
command -v cloudflared
echo "Python lib - Flask"
