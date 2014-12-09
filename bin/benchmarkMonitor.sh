#!/bin/bash
i_scriptDir=$(cd "$(dirname "$0")"; pwd)
cd $i_scriptDir/..

i_interval=30

while [[ true ]]; do
    i_nodes=$(ps ax | grep node |grep client | grep -v grep)
    if [[ "X$i_nodes" == "X" ]]; then
        echo $(date) "No nodes program running. Exiting..."
        break
    else
        echo $(date) "Node program running"
    fi
    sleep $i_interval
done


echo $(date) "Done"