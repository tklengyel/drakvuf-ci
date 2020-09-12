#!/bin/bash
domain=$1
clone=${2:-"jenkins"}
disksize=${3:-"5G"}
lvm_vg="t1vg"
folder="/shared/cfg"
cifolder="/shared/drakvuf-ci/"
vms="windows7-sp1-x86-jenkins windows7-sp1-x64-jenkins windows10-jenkins windows10-2004-jenkins debian-stretch-jenkins"

. $cifolder/setenv.sh
. $cifolder/findpid.sh

clone_do() {
    test=$(xl domid $domain-$clone 2>/dev/null || echo -n 0)
    if [ $test -ne 0 ]; then
        xl destroy $test 1>/dev/null 2>/dev/null || echo "error destroy"
    fi

    test=$(lvdisplay /dev/$lvm_vg/$domain-$clone 2>/dev/null | wc -l || echo -n 0)
    if [ $test -ne 0 ]; then
        lvremove -f /dev/$lvm_vg/$domain-$clone 2>/dev/null 1>&2 || echo "error remove"
    fi

    lvcreate -s -n $domain-$clone -L$disksize /dev/$lvm_vg/$domain 2>/dev/null 1>&2 || echo "error lvcreate"
    sed "s/$domain/$domain-$clone/g" $folder/$domain.cfg > /tmp/$domain-$clone.cfg
    xl restore -e /tmp/$domain-$clone.cfg $folder/$domain.save 2>/dev/null 1>&2 || echo "error restore"
    xl domid $domain-$clone || echo "error domid"
}

clone() {
    clone_result=$(clone_do)
    count=$(echo -n "$clone_result" | wc -w)
    error=$(echo -n "$clone_result" | grep "error" | wc -l)

    if [ $error -ne 0 ] || [ $count -ne 1 ]; then
        echo 0
    else
        echo $clone_result
    fi
}

clean() {
    for vm in $vms; do
        xl destroy $vm 1>/dev/null 2>/dev/null || :
    done
}

#clean
set_libvmi_env

domid=$(clone)
pids=$(findpids $domain $clone)

echo -n "$domid:$pids"

exit 0
