#!/bin/bash
findpid() {
    local domain=$1
    local task=$2
    local pid=$(vmi-process-list $domain 2>/dev/null | grep $task | tail -n1 | awk -F' ' '{print $2}' | awk -F']' '{print $1}')

    if [ -z $pid ]; then
        echo 0
    else
        echo $pid
    fi
}

findpids() {
    local domain=$1

    case "$domain" in
        "windows7-sp1-x86" | "windows7-sp1-x64")
            local tpid=$(findpid $domain-jenkins taskmgr.exe)
            local epid=$(findpid $domain-jenkins explorer.exe)

            if [ $tpid -eq 0 ] || [ $epid -eq 0 ]; then
                echo -n "error:error"
            else
                echo -n "$tpid:$epid"
            fi
            ;;
        "windows10")
            local tpid=$(findpid $domain-jenkins Taskmgr.exe)
            local epid=$(findpid $domain-jenkins explorer.exe)

            if [ $tpid -eq 0 ] || [ $epid -eq 0 ]; then
                echo -n "error:error"
            else
                echo -n "$tpid:$epid"
            fi
            ;;
        *)
            echo -n "error:error"
            exit 1
    esac
}
