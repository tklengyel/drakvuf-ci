#!/bin/bash

runtime=60 # in seconds
sigtime=70 # in seconds
timeout=80 # in seconds
vm="$1"
workspace="$2"
libvmipath="$3"
reset=${4:-"-"}
outfolder=/shared/tmp
cfgfolder=/shared/cfg
cifolder=/shared/drakvuf-ci
AUTORUNS=/shared/sysinternals/Autoruns64.exe

. $cifolder/findpid.sh

#############################################################
finddrakvufpid() {
    ps aux | grep drakvuf | grep $1 | grep -v timeout | grep -v sudo | grep -v "drakvuf-ci" | grep -m 1 drakvuf | awk '{print $2}'
}

overhead() {
    local pid=$1
    local timer=$2
    local count=1
    local final=0
    local cpu=0

     while [ $count -ne $runtime ]; do
         cpu=$(ps -p $pid -o %cpu | tail -n1 | awk -F"." '{print $1}')
         if [ $cpu == "%CPU" ]; then
             break
         fi
         count=$((count+1))
         final=$cpu
         sleep 1
     done

    if [ $count > 0 ]; then
        return $final
    else
        return "-1"
    fi
}

destroy() {
    xl destroy $1 || :
}

injector() {
    domid=$1
    pid=$2
    injector_mode=$3

    if [ $pid -eq 0 ]; then
        exit 1;
    fi

    echo "Running Injector for calc.exe through PID $pid with $injector_mode"

    LD_LIBRARY_PATH=$libvmipath/lib \
        timeout --preserve-status -k $timeout $sigtime \
        $workspace/src/injector -r $cfgfolder/$vm.json -d $domid -i $pid -e calc.exe -m $injector_mode \
        1>$outfolder/$vm.$injector_mode.output.txt 2>&1

    if [ $? -ne 0 ]; then
        cat $outfolder/$vm.$injector_mode.output.txt
        rm $outfolder/$vm.$injector_mode.output.txt
        destroy $domid
        exit 1
    fi

    rm $outfolder/$vm.$injector_mode.output.txt
    echo "Injection with $injector_mode worked";
}

inject_autoruns() {
    domid=$1
    pid=$2

    if [ $pid -eq 0 ]; then
        exit 1;
    fi

    echo "Running Injector to write autoruns into guest through PID $pid"

    LD_LIBRARY_PATH=$libvmipath/lib \
        timeout --preserve-status -k $timeout $sigtime \
        $workspace/src/injector -r $cfgfolder/$vm.json -d $domid -i $pid \
            -m writefile \
            -e 'C:\\autoruns64.exe' \
            -B $AUTORUNS \
        1>$outfolder/$vm.autoruns.output.txt 2>&1

    if [ $? -ne 0 ]; then
        cat $outfolder/$vm.autoruns.output.txt
        rm $outfolder/$vm.autoruns.output.txt
        destroy $domid
        exit 1
    fi

    # file was written into the guest, now execute it
    echo "Placed $AUTORUNS into VM, now executing"

    LD_LIBRARY_PATH=$libvmipath/lib \
        timeout --preserve-status -k $timeout $sigtime \
        $workspace/src/injector -r $cfgfolder/$vm.json -d $domid -i $pid \
            -e 'C:\\autoruns64.exe' \
        1>$outfolder/$vm.autoruns.output.txt 2>&1

    if [ $? -ne 0 ]; then
        cat $outfolder/$vm.autoruns.output.txt
        rm $outfolder/$vm.autoruns.output.txt
        destroy $domid
        exit 1
    fi

    # check that the process is running

    count=$(LD_LIBRARY_PATH=$libvmipath/lib $libvmipath/bin/vmi-process-list $vm-jenkins | grep autoruns | wc -l)
    echo "autoruns process found: $count"

    if [ $count -ne 1 ]; then
        cat $outfolder/$vm.autoruns.output.txt
        rm $outfolder/$vm.autoruns.output.txt
        destroy $domid
        exit 1
    fi

    rm $outfolder/$vm.autoruns.output.txt
}

