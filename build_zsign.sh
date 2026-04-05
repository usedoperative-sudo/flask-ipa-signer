set -e

apt install libminizip-dev
sudo mkdir -p /usr/local/lib/pkgconfig
sudo bash -c 'cat << EOF > /usr/local/lib/pkgconfig/minizip-ng.pc
prefix=/usr
exec_prefix=\${prefix}
libdir=\${exec_prefix}/lib/x86_64-linux-gnu
includedir=\${prefix}/include/minizip

Name: minizip-ng
Description: Minizip-ng shim for zsign
Version: 3.0.0
Libs: -L\${libdir} -lminizip
Cflags: -I\${includedir}
EOF'

apt-get install -y git g++ pkg-config libssl-dev libminizip-dev
git clone https://github.com/zhlynn/zsign.git
cd zsign/build/linux
make clean && make