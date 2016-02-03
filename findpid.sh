#!/bin/bash
ps aux | grep drakvuf | grep root | grep sudo | awk -F' ' '{print $2}'
