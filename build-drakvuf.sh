#!/bin/bash
function git_clean
{
    cd "$WORKSPACE"
    git reset --hard
    git clean -xdf
}

function error_exit
{
    git_clean
    exit 1
}

# Preamble
git_clean

export PKG_CONFIG_PATH='/opt/libvmi/lib/pkgconfig/'
export LD_LIBRARY_PATH='/opt/libvmi/lib'
export LDFLAGS='-L/opt/libvmi/lib'
export CFLAGS='-I/opt/libvmi/include'
export PYTHONPATH='/opt/libvmi/lib/python2.7/site-packages/'

# Build
./autogen.sh || error_exit
./configure || error_exit
make || error_exit

# Run
/opt/jenkins/run.pl "$WORKSPACE" /opt/libvmi || error_exit

exit 0
