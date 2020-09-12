#!/bin/bash
do_findpid() {
    local domain=$1
    local task=$2
    local pid=$(timeout -k 10 5 vmi-process-list $domain 2>/dev/null | grep $task | tail -n1 | awk -F' ' '{print $2}' | awk -F']' '{print $1}')

    if [ -z $pid ]; then
        echo -n 0
    else
        echo -n $pid
    fi
}

findpid() {
    local pid=$(do_findpid $1 $2)

    if [ $pid == "0" ]; then
        pid=$(do_findpid $1 $2)
    fi

    echo -n $pid
}

findpids() {
    local domain=$1
    local suffix=$2

    if [[ "$domain-$suffix" == windows7* ]]; then
            local kpgd=$(vmi-win-offsets -n "$domain-$suffix" -r /shared/cfg/$domain.json -k)
            local tpid=$(findpid "$domain-$suffix" taskmgr.exe)
            local epid=$(findpid "$domain-$suffix" explorer.exe)

            if [ $tpid -eq 0 ] || [ $epid -eq 0 ]; then
                echo -n "error:error:error"
            else
                echo -n "$tpid:$epid:$kpgd"
            fi
        exit 0
    fi

    if [[ "$domain-$suffix" == windows10* ]]; then
            local kpgd=$(vmi-win-offsets -n "$domain-$suffix" -r /shared/cfg/$domain.json -k)
            local tpid=$(findpid "$domain-$suffix" Taskmgr.exe)
            local epid=$(findpid "$domain-$suffix" explorer.exe)

            if [ $tpid -eq 0 ] || [ $epid -eq 0 ]; then
                echo -n "error:error:error"
            else
                echo -n "$tpid:$epid:$kpgd"
            fi
        exit 0
    fi

    echo -n "error:error:error"
    exit 1
}
