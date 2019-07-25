#!/bin/bash

runtime=60 # in seconds
sigtime=70 # in seconds
timeout=80 # in seconds
vm="$1"
workspace="$2"
libvmipath="$3"

#############################################################
findpid() {
    ps aux | grep drakvuf | grep $1 | grep -v timeout | grep -v sudo | grep -v "drakvuf-ci" | awk '{print $2}'
}

overhead() {
    local pid=$1
    local timer=$2
    local count=0
    local overhead=0

    while [ $count -ne $runtime ]; do
        cpu=$(ps -p $pid -o %cpu | tail -n1 | awk -F"." '{print $1}')
        if [ $cpu = "%CPU" ]; then
            break
        fi
        count=$((count+1))
        overhead=$((overhead+cpu))
        sleep 1
    done

    if [ $count > 0 ]; then
        return $((overhead / count))
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

    echo "Running Injector for calc.exe through PID $pid with $injector_mode:"

    LD_LIBRARY_PATH=$libvmipath/lib \
        timeout --preserve-status -k $timeout $sigtime \
        $workspace/src/injector -v -r /ssd-storage/cfg/$vm.json -d $domid -i $pid -e calc.exe -m $injector_mode -j $runtime\
        1>/tmp/$vm.$injector_mode.output.txt 2>&1

    if [ $? -ne 0 ]; then
        cat /tmp/$vm.$injector_mode.output.txt
        destroy $domid
        exit 1
    fi

    echo "Injection with $injector_mode worked";
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

    opts=""
    if [ $pid -ne 0 ]; then
        opts="$opts -i $pid -e calc.exe -m $injector_mode"
    fi
    if [ $filter != "x" ]; then
        opts="$opts -S $filter"
        opts="$opts -a syscalls"
    fi
    if [ $tcpip != "x" ]; then
        opts="$opts --rekall-tcpip $tcpip"
    fi
    if [ $wow64 != "x" ]; then
        opts="$opts --rekall-wow $wow64"
    fi
    if [ $win32k != "x" ]; then
        opts="$opts --rekall-win32k $win32k"
    fi

    echo "Running DRAKVUF #$runid for $runtime seconds. Opts: $opts"
 	LD_LIBRARY_PATH=$libvmipath/lib \
        timeout --preserve-status -k $timeout $sigtime \
            $workspace/src/drakvuf \
                -v \
                -r /ssd-storage/cfg/$vm.json \
                -d $domid \
                -t $runtime \
                -p \
                -b \
                -o $output \
                $opts \
            1>/tmp/$vm.$runid.output.txt 2>&1 &

    waitfor=0
    drakvuf_pid=$(findpid $vm)
    while [ -z "$drakvuf_pid" ]
    do
        ((waitfor++));
        if [ $waitfor -ge 5 ]; then
            echo "DRAKVUF startup failed"
            exit 1
        fi

        sleep 1
        drakvuf_pid=$(findpid $vm)
    done

    echo "DRAKVUF is running with PID $drakvuf_pid"

    overhead $drakvuf_pid
    cpu_overhead=$?
    echo "CPU utilization average: $cpu_overhead"

    syscalls=$(cat /tmp/$vm.$runid.output.txt | grep -i SYSCALL | wc -l)

    echo "Syscalls: $syscalls"

    kill -0 $drakvuf_pid 2>/dev/null
    while [ $? -eq 0 ]
    do
        sleep 1
        kill -0 $drakvuf_pid 2>/dev/null
    done

    if [ $syscalls -lt 10 ]; then
        cat /tmp/$vm.$runid.output.txt
	    destroy $domid
        exit 1
    fi

    return $cpu_overhead
}
#################################################################


echo "Running environment reset..";
reset_result=$(/shared/drakvuf-ci/reset.sh $vm)
echo "Reset result: $reset_result"

if [ $reset_result == "error" ]; then
    reset_result=$(/shared/drakvuf-ci/reset.sh $vm);
    echo "Re-trying reset: $reset_result";
fi

if [ $reset_result == "error" ]; then
    exit 1
fi

values=(${reset_result//:/ })

domid=${values[0]}
tpid=${values[1]}
epid=${values[2]}

if [ $vm == "windows7-sp1-x64" ]; then
    echo "Received Windows 7 x64 Test VM ID: $domid";

    injector $domid $tpid createproc
    injector $domid $epid shellexec
    drakvuf $domid 1 $tpid  createproc  csv
    drakvuf $domid 2 0      0           json    /shared/syscalls.txt
    drakvuf $domid 3 0      0           default x                    x x /shared/windows7-sp1-x64/win32k.json

    if [ $? -gt 90 ]; then
        echo "Overhead is a lot"
        exit 1
    fi

    exit 0
fi

if [ $vm == "windows10" ]; then
    echo "Received Windows 10 x64 Test VM ID: $domid";

    sleep 120

    injector $domid $tpid createproc
    injector $domid $epid shellexec
    drakvuf $domid 1 $tpid createproc csv
    drakvuf $domid 2 0 0 json /shared/syscalls.txt

    if [ $? -gt 95 ]; then
        echo "Overhead is a lot"
        exit 1
    fi

    exit 0
fi

if [ $vm == "windows10-1903" ]; then
    echo "Received Windows 10 1903 x64 Test VM ID: $domid";

    sleep 120

    drakvuf $domid 1 0 0 json /shared/syscalls.txt

    if [ $? -gt 95 ]; then
        echo "Overhead is a lot"
        exit 1
    fi

    exit 0
fi

if [ $vm == "windows7-sp1-x86" ]; then
    echo "Received Windows 7 x86 Test VM ID: $domid";

    injector $domid $tpid createproc
    drakvuf $domid 1 $tpid createproc csv
    drakvuf $domid 2 0 0 json /shared/syscalls.txt

    if [ $? -gt 90 ]; then
        echo "Overhead is a lot"
        exit 1
    fi

    exit 0
fi

if [ $vm == "debian-jessie" ]; then
    echo "Received Debian Jessie Test VM ID: $domid";

    drakvuf $domid 1 0 0

    if [ $? -gt 90 ]; then
        echo "Overhead is a lot"
        exit 1
    fi

    exit 0
fi

if [ $vm == "debian-stretch" ]; then
    echo "Received Debian Stretch Test VM ID: $domid";

    drakvuf $domid 1 0 0 kv

    if [ $? -gt 90 ]; then
        echo "Overhead is a lot"
        exit 1
    fi

    exit 0
fi

if [ $vm == "ubuntu-18" ]; then
    echo "Received Ubuntu 18.10 Test VM ID: $domid";

    drakvuf $domid 1 0 0 json

    if [ $? -gt 90 ]; then
        echo "Overhead is a lot"
        exit 1
    fi

    exit 0
fi

exit 1
