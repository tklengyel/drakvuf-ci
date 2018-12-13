#!/bin/bash

case "$1" in
    "windows7-sp1-x86" | "windows7-sp1-x64")
        domid=$(/share/work/drakvuf-ci/dom0/clone.pl $1)
        tpid=$(/share/work/drakvuf-ci/dom0/findpid.sh $1-jenkins taskmgr.exe)
        epid=$(/share/work/drakvuf-ci/dom0/findpid.sh $1-jenkins explorer.exe)
        echo -n "$domid:$tpid:$epid"
        ;;
    "windows10-x64")
        domid=$(/share/work/drakvuf-ci/dom0/clone.pl windows10-new)
        tpid=$(/share/work/drakvuf-ci/dom0/findpid.sh windows10-new-jenkins Taskmgr.exe)
        epid=$(/share/work/drakvuf-ci/dom0/findpid.sh windows10-new-jenkins explorer.exe)
        echo -n "$domid:$tpid:$epid"
        ;;
    "debian-jessie" | "debian-stretch")
        domid=$(/share/work/drakvuf-ci/dom0/clone.pl $1)
        echo -n "$domid"
        ;;
    *)
        exit 1
esac

exit 0


