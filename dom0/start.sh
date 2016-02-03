#!/bin/bash
export LD_LIBRARY_PATH=:/usr/local/lib
export PATH=$PATH:/usr/local/bin/
/usr/local/sbin/xl create /share/cfg/jenkins.cfg
/usr/local/sbin/xl restore -p -e /share/jenkins/win7-sp1-x86.save
/usr/local/sbin/xl restore -p -e /share/jenkins/win7-sp1-x64.save
screen -d -m /share/jenkins/server /share/jenkins/reset.pl
