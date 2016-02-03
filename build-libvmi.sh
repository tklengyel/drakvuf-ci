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
./autogen.sh || error_exit
./configure --prefix="$WORKSPACE/installed" --enable-xen --enable-xen-events --disable-examples --without-xenstore || error_exit
make || error_exit
make install || error_exit

export PKG_CONFIG_PATH="$WORKSPACE/installed/lib/pkgconfig/"
export LD_LIBRARY_PATH="$WORKSPACE/installed/lib"
export LDFLAGS="-L$WORKSPACE/installed/lib"
export CFLAGS="-I$WORKSPACE/installed/include"
export PYTHONPATH="$WORKSPACE/installed/lib/python2.7/site-packages/"

cd /opt/drakvuf || error_exit
git reset --hard || error_exit
git clean -xdf || error_exit
./autogen.sh || error_exit
./configure --disable-plugin-filedelete || error_exit
make || error_exit

/opt/jenkins/run.pl /opt/drakvuf/ "$WORKSPACE/installed" || error_exit

exit 0
