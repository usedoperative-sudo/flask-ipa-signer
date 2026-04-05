#!/usr/bin/env bash
set -e

echo "🔧 Creating minizip-ng shim for architecture: $(gcc -print-multiarch)"
sudo mkdir -p /usr/local/lib/pkgconfig
sudo bash -c 'cat << EOF > /usr/local/lib/pkgconfig/minizip-ng.pc
prefix=/usr
exec_prefix=\${prefix}
libdir=\${exec_prefix}/lib/$(uname -m)-linux-gnu
includedir=\${prefix}/include/minizip

Name: minizip-ng
Description: Minizip-ng shim for zsign
Version: 3.0.0
Libs: -L\${libdir} -lminizip
Cflags: -I\${includedir}
EOF'
sleep 1s
echo "🔹 Done!"

echo "📥 Cloning and building zsign..."
git clone https://github.com/zhlynn/zsign.git
cd zsign/build/linux
make clean && make
