sudo apt install -y g++ pkg-config libssl-dev libminizip-dev git make
NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
export PATH=/home/linuxbrew/.linuxbrew/bin:$PATH
brew install cloudflared
cd $HOME
git clone https://github.com/zhlynn/zsign.git
cd zsign/build/linux
make clean && make
cd $HOME/zsign/bin
sudo mv /home/linuxbrew/.linuxbrew/bin/cloudflared $PREFIX/bin/cloudflared
sudo mv zsign $PREFIX/usr/bin
sudo chmod +x $PREFIX/usr/bin/zsign
sudo pip install Flask
sudo apt install python3-flask
clear
echo "Preparation done!"
echo "SHOWING INSTALLED COMMANDS:"
command -v zsign
command -v cloudflared
apt search python3-flask
