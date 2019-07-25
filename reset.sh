#!/bin/bash
domain=$1
lvm_vg="t1ssd"
folder="/ssd-storage/cfg"

clone() {
    domain=$1
    test=$(xl domid $domain-jenkins 2>/dev/null || echo 0)
    if [ $test -ne 0 ]; then
        xl destroy $test 1>/dev/null || echo 0
    fi

    test=$(lvdisplay /dev/$lvm_vg/$domain-jenkins 2>/dev/null | wc -l || echo 0)
    if [ $test -ne 0 ]; then
        lvremove -f /dev/$lvm_vg/$domain-jenkins 2>/dev/null 1>&2 || echo 0
    fi

    lvcreate -s -n $domain-jenkins -L5G /dev/$lvm_vg/$domain 2>/dev/null 1>&2 || echo 0
    xl restore -e $folder/$domain-jenkins.cfg $folder/$domain.save 2>/dev/null 1>&2 || echo 0
    domid=$(xl domid $domain-jenkins)

    echo $domid
}

findpid() {
    domain=$1
    task=$2
    pid=$(vmi-process-list $domain | grep $task | awk -F' ' '{print $2}' | awk -F']' '{print $1}')

    if [ -z $pid ]; then
        echo 0
    else
        echo $pid
    fi
}

case "$domain" in
    "windows7-sp1-x86" | "windows7-sp1-x64")
        domid=$(clone $domain)
        tpid=$(findpid $domain-jenkins taskmgr.exe)
        epid=$(findpid $domain-jenkins explorer.exe)
        echo -n "$domid:$tpid:$epid"
        ;;
    "windows10" | "windows10-1903")
        domid=$(clone $domain)
        tpid=$(findpid $domain-jenkins Taskmgr.exe)
        epid=$(findpid $domain-jenkins explorer.exe)
        echo -n "$domid:$tpid:$epid"
        ;;
    "debian-jessie" | "debian-stretch")
        domid=$(clone $domain)
        echo -n "$domid"
        ;;
    "ubuntu-18")
        domid=$(clone "ubuntu18.10")
        echo -n "$domid"
        ;;
    *)
        exit 1
esac

exit 0


