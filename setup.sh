sudo apt install -y g++ pkg-config libssl-dev libminizip-dev git make
NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
export PATH=/home/linuxbrew/.linuxbrew/bin:$PATH
brew install cloudflared
git clone https://github.com/zhlynn/zsign.git
cd zsign/build/linux
make clean && make
cd $HOME/zsign/bin
sudo mv zsign $PREFIX/usr/bin
sudo chmod +x $PREFIX/usr/bin/zsign
sudo pip install Flask
clear
echo "Preparation done!"
