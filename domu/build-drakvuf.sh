#!/bin/bash
function git_clean
{
    sudo git reset --hard > /dev/null
    sudo git clean -xdf > /dev/null
}

function error_exit
{
    exit 1
}

# Preamble
cd "$WORKSPACE"
git_clean

export PKG_CONFIG_PATH='/opt/libvmi/lib/pkgconfig/'
export LD_LIBRARY_PATH='/opt/libvmi/lib'
export LDFLAGS='-L/opt/libvmi/lib'
export CFLAGS='-I/opt/libvmi/include'
export PYTHONPATH='/opt/libvmi/lib/python2.7/site-packages/'
export CXX='clang++-6.0'

# Build
./autogen.sh || error_exit
./configure --enable-debug || error_exit
make -j4 || error_exit

exit 0
