#!/bin/bash
/usr/local/bin/vmi-process-list $1 | grep $2 | awk -F' ' '{print $2}' | awk -F']' '{print $1}';
