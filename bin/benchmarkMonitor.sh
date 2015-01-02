#!/bin/bash
i_scriptDir=$(cd "$(dirname "$0")"; pwd)
cd $i_scriptDir/..

i_totalTime=0
i_interval=30
# default limit 2h
i_limit=$((3600*2))

if [[ "X$1" != "X" ]]; then
    i_limit=$1
fi

echo "watch client process for $i_limit"s

while [[ true ]]; do
    i_nodes=$(ps ax | grep node |grep client | grep -v grep)
    if [[ "X$i_nodes" == "X" ]]; then
        echo $(date) "No nodes program running. Exiting..."
        break
    else
        echo $(date) "Node program running. TotalTime $i_totalTime"s
        if [[ $i_totalTime -gt $i_limit ]]; then
            echo "timeout"
            for i in $(ps ax | grep node |grep client | grep -v grep| awk '{split($0,a," "); print a[1]}'); do
                echo "kill $i"
                kill $i
            done
            continue
        fi
    fi
    sleep $i_interval
    i_totalTime=$((i_totalTime+i_interval))
done


echo $(date) "Done"