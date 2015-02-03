#!/bin/bash
# only for linux
i_scriptDir=$(cd "$(dirname "$0")"; pwd)
cd $i_scriptDir/..

i_testid="test1"
if [[ "X$1" != "X" ]]; then
    i_testid=$1
fi

nohup vmstat -n 3 | while read line; do echo `date` $line; done >$i_testid"_vmstat.log" 2>&1 &