run_valgrind() {
    echo "Running Valgrind on $vm-jenkins"

    G_SLICE=always-malloc LD_LIBRARY_PATH=$libvmipath/lib \
        timeout --preserve-status -k 50 40 \
        valgrind \
            --show-reachable=no \
            --leak-check=full \
            --track-origins=yes \
            --trace-children=yes \
            --xml=yes \
            --xml-file=$workspace/valgrind.drakvuf.xml \
            $workspace/src/drakvuf -r $cfgfolder/$vm.json -d $vm-jenkins -t 30 \
    1>$outfolder/$vm.valgrind.txt 2>$outfolder/$vm.valgrind-err.txt
}

drakvuf() {
    domid=$1
    runid=$2
    pid=${3:-0}
    injector_mode=${4:-0}
    output=${5:-"default"}
    filter=${6:-"x"}
    tcpip=${7:-"x"}
    wow64=${8:-"x"}
    win32k=${9:-"x"}
    dllhooks=${10:-"x"}

    opts=""
    if [ $pid -ne 0 ]; then
        opts="$opts -i $pid -e calc.exe -m $injector_mode"
    fi
    if [ $filter != "x" ]; then
        path=$workspace/$filter
        opts="$opts -S $path"
        opts="$opts -a syscalls"
    fi
    if [ $tcpip != "x" ]; then
        opts="$opts --json-tcpip $tcpip"
    fi
    if [ $wow64 != "x" ]; then
        opts="$opts --json-wow $wow64"
    fi
    if [ $win32k != "x" ]; then
        opts="$opts --json-win32k $win32k"
    fi
    if [ $dllhooks != "x" ]; then
        path=$workspace/$dllhooks
        opts="$opts -a memdump -a apimon"
        opts="$opts --dll-hooks $path"
    fi

    echo "Running DRAKVUF #$runid for $runtime seconds. Opts: $opts"
    LD_LIBRARY_PATH=$libvmipath/lib \
    G_SLICE=debug-blocks \
        timeout --preserve-status -k $timeout $sigtime \
            $workspace/src/drakvuf \
                -r $cfgfolder/$vm.json \
                -d $domid \
                -t $runtime \
                -b \
                -o $output \
                $opts \
            2>$outfolder/$vm.$runid.error.txt | \
            tee >(grep -i syscall | wc -l > $outfolder/$vm.$runid.syscall.txt) \
                >(egrep -i 'apimon|memdump' | grep CharLowerA | grep "0x41" | wc -l > $outfolder/$vm.$runid.apimon.charlowera.txt) \
                >(egrep -i 'apimon|memdump' | grep SetRect | grep -i "0xC0DEC0DE" | wc -l > $outfolder/$vm.$runid.apimon.setrect.txt) \
            >/dev/null &
#            >$outfolder/$vm.$runid.stdout.txt &

    wait_pid=$!
    waitfor=0
    drakvuf_pid=$(finddrakvufpid $vm)
    while [ -z "$drakvuf_pid" ]
    do
        ((waitfor++));
        if [ $waitfor -ge 5 ]; then
            echo "DRAKVUF startup failed"
            exit 1
        fi

        sleep 1
        drakvuf_pid=$(finddrakvufpid $vm)
    done

    echo "DRAKVUF is running with PID $drakvuf_pid, background pid is $wait_pid"

    overhead $drakvuf_pid
    cpu_overhead=$?
    echo "CPU utilization average: $cpu_overhead"

    wait $wait_pid
    status=$?

    echo "Exit status: $status"

    if [ $status -ne 0 ]; then
        destroy $domid
        cat $outfolder/$vm.$runid.error.txt
        exit 1
    fi

    errors=$(cat $outfolder/$vm.$runid.error.txt | wc -l)
    echo "stderr line count: $errors"

    if [ $errors -ne 1 ]; then
        destroy $domid
        cat $outfolder/$vm.$runid.error.txt
        exit 1
    fi

    sleep 1

    syscalls=$(cat $outfolder/$vm.$runid.syscall.txt)
    echo "Syscalls: $syscalls"

    re='^[0-9]+$'
    if ! [[ $syscalls =~ $re ]] || [ $syscalls -lt 10 ]; then
	    destroy $domid
        cat $outfolder/$vm.$runid.error.txt
        exit 1
    fi

    if [ $dllhooks != "x" ]; then
        dllhooktest=$(cat $outfolder/$vm.$runid.apimon.charlowera.txt)
        echo "CharLowerA: $dllhooktest"
        if [ $dllhooktest -lt 1 ]; then
            destroy $domid
            cat $outfolder/$vm.$runid.error.txt
            exit 1
        fi

        dllhooktest=$(cat $outfolder/$vm.$runid.apimon.setrect.txt)
        echo "SetRect: $dllhooktest"
        if [ $dllhooktest -lt 1 ]; then
            destroy $domid
            cat $outfolder/$vm.$runid.error.txt
            exit 1
        fi
    fi

    return $cpu_overhead
}
#################################################################


