#!/bin/bash
/usr/local/bin/process-list $1 | head -n -1 | grep taskmgr.exe | grep -v grep | awk -F' ' '{print $2}' | awk -F']' '{print $1}';
xl pause $1
