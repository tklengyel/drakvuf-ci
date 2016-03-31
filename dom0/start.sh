#!/bin/bash
export LD_LIBRARY_PATH=:/usr/local/lib
export PATH=$PATH:/usr/local/bin/
/usr/local/sbin/xl create /share/cfg/jenkins.cfg
screen -d -m /share/work/drakvuf-ci/dom0/server /share/work/drakvuf-ci/dom0/reset.pl
