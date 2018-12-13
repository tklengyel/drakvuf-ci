#!/bin/bash

runtime=10 # in seconds
timeout=30 # in seconds
vm="$1"
workspace="$2"
libvmipath="$3"

#############################################################
findpid() {
    ps aux | grep drakvuf | grep $1 | grep -v timeout | grep -v sudo | awk '{print $2}'
}

overhead() {
    local pid=$1
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

pause() {
    sudo xl pause $1
}

injector() {
    domid=$1
    pid=$2
    injector_mode=$3

    echo "Running Injector for calc.exe through PID $pid with $injector_mode"
    BUILD_ID=dontKillMe timeout --preserve-status -k $timeout $runtime \
        sudo LD_LIBRARY_PATH=$libvmipath/lib \
        $workspace/src/injector -r /opt/jenkins/$vm.json -d $domid -i $pid -e calc.exe -m $injector_mode \
        1>$workspace/$vm.output.txt 2>&1

    if [ $? -ne 0 ]; then
        cat $workspace/$vm.output.txt
        pause $domid
        exit 1
    fi

    echo "Injection with createproc worked";
}

drakvuf() {
    domid=$1
    pid=${2:-0}
    injector_mode=${3:-0}
    filter=${4:-"x"}

    echo "Running DRAKVUF for $runtime seconds"
    if [ $filter != "x" ]; then
        echo "Using syscall filter $filter"
        BUILD_ID=dontKillMe timeout --preserve-status -k $timeout $runtime \
            sudo LD_LIBRARY_PATH=$libvmipath/lib \
            $workspace/src/drakvuf -r /opt/jenkins/$vm.json -d $domid -t $runtime -p -b \
                -S $filter \
                -x procmon -x objmon -x poolmon -x filetracer -x filedelete -x socketmon -x regmon -x exmon \
                -x ssdtmon -x bsodmon -x cpuidmon \
            1>$workspace/$vm.output.txt 2>&1 &
    elif [ $pid -eq 0 ]; then
        BUILD_ID=dontKillMe timeout --preserve-status -k $timeout $runtime \
            sudo LD_LIBRARY_PATH=$libvmipath/lib \
            $workspace/src/drakvuf -r /opt/jenkins/$vm.json -d $domid -t $runtime -p -b \
            1>$workspace/$vm.output.txt 2>&1 &
    else
        echo "Performing injection with PID $pid"
        BUILD_ID=dontKillMe timeout --preserve-status -k $timeout $runtime \
            sudo LD_LIBRARY_PATH=$libvmipath/lib \
            $workspace/src/drakvuf -r /opt/jenkins/$vm.json -d $domid -t $runtime -p -b \
                -i $pid -e calc.exe -m $injector_mode \
            1>$workspace/$vm.output.txt 2>&1 &
    fi

    sleep 2

    drakvuf_pid=$(findpid $vm)
    echo "DRAKVUF is running with PID $drakvuf_pid"

    overhead $drakvuf_pid
    cpu_overhead=$?
    echo "CPU utilization average: $cpu_overhead"

    pause $domid

    syscalls=$(cat $workspace/$vm.output.txt | grep SYSCALL | wc -l)

    echo "Syscalls: $syscalls"

    if [ $syscalls -lt 100 ]; then
        cat $workspace/$vm.output.txt
        pause $domid
        exit 1
    fi

    return $cpu_overhead
}
#################################################################


echo "Running environment reset..";
reset_result=$(sudo /opt/jenkins/reset $vm)
echo "Reset result: $reset_result"

if [ $reset_result == "error" ]; then
    reset_result=$(sudo /opt/jenkins/reset $vm);
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
    drakvuf $domid 0 0 /opt/jenkins/syscalls.txt

    if [ $? -gt 90 ]; then
        echo "Overhead is a lot"
        exit 1
    fi

    drakvuf $domid $tpid createproc
fi

if [ $vm == "windows10-x64" ]; then
    echo "Received Windows 7 x64 Test VM ID: $domid";

    injector $domid $tpid createproc
    #injector $domid $epid shellexec
    drakvuf $domid 0 0 /opt/jenkins/syscalls.txt

    if [ $? -gt 90 ]; then
        echo "Overhead is a lot"
        exit 1
    fi

    drakvuf $domid $tpid createproc
fi

if [ $vm == "windows7-sp1-x86" ]; then
    echo "Received Windows 7 x64 Test VM ID: $domid";

    injector $domid $tpid createproc
    drakvuf $domid 0 0 /opt/jenkins/syscalls.txt

    if [ $? -gt 90 ]; then
        echo "Overhead is a lot"
        exit 1
    fi

    drakvuf $domid $tpid createproc
fi

if [ $vm == "debian-jessie" ]; then
    echo "Received Debian Jessie Test VM ID: $domid";

    drakvuf $domid

    if [ $? -gt 90 ]; then
        echo "Overhead is a lot"
        exit 1
    fi
fi

if [ $vm == "debian-stretch" ]; then
    echo "Received Debian Stretch Test VM ID: $domid";

    drakvuf $domid

    if [ $? -gt 90 ]; then
        echo "Overhead is a lot"
        exit 1
    fi
fi

exit 0
