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

export PKG_CONFIG_PATH="$LIBVMI/lib/pkgconfig/"
export LD_LIBRARY_PATH="$LIBVMI/lib"
export LDFLAGS="-L$LIBVMI/lib"
export CFLAGS="-I$LIBVMI/include"
export PYTHONPATH="$LIBVMI/lib/python2.7/site-packages/"
export CXX="clang++"
export CC="clang"

# Build
./autogen.sh || error_exit
./configure "$1" || error_exit
make -j4 || error_exit

exit 0