if [ $reset != "-" ]; then
    echo "Running environment reset..";
    reset_result=$($cifolder/reset.sh $vm)
    values=(${reset_result//:/ })
    echo "Reset result: $reset_result"

    if [ ${values[0]} -eq 0 ]; then
        reset_result=$($cifolder/reset.sh $vm);
        values=(${reset_result//:/ })
        echo "Re-trying reset: $reset_result";
    fi

    if [ ${values[0]} -eq 0 ]; then
        exit 1
    fi
else
    domid=$(xl domid "$vm-jenkins")
    pids=$(findpids $vm)
    reset_result="$domid:$pids"
fi

values=(${reset_result//:/ })
domid=${values[0]}
tpid=${values[1]}
epid=${values[2]}

if [ -z $domid ] || [ $domid -eq 0 ]; then
    exit 1;
fi

if [ $tpid == "error" ]; then
    tpid=0
fi

if [ $epid == "error" ]; then
    epid=0
fi

if [ $vm == "windows7-sp1-x64" ]; then
    echo "Received Windows 7 x64 Test VM ID: $domid $tpid $epid";

    injector $domid $tpid createproc
    injector $domid $tpid createproc
    injector $domid $epid shellexec
    drakvuf $domid 1 $tpid createproc  csv
    drakvuf $domid 2 0      0           json    ci/syscalls.txt
    #drakvuf $domid 3 0      0           default x                    x x /shared/windows7-sp1-x64/win32k.json

    overhead=$?

    if [ $overhead -gt 90 ]; then
        echo "Overhead is a lot"
        exit 1
    fi
fi

if [ $vm == "windows10" ]; then
    echo "Received Windows 10 x64 Test VM ID: $domid $tpid $epid";

    injector $domid $tpid createproc
    #injector $domid $epid shellexec
    #drakvuf $domid 1 $tpid createproc  csv ci/syscalls.txt
    drakvuf $domid 1 0      0   csv ci/syscalls.txt
    drakvuf $domid 2 0      0   json ci/syscalls.txt x x x ci/dll-hooks-list

    overhead=$?

    if [ $overhead -gt 95 ]; then
        echo "Overhead is a lot"
        exit 1
    fi
fi

if [ $vm == "windows10-2004" ]; then
    echo "Received Windows 10 x64 Test VM ID: $domid $tpid $epid";

    #injector $domid $tpid createproc
    #injector $domid $epid shellexec
    inject_autoruns $domid $tpid
    drakvuf $domid 1 $tpid createproc  csv ci/syscalls.txt
    #drakvuf $domid 1 0      0   csv ci/syscalls.txt
    drakvuf $domid 2 0      0   kv ci/syscalls.txt

    overhead=$?

    if [ $overhead -gt 95 ]; then
        echo "Overhead is a lot"
        exit 1
    fi
fi

if [ $vm == "windows7-sp1-x86" ]; then
    echo "Received Windows 7 x86 Test VM ID: $domid $tpid $epid";

    injector $domid $tpid createproc
    drakvuf $domid 1 $tpid createproc csv
    drakvuf $domid 2 0 0 json ci/syscalls.txt

    overhead=$?

    if [ $overhead -gt 90 ]; then
        echo "Overhead is a lot"
        exit 1
    fi
fi

if [ $vm == "debian-stretch" ]; then
    echo "Received Debian Stretch Test VM ID: $domid";

    drakvuf $domid 1 0 0 kv

    overhead=$?

    if [ $overhead -gt 90 ]; then
        echo "Overhead is a lot"
        exit 1
    fi
fi

run_valgrind

exit $?
