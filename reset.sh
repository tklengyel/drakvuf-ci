#!/bin/bash
domain=$1
lvm_vg="t1vg"
folder="/shared/cfg"
cifolder="/shared/drakvuf-ci/"

. $cifolder/findpid.sh

clone_do() {
    domain=$1
    test=$(xl domid $domain-jenkins 2>/dev/null || echo -n 0)
    if [ $test -ne 0 ]; then
        xl destroy $test 1>/dev/null 2>/dev/null || echo "error destroy"
    fi

    test=$(lvdisplay /dev/$lvm_vg/$domain-jenkins 2>/dev/null | wc -l || echo -n 0)
    if [ $test -ne 0 ]; then
        lvremove -f /dev/$lvm_vg/$domain-jenkins 2>/dev/null 1>&2 || echo "error remove"
    fi

    lvcreate -s -n $domain-jenkins -L5G /dev/$lvm_vg/$domain 2>/dev/null 1>&2 || echo "error lvcreate"
    xl restore -e $folder/$domain-jenkins.cfg $folder/$domain.save 2>/dev/null 1>&2 || echo "error restore"
    xl domid $domain-jenkins || echo "error domid"
}

clone() {
    clone_result=$(clone_do $1)
    count=$(echo -n "$clone_result" | wc -w)
    error=$(echo -n "$clone_result" | grep "error" | wc -l)

    if [ $error -ne 0 ] || [ $count -ne 1 ]; then
        echo 0
    else
        echo $clone_result
    fi
}

domid=$(clone $domain)
pids=$(findpids $domain)

echo -n "$domid:$pids"

exit 0
