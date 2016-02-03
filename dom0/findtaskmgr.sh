#!/bin/bash
/usr/local/bin/process-list $1 | grep taskmgr.exe | awk -F' ' '{print $2}' | awk -F']' '{print $1}';

