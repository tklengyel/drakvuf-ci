#!/bin/bash
ps aux | grep drakvuf | grep json | grep $1 | grep -v timeout | grep -v sudo | awk '{print $2}'

