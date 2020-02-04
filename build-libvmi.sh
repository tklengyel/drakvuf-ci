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

export CXX='clang++'
export CC="clang"

# Build
autoreconf -vif || error_exit
./configure "$1" --prefix="$WORKSPACE/install" || error_exit
make -j4 || error_exit
make -j4 install || error_exit

exit 0
